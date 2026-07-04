import Foundation

/// The single source of truth for tunable sites and features: ids, the site that
/// owns each, where each can be enforced, and what each mode preset turns on.
/// Shared by macOS, iOS, and iOS Safari enforcement.
enum TuningCatalog {
  struct Site {
    let id: String
    let title: String
    let brandAssetName: String
    let featureIDs: [String]
  }

  struct Feature {
    let id: String
    let siteID: String
    let enforceableOn: Set<TuningSurface>
  }

  private static let youtubeFeatureIDs = [
    "youtubeHome", "youtubeVideoSidebar", "youtubeRecommendations", "youtubeLiveChat",
    "youtubePlaylists", "youtubeFundraisers", "youtubeEndScreens", "youtubeEndScreenCards",
    "youtubeShorts", "youtubeComments", "youtubeMixes", "youtubeMerch", "youtubeVideoInfo",
    "youtubeTopHeader", "youtubeNotifications", "youtubeSearch", "youtubeExplore",
    "youtubeMoreFromYouTube", "youtubeSubscriptions", "youtubeAutoplay", "youtubeAnnotations",
    "youtubeUsageTracking", "youtubeDailyLimit",
  ]
  private static let xFeatureIDs = [
    "xSensitiveMedia", "xExplicitContent", "xExplicitSearch",
    "xVideos", "xPhotos", "xMediaCards", "xExploreTrends",
  ]
  private static let instagramFeatureIDs = [
    "instagramReels", "instagramExplore", "instagramSuggested", "instagramProfileSuggestions",
    "instagramMessages", "instagramNotifications", "instagramStories",
  ]
  private static let redditFeatureIDs = [
    "redditPopularAll", "redditRecommendations", "redditNSFW", "redditMedia", "redditSidebars",
  ]

  static let sites: [Site] = [
    Site(id: "youtube", title: "YouTube", brandAssetName: "BrandYouTube", featureIDs: youtubeFeatureIDs),
    Site(id: "x", title: "X", brandAssetName: "BrandX", featureIDs: xFeatureIDs),
    Site(id: "instagram", title: "Instagram", brandAssetName: "BrandInstagram", featureIDs: instagramFeatureIDs),
    Site(id: "reddit", title: "Reddit", brandAssetName: "BrandReddit", featureIDs: redditFeatureIDs),
  ]

  static let allFeatureIDs: [String] = sites.flatMap(\.featureIDs)

  /// Features the iOS Safari web extension applies via its content scripts. The
  /// scripts handle every catalog feature (incl. the two Instagram surfaces — see
  /// TortoiseSafariExtension/content/instagram.js + instagram.css), so Safari
  /// enforces all of them.
  private static let iosSafariFeatureIDs: Set<String> = Set(allFeatureIDs)

  /// Features enforced by iOS Screen Time rather than a content script.
  private static let iosScreenTimeFeatureIDs: Set<String> = ["youtubeDailyLimit"]

  static let features: [Feature] = sites.flatMap { site in
    site.featureIDs.map { id -> Feature in
      var surfaces: Set<TuningSurface> = [.chromeExtension, .firefoxExtension]
      if iosSafariFeatureIDs.contains(id) { surfaces.insert(.iosSafari) }
      if iosScreenTimeFeatureIDs.contains(id) { surfaces.insert(.iosScreenTime) }
      return Feature(id: id, siteID: site.id, enforceableOn: surfaces)
    }
  }

  static let openFeatureIDs: Set<String> = []

  static let focusFeatureIDs: Set<String> = [
    "youtubeHome", "youtubeShorts", "youtubeUsageTracking",
    "xSensitiveMedia", "xVideos",
    "instagramReels", "instagramExplore", "instagramSuggested", "instagramProfileSuggestions",
    "instagramMessages", "instagramNotifications",
    "redditPopularAll", "redditRecommendations",
  ]

  static var strictFeatureIDs: Set<String> { Set(allFeatureIDs) }

  /// A full flag map (every feature id → on/off) for a mode string.
  static func enabledFeatureFlags(for mode: String) -> [String: Bool] {
    let on: Set<String>
    switch mode {
    case "strict": on = strictFeatureIDs
    case "focus": on = focusFeatureIDs
    default: on = openFeatureIDs
    }
    return Dictionary(uniqueKeysWithValues: allFeatureIDs.map { ($0, on.contains($0)) })
  }

  static func siteID(forFeatureID id: String) -> String? {
    features.first { $0.id == id }?.siteID
  }
}
