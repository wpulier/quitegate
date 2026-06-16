import Foundation
@testable import QuietGate

final class MemorySecretStore: SecretStoring {
  var secret: String?

  init(secret: String? = nil) {
    self.secret = secret
  }

  func readSecret() throws -> String? {
    secret
  }

  func saveSecret(_ value: String) throws {
    secret = value
  }

  func deleteSecret() throws {
    secret = nil
  }
}

final class LockedSecretStore: SecretStoring {
  var readCount = 0
  var savedSecret: String?
  var interactiveSecret: String?

  func readSecret() throws -> String? {
    readCount += 1
    throw KeychainError.unavailableWithoutUserInteraction
  }

  func readSecret(allowUserInteraction: Bool) throws -> String? {
    if allowUserInteraction, let interactiveSecret {
      return interactiveSecret
    }
    return try readSecret()
  }

  func hasSecret() -> Bool {
    true
  }

  func saveSecret(_ value: String) throws {
    savedSecret = value
  }

  func deleteSecret() throws {
    savedSecret = nil
  }
}

final class FakeLegacyProviderService: LegacyProviderServicing {
  var parentalControl: ParentalControl
  var denylist: [LegacyProviderRuleItem]
  var addedDomains: [String] = []
  var removedDomains: [String] = []
  var getCount = 0
  var getDenylistCount = 0
  var patchCount = 0
  var getError: Error?
  var getDenylistError: Error?
  var patchError: Error?
  var addError: Error?
  var removeError: Error?
  var blockedLogsError: Error?
  var analyticsError: Error?
  var confirmsAddedDomains = true
  var confirmsRemovedDomains = true

  init(parentalControl: ParentalControl, denylist: [LegacyProviderRuleItem] = []) {
    self.parentalControl = parentalControl
    self.denylist = denylist
  }

  func getParentalControl(profileID: String) async throws -> ParentalControl {
    getCount += 1
    if let getError {
      throw getError
    }
    return parentalControl
  }

  func patchParentalControl(profileID: String, value: ParentalControl) async throws -> ParentalControl {
    if let patchError {
      throw patchError
    }
    patchCount += 1
    parentalControl = value
    return value
  }

  func getDenylist(profileID: String) async throws -> [LegacyProviderRuleItem] {
    getDenylistCount += 1
    if let getDenylistError {
      throw getDenylistError
    }
    return denylist
  }

  func addDenylist(profileID: String, domain: String) async throws -> LegacyProviderRuleItem {
    if let addError {
      throw addError
    }
    addedDomains.append(domain)
    let item = LegacyProviderRuleItem(id: domain, active: true)
    if confirmsAddedDomains {
      if let index = denylist.firstIndex(where: { $0.id.caseInsensitiveCompare(domain) == .orderedSame }) {
        denylist[index] = item
      } else {
        denylist.append(item)
        denylist.sort { $0.id < $1.id }
      }
    }
    return item
  }

  func removeDenylist(profileID: String, domain: String) async throws {
    if let removeError {
      throw removeError
    }
    removedDomains.append(domain)
    if confirmsRemovedDomains {
      denylist.removeAll { $0.id.caseInsensitiveCompare(domain) == .orderedSame }
    }
  }

  func blockedLogs(profileID: String, limit: Int) async throws -> [LegacyProviderLogEntry] {
    if let blockedLogsError {
      throw blockedLogsError
    }
    return []
  }

  func analyticsStatus(profileID: String) async throws -> [LegacyProviderAnalyticsStatus] {
    if let analyticsError {
      throw analyticsError
    }
    return []
  }
}

final class FakeResolverStatusService: ResolverStatusChecking {
  let status: LegacyProviderResolverStatus
  private(set) var checkCount = 0

  init(
    status: LegacyProviderResolverStatus = LegacyProviderResolverStatus(
      status: "ok",
      profile: "abc123",
      client: nil,
      clientName: nil,
      protocolName: nil
    )
  ) {
    self.status = status
  }

  func check() async throws -> LegacyProviderResolverStatus {
    checkCount += 1
    return status
  }
}

final class FakeDomainResolver: DomainResolutionChecking {
  var addressesByDomain: [String: [String]] = [:]
  var checkedDomains: [String] = []

  func addresses(for domain: String) async -> [String] {
    checkedDomains.append(domain)
    return addressesByDomain[domain] ?? []
  }
}

final class FakePlatformControlsChecker: PlatformControlsChecking {
  var delayNanoseconds: UInt64 = 0
  private(set) var snapshotCount = 0

