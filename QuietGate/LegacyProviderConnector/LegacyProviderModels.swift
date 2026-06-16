import Foundation

struct APIEnvelope<T: Decodable>: Decodable {
  let data: T
  let meta: APIMeta?
}

struct APIMeta: Decodable, Equatable {
  let pagination: Pagination?
  let stream: Stream?
}

struct Pagination: Decodable, Equatable {
  let cursor: String?
}

struct Stream: Decodable, Equatable {
  let id: String?
}

struct LegacyProviderErrorEnvelope: Decodable {
  let errors: [LegacyProviderAPIErrorDetail]
}

struct LegacyProviderAPIErrorDetail: Decodable, Equatable {
  struct Source: Decodable, Equatable {
    let parameter: String?
    let pointer: String?
  }

  let code: String
  let detail: String
  let source: Source?
}

struct LegacyProviderRuleItem: Codable, Equatable, Identifiable {
  let id: String
  var active: Bool

  init(id: String, active: Bool = true) {
    self.id = id
    self.active = active
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    active = try container.decodeIfPresent(Bool.self, forKey: .active) ?? true
  }
}

struct ParentalControl: Codable, Equatable {
  var services: [LegacyProviderRuleItem]
  var categories: [LegacyProviderRuleItem]
  var safeSearch: Bool
  var youtubeRestrictedMode: Bool
  var blockBypass: Bool

  init(
    services: [LegacyProviderRuleItem] = [],
    categories: [LegacyProviderRuleItem] = [],
    safeSearch: Bool = false,
    youtubeRestrictedMode: Bool = false,
    blockBypass: Bool = false
  ) {
    self.services = services
    self.categories = categories
    self.safeSearch = safeSearch
    self.youtubeRestrictedMode = youtubeRestrictedMode
    self.blockBypass = blockBypass
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    services = try container.decodeIfPresent([LegacyProviderRuleItem].self, forKey: .services) ?? []
    categories = try container.decodeIfPresent([LegacyProviderRuleItem].self, forKey: .categories) ?? []
    safeSearch = try container.decodeIfPresent(Bool.self, forKey: .safeSearch) ?? false
    youtubeRestrictedMode = try container.decodeIfPresent(Bool.self, forKey: .youtubeRestrictedMode) ?? false
    blockBypass = try container.decodeIfPresent(Bool.self, forKey: .blockBypass) ?? false
  }

  var pornCategoryActive: Bool {
    categories.first { $0.id == "porn" }?.active == true
  }

  var isQuietGateEnabled: Bool {
    pornCategoryActive && safeSearch && youtubeRestrictedMode && blockBypass
  }

  var quietGateManagedRestrictionActive: Bool {
    pornCategoryActive || safeSearch || youtubeRestrictedMode || blockBypass
  }

  func applyingQuietGateEnabled() -> ParentalControl {
    var copy = self
    copy.safeSearch = true
    copy.youtubeRestrictedMode = true
    copy.blockBypass = true
    copy.setCategory("porn", active: true)
    return copy
  }

  func applyingQuietGateDisabled() -> ParentalControl {
    var copy = self
    copy.safeSearch = false
    copy.youtubeRestrictedMode = false
    copy.blockBypass = false
    copy.setCategory("porn", active: false)
    return copy
  }

  private mutating func setCategory(_ id: String, active: Bool) {
    if let index = categories.firstIndex(where: { $0.id == id }) {
      categories[index].active = active
    } else {
      categories.append(LegacyProviderRuleItem(id: id, active: active))
    }
  }
}

struct LegacyProviderRuleRequest: Encodable {
  let id: String
  let active: Bool
}

struct LegacyProviderAnalyticsStatus: Decodable, Equatable, Identifiable {
  let status: String
  let queries: Int

  var id: String { status }
}

struct LegacyProviderReason: Decodable, Equatable, Identifiable {
  let id: String
  let name: String?
}

struct LegacyProviderDevice: Decodable, Equatable {
  let id: String?
  let name: String?
  let model: String?
}

struct LegacyProviderLogEntry: Decodable, Equatable, Identifiable {
  private let eventID: String?
  let timestamp: Date
  let domain: String
  let root: String?
  let protocolName: String?
  let client: String?
  let status: String
  let reasons: [LegacyProviderReason]
  let device: LegacyProviderDevice?

  var id: String {
    eventID ?? "\(timestamp.timeIntervalSince1970)-\(domain)-\(status)"
  }

  enum CodingKeys: String, CodingKey {
    case eventID = "id"
    case timestamp
    case domain
    case root
    case protocolName = "protocol"
    case client
    case status
    case reasons
    case device
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
    timestamp = try container.decode(Date.self, forKey: .timestamp)
    domain = try container.decode(String.self, forKey: .domain)
    root = try container.decodeIfPresent(String.self, forKey: .root)
    protocolName = try container.decodeIfPresent(String.self, forKey: .protocolName)
    client = try container.decodeIfPresent(String.self, forKey: .client)
    status = try container.decodeIfPresent(String.self, forKey: .status) ?? "default"
    reasons = try container.decodeIfPresent([LegacyProviderReason].self, forKey: .reasons) ?? []
    device = try container.decodeIfPresent(LegacyProviderDevice.self, forKey: .device)
  }
}

struct LegacyProviderResolverStatus: Decodable, Equatable {
  let status: String
  let profile: String?
  let client: String?
  let clientName: String?
  let protocolName: String?

  enum CodingKeys: String, CodingKey {
    case status
    case profile
    case client
    case clientName
    case protocolName = "protocol"
  }
}
