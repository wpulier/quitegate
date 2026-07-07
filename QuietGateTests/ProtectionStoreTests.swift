import AppKit
import Foundation
import XCTest

@testable import QuietGate

@MainActor
final class ProtectionStoreTests: XCTestCase {
  private var isolatedHostsURL: URL?

  override func setUp() {
    super.setUp()
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("QuietGateTests-hosts-\(UUID().uuidString)")
    FileManager.default.createFile(atPath: url.path, contents: Data(), attributes: nil)
    setenv("QG_HOSTS_PATH", url.path, 1)
    isolatedHostsURL = url
  }

  override func tearDown() {
    if let isolatedHostsURL {
      try? FileManager.default.removeItem(at: isolatedHostsURL)
    }
    isolatedHostsURL = nil
    unsetenv("QG_HOSTS_PATH")
    super.tearDown()
  }

  func testPublicNavigationDoesNotExposeLegacyHistoryOrDNSSetup() {
    XCTAssertEqual(AppSection.allCases, [.devices, .tuning, .blocking, .usage])
    XCTAssertEqual(AppSection.allCases.map(\.title), ["Devices", "Tune", "Block", "Usage"])
    XCTAssertFalse(AppSection.allCases.map(\.title).contains("History"))
    XCTAssertFalse(AppSection.allCases.map(\.title).contains("Activity"))
  }

  func testReadinessActionLabelsAvoidManualCheckAndAccountCopy() {
    let labels = [
      ReadinessAction.refreshProtectionStatus.title,
      ReadinessAction.checkThisMac.title,
    ]

    XCTAssertFalse(labels.contains("Check Again"))
    XCTAssertFalse(labels.contains("Open Account Page"))
    XCTAssertFalse(labels.contains { $0.contains("DNS") })
    XCTAssertFalse(labels.contains { $0.contains("API") })
  }

  func testAppUpdateButtonStateAppearsOnlyWhenInstalledUpdateExists() async {
    let appUpdateService = FakeAppUpdateService()
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      extensionBridge: FakeBrowserExtensionBridge(),
      appUpdateService: appUpdateService,
      browserInstallationChecker: installedBrowsers([.chrome])
    )

    store.refreshAppUpdateStatus()

    XCTAssertFalse(store.appUpdateAvailable)
    XCTAssertEqual(store.appUpdateDetail, "Tortoise is up to date.")

    let update = AppUpdateInfo(
      currentVersion: AppVersionIdentifier(version: "1.0", build: "1"),
      installedVersion: AppVersionIdentifier(version: "1.0", build: "2"),
      installedAppURL: URL(fileURLWithPath: "/Applications/QuietGate.app")
    )
    appUpdateService.update = update
    store.refreshAppUpdateStatus()

    XCTAssertTrue(store.appUpdateAvailable)
    XCTAssertEqual(store.appUpdateDetail, "Tortoise 1.0 (2) is installed. Relaunch to use it.")

    await store.performInstalledAppUpdate()

