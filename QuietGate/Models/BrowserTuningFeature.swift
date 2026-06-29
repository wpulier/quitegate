import Foundation

enum BrowserTuningSite: String, CaseIterable, Identifiable {
  case youtube
  case x
  case instagram
  case reddit

  var id: String { rawValue }

  var title: String {
    switch self {
    case .youtube: return "YouTube"
    case .x: return "X"
    case .instagram: return "Instagram"
    case .reddit: return "Reddit"
    }
  }

  var brandAssetName: String {
    switch self {
    case .youtube: return "BrandYouTube"
    case .x: return "BrandX"
    case .instagram: return "BrandInstagram"
    case .reddit: return "BrandReddit"
    }
  }

  var domainsLabel: String {
    switch self {
    case .youtube: return "youtube.com"
    case .x: return "x.com + twitter.com"
    case .instagram: return "instagram.com"
    case .reddit: return "reddit.com"
    }
  }

  var subtitle: String {
    switch self {
    case .youtube:
      return "Hide recommendation loops and other distracting YouTube surfaces."
    case .x:
      return "Keep X usable while hiding sensitive media and noisy discovery surfaces."
    case .instagram:
      return "Keep Instagram usable while hiding Reels, Explore, stories, messages, and recommendations."
    case .reddit:
      return "Keep Reddit usable while hiding popular feeds, recommendations, media, and sidebars."
    }
  }

  var systemImage: String {
    switch self {
    case .youtube: return "play.rectangle"
    case .x: return "xmark"
    case .instagram: return "camera"
    case .reddit: return "bubble.left.and.bubble.right"
    }
  }

  var rulesTitle: String {
    switch self {
    case .youtube: return "YouTube cleanup"
    case .x: return "X media tuning"
    case .instagram: return "Instagram cleanup"
    case .reddit: return "Reddit cleanup"
    }
  }

  var rulesSubtitle: String {
    switch self {
    case .youtube:
      return "Tune YouTube without blocking the whole site."
    case .x:
      return "Tune x.com and twitter.com without blocking the whole site."
    case .instagram:
      return "Tune instagram.com without blocking the whole site."
    case .reddit:
      return "Tune reddit.com without blocking the whole site."
    }
  }

  var connectionTitle: String {
    switch self {
    case .youtube: return "Connect a browser to use YouTube cleanup"
    case .x: return "Connect a browser to use X media tuning"
    case .instagram: return "Connect a browser to use Instagram cleanup"
    case .reddit: return "Connect a browser to use Reddit cleanup"
    }
  }
}

enum BrowserTuningFeature: String, CaseIterable, Codable, Identifiable {
  case youtubeHome
  case youtubeVideoSidebar
  case youtubeRecommendations
  case youtubeLiveChat
  case youtubePlaylists
  case youtubeFundraisers
  case youtubeEndScreens
  case youtubeEndScreenCards
  case youtubeShorts
  case youtubeComments
  case youtubeMixes
  case youtubeMerch
  case youtubeVideoInfo
  case youtubeTopHeader
  case youtubeNotifications
  case youtubeSearch
  case youtubeExplore
  case youtubeMoreFromYouTube
  case youtubeSubscriptions
  case youtubeAutoplay
  case youtubeAnnotations
  case youtubeUsageTracking
  case youtubeDailyLimit
  case xSensitiveMedia
  case xExplicitContent
  case xExplicitSearch
  case xVideos
  case xPhotos
  case xMediaCards
  case xExploreTrends
  case instagramReels
  case instagramExplore
  case instagramSuggested
  case instagramProfileSuggestions
  case instagramMessages
  case instagramNotifications
  case instagramStories
  case redditPopularAll
  case redditRecommendations
  case redditNSFW
  case redditMedia
  case redditSidebars

  var id: String { rawValue }

  static func features(for site: BrowserTuningSite) -> [BrowserTuningFeature] {
    allCases.filter { $0.site == site }
  }

  var site: BrowserTuningSite {
    switch self {
    case .youtubeHome, .youtubeVideoSidebar, .youtubeRecommendations, .youtubeLiveChat,
      .youtubePlaylists, .youtubeFundraisers, .youtubeEndScreens, .youtubeEndScreenCards,
      .youtubeShorts, .youtubeComments, .youtubeMixes, .youtubeMerch, .youtubeVideoInfo,
      .youtubeTopHeader, .youtubeNotifications, .youtubeSearch, .youtubeExplore,
      .youtubeMoreFromYouTube, .youtubeSubscriptions, .youtubeAutoplay, .youtubeAnnotations,
      .youtubeUsageTracking, .youtubeDailyLimit:
      return .youtube
    case .xSensitiveMedia, .xExplicitContent, .xExplicitSearch, .xVideos, .xPhotos, .xMediaCards,
      .xExploreTrends:
      return .x
    case .instagramReels, .instagramExplore, .instagramSuggested, .instagramProfileSuggestions,
      .instagramMessages, .instagramNotifications, .instagramStories:
      return .instagram
    case .redditPopularAll, .redditRecommendations, .redditNSFW, .redditMedia,
      .redditSidebars:
      return .reddit
    }
  }

