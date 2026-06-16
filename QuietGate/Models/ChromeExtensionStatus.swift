import Foundation

struct ChromeExtensionStatus: Equatable {
  static let empty = ChromeExtensionStatus(
    selectedProfile: nil,
    profileCount: 0,
    loadedProfiles: [],
    disabledProfiles: [],
    sessionProfiles: [],
    profileDisplayNames: [:]
  )

  let selectedProfile: String?
  let profileCount: Int
  let loadedProfiles: [String]
  let disabledProfiles: [String]
  let sessionProfiles: [String]
  let profileDisplayNames: [String: String]

  init(
    selectedProfile: String?,
    profileCount: Int,
    loadedProfiles: [String],
    disabledProfiles: [String],
    sessionProfiles: [String],
    profileDisplayNames: [String: String] = [:]
  ) {
    self.selectedProfile = selectedProfile
    self.profileCount = profileCount
    self.loadedProfiles = loadedProfiles
    self.disabledProfiles = disabledProfiles
    self.sessionProfiles = sessionProfiles
    self.profileDisplayNames = profileDisplayNames
  }

  var ready: Bool {
    guard let selectedProfile, !selectedProfile.isEmpty else {
      return !readyProfiles.isEmpty
    }
    return readyProfiles.contains(selectedProfile)
  }

  var loadedElsewhere: Bool {
    guard let selectedProfile, !selectedProfile.isEmpty else {
      return false
    }
    return !readyProfiles.isEmpty && !readyProfiles.contains(selectedProfile)
  }

  var readyProfiles: [String] {
    Array(Set(loadedProfiles + sessionProfiles)).sorted()
  }

  var selectedProfileLabel: String? {
    guard let selectedProfile, !selectedProfile.isEmpty else {
      return nil
    }
    return profileLabel(for: selectedProfile)
  }

  var readyProfileLabels: [String] {
    readyProfiles.map { profileLabel(for: $0) }
  }

  var loadedProfileLabels: [String] {
    loadedProfiles.map { profileLabel(for: $0) }
  }

  var sessionProfileLabels: [String] {
    sessionProfiles.map { profileLabel(for: $0) }
  }

  var sessionReady: Bool {
    guard let selectedProfile, !selectedProfile.isEmpty else {
      return !sessionProfiles.isEmpty
    }
    return sessionProfiles.contains(selectedProfile)
  }

  var persistentReady: Bool {
    guard let selectedProfile, !selectedProfile.isEmpty else {
      return !loadedProfiles.isEmpty
    }
    return loadedProfiles.contains(selectedProfile)
  }

  func profileLabel(for profile: String) -> String {
    let profile = profile.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !profile.isEmpty else {
      return profile
    }
    let displayName = profileDisplayNames[profile]?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard let displayName,
          !displayName.isEmpty,
          displayName.caseInsensitiveCompare(profile) != .orderedSame else {
      return profile
    }
    return "\(displayName) (\(profile))"
  }

  func addingSessionProfile(_ profile: String) -> ChromeExtensionStatus {
    let normalized = profile.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else {
      return self
    }

    return ChromeExtensionStatus(
      selectedProfile: normalized,
      profileCount: max(profileCount, 1),
      loadedProfiles: loadedProfiles,
      disabledProfiles: disabledProfiles,
      sessionProfiles: Array(Set(sessionProfiles + [normalized])).sorted(),
      profileDisplayNames: profileDisplayNames
    )
  }
}

enum SystemBlockState: Equatable {
  case notReady
  case savedNeedsSync
  case active
  case error(String)
}

enum ChromeHelperState: Equatable {
  case notInstalled
  case nativeHostMissing
  case needsChromeOpen
  case needsSync
  case current
  case stale
  case extensionNeedsReload
  case error(String)

  var isCurrent: Bool {
    self == .current
  }

  var needsUserAction: Bool {
    switch self {
    case .current:
      return false
    case .notInstalled, .nativeHostMissing, .needsChromeOpen, .needsSync, .stale, .extensionNeedsReload, .error:
      return true
    }
  }
}

