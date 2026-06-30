import FamilyControls
import Foundation
import ManagedSettings

@MainActor
final class IOSYouTubeScreenTimeController: ObservableObject {
  @Published var selection: FamilyActivitySelection {
    didSet {
      persistState()
      applyShielding()
    }
  }
  @Published var shieldingEnabled: Bool {
    didSet {
      persistState()
      applyShielding()
    }
  }
  @Published private(set) var authorizationState: IOSScreenTimeAuthorizationState = .notDetermined
  @Published private(set) var statusMessage: String = "Choose the YouTube app and youtube.com in Safari."

  private let managedSettingsStore = ManagedSettingsStore(named: .tortoiseYouTube)

  init() {
    let state = Self.loadState()
    selection = state.selection
    shieldingEnabled = state.shieldingEnabled
    refreshAuthorizationState()
    applyShielding()
  }

  var hasSelection: Bool {
    !selection.applicationTokens.isEmpty || !selection.webDomainTokens.isEmpty
  }

  var coverageSummary: String {
    if !hasSelection {
      return "No iOS YouTube targets selected"
    }

    let appText = "\(selection.applicationTokens.count) app\(selection.applicationTokens.count == 1 ? "" : "s")"
    let domainText = "\(selection.webDomainTokens.count) Safari domain\(selection.webDomainTokens.count == 1 ? "" : "s")"
    return "\(appText) · \(domainText)"
  }

  var canApplyShielding: Bool {
    authorizationState == .approved && hasSelection
  }

  func refreshAuthorizationState() {
    switch AuthorizationCenter.shared.authorizationStatus {
    case .notDetermined:
      authorizationState = .notDetermined
    case .denied:
      authorizationState = .denied
    case .approved:
      authorizationState = .approved
    @unknown default:
      authorizationState = .unknown
    }
    updateStatusMessage()
  }

  func requestAuthorization() async {
    do {
      try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
      refreshAuthorizationState()
    } catch {
      authorizationState = .denied
      statusMessage = "Screen Time permission failed. Check the Family Controls entitlement before shipping."
    }
    applyShielding()
  }

  func clearSelection() {
    selection = FamilyActivitySelection()
    shieldingEnabled = false
  }

  private func applyShielding() {
    guard canApplyShielding, shieldingEnabled else {
      managedSettingsStore.shield.applications = nil
      managedSettingsStore.shield.webDomains = nil
      updateStatusMessage()
      return
    }

    managedSettingsStore.shield.applications = selection.applicationTokens.isEmpty
      ? nil
      : selection.applicationTokens
    managedSettingsStore.shield.webDomains = selection.webDomainTokens.isEmpty
      ? nil
      : selection.webDomainTokens
    updateStatusMessage()
  }

  private func updateStatusMessage() {
    switch authorizationState {
    case .approved where shieldingEnabled && hasSelection:
      statusMessage = "Blocking selected YouTube app and Safari targets on this iPhone."
    case .approved where hasSelection:
      statusMessage = "Ready. Turn on iOS blocking when you want the selected targets shielded."
    case .approved:
      statusMessage = "Screen Time is approved. Select YouTube app and youtube.com next."
    case .denied:
      statusMessage = "Screen Time permission is not approved for QuietGate."
    case .notDetermined:
      statusMessage = "Allow Screen Time, then select YouTube app and youtube.com."
    case .unknown:
      statusMessage = "Screen Time permission status is unavailable."
    }
  }

  private func persistState() {
    let state = PersistedState(selection: selection, shieldingEnabled: shieldingEnabled)
    guard let data = try? JSONEncoder().encode(state) else {
      return
    }
    UserDefaults.standard.set(data, forKey: Self.stateKey)
  }

  private static func loadState() -> PersistedState {
    guard let data = UserDefaults.standard.data(forKey: stateKey),
          let state = try? JSONDecoder().decode(PersistedState.self, from: data) else {
      return PersistedState(selection: FamilyActivitySelection(), shieldingEnabled: false)
    }
    return state
  }

  private static let stateKey = "TortoiseYouTubeScreenTimeState"
}

enum IOSScreenTimeAuthorizationState: Equatable {
  case notDetermined
  case denied
  case approved
  case unknown

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

private struct PersistedState: Codable {
  let selection: FamilyActivitySelection
  let shieldingEnabled: Bool
}

private extension ManagedSettingsStore.Name {
  static let tortoiseYouTube = Self("tortoise.youtube")
}