  var title: String {
    switch self {
    case .youtubeHome: return "Hide YouTube Home"
    case .youtubeVideoSidebar: return "Hide Video Sidebar"
    case .youtubeRecommendations: return "Hide Recommended"
    case .youtubeLiveChat: return "Hide Live Chat"
    case .youtubePlaylists: return "Hide Playlists"
    case .youtubeFundraisers: return "Hide Fundraisers"
    case .youtubeEndScreens: return "Hide End Screen Feed"
    case .youtubeEndScreenCards: return "Hide End Screen Cards"
    case .youtubeShorts: return "Hide Shorts"
    case .youtubeComments: return "Hide Comments"
    case .youtubeMixes: return "Hide Mixes"
    case .youtubeMerch: return "Hide Merch, Tickets, Offers"
    case .youtubeVideoInfo: return "Hide Video Info"
    case .youtubeTopHeader: return "Hide Top Header"
    case .youtubeNotifications: return "Hide Notifications"
    case .youtubeSearch: return "Hide Inapt Search Results"
    case .youtubeExplore: return "Hide Explore and Trending"
    case .youtubeMoreFromYouTube: return "Hide More from YouTube"
    case .youtubeSubscriptions: return "Hide Subscriptions"
    case .youtubeAutoplay: return "Disable Autoplay"
    case .youtubeAnnotations: return "Disable Annotations"
    case .youtubeUsageTracking: return "Track YouTube Time"
    case .youtubeDailyLimit: return "Enforce Daily Time Limit"
    case .xSensitiveMedia: return "Hide Sensitive Media"
    case .xExplicitContent: return "Hide Explicit-Cue Posts"
    case .xExplicitSearch: return "Hide Explicit Search Results"
    case .xVideos: return "Hide Videos and GIFs"
    case .xPhotos: return "Hide Tweet Photos"
    case .xMediaCards: return "Hide Media Cards"
    case .xExploreTrends: return "Hide Explore and Trends"
    case .instagramReels: return "Hide Reels"
    case .instagramExplore: return "Hide Explore"
    case .instagramSuggested: return "Hide Suggested Posts"
    case .instagramProfileSuggestions: return "Hide Profile Suggestions"
    case .instagramMessages: return "Hide DMs"
    case .instagramNotifications: return "Hide Notifications"
    case .instagramStories: return "Hide Stories"
    case .redditPopularAll: return "Hide Popular and All"
    case .redditRecommendations: return "Hide Recommendations"
    case .redditNSFW: return "Hide NSFW Posts and Communities"
    case .redditMedia: return "Hide Media Posts"
    case .redditSidebars: return "Hide Sidebars"
    }
  }

