import XCTest
@testable import QuietGate

final class TortoisePolicyCatalogTests: XCTestCase {
  func testBrowserFeatureKeysEqualsCatalog() {
    XCTAssertEqual(TortoisePolicy.browserFeatureKeys, TuningCatalog.allFeatureIDs)
  }

  func testEveryTuningFeatureIsABrowserFeatureKey() {
    let keys = Set(TortoisePolicy.browserFeatureKeys)
    for feature in BrowserTuningFeature.allCases {
      XCTAssertTrue(keys.contains(feature.rawValue), "\(feature.rawValue) missing from browserFeatureKeys")
    }
  }

  func testPreviouslyDroppedInstagramFeatureNowPersists() {
    // instagramMessages was absent from the 39-key list and silently dropped.
    let base = TortoisePolicy.open
    let updated = base.settingBrowserFeature("instagramMessages", enabled: true)
    XCTAssertEqual(updated.browser?.features["instagramMessages"], true)
  }

  func testFocusKeysMatchCatalog() {
    XCTAssertEqual(TortoisePolicy.focusBrowserFeatureKeys, TuningCatalog.focusFeatureIDs)
  }
}
