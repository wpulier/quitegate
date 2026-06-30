import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import UIKit

@MainActor
final class IOSEnforcementController: ObservableObject {
  @Published var selection: FamilyActivitySelection {
    didSet {
      persistState()
      applyCurrentMode()
    }
  }

  @Published var shieldingEnabled: Bool {
    didSet {
      persistState()
      applyCurrentMode()
    }
  }

  @Published var authorizationMode: IOSEnforcementAuthorizationMode {
    didSet {
      persistState()
      saveSnapshot(lastError: lastError)
      updateStatusMessage()
    }
  }

  @Published var enforcementMode: IOSEnforcementMode {
    didSet {
      persistState()
      applyCurrentMode()
    }
  }

  @Published var dailyLimitMinutes: Int {
    didSet {
      dailyLimitMinutes = min(max(dailyLimitMinutes, 5), 480)
      persistState()
      applyCurrentMode()
    }
  }

  @Published var safariExtensionAcknowledged: Bool {
    didSet {
      persistState()
      writeSafariPolicy()
      saveSnapshot(lastError: lastError)
      updateStatusMessage()
    }
  }

  @Published private(set) var authorizationState: IOSScreenTimeAuthorizationState = .notDetermined
  @Published private(set) var statusMessage: String = "Choose setup type, allow Screen Time, then select apps and sites."
  @Published private(set) var scheduleActive = false
  @Published private(set) var syncHealth = "Waiting for setup"
  @Published private(set) var lastError: String?

  private let immediateStore = ManagedSettingsStore(named: .tortoiseImmediate)
  private let activityCenter = DeviceActivityCenter()
  private var isApplying = false

  init() {
    let persisted = Self.loadState()
    selection = IOSEnforcementSharedStore.loadSelection()
    shieldingEnabled = persisted.shieldingEnabled
    authorizationMode = persisted.authorizationMode
    enforcementMode = persisted.enforcementMode
    dailyLimitMinutes = persisted.dailyLimitMinutes
    safariExtensionAcknowledged = persisted.safariExtensionAcknowledged
    refreshAuthorizationState()
    applyCurrentMode()
  }

  var hasSelection: Bool {
    !selection.applicationTokens.isEmpty ||
      !selection.categoryTokens.isEmpty ||
      !selection.webDomainTokens.isEmpty
  }

  var coverageSummary: String {
    if !hasSelection {
      return "No iOS targets selected"
    }

    let appText = "\(selection.applicationTokens.count) app\(selection.applicationTokens.count == 1 ? "" : "s")"
    let categoryText = "\(selection.categoryTokens.count) categor\(selection.categoryTokens.count == 1 ? "y" : "ies")"
    let domainText = "\(selection.webDomainTokens.count) Safari domain\(selection.webDomainTokens.count == 1 ? "" : "s")"
    return "\(appText) · \(categoryText) · \(domainText)"
  }

  var canApplyShielding: Bool {
    authorizationState.isApproved && hasSelection
  }

  var canTurnOn: Bool {
    canApplyShielding
  }

  var screenTimeStatusTitle: String {
    authorizationState.title
  }

  var targetStatusTitle: String {
    hasSelection ? coverageSummary : "Select apps, sites, or categories"
  }

  var safariStatusTitle: String {
    safariExtensionAcknowledged ? "Checklist confirmed" : "Enable in Safari settings"
  }

  var schedulesStatusTitle: String {
    scheduleActive ? "Daily monitor active" : "No active monitor"
  }

  var limitStatusTitle: String {
    "\(dailyLimitMinutes)m selected-target limit"
  }

  func refreshAuthorizationState() {
    let status = AuthorizationCenter.shared.authorizationStatus
    switch status {
    case .notDetermined:
      authorizationState = .notDetermined
    case .denied:
      authorizationState = .denied
    case .approved:
      authorizationState = .approved
    case .approvedWithDataAccess:
      authorizationState = .approved
    @unknown default:
      authorizationState = .unknown
    }
    updateStatusMessage()
  }

  func requestAuthorization() async {
    do {
      try await AuthorizationCenter.shared.requestAuthorization(for: authorizationMode.familyMember)
      refreshAuthorizationState()
      lastError = nil
    } catch {
      authorizationState = .denied
      lastError = error.localizedDescription
      statusMessage = authorizationMode == .child
        ? "Child setup needs Family Sharing and a child Apple Account before Screen Time authorization can finish."
        : "Screen Time permission failed. Check the Family Controls entitlement and Settings."
    }
    applyCurrentMode()
  }

  func setMode(_ mode: IOSEnforcementMode) {
    enforcementMode = mode
    shieldingEnabled = mode != .open
  }

  func turnOn() {
    if enforcementMode == .open {
      enforcementMode = .focus
    }
    shieldingEnabled = true
    applyCurrentMode()
  }

  func turnOff() {
    shieldingEnabled = false
    enforcementMode = .open
    applyCurrentMode()
  }

  func clearSelection() {
    selection = FamilyActivitySelection()
    shieldingEnabled = false
  }

