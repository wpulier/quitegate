import XCTest
@testable import QuietGate

final class ConnectionStatusTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_000_000)

  func testPausedIsOff() {
    let status = ConnectionStatus.resolve(
      lastSeenAt: now, isEnforcingLatestPolicy: true, isPausedByUser: true, now: now
    )
    XCTAssertEqual(status, .off)
  }

  func testNeverSeenIsSetupIncomplete() {
    let status = ConnectionStatus.resolve(
      lastSeenAt: nil, isEnforcingLatestPolicy: true, isPausedByUser: false, now: now
    )
    XCTAssertEqual(status, .attention(.setupIncomplete))
  }

  func testBeyondFreshWindowIsStale() {
    let old = now.addingTimeInterval(-(ConnectionFreshness.freshWindow + 1))
    let status = ConnectionStatus.resolve(
      lastSeenAt: old, isEnforcingLatestPolicy: true, isPausedByUser: false, now: now
    )
    XCTAssertEqual(status, .attention(.stale))
  }

  func testFreshButNotEnforcingIsCatchingUp() {
    let recent = now.addingTimeInterval(-60)
    let status = ConnectionStatus.resolve(
      lastSeenAt: recent, isEnforcingLatestPolicy: false, isPausedByUser: false, now: now
    )
    XCTAssertEqual(status, .attention(.catchingUp))
  }

  func testFreshAndEnforcingIsOn() {
    let recent = now.addingTimeInterval(-60)
    let status = ConnectionStatus.resolve(
      lastSeenAt: recent, isEnforcingLatestPolicy: true, isPausedByUser: false, now: now
    )
    XCTAssertEqual(status, .on)
  }
}
