import XCTest
@testable import QuietGate

final class TuneScopeModelTests: XCTestCase {
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

  private func iosState(
    safari: IOSSafariExtensionState,
    acknowledged: Bool = false,
    heartbeatFresh: Bool = false,
    devices: [TortoiseDevice] = []
  ) -> TuneScopeState {
    TuneScope.iosState(
      safariExtensionState: safari,
      safariAcknowledged: acknowledged,
      safariHeartbeatFresh: heartbeatFresh,
      devices: devices,
      now: now
    )
  }

  // MARK: safariConnectionStatus — all extension states map onto the canonical status

  func testSafariConnectedIsOn() {
    XCTAssertEqual(
      TuneScope.safariConnectionStatus(state: .connected, acknowledged: false, heartbeatFresh: false),
      .on
    )
  }

  func testSafariWaitingAndUnknownAreCatchingUp() {
    XCTAssertEqual(
      TuneScope.safariConnectionStatus(state: .enabledWaitingForHeartbeat, acknowledged: false, heartbeatFresh: false),
      .attention(.catchingUp)
    )
    XCTAssertEqual(
      TuneScope.safariConnectionStatus(state: .unknown, acknowledged: false, heartbeatFresh: false),
      .attention(.catchingUp)
    )
  }

  func testSafariDisabledAndFailedAreSetupIncomplete() {
    XCTAssertEqual(
      TuneScope.safariConnectionStatus(state: .disabled, acknowledged: true, heartbeatFresh: true),
      .attention(.setupIncomplete)
    )
    XCTAssertEqual(
      TuneScope.safariConnectionStatus(state: .failed, acknowledged: true, heartbeatFresh: true),
      .attention(.setupIncomplete)
    )
  }

  func testSafariUnavailableMirrorsManualAcknowledgementAndHeartbeat() {
    // Mirrors IOSYouTubeScreenTimeController.safariExtensionConnected: manual
    // setup counts as connected only when acknowledged AND the heartbeat is fresh.
    XCTAssertEqual(
      TuneScope.safariConnectionStatus(state: .unavailable, acknowledged: true, heartbeatFresh: true),
      .on
    )
    XCTAssertEqual(
      TuneScope.safariConnectionStatus(state: .unavailable, acknowledged: true, heartbeatFresh: false),
      .attention(.setupIncomplete)
    )
    XCTAssertEqual(
      TuneScope.safariConnectionStatus(state: .unavailable, acknowledged: false, heartbeatFresh: true),
      .attention(.setupIncomplete)
    )
  }

  // MARK: safariHint — one action line for attention states, silence when on

  func testSafariHintIsNilWhenConnected() {
    XCTAssertNil(TuneScope.safariHint(state: .connected, acknowledged: false, heartbeatFresh: false))
    XCTAssertNil(TuneScope.safariHint(state: .unavailable, acknowledged: true, heartbeatFresh: true))
  }

  func testSafariHintNamesTheNextStep() {
    XCTAssertEqual(
      TuneScope.safariHint(state: .disabled, acknowledged: false, heartbeatFresh: false),
      TuneScopeCopy.safariHintNeedsSetup
    )
    XCTAssertEqual(
      TuneScope.safariHint(state: .enabledWaitingForHeartbeat, acknowledged: false, heartbeatFresh: false),
      TuneScopeCopy.safariHintVerify
    )
    XCTAssertEqual(
      TuneScope.safariHint(state: .failed, acknowledged: false, heartbeatFresh: false),
      TuneScopeCopy.safariHintNeedsSetup
    )
  }

  // MARK: iosState — the iPhone-only user (the dishonesty being fixed)

  func testIPhoneOnlyUserSeesSafariSurfaceIndependentOfDeviceList() {
    let state = iosState(safari: .connected)
    XCTAssertEqual(state.iphoneSafari.kind, .iphoneSafari)
    XCTAssertEqual(state.iphoneSafari.title, TuneScopeCopy.iphoneSafariChip)
    XCTAssertEqual(state.iphoneSafari.status, .on)
    XCTAssertTrue(state.desktopProfiles.isEmpty)
    XCTAssertTrue(state.showAddComputerAffordance)
    XCTAssertTrue(state.hasAnyActiveSurface)
    XCTAssertFalse(state.showSetupFirstBanner)
  }

