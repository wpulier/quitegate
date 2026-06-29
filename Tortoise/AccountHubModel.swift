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

      try? await apiClient.postHealth(
        token: token,
        deviceId: registeredDevice.id,
        health: DeviceHealth(
          appVersion: Bundle.main.appVersion,
          platformMetadata: [
            "setupStatus": .string("signed_in"),
            "policyVersion": .string("\(policy.settingsVersion)"),
            "capabilities": .object(Self.iosCapabilities)
          ],
          canaryStatus: [
            "accountHub": .string("live"),
            "policySync": .string("live")
          ],
          adultProtection: [
            "iosEnforcement": .string("not_supported_v1"),
            "sourceOfTruth": .string("supabase_policy")
          ]
        )
      )

      snapshot = AccountHubSnapshot(
        policy: policy,
        device: registeredDevice,
        devices: devices,
        lastSyncedAt: Date()
      )
      syncMessage = "This iPhone is registered and policy is current. iOS enforcement is not available in v1."
    } catch {
      syncMessage = "Policy sync unavailable. Try again after account services are reachable."
    }
  }

  private static let iosCapabilities: [String: JSONValue] = [
    "accountHub": .string("supported"),
    "policySync": .string("supported"),
    "deviceHealth": .string("supported"),
    "adultWebBlocking": .string("planned"),
    "xTuning": .string("not_supported_v1"),
    "redditTuning": .string("not_supported_v1"),
    "youtubeTuning": .string("not_supported_v1"),
    "instagramBlocking": .string("not_supported_v1"),
    "macAppBlocking": .string("not_supported")
  ]
}

private extension Bundle {
  var appVersion: String {
    let version = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    return "\(version) (\(build))"
  }
}
