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

struct TortoisePolicy: Decodable {
  let mode: String
  let adultBlockingEnabled: Bool
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

struct DeviceRegistration: Encodable {
  let installationId: String
  let platform: String
  let name: String
  let appVersion: String?
  let platformMetadata: [String: String]
}

struct DeviceHealth: Encodable {
  let appVersion: String?
  let platformMetadata: [String: String]
  let canaryStatus: [String: String]
  let adultProtection: [String: String]
}

struct AccountHubSnapshot {
  var policy: PolicyEnvelope?
  var device: TortoiseDevice?
  var devices: [TortoiseDevice] = []
  var lastSyncedAt: Date?
}
