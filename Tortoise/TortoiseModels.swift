import Foundation

struct ApiEnvelope<Value: Decodable>: Decodable {
  let ok: Bool
  let data: Value?
  let error: ApiError?
}

struct ApiError: Decodable {
  let code: String
  let message: String
}

struct PolicyEnvelope: Decodable {
  let policy: TortoisePolicy
  let settingsVersion: Int
  let updatedAt: String
}

struct TortoisePolicy: Codable {
  let schemaVersion: Int
  let mode: String
  let adultBlockingEnabled: Bool
  let browser: BrowserPolicy?
  let schedules: SchedulePolicy?
  let applications: ApplicationsPolicy?
}

struct BrowserPolicy: Codable {
  let features: [String: Bool]
  let blockedDomains: [String]
  let blockedCategories: [String]
  let options: BrowserPolicyOptions?
}

struct BrowserPolicyOptions: Codable {
  let explicitHideStyle: String?
  let youtubeDailyLimitMinutes: Int?
}

struct SchedulePolicy: Codable {
  let enabled: Bool
  let dailyFocusWindows: [FocusWindowPolicy]
}

struct FocusWindowPolicy: Codable {
  let id: String
  let title: String
  let startMinute: Int
  let endMinute: Int
  let mode: String
  let isEnabled: Bool
}

struct ApplicationsPolicy: Codable {
  let enforcementEnabled: Bool
  let blocked: [ApplicationPolicyRule]
  let allowed: [ApplicationPolicyRule]
}

struct ApplicationPolicyRule: Codable, Identifiable {
  let bundleIdentifier: String
  let displayName: String
  let isEnabled: Bool
  let addedAt: String

  var id: String {
    bundleIdentifier
  }
}

extension TortoisePolicy {
  static let browserFeatureKeys = [
    "youtubeHome",
    "youtubeVideoSidebar",
    "youtubeRecommendations",
    "youtubeLiveChat",
    "youtubePlaylists",
    "youtubeFundraisers",
    "youtubeEndScreens",
    "youtubeEndScreenCards",
    "youtubeShorts",
    "youtubeComments",
    "youtubeMixes",
    "youtubeMerch",
    "youtubeVideoInfo",
    "youtubeTopHeader",
    "youtubeNotifications",
    "youtubeSearch",
    "youtubeExplore",
    "youtubeMoreFromYouTube",
    "youtubeSubscriptions",
    "youtubeAutoplay",
    "youtubeAnnotations",
    "youtubeUsageTracking",
    "youtubeDailyLimit",
    "xSensitiveMedia",
    "xExplicitContent",
    "xExplicitSearch",
    "xVideos",
    "xPhotos",
    "xMediaCards",
    "xExploreTrends",
    "instagramReels",
    "instagramExplore",
    "instagramSuggested",
    "instagramStories",
    "redditPopularAll",
    "redditRecommendations",
    "redditNSFW",
    "redditMedia",
    "redditSidebars"
  ]

  static let focusBrowserFeatureKeys: Set<String> = [
    "youtubeHome",
    "youtubeShorts",
    "youtubeUsageTracking",
    "xSensitiveMedia",
    "xVideos",
    "instagramReels",
    "instagramExplore",
    "instagramSuggested",
    "redditPopularAll",
    "redditRecommendations"
  ]

  var normalizedMode: String {
    mode.capitalized
  }

  var enabledBrowserFeatureCount: Int {
    browser?.features.values.filter { $0 }.count ?? 0
  }

  func featureEnabled(withPrefix prefix: String) -> Bool {
    let normalizedPrefix = prefix.lowercased()
    return browser?.features.contains { key, isEnabled in
      isEnabled && key.lowercased().hasPrefix(normalizedPrefix)
    } ?? false
  }

  var activeBlockedAppCount: Int {
    applications?.blocked.filter(\.isEnabled).count ?? 0
  }

  var activeAllowedAppCount: Int {
    applications?.allowed.filter(\.isEnabled).count ?? 0
  }

  var activeFocusWindowCount: Int {
    schedules?.dailyFocusWindows.filter(\.isEnabled).count ?? 0
  }

  func settingMode(_ mode: String) -> TortoisePolicy {
    let normalizedMode = ["open", "focus", "strict"].contains(mode) ? mode : "focus"
    return TortoisePolicy(
      schemaVersion: schemaVersion,
      mode: normalizedMode,
      adultBlockingEnabled: normalizedMode != "open",
      browser: normalizedBrowserPolicy(settingFeatures: Self.defaultFeatures(for: normalizedMode), mode: normalizedMode),
      schedules: normalizedSchedulePolicy(),
      applications: normalizedApplicationsPolicy()
    )
  }

  func settingBrowserFeature(_ feature: String, enabled: Bool) -> TortoisePolicy {
    settingBrowserFeatures([feature], enabled: enabled)
  }

  func settingBrowserFeatures(_ features: [String], enabled: Bool) -> TortoisePolicy {
    var nextFeatures = normalizedBrowserFeatures()
    for feature in features where Self.browserFeatureKeys.contains(feature) {
      nextFeatures[feature] = enabled
    }

    return TortoisePolicy(
      schemaVersion: schemaVersion,
      mode: mode,
      adultBlockingEnabled: adultBlockingEnabled,
      browser: normalizedBrowserPolicy(settingFeatures: nextFeatures, mode: mode),
      schedules: normalizedSchedulePolicy(),
      applications: normalizedApplicationsPolicy()
    )
  }

