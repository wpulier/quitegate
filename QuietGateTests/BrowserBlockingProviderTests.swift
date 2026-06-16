import XCTest

@testable import QuietGate

final class BrowserBlockingProviderTests: XCTestCase {
  func testBrowserProviderBuildsRulesWithoutDNSInputs() {
    let provider = BrowserBlockingProvider(
      accessMode: .focus,
      blockCategories: [
        BlockCategoryRule(id: .adultContent, isEnabled: true)
      ],
      blockedSites: [
        BlockedSiteRule(domain: "x.com", isEnabled: true),
        BlockedSiteRule(domain: "example.com", isEnabled: false),
      ],
      tuningOverrides: [:]
    )

    XCTAssertTrue(provider.activeBlockedDomains.contains("x.com"))
    XCTAssertTrue(provider.activeBlockedDomains.contains("pornhub.com"))
    XCTAssertFalse(provider.activeBlockedDomains.contains("example.com"))
    XCTAssertEqual(provider.settings.blockedDomains, provider.activeBlockedDomains)
    XCTAssertEqual(provider.settings.blockedCategories, ["adultContent"])
    XCTAssertEqual(provider.settings.mode, .focus)
    XCTAssertEqual(provider.settings.options, .defaultValue)
  }

  func testBrowserProviderSnapshotIsWebsiteBlockingRoute() {
    let provider = BrowserBlockingProvider(
      accessMode: .focus,
      blockCategories: [
        BlockCategoryRule(id: .adultContent, isEnabled: true)
      ],
      blockedSites: [
        BlockedSiteRule(domain: "x.com", isEnabled: true)
      ],
      tuningOverrides: [:]
    )

    let disconnected = provider.providerSnapshot(destinationNames: [])
    XCTAssertEqual(disconnected.id, .browserHelpers)
    XCTAssertEqual(disconnected.title, "Browsers")
    XCTAssertEqual(disconnected.kind, .browser)
    XCTAssertEqual(disconnected.activeRuleCount, provider.activeBlockedDomains.count)
    XCTAssertTrue(disconnected.isDefault)
    XCTAssertFalse(disconnected.isReady)
    XCTAssertFalse(disconnected.isLegacy)

    let connected = provider.providerSnapshot(destinationNames: ["Chrome", "Firefox"])
    XCTAssertTrue(connected.isReady)
    XCTAssertEqual(connected.destinationNames, ["Chrome", "Firefox"])
    XCTAssertEqual(connected.activeRuleCount, provider.activeBlockedDomains.count)
  }

  func testBrowserProviderOwnsTuningOverrides() {
    let provider = BrowserBlockingProvider(
      accessMode: .focus,
      blockCategories: [],
      blockedSites: [],
      tuningOverrides: [
        BrowserTuningFeature.youtubeComments.rawValue: true,
        BrowserTuningFeature.youtubeShorts.rawValue: false,
        BrowserTuningFeature.xPhotos.rawValue: true,
      ]
    )

    XCTAssertTrue(provider.tuningFeatureEnabled(.youtubeComments))
    XCTAssertFalse(provider.tuningFeatureEnabled(.youtubeShorts))
    XCTAssertTrue(provider.tuningFeatureEnabled(.xPhotos))
    XCTAssertEqual(
      provider.settings.features[BrowserTuningFeature.youtubeComments.rawValue],
      true
    )
    XCTAssertEqual(
      provider.settings.features[BrowserTuningFeature.youtubeShorts.rawValue],
      false
    )
    XCTAssertEqual(
      provider.settings.features[BrowserTuningFeature.xPhotos.rawValue],
      true
    )
  }

  func testBrowserProviderIncludesTuningOptionsInSettings() {
    let provider = BrowserBlockingProvider(
      accessMode: .open,
      blockCategories: [],
      blockedSites: [],
      tuningOverrides: [
        BrowserTuningFeature.xExplicitContent.rawValue: true
      ],
      tuningOptions: BrowserTuningOptions(explicitHideStyle: .placeholder)
    )

    XCTAssertEqual(provider.settings.options.explicitHideStyle, .placeholder)
    XCTAssertTrue(provider.settings.settingsVersion.contains("options=explicitHideStyle=placeholder"))
  }
}
