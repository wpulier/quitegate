import AppKit
import ClerkKit
import CryptoKit
import Foundation

enum MacAccountSessionState: Equatable {
  case signedOut
  case signingIn
  case signedIn
  case needsReconnect
  case syncUnavailable(String)
}

enum MacPolicySyncState: Equatable {
  case current
  case syncing
  case conflict
  case failed(String)
  case stale
}

@MainActor
final class MacAccountStore: ObservableObject {
  @Published var sessionState: MacAccountSessionState = .signedOut
  @Published var syncState: MacPolicySyncState = .stale
  @Published var snapshot = AccountHubSnapshot()
  @Published var isSyncing = false
  @Published var syncMessage = "Sign in to sync this Mac."

  private let apiClient = MacTortoiseAPIClient()

  var isSignedIn: Bool {
    if case .signedIn = sessionState {
      return true
    }
    return false
  }

  var accountDisplayName: String {
    guard let user = Clerk.shared.user else {
      return "Tortoise account"
    }

    let parts = [user.firstName, user.lastName]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    if !parts.isEmpty {
      return parts.joined(separator: " ")
    }

    return user.username ?? user.primaryEmailAddress?.emailAddress ?? "Tortoise account"
  }

  var accountEmail: String {
    Clerk.shared.user?.primaryEmailAddress?.emailAddress ?? "Signed in"
  }

  var accountInitials: String {
    let words = accountDisplayName
      .split(separator: " ")
      .prefix(2)
      .compactMap(\.first)
    let initials = String(words).uppercased()
    if !initials.isEmpty {
      return initials
    }
    return "T"
  }

  var accountFooterText: String {
    switch syncState {
    case .current:
      return "\(max(connectedDeviceCount, snapshot.device == nil ? 0 : 1)) connected"
    case .syncing:
      return "Syncing account"
    case .conflict:
      return "Settings changed"
    case .failed:
      return "Reconnect account"
    case .stale:
      return "Setup needed"
    }
  }

  var connectedDeviceCount: Int {
    snapshot.devices.filter { device in
      guard let lastSeenAt = device.lastSeenAt else {
        return false
      }
      return Self.date(from: lastSeenAt).map { Date().timeIntervalSince($0) < 7 * 24 * 3600 } ?? true
    }.count
  }

  var macConnectionStatus: String {
    guard snapshot.device != nil else {
      return isSignedIn ? "Setup needed" : "Sign in"
    }
    switch syncState {
    case .current:
      return "Connected"
    case .syncing:
      return "Syncing"
    case .conflict:
      return "Refresh"
    case .failed, .stale:
      return "Needs repair"
    }
  }

  func refresh(
    using clerk: Clerk,
    protectionStore: ProtectionStore,
    appBlockingStore: AppBlockingStore
  ) async {
    guard let session = clerk.session else {
      snapshot = AccountHubSnapshot()
      sessionState = .signedOut
      syncState = .stale
      syncMessage = "Sign in to sync this Mac."
      return
    }

    isSyncing = true
    syncState = .syncing
    defer { isSyncing = false }

    do {
      guard let token = try await session.getToken() else {
        throw TortoiseAPIError.missingSessionToken
      }

      var policyEnvelope = try await apiClient.fetchPolicy(token: token)
      let registeredDevice = try await registerMac(token: token, protectionStore: protectionStore)

      if shouldMigrateLocalPolicy(policyEnvelope, protectionStore: protectionStore, appBlockingStore: appBlockingStore) {
        policyEnvelope = try await apiClient.updatePolicy(
          token: token,
          policy: protectionStore.accountPolicySnapshot(appBlockingStore: appBlockingStore),
          expectedSettingsVersion: policyEnvelope.settingsVersion
        )
      } else {
        let applied = await protectionStore.applyAccountPolicy(
          policyEnvelope.policy,
          appBlockingStore: appBlockingStore
        )
        if !applied && protectionStore.timedSessionLockedActive {
          syncMessage = "A locked session is running. Tortoise will apply account changes after it ends."
        }
      }

      try? await postHealth(
        token: token,
        deviceId: registeredDevice.id,
        policyEnvelope: policyEnvelope,
        protectionStore: protectionStore,
        appBlockingStore: appBlockingStore
      )

      let devices = try await apiClient.fetchDevices(token: token).devices
      let siteUsageSummary = try? await apiClient.fetchSiteUsage(
        token: token,
        date: SiteUsageSummaryMerge.localDateKey()
      )
      snapshot = AccountHubSnapshot(
        policy: policyEnvelope,
        device: registeredDevice,
        devices: devices,
        siteUsageSummary: siteUsageSummary ?? snapshot.siteUsageSummary,
        lastSyncedAt: Date()
      )
      sessionState = .signedIn
      syncState = .current
      if !protectionStore.timedSessionLockedActive {
        syncMessage = "This Mac is connected. Policy and local enforcement are current."
      }
    } catch {
      sessionState = .syncUnavailable(error.localizedDescription)
      syncState = .failed(error.localizedDescription)
      syncMessage = error.localizedDescription
    }
  }