  func openSettings() {
    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
      return
    }
    UIApplication.shared.open(settingsURL)
  }

  private func applyCurrentMode() {
    guard !isApplying else {
      return
    }
    isApplying = true
    defer {
      isApplying = false
      updateStatusMessage()
    }

    let shouldEnforce = shieldingEnabled && enforcementMode != .open && canApplyShielding
    if !shouldEnforce {
      IOSEnforcementShieldApplier.clearAllStores()
      activityCenter.stopMonitoring([.tortoiseDaily])
      scheduleActive = false
      syncHealth = "Open mode"
      writeSafariPolicy(mode: .open)
      saveSnapshot(lastError: lastError)
      return
    }

    let adultWebFilterEnabled = enforcementMode == .strict
    IOSEnforcementShieldApplier.applySelection(
      selection,
      to: immediateStore,
      adultWebFilterEnabled: adultWebFilterEnabled
    )
    startDailyMonitoring()
    writeSafariPolicy()
    saveSnapshot(lastError: lastError)
    syncHealth = "Screen Time and Safari policy current"
  }

  private func startDailyMonitoring() {
    let schedule = DeviceActivitySchedule(
      intervalStart: DateComponents(hour: 0, minute: 0),
      intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
      repeats: true,
      warningTime: DateComponents(minute: 5)
    )

    let event = DeviceActivityEvent(
      applications: selection.applicationTokens,
      categories: selection.categoryTokens,
      webDomains: selection.webDomainTokens,
      threshold: DateComponents(minute: dailyLimitMinutes)
    )

    do {
      try activityCenter.startMonitoring(
        .tortoiseDaily,
        during: schedule,
        events: [.tortoiseDailyLimit: event]
      )
      scheduleActive = true
      lastError = nil
    } catch {
      scheduleActive = false
      lastError = error.localizedDescription
    }
  }

  private func writeSafariPolicy(mode overrideMode: IOSEnforcementMode? = nil) {
    let mode = overrideMode ?? (shieldingEnabled ? enforcementMode : .open)
    let policy = SafariExtensionPolicy.policy(
      for: mode,
      dailyLimitMinutes: dailyLimitMinutes,
      adultWebFilterEnabled: mode == .strict
    )
    IOSEnforcementSharedStore.saveSafariPolicy(policy)
  }

  private func saveSnapshot(lastError: String?) {
    IOSEnforcementSharedStore.saveSelection(selection)
    IOSEnforcementSharedStore.saveSnapshot(
      IOSEnforcementSnapshot(
        mode: enforcementMode,
        authorizationMode: authorizationMode,
        shieldingEnabled: shieldingEnabled,
        dailyLimitMinutes: dailyLimitMinutes,
        adultWebFilterEnabled: enforcementMode == .strict && shieldingEnabled,
        safariExtensionEnabled: safariExtensionAcknowledged,
        selectedApplicationCount: selection.applicationTokens.count,
        selectedCategoryCount: selection.categoryTokens.count,
        selectedWebDomainCount: selection.webDomainTokens.count,
        scheduleActive: scheduleActive,
        lastAppliedAt: Date(),
        lastError: lastError
      )
    )
  }

  private func updateStatusMessage() {
    switch authorizationState {
    case .approved where shieldingEnabled && enforcementMode == .strict && hasSelection:
      statusMessage = "Strict is active. Selected apps/sites are shielded, Safari tuners are on, and the daily limit monitor is running."
    case .approved where shieldingEnabled && hasSelection:
      statusMessage = "Focus is active. Selected apps/sites are shielded and Safari tuners are synced."
    case .approved where hasSelection:
      statusMessage = "Ready. Turn on iOS enforcement to shield selected apps/sites and sync Safari tuners."
    case .approved:
      statusMessage = "Screen Time is approved. Select apps, categories, youtube.com, and other Safari domains next."
    case .denied:
      statusMessage = authorizationMode == .child
        ? "Child setup is not authorized. Confirm Family Sharing and Screen Time permissions for this child device."
        : "Screen Time permission is not approved for QuietGate."
    case .notDetermined:
      statusMessage = "Choose My iPhone or Child device, then allow Screen Time."
    case .unknown:
      statusMessage = "Screen Time permission status is unavailable."
    }
  }

  private func persistState() {
    IOSEnforcementSharedStore.saveSelection(selection)
    let state = PersistedIOSEnforcementState(
      authorizationMode: authorizationMode,
      enforcementMode: enforcementMode,
      shieldingEnabled: shieldingEnabled,
      dailyLimitMinutes: dailyLimitMinutes,
      safariExtensionAcknowledged: safariExtensionAcknowledged
    )
    guard let data = try? JSONEncoder().encode(state) else {
      return
    }
    UserDefaults.standard.set(data, forKey: Self.stateKey)
    TortoiseAppGroup.defaults.set(data, forKey: Self.stateKey)
  }

  private static func loadState() -> PersistedIOSEnforcementState {
    let stores = [TortoiseAppGroup.defaults, UserDefaults.standard]
    for store in stores {
      guard let data = store.data(forKey: stateKey),
            let state = try? JSONDecoder().decode(PersistedIOSEnforcementState.self, from: data) else {
        continue
      }
      return state
    }
    return PersistedIOSEnforcementState(
      authorizationMode: .individual,
      enforcementMode: .open,
      shieldingEnabled: false,
      dailyLimitMinutes: 30,
      safariExtensionAcknowledged: false
    )
  }

  private static let stateKey = "TortoiseIOSEnforcementState"
}

typealias IOSYouTubeScreenTimeController = IOSEnforcementController

enum IOSScreenTimeAuthorizationState: Equatable {
  case notDetermined
  case denied
  case approved
  case unknown

  var isApproved: Bool {
    self == .approved
  }

  var title: String {
    switch self {
    case .notDetermined:
      return "Permission needed"
    case .denied:
      return "Permission blocked"
    case .approved:
      return "Permission approved"
    case .unknown:
      return "Permission unknown"
    }
  }
}

private struct PersistedIOSEnforcementState: Codable {
  let authorizationMode: IOSEnforcementAuthorizationMode
  let enforcementMode: IOSEnforcementMode
  let shieldingEnabled: Bool
  let dailyLimitMinutes: Int
  let safariExtensionAcknowledged: Bool
}