  func snapshot(
    browserSnapshot: ChromeHelperSnapshot?,
    quietGateTunersReady: Bool,
    now: Date
  ) async -> BuiltInProtectionsSnapshot {
    snapshotCount += 1
    if delayNanoseconds > 0 {
      try? await Task.sleep(nanoseconds: delayNanoseconds)
    }
    return BuiltInProtectionsSnapshot(
      checkedAt: now,
      items: [
        PlatformControlItem(
          id: .quietGateTuners,
          title: "QuietGate tuner",
          detail: quietGateTunersReady ? "Ready" : "Not ready",
          state: quietGateTunersReady ? .enabled : .needsAction,
          actionTitle: nil,
          actionURLString: nil,
          checkedAt: now
        )
      ]
    )
  }
}

final class FakeSystemProfileChecker: SystemProfileChecking {
  var status: SystemLegacyProviderProfileStatus
  private(set) var checkCount = 0

  init(
    installed: Bool = false,
    configuredProfileInstalled: Bool? = nil
  ) {
    status = SystemLegacyProviderProfileStatus(
      anyLegacyProviderProfileInstalled: installed,
      configuredLegacyProviderProfileInstalled: configuredProfileInstalled ?? installed
    )
  }

  func legacyProviderProfileStatus(profileID: String) -> SystemLegacyProviderProfileStatus {
    checkCount += 1
    return status
  }
}

final class FakeLocalHostsScriptGenerator: LocalHostsBlockerScriptGenerating {
  let url = URL(fileURLWithPath: "/tmp/QuietGate Local Hosts Blocker.command")
  var domains: [String] = []
  var installedDomains: [String] = []
  var installCount = 0
  var installed = false
  var removed = false

  func writeScript(domains: [String]) throws -> URL {
    self.domains = domains
    return url
  }

  func installBlocklist(domains: [String]) throws {
    installCount += 1
    installedDomains = domains
    installed = true
  }

  func removeBlocklist() throws {
    installed = false
    removed = true
  }

  func localHostsBlocklistInstalled() -> Bool {
    installed
  }

  func localHostsBlocklistMatches(domains: [String]) -> Bool {
    installed && Set(installedDomains) == Set(domains)
  }
}

final class FakeBrowserExtensionBridge: BrowserExtensionBridging {
  let chromeExtensionDirectoryURL = URL(fileURLWithPath: "/tmp/ChromeExtension", isDirectory: true)
  let settingsURL = URL(fileURLWithPath: "/tmp/quietgate-test-extension-settings.json")
  let chromeStatusURL = URL(fileURLWithPath: "/tmp/quietgate-test-chrome-status.json")
  let installedNativeHostURL = URL(fileURLWithPath: "/tmp/quietgate-native-host")
  let nativeMessagingManifestURL = URL(fileURLWithPath: "/tmp/com.willpulier.quietgate.json")
  var writtenSettings: [BrowserTuningSettings] = []
  var installedHostCount = 0
  var installed = false
  var installedBrowsers: Set<BrowserConnectorID> = []
  var helperSnapshot: ChromeHelperSnapshot?
  var helperSnapshots: [BrowserConnectorID: ChromeHelperSnapshot] = [:]
  var helperState: ChromeHelperState?
  var helperStates: [BrowserConnectorID: ChromeHelperState] = [:]
  var extensionAvailable = true
  var extensionLoaded = false
  var extensionLoadedBrowsers: Set<BrowserConnectorID> = []
  var extensionStatus: ChromeExtensionStatus?
  var extensionStatuses: [BrowserConnectorID: ChromeExtensionStatus] = [:]
  var statusWatchURLs: [BrowserConnectorID: [URL]] = [:]

  func extensionDirectoryURL(for browser: BrowserConnectorID) -> URL {
    if browser == .firefox {
      return URL(fileURLWithPath: "/tmp/FirefoxExtension", isDirectory: true)
    }
    return chromeExtensionDirectoryURL
  }

  func writeSettings(_ settings: BrowserTuningSettings) throws {
    writtenSettings.append(settings)
  }

  func chromeExtensionAvailable() -> Bool {
    extensionAvailable(for: .chrome)
  }

  func extensionAvailable(for browser: BrowserConnectorID) -> Bool {
    extensionAvailable && browser.isSupportedToday
  }

  func chromeExtensionLoaded() -> Bool {
    extensionLoaded(for: .chrome)
  }

  func extensionLoaded(for browser: BrowserConnectorID) -> Bool {
    extensionStatus(for: browser).ready
  }

  func chromeExtensionStatus() -> ChromeExtensionStatus {
    extensionStatus(for: .chrome)
  }

