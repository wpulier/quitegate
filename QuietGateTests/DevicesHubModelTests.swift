import XCTest
@testable import QuietGate

final class DevicesHubModelTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 2_000_000_000)

  private func device(id: String, platform: String, name: String? = nil, minutesAgo: Double?) -> TortoiseDevice {
    var payload: [String: Any] = ["id": id, "platform": platform]
    if let name { payload["name"] = name }
    if let minutesAgo {
      payload["last_seen_at"] = DevicePresentationFormatters.withFractional
        .string(from: now.addingTimeInterval(-minutesAgo * 60))
    }
    let data = try! JSONSerialization.data(withJSONObject: payload)
    return try! JSONDecoder().decode(TortoiseDevice.self, from: data)
  }

  func testFreshDeviceIsOn() {
    let rows = DevicesHub.rows(devices: [device(id: "m", platform: "macos", minutesAgo: 1)], currentDeviceID: nil, now: now)
    XCTAssertEqual(rows.count, 1)
    XCTAssertEqual(rows[0].status, .on)
    XCTAssertEqual(rows[0].kind, .mac)
  }

  func testStaleDeviceIsAttentionStale() {
    let rows = DevicesHub.rows(devices: [device(id: "m", platform: "macos", minutesAgo: 30)], currentDeviceID: nil, now: now)
    XCTAssertEqual(rows[0].status, .attention(.stale))
  }

  func testNeverSeenDeviceIsSetupIncomplete() {
    let rows = DevicesHub.rows(devices: [device(id: "p", platform: "ios", minutesAgo: nil)], currentDeviceID: nil, now: now)
    XCTAssertEqual(rows[0].status, .attention(.setupIncomplete))
  }

  func testBrowserProfilesNestUnderOneBrowserRow() {
    let rows = DevicesHub.rows(devices: [
      device(id: "c1", platform: "chrome_extension", name: "willpulier1999@gmail.com", minutesAgo: 1),
      device(id: "c2", platform: "chrome_extension", name: "work", minutesAgo: 1),
    ], currentDeviceID: nil, now: now)
    let browserRows = rows.filter { if case .browser = $0.kind { return true } else { return false } }
    XCTAssertEqual(browserRows.count, 1, "both Chrome profiles nest under one Chrome row")
    XCTAssertEqual(browserRows[0].profiles.count, 2)
  }

  func testCurrentDeviceSortsFirst() {
    let rows = DevicesHub.rows(devices: [
      device(id: "old", platform: "ios", minutesAgo: 2),
      device(id: "me", platform: "macos", minutesAgo: 5),
    ], currentDeviceID: "me", now: now)
    XCTAssertEqual(rows.first?.id, "me")
    XCTAssertTrue(rows.first?.isCurrentDevice == true)
  }

  func testConnectedCountCountsOnLeaves() {
    // Two Chrome profiles, both on, nested under a single Chrome browser row.
    // Real (leaf) count = Mac(1) + c1(1) + c2(1) = 3 (stale iPhone not counted).
    // A naive container-counting bug (counting the Chrome row once) would give
    // Mac(1) + Chrome-row(1) = 2, so this discriminates the two implementations.
    let rows = DevicesHub.rows(devices: [
      device(id: "m", platform: "macos", minutesAgo: 1),              // on
      device(id: "p", platform: "ios", minutesAgo: 30),                // stale, attention
      device(id: "c1", platform: "chrome_extension", minutesAgo: 1),   // on (nested)
      device(id: "c2", platform: "chrome_extension", minutesAgo: 1),   // on (nested)
    ], currentDeviceID: nil, now: now)

    let browserRows = rows.filter { if case .browser = $0.kind { return true } else { return false } }
    XCTAssertEqual(browserRows.count, 1, "both Chrome profiles nest under one Chrome row")
    XCTAssertEqual(browserRows[0].profiles.count, 2)

    XCTAssertEqual(DevicesHub.connectedCount(rows), 3, "counts on-profiles (leaves), not container rows")
  }
}
