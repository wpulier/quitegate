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
          "setupStatus": "signed_in",
          "systemName": UIDevice.current.systemName,
          "systemVersion": UIDevice.current.systemVersion
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
            "setupStatus": "signed_in",
            "policyVersion": "\(policy.settingsVersion)"
          ],
          canaryStatus: [
            "accountHub": "ok"
          ],
          adultProtection: [
            "iosEnforcement": "not_enabled_v1"
          ]
        )
      )

      snapshot = AccountHubSnapshot(
        policy: policy,
        device: registeredDevice,
        devices: devices,
        lastSyncedAt: Date()
      )
      syncMessage = "This device is registered and policy is current."
    } catch {
      syncMessage = "Policy sync unavailable. Try again after account services are reachable."
    }
  }
}

private extension Bundle {
  var appVersion: String {
    let version = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    return "\(version) (\(build))"
  }
}