  func extensionStatus(for browser: BrowserConnectorID) -> ChromeExtensionStatus {
    if let status = extensionStatuses[browser] {
      return status
    }
    if let extensionStatus {
      return extensionStatus
    }

    let loaded = extensionLoaded || extensionLoadedBrowsers.contains(browser)
    return ChromeExtensionStatus(
      selectedProfile: loaded ? "Default" : nil,
      profileCount: loaded ? 1 : 0,
      loadedProfiles: loaded ? ["Default"] : [],
      disabledProfiles: [],
      sessionProfiles: []
    )
  }

  func installNativeMessagingHost() throws {
    try installNativeMessagingHost(for: .chrome)
  }

  func installNativeMessagingHost(for browser: BrowserConnectorID) throws {
    installedHostCount += 1
    installed = true
    installedBrowsers.insert(browser)
  }

  func nativeMessagingHostInstalled() -> Bool {
    nativeMessagingHostInstalled(for: .chrome)
  }

  func nativeMessagingHostInstalled(for browser: BrowserConnectorID) -> Bool {
    installed || installedBrowsers.contains(browser)
  }

  func chromeHelperSnapshot() -> ChromeHelperSnapshot? {
    helperSnapshot(for: .chrome)
  }

  func helperSnapshot(for browser: BrowserConnectorID) -> ChromeHelperSnapshot? {
    helperSnapshots[browser] ?? helperSnapshot
  }

  func chromeHelperState(currentSettingsVersion: String, now: Date) -> ChromeHelperState {
    helperState(for: .chrome, currentSettingsVersion: currentSettingsVersion, now: now)
  }

  func helperState(
    for browser: BrowserConnectorID,
    currentSettingsVersion: String,
    now: Date
  ) -> ChromeHelperState {
    helperState(
      for: browser,
      currentSettingsVersion: currentSettingsVersion,
      now: now,
      extensionStatus: extensionStatus(for: browser)
    )
  }

  func helperState(
    for browser: BrowserConnectorID,
    currentSettingsVersion: String,
    now: Date,
    extensionStatus: ChromeExtensionStatus
  ) -> ChromeHelperState {
    if let state = helperStates[browser] {
      return state
    }
    if let helperState {
      return helperState
    }
    guard nativeMessagingHostInstalled(for: browser) else {
      return extensionStatus.ready ? .nativeHostMissing : .notInstalled
    }
    guard let helperSnapshot = helperSnapshot(for: browser) else {
      return extensionStatus.ready ? .needsChromeOpen : .notInstalled
    }
    if helperSnapshot.lastAppliedSettingsVersion == currentSettingsVersion {
      return .current
    }
    return .needsSync
  }

  func nativeMessagingManifestURL(for browser: BrowserConnectorID) -> URL {
    URL(fileURLWithPath: "/tmp/com.willpulier.quietgate.\(browser.rawValue).json")
  }

  func statusWatchURLs(for browser: BrowserConnectorID) -> [URL] {
    statusWatchURLs[browser] ?? [
      URL(fileURLWithPath: "/tmp/quietgate-\(browser.rawValue)-status.json")
    ]
  }
}

@MainActor
final class ManualBrowserStatusMonitor: BrowserStatusMonitoring {
  private(set) var started = false
  private(set) var stopped = false
  private(set) var latestWatchURLs: [URL] = []
  private var watchURLsProvider: (() -> [URL])?
  private var onChange: (() -> Void)?

  func start(
    watchURLsProvider: @escaping () -> [URL],
    onChange: @escaping () -> Void
  ) {
    started = true
    stopped = false
    self.watchURLsProvider = watchURLsProvider
    self.onChange = onChange
    latestWatchURLs = watchURLsProvider()
  }

  func stop() {
    stopped = true
    watchURLsProvider = nil
    onChange = nil
  }

  func refreshWatchURLs() {
    latestWatchURLs = watchURLsProvider?() ?? []
  }

  func triggerChange() {
    onChange?()
    refreshWatchURLs()
  }

  func triggerAppActivation() {
    triggerChange()
  }
}

final class FakeAppUpdateService: AppUpdateServicing {
  var update: AppUpdateInfo?
  var relaunchedUpdates: [AppUpdateInfo] = []
  var relaunchError: Error?

  func availableUpdate() -> AppUpdateInfo? {
    update
  }

  func relaunch(using update: AppUpdateInfo) async throws {
    if let relaunchError {
      throw relaunchError
    }
    relaunchedUpdates.append(update)
  }
}
