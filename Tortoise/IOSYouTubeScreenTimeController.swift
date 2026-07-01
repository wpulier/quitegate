import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import SafariServices
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
  @Published private(set) var safariExtensionState: IOSSafariExtensionState = .unknown
  @Published private(set) var lastSafariExtensionSeenAt: Date?
  @Published private(set) var lastSafariPolicyAppliedAt: Date?
  @Published private(set) var lastSetupCheckAt: Date?
  @Published private(set) var safariExtensionStatusError: String?

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
    loadSafariSetupSnapshot()
    refreshAuthorizationState()
    refreshSetupStatus()
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

  var connectionState: IOSEnforcementConnectionState {
    if authorizationState == .denied || lastError != nil || safariExtensionState == .failed {
      return .repairRequired
    }

    if authorizationState != .approved || !hasSelection {
      return .setupRequired
    }

    if shieldingEnabled && enforcementMode != .open && scheduleActive && safariExtensionConnected {
      return .connected
    }

    if shieldingEnabled || safariExtensionConnected || scheduleActive {
      return .partial
    }

    return .setupRequired
  }

  var setupProgressText: String {
    let completeCount = IOSEnforcementSetupStep.allCases.filter { setupStatus(for: $0) == .complete }.count
    return "\(completeCount)/\(IOSEnforcementSetupStep.allCases.count) ready"
  }

  var connectionTitle: String {
    switch connectionState {
    case .connected:
      return "iOS connected"
    case .partial:
      return "iOS partially connected"
    case .setupRequired:
      return "iOS setup needed"
    case .repairRequired:
      return "iOS needs repair"
    }
  }

  var connectionDetail: String {
    switch connectionState {
    case .connected:
      return "Screen Time, selected targets, Safari tuners, monitoring, and local policy are active."
    case .partial:
      return "Some pieces are ready. Finish the checklist so app blocking and Safari tuning both work."
    case .setupRequired:
      return "Finish Screen Time permission, target selection, Safari extension, and Turn On."
    case .repairRequired:
      return repairDetail
    }
  }

  var deviceStatusSubtitle: String {
    switch connectionState {
    case .connected:
      return "\(enforcementMode.rawValue.capitalized) active · \(coverageSummary) · \(safariStateTitle)"
    case .partial:
      return "\(enforcementMode.rawValue.capitalized) partially active · \(coverageSummary) · \(safariStateTitle)"
    case .setupRequired:
      return "Finish iOS setup · \(coverageSummary) · \(safariStateTitle)"
    case .repairRequired:
      return repairDetail
    }
  }

  var repairDetail: String {
    if authorizationState == .denied {
      return authorizationMode == .child
        ? "Child setup needs Family Sharing and Screen Time approval on the child device."
        : "Screen Time permission is blocked. Re-enable App & Website Activity for QuietGate, then retry."
    }
    if safariExtensionState == .failed {
      return safariExtensionStatusError ?? "Safari extension status could not be checked."
    }
    return lastError ?? "QuietGate could not apply the latest iOS protection state."
  }

  var safariExtensionConnected: Bool {
    switch safariExtensionState {
    case .connected:
      return true
    case .unavailable:
      return safariExtensionAcknowledged && safariHeartbeatIsFresh
    default:
      return false
    }
  }

  var safariHeartbeatIsFresh: Bool {
    IOSEnforcementSharedStore.safariHeartbeatIsFresh(lastSafariExtensionSeenAt)
  }

  var safariStateTitle: String {
    switch safariExtensionState {
    case .connected:
      return "Safari connected"
    case .enabledWaitingForHeartbeat:
      return "Enabled, waiting for Safari"
    case .disabled:
      return "Safari extension off"
    case .unavailable:
      return safariExtensionAcknowledged ? "Manual Safari check pending" : "Manual Safari setup"
    case .failed:
      return "Safari check failed"
    case .unknown:
      return "Checking Safari"
    }
  }

  var screenTimeStatusTitle: String {
    authorizationState.title
  }

  var targetStatusTitle: String {
    hasSelection ? coverageSummary : "Select apps, sites, or categories"
  }

  var safariStatusTitle: String {
    switch safariExtensionState {
    case .connected:
      return "Heartbeat verified"
    case .enabledWaitingForHeartbeat:
      return "Open Safari to verify"
    case .disabled:
      return "Enable in Safari settings"
    case .unavailable:
      return safariExtensionAcknowledged ? "Manual confirmation saved" : "Enable in Safari settings"
    case .failed:
      return "Tap Recheck or use manual setup"
    case .unknown:
      return "Checking extension state"
    }
  }

  var schedulesStatusTitle: String {
    scheduleActive ? "Daily monitor active" : "No active monitor"
  }

  var limitStatusTitle: String {
    "\(dailyLimitMinutes)m selected-target limit"
  }

  var safariManualSetupText: String {
    "Settings -> Apps -> Safari -> Extensions -> QuietGate Safari -> Allow Extension"
  }

  func setupStatus(for step: IOSEnforcementSetupStep) -> IOSEnforcementSetupStatus {
    switch step {
    case .account:
      return .complete
    case .authorizationMode:
      return .complete
    case .screenTimePermission:
      switch authorizationState {
      case .approved:
        return .complete
      case .denied:
        return .failed
      case .notDetermined:
        return .needsAction
      case .unknown:
        return .checking
      }
    case .targets:
      return hasSelection ? .complete : .needsAction
    case .safariExtension:
      switch safariExtensionState {
      case .connected:
        return .complete
      case .enabledWaitingForHeartbeat:
        return .checking
      case .disabled, .unavailable:
        return .needsAction
      case .failed:
        return .failed
      case .unknown:
        return .checking
      }
    case .mode:
      return shieldingEnabled && enforcementMode != .open ? .complete : .needsAction
    case .sync:
      if let lastError, !lastError.isEmpty {
        return .failed
      }
      return syncHealth.contains("current") || connectionState == .connected ? .complete : .checking
    }
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

  func refreshSetupStatus() {
    refreshAuthorizationState()
    loadSafariSetupSnapshot()
    lastSetupCheckAt = Date()
    refreshSafariExtensionState()
    saveSnapshot(lastError: lastError)
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

  func retrySetupStep(_ step: IOSEnforcementSetupStep) {
    switch step {
    case .screenTimePermission:
      Task {
        await requestAuthorization()
      }
    case .safariExtension:
      openSafariExtensionSettings()
    case .mode:
      turnOn()
    case .sync, .account, .authorizationMode, .targets:
      refreshSetupStatus()
    }
  }

  func openSettings() {
    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
      return
    }
    UIApplication.shared.open(settingsURL)
  }

  func openSafariExtensionSettings() {
    if #available(iOS 26.2, *) {
      SFSafariSettings.openExtensionsSettings(forIdentifiers: [Self.safariExtensionBundleIdentifier]) { [weak self] error in
        guard let self else {
          return
        }
        if let error {
          Task { @MainActor in
            self.safariExtensionStatusError = error.localizedDescription
            self.openSettings()
          }
        }
      }
      return
    }

    openSettings()
  }

  func openSafariVerificationPage() {
    guard let url = URL(string: "https://youtube.com") else {
      return
    }
    UIApplication.shared.open(url)
  }

  private func loadSafariSetupSnapshot() {
    let snapshot = IOSEnforcementSharedStore.loadSnapshot()
    lastSafariExtensionSeenAt = snapshot.lastSafariExtensionSeenAt
    lastSafariPolicyAppliedAt = snapshot.lastSafariPolicyAppliedAt
    if let storedState = snapshot.safariExtensionState {
      safariExtensionState = resolvedSafariState(from: storedState)
    } else if safariExtensionAcknowledged {
      safariExtensionState = safariHeartbeatIsFresh ? .connected : .enabledWaitingForHeartbeat
    }
  }

  private func refreshSafariExtensionState() {
    loadSafariSetupSnapshot()

    if #available(iOS 26.2, *) {
      safariExtensionState = .unknown
      SFSafariExtensionManager.getStateOfExtension(withIdentifier: Self.safariExtensionBundleIdentifier) { [weak self] state, error in
        Task { @MainActor in
          guard let self else {
            return
          }

          self.lastSetupCheckAt = Date()
          if let error {
            self.safariExtensionStatusError = error.localizedDescription
            self.safariExtensionState = .failed
          } else if state?.isEnabled == true {
            self.safariExtensionStatusError = nil
            self.safariExtensionState = self.safariHeartbeatIsFresh ? .connected : .enabledWaitingForHeartbeat
          } else {
            self.safariExtensionStatusError = nil
            self.safariExtensionState = .disabled
          }
          self.saveSnapshot(lastError: self.lastError)
          self.updateStatusMessage()
        }
      }
      return
    }

    safariExtensionStatusError = nil
    safariExtensionState = safariExtensionAcknowledged
      ? (safariHeartbeatIsFresh ? .connected : .enabledWaitingForHeartbeat)
      : .unavailable
  }

  private func resolvedSafariState(from storedState: IOSSafariExtensionState) -> IOSSafariExtensionState {
    switch storedState {
    case .connected:
      return safariHeartbeatIsFresh ? .connected : .enabledWaitingForHeartbeat
    case .enabledWaitingForHeartbeat, .unavailable:
      return safariExtensionAcknowledged && safariHeartbeatIsFresh ? .connected : storedState
    case .unknown, .disabled, .failed:
      return storedState
    }
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
    var snapshot = IOSEnforcementSnapshot(
      mode: enforcementMode,
      authorizationMode: authorizationMode,
      shieldingEnabled: shieldingEnabled,
      dailyLimitMinutes: dailyLimitMinutes,
      adultWebFilterEnabled: enforcementMode == .strict && shieldingEnabled,
      safariExtensionEnabled: safariExtensionConnected || safariExtensionAcknowledged,
      selectedApplicationCount: selection.applicationTokens.count,
      selectedCategoryCount: selection.categoryTokens.count,
      selectedWebDomainCount: selection.webDomainTokens.count,
      scheduleActive: scheduleActive,
      lastAppliedAt: Date(),
      lastError: lastError
    )
    snapshot.safariExtensionState = safariExtensionState
    snapshot.lastSafariExtensionSeenAt = lastSafariExtensionSeenAt
    snapshot.lastSafariPolicyAppliedAt = lastSafariPolicyAppliedAt
    snapshot.lastSetupCheckAt = lastSetupCheckAt
    if let previousMode = IOSEnforcementSharedStore.loadSnapshot().lastSafariPolicyMode {
      snapshot.lastSafariPolicyMode = previousMode
    }
    IOSEnforcementSharedStore.saveSnapshot(snapshot)
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
  private static let safariExtensionBundleIdentifier = "com.yourtortoise.Tortoise.SafariExtension"
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
