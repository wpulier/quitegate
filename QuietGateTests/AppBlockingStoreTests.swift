import Foundation
import Combine
import XCTest

@testable import QuietGate

@MainActor
final class AppBlockingStoreTests: XCTestCase {
  func testAddRunningApplicationPersistsAndRequestsQuit() {
    let defaults = isolatedDefaults()
    let service = FakeApplicationBlockingService(
      running: [
        RunningApplicationSnapshot(
          bundleIdentifier: "com.example.Distraction",
          displayName: "Distraction"
        )
      ]
    )
    let store = AppBlockingStore(defaults: defaults, service: service)

    store.addBlockedApplication(
      RunningApplicationSnapshot(
        bundleIdentifier: "com.example.Distraction",
        displayName: "Distraction"
      )
    )

    XCTAssertEqual(
      store.blockedApplications,
      [
        BlockedApplicationRule(
          bundleIdentifier: "com.example.Distraction",
          displayName: "Distraction",
          isEnabled: true,
          addedAt: store.blockedApplications[0].addedAt
        )
      ]
    )
    XCTAssertEqual(service.quitRequests, [Set(["com.example.Distraction"])])
    XCTAssertEqual(store.lastQuitResults.map(\.bundleIdentifier), ["com.example.Distraction"])
  }

  func testDisabledApplicationDoesNotQuit() {
    let service = FakeApplicationBlockingService(
      running: [
        RunningApplicationSnapshot(
          bundleIdentifier: "com.example.Chat",
          displayName: "Chat"
        )
      ]
    )
    let store = AppBlockingStore(defaults: isolatedDefaults(), service: service)

    store.addBlockedApplication(
      RunningApplicationSnapshot(
        bundleIdentifier: "com.example.Chat",
        displayName: "Chat"
      )
    )
    service.running = [
      RunningApplicationSnapshot(
        bundleIdentifier: "com.example.Chat",
        displayName: "Chat"
      )
    ]
    store.setBlockedApplication("com.example.Chat", enabled: false)
    _ = store.enforceNow()

    XCTAssertEqual(service.quitRequests.count, 1)
    XCTAssertFalse(store.blockedApplications[0].isEnabled)
  }

  func testReloadPreservesBlockedApplications() {
    let defaults = isolatedDefaults()
    let firstStore = AppBlockingStore(defaults: defaults, service: FakeApplicationBlockingService())
    firstStore.addBlockedApplication(
      RunningApplicationSnapshot(
        bundleIdentifier: "com.example.Video",
        displayName: "Video"
      )
    )

    let reloadedStore = AppBlockingStore(defaults: defaults, service: FakeApplicationBlockingService())

    XCTAssertEqual(reloadedStore.blockedApplications.map(\.bundleIdentifier), ["com.example.Video"])
    XCTAssertEqual(reloadedStore.blockedApplications.map(\.displayName), ["Video"])
    XCTAssertTrue(reloadedStore.blockedApplications.allSatisfy(\.isEnabled))
  }

  func testInstalledApplicationsCanBeSelectedWithoutRunning() {
    let app = RunningApplicationSnapshot(
      bundleIdentifier: "com.example.Writer",
      displayName: "Writer"
    )
    let service = FakeApplicationBlockingService(installed: [app], running: [])
    let store = AppBlockingStore(defaults: isolatedDefaults(), service: service)

    store.refreshAvailableApplications()

    XCTAssertEqual(store.availableApplications, [app])

    store.addBlockedApplication(app)

    XCTAssertEqual(store.blockedApplications.map(\.bundleIdentifier), ["com.example.Writer"])
    XCTAssertTrue(service.quitRequests.isEmpty)
  }

  func testMacServiceScansInstalledApplicationsByName() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("QuietGateInstalledApps-\(UUID().uuidString)", isDirectory: true)
    let contentsURL = root
      .appendingPathComponent("Focus Leak.app", isDirectory: true)
      .appendingPathComponent("Contents", isDirectory: true)
    try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
    defer {
      try? FileManager.default.removeItem(at: root)
    }

