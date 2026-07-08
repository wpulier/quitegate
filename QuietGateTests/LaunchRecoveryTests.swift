import XCTest
@testable import QuietGate

final class LaunchRecoveryTests: XCTestCase {
  // MARK: survived launches reset the streak

  func testSurvivedPreviousLaunchResetsCount() {
    let assessment = LaunchRecovery.assess(
      previousLaunchDiedEarly: false, wasEnforcing: true, priorEarlyDeathCount: 5
    )
    XCTAssertEqual(assessment, .init(earlyDeathCount: 0, shouldEnterSafeMode: false))
  }

  func testFreshInstallHasNoStreak() {
    let assessment = LaunchRecovery.assess(
      previousLaunchDiedEarly: false, wasEnforcing: false, priorEarlyDeathCount: 0
    )
    XCTAssertEqual(assessment, .init(earlyDeathCount: 0, shouldEnterSafeMode: false))
  }

  // MARK: early deaths without enforcement never wipe

  func testEarlyDeathWhileNotEnforcingResetsCount() {
    let assessment = LaunchRecovery.assess(
      previousLaunchDiedEarly: true, wasEnforcing: false, priorEarlyDeathCount: 3
    )
    XCTAssertEqual(assessment, .init(earlyDeathCount: 0, shouldEnterSafeMode: false))
  }

  // MARK: the loop

  func testFirstEarlyDeathWhileEnforcingCountsButDoesNotWipe() {
    let assessment = LaunchRecovery.assess(
      previousLaunchDiedEarly: true, wasEnforcing: true, priorEarlyDeathCount: 0
    )
    XCTAssertEqual(assessment, .init(earlyDeathCount: 1, shouldEnterSafeMode: false))
  }

  func testSecondConsecutiveEarlyDeathEntersSafeMode() {
    let assessment = LaunchRecovery.assess(
      previousLaunchDiedEarly: true, wasEnforcing: true, priorEarlyDeathCount: 1
    )
    XCTAssertEqual(assessment, .init(earlyDeathCount: 2, shouldEnterSafeMode: true))
  }

  func testStreakBeyondThresholdStaysInSafeMode() {
    let assessment = LaunchRecovery.assess(
      previousLaunchDiedEarly: true, wasEnforcing: true, priorEarlyDeathCount: 5
    )
    XCTAssertEqual(assessment, .init(earlyDeathCount: 6, shouldEnterSafeMode: true))
  }
}
