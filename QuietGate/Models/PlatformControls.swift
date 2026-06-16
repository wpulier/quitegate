import Foundation

enum PlatformControlID: String, Codable, CaseIterable, Identifiable {
  case appleScreenTimeWeb
  case appleSensitiveContentWarning
  case cloudflareFamilyDNS
  case cleanBrowsingFamilyDNS
  case googleSafeSearch
  case chromeGoogleSafeSearchPolicy
  case chromeYouTubeRestrictedMode
  case xSensitiveMedia
  case xSensitiveSearch
  case redditMatureContent
  case redditBlurMatureMedia
  case quietGateTuners

  var id: String { rawValue }
}

enum PlatformControlState: String, Codable, Equatable {
  case enabled
  case needsAction
  case checkInBrowser
  case manualCheck
  case unavailable
  case unknown
}

struct PlatformControlItem: Identifiable, Codable, Equatable {
  let id: PlatformControlID
  let title: String
  let detail: String
  let state: PlatformControlState
  let actionTitle: String?
  let actionURLString: String?
  let checkedAt: Date?

  init(
    id: PlatformControlID,
    title: String,
    detail: String,
    state: PlatformControlState,
    actionTitle: String? = nil,
    actionURLString: String? = nil,
    checkedAt: Date? = nil
  ) {
    self.id = id
    self.title = title
    self.detail = detail
    self.state = state
    self.actionTitle = actionTitle
    self.actionURLString = actionURLString
    self.checkedAt = checkedAt
  }
}

struct BuiltInProtectionsSnapshot: Codable, Equatable {
  let checkedAt: Date
  let items: [PlatformControlItem]

  static let empty = BuiltInProtectionsSnapshot(
    checkedAt: Date(timeIntervalSince1970: 0),
    items: []
  )

  func item(_ id: PlatformControlID) -> PlatformControlItem? {
    items.first { $0.id == id }
  }
}

struct BrowserAccountPlatformControlsSnapshot: Codable, Equatable {
  let x: XAccountPlatformControlsSnapshot?
  let reddit: RedditAccountPlatformControlsSnapshot?
}

struct XAccountPlatformControlsSnapshot: Codable, Equatable {
  let checkedAt: Date?
  let url: String?
  let displaySensitiveMedia: Bool?
  let hideSensitiveSearch: Bool?
}

struct RedditAccountPlatformControlsSnapshot: Codable, Equatable {
  let checkedAt: Date?
  let url: String?
  let showMatureContent: Bool?
  let blurMatureMedia: Bool?
}
