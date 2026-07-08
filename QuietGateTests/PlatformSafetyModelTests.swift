import XCTest
@testable import QuietGate

/// Guards the X account-setting honesty row: the mapping from an observed (or
/// never-observed) platform-controls snapshot to exactly one status, and the
/// App Group round-trip the Safari extension handler uses to record it.
final class PlatformSafetyModelTests: XCTestCase {
  private func snapshot(site: String = "x", controls: [String: Bool]) -> PlatformControlsSnapshot {
    PlatformControlsSnapshot(site: site, observedAt: Date(timeIntervalSince1970: 2_000_000_000), controls: controls)
  }

  func testNeverObservedIsUnknown() {
    XCTAssertEqual(XPlatformSafety.status(snapshot: nil), .unknown)
  }

  func testObservedWithoutTheControlIsUnknown() {
    // The observer was on a settings page but could not read this control.
    XCTAssertEqual(XPlatformSafety.status(snapshot: snapshot(controls: ["hideSensitiveSearch": true])), .unknown)
  }

  func testDisplaySensitiveMediaOnIsExposed() {
    XCTAssertEqual(XPlatformSafety.status(snapshot: snapshot(controls: ["displaySensitiveMedia": true])), .exposed)
  }

  func testDisplaySensitiveMediaOffIsProtected() {
    XCTAssertEqual(XPlatformSafety.status(snapshot: snapshot(controls: ["displaySensitiveMedia": false])), .protected)
  }

  func testWrongSiteSnapshotIsUnknown() {
    XCTAssertEqual(XPlatformSafety.status(snapshot: snapshot(site: "reddit", controls: ["displaySensitiveMedia": true])), .unknown)
  }

  func testActionTitlePresentExactlyWhenActionable() {
    XCTAssertNotNil(XPlatformSafety.actionTitle(for: .unknown))
    XCTAssertNotNil(XPlatformSafety.actionTitle(for: .exposed))
    XCTAssertNil(XPlatformSafety.actionTitle(for: .protected))
  }

  func testEveryStatusHasDistinctDetailCopy() {
    let details = [
      XPlatformSafety.detail(for: .unknown),
      XPlatformSafety.detail(for: .exposed),
      XPlatformSafety.detail(for: .protected),
    ]
    XCTAssertEqual(Set(details).count, 3)
    details.forEach { XCTAssertFalse($0.isEmpty) }
  }

  // MARK: store round-trip (what SafariWebExtensionHandler records)

  func testRecordPlatformControlsRoundTripsBooleansOnly() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    IOSEnforcementSharedStore.recordPlatformControls(
      payload: [
        "site": "x",
        "url": "https://x.com/settings/content_you_see",
        "checkedAt": "2026-07-08T14:00:00Z",
        "displaySensitiveMedia": true,
        "hideSensitiveSearch": false,
        "bogusCount": 42,
      ],
      now: now
    )

    let stored = IOSEnforcementSharedStore.loadPlatformControls(site: "x")
    XCTAssertEqual(stored?.site, "x")
    XCTAssertEqual(stored?.observedAt, now)
    XCTAssertEqual(stored?.controls["displaySensitiveMedia"], true)
    XCTAssertEqual(stored?.controls["hideSensitiveSearch"], false)
    // Numbers and strings must not masquerade as safety-control states.
    XCTAssertNil(stored?.controls["bogusCount"])
    XCTAssertNil(stored?.controls["url"])
    XCTAssertEqual(XPlatformSafety.status(snapshot: stored), .exposed)
  }

  func testRecordPlatformControlsIgnoresPayloadWithoutSite() {
    IOSEnforcementSharedStore.recordPlatformControls(payload: ["displaySensitiveMedia": true])
    // No crash, and no snapshot stored under an empty site.
    XCTAssertNil(IOSEnforcementSharedStore.loadPlatformControls(site: ""))
  }

  func testLaterObservationReplacesEarlier() {
    IOSEnforcementSharedStore.recordPlatformControls(payload: ["site": "x", "displaySensitiveMedia": true])
    IOSEnforcementSharedStore.recordPlatformControls(payload: ["site": "x", "displaySensitiveMedia": false])
    XCTAssertEqual(XPlatformSafety.status(snapshot: IOSEnforcementSharedStore.loadPlatformControls(site: "x")), .protected)
  }
}