  /// Refreshes just the cross-device usage summary. Lightweight enough to
  /// poll while the Usage screen is visible; failures keep the last summary.
  func refreshUsage(using clerk: Clerk) async {
    guard let session = clerk.session,
          let token = try? await session.getToken() else {
      return
    }

    if let summary = try? await apiClient.fetchSiteUsage(
      token: token,
      date: SiteUsageSummaryMerge.localDateKey()
    ) {
      snapshot.siteUsageSummary = summary
    }
  }

  @discardableResult
  func updatePolicy(
    using clerk: Clerk,
    protectionStore: ProtectionStore,
    appBlockingStore: AppBlockingStore,
    transform: (TortoisePolicy) -> TortoisePolicy
  ) async -> TortoisePolicy? {
    guard let session = clerk.session else {
      sessionState = .needsReconnect
      syncMessage = "Sign in again to change synced settings."
      return nil
    }

    if snapshot.policy == nil {
      await refresh(using: clerk, protectionStore: protectionStore, appBlockingStore: appBlockingStore)
    }

    guard let currentEnvelope = snapshot.policy else {
      syncState = .stale
      syncMessage = "Account policy is not loaded yet."
      return nil
    }

    isSyncing = true
    syncState = .syncing
    defer { isSyncing = false }

    do {
      guard let token = try await session.getToken() else {
        throw TortoiseAPIError.missingSessionToken
      }

      let nextPolicy = transform(currentEnvelope.policy)
      let updatedEnvelope = try await apiClient.updatePolicy(
        token: token,
        policy: nextPolicy,
        expectedSettingsVersion: currentEnvelope.settingsVersion
      )
      snapshot.policy = updatedEnvelope
      snapshot.lastSyncedAt = Date()
      _ = await protectionStore.applyAccountPolicy(
        updatedEnvelope.policy,
        appBlockingStore: appBlockingStore
      )
      if let device = snapshot.device {
        try? await postHealth(
          token: token,
          deviceId: device.id,
          policyEnvelope: updatedEnvelope,
          protectionStore: protectionStore,
          appBlockingStore: appBlockingStore
        )
      }
      sessionState = .signedIn
      syncState = .current
      syncMessage = "Tortoise settings are synced."
      return updatedEnvelope.policy
    } catch {
      if let apiError = error as? TortoiseAPIError,
         case .server(let message) = apiError,
         message.localizedCaseInsensitiveContains("changed") {
        syncState = .conflict
        await refresh(using: clerk, protectionStore: protectionStore, appBlockingStore: appBlockingStore)
        syncMessage = "Settings changed on another device. Refreshed policy; try again."
      } else {
        syncState = .failed(error.localizedDescription)
        syncMessage = error.localizedDescription
      }
      return nil
    }
  }

  func pushLocalPolicy(
    using clerk: Clerk,
    protectionStore: ProtectionStore,
    appBlockingStore: AppBlockingStore
  ) async {
    await updatePolicy(
      using: clerk,
      protectionStore: protectionStore,
      appBlockingStore: appBlockingStore
    ) { _ in
      protectionStore.accountPolicySnapshot(appBlockingStore: appBlockingStore)
    }
  }

  func setAccessMode(
    _ mode: AccessMode,
    using clerk: Clerk,
    protectionStore: ProtectionStore,
    appBlockingStore: AppBlockingStore
  ) async {
    await updatePolicy(
      using: clerk,
      protectionStore: protectionStore,
      appBlockingStore: appBlockingStore
    ) { policy in
      policy.settingMode(mode.rawValue)
    }
  }

  func setTuningFeature(
    _ feature: BrowserTuningFeature,
    enabled: Bool,
    using clerk: Clerk,
    protectionStore: ProtectionStore,
    appBlockingStore: AppBlockingStore
  ) async {
    await updatePolicy(
      using: clerk,
      protectionStore: protectionStore,
      appBlockingStore: appBlockingStore
    ) { policy in
      policy.settingBrowserFeature(feature.rawValue, enabled: enabled)
    }
  }

  func setTuningFeatures(
    _ features: [BrowserTuningFeature],
    enabled: Bool,
    using clerk: Clerk,
    protectionStore: ProtectionStore,
    appBlockingStore: AppBlockingStore
  ) async {
    await updatePolicy(
      using: clerk,
      protectionStore: protectionStore,
      appBlockingStore: appBlockingStore
    ) { policy in
      policy.settingBrowserFeatures(features.map(\.rawValue), enabled: enabled)
    }
  }

