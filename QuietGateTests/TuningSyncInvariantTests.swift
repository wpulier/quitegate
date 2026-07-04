import XCTest
@testable import QuietGate

final class TuningSyncInvariantTests: XCTestCase {
  // Guards the Task 5 removal: if any BrowserTuningFeature stops being a
  // browserFeatureKey, MacAccountStore could silently drop it locally again.
  func testEveryTuningFeatureSyncsThroughThePolicy() {
    let keys = Set(TortoisePolicy.browserFeatureKeys)
    for feature in BrowserTuningFeature.allCases {
      XCTAssertTrue(keys.contains(feature.rawValue), "\(feature.rawValue) would not sync to the account")
    }
  }
}
