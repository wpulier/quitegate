import AppKit
import Combine
import Foundation

protocol ApplicationBlockingServicing {
  func runningApplications() -> [RunningApplicationSnapshot]
  func installedApplications() -> [RunningApplicationSnapshot]
  func quitApplications(bundleIdentifiers: Set<String>) -> [ApplicationQuitResult]
  func observeApplicationLaunches(_ handler: @escaping () -> Void) -> AnyCancellable
}

final class MacApplicationBlockingService: ApplicationBlockingServicing {
  private let fileManager: FileManager
  private let currentBundleIdentifier: String?
  private let applicationSearchRoots: [URL]

  init(
    fileManager: FileManager = .default,
    currentBundleIdentifier: String? = Bundle.main.bundleIdentifier,
    applicationSearchRoots: [URL]? = nil
  ) {
    self.fileManager = fileManager
    self.currentBundleIdentifier = currentBundleIdentifier
    self.applicationSearchRoots = applicationSearchRoots ?? Self.defaultApplicationSearchRoots(fileManager: fileManager)
  }

  func runningApplications() -> [RunningApplicationSnapshot] {
    let apps = NSWorkspace.shared.runningApplications.compactMap { app -> RunningApplicationSnapshot? in
      guard app.activationPolicy == .regular,
            let bundleIdentifier = app.bundleIdentifier,
            bundleIdentifier != currentBundleIdentifier
      else {
        return nil
      }

      return RunningApplicationSnapshot(
        bundleIdentifier: bundleIdentifier,
        displayName: Self.displayName(for: app, fallback: bundleIdentifier)
      )
    }

    return Self.deduplicate(apps)
      .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
  }

  func installedApplications() -> [RunningApplicationSnapshot] {
    var apps: [RunningApplicationSnapshot] = []
    for root in applicationSearchRoots where fileManager.fileExists(atPath: root.path) {
      guard let enumerator = fileManager.enumerator(
        at: root,
        includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
        options: [.skipsHiddenFiles]
      ) else {
        continue
      }

      for case let url as URL in enumerator {
        guard url.pathExtension.caseInsensitiveCompare("app") == .orderedSame else {
          continue
        }
        enumerator.skipDescendants()

        guard let snapshot = Self.applicationSnapshot(
          forBundleAt: url,
          currentBundleIdentifier: currentBundleIdentifier
        ) else {
          continue
        }
        apps.append(snapshot)
      }
    }

    return Self.deduplicate(apps)
      .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
  }

  func quitApplications(bundleIdentifiers: Set<String>) -> [ApplicationQuitResult] {
    guard !bundleIdentifiers.isEmpty else {
      return []
    }

    return NSWorkspace.shared.runningApplications.compactMap { app in
      guard let bundleIdentifier = app.bundleIdentifier,
            bundleIdentifiers.contains(bundleIdentifier)
      else {
        return nil
      }

      return ApplicationQuitResult(
        bundleIdentifier: bundleIdentifier,
        displayName: Self.displayName(for: app, fallback: bundleIdentifier),
        didRequestQuit: app.terminate() || app.forceTerminate()
      )
    }
  }

  func observeApplicationLaunches(_ handler: @escaping () -> Void) -> AnyCancellable {
    let center = NSWorkspace.shared.notificationCenter
    let observer = center.addObserver(
      forName: NSWorkspace.didLaunchApplicationNotification,
      object: nil,
      queue: .main
    ) { _ in
      handler()
    }

    return AnyCancellable {
      center.removeObserver(observer)
    }
  }

  private static func displayName(
    for app: NSRunningApplication,
    fallback: String
  ) -> String {
    if let localizedName = app.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines),
       !localizedName.isEmpty
    {
      return localizedName
    }
    if let bundleName = app.bundleURL?.deletingPathExtension().lastPathComponent,
       !bundleName.isEmpty
    {
      return bundleName
    }
    return fallback
  }

  private static func applicationSnapshot(
    forBundleAt url: URL,
    currentBundleIdentifier: String?
  ) -> RunningApplicationSnapshot? {
    guard let bundle = Bundle(url: url),
          let bundleIdentifier = bundle.bundleIdentifier,
          bundleIdentifier != currentBundleIdentifier
    else {
      return nil
    }

    let displayName =
      bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String
      ?? bundle.localizedInfoDictionary?["CFBundleName"] as? String
      ?? bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
      ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
      ?? url.deletingPathExtension().lastPathComponent

    return RunningApplicationSnapshot(
      bundleIdentifier: bundleIdentifier,
      displayName: displayName
    )
  }

  private static func defaultApplicationSearchRoots(fileManager: FileManager) -> [URL] {
    [
      URL(fileURLWithPath: "/Applications", isDirectory: true),
      fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
      URL(fileURLWithPath: "/System/Applications", isDirectory: true),
      URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true),
    ]
  }

  private static func deduplicate(
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
    return unique
  }
}
