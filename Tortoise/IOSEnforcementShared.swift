import Foundation
#if os(iOS)
import DeviceActivity
import FamilyControls
import ManagedSettings
#endif

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

  #if os(iOS)
  var familyMember: FamilyControlsMember {
    switch self {
    case .individual:
      return .individual
    case .child:
      return .child
    }
  }
  #endif
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
  var session: IOSSessionState? = nil
  /// Stage 2: combined managed-apps daily limit (minutes). `nil` = off. Persisted
  /// so the DeviceActivity monitor extension can gate the limit shield. `Int?` is
  /// cross-platform safe — no `FamilyControls`/`ManagedSettings` type leaks here.
  var managedAppsLimitMinutes: Int? = nil

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

  private static var openFeatures: [String: Bool] { TuningCatalog.enabledFeatureFlags(for: "open") }
  private static var focusFeatures: [String: Bool] { TuningCatalog.enabledFeatureFlags(for: "focus") }
  private static var strictFeatures: [String: Bool] { TuningCatalog.enabledFeatureFlags(for: "strict") }

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
  private static let managedAppsSelectionKey = "TortoiseIOSManagedAppsSelection"
  private static let snapshotKey = "TortoiseIOSEnforcementSnapshot"
  private static let safariPolicyKey = "TortoiseIOSSafariPolicy"
  static let siteUsageKey = "TortoiseSiteUsageBySite"
  private static let thresholdEventsKey = "TortoiseIOSThresholdEvents"
  static let safariHeartbeatFreshInterval: TimeInterval = 15 * 60

  /// Written by the ShieldConfiguration extension when iOS asks it to shield
  /// Tortoise itself ("Tortoise can't block Tortoise"). The key string is
  /// duplicated there — that target does not compile this file.
  private static let selfShieldKey = "TortoiseSelfShieldDetectedAt"

  /// Returns true exactly once per detected self-shield, clearing the flag.
  static func consumeSelfShieldFlag() -> Bool {
    guard defaults.object(forKey: selfShieldKey) != nil else {
      return false
    }
    defaults.removeObject(forKey: selfShieldKey)
    return true
  }

  #if os(iOS)
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

  static func loadManagedAppsSelection() -> FamilyActivitySelection {
    guard let data = defaults.data(forKey: managedAppsSelectionKey),
          let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
      return FamilyActivitySelection()
    }
    return selection
  }

  static func saveManagedAppsSelection(_ selection: FamilyActivitySelection) {
    guard let data = try? JSONEncoder().encode(selection) else {
      return
    }
    defaults.set(data, forKey: managedAppsSelectionKey)
  }
  #endif

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

#if os(iOS)
enum IOSEnforcementShieldApplier {
  static func applySelection(
    _ selection: FamilyActivitySelection,
    to store: ManagedSettingsStore,
    adultWebFilterEnabled: Bool
  ) {
    store.shield.applications = selection.applicationTokens.nilIfEmpty
    store.shield.webDomains = selection.webDomainTokens.nilIfEmpty
    // NEVER shield raw category tokens: an opaque category can contain
    // Tortoise itself, and iOS would silently keep closing Tortoise (no crash
    // log). Category picks enforce via their member-app tokens, expanded at
    // pick time with FamilyActivitySelection(includeEntireCategory: true).
    store.shield.applicationCategories = nil
    store.shield.webDomainCategories = nil
    store.webContent.blockedByFilter = adultWebFilterEnabled ? .auto() : nil
    store.media.denyExplicitContent = adultWebFilterEnabled ? true : nil
  }

  /// Writes ONLY the shield fields from `selection` into `store` — no adult web/
  /// media filter (that stays on the YouTube/Strict `applySelection` path). Used
  /// for the general "Apps" store so the two shields union cleanly.
  static func applyShield(
    _ selection: FamilyActivitySelection,
    to store: ManagedSettingsStore
  ) {
    store.shield.applications = selection.applicationTokens.nilIfEmpty
    store.shield.webDomains = selection.webDomainTokens.nilIfEmpty
    // See applySelection: raw category shields could catch Tortoise itself.
    store.shield.applicationCategories = nil
    store.shield.webDomainCategories = nil
  }

  static func clearAllStores() {
    for name in ManagedSettingsStore.Name.tortoiseEnforcementStores {
      ManagedSettingsStore(named: name).clearAllSettings()
    }
  }

  /// Clears EVERY store any Tortoise build has ever written — including the
  /// event-owned stores (`.tortoiseSchedule`, `.tortoiseLimit`,
  /// `.tortoiseManagedApps*`) that normal enforcement passes never rewrite.
  /// ManagedSettings persist system-side until explicitly cleared, so a stale
  /// category shield from an old build (which can include Tortoise itself)
  /// survives app updates unless this runs. Used by the launch migration and
  /// the self-shield repair.
  static func purgeAllStoresEverWritten() {
    for name in ManagedSettingsStore.Name.tortoiseAllStores {
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

  /// The general "Apps" (Screen-Time) shield lives in its OWN store so the system
  /// UNIONS it with the YouTube shield in `.tortoiseImmediate` automatically —
  /// no manual merge. Deliberately NOT part of `tortoiseEnforcementStores`: this
  /// store is owned solely by `applyManagedAppsShield()`, which reconciles it on
  /// every `applyCurrentMode()`, so the YouTube `clearAllStores()` sweep never
  /// touches it.
  static let tortoiseManagedApps = Self("tortoise.managedApps")

  /// Stage 2: the combined managed-apps DAILY-LIMIT shield store. Written by the
  /// DeviceActivity monitor extension when the Open-mode combined threshold is
  /// reached; the OS UNIONS it with `.tortoiseManagedApps` (Stage 1) and the
  /// YouTube `.tortoiseImmediate` shield automatically. Like `.tortoiseManagedApps`
  /// it is deliberately NOT in `tortoiseEnforcementStores` — it is owned by its own
  /// reconcile paths (`reconcileManagedAppsLimitMonitoring()` disarm + the
  /// extension's `intervalDidStart`/`intervalDidEnd`), so the YouTube
  /// `clearAllStores()` sweep never touches it.
  static let tortoiseManagedAppsLimit = Self("tortoise.managedApps.limit")

  static let tortoiseEnforcementStores: [Self] = [
    .tortoiseImmediate,
    .tortoiseSchedule,
    .tortoiseLimit
  ]

  /// Every store name any shipped Tortoise build has ever written. Append-only:
  /// if a store name is ever retired, it must STAY here so the purge can clear
  /// what old installs left behind.
  static let tortoiseAllStores: [Self] = [
    .tortoiseImmediate,
    .tortoiseSchedule,
    .tortoiseLimit,
    .tortoiseManagedApps,
    .tortoiseManagedAppsLimit
  ]
}

extension DeviceActivityName {
  static let tortoiseDaily = Self("tortoise.daily")

  /// Stage 2: the managed-apps limit runs on its OWN DeviceActivity so it is
  /// independent of the YouTube `.tortoiseDaily` start/stop lifecycle and can run
  /// in Open mode (where `.tortoiseDaily` is stopped).
  static let tortoiseManagedAppsDaily = Self("tortoise.managedApps.daily")
}

extension DeviceActivityEvent.Name {
  static let tortoiseDailyLimit = Self("tortoise.youtube.dailyLimit")

  /// Stage 2: combined managed-apps daily-limit threshold event. Routed by NAME in
  /// the extension to `.tortoiseManagedAppsLimit`.
  static let managedAppsDailyLimit = Self("tortoise.managedApps.dailyLimit")
}
#endif