    let plist: [String: Any] = [
      "CFBundleIdentifier": "com.example.FocusLeak",
      "CFBundleName": "Focus Leak",
    ]
    let data = try PropertyListSerialization.data(
      fromPropertyList: plist,
      format: .xml,
      options: 0
    )
    try data.write(to: contentsURL.appendingPathComponent("Info.plist"))

    let service = MacApplicationBlockingService(applicationSearchRoots: [root])

    XCTAssertEqual(
      service.installedApplications(),
      [
        RunningApplicationSnapshot(
          bundleIdentifier: "com.example.FocusLeak",
          displayName: "Focus Leak"
        )
      ]
    )
  }

  func testProviderSnapshotShowsOwnedMacBlockingReadiness() {
    let app = RunningApplicationSnapshot(
      bundleIdentifier: "com.example.FocusLeak",
      displayName: "Focus Leak"
    )
    let store = AppBlockingStore(
      defaults: isolatedDefaults(),
      service: FakeApplicationBlockingService(running: [app])
    )

    XCTAssertEqual(store.providerSnapshot.id, .localMac)
    XCTAssertEqual(store.providerSnapshot.title, "QuietGate Mac Blocker")
    XCTAssertEqual(store.providerSnapshot.kind, .localMac)
    XCTAssertTrue(store.providerSnapshot.isReady)
    XCTAssertFalse(store.providerSnapshot.isLegacy)
    XCTAssertEqual(store.providerSnapshot.destinationNames, ["This Mac"])
    XCTAssertEqual(store.providerSnapshot.activeRuleCount, 0)

    store.addBlockedApplication(app)

    XCTAssertEqual(store.providerSnapshot.activeRuleCount, 1)
    XCTAssertTrue(store.providerSnapshot.state.detail.contains("1 app"))
  }

  func testInitializationDoesNotScanRunningApplications() {
    let service = FakeApplicationBlockingService(
      running: [
        RunningApplicationSnapshot(
          bundleIdentifier: "com.example.FocusLeak",
          displayName: "Focus Leak"
        )
      ]
    )

    _ = AppBlockingStore(defaults: isolatedDefaults(), service: service)

    XCTAssertEqual(service.runningRequestCount, 0)
  }

  func testProviderSnapshotShowsWhenAppClosingPaused() {
    let store = AppBlockingStore(defaults: isolatedDefaults(), service: FakeApplicationBlockingService())

    store.enforcementEnabled = false

    XCTAssertFalse(store.providerSnapshot.isReady)
    XCTAssertEqual(store.providerSnapshot.activeRuleCount, 0)
    XCTAssertEqual(store.providerSnapshot.destinationNames, ["This Mac"])
    XCTAssertTrue(store.providerSnapshot.state.detail.contains("paused"))
  }

  func testStartupConnectorTurnsOnLoginItem() {
    let loginItemService = FakeLoginItemService(state: .off)
    let store = AppBlockingStore(
      defaults: isolatedDefaults(),
      service: FakeApplicationBlockingService(),
      loginItemService: loginItemService
    )

    XCTAssertEqual(store.startupState, .off)

    store.setStartAtLoginEnabled(true)

    XCTAssertEqual(loginItemService.requests, [true])
    XCTAssertEqual(store.startupState, .enabled)
    XCTAssertEqual(store.startupMessage, "QuietGate will start when you sign in.")
    XCTAssertNil(store.startupErrorMessage)
  }

  func testStartupConnectorExplainsMacApproval() {
    let loginItemService = FakeLoginItemService(state: .off)
    loginItemService.stateAfterSet = .needsApproval
    let store = AppBlockingStore(
      defaults: isolatedDefaults(),
      service: FakeApplicationBlockingService(),
      loginItemService: loginItemService
    )

    store.setStartAtLoginEnabled(true)

    XCTAssertEqual(store.startupState, .needsApproval)
    XCTAssertEqual(
      store.startupMessage,
      "Approve QuietGate in System Settings > General > Login Items."
    )
  }

  func testMonitoringClosesBlockedAppWhenItLaunches() async {
    let app = RunningApplicationSnapshot(
      bundleIdentifier: "com.example.Game",
      displayName: "Game"
    )
    let service = FakeApplicationBlockingService(running: [])
    let store = AppBlockingStore(defaults: isolatedDefaults(), service: service)

    store.addBlockedApplication(app)
    XCTAssertEqual(service.quitRequests.count, 0)

    store.startMonitoring(interval: 600)
    XCTAssertEqual(service.observerCount, 1)

    service.running = [app]
    service.simulateLaunch()
    await Task.yield()

    XCTAssertEqual(service.quitRequests, [Set(["com.example.Game"])])
    XCTAssertEqual(store.lastQuitResults.map(\.bundleIdentifier), ["com.example.Game"])
  }

  func testStopMonitoringCancelsLaunchObserver() {
    let app = RunningApplicationSnapshot(
      bundleIdentifier: "com.example.Game",
      displayName: "Game"
    )
    let service = FakeApplicationBlockingService()
    let store = AppBlockingStore(defaults: isolatedDefaults(), service: service)
    store.addBlockedApplication(app)

    store.startMonitoring(interval: 600)
    store.stopMonitoring()
    service.simulateLaunch()

    XCTAssertEqual(service.observerCount, 1)
    XCTAssertEqual(service.canceledObserverCount, 1)
    XCTAssertTrue(service.quitRequests.isEmpty)
  }

  func testMonitoringStaysIdleWithoutBlockedApps() {
    let service = FakeApplicationBlockingService()
    let store = AppBlockingStore(defaults: isolatedDefaults(), service: service)
    let initialRunningRequestCount = service.runningRequestCount

    store.startMonitoring(interval: 600)
    service.simulateLaunch()

    XCTAssertEqual(service.observerCount, 0)
    XCTAssertEqual(service.runningRequestCount, initialRunningRequestCount)
    XCTAssertTrue(service.quitRequests.isEmpty)
  }

  private func isolatedDefaults() -> UserDefaults {
    let suiteName = "QuietGateAppBlockingTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }
}

