import Foundation

enum AccessMode: String, CaseIterable, Codable, Identifiable {
  case open
  case focus
  case strict

  var id: String { rawValue }

  var title: String {
    switch self {
    case .open: return "Open"
    case .focus: return "Focus"
    case .strict: return "Strict"
    }
  }

  var systemImage: String {
    switch self {
    case .open: return "circle"
    case .focus: return "scope"
    case .strict: return "lock.shield"
    }
  }

  var protectionEnabled: Bool {
    self != .open
  }

  var tunerEnabled: Bool {
    self != .open
  }

  var summary: String {
    switch self {
    case .open:
      return "No QuietGate rules are applied."
    case .focus:
      return "Blocks adult domains and high-confidence explicit pages while removing the noisiest browser surfaces."
    case .strict:
      return "Keeps blocking on and tunes supported sites down to intentional use."
    }
  }

  var blockerSummary: String {
    switch self {
    case .open:
      return "QuietGate blocking is off."
    case .focus, .strict:
      return "QuietGate is blocking adult domains, adult-host media, and high-confidence explicit pages."
    }
  }

  var tuningFeatures: [BrowserTuningFeature] {
    switch self {
    case .open:
      return []
    case .focus:
      return [
        .youtubeHome, .youtubeShorts, .youtubeUsageTracking,
        .xSensitiveMedia, .xVideos,
        .instagramReels, .instagramExplore, .instagramSuggested, .instagramProfileSuggestions,
        .instagramMessages, .instagramNotifications,
        .redditPopularAll, .redditRecommendations,
      ]
    case .strict:
      return BrowserTuningFeature.allCases
    }
  }
}
