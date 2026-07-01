import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

enum TortoiseAppGroup {
  static let identifier = "group.com.yourtortoise.Tortoise"

  static var defaults: UserDefaults {
    UserDefaults(suiteName: identifier) ?? .standard
  }
}

enum IOSEnforcementMode: String, Codable, CaseIterable, Identifiable {
  case open
  case focus
  case strict

  var id: String { rawValue }
}

enum IOSEnforcementAuthorizationMode: String, Codable, CaseIterable, Identifiable {
  case individual
  case child

  var id: String { rawValue }

  var familyMember: FamilyControlsMember {
    switch self {
    case .individual:
      return .individual
    case .child:
      return .child
    }
  }
}

enum IOSEnforcementSetupStep: String, Codable, CaseIterable, Identifiable {
  case account
  case authorizationMode
  case screenTimePermission
  case targets
  case safariExtension
  case mode
  case sync

  var id: String { rawValue }
}

enum IOSEnforcementSetupStatus: String, Codable, Equatable {
  case complete
  case needsAction
  case checking
  case failed
}

enum IOSEnforcementConnectionState: String, Codable, Equatable {
  case connected
  case partial
  case setupRequired
  case repairRequired
}

enum IOSSafariExtensionState: String, Codable, Equatable {
  case unknown
  case unavailable
  case disabled
  case enabledWaitingForHeartbeat
  case connected
  case failed
}

struct IOSEnforcementSnapshot: Codable, Equatable {
  var mode: IOSEnforcementMode
  var authorizationMode: IOSEnforcementAuthorizationMode
  var shieldingEnabled: Bool
  var dailyLimitMinutes: Int
  var adultWebFilterEnabled: Bool
  var safariExtensionEnabled: Bool
  var selectedApplicationCount: Int
  var selectedCategoryCount: Int
  var selectedWebDomainCount: Int
  var scheduleActive: Bool
  var lastAppliedAt: Date?
  var lastError: String?
  var safariExtensionState: IOSSafariExtensionState? = nil
  var lastSafariExtensionSeenAt: Date? = nil
  var lastSafariPolicyMode: IOSEnforcementMode? = nil
  var lastSafariPolicyAppliedAt: Date? = nil
  var lastSetupCheckAt: Date? = nil

  var hasSelectedTargets: Bool {
    selectedApplicationCount > 0 || selectedCategoryCount > 0 || selectedWebDomainCount > 0
  }

  static let empty = IOSEnforcementSnapshot(
    mode: .open,
    authorizationMode: .individual,
    shieldingEnabled: false,
    dailyLimitMinutes: 30,
    adultWebFilterEnabled: false,
    safariExtensionEnabled: false,
    selectedApplicationCount: 0,
    selectedCategoryCount: 0,
    selectedWebDomainCount: 0,
    scheduleActive: false,
    lastAppliedAt: nil,
    lastError: nil
  )
}

struct IOSEnforcementThresholdEvent: Codable, Equatable {
  let eventName: String
  let activityName: String
  let reachedAt: Date
}

struct SafariExtensionPolicy: Codable, Equatable {
  var mode: IOSEnforcementMode
  var features: [String: Bool]
  var options: [String: Int]
  var blockedDomains: [String]
  var browserID: String
  var browserProfile: SafariBrowserProfile

  static let open = SafariExtensionPolicy(
    mode: .open,
    features: SafariExtensionPolicy.openFeatures,
    options: ["youtubeDailyLimitMinutes": 30],
    blockedDomains: [],
    browserID: "ios-safari",
    browserProfile: SafariBrowserProfile(
      id: "ios-safari",
      name: "Safari",
      label: "Safari on iPhone"
    )
  )

  static func policy(
    for mode: IOSEnforcementMode,
    dailyLimitMinutes: Int,
    adultWebFilterEnabled: Bool
  ) -> SafariExtensionPolicy {
    switch mode {
    case .open:
      var policy = open
      policy.options["youtubeDailyLimitMinutes"] = dailyLimitMinutes
      return policy
    case .focus:
      return SafariExtensionPolicy(
        mode: .focus,
        features: focusFeatures,
        options: ["youtubeDailyLimitMinutes": dailyLimitMinutes],
        blockedDomains: adultWebFilterEnabled ? adultFallbackDomains : [],
        browserID: "ios-safari",
        browserProfile: open.browserProfile
      )
    case .strict:
      return SafariExtensionPolicy(
        mode: .strict,
        features: strictFeatures,
        options: ["youtubeDailyLimitMinutes": dailyLimitMinutes],
        blockedDomains: adultWebFilterEnabled ? adultFallbackDomains : [],
        browserID: "ios-safari",
        browserProfile: open.browserProfile
      )
    }
  }