struct ChromeHelperSnapshot: Codable, Equatable {
  let schemaVersion: Int
  let extensionID: String
  let lastSeenAt: Date
  let lastAppliedSettingsVersion: String?
  let extensionVersion: String?
  let scriptVersions: [String: String]?
  let adultProtection: AdultProtectionHealthSnapshot?
  let platformControls: BrowserAccountPlatformControlsSnapshot?
  let youtubeUsage: YouTubeUsageSnapshot?
  let blockedRuleCount: Int
  let lastError: String?
  let browserID: String?
  let profileID: String?
  let profileName: String?

  init(
    schemaVersion: Int = 1,
    extensionID: String,
    lastSeenAt: Date,
    lastAppliedSettingsVersion: String?,
    extensionVersion: String?,
    scriptVersions: [String: String]? = nil,
    adultProtection: AdultProtectionHealthSnapshot? = nil,
    platformControls: BrowserAccountPlatformControlsSnapshot? = nil,
    youtubeUsage: YouTubeUsageSnapshot? = nil,
    blockedRuleCount: Int,
    lastError: String? = nil,
    browserID: String? = nil,
    profileID: String? = nil,
    profileName: String? = nil
  ) {
    self.schemaVersion = schemaVersion
    self.extensionID = extensionID
    self.lastSeenAt = lastSeenAt
    self.lastAppliedSettingsVersion = lastAppliedSettingsVersion
    self.extensionVersion = extensionVersion
    self.scriptVersions = scriptVersions
    self.adultProtection = adultProtection
    self.platformControls = platformControls
    self.youtubeUsage = youtubeUsage
    self.blockedRuleCount = blockedRuleCount
    self.lastError = lastError
    self.browserID = browserID
    self.profileID = profileID
    self.profileName = profileName
  }
}

struct YouTubeUsageSnapshot: Codable, Equatable {
  let date: String
  let totalSeconds: Int
  let lifetimeSeconds: Int
  let videoCount: Int
  let lifetimeVideoCount: Int
  let limitSeconds: Int?
  let limitReached: Bool
  let lastUpdatedAt: Date?

  init(
    date: String,
    totalSeconds: Int,
    lifetimeSeconds: Int = 0,
    videoCount: Int,
    lifetimeVideoCount: Int = 0,
    limitSeconds: Int? = nil,
    limitReached: Bool = false,
    lastUpdatedAt: Date? = nil
  ) {
    self.date = date
    self.totalSeconds = totalSeconds
    self.lifetimeSeconds = lifetimeSeconds
    self.videoCount = videoCount
    self.lifetimeVideoCount = lifetimeVideoCount
    self.limitSeconds = limitSeconds
    self.limitReached = limitReached
    self.lastUpdatedAt = lastUpdatedAt
  }
}

struct AdultProtectionHealthSnapshot: Codable, Equatable {
  let enabled: Bool
  let mode: String?
  let domainListCount: Int
  let seedDomainCount: Int
  let staticRulesetsEnabled: [String]
  let dynamicRuleCount: Int
  let scriptVersions: [String: String]?
  let canaryDomains: [String]
  let checkedAt: Date?

  init(
    enabled: Bool,
    mode: String? = nil,
    domainListCount: Int,
    seedDomainCount: Int,
    staticRulesetsEnabled: [String] = [],
    dynamicRuleCount: Int,
    scriptVersions: [String: String]? = nil,
    canaryDomains: [String] = [],
    checkedAt: Date? = nil
  ) {
    self.enabled = enabled
    self.mode = mode
    self.domainListCount = domainListCount
    self.seedDomainCount = seedDomainCount
    self.staticRulesetsEnabled = staticRulesetsEnabled
    self.dynamicRuleCount = dynamicRuleCount
    self.scriptVersions = scriptVersions
    self.canaryDomains = canaryDomains
    self.checkedAt = checkedAt
  }
}