  func testDesktopProfileFreshnessBoundary() {
    let state = iosState(safari: .disabled, devices: [
      device(id: "fresh", platform: "chrome_extension", name: "personal", minutesAgo: 14),
      device(id: "stale", platform: "chrome_extension", name: "work", minutesAgo: 16),
    ])
    XCTAssertEqual(state.desktopProfiles.count, 2)
    XCTAssertEqual(state.desktopProfiles.first { $0.id == "fresh" }!.status, .on)
    XCTAssertEqual(state.desktopProfiles.first { $0.id == "stale" }!.status, .attention(.stale))
    XCTAssertFalse(state.showAddComputerAffordance)
    XCTAssertTrue(state.hasAnyActiveSurface)  // the fresh chrome profile
  }

  func testZeroActiveSurfacesShowsSetupFirstBanner() {
    let state = iosState(safari: .disabled, devices: [
      device(id: "stale", platform: "chrome_extension", name: "work", minutesAgo: 60),
    ])
    XCTAssertFalse(state.hasAnyActiveSurface)
    XCTAssertTrue(state.showSetupFirstBanner)
  }

  func testUnknownSafariStateNeverFlashesTheBanner() {
    // At launch the extension state is .unknown for a beat; the banner must not flash.
    let state = iosState(safari: .unknown)
    XCTAssertFalse(state.hasAnyActiveSurface)
    XCTAssertFalse(state.showSetupFirstBanner)
  }

  func testMacAndIPhoneDevicesAreExcludedFromDesktopProfiles() {
    let state = iosState(safari: .connected, devices: [
      device(id: "mac", platform: "macos", name: "Will's MacBook", minutesAgo: 1),
      device(id: "phone", platform: "ios", name: "Will's iPhone", minutesAgo: 1),
      device(id: "ff", platform: "firefox_extension", name: "default", minutesAgo: 1),
    ])
    XCTAssertEqual(state.desktopProfiles.map(\.id), ["ff"])
    XCTAssertEqual(state.desktopProfiles[0].kind, .desktopProfile(brand: "firefox"))
  }

  func testDesktopProfileTitleNamesBrandAndProfile() {
    let state = iosState(safari: .connected, devices: [
      device(id: "c", platform: "chrome_extension", name: "will@wildstudio.ai", minutesAgo: 1),
    ])
    XCTAssertEqual(state.desktopProfiles[0].title, "Chrome · will@wildstudio.ai")
  }

  func testDesktopProfilesOrderNewestFirst() {
    let state = iosState(safari: .connected, devices: [
      device(id: "older", platform: "chrome_extension", name: "a", minutesAgo: 10),
      device(id: "newer", platform: "chrome_extension", name: "b", minutesAgo: 1),
      device(id: "never", platform: "chrome_extension", name: "c", minutesAgo: nil),
    ])
    XCTAssertEqual(state.desktopProfiles.map(\.id), ["newer", "older", "never"])
  }

  // MARK: macIPhoneEntries — the Mac scope card's iPhone chip

  func testMacIPhoneEntriesUseDeviceFreshness() {
    let fresh = TuneScope.macIPhoneEntries(
      devices: [device(id: "p", platform: "ios", name: "Will's iPhone", minutesAgo: 1)], now: now
    )
    XCTAssertEqual(fresh.count, 1)
    XCTAssertEqual(fresh[0].status, .on)
    XCTAssertEqual(fresh[0].kind, .iphoneSafari)
    XCTAssertEqual(fresh[0].title, "Will's iPhone · Safari")

    let stale = TuneScope.macIPhoneEntries(
      devices: [device(id: "p", platform: "ios", minutesAgo: 60)], now: now
    )
    XCTAssertEqual(stale[0].status, .attention(.stale))
    XCTAssertEqual(stale[0].title, "iPhone · Safari")
  }

  func testMacIPhoneEntriesEmptyWithoutIOSDevices() {
    let entries = TuneScope.macIPhoneEntries(
      devices: [device(id: "m", platform: "macos", minutesAgo: 1),
                device(id: "c", platform: "chrome_extension", minutesAgo: 1)],
      now: now
    )
    XCTAssertTrue(entries.isEmpty)
  }

  func testMacIPhoneEntriesOnePerIPhone() {
    let entries = TuneScope.macIPhoneEntries(
      devices: [device(id: "p1", platform: "ios", name: "Will's iPhone", minutesAgo: 1),
                device(id: "p2", platform: "ios", name: "Kid's iPhone", minutesAgo: 1)],
      now: now
    )
    XCTAssertEqual(entries.map(\.id), ["p1", "p2"])
  }
}
