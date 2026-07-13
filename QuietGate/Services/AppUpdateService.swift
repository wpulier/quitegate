import AppKit
import Foundation

struct AppVersionIdentifier: Comparable, Equatable {
  let version: String
  let build: String

  var displayText: String {
    if version.isEmpty {
      return build
    }
    if build.isEmpty {
      return version
    }
    return "\(version) (\(build))"
  }

  static func < (lhs: AppVersionIdentifier, rhs: AppVersionIdentifier) -> Bool {
    let versionComparison = compareVersionText(lhs.version, rhs.version)
    if versionComparison != .orderedSame {
      return versionComparison == .orderedAscending
    }
    return compareVersionText(lhs.build, rhs.build) == .orderedAscending
  }

  static func fromInfoDictionary(_ dictionary: [String: Any]?) -> AppVersionIdentifier? {
    let version = (dictionary?["CFBundleShortVersionString"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let build = (dictionary?["CFBundleVersion"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !version.isEmpty || !build.isEmpty else {
      return nil
    }
    return AppVersionIdentifier(version: version, build: build)
  }

  private static func compareVersionText(_ lhs: String, _ rhs: String) -> ComparisonResult {
    let lhsParts = versionParts(lhs)
    let rhsParts = versionParts(rhs)
    let count = max(lhsParts.count, rhsParts.count)

    for index in 0..<count {
      let left = index < lhsParts.count ? lhsParts[index] : "0"
      let right = index < rhsParts.count ? rhsParts[index] : "0"
      if left == right {
        continue
      }

      if let leftNumber = Int(left), let rightNumber = Int(right) {
        if leftNumber < rightNumber {
          return .orderedAscending
        }
        if leftNumber > rightNumber {
          return .orderedDescending
        }
      } else {
        let comparison = left.localizedStandardCompare(right)
        if comparison != .orderedSame {
          return comparison
        }
      }
    }

    return .orderedSame
  }

  private static func versionParts(_ value: String) -> [String] {
    value
      .split { !$0.isLetter && !$0.isNumber }
      .map(String.init)
  }
}

struct AppUpdateInfo: Equatable {
  let currentVersion: AppVersionIdentifier
  let installedVersion: AppVersionIdentifier
  let installedAppURL: URL

  var detailText: String {
    "Tortoise \(installedVersion.displayText) is installed. Relaunch to use it."
  }
}

/// A newer Tortoise published to the release feed (GitHub Releases). Distinct
/// from `AppUpdateInfo`, which is a newer copy already sitting on this Mac.
struct RemoteAppRelease: Equatable {
  let version: AppVersionIdentifier
  let downloadURL: URL
  let releaseURL: URL
}

/// The published-release feed: parsing is pure and unit-tested; the fetch is a
/// thin URLSession wrapper. The repository also publishes browser-extension
/// releases, so the feed scans releases and selects the newest Mac app tag.
enum AppReleaseFeed {
  static let repo = "wpulier/quitegate"
  static let releasesAPIURL = URL(string: "https://api.github.com/repos/\(repo)/releases?per_page=30")!

  /// "v1.1-2" → version "1.1", build "2". Nil for anything else.
  static func versionIdentifier(fromTag tag: String) -> AppVersionIdentifier? {
    var trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("v") else {
      return nil
    }
    trimmed.removeFirst()
    let parts = trimmed.split(separator: "-", maxSplits: 1)
    guard let version = parts.first, !version.isEmpty else {
      return nil
    }
    return AppVersionIdentifier(
      version: String(version),
      build: parts.count > 1 ? String(parts[1]) : ""
    )
  }

  /// Decodes either one GitHub release or a release-list response. Browser
  /// releases such as `chrome-v1.0.0` are deliberately ignored.
  static func remoteRelease(fromJSON data: Data) -> RemoteAppRelease? {
    if let payloads = try? JSONDecoder().decode([Payload].self, from: data) {
      return payloads
        .compactMap(remoteRelease(from:))
        .max { $0.version < $1.version }
    }
    guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
      return nil
    }
    return remoteRelease(from: payload)
  }

  private struct Payload: Decodable {
    struct Asset: Decodable {
      let name: String
      let browserDownloadUrl: String

      enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
      }
    }

    let tagName: String
    let htmlUrl: String
    let draft: Bool?
    let prerelease: Bool?
    let assets: [Asset]?

    enum CodingKeys: String, CodingKey {
      case tagName = "tag_name"
      case htmlUrl = "html_url"
      case draft
      case prerelease
      case assets
    }
  }

  private static func remoteRelease(from payload: Payload) -> RemoteAppRelease? {
    guard payload.draft != true,
          payload.prerelease != true,
          let version = versionIdentifier(fromTag: payload.tagName),
          let releaseURL = URL(string: payload.htmlUrl) else {
      return nil
    }

    let assetURL = payload.assets?
      .first { $0.name == "Tortoise.dmg" }
      .flatMap { URL(string: $0.browserDownloadUrl) }
    let fallbackURL = URL(
      string: "https://github.com/\(repo)/releases/download/\(payload.tagName)/Tortoise.dmg"
    )
    guard let downloadURL = assetURL ?? fallbackURL else {
      return nil
    }

    return RemoteAppRelease(
      version: version,
      downloadURL: downloadURL,
      releaseURL: releaseURL
    )
  }
}

protocol AppUpdateServicing {
  func availableUpdate() -> AppUpdateInfo?
  func relaunch(using update: AppUpdateInfo) async throws
  func latestRemoteRelease() async -> RemoteAppRelease?
}

extension AppUpdateServicing {
  /// Test doubles and previews don't hit the network.
  func latestRemoteRelease() async -> RemoteAppRelease? { nil }
}

final class AppUpdateService: AppUpdateServicing {
  private let fileManager: FileManager
  private let currentBundleURL: URL
  private let currentVersion: AppVersionIdentifier
  private let candidateAppURLs: () -> [URL]

  init(
    fileManager: FileManager = .default,
    currentBundle: Bundle = .main,
    candidateAppURLs: (() -> [URL])? = nil
  ) {
    self.fileManager = fileManager
    currentBundleURL = currentBundle.bundleURL
    currentVersion = AppVersionIdentifier.fromInfoDictionary(currentBundle.infoDictionary)
      ?? AppVersionIdentifier(version: "", build: "")
    self.candidateAppURLs = candidateAppURLs
      ?? { Self.defaultCandidateAppURLs(fileManager: fileManager) }
  }

  init(
    fileManager: FileManager = .default,
    currentBundleURL: URL,
    currentVersion: AppVersionIdentifier,
    candidateAppURLs: @escaping () -> [URL]
  ) {
    self.fileManager = fileManager
    self.currentBundleURL = currentBundleURL
    self.currentVersion = currentVersion
    self.candidateAppURLs = candidateAppURLs
  }

  func availableUpdate() -> AppUpdateInfo? {
    let currentPath = normalizedPath(currentBundleURL)
    return candidateAppURLs()
      .compactMap { candidateURL -> AppUpdateInfo? in
        guard fileManager.fileExists(atPath: candidateURL.path),
              normalizedPath(candidateURL) != currentPath,
              let installedVersion = installedVersion(at: candidateURL),
              currentVersion < installedVersion else {
          return nil
        }
        return AppUpdateInfo(
          currentVersion: currentVersion,
          installedVersion: installedVersion,
          installedAppURL: candidateURL
        )
      }
      .max { lhs, rhs in
        lhs.installedVersion < rhs.installedVersion
      }
  }

  func relaunch(using update: AppUpdateInfo) async throws {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      NSWorkspace.shared.openApplication(
        at: update.installedAppURL,
        configuration: configuration
      ) { _, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
    await MainActor.run {
      NSApp.terminate(nil)
    }
  }

  func latestRemoteRelease() async -> RemoteAppRelease? {
    var request = URLRequest(url: AppReleaseFeed.releasesAPIURL)
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.timeoutInterval = 15
    guard let (data, response) = try? await URLSession.shared.data(for: request),
          (response as? HTTPURLResponse)?.statusCode == 200 else {
      return nil
    }
    return AppReleaseFeed.remoteRelease(fromJSON: data)
  }

  private func installedVersion(at appURL: URL) -> AppVersionIdentifier? {
    AppVersionIdentifier.fromInfoDictionary(Bundle(url: appURL)?.infoDictionary)
  }

  private func normalizedPath(_ url: URL) -> String {
    url.standardizedFileURL.resolvingSymlinksInPath().path
  }

  private static func defaultCandidateAppURLs(fileManager: FileManager) -> [URL] {
    var urls: [URL] = [
      URL(fileURLWithPath: "/Applications/Tortoise.app"),
      fileManager.homeDirectoryForCurrentUser
        .appendingPathComponent("Applications", isDirectory: true)
        .appendingPathComponent("Tortoise.app", isDirectory: true),
      URL(fileURLWithPath: "/Applications/QuietGate.app"),
      fileManager.homeDirectoryForCurrentUser
        .appendingPathComponent("Applications", isDirectory: true)
        .appendingPathComponent("QuietGate.app", isDirectory: true),
    ]

    if let bundleIdentifier = Bundle.main.bundleIdentifier,
       let locatedURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
      urls.append(locatedURL)
    }

    var seen: Set<String> = []
    return urls.filter { url in
      seen.insert(url.standardizedFileURL.resolvingSymlinksInPath().path).inserted
    }
  }
}