    XCTAssertEqual(appUpdateService.relaunchedUpdates, [update])
  }

  func testBuiltInProtectionRefreshCoalescesConcurrentRequests() async {
    let platformChecker = FakePlatformControlsChecker()
    platformChecker.delayNanoseconds = 50_000_000
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      extensionBridge: FakeBrowserExtensionBridge(),
      platformControlsChecker: platformChecker,
      browserInstallationChecker: installedBrowsers([.chrome])
    )

    async let first: Void = store.refreshBuiltInProtections()
    async let second: Void = store.refreshBuiltInProtections()
    _ = await (first, second)

    XCTAssertEqual(platformChecker.snapshotCount, 1)
    XCTAssertEqual(store.builtInProtectionsSnapshot.items.map(\.id), [.quietGateTuners])
  }

  func testBrowserFirstDefaultRequiresChromeInsteadOfNextDNSSetup() {
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge(),
      browserInstallationChecker: installedBrowsers([.chrome])
    )

    XCTAssertFalse(store.legacyProviderConnectorEnabled)
    XCTAssertFalse(store.blockingControlsReady)
    XCTAssertFalse(store.blockRuleEditingReady)
    XCTAssertEqual(
      store.blockingCapabilityUnavailableReason,
      "Connect Chrome before using Home controls."
    )
    XCTAssertTrue(store.readinessChecks(scope: .blocker).isEmpty)
    XCTAssertEqual(
      store.settingsStatusSummary,
      "Connect a browser to finish setup for browser blocking and site tuning."
    )
  }

  func testBrowserFirstReadinessUsesBrowserConnectorLanguage() {
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      extensionBridge: FakeBrowserExtensionBridge(),
      browserInstallationChecker: installedBrowsers([.edge])
    )

    let checks = store.readinessChecks(scope: .tuner)
    let renderedText = checks
      .flatMap { [$0.title, $0.detail, $0.action?.title ?? ""] }
      .joined(separator: " ")

    XCTAssertEqual(checks.map(\.id), [.browserConnection, .browserSettings])
    XCTAssertEqual(checks.first?.title, "Edge")
    XCTAssertEqual(checks.first?.action, .launchBrowserTunerSession(.edge))
    XCTAssertFalse(renderedText.localizedCaseInsensitiveContains("nextdns"))
    XCTAssertFalse(renderedText.localizedCaseInsensitiveContains("dns"))
    XCTAssertFalse(renderedText.localizedCaseInsensitiveContains("api"))
    XCTAssertFalse(renderedText.localizedCaseInsensitiveContains("profile id"))
  }

  func testBrowserFirstUnlocksBlockingControlsWhenChromeIsConnected() {
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge(),
      browserInstallationChecker: installedBrowsers([.chrome])
    )

    markChromeConnected(store)

    XCTAssertTrue(store.blockingControlsReady)
    XCTAssertTrue(store.blockRuleEditingReady)
    XCTAssertNil(store.blockingCapabilityUnavailableReason)
    XCTAssertEqual(
      store.settingsStatusSummary,
      "Tortoise is ready. Chrome profile: Default connected for browser blocking and tuning."
    )
  }

  func testBrowserFirstTrustsFreshChromeHeartbeatBeforePreferencesFlush() {
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge,
      browserInstallationChecker: installedBrowsers([.chrome])
    )
    bridge.installedBrowsers.insert(.chrome)
    bridge.helperSnapshots[.chrome] = ChromeHelperSnapshot(
      extensionID: BrowserExtensionBridge.chromiumExtensionID,
      lastSeenAt: Date(),
      lastAppliedSettingsVersion: store.currentBrowserSettingsVersion,
      extensionVersion: "0.1.0",
      blockedRuleCount: 0
    )

    store.refreshChromeExtensionStatus()

    XCTAssertFalse(store.chromeExtensionLoaded)
    XCTAssertEqual(store.chromeHelperState, .current)
    XCTAssertTrue(store.blockingControlsReady)
    XCTAssertTrue(store.primaryBrowserConnector.isConnected)
    XCTAssertEqual(
      store.settingsStatusSummary,
      "Tortoise is ready. Chrome connected for browser blocking and tuning."
    )
  }

  func testBrowserFirstDoesNotRelockControlsWhileConnectedBrowserCatchesUp() {
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge,
      browserInstallationChecker: installedBrowsers([.chrome])
    )
    let status = ChromeExtensionStatus(
      selectedProfile: "Default",
      profileCount: 1,
      loadedProfiles: ["Default"],
      disabledProfiles: [],
      sessionProfiles: []
    )
    bridge.extensionStatuses[.chrome] = status
    bridge.installedBrowsers.insert(.chrome)
    bridge.helperStates[.chrome] = .needsSync
    store.refreshChromeExtensionStatus()

    XCTAssertTrue(store.blockingControlsReady)
    XCTAssertNil(store.blockingCapabilityUnavailableReason)
    XCTAssertTrue(store.primaryBrowserConnector.isConnected)
    XCTAssertEqual(
      store.primaryBrowserConnector.state,
      .connectedPending(
        "Chrome is connected in Default. Tortoise is updating it with the latest settings."
      )
    )
    XCTAssertEqual(store.primaryBrowserConnector.nextAction, .applyBrowserChanges(.chrome))
    XCTAssertTrue(store.browserSettingsApplyNeeded)
  }

  func testBrowserFirstRoutesOlderExtensionToExtensionsPage() {
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge,
      browserInstallationChecker: installedBrowsers([.chrome])
    )
    bridge.extensionStatuses[.chrome] = ChromeExtensionStatus(
      selectedProfile: "Default",
      profileCount: 1,
      loadedProfiles: ["Default"],
      disabledProfiles: [],
      sessionProfiles: []
    )
    bridge.installedBrowsers.insert(.chrome)
    bridge.helperStates[.chrome] = .extensionNeedsReload
    store.refreshChromeExtensionStatus()

    XCTAssertTrue(store.primaryBrowserConnector.isConnected)
    XCTAssertEqual(
      store.primaryBrowserConnector.state,
      .connectedPending(
        "Chrome has an older Tortoise extension loaded. Open Extensions, reload Tortoise, then refresh the affected site."
      )
    )
    XCTAssertEqual(store.primaryBrowserConnector.nextAction, .openBrowserExtensionsPage(.chrome))
  }

  func testBrowserFirstSettingsSaveMarksBrowserPendingUntilConfirmed() async {
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge,
      browserInstallationChecker: installedBrowsers([.chrome])
    )
    bridge.installedBrowsers.insert(.chrome)
    bridge.extensionStatuses[.chrome] = ChromeExtensionStatus(
      selectedProfile: "Default",
      profileCount: 1,
      loadedProfiles: ["Default"],
      disabledProfiles: [],
      sessionProfiles: []
    )
    bridge.helperSnapshots[.chrome] = ChromeHelperSnapshot(
      extensionID: BrowserExtensionBridge.chromiumExtensionID,
      lastSeenAt: Date(),
      lastAppliedSettingsVersion: store.currentBrowserSettingsVersion,
      extensionVersion: "0.1.0",
      blockedRuleCount: 0
    )
    store.refreshChromeExtensionStatus()
    XCTAssertTrue(store.primaryBrowserConnector.isCurrent)

    await store.setAccessMode(.strict)

    XCTAssertEqual(bridge.writtenSettings.last?.mode, .strict)
    XCTAssertEqual(store.primaryBrowserConnector.state, .connectedPending(
      "Chrome is connected in Default. Tortoise is updating it with the latest settings."
    ))
    XCTAssertEqual(store.primaryBrowserConnector.nextAction, .applyBrowserChanges(.chrome))
    XCTAssertTrue(store.browserSettingsApplyNeeded)
  }

  func testBrowserProfileScopeUsesFriendlyProfileName() {
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge,
      browserInstallationChecker: installedBrowsers([.chrome])
    )
    let status = ChromeExtensionStatus(
      selectedProfile: "Profile 1",
      profileCount: 1,
      loadedProfiles: ["Profile 1"],
      disabledProfiles: [],
      sessionProfiles: [],
      profileDisplayNames: ["Profile 1": "Work"]
    )
    bridge.extensionStatuses[.chrome] = status
    bridge.installedBrowsers.insert(.chrome)
    bridge.helperStates[.chrome] = .current
    store.refreshChromeExtensionStatus()

    XCTAssertEqual(store.primaryBrowserConnector.profileScopeText, "Chrome profile: Work (Profile 1)")
    XCTAssertEqual(store.connectedBrowserProfileScopeText, "Chrome profile: Work (Profile 1)")
    XCTAssertEqual(
      store.primaryBrowserConnector.state,
      .connected("Connected in the current Chrome profile (Work (Profile 1)).")
    )
    XCTAssertEqual(
      store.browserRuleProfileScopeDetail,
      "Website blocks and site tuning apply in Chrome profile: Work (Profile 1). Other browser profiles need their own Tortoise connection."
    )
  }

  func testBrowserFirstUnavailableReasonNamesKnownProfileWhenConnectionNeedsFinishing() {
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge,
      browserInstallationChecker: installedBrowsers([.chrome])
    )
    bridge.extensionStatuses[.chrome] = ChromeExtensionStatus(
      selectedProfile: "Profile 1",
      profileCount: 1,
      loadedProfiles: ["Profile 1"],
      disabledProfiles: [],
      sessionProfiles: [],
      profileDisplayNames: ["Profile 1": "Work"]
    )

    store.refreshChromeExtensionStatus()

    XCTAssertFalse(store.blockingControlsReady)
    XCTAssertEqual(store.primaryBrowserConnector.selectedProfileLabel, "Work (Profile 1)")
    XCTAssertEqual(store.primaryBrowserConnector.profileScopeText, "Chrome profile: Work (Profile 1)")
    XCTAssertEqual(
      store.primaryBrowserConnector.state,
      .actionNeeded(
        "Finish the small Chrome connection file so Chrome can receive Tortoise settings."
      )
    )
    XCTAssertEqual(store.primaryBrowserConnector.nextAction, .installChromeSync)
    XCTAssertEqual(
      store.blockingCapabilityUnavailableReason,
      "Finish the Chrome connection for Work (Profile 1) before using Home controls."
    )
  }

  func testBrowserStatusMonitorRefreshesProfilesFromWatchEvent() {
    let bridge = FakeBrowserExtensionBridge()
    let monitor = ManualBrowserStatusMonitor()
    let initialWatchURL = URL(fileURLWithPath: "/tmp/quietgate-initial-status.json")
    let refreshedWatchURL = URL(fileURLWithPath: "/tmp/quietgate-refreshed-status.json")
    bridge.statusWatchURLs[.chrome] = [initialWatchURL]
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge,
      browserInstallationChecker: installedBrowsers([.chrome]),
      browserStatusMonitor: monitor
    )

    XCTAssertTrue(monitor.started)
    XCTAssertTrue(monitor.latestWatchURLs.contains(initialWatchURL))
    XCTAssertNil(store.primaryBrowserConnector.profileScopeText)

    bridge.extensionStatuses[.chrome] = ChromeExtensionStatus(
      selectedProfile: "Profile 2",
      profileCount: 1,
      loadedProfiles: ["Profile 2"],
      disabledProfiles: [],
      sessionProfiles: [],
      profileDisplayNames: ["Profile 2": "Writing"]
    )
    bridge.statusWatchURLs[.chrome] = [refreshedWatchURL]
    monitor.triggerChange()

    XCTAssertEqual(store.primaryBrowserConnector.profileScopeText, "Chrome profile: Writing (Profile 2)")
    XCTAssertTrue(monitor.latestWatchURLs.contains(refreshedWatchURL))
  }

  func testBrowserStatusMonitorRefreshesOnAppActivation() {
    let bridge = FakeBrowserExtensionBridge()
    let monitor = ManualBrowserStatusMonitor()
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge,
      browserInstallationChecker: installedBrowsers([.chrome]),
      browserStatusMonitor: monitor
    )

    bridge.extensionStatuses[.chrome] = ChromeExtensionStatus(
      selectedProfile: "Default",
      profileCount: 1,
      loadedProfiles: ["Default"],
      disabledProfiles: [],
      sessionProfiles: [],
      profileDisplayNames: ["Default": "Will"]
    )
    monitor.triggerAppActivation()

    XCTAssertEqual(store.primaryBrowserConnector.profileScopeText, "Chrome profile: Will (Default)")
  }

  func testRecordedBrowserSessionStaysConnectedWithoutProcessArguments() {
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge,
      browserInstallationChecker: installedBrowsers([.chrome]),
      browserRunningChecker: { $0 == .chrome }
    )
    bridge.installedBrowsers.insert(.chrome)
    bridge.helperStates[.chrome] = .current
    bridge.extensionStatuses[.chrome] = ChromeExtensionStatus(
      selectedProfile: nil,
      profileCount: 0,
      loadedProfiles: [],
      disabledProfiles: [],
      sessionProfiles: []
    )

    store.noteLaunchedBrowserSession(.chrome, profile: "Profile 1")
    store.refreshChromeExtensionStatus()

    XCTAssertEqual(store.chromeExtensionStatus.selectedProfile, "Profile 1")
    XCTAssertEqual(store.chromeExtensionStatus.sessionProfiles, ["Profile 1"])
    XCTAssertTrue(store.chromeExtensionStatus.ready)
    XCTAssertEqual(
      store.primaryBrowserConnector.state,
      .connected(
        "Connected for this Chrome session in Profile 1. Add Tortoise to Chrome later if you want it to stay connected after restart."
      )
    )
  }

  func testBrowserProfileRegistrationWatchDetectsNewProfileAndStops() {
    let bridge = FakeBrowserExtensionBridge()
    let monitor = ManualBrowserStatusMonitor()
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge,
      browserInstallationChecker: installedBrowsers([.chrome]),
      browserStatusMonitor: monitor
    )
    bridge.extensionStatuses[.chrome] = ChromeExtensionStatus(
      selectedProfile: "Default",
      profileCount: 1,
      loadedProfiles: ["Default"],
      disabledProfiles: [],
      sessionProfiles: []
    )
    store.refreshChromeExtensionStatus()

    store.startBrowserProfileRegistrationWatch(for: .chrome)
    XCTAssertEqual(store.browserProfileWatchMessage, "Watching for a new Chrome profile...")
    XCTAssertEqual(store.browserProfileWatchBrowser, .chrome)

    bridge.extensionStatuses[.chrome] = ChromeExtensionStatus(
      selectedProfile: "Profile 2",
      profileCount: 2,
      loadedProfiles: ["Default", "Profile 2"],
      disabledProfiles: [],
      sessionProfiles: [],
      profileDisplayNames: ["Profile 2": "Work"]
    )
    monitor.triggerChange()

    XCTAssertNil(store.browserProfileWatchBrowser)
    XCTAssertEqual(
      store.browserProfileWatchMessage,
      "Chrome profiles: Default and Work (Profile 2) registered."
    )
  }

  func testBrowserProfileRegistrationWatchTimesOutWithRecoveryCopy() {
    var now = Date(timeIntervalSince1970: 0)
    let bridge = FakeBrowserExtensionBridge()
    let monitor = ManualBrowserStatusMonitor()
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge,
      browserInstallationChecker: installedBrowsers([.chrome]),
      browserStatusMonitor: monitor,
      nowProvider: { now }
    )

    store.startBrowserProfileRegistrationWatch(for: .chrome)
    now = Date(timeIntervalSince1970: 91)
    monitor.triggerChange()

    XCTAssertNil(store.browserProfileWatchBrowser)
    XCTAssertEqual(
      store.browserProfileWatchMessage,
      "Still waiting for Chrome to report the profile. Open the Tortoise extension in that profile or press Update Status."
    )
  }

  func testBrowserConnectionCheckNamesConnectedElsewhereProfiles() {
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge,
      browserInstallationChecker: installedBrowsers([.chrome])
    )
    bridge.extensionStatuses[.chrome] = ChromeExtensionStatus(
      selectedProfile: "Default",
      profileCount: 2,
      loadedProfiles: ["Profile 1"],
      disabledProfiles: [],
      sessionProfiles: [],
      profileDisplayNames: [
        "Default": "Personal",
        "Profile 1": "Work",
      ]
    )
    store.refreshChromeExtensionStatus()

    let browserCheck = store.readinessChecks(scope: .tuner)
      .first { $0.id == .browserConnection }

    XCTAssertEqual(
      browserCheck?.detail,
      "Chrome is connected in Work (Profile 1), but not in Personal (Default). Add it there too if you use that profile."
    )
  }

  func testBrowserFirstBlockingProvidersExposeBrowserDefaultWithoutMacPlaceholder() {
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge()
    )

    XCTAssertEqual(store.blockingProviders.map(\.id), [.browserHelpers])
    XCTAssertEqual(store.defaultBlockingProvider.id, .browserHelpers)
    XCTAssertFalse(store.defaultBlockingProvider.isReady)
    XCTAssertFalse(store.defaultBlockingProvider.isLegacy)
    XCTAssertEqual(store.defaultBlockingProvider.activeRuleCount, 0)
    XCTAssertEqual(store.defaultBlockingProvider.destinationNames, [])
  }

  func testBrowserFirstBlockingProviderCatalogUsesRealMacAppSnapshot() {
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge()
    )
    let appBlockingStore = AppBlockingStore(
      defaults: browserFirstDefaults(),
      loginItemService: TestLoginItemService(state: .enabled)
    )
    appBlockingStore.addBlockedApplication(
      RunningApplicationSnapshot(
        bundleIdentifier: "com.example.Distraction",
        displayName: "Distraction"
      )
    )

    let providers = store.blockingProviders(includingLocalMac: appBlockingStore.providerSnapshot)

    XCTAssertEqual(providers.map(\.id), [.browserHelpers, .localMac])
    XCTAssertEqual(providers.first?.id, .browserHelpers)
    XCTAssertEqual(providers.last?.title, "Tortoise Mac Blocker")
    XCTAssertEqual(providers.last?.activeRuleCount, 1)
    XCTAssertEqual(providers.last?.destinationNames, ["This Mac"])
    XCTAssertEqual(
      providers.last?.state,
      .ready("1 app will close when opened.")
    )
  }

  func testBrowserFirstDisabledSitesDoNotRunLegacyProviderConnectorOffProof() async throws {
    let resolver = FakeDomainResolver()
    resolver.addressesByDomain["x.com"] = ["0.0.0.0", "::"]
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge,
      domainResolver: resolver,
      browserInstallationChecker: installedBrowsers([.chrome])
    )
    markChromeConnected(store, bridge: bridge)

    try await store.addCustomDomain("x.com")
    await store.setBlockedSite("x.com", enabled: false)

    let site = try XCTUnwrap(store.blockedSites.first)
    XCTAssertEqual(resolver.checkedDomains, [])
    XCTAssertEqual(store.blockedSiteApplicationStatus(site).text, "Off in Tortoise")
    XCTAssertEqual(store.disabledSiteStillBlockedDomains, [])
    XCTAssertNil(store.disabledSiteStillBlockedWarningTitle)
    XCTAssertNil(store.disabledSiteStillBlockedWarningDetail)
    XCTAssertNil(store.errorMessage)
  }

  func testBrowserConnectorListShowsSupportedBrowsersAndPlannedOthers() {
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge(),
      browserInstallationChecker: installedBrowsers([.chrome, .edge, .arc, .firefox, .safari])
    )

    XCTAssertEqual(
      store.browserConnectors.map(\.id),
      [.chrome, .edge, .brave, .arc, .firefox, .safari]
    )
    XCTAssertTrue(store.browserConnectors[0].isPrimary)
    XCTAssertEqual(store.browserConnectors[0].nextAction, .launchChromeTunerSession)
    let connectors = Dictionary(uniqueKeysWithValues: store.browserConnectors.map { ($0.id, $0) })
    XCTAssertTrue(connectors[.edge]?.isInstalled == true)
    XCTAssertTrue(connectors[.arc]?.isInstalled == true)
    XCTAssertFalse(connectors[.brave]?.isInstalled == true)
    XCTAssertEqual(
      connectors[.edge]?.state,
      .actionNeeded("Connect Edge so website blocks and site tuning apply there.")
    )
    XCTAssertEqual(connectors[.edge]?.nextAction, .launchBrowserTunerSession(.edge))
    XCTAssertEqual(
      connectors[.arc]?.state,
      .actionNeeded("Connect Arc so website blocks and site tuning apply there.")
    )
    XCTAssertEqual(connectors[.arc]?.nextAction, .launchBrowserTunerSession(.arc))
    XCTAssertEqual(
      connectors[.firefox]?.state,
      .actionNeeded("Connect Firefox so website blocks and site tuning apply there.")
    )
    XCTAssertEqual(connectors[.firefox]?.nextAction, .launchBrowserTunerSession(.firefox))
    XCTAssertEqual(
      connectors[.safari]?.state,
      .comingSoon("Safari is installed. Tortoise support is planned.")
    )
  }

  func testChromeConnectorShowsInstallActionWhenChromeIsMissing() {
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge(),
      browserInstallationChecker: installedBrowsers([])
    )

    let connector = store.primaryBrowserConnector

    XCTAssertEqual(connector.id, .chrome)
    XCTAssertFalse(connector.isInstalled)
    XCTAssertEqual(connector.nextAction, .openChromeDownload)
    XCTAssertEqual(
      connector.state,
      .actionNeeded("Chrome is not installed. Install Chrome, or connect another supported browser.")
    )
  }

  func testPrimaryBrowserConnectorReflectsChromeConnectionState() {
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge
    )
    markChromeConnected(store, bridge: bridge)

    let connector = store.primaryBrowserConnector

    XCTAssertEqual(connector.id, .chrome)
    XCTAssertEqual(connector.displayName, "Chrome")
    XCTAssertTrue(connector.isConnected)
    XCTAssertEqual(connector.connectedProfiles, ["Default"])
    XCTAssertNil(connector.nextAction)
    XCTAssertEqual(store.defaultBlockingProvider.destinationNames, ["Chrome"])
  }

  func testBrowserFirstUnlocksBlockingControlsWhenEdgeIsConnectedWithoutChrome() {
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge,
      browserInstallationChecker: installedBrowsers([.edge])
    )

    markBrowserConnected(store, .edge, bridge: bridge)

    XCTAssertTrue(store.blockingControlsReady)
    XCTAssertEqual(store.primaryBrowserConnector.id, .edge)
    XCTAssertEqual(store.defaultBlockingProvider.destinationNames, ["Edge"])
    XCTAssertEqual(
      store.settingsStatusSummary,
      "Tortoise is ready. Edge profile: Default connected for browser blocking and tuning."
    )
  }

  func testBrowserFirstUnlocksBlockingControlsWhenArcIsConnectedWithoutChrome() {
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge,
      browserInstallationChecker: installedBrowsers([.arc])
    )

    markBrowserConnected(store, .arc, bridge: bridge)

    XCTAssertTrue(store.blockingControlsReady)
    XCTAssertEqual(store.primaryBrowserConnector.id, .arc)
    XCTAssertEqual(store.defaultBlockingProvider.destinationNames, ["Arc"])
    XCTAssertEqual(
      store.settingsStatusSummary,
      "Tortoise is ready. Arc profile: Default connected for browser blocking and tuning."
    )
  }

  func testBrowserFirstUnlocksBlockingControlsWhenFirefoxIsConnectedWithoutChrome() {
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge,
      browserInstallationChecker: installedBrowsers([.firefox])
    )

    markBrowserConnected(store, .firefox, bridge: bridge)

    XCTAssertTrue(store.blockingControlsReady)
    XCTAssertEqual(store.primaryBrowserConnector.id, .firefox)
    XCTAssertEqual(store.defaultBlockingProvider.destinationNames, ["Firefox"])
    XCTAssertEqual(
      store.settingsStatusSummary,
      "Tortoise is ready. Firefox profile: Default connected for browser blocking and tuning."
    )
  }

  func testBrowserFirstStartupMigrationClearsLegacyProviderConnectorDefaults() {
    let defaults = isolatedDefaults()
    defaults.set("abc123", forKey: "quietgate.profileID")
    defaults.set("abc123", forKey: "quietgate.legacyProviderVerifiedProfileID")
    defaults.set(true, forKey: "quietgate.legacyProviderRulesSyncPending")
    defaults.set(["x.com"], forKey: "quietgate.pendingLegacyProviderRuleRemovals")
    defaults.set("/tmp/quietgate.mobileconfig", forKey: "quietgate.generatedAppleProfilePath")
    defaults.set(true, forKey: "quietgate.legacyProviderConnectorEnabledDeprecated")
    defaults.set(true, forKey: "quietgate.enableLegacyProviderRuntime")

    ProtectionStore.disableLegacyProviderConnector(in: defaults)
    let store = ProtectionStore(
      defaults: defaults,
      keychain: MemorySecretStore(secret: "secret"),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge()
    )

    XCTAssertFalse(store.legacyProviderConnectorEnabled)
    XCTAssertEqual(store.profileID, "")
    XCTAssertFalse(store.hasAPIKey)
    XCTAssertNil(store.legacyProviderVerifiedProfileID)
    XCTAssertNil(defaults.string(forKey: "quietgate.profileID"))
    XCTAssertNil(defaults.string(forKey: "quietgate.legacyProviderVerifiedProfileID"))
    XCTAssertNil(defaults.string(forKey: "quietgate.generatedAppleProfilePath"))
    XCTAssertFalse(defaults.bool(forKey: "quietgate.legacyProviderConnectorEnabledDeprecated"))
    XCTAssertFalse(defaults.bool(forKey: "quietgate.legacyProviderRulesSyncPending"))
    XCTAssertFalse(defaults.bool(forKey: "quietgate.enableLegacyProviderRuntime"))
    XCTAssertTrue(pendingRemovalDefaults(defaults).isEmpty)
    XCTAssertNil(store.generatedAppleProfileURL)
    XCTAssertEqual(store.defaultBlockingProvider.id, .browserHelpers)
  }

  func testBrowserFirstStartupMigrationIgnoresLegacyProviderEnvironmentFlag() {
    setenv("QG_ENABLE_LEGACY_PROVIDER", "1", 1)
    defer { unsetenv("QG_ENABLE_LEGACY_PROVIDER") }

    let defaults = isolatedDefaults()
    defaults.set(true, forKey: "quietgate.legacyProviderConnectorEnabled")
    defaults.set(true, forKey: "quietgate.legacyProviderConnectorEnabledDeprecated")
    defaults.set(true, forKey: "quietgate.enableLegacyProviderRuntime")

    ProtectionStore.disableLegacyProviderConnector(in: defaults)
    let store = ProtectionStore(
      defaults: defaults,
      keychain: MemorySecretStore(secret: "secret"),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge(),
      browserInstallationChecker: installedBrowsers([.chrome])
    )

    XCTAssertFalse(store.legacyProviderConnectorEnabled)
    XCTAssertFalse(defaults.bool(forKey: "quietgate.legacyProviderConnectorEnabled"))
    XCTAssertFalse(defaults.bool(forKey: "quietgate.legacyProviderConnectorEnabledDeprecated"))
    XCTAssertFalse(defaults.bool(forKey: "quietgate.enableLegacyProviderRuntime"))
    XCTAssertEqual(store.defaultBlockingProvider.id, .browserHelpers)
    XCTAssertTrue(store.readinessChecks(scope: .blocker).isEmpty)
  }

  func testBrowserFirstIgnoresStaleLegacyProviderConnectorStateWhenFlagIsOff() {
    let defaults = browserFirstDefaults()
    defaults.set("abc123", forKey: "quietgate.profileID")
    defaults.set("abc123", forKey: "quietgate.legacyProviderVerifiedProfileID")
    defaults.set(true, forKey: "quietgate.legacyProviderRulesSyncPending")
    defaults.set(["x.com"], forKey: "quietgate.pendingLegacyProviderRuleRemovals")
    defaults.set("/tmp/quietgate.mobileconfig", forKey: "quietgate.generatedAppleProfilePath")

    let store = ProtectionStore(
      defaults: defaults,
      keychain: MemorySecretStore(secret: "secret"),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge(),
      browserInstallationChecker: installedBrowsers([.chrome])
    )

    XCTAssertFalse(store.legacyProviderConnectorEnabled)
    XCTAssertEqual(store.profileID, "")
    XCTAssertFalse(store.hasAPIKey)
    XCTAssertFalse(store.legacyProviderRulesSyncPending)
    XCTAssertNil(store.legacyProviderVerifiedProfileID)
    XCTAssertNil(store.generatedAppleProfileURL)
    XCTAssertEqual(store.defaultBlockingProvider.id, .browserHelpers)
    XCTAssertEqual(
      store.settingsStatusSummary,
      "Connect a browser to finish setup for browser blocking and site tuning."
    )
  }

  func testBrowserFirstCapabilitySnapshotNamesBrowserProvider() {
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(secret: "secret"),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge(),
      browserInstallationChecker: installedBrowsers([.chrome])
    )
    markChromeConnected(store)

    let snapshot = store.blockingCapabilitySnapshot
    XCTAssertEqual(snapshot.state, .ready)
    XCTAssertEqual(snapshot.providerID, .browserHelpers)
    XCTAssertEqual(snapshot.providerTitle, "Browsers")
    XCTAssertTrue(snapshot.providerDetail.contains("connected browsers"))
  }

  func testBrowserFirstSiteRulesSyncToChromeSettingsWithoutNextDNS() async throws {
    let service = FakeLegacyProviderService(parentalControl: ParentalControl())
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in service },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge
    )
    markChromeConnected(store, bridge: bridge)

    try await store.addCustomDomain("x.com")

    XCTAssertEqual(service.addedDomains, [])
    XCTAssertTrue(store.blockedSites.contains { $0.domain == "x.com" && $0.isEnabled })
    XCTAssertTrue(bridge.writtenSettings.last?.blockedDomains.contains("x.com") == true)
    XCTAssertEqual(store.blockCoverageSummary, "1 block active in connected browsers.")
  }

  func testBrowserFirstRuleChangeStaysUsableUntilBrowserAppliesLatestSettings() async throws {
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge,
      browserInstallationChecker: installedBrowsers([.chrome])
    )
    let status = ChromeExtensionStatus(
      selectedProfile: "Default",
      profileCount: 1,
      loadedProfiles: ["Default"],
      disabledProfiles: [],
      sessionProfiles: []
    )
    bridge.extensionStatuses[.chrome] = status
    bridge.installedBrowsers.insert(.chrome)
    bridge.helperSnapshots[.chrome] = ChromeHelperSnapshot(
      extensionID: BrowserExtensionBridge.extensionID,
      lastSeenAt: Date(),
      lastAppliedSettingsVersion: store.currentBrowserSettingsVersion,
      extensionVersion: "0.1.0",
      blockedRuleCount: 0
    )
    store.refreshChromeExtensionStatus()

    XCTAssertTrue(store.blockingControlsReady)

    try await store.addCustomDomain("x.com")

    XCTAssertTrue(store.blockingControlsReady)
    XCTAssertEqual(store.browserHelperStates[.chrome], .needsSync)
    XCTAssertTrue(store.primaryBrowserConnector.isConnected)
    XCTAssertEqual(store.blockCoverageSummary, "1 block active in connected browsers.")
    XCTAssertNil(store.blockingCapabilityUnavailableReason)
  }

  func testBrowserFirstAdultCategorySyncsPresetDomainsToChromeWithoutNextDNS() async throws {
    let service = FakeLegacyProviderService(parentalControl: ParentalControl())
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in service },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge
    )
    markChromeConnected(store, bridge: bridge)

    await store.setBlockCategory(.adultContent, enabled: true)

    XCTAssertEqual(service.patchCount, 0)
    XCTAssertEqual(service.addedDomains, [])
    XCTAssertTrue(bridge.writtenSettings.last?.blockedDomains.contains("pornhub.com") == true)
    XCTAssertEqual(store.accessMode, .open)
    XCTAssertTrue(store.adultContentBlockingEnabled)
  }

  func testBrowserFirstRefreshDoesNotTouchLegacyProviderConnectorSetup() async throws {
    let service = FakeLegacyProviderService(parentalControl: ParentalControl())
    let resolver = FakeResolverStatusService()
    let systemProfile = FakeSystemProfileChecker(installed: true)
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(secret: "secret"),
      makeClient: { _ in service },
      resolverService: resolver,
      extensionBridge: bridge,
      systemProfileChecker: systemProfile,
      browserInstallationChecker: installedBrowsers([.chrome])
    )
    markChromeConnected(store, bridge: bridge)
    store.macOSLegacyProviderProfileInstalled = true
    store.resolverStatus = LegacyProviderResolverStatus(
      status: "ok",
      profile: "abc123",
      client: nil,
      clientName: nil,
      protocolName: nil
    )

    await store.refreshProtectionStatus()
    await store.refresh()
    await store.checkThisMac()
    await store.checkResolverStatus()

    XCTAssertEqual(service.getCount, 0)
    XCTAssertEqual(service.getDenylistCount, 0)
    XCTAssertEqual(service.patchCount, 0)
    XCTAssertEqual(resolver.checkCount, 0)
    XCTAssertEqual(systemProfile.checkCount, 0)
    XCTAssertFalse(store.macOSLegacyProviderProfileInstalled)
    XCTAssertNil(store.resolverStatus)
    XCTAssertTrue(store.blockingControlsReady)
  }

  func testBrowserFirstStoreRunsWithDisabledLegacyProviderConnectorDependencies() async throws {
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: DisabledLegacySecretStore(),
      makeClient: { _ in DisabledLegacyProviderService() },
      resolverService: DisabledResolverStatusService(),
      extensionBridge: bridge,
      systemProfileChecker: DisabledSystemProfileChecker(),
      appleProfileGenerator: DisabledLegacyProviderProfileGenerator(),
      browserInstallationChecker: installedBrowsers([.chrome])
    )
    markChromeConnected(store, bridge: bridge)

    await store.refreshProtectionStatus()
    try await store.addCustomDomain("x.com")
    await store.setBlockCategory(.adultContent, enabled: true)

    XCTAssertNil(store.errorMessage)
    XCTAssertTrue(store.blockingControlsReady)
    XCTAssertEqual(
      store.blockCoverageSummary,
      "\(AdultContentPreset.domains.count + 1) blocks active in connected browsers."
    )
    XCTAssertTrue(bridge.writtenSettings.last?.blockedDomains.contains("x.com") == true)
    XCTAssertTrue(bridge.writtenSettings.last?.blockedDomains.contains("pornhub.com") == true)
  }

  func testBrowserFirstDiagnosticStatusDoesNotExposeNextDNSSetup() {
    let store = ProtectionStore(
      defaults: browserFirstDefaults(),
      keychain: MemorySecretStore(secret: "secret"),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge(),
      browserInstallationChecker: installedBrowsers([.chrome])
    )

    let status = store.diagnosticStatusText

    XCTAssertFalse(status.contains("Advanced blocking connector"))
    XCTAssertFalse(status.contains("Legacy backup"))
    XCTAssertFalse(status.contains("Local hosts script"))
    XCTAssertFalse(status.contains("Advanced blocking configured"))
    XCTAssertFalse(status.contains("Advanced Mac setup URL"))
    XCTAssertFalse(status.contains("macOS advanced blocking profile installed"))
    XCTAssertFalse(status.contains("Verified active blocked domains"))
    XCTAssertFalse(status.contains("Minimum hard block"))
    XCTAssertFalse(status.contains("Browser helper"))
    XCTAssertFalse(status.contains("secret"))
  }

  func testTimedSessionExpiryReturnsToOpenAndClearsPersistence() async {
    var now = Date(timeIntervalSince1970: 1_000)
    let defaults = isolatedDefaults()
    let bridge = FakeBrowserExtensionBridge()
    let service = FakeLegacyProviderService(parentalControl: ParentalControl())
    let store = ProtectionStore(
      defaults: defaults,
      keychain: MemorySecretStore(secret: "secret"),
      makeClient: { _ in service },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge,
      nowProvider: { now }
    )
    markBlockConnectorReady(store)

    await store.startTimedSession(mode: .focus, duration: 60)
    now = now.addingTimeInterval(61)
    await store.expireTimedSessionIfNeeded()

    XCTAssertEqual(store.accessMode, .open)
    XCTAssertFalse(store.timedSessionActive)
    XCTAssertNil(store.timedSessionMode)
    XCTAssertNil(store.timedSessionEndDate)
    XCTAssertNil(defaults.string(forKey: "quietgate.timedSessionMode"))
    XCTAssertNil(defaults.object(forKey: "quietgate.timedSessionEndDate"))
    XCTAssertEqual(bridge.writtenSettings.last?.mode, .open)
  }

  func testActiveTimedSessionRestoresModeOnInitialization() {
    let now = Date(timeIntervalSince1970: 1_000)
    let defaults = isolatedDefaults()
    defaults.set(AccessMode.open.rawValue, forKey: "quietgate.accessMode")
    defaults.set(AccessMode.strict.rawValue, forKey: "quietgate.timedSessionMode")
    defaults.set(now.addingTimeInterval(300), forKey: "quietgate.timedSessionEndDate")

    let store = ProtectionStore(
      defaults: defaults,
      keychain: MemorySecretStore(secret: "secret"),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge(),
      nowProvider: { now }
    )

    XCTAssertEqual(store.accessMode, .strict)
    XCTAssertTrue(store.timedSessionActive)
    XCTAssertEqual(store.timedSessionStatusLine, "Strict session ends in 5m")
  }

  func testActiveLockedTimedSessionRestoresLockOnInitialization() {
    let now = Date(timeIntervalSince1970: 1_000)
    let defaults = isolatedDefaults()
    defaults.set(AccessMode.open.rawValue, forKey: "quietgate.accessMode")
    defaults.set(AccessMode.strict.rawValue, forKey: "quietgate.timedSessionMode")
    defaults.set(now.addingTimeInterval(300), forKey: "quietgate.timedSessionEndDate")
    defaults.set(true, forKey: "quietgate.timedSessionLocked")

    let store = ProtectionStore(
      defaults: defaults,
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge(),
      nowProvider: { now }
    )

    XCTAssertEqual(store.accessMode, .strict)
    XCTAssertTrue(store.timedSessionActive)
    XCTAssertTrue(store.timedSessionLockedActive)
    XCTAssertEqual(store.timedSessionStatusLine, "Locked Strict session ends in 5m")
  }

  func testFocusWindowExpiryReturnsToOpen() async {
    var now = localDate(hour: 10)
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: isolatedDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge,
      nowProvider: { now }
    )
    markBlockConnectorReady(store)

    store.addFocusWindow(title: "Work", startMinute: 9 * 60, endMinute: 17 * 60, mode: .focus)
    await store.evaluateFocusWindowSchedule()
    now = localDate(hour: 18)
    await store.evaluateFocusWindowSchedule()

    XCTAssertEqual(store.accessMode, .open)
    XCTAssertNil(store.activeFocusWindow)
    XCTAssertEqual(bridge.writtenSettings.last?.mode, .open)
  }

  func testManualModeSuppressionSurvivesReloadDuringActiveFocusWindow() async {
    let now = localDate(hour: 10)
    let defaults = isolatedDefaults()
    let store = ProtectionStore(
      defaults: defaults,
      keychain: MemorySecretStore(secret: "secret"),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge(),
      nowProvider: { now }
    )
    markBlockConnectorReady(store)

    store.addFocusWindow(title: "Work", startMinute: 9 * 60, endMinute: 17 * 60, mode: .focus)
    await store.evaluateFocusWindowSchedule()
    await store.setAccessMode(.open)

    let reloaded = ProtectionStore(
      defaults: defaults,
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge(),
      nowProvider: { now }
    )

    await reloaded.evaluateFocusWindowSchedule()

    XCTAssertEqual(reloaded.accessMode, .open)
  }

  func testConnectedChromeClearsInstantBrowserBlockingPrompt() async throws {
    let bridge = FakeBrowserExtensionBridge()
    bridge.installed = true
    bridge.extensionLoaded = true
    bridge.helperState = .current
    let store = ProtectionStore(
      defaults: verifiedLegacyProviderDefaults(),
      keychain: MemorySecretStore(secret: "secret"),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge
    )
    store.resolverStatus = LegacyProviderResolverStatus(
      status: "ok", profile: "abc123", client: nil, clientName: nil, protocolName: nil)

    try await store.addCustomDomain("x.com")

    XCTAssertNil(store.blockBrowserAttentionTitle)
    XCTAssertNil(store.blockBrowserAttentionDetail)
  }

  func testBatchTuningFeatureUpdatesPersistAndSyncOnce() {
    let defaults = isolatedDefaults()
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: defaults,
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge
    )
    let initialWriteCount = bridge.writtenSettings.count

    store.setTuningFeatures(
      [.instagramReels, .instagramMessages, .instagramNotifications],
      enabled: true
    )

    XCTAssertEqual(bridge.writtenSettings.count, initialWriteCount + 1)
    XCTAssertEqual(store.tuningOverrides["instagramReels"], true)
    XCTAssertEqual(store.tuningOverrides["instagramMessages"], true)
    XCTAssertEqual(store.tuningOverrides["instagramNotifications"], true)
    XCTAssertEqual(bridge.writtenSettings.last?.features["instagramReels"], true)
    XCTAssertEqual(bridge.writtenSettings.last?.features["instagramMessages"], true)
    XCTAssertEqual(bridge.writtenSettings.last?.features["instagramNotifications"], true)

    store.setTuningFeatures(
      [.instagramReels, .instagramMessages, .instagramNotifications],
      enabled: false
    )

    XCTAssertEqual(bridge.writtenSettings.count, initialWriteCount + 2)
    XCTAssertNil(defaults.dictionary(forKey: "quietgate.tuningOverrides"))
    XCTAssertEqual(bridge.writtenSettings.last?.features["instagramReels"], false)
    XCTAssertEqual(bridge.writtenSettings.last?.features["instagramMessages"], false)
    XCTAssertEqual(bridge.writtenSettings.last?.features["instagramNotifications"], false)
  }

  func testAppleDNSProfileGeneratorBuildsNextDNSPayload() throws {
    let data = try LegacyProviderAppleProfileGenerator.profileData(
      profileID: " fp123 ",
      deviceName: "Will Mac",
      profileUUID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
      payloadUUID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    )
    let plist = try XCTUnwrap(
      PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
    )
    let content = try XCTUnwrap(plist["PayloadContent"] as? [[String: Any]])
    let payload = try XCTUnwrap(content.first)
    let dnsSettings = try XCTUnwrap(payload["DNSSettings"] as? [String: Any])
    let onDemandRules = try XCTUnwrap(payload["OnDemandRules"] as? [[String: Any]])
    let evaluateRule = try XCTUnwrap(onDemandRules.first)
    let actionParameters = try XCTUnwrap(evaluateRule["ActionParameters"] as? [[String: Any]])
    let captivePortalRule = try XCTUnwrap(actionParameters.first)
    let captivePortalDomains = try XCTUnwrap(captivePortalRule["Domains"] as? [String])

    XCTAssertEqual(plist["PayloadType"] as? String, "Configuration")
    XCTAssertEqual(plist["PayloadDisplayName"] as? String, "Tortoise Blocking")
    XCTAssertEqual(plist["PayloadScope"] as? String, "System")
    XCTAssertEqual(payload["PayloadType"] as? String, "com.apple.dnsSettings.managed")
    XCTAssertEqual(dnsSettings["DNSProtocol"] as? String, "HTTPS")
    XCTAssertEqual(
      dnsSettings["ServerURL"] as? String, "https://apple.dns.nextdns.io/fp123/Will%20Mac")
    XCTAssertEqual(onDemandRules.count, 2)
    XCTAssertEqual(evaluateRule["Action"] as? String, "EvaluateConnection")
    XCTAssertEqual(captivePortalRule["DomainAction"] as? String, "NeverConnect")
    XCTAssertTrue(captivePortalDomains.contains("captive.apple.com"))
    XCTAssertEqual(onDemandRules.last?["Action"] as? String, "Connect")
  }

  func testSystemProfilerProfileStatusFindsConfiguredNextDNSProfile() throws {
    let data = Data(
      """
      {
        "SPConfigurationProfileDataType": [
          {
            "_items": [
              {
                "_name": "QuietGate NextDNS",
                "spconfigprofile_profile_identifier": "com.willpulier.quietgate.nextdns.77df3e",
                "_items": [
                  {
                    "spconfigprofile_payload_data": "DNSSettings = { ServerURL = \\"https://apple.dns.nextdns.io/77df3e/Will%20Pulier\\"; };",
                    "spconfigprofile_payload_display_name": "QuietGate NextDNS DNS"
                  }
                ]
              }
            ]
          }
        ]
      }
      """.utf8)

    let status = try XCTUnwrap(
      MacConfigurationProfileService.legacyProviderProfileStatus(
        fromSystemProfilerJSON: data,
        profileID: "77df3e"
      )
    )

    XCTAssertTrue(status.anyLegacyProviderProfileInstalled)
    XCTAssertTrue(status.configuredLegacyProviderProfileInstalled)
  }

  func testLocalHostsBlockerScriptGeneratorWritesReversibleExecutableScript() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("QuietGateHostsScriptTests-\(UUID().uuidString)", isDirectory: true)
    let hostsFile = directory.appendingPathComponent("hosts")
    let generator = LocalHostsBlockerScriptGenerator(
      outputDirectory: directory, hostsFileURL: hostsFile)

    let url = try generator.writeScript(domains: [
      "https://Example.com/path",
      "*.example.com",
      "onlyfans.com",
    ])
    let script = try String(contentsOf: url, encoding: .utf8)

    XCTAssertEqual(url.lastPathComponent, "Tortoise Local Hosts Blocker.command")
    XCTAssertTrue(FileManager.default.isExecutableFile(atPath: url.path))
    XCTAssertTrue(script.contains("# QuietGate blocklist begin"))
    XCTAssertTrue(script.contains("# QuietGate blocklist end"))
    XCTAssertTrue(script.contains("0.0.0.0 example.com"))
    XCTAssertTrue(script.contains("::1 www.example.com"))
    XCTAssertTrue(script.contains("0.0.0.0 m.onlyfans.com"))
    XCTAssertTrue(script.contains("Remove Tortoise local blocks"))
    XCTAssertTrue(script.contains("sudo install -m 644"))
  }

  func testLocalHostsBlockerScriptGeneratorDetectsInstalledMarkerSection() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("QuietGateHostsStatusTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let hostsFile = directory.appendingPathComponent("hosts")
    let generator = LocalHostsBlockerScriptGenerator(
      outputDirectory: directory, hostsFileURL: hostsFile)

    try "127.0.0.1 localhost\n".write(to: hostsFile, atomically: true, encoding: .utf8)
    XCTAssertFalse(generator.localHostsBlocklistInstalled())

    try """
    127.0.0.1 localhost
    # QuietGate blocklist begin
    0.0.0.0 example.com
    # QuietGate blocklist end
    """.write(to: hostsFile, atomically: true, encoding: .utf8)

    XCTAssertTrue(generator.localHostsBlocklistInstalled())
  }

  func testLocalHostsBlockerScriptGeneratorMatchesInstalledDomains() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("QuietGateHostsMatchTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let hostsFile = directory.appendingPathComponent("hosts")
    let generator = LocalHostsBlockerScriptGenerator(
      outputDirectory: directory, hostsFileURL: hostsFile)

    try """
    127.0.0.1 localhost
    # QuietGate blocklist begin
    0.0.0.0 example.com
    ::1 example.com
    0.0.0.0 m.example.com
    ::1 m.example.com
    0.0.0.0 www.example.com
    ::1 www.example.com
    # QuietGate blocklist end
    """.write(to: hostsFile, atomically: true, encoding: .utf8)

    XCTAssertTrue(generator.localHostsBlocklistMatches(domains: ["example.com"]))
    XCTAssertFalse(generator.localHostsBlocklistMatches(domains: ["example.org"]))
  }

  func testLocalHostsBlockerScriptGeneratorBuildsPrivilegedInstallAndRemoveScripts() throws {
    var scripts: [String] = []
    let generator = LocalHostsBlockerScriptGenerator(
      privilegedScriptRunner: { scripts.append($0) }
    )

    try generator.installBlocklist(domains: ["example.com"])
    try generator.installBlocklist(domains: [])
    try generator.removeBlocklist()

    XCTAssertEqual(scripts.count, 3)
    XCTAssertTrue(scripts[0].contains("ACTION=\"install\""))
    XCTAssertTrue(scripts[0].contains("# QuietGate blocklist begin"))
    XCTAssertTrue(scripts[0].contains("0.0.0.0 example.com"))
    XCTAssertTrue(scripts[0].contains("::1 www.example.com"))
    XCTAssertTrue(scripts[1].contains("ACTION=\"install\""))
    XCTAssertTrue(scripts[1].contains("# QuietGate blocklist begin"))
    XCTAssertFalse(scripts[1].contains("0.0.0.0 example.com"))
    XCTAssertTrue(scripts[2].contains("ACTION=\"remove\""))
    XCTAssertFalse(scripts[2].contains("0.0.0.0 example.com"))
  }

  func testLocalHostsBlockerCanceledPasswordPromptUsesFriendlyMessage() {
    let error = LocalHostsBlockerScriptError.privilegedCommandFailed(
      "0:164: execution error: User canceled. (-128)"
    )

    XCTAssertEqual(
      error.localizedDescription,
      "Backup blocking was not updated because the Mac password prompt was canceled.")
  }

  func testBrowserSettingsDoNotRewriteOnStoreInitializationWhenVersionPersisted() {
    let defaults = browserFirstDefaults()
    let firstBridge = FakeBrowserExtensionBridge()
    _ = ProtectionStore(
      defaults: defaults,
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: firstBridge
    )
    let firstVersion = firstBridge.writtenSettings.last?.settingsVersion

    let secondBridge = FakeBrowserExtensionBridge()
    _ = ProtectionStore(
      defaults: defaults,
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: secondBridge
    )

    XCTAssertEqual(firstBridge.writtenSettings.count, 1)
    XCTAssertEqual(defaults.string(forKey: "quietgate.browserSettingsVersion"), firstVersion)
    XCTAssertTrue(secondBridge.writtenSettings.isEmpty)
  }

  func testCustomTuningPersistsAcrossStoreInitialization() {
    let defaults = isolatedDefaults()
    let firstBridge = FakeBrowserExtensionBridge()
    let firstStore = ProtectionStore(
      defaults: defaults,
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: firstBridge
    )
    firstStore.setTuningFeature(.youtubeRecommendations, enabled: true)

    let secondBridge = FakeBrowserExtensionBridge()
    let secondStore = ProtectionStore(
      defaults: defaults,
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: secondBridge
    )

    XCTAssertTrue(secondStore.tuningFeatureEnabled(.youtubeRecommendations))
    XCTAssertEqual(secondStore.effectiveTuningFeatures, [.youtubeRecommendations])
    XCTAssertTrue(secondBridge.writtenSettings.isEmpty)
  }

  func testExplicitHideStylePersistsAndSyncsBrowserSettings() {
    let defaults = isolatedDefaults()
    let firstBridge = FakeBrowserExtensionBridge()
    let firstStore = ProtectionStore(
      defaults: defaults,
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: firstBridge
    )

    firstStore.setExplicitHideStyle(.media)

    XCTAssertEqual(firstStore.tuningOptions.explicitHideStyle, .media)
    XCTAssertNotNil(defaults.data(forKey: "quietgate.tuningOptions"))
    XCTAssertEqual(firstBridge.writtenSettings.last?.options.explicitHideStyle, .media)
    XCTAssertTrue(
      firstBridge.writtenSettings.last?.settingsVersion.contains("options=explicitHideStyle=media")
        == true
    )

    let secondBridge = FakeBrowserExtensionBridge()
    let secondStore = ProtectionStore(
      defaults: defaults,
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: secondBridge
    )

    XCTAssertEqual(secondStore.tuningOptions.explicitHideStyle, .media)
    XCTAssertTrue(secondBridge.writtenSettings.isEmpty)

    secondStore.setExplicitHideStyle(.post)

    XCTAssertNil(defaults.data(forKey: "quietgate.tuningOptions"))
    XCTAssertEqual(secondBridge.writtenSettings.last?.options.explicitHideStyle, .post)
  }

  /// Regression guard for the Mac Tune "hide style" segmented control (spec §6.3):
  /// the exact case order and titles it renders must match the design intent.
  func testExplicitHideStyleTitlesMatchTuneUISpec() {
    XCTAssertEqual(ExplicitHideStyle.allCases, [.post, .media, .placeholder])
    XCTAssertEqual(
      ExplicitHideStyle.allCases.map(\.title),
      ["Whole post", "Media only", "Placeholder"]
    )
  }

  /// Regression guard for the Mac Tune "daily limit" stepper (spec §6.3): the
  /// stepper's range and default must match the values the UI is built around.
  func testYouTubeDailyLimitRangeAndDefaultMatchTuneUISpec() {
    XCTAssertEqual(BrowserTuningOptions.youtubeDailyLimitRange, 5...480)
    XCTAssertEqual(BrowserTuningOptions.defaultYouTubeDailyLimitMinutes, 30)
  }

  func testYouTubeDailyLimitMinutesPersistClampAndSyncBrowserSettings() {
    let defaults = isolatedDefaults()
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: defaults,
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge
    )

    store.setYouTubeDailyLimitMinutes(2)

    XCTAssertEqual(store.tuningOptions.youtubeDailyLimitMinutes, 5)
    XCTAssertNotNil(defaults.data(forKey: "quietgate.tuningOptions"))
    XCTAssertEqual(bridge.writtenSettings.last?.options.youtubeDailyLimitMinutes, 5)
    XCTAssertTrue(
      bridge.writtenSettings.last?.settingsVersion.contains("youtubeDailyLimitMinutes=5")
        == true
    )

    store.setYouTubeDailyLimitMinutes(BrowserTuningOptions.defaultYouTubeDailyLimitMinutes)

    XCTAssertNil(defaults.data(forKey: "quietgate.tuningOptions"))
    XCTAssertEqual(
      bridge.writtenSettings.last?.options.youtubeDailyLimitMinutes,
      BrowserTuningOptions.defaultYouTubeDailyLimitMinutes
    )
  }

  func testResetTuningOverridesCanTargetOneSite() {
    let defaults = isolatedDefaults()
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: defaults,
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge
    )
    store.setTuningFeature(.youtubeRecommendations, enabled: true)
    store.setTuningFeature(.xPhotos, enabled: true)

    store.resetTuningOverrides(for: .x)

    XCTAssertTrue(store.tuningFeatureEnabled(.youtubeRecommendations))
    XCTAssertFalse(store.tuningFeatureEnabled(.xPhotos))
    XCTAssertEqual(
      defaults.dictionary(forKey: "quietgate.tuningOverrides")?["youtubeRecommendations"] as? Bool,
      true
    )
    XCTAssertNil(defaults.dictionary(forKey: "quietgate.tuningOverrides")?["xPhotos"])
    XCTAssertEqual(bridge.writtenSettings.last?.features["youtubeRecommendations"], true)
    XCTAssertEqual(bridge.writtenSettings.last?.features["xPhotos"], false)
  }

  func testSaveConfigurationDoesNotApplyPreSetupFocusSelection() async throws {
    let defaults = isolatedDefaults()
    let secretStore = MemorySecretStore()
    let service = FakeLegacyProviderService(parentalControl: ParentalControl())
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: defaults,
      keychain: secretStore,
      makeClient: { _ in service },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge
    )

    await store.setAccessMode(.focus)
    store.profileID = "abc123"
    store.apiKeyDraft = "secret"

    await store.saveConfiguration()

    XCTAssertEqual(store.accessMode, .open)
    XCTAssertEqual(store.mode, .off)
    XCTAssertFalse(service.parentalControl.isQuietGateEnabled)
    XCTAssertEqual(secretStore.secret, "secret")
    XCTAssertNil(defaults.string(forKey: "quietgate.accessMode"))
    XCTAssertEqual(bridge.writtenSettings.last?.mode, .open)
  }

  func testRefreshKeepsOpenModeWhenRemoteProtectionIsOff() async throws {
    let service = FakeLegacyProviderService(parentalControl: ParentalControl())
    let store = ProtectionStore(
      defaults: isolatedDefaults(),
      keychain: MemorySecretStore(secret: "secret"),
      makeClient: { _ in service },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge()
    )
    store.profileID = "abc123"

    await store.refresh()

    XCTAssertEqual(store.accessMode, .open)
    XCTAssertEqual(store.mode, .off)
    XCTAssertEqual(service.patchCount, 0)
  }

  func testClearAPIKeyClearsLocalBlockerStateAndActivity() async throws {
    let secretStore = MemorySecretStore(secret: "secret")
    let store = ProtectionStore(
      defaults: isolatedDefaults(),
      keychain: secretStore,
      makeClient: { _ in
        FakeLegacyProviderService(parentalControl: ParentalControl().applyingQuietGateEnabled())
      },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge()
    )
    store.profileID = "abc123"
    await store.setAccessMode(.focus)
    store.blockedLogs = [try blockedLogEntry()]
    store.analyticsStatus = [LegacyProviderAnalyticsStatus(status: "blocked", queries: 4)]

    store.clearAPIKey()

    XCTAssertNil(secretStore.secret)
    XCTAssertFalse(store.hasAPIKey)
    XCTAssertEqual(store.mode, .off)
    XCTAssertNil(store.parentalControl)
    XCTAssertTrue(store.blockedLogs.isEmpty)
    XCTAssertTrue(store.analyticsStatus.isEmpty)
    XCTAssertEqual(store.connectionState, .notConfigured)
    XCTAssertFalse(store.blockerVisualEnabled)
  }

  func testRefreshChromeExtensionStatusSeparatesLoadedExtensionFromNativeSync() {
    let bridge = FakeBrowserExtensionBridge()
    bridge.extensionLoaded = true
    bridge.installed = false
    let store = ProtectionStore(
      defaults: isolatedDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge
    )

    store.refreshChromeExtensionStatus()

    XCTAssertTrue(store.chromeExtensionLoaded)
    XCTAssertFalse(store.chromeBridgeInstalled)
    XCTAssertFalse(store.chromeBridgeResponding)
  }

  func testChromeSyncIsNotReadyWhenChromeExtensionIsNotConnected() {
    let bridge = FakeBrowserExtensionBridge()
    bridge.extensionLoaded = false
    bridge.installed = true
    let store = ProtectionStore(
      defaults: isolatedDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge
    )

    store.setTuningFeature(.youtubeComments, enabled: true)
    store.refreshChromeExtensionStatus()
    let checks = Dictionary(
      uniqueKeysWithValues: store.readinessChecks(scope: .tuner).map { ($0.id, $0) })

    XCTAssertFalse(store.chromeExtensionLoaded)
    XCTAssertTrue(store.chromeBridgeInstalled)
    XCTAssertFalse(store.chromeBridgeResponding)
    XCTAssertEqual(store.tunerStatusLabel, "Not connected")
    XCTAssertEqual(checks[.browserSettings]?.state, .actionNeeded)
    XCTAssertEqual(checks[.browserSettings]?.action, .launchChromeTunerSession)
    XCTAssertTrue(checks[.browserSettings]?.detail.contains("Connect Chrome") == true)
  }

  func testNextReadinessCheckPrioritizesChromeForTunerOnlySetup() {
    let store = ProtectionStore(
      defaults: isolatedDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge()
    )

    store.setTuningFeature(.youtubeComments, enabled: true)

    XCTAssertEqual(store.nextReadinessCheck?.id, .browserConnection)
    XCTAssertEqual(store.nextReadinessCheck?.action, .launchChromeTunerSession)
    XCTAssertEqual(store.nextReadinessMenuTitle, "Next: Chrome")
  }

  func testNextReadinessCheckIsNilWhenSystemBlockingReadyEvenIfChromeMissing() {
    let store = ProtectionStore(
      defaults: verifiedLegacyProviderDefaults(),
      keychain: MemorySecretStore(secret: "secret"),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge()
    )
    markBlockConnectorReady(store)

    XCTAssertNil(store.nextReadinessCheck)
  }

  func testNextReadinessCheckIsNilWhenSetupIsReady() {
    let bridge = FakeBrowserExtensionBridge()
    bridge.extensionLoaded = true
    bridge.installed = true
    let store = ProtectionStore(
      defaults: verifiedLegacyProviderDefaults(),
      keychain: MemorySecretStore(secret: "secret"),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge
    )
    markBlockConnectorReady(store)

    XCTAssertNil(store.nextReadinessCheck)
    XCTAssertNil(store.nextReadinessMenuTitle)
  }

  func testCopyDiagnosticStatusWritesPasteboardAndMessage() {
    let store = ProtectionStore(
      defaults: isolatedDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge()
    )

    store.copyDiagnosticStatus()

    XCTAssertEqual(store.extensionBridgeMessage, "Status copied.")
    XCTAssertEqual(NSPasteboard.general.string(forType: .string), store.diagnosticStatusText)
  }

  func testCopyChromeExtensionFolderPathWritesPasteboardAndMessage() {
    let bridge = FakeBrowserExtensionBridge()
    let store = ProtectionStore(
      defaults: isolatedDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: bridge
    )

    store.copyChromeExtensionFolderPath()

    XCTAssertEqual(
      store.extensionBridgeMessage,
      "Browser extension path copied. In your browser, click Load unpacked and paste it.")
    XCTAssertEqual(
      NSPasteboard.general.string(forType: .string), bridge.chromeExtensionDirectoryURL.path)
  }

  func testCreateLocalHostsBlockerScriptIncludesAdultPresetAndCustomDomains() {
    let defaults = isolatedDefaults()
    defaults.set(AccessMode.focus.rawValue, forKey: "quietgate.accessMode")
    let generator = FakeLocalHostsScriptGenerator()
    let store = ProtectionStore(
      defaults: defaults,
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge(),
      localHostsScriptGenerator: generator
    )
    store.customDomains = ["example.com"]

    store.createLocalHostsBlockerScript()

    XCTAssertTrue(generator.domains.contains("onlyfans.com"))
    XCTAssertTrue(generator.domains.contains("pornhub.com"))
    XCTAssertTrue(generator.domains.contains("example.com"))
    XCTAssertEqual(store.generatedHostsScriptURL, generator.url)
    XCTAssertTrue(store.setupMessage?.contains("Backup blocking script created") == true)
  }

  func testInstallLocalHostsFallbackInstallsAdultPresetAndCustomDomains() {
    let defaults = isolatedDefaults()
    defaults.set(AccessMode.focus.rawValue, forKey: "quietgate.accessMode")
    let generator = FakeLocalHostsScriptGenerator()
    let store = ProtectionStore(
      defaults: defaults,
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge(),
      localHostsScriptGenerator: generator
    )
    store.customDomains = ["example.com"]

    store.installLocalBlockerBackup()

    XCTAssertTrue(generator.installedDomains.contains("onlyfans.com"))
    XCTAssertTrue(generator.installedDomains.contains("pornhub.com"))
    XCTAssertTrue(generator.installedDomains.contains("example.com"))
    XCTAssertTrue(generator.installed)
    XCTAssertTrue(store.localHostsFallbackInstalled)
    XCTAssertTrue(store.localHostsFallbackCurrent)
    XCTAssertFalse(store.localHostsFallbackNeedsUpdate)
    XCTAssertTrue(store.localHostsFallbackConnected)
    XCTAssertTrue(store.localHostsFallbackSynced)
    XCTAssertNil(store.localHostsFallbackMaintenanceStatus)
    XCTAssertEqual(store.localFallbackCoverageStatus, "Installed")
    XCTAssertEqual(store.setupMessage, "Backup blocking updated.")
  }

  func testRemoveLocalHostsFallbackClearsInstalledStatus() {
    let generator = FakeLocalHostsScriptGenerator()
    generator.installed = true
    let store = ProtectionStore(
      defaults: isolatedDefaults(),
      keychain: MemorySecretStore(secret: "secret"),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge(),
      localHostsScriptGenerator: generator
    )
    markBlockConnectorReady(store)

    store.removeLocalHostsFallback()

    XCTAssertTrue(generator.removed)
    XCTAssertFalse(store.localHostsFallbackInstalled)
    XCTAssertFalse(store.localHostsFallbackCurrent)
    XCTAssertEqual(store.setupMessage, "Backup blocking turned off.")
  }

  func testRefreshLocalSetupStatusTracksLocalHostsFallback() {
    let generator = FakeLocalHostsScriptGenerator()
    let store = ProtectionStore(
      defaults: isolatedDefaults(),
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge(),
      localHostsScriptGenerator: generator
    )

    XCTAssertFalse(store.localHostsFallbackInstalled)

    generator.installed = true
    store.refreshLocalSetupStatus()

    XCTAssertTrue(store.localHostsFallbackInstalled)
  }

  func testRefreshDoesNotSurfaceCancelledActivityRequests() async {
    let service = FakeLegacyProviderService(parentalControl: ParentalControl())
    service.analyticsError = URLError(.cancelled)
    service.blockedLogsError = URLError(.cancelled)
    let store = ProtectionStore(
      defaults: verifiedLegacyProviderDefaults(),
      keychain: MemorySecretStore(secret: "secret"),
      makeClient: { _ in service },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge()
    )

    await store.refresh()

    XCTAssertNil(store.errorMessage)
  }

  func testLegacyCustomDomainsMigrateToEnabledBlockedSiteRules() {
    let defaults = isolatedDefaults()
    defaults.set(["Example.com", "news.example", "example.com"], forKey: "quietgate.customDomains")

    let store = ProtectionStore(
      defaults: defaults,
      keychain: MemorySecretStore(),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge()
    )

    XCTAssertEqual(
      store.blockedSites,
      [
        BlockedSiteRule(domain: "example.com", isEnabled: true),
        BlockedSiteRule(domain: "news.example", isEnabled: true),
      ])
    XCTAssertEqual(blockedSiteDefaults(defaults), store.blockedSites)
  }

  func testInstalledLocalFallbackSyncChecksActualHostsContent() async throws {
    let generator = FakeLocalHostsScriptGenerator()
    let store = ProtectionStore(
      defaults: isolatedDefaults(),
      keychain: MemorySecretStore(secret: "secret"),
      makeClient: { _ in FakeLegacyProviderService(parentalControl: ParentalControl()) },
      resolverService: FakeResolverStatusService(),
      extensionBridge: FakeBrowserExtensionBridge(),
      localHostsScriptGenerator: generator
    )
    markBlockConnectorReady(store)
    try await store.addCustomDomain("example.com")
    store.installLocalBlockerBackup()

    XCTAssertTrue(store.localHostsFallbackSynced)

    generator.installedDomains = ["other.example"]

    XCTAssertTrue(store.localHostsFallbackConnected)
    XCTAssertFalse(store.localHostsFallbackSynced)
    XCTAssertTrue(store.localHostsFallbackMaintenanceNeeded)
  }

  private func blockedSiteDefaults(_ defaults: UserDefaults) -> [BlockedSiteRule] {
    let values = defaults.array(forKey: "quietgate.blockedSites") as? [[String: Any]] ?? []
    return values.compactMap { value in
      guard let domain = value["domain"] as? String else {
        return nil
      }
      let isEnabled: Bool
      if let bool = value["isEnabled"] as? Bool {
        isEnabled = bool
      } else if let number = value["isEnabled"] as? NSNumber {
        isEnabled = number.boolValue
      } else {
        isEnabled = true
      }
      return BlockedSiteRule(domain: domain, isEnabled: isEnabled)
    }
    .sorted { $0.domain < $1.domain }
  }

  private func pendingRemovalDefaults(_ defaults: UserDefaults) -> [String] {
    defaults.stringArray(forKey: "quietgate.pendingLegacyProviderRuleRemovals") ?? []
  }

  private func isolatedDefaults() -> UserDefaults {
    let suiteName = "QuietGateTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }

  private func browserFirstDefaults() -> UserDefaults {
    isolatedDefaults()
  }

  private func installedBrowsers(_ ids: Set<BrowserConnectorID>) -> (BrowserConnectorID) -> Bool {
    { ids.contains($0) }
  }

  private func markChromeConnected(
    _ store: ProtectionStore,
    bridge: FakeBrowserExtensionBridge? = nil,
    profile: String = "Default"
  ) {
    markBrowserConnected(store, .chrome, bridge: bridge, profile: profile)
  }

  private func markBrowserConnected(
    _ store: ProtectionStore,
    _ browser: BrowserConnectorID,
    bridge: FakeBrowserExtensionBridge? = nil,
    profile: String = "Default"
  ) {
    let status = ChromeExtensionStatus(
      selectedProfile: profile,
      profileCount: 1,
      loadedProfiles: [profile],
      disabledProfiles: [],
      sessionProfiles: []
    )
    bridge?.extensionLoadedBrowsers.insert(browser)
    bridge?.installedBrowsers.insert(browser)
    bridge?.helperStates[browser] = .current
    bridge?.extensionStatuses[browser] = status
    store.browserHelperStates[browser] = .current
    store.browserExtensionStatuses[browser] = status
    store.browserBridgeInstalled[browser] = true

    if browser == .chrome {
      bridge?.extensionLoaded = true
      bridge?.installed = true
      bridge?.helperState = .current
      bridge?.extensionStatus = status
      store.chromeHelperState = .current
      store.chromeExtensionLoaded = true
      store.chromeBridgeResponding = true
      store.chromeExtensionStatus = status
    }
  }

  private func verifiedLegacyProviderDefaults(profileID: String = "abc123") -> UserDefaults {
    let defaults = isolatedDefaults()
    defaults.set(profileID, forKey: "quietgate.profileID")
    defaults.set(profileID, forKey: "quietgate.legacyProviderVerifiedProfileID")
    return defaults
  }

  private func markBlockConnectorReady(_ store: ProtectionStore, profileID: String = "abc123") {
    let now = Date()
    store.profileID = profileID
    store.hasAPIKey = true
    store.legacyProviderKeyNeedsPermission = false
    store.legacyProviderVerifiedProfileID = profileID
    store.macOSLegacyProviderProfileInstalled = true
    store.macOSConfiguredLegacyProviderProfileInstalled = true
    store.resolverStatus = LegacyProviderResolverStatus(
      status: "ok",
      profile: profileID,
      client: nil,
      clientName: "apple-profile",
      protocolName: "DOH"
    )
    store.parentalControlCheckedAt = now
    store.legacyProviderRulesCheckedAt = now
    store.resolverStatusCheckedAt = now
    store.legacyProviderRulesSyncPending = false
  }

  private func localDate(hour: Int, minute: Int = 0) -> Date {
    var components = DateComponents()
    components.calendar = Calendar.current
    components.year = 2026
    components.month = 5
    components.day = 26
    components.hour = hour
    components.minute = minute
    return components.date!
  }

  private func blockedLogEntry() throws -> LegacyProviderLogEntry {
    let data = """
      {
        "id": "event-1",
        "timestamp": "2026-05-26T10:00:00Z",
        "domain": "example.com",
        "status": "blocked",
        "reasons": []
      }
      """.data(using: .utf8)!
    let decoder = JSONDecoder.legacyProviderDecoder()
    return try decoder.decode(LegacyProviderLogEntry.self, from: data)
  }
}

private final class TestLoginItemService: LoginItemServicing {
  var stateValue: MacStartupState

  init(state: MacStartupState) {
    stateValue = state
  }

  var state: MacStartupState {
    stateValue
  }

  func setEnabled(_ enabled: Bool) throws {
    stateValue = enabled ? .enabled : .off
  }
}