  var storageObject: [String: Any] {
    [
      "mode": mode.rawValue,
      "features": features,
      "options": options,
      "blockedDomains": blockedDomains,
      "browserID": browserID,
      "browserProfile": browserProfile.storageObject
    ]
  }

  private static let openFeatures: [String: Bool] = [
    "youtubeHome": false,
    "youtubeVideoSidebar": false,
    "youtubeShorts": false,
    "youtubeComments": false,
    "youtubeRecommendations": false,
    "youtubeSearch": false,
    "youtubeEndScreens": false,
    "youtubeEndScreenCards": false,
    "youtubeLiveChat": false,
    "youtubeAutoplay": false,
    "youtubePlaylists": false,
    "youtubeFundraisers": false,
    "youtubeMixes": false,
    "youtubeMerch": false,
    "youtubeVideoInfo": false,
    "youtubeTopHeader": false,
    "youtubeNotifications": false,
    "youtubeExplore": false,
    "youtubeMoreFromYouTube": false,
    "youtubeSubscriptions": false,
    "youtubeAnnotations": false,
    "youtubeUsageTracking": true,
    "youtubeDailyLimit": false,
    "xSensitiveMedia": false,
    "xExplicitContent": false,
    "xExplicitSearch": false,
    "xVideos": false,
    "xPhotos": false,
    "xMediaCards": false,
    "xExploreTrends": false,
    "instagramReels": false,
    "instagramExplore": false,
    "instagramSuggested": false,
    "instagramStories": false,
    "instagramMessages": false,
    "redditPopular": false,
    "redditRecommendations": false,
    "redditNSFW": false,
    "redditMedia": false,
    "redditSidebars": false
  ]

  private static var focusFeatures: [String: Bool] {
    var features = openFeatures
    [
      "youtubeHome",
      "youtubeShorts",
      "youtubeRecommendations",
      "youtubeVideoSidebar",
      "youtubeAutoplay",
      "youtubeExplore",
      "xSensitiveMedia",
      "xVideos",
      "xExploreTrends",
      "instagramReels",
      "instagramExplore",
      "instagramSuggested",
      "redditPopular",
      "redditRecommendations",
      "redditNSFW"
    ].forEach { features[$0] = true }
    return features
  }

  private static var strictFeatures: [String: Bool] {
    var features = openFeatures
    for key in Array(features.keys) {
      features[key] = true
    }
    return features
  }

  private static let adultFallbackDomains = [
    "pornhub.com",
    "xvideos.com",
    "xnxx.com",
    "xhamster.com",
    "redtube.com",
    "youporn.com",
    "spankbang.com",
    "onlyfans.com",
    "fansly.com",
    "redgifs.com"
  ]
}

struct SafariBrowserProfile: Codable, Equatable {
  let id: String
  let name: String
  let label: String

  var storageObject: [String: Any] {
    [
      "id": id,
      "name": name,
      "label": label
    ]
  }
}

enum IOSEnforcementSharedStore {
  private static let selectionKey = "TortoiseIOSEnforcementSelection"
  private static let snapshotKey = "TortoiseIOSEnforcementSnapshot"
  private static let safariPolicyKey = "TortoiseIOSSafariPolicy"
  static let siteUsageKey = "TortoiseSiteUsageBySite"
  private static let thresholdEventsKey = "TortoiseIOSThresholdEvents"
  static let safariHeartbeatFreshInterval: TimeInterval = 15 * 60

