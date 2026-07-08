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
    // iOS Safari content scripts handle every Instagram feature too (verified in
    // TortoiseSafariExtension/content/instagram.js + instagram.css), so all are enforceable there.
    let safari = TuneScreen.features(forSiteID: "instagram", policy: nil, surface: .iosSafari)
    XCTAssertTrue(safari.allSatisfy(\.isEnforceable))
  }

  func testEveryCatalogFeatureResolvesToABrowserTuningFeature() {
    // Guards the model's BrowserTuningFeature(rawValue:) so no site row silently drops a feature.
    for id in TuningCatalog.allFeatureIDs {
      XCTAssertNotNil(BrowserTuningFeature(rawValue: id), "\(id) has no BrowserTuningFeature case")
    }
  }

  func testFeaturedAndRemainingPartitionEverySite() {
    // The accordion's curated rows + its "All settings" fold must together be
    // exactly the site's catalog features — nothing duplicated, nothing lost.
    for site in TuningCatalog.sites {
      let featured = TuneScreen.featuredFeatures(forSiteID: site.id, policy: nil, surface: .iosSafari)
      let remaining = TuneScreen.remainingFeatures(forSiteID: site.id, policy: nil, surface: .iosSafari)
      XCTAssertEqual(featured.map(\.id), TuningCatalog.featuredFeatureIDs(for: site.id))
      XCTAssertEqual(
        Set(featured.map(\.id)).union(remaining.map(\.id)),
        Set(site.featureIDs)
      )
      XCTAssertTrue(Set(featured.map(\.id)).isDisjoint(with: remaining.map(\.id)))
    }
  }

  func testFeatureCarriesSystemImage() {
    let features = TuneScreen.features(forSiteID: "youtube", policy: nil, surface: .iosSafari)
    XCTAssertTrue(features.allSatisfy { !$0.systemImage.isEmpty })
  }

  func testIosSafariEnforcedFeaturesReflectRealPolicy() {
    let safari = TuneScreen.iosSafariEnforcedFeatures(
      policy: policy(featuresOn: ["youtubeShorts", "instagramReels", "instagramNotifications"])
    )
    XCTAssertEqual(Set(safari.keys), Set(TuningCatalog.allFeatureIDs))
    XCTAssertTrue(safari["youtubeShorts"]!)          // enforceable + on
    XCTAssertTrue(safari["instagramReels"]!)         // enforceable + on
    XCTAssertTrue(safari["instagramNotifications"]!) // now enforceable on iOS Safari + on
    XCTAssertFalse(safari["youtubeHome"]!)           // enforceable but off
  }
}