  func settingYouTubeDailyLimit(minutes: Int) -> TortoisePolicy {
    let boundedMinutes = min(max(minutes, 5), 480)
    let normalizedBrowser = normalizedBrowserPolicy(settingFeatures: normalizedBrowserFeatures(), mode: mode)
    let options = BrowserPolicyOptions(
      explicitHideStyle: normalizedBrowser.options?.explicitHideStyle ?? "post",
      youtubeDailyLimitMinutes: boundedMinutes
    )
    return TortoisePolicy(
      schemaVersion: schemaVersion,
      mode: mode,
      adultBlockingEnabled: adultBlockingEnabled,
      browser: BrowserPolicy(
        features: normalizedBrowser.features,
        blockedDomains: normalizedBrowser.blockedDomains,
        blockedCategories: normalizedBrowser.blockedCategories,
        options: options
      ),
      schedules: normalizedSchedulePolicy(),
      applications: normalizedApplicationsPolicy()
    )
  }

  private static func defaultFeatures(for mode: String) -> [String: Bool] {
    switch mode {
    case "strict":
      return Dictionary(uniqueKeysWithValues: browserFeatureKeys.map { ($0, true) })
    case "focus":
      return Dictionary(uniqueKeysWithValues: browserFeatureKeys.map { ($0, focusBrowserFeatureKeys.contains($0)) })
    default:
      return Dictionary(uniqueKeysWithValues: browserFeatureKeys.map { ($0, false) })
    }
  }

  private func normalizedBrowserFeatures() -> [String: Bool] {
    let existing = browser?.features ?? Self.defaultFeatures(for: mode)
    return Dictionary(uniqueKeysWithValues: Self.browserFeatureKeys.map { ($0, existing[$0] ?? false) })
  }

  private func normalizedBrowserPolicy(settingFeatures features: [String: Bool], mode: String) -> BrowserPolicy {
    let existing = browser
    return BrowserPolicy(
      features: Dictionary(uniqueKeysWithValues: Self.browserFeatureKeys.map { ($0, features[$0] ?? false) }),
      blockedDomains: existing?.blockedDomains ?? [],
      blockedCategories: mode == "open" ? [] : (existing?.blockedCategories.isEmpty == false ? existing?.blockedCategories ?? ["adultContent"] : ["adultContent"]),
      options: BrowserPolicyOptions(
        explicitHideStyle: existing?.options?.explicitHideStyle ?? "post",
        youtubeDailyLimitMinutes: existing?.options?.youtubeDailyLimitMinutes ?? 30
      )
    )
  }

  private func normalizedSchedulePolicy() -> SchedulePolicy {
    schedules ?? SchedulePolicy(enabled: false, dailyFocusWindows: [])
  }

  private func normalizedApplicationsPolicy() -> ApplicationsPolicy {
    applications ?? ApplicationsPolicy(enforcementEnabled: true, blocked: [], allowed: [])
  }
}

struct DevicesEnvelope: Decodable {
  let devices: [TortoiseDevice]
}

struct DeviceEnvelope: Decodable {
  let device: TortoiseDevice
}

struct TortoiseDevice: Decodable, Identifiable {
  let id: String
  let platform: String?
  let name: String?
  let appVersion: String?
  let helperVersion: String?
  let lastSeenAt: String?

  enum CodingKeys: String, CodingKey {
    case id
    case platform
    case name
    case appVersion = "app_version"
    case helperVersion = "helper_version"
    case lastSeenAt = "last_seen_at"
  }
}

enum JSONValue: Codable {
  case string(String)
  case bool(Bool)
  case int(Int)
  case double(Double)
  case object([String: JSONValue])
  case array([JSONValue])
  case null

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Int.self) {
      self = .int(value)
    } else if let value = try? container.decode(Double.self) {
      self = .double(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([String: JSONValue].self) {
      self = .object(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Unsupported JSON value."
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    switch self {
    case .string(let value):
      try container.encode(value)
    case .bool(let value):
      try container.encode(value)
    case .int(let value):
      try container.encode(value)
    case .double(let value):
      try container.encode(value)
    case .object(let value):
      try container.encode(value)
    case .array(let value):
      try container.encode(value)
    case .null:
      try container.encodeNil()
    }
  }
}

struct DeviceRegistration: Encodable {
  let installationId: String
  let platform: String
  let name: String
  let appVersion: String?
  let platformMetadata: [String: JSONValue]
}

struct DeviceHealth: Encodable {
  let appVersion: String?
  let platformMetadata: [String: JSONValue]
  let canaryStatus: [String: JSONValue]
  let adultProtection: [String: JSONValue]
}

struct PolicyUpdateRequest: Encodable {
  let expectedSettingsVersion: Int
  let policy: TortoisePolicy
}

struct AccountHubSnapshot {
  var policy: PolicyEnvelope?
  var device: TortoiseDevice?
  var devices: [TortoiseDevice] = []
  var siteUsageSummary: SiteUsageSummarySnapshot?
  var lastSyncedAt: Date?
}
