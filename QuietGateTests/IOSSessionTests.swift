import XCTest
@testable import QuietGate

final class IOSSessionTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_000_000)
  private func session(_ mode: IOSEnforcementMode, inMinutes: Double, locked: Bool) -> IOSSessionState {
    IOSSessionState(mode: mode, endsAt: now.addingTimeInterval(inMinutes * 60), locked: locked)
  }

  func testNilSessionIsInactive() {
    XCTAssertFalse(IOSSession.isActive(nil, now: now))
    XCTAssertFalse(IOSSession.isLockedActive(nil, now: now))
    XCTAssertTrue(IOSSession.canEndEarly(nil, now: now))
    XCTAssertTrue(IOSSession.canChangeMode(nil, now: now))
  }

  func testActiveWhileWithinWindow() {
    let s = session(.focus, inMinutes: 25, locked: false)
    XCTAssertTrue(IOSSession.isActive(s, now: now))
    XCTAssertFalse(IOSSession.hasExpired(s, now: now))
  }

  func testExpiredAfterWindow() {
    let s = session(.focus, inMinutes: 25, locked: false)
    let later = now.addingTimeInterval(26 * 60)
    XCTAssertFalse(IOSSession.isActive(s, now: later))
    XCTAssertTrue(IOSSession.hasExpired(s, now: later))
  }

  func testLockedActiveBlocksEndAndModeChange() {
    let s = session(.strict, inMinutes: 120, locked: true)
    XCTAssertTrue(IOSSession.isLockedActive(s, now: now))
    XCTAssertFalse(IOSSession.canEndEarly(s, now: now))
    XCTAssertFalse(IOSSession.canChangeMode(s, now: now))
  }

  func testExpiredLockedSessionNoLongerBlocks() {
    let s = session(.strict, inMinutes: 120, locked: true)
    let later = now.addingTimeInterval(121 * 60)
    XCTAssertFalse(IOSSession.isLockedActive(s, now: later))
    XCTAssertTrue(IOSSession.canEndEarly(s, now: later))   // window over → precommitment released
  }

  func testUnlockedSessionCanEndEarly() {
    let s = session(.focus, inMinutes: 60, locked: false)
    XCTAssertTrue(IOSSession.isActive(s, now: now))
    XCTAssertTrue(IOSSession.canEndEarly(s, now: now))
  }

  func testRemainingCountsDown() {
    let s = session(.focus, inMinutes: 25, locked: false)
    XCTAssertEqual(IOSSession.remaining(s, now: now), 25 * 60, accuracy: 0.5)
    XCTAssertEqual(IOSSession.remaining(s, now: now.addingTimeInterval(26 * 60)), 0)
  }

  func testSnapshotRoundTripsSession() throws {
    var snapshot = IOSEnforcementSnapshot.empty
    snapshot.session = session(.strict, inMinutes: 120, locked: true)
    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(IOSEnforcementSnapshot.self, from: data)
    XCTAssertEqual(decoded.session, snapshot.session)
  }
}
