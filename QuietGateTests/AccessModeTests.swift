import XCTest
@testable import QuietGate

final class AccessModeTests: XCTestCase {
  func testFocusModeHasLightSiteTuning() {
    XCTAssertTrue(AccessMode.focus.protectionEnabled)
    XCTAssertEqual(
      AccessMode.focus.tuningFeatures,
      [
        .youtubeHome, .youtubeShorts, .youtubeUsageTracking,
        .xSensitiveMedia, .xVideos,
        .instagramReels, .instagramExplore, .instagramSuggested,
        .redditPopularAll, .redditRecommendations,
      ]
    )
  }

  func testStrictModeEnablesEveryTuningFeature() {
    XCTAssertTrue(AccessMode.strict.protectionEnabled)
    XCTAssertEqual(AccessMode.strict.tuningFeatures, BrowserTuningFeature.allCases)
  }

  func testOpenModeDisablesProtectionAndTuning() {
    XCTAssertFalse(AccessMode.open.protectionEnabled)
    XCTAssertTrue(AccessMode.open.tuningFeatures.isEmpty)
  }

  func testTuningFeaturesAreGroupedBySite() {
    XCTAssertEqual(
      BrowserTuningFeature.features(for: .youtube),
      [
        .youtubeHome, .youtubeVideoSidebar, .youtubeRecommendations, .youtubeLiveChat,
        .youtubePlaylists, .youtubeFundraisers, .youtubeEndScreens, .youtubeEndScreenCards,
        .youtubeShorts, .youtubeComments, .youtubeMixes, .youtubeMerch, .youtubeVideoInfo,
        .youtubeTopHeader, .youtubeNotifications, .youtubeSearch, .youtubeExplore,
        .youtubeMoreFromYouTube, .youtubeSubscriptions, .youtubeAutoplay, .youtubeAnnotations,
        .youtubeUsageTracking, .youtubeDailyLimit,
      ]
    )
    XCTAssertEqual(
      BrowserTuningFeature.features(for: .x),
      [
        .xSensitiveMedia, .xExplicitContent, .xExplicitSearch,
        .xVideos, .xPhotos, .xMediaCards, .xExploreTrends,
      ]
    )
    XCTAssertEqual(
      BrowserTuningFeature.features(for: .instagram),
      [.instagramReels, .instagramExplore, .instagramSuggested, .instagramStories]
    )
    XCTAssertEqual(
      BrowserTuningFeature.features(for: .reddit),
      [.redditPopularAll, .redditRecommendations, .redditNSFW, .redditMedia, .redditSidebars]
    )
  }
}
