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
