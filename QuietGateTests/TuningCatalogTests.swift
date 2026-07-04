import XCTest
@testable import QuietGate

final class TuningCatalogTests: XCTestCase {
  func testCatalogHasEveryFeatureExactlyOnceInEnumOrder() {
    XCTAssertEqual(TuningCatalog.allFeatureIDs, BrowserTuningFeature.allCases.map(\.rawValue))
    XCTAssertEqual(Set(TuningCatalog.allFeatureIDs).count, TuningCatalog.allFeatureIDs.count)
    XCTAssertEqual(TuningCatalog.allFeatureIDs.count, 42)
  }

  func testEveryFeatureMapsToAKnownSite() {
    let siteIDs = Set(TuningCatalog.sites.map(\.id))
    for feature in TuningCatalog.features {
      XCTAssertTrue(siteIDs.contains(feature.siteID), "\(feature.id) has unknown site \(feature.siteID)")
    }
  }

  func testSiteFeatureIDsUnionEqualsAllFeatureIDs() {
    XCTAssertEqual(TuningCatalog.sites.flatMap(\.featureIDs), TuningCatalog.allFeatureIDs)
  }

  func testWebFeaturesAreAllEnforceableInChromeAndFirefox() {
    for feature in TuningCatalog.features {
      XCTAssertTrue(feature.enforceableOn.contains(.chromeExtension), "\(feature.id)")
      XCTAssertTrue(feature.enforceableOn.contains(.firefoxExtension), "\(feature.id)")
    }
  }

  func testModeFlagMapsCoverEveryFeature() {
    for mode in ["open", "focus", "strict"] {
      XCTAssertEqual(Set(TuningCatalog.enabledFeatureFlags(for: mode).keys), Set(TuningCatalog.allFeatureIDs))
    }
    XCTAssertTrue(TuningCatalog.enabledFeatureFlags(for: "open").values.allSatisfy { $0 == false })
    XCTAssertTrue(TuningCatalog.enabledFeatureFlags(for: "strict").values.allSatisfy { $0 == true })
  }
}
