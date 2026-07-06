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

  // MARK: clampManagedAppsLimitMinutes(_:)

  func testClampBelowMinimumRaisesToFive() {
    XCTAssertEqual(ManagedAppsShield.clampManagedAppsLimitMinutes(0), 5)
    XCTAssertEqual(ManagedAppsShield.clampManagedAppsLimitMinutes(4), 5)
    XCTAssertEqual(ManagedAppsShield.clampManagedAppsLimitMinutes(-30), 5)
  }

  func testClampAboveMaximumLowersToFourEighty() {
    XCTAssertEqual(ManagedAppsShield.clampManagedAppsLimitMinutes(481), 480)
    XCTAssertEqual(ManagedAppsShield.clampManagedAppsLimitMinutes(10_000), 480)
  }

  func testClampWithinRangeIsUnchanged() {
    XCTAssertEqual(ManagedAppsShield.clampManagedAppsLimitMinutes(5), 5)
    XCTAssertEqual(ManagedAppsShield.clampManagedAppsLimitMinutes(30), 30)
    XCTAssertEqual(ManagedAppsShield.clampManagedAppsLimitMinutes(480), 480)
  }

  // MARK: shouldArmManagedAppsLimit(limitEnabled:hasSelection:)

  func testArmsOnlyWhenEnabledAndSelectionPresent() {
    XCTAssertTrue(ManagedAppsShield.shouldArmManagedAppsLimit(limitEnabled: true, hasSelection: true))
  }

  func testDoesNotArmWhenDisabled() {
    XCTAssertFalse(ManagedAppsShield.shouldArmManagedAppsLimit(limitEnabled: false, hasSelection: true))
  }

  func testDoesNotArmWhenSelectionEmpty() {
    XCTAssertFalse(ManagedAppsShield.shouldArmManagedAppsLimit(limitEnabled: true, hasSelection: false))
  }

  // MARK: shouldApplyAdultFilter(mode:adultEnabled:)

  func testAdultFilterAppliesOnlyInStrictWhenEnabled() {
    XCTAssertTrue(ManagedAppsShield.shouldApplyAdultFilter(mode: .strict, adultEnabled: true))
  }

  func testAdultFilterOffWhenAdultDisabledEvenInStrict() {
    XCTAssertFalse(ManagedAppsShield.shouldApplyAdultFilter(mode: .strict, adultEnabled: false))
  }

  func testAdultFilterOffInOpenAndFocus() {
    XCTAssertFalse(ManagedAppsShield.shouldApplyAdultFilter(mode: .open, adultEnabled: true))
    XCTAssertFalse(ManagedAppsShield.shouldApplyAdultFilter(mode: .focus, adultEnabled: true))
  }

  // MARK: isEnforcementActive(youtubeSelected:managedAppsSelected:adultFilterOn:)

  func testEnforcementActiveWhenYouTubeSelected() {
    XCTAssertTrue(ManagedAppsShield.isEnforcementActive(
      youtubeSelected: true, managedAppsSelected: false, adultFilterOn: false))
  }

  func testEnforcementActiveWhenManagedAppsSelected() {
    XCTAssertTrue(ManagedAppsShield.isEnforcementActive(
      youtubeSelected: false, managedAppsSelected: true, adultFilterOn: false))
  }

  func testEnforcementActiveWhenAdultFilterOn() {
    XCTAssertTrue(ManagedAppsShield.isEnforcementActive(
      youtubeSelected: false, managedAppsSelected: false, adultFilterOn: true))
  }

  func testEnforcementInactiveWhenNothingActive() {
    XCTAssertFalse(ManagedAppsShield.isEnforcementActive(
      youtubeSelected: false, managedAppsSelected: false, adultFilterOn: false))
  }

  // MARK: IOSEnforcementSnapshot.managedAppsLimitMinutes

  func testSnapshotDefaultsManagedAppsLimitToNil() {
    XCTAssertNil(IOSEnforcementSnapshot.empty.managedAppsLimitMinutes)
  }

  func testSnapshotRoundTripsManagedAppsLimit() throws {
    var snapshot = IOSEnforcementSnapshot.empty
    snapshot.managedAppsLimitMinutes = 45
    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(IOSEnforcementSnapshot.self, from: data)
    XCTAssertEqual(decoded.managedAppsLimitMinutes, 45)
  }

  func testLegacySnapshotJSONWithoutLimitDecodesToNil() throws {
    // A snapshot persisted before Stage 2 has no managedAppsLimitMinutes key; the
    // JSON below carries exactly the non-defaulted required keys.
    let legacy = """
    {"mode":"open","authorizationMode":"individual","shieldingEnabled":false,\
    "dailyLimitMinutes":30,"adultWebFilterEnabled":false,"safariExtensionEnabled":false,\
    "selectedApplicationCount":0,"selectedCategoryCount":0,"selectedWebDomainCount":0,\
    "scheduleActive":false}
    """
    let decoded = try JSONDecoder().decode(IOSEnforcementSnapshot.self, from: Data(legacy.utf8))
    XCTAssertNil(decoded.managedAppsLimitMinutes)
  }
}