  private func registerMac(token: String, protectionStore: ProtectionStore) async throws -> TortoiseDevice {
    let name = Host.current().localizedName ?? "This Mac"
    let registration = DeviceRegistration(
      installationId: InstallationStore.installationId(),
      platform: "macos",
      name: name,
      appVersion: Bundle.main.appVersion,
      platformMetadata: [
        "setupStatus": .string("signed_in"),
        "systemName": .string("macOS"),
        "systemVersion": .string(ProcessInfo.processInfo.operatingSystemVersionString),
        "browserSettingsVersion": .string(Self.settingsVersionDigest(protectionStore.currentBrowserSettingsVersion)),
        "capabilities": .object(Self.macCapabilities)
      ]
    )

    return try await apiClient.registerDevice(token: token, registration: registration).device
  }

  private func postHealth(
    token: String,
    deviceId: String,
    policyEnvelope: PolicyEnvelope,
    protectionStore: ProtectionStore,
    appBlockingStore: AppBlockingStore
  ) async throws {
    try await apiClient.postHealth(
      token: token,
      deviceId: deviceId,
      health: DeviceHealth(
        appVersion: Bundle.main.appVersion,
        platformMetadata: [
          "setupStatus": .string("signed_in"),
          "policyVersion": .int(policyEnvelope.settingsVersion),
          "mode": .string(protectionStore.accessMode.rawValue),
          "browserSettingsVersion": .string(Self.settingsVersionDigest(protectionStore.currentBrowserSettingsVersion)),
          "capabilities": .object(Self.macCapabilities)
        ],
        canaryStatus: [
          "accountClient": .string("live"),
          "policySync": .string(syncStateLabel),
          "browserProfiles": .int(protectionStore.connectedBrowserConnectors.count),
          "appBlocking": .string(appBlockingStore.enforcementEnabled ? "enabled" : "paused")
        ],
        adultProtection: [
          "mode": .string(protectionStore.accessMode.rawValue),
          "adultContentBlocking": .bool(protectionStore.adultContentBlockingEnabled),
          "blockedSiteCount": .int(protectionStore.enabledBlockedSites.count),
          "blockedAppCount": .int(appBlockingStore.activeBlockedApplications.count),
          "nativeHost": .string("bundled"),
          "sourceOfTruth": .string("supabase_policy")
        ]
      )
    )
  }

  private func shouldMigrateLocalPolicy(
    _ envelope: PolicyEnvelope,
    protectionStore: ProtectionStore,
    appBlockingStore: AppBlockingStore
  ) -> Bool {
    guard envelope.settingsVersion <= 1 else {
      return false
    }

    let local = protectionStore.accountPolicySnapshot(appBlockingStore: appBlockingStore)
    return local.mode != envelope.policy.mode
      || local.adultBlockingEnabled != envelope.policy.adultBlockingEnabled
      || local.browser?.features != envelope.policy.browser?.features
      || local.browser?.blockedDomains.isEmpty == false
      || local.browser?.blockedCategories != envelope.policy.browser?.blockedCategories
      || local.browser?.options?.explicitHideStyle != envelope.policy.browser?.options?.explicitHideStyle
      || local.browser?.options?.youtubeDailyLimitMinutes != envelope.policy.browser?.options?.youtubeDailyLimitMinutes
      || local.schedules?.enabled == true
      || local.schedules?.dailyFocusWindows.isEmpty == false
      || local.applications?.blocked.isEmpty == false
  }

  private var syncStateLabel: String {
    switch syncState {
    case .current:
      return "current"
    case .syncing:
      return "syncing"
    case .conflict:
      return "conflict"
    case .failed:
      return "failed"
    case .stale:
      return "stale"
    }
  }

  private static let macCapabilities: [String: JSONValue] = [
    "accountHub": .string("supported"),
    "policySync": .string("supported"),
    "deviceHealth": .string("supported"),
    "chromeTuning": .string("native_messaging_host"),
    "firefoxTuning": .string("native_messaging_host"),
    "youtubeUsageHover": .string("browser_extension"),
    "adultWebBlocking": .string("browser_extension_and_local_hosts"),
    "macAppBlocking": .string("running_app_monitor"),
    "iosScreenTime": .string("not_supported_on_macos")
  ]

  /// The full browser-settings fingerprint can exceed the backend's 1000-char
  /// metadata-string limit; send a short stable hash of it instead (it still
  /// changes whenever settings change).
  private static func settingsVersionDigest(_ value: String) -> String {
    let digest = SHA256.hash(data: Data(value.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  private static func date(from value: String) -> Date? {
    ISO8601DateFormatter().date(from: value)
  }
}

private extension Bundle {
  var appVersion: String {
    let shortVersion = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String
    let version = shortVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let buildNumber = build?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !version.isEmpty, !buildNumber.isEmpty {
      return "\(version) (\(buildNumber))"
    }
    return version.isEmpty ? buildNumber : version
  }
}
