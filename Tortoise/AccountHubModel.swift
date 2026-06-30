import ClerkKit
import Foundation
import UIKit

@MainActor
final class AccountHubModel: ObservableObject {
  @Published var snapshot = AccountHubSnapshot()
  @Published var isSyncing = false
  @Published var syncMessage = "Sign in to sync this device."

  private let apiClient = TortoiseAPIClient()

  func refresh(using clerk: Clerk) async {
    guard let session = clerk.session else {
      snapshot = AccountHubSnapshot()
      syncMessage = "Sign in to sync this device."
      return
    }

    isSyncing = true
    defer { isSyncing = false }

    do {
      guard let token = try await session.getToken() else {
        throw TortoiseAPIError.missingSessionToken
      }

      let policy = try await apiClient.fetchPolicy(token: token)
      let enforcementSnapshot = IOSEnforcementSharedStore.loadSnapshot()
      let registration = DeviceRegistration(
        installationId: InstallationStore.installationId(),
        platform: "ios",
        name: UIDevice.current.name,
        appVersion: Bundle.main.appVersion,
        platformMetadata: [
          "setupStatus": .string("signed_in"),
          "systemName": .string(UIDevice.current.systemName),
          "systemVersion": .string(UIDevice.current.systemVersion),
          "capabilities": .object(Self.iosCapabilities)
        ]
      )
      let registeredDevice = try await apiClient.registerDevice(
        token: token,
        registration: registration
      ).device
      let devices = try await apiClient.fetchDevices(token: token).devices
      let siteUsageSummary: SiteUsageSummarySnapshot?
      if let usageReport = IOSSiteUsageReporter.pendingReport(deviceName: UIDevice.current.name) {
        siteUsageSummary = try await apiClient.postSiteUsage(
          token: token,
          deviceId: registeredDevice.id,
          usage: usageReport
        ).siteUsageSummary
      } else {
        siteUsageSummary = try? await apiClient.fetchSiteUsage(token: token).siteUsageSummary
      }

      try? await apiClient.postHealth(
        token: token,
        deviceId: registeredDevice.id,
        health: DeviceHealth(
          appVersion: Bundle.main.appVersion,
          platformMetadata: [
            "setupStatus": .string("signed_in"),
            "policyVersion": .string("\(policy.settingsVersion)"),
            "capabilities": .object(Self.iosCapabilities),
            "iosEnforcement": .object(Self.enforcementMetadata(enforcementSnapshot))
          ],
          canaryStatus: [
            "accountHub": .string("live"),
            "policySync": .string("live"),
            "siteUsageSummary": .string(siteUsageSummary == nil ? "no_data" : "live"),
            "iosScreenTime": .string(enforcementSnapshot.shieldingEnabled ? "configured" : "available"),
            "iosSafariExtension": .string(enforcementSnapshot.safariExtensionEnabled ? "enabled_by_user" : "setup_required")
          ],
          adultProtection: [
            "iosEnforcement": .string("screen_time_device_activity"),
            "iosAuthorizationMode": .string(enforcementSnapshot.authorizationMode.rawValue),
            "iosMode": .string(enforcementSnapshot.mode.rawValue),
            "youtubeAppShielding": .string("family_controls_managed_settings"),
            "youtubeSafariShielding": .string("managed_web_domains_device_activity"),
            "iosSafariTuning": .string("safari_web_extension"),
            "deviceActivityMonitor": .string("installed"),
            "shieldConfiguration": .string("installed"),
            "shieldAction": .string("installed"),
            "appGroup": .string(TortoiseAppGroup.identifier),
            "screenTimeTokenPrivacy": .string("device_local_counts_only"),
            "siteUsage": .string("safari_extension_summary_live"),
            "sourceOfTruth": .string("supabase_policy")
          ]
        )
      )

      snapshot = AccountHubSnapshot(
        policy: policy,
        device: registeredDevice,
        devices: devices,
        siteUsageSummary: siteUsageSummary,
        lastSyncedAt: Date()
      )
      syncMessage = "This iPhone is registered. Policy and usage summaries are current."
    } catch {
      syncMessage = "Policy sync unavailable. Try again after account services are reachable."
    }
  }

  private static let iosCapabilities: [String: JSONValue] = [
    "accountHub": .string("supported"),
    "policySync": .string("supported"),
    "deviceHealth": .string("supported"),
    "siteUsageDisplay": .string("supported"),
    "siteUsageUpload": .string("supported"),
    "iosUsageCollector": .string("screen_time_privacy_limited"),
    "adultWebBlocking": .string("managed_settings_web_content_filter"),
    "youtubeAppShielding": .string("family_controls_device_activity"),
    "youtubeSafariShielding": .string("managed_web_domains_device_activity"),
    "youtubeDailyLimit": .string("device_activity_event"),
    "safariWebExtension": .string("supported"),
    "xTuning": .string("safari_web_extension"),
    "redditTuning": .string("safari_web_extension"),
    "youtubeTuning": .string("safari_web_extension"),
    "instagramTuning": .string("safari_web_extension"),
    "instagramBlocking": .string("screen_time_selection"),
    "macAppBlocking": .string("not_supported")
  ]

  private static func enforcementMetadata(_ snapshot: IOSEnforcementSnapshot) -> [String: JSONValue] {
    [
      "mode": .string(snapshot.mode.rawValue),
      "authorizationMode": .string(snapshot.authorizationMode.rawValue),
      "shieldingEnabled": .bool(snapshot.shieldingEnabled),
      "dailyLimitMinutes": .int(snapshot.dailyLimitMinutes),
      "selectedApplicationCount": .int(snapshot.selectedApplicationCount),
      "selectedCategoryCount": .int(snapshot.selectedCategoryCount),
      "selectedWebDomainCount": .int(snapshot.selectedWebDomainCount),
      "safariExtensionEnabled": .bool(snapshot.safariExtensionEnabled),
      "scheduleActive": .bool(snapshot.scheduleActive)
    ]
  }
}

private extension Bundle {
  var appVersion: String {
    let version = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    return "\(version) (\(build))"
  }
}