  static func loadSelection() -> FamilyActivitySelection {
    guard let data = defaults.data(forKey: selectionKey),
          let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
      return FamilyActivitySelection()
    }
    return selection
  }

  static func saveSelection(_ selection: FamilyActivitySelection) {
    guard let data = try? JSONEncoder().encode(selection) else {
      return
    }
    defaults.set(data, forKey: selectionKey)
  }

  static func loadSnapshot() -> IOSEnforcementSnapshot {
    guard let data = defaults.data(forKey: snapshotKey),
          let snapshot = try? JSONDecoder().decode(IOSEnforcementSnapshot.self, from: data) else {
      return .empty
    }
    return snapshot
  }

  static func saveSnapshot(_ snapshot: IOSEnforcementSnapshot) {
    guard let data = try? JSONEncoder().encode(snapshot) else {
      return
    }
    defaults.set(data, forKey: snapshotKey)
  }

  static func updateSnapshot(_ update: (inout IOSEnforcementSnapshot) -> Void) {
    var snapshot = loadSnapshot()
    update(&snapshot)
    saveSnapshot(snapshot)
  }

  static func loadSafariPolicy() -> SafariExtensionPolicy {
    guard let data = defaults.data(forKey: safariPolicyKey),
          let policy = try? JSONDecoder().decode(SafariExtensionPolicy.self, from: data) else {
      return .open
    }
    return policy
  }

  static func saveSafariPolicy(_ policy: SafariExtensionPolicy) {
    guard let data = try? JSONEncoder().encode(policy) else {
      return
    }
    defaults.set(data, forKey: safariPolicyKey)
  }

  static func recordSafariExtensionHeartbeat(policyMode: IOSEnforcementMode) {
    updateSnapshot { snapshot in
      let now = Date()
      snapshot.safariExtensionEnabled = true
      snapshot.safariExtensionState = .connected
      snapshot.lastSafariExtensionSeenAt = now
      snapshot.lastSafariPolicyMode = policyMode
      snapshot.lastSafariPolicyAppliedAt = now
    }
  }

  static func safariHeartbeatIsFresh(_ date: Date?, now: Date = Date()) -> Bool {
    guard let date else {
      return false
    }
    return now.timeIntervalSince(date) <= safariHeartbeatFreshInterval
  }

  static func saveSiteUsageBySite(_ usage: [String: Any]) {
    defaults.set(usage, forKey: siteUsageKey)
  }

  static func loadSiteUsageBySite() -> [String: [String: Any]]? {
    defaults.dictionary(forKey: siteUsageKey) as? [String: [String: Any]]
  }

  static func recordThresholdEvent(_ event: IOSEnforcementThresholdEvent) {
    var events = loadThresholdEvents()
    events.append(event)
    events = Array(events.suffix(25))
    guard let data = try? JSONEncoder().encode(events) else {
      return
    }
    defaults.set(data, forKey: thresholdEventsKey)
  }

  static func loadThresholdEvents() -> [IOSEnforcementThresholdEvent] {
    guard let data = defaults.data(forKey: thresholdEventsKey),
          let events = try? JSONDecoder().decode([IOSEnforcementThresholdEvent].self, from: data) else {
      return []
    }
    return events
  }

  private static var defaults: UserDefaults {
    TortoiseAppGroup.defaults
  }
}

enum IOSEnforcementShieldApplier {
  static func applySelection(
    _ selection: FamilyActivitySelection,
    to store: ManagedSettingsStore,
    adultWebFilterEnabled: Bool
  ) {
    store.shield.applications = selection.applicationTokens.nilIfEmpty
    store.shield.webDomains = selection.webDomainTokens.nilIfEmpty
    store.shield.applicationCategories = selection.categoryTokens.isEmpty
      ? nil
      : .specific(selection.categoryTokens)
    store.shield.webDomainCategories = selection.categoryTokens.isEmpty
      ? nil
      : .specific(selection.categoryTokens)
    store.webContent.blockedByFilter = adultWebFilterEnabled ? .auto() : nil
    store.media.denyExplicitContent = adultWebFilterEnabled ? true : nil
  }

  static func clearAllStores() {
    for name in ManagedSettingsStore.Name.tortoiseEnforcementStores {
      ManagedSettingsStore(named: name).clearAllSettings()
    }
  }
}

extension Set {
  fileprivate var nilIfEmpty: Set<Element>? {
    isEmpty ? nil : self
  }
}

extension ManagedSettingsStore.Name {
  static let tortoiseImmediate = Self("tortoise.immediate")
  static let tortoiseSchedule = Self("tortoise.schedule")
  static let tortoiseLimit = Self("tortoise.limit")

  static let tortoiseEnforcementStores: [Self] = [
    .tortoiseImmediate,
    .tortoiseSchedule,
    .tortoiseLimit
  ]
}

extension DeviceActivityName {
  static let tortoiseDaily = Self("tortoise.daily")
}

extension DeviceActivityEvent.Name {
  static let tortoiseDailyLimit = Self("tortoise.youtube.dailyLimit")
}
