import XCTest
@testable import QuietGate

final class TuneScreenModelTests: XCTestCase {
  private func policy(featuresOn: [String]) -> TortoisePolicy {
    var flags = TuningCatalog.enabledFeatureFlags(for: "open") // all-false baseline
    for id in featuresOn { flags[id] = true }
    return TortoisePolicy(
      schemaVersion: 1, mode: "open", adultBlockingEnabled: false,
      browser: BrowserPolicy(features: flags, blockedDomains: [], blockedCategories: [], options: nil),
      schedules: nil, applications: nil
    )
  }

  func testSitesAreCatalogSitesInOrder() {
    let sites = TuneScreen.sites(policy: nil, surface: .chromeExtension)
    XCTAssertEqual(sites.map(\.id), ["youtube", "x", "instagram", "reddit"])
    XCTAssertEqual(sites.map(\.title), ["YouTube", "X", "Instagram", "Reddit"])
  }

  func testSiteEnabledCountReflectsPolicy() {
    let sites = TuneScreen.sites(policy: policy(featuresOn: ["youtubeShorts", "youtubeHome"]), surface: .chromeExtension)
    let youtube = sites.first { $0.id == "youtube" }!
    XCTAssertEqual(youtube.enabledCount, 2)
    XCTAssertEqual(youtube.totalCount, 23)
    XCTAssertEqual(sites.first { $0.id == "x" }!.enabledCount, 0)
  }

  func testFeatureTitlesComeFromBrowserTuningFeature() {
    let features = TuneScreen.features(forSiteID: "youtube", policy: nil, surface: .chromeExtension)
    let shorts = features.first { $0.id == "youtubeShorts" }!
    XCTAssertEqual(shorts.title, BrowserTuningFeature.youtubeShorts.title)
    XCTAssertEqual(shorts.detail, BrowserTuningFeature.youtubeShorts.detail)
  }

  func testFeatureIsOnReflectsPolicy() {
    let features = TuneScreen.features(forSiteID: "youtube", policy: policy(featuresOn: ["youtubeShorts"]), surface: .chromeExtension)
    XCTAssertTrue(features.first { $0.id == "youtubeShorts" }!.isOn)
    XCTAssertFalse(features.first { $0.id == "youtubeHome" }!.isOn)
  }

  func testEnforceabilityIsSurfaceAware() {
    // Browser (chrome) enforces every feature.
    let browser = TuneScreen.features(forSiteID: "instagram", policy: nil, surface: .chromeExtension)
    XCTAssertTrue(browser.allSatisfy(\.isEnforceable))
    // iOS Safari cannot hook two Instagram surfaces.
    let safari = TuneScreen.features(forSiteID: "instagram", policy: nil, surface: .iosSafari)
    XCTAssertFalse(safari.first { $0.id == "instagramProfileSuggestions" }!.isEnforceable)
    XCTAssertFalse(safari.first { $0.id == "instagramNotifications" }!.isEnforceable)
    XCTAssertTrue(safari.first { $0.id == "instagramReels" }!.isEnforceable)
  }

  func testEveryCatalogFeatureResolvesToABrowserTuningFeature() {
    // Guards the model's BrowserTuningFeature(rawValue:) so no site row silently drops a feature.
    for id in TuningCatalog.allFeatureIDs {
      XCTAssertNotNil(BrowserTuningFeature(rawValue: id), "\(id) has no BrowserTuningFeature case")
    }
  }

  func testIosSafariEnforcedFeaturesReflectsPolicyAndDropsUnhookable() {
    let safari = TuneScreen.iosSafariEnforcedFeatures(
      policy: policy(featuresOn: ["youtubeShorts", "instagramReels", "instagramNotifications"])
    )
    XCTAssertEqual(Set(safari.keys), Set(TuningCatalog.allFeatureIDs))
    XCTAssertTrue(safari["youtubeShorts"]!)            // enforceable on iOS Safari + on
    XCTAssertTrue(safari["instagramReels"]!)           // enforceable + on
    XCTAssertFalse(safari["instagramNotifications"]!)  // on in policy but NOT hookable on iOS Safari
    XCTAssertFalse(safari["youtubeHome"]!)             // enforceable but off
  }
}
