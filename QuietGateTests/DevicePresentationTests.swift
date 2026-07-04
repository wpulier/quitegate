import XCTest
@testable import QuietGate

final class DevicePresentationTests: XCTestCase {
  private func device(platform: String?, name: String? = nil, lastSeenAt: String? = nil) -> TortoiseDevice {
    // TortoiseDevice is Decodable-only; build one from JSON to respect its coding keys.
    // Insert keys ONLY when non-nil — a nil boxed as `Any` is Optional.none, which is
    // not valid JSON and makes JSONSerialization throw. (A missing key decodes to nil.)
    var payload: [String: Any] = ["id": "d1"]
    if let platform { payload["platform"] = platform }
    if let name { payload["name"] = name }
    if let lastSeenAt { payload["last_seen_at"] = lastSeenAt }
    let data = try! JSONSerialization.data(withJSONObject: payload)
    return try! JSONDecoder().decode(TortoiseDevice.self, from: data)
  }

  func testKindClassification() {
    XCTAssertEqual(device(platform: "ios").deviceKind, .iphone)
    XCTAssertEqual(device(platform: "macos").deviceKind, .mac)
    XCTAssertEqual(device(platform: "mac").deviceKind, .mac)
    XCTAssertEqual(device(platform: "chrome_extension").deviceKind, .browser(brand: "chrome"))
    XCTAssertEqual(device(platform: "firefox_extension").deviceKind, .browser(brand: "firefox"))
    XCTAssertEqual(device(platform: "safari").deviceKind, .browser(brand: "safari"))
    XCTAssertEqual(device(platform: "watch").deviceKind, .other)
    XCTAssertEqual(device(platform: nil).deviceKind, .other)
  }

  func testIsBrowserProfile() {
    XCTAssertTrue(device(platform: "chrome_extension").isBrowserProfile)
    XCTAssertFalse(device(platform: "ios").isBrowserProfile)
  }

  func testDisplayNameFallsBackToKind() {
    XCTAssertEqual(device(platform: "ios", name: "Will's iPhone").displayName, "Will's iPhone")
    XCTAssertEqual(device(platform: "ios", name: "  ").displayName, "iPhone")
    XCTAssertEqual(device(platform: "chrome", name: nil).displayName, "Chrome")
  }

  func testInitials() {
    XCTAssertEqual(device(platform: "ios", name: "Will Pulier").initials, "WP")
    XCTAssertEqual(device(platform: "mac", name: nil).initials, "M")
  }

  func testBrandAssetNameOnlyForBrowsers() {
    XCTAssertEqual(device(platform: "chrome").brandAssetName, "BrandChrome")
    XCTAssertNil(device(platform: "ios").brandAssetName)
  }

  func testLastSeenDateParsesBothISOFormats() {
    XCTAssertNotNil(device(platform: "ios", lastSeenAt: "2026-07-04T00:00:00.123Z").lastSeenDate)
    XCTAssertNotNil(device(platform: "ios", lastSeenAt: "2026-07-04T00:00:00Z").lastSeenDate)
    XCTAssertNil(device(platform: "ios", lastSeenAt: nil).lastSeenDate)
    XCTAssertNil(device(platform: "ios", lastSeenAt: "not-a-date").lastSeenDate)
  }
}