  var detail: String {
    switch self {
    case .youtubeHome:
      return "Removes the browse feed so YouTube opens without a recommendation wall."
    case .youtubeVideoSidebar:
      return "Removes the watch-page side rail that pulls in videos and modules."
    case .youtubeRecommendations:
      return "Removes recommended video, playlist, and mix modules."
    case .youtubeLiveChat:
      return "Removes live chat panels from watch pages."
    case .youtubePlaylists:
      return "Removes playlist panels from watch pages."
    case .youtubeFundraisers:
      return "Removes donation and fundraiser modules."
    case .youtubeEndScreens:
      return "Removes the end-screen video wall that appears after playback."
    case .youtubeEndScreenCards:
      return "Removes end-screen cards, teasers, and card buttons over the player."
    case .youtubeShorts:
      return "Removes Shorts links, shelves, and Shorts watch pages."
    case .youtubeComments:
      return "Removes comments from watch pages."
    case .youtubeMixes:
      return "Removes YouTube Mix and radio-style result modules."
    case .youtubeMerch:
      return "Removes merchandise, ticket, offer, and shopping shelves."
    case .youtubeVideoInfo:
      return "Removes watch-page metadata, description, and video details."
    case .youtubeTopHeader:
      return "Removes the top masthead from YouTube pages."
    case .youtubeNotifications:
      return "Removes notification buttons and notification entry points."
    case .youtubeSearch:
      return "Removes Shorts shelves and irrelevant search modules while keeping normal results."
    case .youtubeExplore:
      return "Removes Explore and Trending links and redirects those feeds home."
    case .youtubeMoreFromYouTube:
      return "Removes promotional More from YouTube entries such as Premium and Music."
    case .youtubeSubscriptions:
      return "Removes Subscriptions links and redirects the subscriptions feed home."
    case .youtubeAutoplay:
      return "Turns YouTube autoplay off when a watch page exposes the control."
    case .youtubeAnnotations:
      return "Removes legacy annotations, cards, paid overlays, and player prompts."
    case .youtubeUsageTracking:
      return "Tracks active YouTube time and unique watched videos in connected browser profiles."
    case .youtubeDailyLimit:
      return "Blocks YouTube after the configured daily time limit is reached."
    case .xSensitiveMedia:
      return "Hides X-labeled sensitive media and media posts with high-confidence explicit cues."
    case .xExplicitContent:
      return "Hides media posts with adult domains, explicit text cues, or adult account cues."
    case .xExplicitSearch:
      return "Hides X search People, Latest, and Media results when the query or result has high-confidence explicit cues."
    case .xVideos:
      return "Removes video and GIF players from posts while keeping text available."
    case .xPhotos:
      return "Removes tweet photos without hiding profile avatars."
    case .xMediaCards:
      return "Removes rich link cards with large media previews."
    case .xExploreTrends:
      return "Removes trend modules and Explore entry points that pull you into browsing."
    case .instagramReels:
      return "Removes Reels links, trays, and Reels pages."
    case .instagramExplore:
      return "Removes Explore entry points and redirects direct Explore pages back home."
    case .instagramSuggested:
      return "Removes suggested posts, recommendation modules, and clearly labeled promoted posts."
    case .instagramProfileSuggestions:
      return "Removes suggested account cards and right-rail profile recommendation modules."
    case .instagramMessages:
      return "Removes DM entry points and redirects direct-message pages back home."
    case .instagramNotifications:
      return "Removes notification entry points that pull you back into browsing."
    case .instagramStories:
      return "Removes the stories tray while keeping the main feed available."
    case .redditPopularAll:
      return "Removes r/popular and r/all entry points and redirects those feeds home."
    case .redditRecommendations:
      return "Removes recommended, promoted, and suggested community modules."
    case .redditNSFW:
      return "Removes native NSFW posts, mature communities, and adult-domain media posts."
    case .redditMedia:
      return "Removes image and video media from posts while leaving text posts available."
    case .redditSidebars:
      return "Removes right-rail sidebars and community panels."
    }
  }

  var systemImage: String {
    switch self {
    case .youtubeHome: return "house.slash"
    case .youtubeVideoSidebar: return "sidebar.right"
    case .youtubeRecommendations: return "rectangle.stack.badge.minus"
    case .youtubeLiveChat: return "message.badge"
    case .youtubePlaylists: return "list.bullet.rectangle"
    case .youtubeFundraisers: return "heart.slash"
    case .youtubeEndScreens: return "rectangle.stack.badge.minus"
    case .youtubeEndScreenCards: return "rectangle.on.rectangle.slash"
    case .youtubeShorts: return "rectangle.portrait.slash"
    case .youtubeComments: return "text.bubble"
    case .youtubeMixes: return "shuffle"
    case .youtubeMerch: return "bag"
    case .youtubeVideoInfo: return "info.circle"
    case .youtubeTopHeader: return "menubar.rectangle"
    case .youtubeNotifications: return "bell.slash"
    case .youtubeSearch: return "magnifyingglass"
    case .youtubeExplore: return "safari"
    case .youtubeMoreFromYouTube: return "square.grid.2x2"
    case .youtubeSubscriptions: return "person.2.slash"
    case .youtubeAutoplay: return "play.slash"
    case .youtubeAnnotations: return "text.bubble.fill"
    case .youtubeUsageTracking: return "clock"
    case .youtubeDailyLimit: return "timer"
    case .xSensitiveMedia: return "eye.slash"
    case .xExplicitContent: return "exclamationmark.octagon"
    case .xExplicitSearch: return "magnifyingglass.circle"
    case .xVideos: return "video.slash"
    case .xPhotos: return "photo.on.rectangle.angled"
    case .xMediaCards: return "rectangle.on.rectangle.slash"
    case .xExploreTrends: return "chart.line.downtrend.xyaxis"
    case .instagramReels: return "rectangle.portrait.slash"
    case .instagramExplore: return "magnifyingglass"
    case .instagramSuggested: return "person.crop.circle.badge.questionmark"
    case .instagramProfileSuggestions: return "person.2.slash"
    case .instagramMessages: return "paperplane"
    case .instagramNotifications: return "bell.slash"
    case .instagramStories: return "circle.dashed"
    case .redditPopularAll: return "flame"
    case .redditRecommendations: return "sparkles"
    case .redditNSFW: return "shield.lefthalf.filled"
    case .redditMedia: return "photo.on.rectangle.angled"
    case .redditSidebars: return "sidebar.right"
    }
  }
}
