import XCTest
@testable import QuietGate

final class PresetUnificationTests: XCTestCase {
  func testAccessModeFocusMatchesCatalog() {
    XCTAssertEqual(Set(AccessMode.focus.tuningFeatures.map(\.rawValue)), TuningCatalog.focusFeatureIDs)
  }

  func testAccessModeStrictIsEveryFeature() {
    XCTAssertEqual(AccessMode.strict.tuningFeatures, BrowserTuningFeature.allCases)
  }

  func testAccessModeOpenIsEmpty() {
    XCTAssertTrue(AccessMode.open.tuningFeatures.isEmpty)
  }

  func testPolicyFocusFlagsMatchCatalog() {
    let focusOn = TortoisePolicy.open.settingMode("focus").browser?.features
      .filter { $0.value }.keys.sorted()
    XCTAssertEqual(Set(focusOn ?? []), TuningCatalog.focusFeatureIDs)
  }
}
