import Combine
import Foundation

@MainActor
final class AppBlockingStore: ObservableObject {
  @Published private(set) var blockedApplications: [BlockedApplicationRule]
  @Published private(set) var runningApplications: [RunningApplicationSnapshot] = []
  @Published private(set) var availableApplications: [RunningApplicationSnapshot] = []
  @Published private(set) var lastQuitResults: [ApplicationQuitResult] = []
  @Published private(set) var lastCheckedAt: Date?
  @Published private(set) var startupState: MacStartupState
  @Published private(set) var startupMessage: String?
  @Published private(set) var startupErrorMessage: String?
  @Published var enforcementEnabled: Bool {
    didSet {
      defaults.set(enforcementEnabled, forKey: DefaultsKey.enforcementEnabled)
      if enforcementEnabled {
        enforceNow()
      }
      updateLaunchMonitoring()
    }
  }

  private let defaults: UserDefaults
  private let service: ApplicationBlockingServicing
  private let loginItemService: LoginItemServicing
  private let nowProvider: () -> Date
  private var monitoringRequested = false
  private var launchObserver: AnyCancellable?

  private enum DefaultsKey {
    static let blockedApplications = "quietgate.blockedApplications"
    static let enforcementEnabled = "quietgate.appBlockingEnabled"
  }

  init(
    defaults: UserDefaults = .standard,
    service: ApplicationBlockingServicing = MacApplicationBlockingService(),
    loginItemService: LoginItemServicing = MacLoginItemService(),
    nowProvider: @escaping () -> Date = Date.init
  ) {
    self.defaults = defaults
    self.service = service
    self.loginItemService = loginItemService
    self.nowProvider = nowProvider
    blockedApplications = Self.loadBlockedApplications(from: defaults)
    enforcementEnabled =
      defaults.object(forKey: DefaultsKey.enforcementEnabled) as? Bool ?? true
    startupState = loginItemService.state
  }

  deinit {
    launchObserver?.cancel()
  }

  var activeBlockedApplications: [BlockedApplicationRule] {
    localMacBlockingProvider.activeBlockedApplications
  }

  var runningBlockedApplications: [RunningApplicationSnapshot] {
    localMacBlockingProvider.runningBlockedApplications
  }

  var statusSummary: String {
    localMacBlockingProvider.statusSummary
  }

  var startupStatusSummary: String {
    startupState.detail
  }

  var providerSnapshot: BlockingProviderSnapshot {
    localMacBlockingProvider.providerSnapshot
  }

  func startMonitoring(interval: TimeInterval = 5) {
    guard !monitoringRequested else {
      return
    }

    monitoringRequested = true
    if enforcementEnabled, !activeBlockedApplications.isEmpty {
      enforceNow()
    }
    updateLaunchMonitoring()
  }

  func stopMonitoring() {
    monitoringRequested = false
    launchObserver?.cancel()
    launchObserver = nil
  }

  func refreshRunningApplications() {
    runningApplications = service.runningApplications()
    lastCheckedAt = nowProvider()
  }

  func refreshAvailableApplications() {
    let installed = service.installedApplications()
    let running = service.runningApplications()
    runningApplications = running
    availableApplications = Self.sortedUniqueApplications(installed + running)
    refreshStartupState()
    lastCheckedAt = nowProvider()
  }

  func refreshStartupState() {
    startupState = loginItemService.state
  }

  func setStartAtLoginEnabled(_ enabled: Bool) {
    do {
      try loginItemService.setEnabled(enabled)
      refreshStartupState()
      startupErrorMessage = nil
      if case .needsApproval = startupState {
        startupMessage = "Approve QuietGate in System Settings > General > Login Items."
      } else {
        startupMessage = enabled
          ? "QuietGate will start when you sign in."
          : "QuietGate will not start automatically."
      }
    } catch {
      refreshStartupState()
      startupMessage = nil
      startupErrorMessage = error.localizedDescription
    }
  }

  func addBlockedApplication(_ app: RunningApplicationSnapshot) {
    if let index = blockedApplications.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
      blockedApplications[index].displayName = app.displayName
      blockedApplications[index].isEnabled = true
    } else {
      blockedApplications.append(
        BlockedApplicationRule(
          bundleIdentifier: app.bundleIdentifier,
          displayName: app.displayName,
          addedAt: nowProvider()
        )
      )
      sortBlockedApplications()
    }
    persistBlockedApplications()
    enforceNow()
    updateLaunchMonitoring()
  }

  func setBlockedApplication(_ bundleIdentifier: String, enabled: Bool) {
    guard let index = blockedApplications.firstIndex(where: { $0.bundleIdentifier == bundleIdentifier })
    else {
      return
    }
    blockedApplications[index].isEnabled = enabled
    persistBlockedApplications()
    if enabled {
      enforceNow()
    }
    updateLaunchMonitoring()
  }

  func removeBlockedApplication(_ bundleIdentifier: String) {
    blockedApplications.removeAll { $0.bundleIdentifier == bundleIdentifier }
    persistBlockedApplications()
    refreshRunningApplications()
    updateLaunchMonitoring()
  }

  @discardableResult
  func enforceNow() -> [ApplicationQuitResult] {
    refreshRunningApplications()
    guard enforcementEnabled else {
      lastQuitResults = []
      return []
    }

    let blockedIDs = Set(activeBlockedApplications.map(\.bundleIdentifier))
    let runningBlockedIDs = Set(
      runningApplications
        .map(\.bundleIdentifier)
        .filter { blockedIDs.contains($0) }
    )

    guard !runningBlockedIDs.isEmpty else {
      lastQuitResults = []
      return []
    }

    lastQuitResults = service.quitApplications(bundleIdentifiers: runningBlockedIDs)
    refreshRunningApplications()
    return lastQuitResults
  }

  private func sortBlockedApplications() {
    blockedApplications.sort {
      $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
    }
  }

  private var localMacBlockingProvider: LocalMacBlockingProvider {
    LocalMacBlockingProvider(
      blockedApplications: blockedApplications,
      runningApplications: runningApplications,
      enforcementEnabled: enforcementEnabled,
      startupState: startupState
    )
  }

  private func persistBlockedApplications() {
    if let data = try? JSONEncoder().encode(blockedApplications) {
      defaults.set(data, forKey: DefaultsKey.blockedApplications)
    }
  }

  private func updateLaunchMonitoring() {
    guard monitoringRequested, enforcementEnabled, !activeBlockedApplications.isEmpty else {
      launchObserver?.cancel()
      launchObserver = nil
      return
    }

    guard launchObserver == nil else {
      return
    }

    launchObserver = service.observeApplicationLaunches { [weak self] in
      Task { @MainActor in
        self?.enforceNow()
      }
    }
  }

  private static func loadBlockedApplications(
    from defaults: UserDefaults
  ) -> [BlockedApplicationRule] {
    guard let data = defaults.data(forKey: DefaultsKey.blockedApplications),
          let rules = try? JSONDecoder().decode([BlockedApplicationRule].self, from: data)
    else {
      return []
    }
    return rules.sorted {
      $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
    }
  }

  private static func sortedUniqueApplications(
    _ apps: [RunningApplicationSnapshot]
  ) -> [RunningApplicationSnapshot] {
    var seen: Set<String> = []
    var unique: [RunningApplicationSnapshot] = []
    for app in apps {
      guard !seen.contains(app.bundleIdentifier) else {
        continue
      }
      seen.insert(app.bundleIdentifier)
      unique.append(app)
    }
    return unique.sorted {
      $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
    }
  }
}
