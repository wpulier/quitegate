import XCTest
@testable import QuietGate

final class ManagedAppsShieldTests: XCTestCase {
  // MARK: shouldShield(mode:)

  func testShouldShieldIsTrueForFocusAndStrict() {
    XCTAssertTrue(ManagedAppsShield.shouldShield(mode: .focus))
    XCTAssertTrue(ManagedAppsShield.shouldShield(mode: .strict))
  }

  func testShouldShieldIsFalseForOpen() {
    XCTAssertFalse(ManagedAppsShield.shouldShield(mode: .open))
  }

  // MARK: isShrink(old:new:)

  func testAddingIsNotShrink() {
    XCTAssertFalse(ManagedAppsShield.isShrink(old: Set([1, 2]), new: Set([1, 2, 3])))
  }

  func testUnchangedIsNotShrink() {
    XCTAssertFalse(ManagedAppsShield.isShrink(old: Set([1, 2]), new: Set([1, 2])))
  }

  func testEmptyToNonEmptyIsNotShrink() {
    XCTAssertFalse(ManagedAppsShield.isShrink(old: Set<Int>(), new: Set([1])))
  }

  func testRemovingIsShrink() {
    XCTAssertTrue(ManagedAppsShield.isShrink(old: Set([1, 2, 3]), new: Set([1, 2])))
  }

  func testClearingIsShrink() {
    XCTAssertTrue(ManagedAppsShield.isShrink(old: Set([1]), new: Set<Int>()))
  }

  func testSwapKeepingCountIsShrink() {
    // Same count, but a committed token was dropped → still a shrink.
    XCTAssertTrue(ManagedAppsShield.isShrink(old: Set([1, 2]), new: Set([1, 3])))
  }

  // MARK: canApplyEdit(lockedActive:isShrink:)

  func testUnlockedAllowsShrink() {
    XCTAssertTrue(ManagedAppsShield.canApplyEdit(lockedActive: false, isShrink: true))
  }

  func testUnlockedAllowsGrow() {
    XCTAssertTrue(ManagedAppsShield.canApplyEdit(lockedActive: false, isShrink: false))
  }

  func testLockedRefusesShrink() {
    XCTAssertFalse(ManagedAppsShield.canApplyEdit(lockedActive: true, isShrink: true))
  }

  func testLockedAllowsGrow() {
    XCTAssertTrue(ManagedAppsShield.canApplyEdit(lockedActive: true, isShrink: false))
  }
}
