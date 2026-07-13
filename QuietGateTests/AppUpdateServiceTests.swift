import XCTest
@testable import QuietGate

final class AppUpdateServiceTests: XCTestCase {
  func testDetectsNewerInstalledBuild() throws {
    let root = try temporaryDirectory()
    let currentURL = try writeAppBundle(
      named: "Current.app",
      version: "1.0",
      build: "1",
      in: root
    )
    let installedURL = try writeAppBundle(
      named: "QuietGate.app",
      version: "1.0",
      build: "2",
      in: root
    )
    let service = AppUpdateService(
      currentBundleURL: currentURL,
      currentVersion: AppVersionIdentifier(version: "1.0", build: "1"),
      candidateAppURLs: { [installedURL] }
    )

    let update = try XCTUnwrap(service.availableUpdate())

    XCTAssertEqual(update.installedAppURL, installedURL)
    XCTAssertEqual(update.currentVersion, AppVersionIdentifier(version: "1.0", build: "1"))
    XCTAssertEqual(update.installedVersion, AppVersionIdentifier(version: "1.0", build: "2"))
  }

  func testDetectsNewerInstalledMarketingVersion() throws {
    let root = try temporaryDirectory()
    let currentURL = try writeAppBundle(
      named: "Current.app",
      version: "1.9",
      build: "9",
      in: root
    )
    let installedURL = try writeAppBundle(
      named: "QuietGate.app",
      version: "1.10",
      build: "1",
      in: root
    )
    let service = AppUpdateService(
      currentBundleURL: currentURL,
      currentVersion: AppVersionIdentifier(version: "1.9", build: "9"),
      candidateAppURLs: { [installedURL] }
    )

    XCTAssertEqual(
      service.availableUpdate()?.installedVersion,
      AppVersionIdentifier(version: "1.10", build: "1")
    )
  }

  func testIgnoresSameOlderAndCurrentBundleCandidates() throws {
    let root = try temporaryDirectory()
    let currentURL = try writeAppBundle(
      named: "QuietGate.app",
      version: "2.0",
      build: "1",
      in: root
    )
    let olderURL = try writeAppBundle(
      named: "Older.app",
      version: "1.9",
      build: "9",
      in: root
    )
    let sameURL = try writeAppBundle(
      named: "Same.app",
      version: "2.0",
      build: "1",
      in: root
    )
    let service = AppUpdateService(
      currentBundleURL: currentURL,
      currentVersion: AppVersionIdentifier(version: "2.0", build: "1"),
      candidateAppURLs: { [currentURL, olderURL, sameURL] }
    )

    XCTAssertNil(service.availableUpdate())
  }

  // MARK: Release feed (published-version awareness)

  func testReleaseTagParsing() {
    XCTAssertEqual(
      AppReleaseFeed.versionIdentifier(fromTag: "v1.1-2"),
      AppVersionIdentifier(version: "1.1", build: "2")
    )
    XCTAssertEqual(
      AppReleaseFeed.versionIdentifier(fromTag: "v1.0-202607031226"),
      AppVersionIdentifier(version: "1.0", build: "202607031226")
    )
    XCTAssertEqual(
      AppReleaseFeed.versionIdentifier(fromTag: "v2.0"),
      AppVersionIdentifier(version: "2.0", build: "")
    )
    XCTAssertNil(AppReleaseFeed.versionIdentifier(fromTag: "1.1-2"))
    XCTAssertNil(AppReleaseFeed.versionIdentifier(fromTag: "v"))
    XCTAssertNil(AppReleaseFeed.versionIdentifier(fromTag: ""))
  }

  func testReleaseFeedJSONDecoding() throws {
    let json = """
    {"tag_name":"v1.2-14","html_url":"https://github.com/wpulier/quitegate/releases/tag/v1.2-14","name":"Tortoise 1.2 (14)","assets":[{"name":"Tortoise.dmg","browser_download_url":"https://github.com/wpulier/quitegate/releases/download/v1.2-14/Tortoise.dmg"}]}
    """
    let release = try XCTUnwrap(AppReleaseFeed.remoteRelease(fromJSON: Data(json.utf8)))
    XCTAssertEqual(release.version, AppVersionIdentifier(version: "1.2", build: "14"))
    XCTAssertEqual(
      release.downloadURL.absoluteString,
      "https://github.com/wpulier/quitegate/releases/download/v1.2-14/Tortoise.dmg"
    )
    XCTAssertEqual(release.releaseURL.absoluteString, "https://github.com/wpulier/quitegate/releases/tag/v1.2-14")
  }

  func testReleaseFeedSkipsNewerChromeReleaseAndFindsMacUpdate() throws {
    let json = """
    [
      {"tag_name":"chrome-v1.0.1","html_url":"https://github.com/wpulier/quitegate/releases/tag/chrome-v1.0.1"},
      {"tag_name":"v1.1-16","html_url":"https://github.com/wpulier/quitegate/releases/tag/v1.1-16","assets":[{"name":"Tortoise.dmg","browser_download_url":"https://github.com/wpulier/quitegate/releases/download/v1.1-16/Tortoise.dmg"}]},
      {"tag_name":"v1.1-15","html_url":"https://github.com/wpulier/quitegate/releases/tag/v1.1-15"}
    ]
    """

    let release = try XCTUnwrap(AppReleaseFeed.remoteRelease(fromJSON: Data(json.utf8)))

    XCTAssertEqual(release.version, AppVersionIdentifier(version: "1.1", build: "16"))
    XCTAssertEqual(
      release.downloadURL.absoluteString,
      "https://github.com/wpulier/quitegate/releases/download/v1.1-16/Tortoise.dmg"
    )
  }

  func testReleaseFeedRejectsGarbage() {
    XCTAssertNil(AppReleaseFeed.remoteRelease(fromJSON: Data("not json".utf8)))
    XCTAssertNil(AppReleaseFeed.remoteRelease(fromJSON: Data(#"{"tag_name":"nightly","html_url":"https://x.y"}"#.utf8)))
  }

  func testRemoteVersionComparisonGatesOnNewer() {
    // Same logic the store uses to decide whether to surface the Get button.
    let current = AppVersionIdentifier(version: "1.1", build: "2")
    XCTAssertTrue(current < AppVersionIdentifier(version: "1.1", build: "13"))
    XCTAssertTrue(current < AppVersionIdentifier(version: "1.2", build: "1"))
    XCTAssertFalse(current < AppVersionIdentifier(version: "1.1", build: "2"))
    XCTAssertFalse(current < AppVersionIdentifier(version: "1.0", build: "99"))
  }

  private func writeAppBundle(
    named name: String,
    version: String,
    build: String,
    in root: URL
  ) throws -> URL {
    let appURL = root.appendingPathComponent(name, isDirectory: true)
    let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
    try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
    let info: [String: Any] = [
      "CFBundleIdentifier": "com.willpulier.QuietGate",
      "CFBundleName": "QuietGate",
      "CFBundlePackageType": "APPL",
      "CFBundleShortVersionString": version,
      "CFBundleVersion": build,
    ]
    let data = try PropertyListSerialization.data(
      fromPropertyList: info,
      format: .xml,
      options: 0
    )
    try data.write(to: contentsURL.appendingPathComponent("Info.plist"))
    return appURL
  }

  private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("QuietGateTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: url)
    }
    return url
  }
}
