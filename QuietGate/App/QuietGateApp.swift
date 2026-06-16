import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    guard !ProcessInfo.processInfo.isRunningUnitTests else {
      return
    }

    NSApp.setActivationPolicy(.regular)
    DispatchQueue.main.async {
      NSApp.activate(ignoringOtherApps: true)
    }
  }
}

private extension ProcessInfo {
  var isRunningUnitTests: Bool {
    environment["XCTestConfigurationFilePath"] != nil
  }
}

@main
struct QuietGateApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var store: ProtectionStore
  @StateObject private var appBlockingStore: AppBlockingStore

  init() {
    _store = StateObject(wrappedValue: Self.makeStore())
    _appBlockingStore = StateObject(wrappedValue: AppBlockingStore())
  }

  var body: some Scene {
    WindowGroup("QuietGate", id: "main") {
      ContentView()
        .environmentObject(store)
        .environmentObject(appBlockingStore)
        .task {
          guard !ProcessInfo.processInfo.isRunningUnitTests else {
            return
          }

          appBlockingStore.startMonitoring()
          await store.evaluateFocusWindowSchedule()
        }
    }
    .defaultSize(width: 1040, height: 760)
    .commands {
      CommandGroup(replacing: .newItem) {}
      CommandGroup(replacing: .appTermination) {
        Button("Quit QuietGate") {
          NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
        .disabled(store.timedSessionLockedActive)
      }
    }

    MenuBarExtra {
      MenuBarContentView()
        .environmentObject(store)
        .environmentObject(appBlockingStore)
    } label: {
      Image(systemName: store.mode.systemImage)
    }
    .menuBarExtraStyle(.menu)
  }

  private static func makeStore() -> ProtectionStore {
    guard ProcessInfo.processInfo.isRunningUnitTests else {
      ProtectionStore.disableLegacyProviderConnector()
      return ProtectionStore(
        keychain: DisabledLegacySecretStore()
      )
    }

    let defaults =
      UserDefaults(suiteName: "QuietGate.AppHostTests.\(UUID().uuidString)") ?? .standard
    ProtectionStore.disableLegacyProviderConnector(in: defaults)
    return ProtectionStore(
      defaults: defaults,
      keychain: DisabledLegacySecretStore(),
      extensionBridge: AppHostNoopBrowserExtensionBridge(),
      appUpdateService: AppHostNoopAppUpdateService(),
      localHostsScriptGenerator: AppHostNoopLocalHostsScriptGenerator()
    )
  }
}

private struct AppHostNoopBrowserExtensionBridge: BrowserExtensionBridging {
  var chromeExtensionDirectoryURL: URL { FileManager.default.temporaryDirectory }
  var settingsURL: URL { FileManager.default.temporaryDirectory.appendingPathComponent("noop.json") }
  var chromeStatusURL: URL { FileManager.default.temporaryDirectory.appendingPathComponent("noop-status.json") }
  var installedNativeHostURL: URL { FileManager.default.temporaryDirectory }
  var nativeMessagingManifestURL: URL { FileManager.default.temporaryDirectory }
  func extensionDirectoryURL(for browser: BrowserConnectorID) -> URL { FileManager.default.temporaryDirectory }
  func chromeExtensionAvailable() -> Bool { false }
  func chromeExtensionStatus() -> ChromeExtensionStatus { .empty }
  func chromeExtensionLoaded() -> Bool { false }
  func writeSettings(_ settings: BrowserTuningSettings) throws {}
  func installNativeMessagingHost() throws {}
  func nativeMessagingHostInstalled() -> Bool { false }
  func chromeHelperSnapshot() -> ChromeHelperSnapshot? { nil }
  func chromeHelperState(currentSettingsVersion: String, now: Date) -> ChromeHelperState { .notInstalled }
  func extensionAvailable(for browser: BrowserConnectorID) -> Bool { false }
  func extensionStatus(for browser: BrowserConnectorID) -> ChromeExtensionStatus { .empty }
  func extensionLoaded(for browser: BrowserConnectorID) -> Bool { false }
  func installNativeMessagingHost(for browser: BrowserConnectorID) throws {}
  func nativeMessagingHostInstalled(for browser: BrowserConnectorID) -> Bool { false }
  func helperSnapshot(for browser: BrowserConnectorID) -> ChromeHelperSnapshot? { nil }
  func helperState(
    for browser: BrowserConnectorID,
    currentSettingsVersion: String,
    now: Date
  ) -> ChromeHelperState { .notInstalled }
  func helperState(
    for browser: BrowserConnectorID,
    currentSettingsVersion: String,
    now: Date,
    extensionStatus: ChromeExtensionStatus
  ) -> ChromeHelperState { .notInstalled }
  func nativeMessagingManifestURL(for browser: BrowserConnectorID) -> URL {
    FileManager.default.temporaryDirectory
  }
  func statusWatchURLs(for browser: BrowserConnectorID) -> [URL] { [] }
}

private struct AppHostNoopLocalHostsScriptGenerator: LocalHostsBlockerScriptGenerating {
  func writeScript(domains: [String]) throws -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("quietgate-hosts.sh")
  }

  func installBlocklist(domains: [String]) throws {}
  func removeBlocklist() throws {}
  func localHostsBlocklistInstalled() -> Bool { false }
  func localHostsBlocklistMatches(domains: [String]) -> Bool { false }
}

private struct AppHostNoopAppUpdateService: AppUpdateServicing {
  func availableUpdate() -> AppUpdateInfo? { nil }
  func relaunch(using update: AppUpdateInfo) async throws {}
}
