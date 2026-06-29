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

struct AccountHubSnapshot {
  var policy: PolicyEnvelope?
  var device: TortoiseDevice?
  var devices: [TortoiseDevice] = []
  var lastSyncedAt: Date?
}