private final class FakeLoginItemService: LoginItemServicing {
  var stateValue: MacStartupState
  var stateAfterSet: MacStartupState?
  var requests: [Bool] = []

  init(state: MacStartupState) {
    stateValue = state
  }

  var state: MacStartupState {
    stateValue
  }

  func setEnabled(_ enabled: Bool) throws {
    requests.append(enabled)
    if let stateAfterSet {
      stateValue = stateAfterSet
    } else {
      stateValue = enabled ? .enabled : .off
    }
  }
}

private final class FakeApplicationBlockingService: ApplicationBlockingServicing {
  var installed: [RunningApplicationSnapshot]
  var running: [RunningApplicationSnapshot]
  var quitRequests: [Set<String>] = []
  private(set) var runningRequestCount = 0
  private var launchHandlers: [UUID: () -> Void] = [:]
  private(set) var observerCount = 0
  private(set) var canceledObserverCount = 0

  init(
    installed: [RunningApplicationSnapshot] = [],
    running: [RunningApplicationSnapshot] = []
  ) {
    self.installed = installed
    self.running = running
  }

  func runningApplications() -> [RunningApplicationSnapshot] {
    runningRequestCount += 1
    return running
  }

  func installedApplications() -> [RunningApplicationSnapshot] {
    installed
  }

  func quitApplications(bundleIdentifiers: Set<String>) -> [ApplicationQuitResult] {
    quitRequests.append(bundleIdentifiers)
    let matches = running.filter { bundleIdentifiers.contains($0.bundleIdentifier) }
    running.removeAll { bundleIdentifiers.contains($0.bundleIdentifier) }
    return matches.map {
      ApplicationQuitResult(
        bundleIdentifier: $0.bundleIdentifier,
        displayName: $0.displayName,
        didRequestQuit: true
      )
    }
  }

  func observeApplicationLaunches(_ handler: @escaping () -> Void) -> AnyCancellable {
    let id = UUID()
    observerCount += 1
    launchHandlers[id] = handler
    return AnyCancellable { [weak self] in
      self?.canceledObserverCount += 1
      self?.launchHandlers.removeValue(forKey: id)
    }
  }

  func simulateLaunch() {
    launchHandlers.values.forEach { $0() }
  }
}
