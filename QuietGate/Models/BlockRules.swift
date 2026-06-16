import Foundation

enum BlockCategoryID: String, Codable, CaseIterable, Hashable, Identifiable {
  case adultContent

  var id: String { rawValue }

  var title: String {
    switch self {
    case .adultContent: return "Adult Content"
    }
  }

  var detail: String {
    switch self {
    case .adultContent:
      return "Blocks known adult domains, adult-host media, and high-confidence explicit pages."
    }
  }

  var domains: [String] {
    switch self {
    case .adultContent: return AdultContentPreset.domains
    }
  }
}

struct BlockCategoryRule: Codable, Equatable, Identifiable {
  let id: BlockCategoryID
  var isEnabled: Bool

  init(id: BlockCategoryID, isEnabled: Bool) {
    self.id = id
    self.isEnabled = isEnabled
  }
}

struct BlockedSiteRule: Codable, Equatable, Identifiable {
  var domain: String
  var isEnabled: Bool

  var id: String { domain }

  init(domain: String, isEnabled: Bool = true) {
    self.domain = domain
    self.isEnabled = isEnabled
  }
}

enum BlockApplicationTone: Equatable {
  case positive
  case warning
  case secondary
}

struct BlockApplicationStatus: Equatable {
  let text: String
  let tone: BlockApplicationTone
}

enum BlockingCapabilityState: Equatable {
  case checking
  case ready
  case disabled(String)
}

struct BlockingCapabilitySnapshot: Equatable {
  let state: BlockingCapabilityState
  let providerID: BlockingProviderID
  let providerTitle: String
  let providerDetail: String
  let checkedAt: Date?
  let browserHelperState: ChromeHelperState
  let lastTransaction: BlockingControlTransactionState
}

enum BlockingControlTransactionState: Equatable {
  case idle
  case checkingCapability
  case applying(String)
  case verified(String)
  case reverted(reason: String, nextAction: String?)

  var message: String? {
    switch self {
    case .idle, .checkingCapability:
      return nil
    case .applying(let message), .verified(let message):
      return message
    case .reverted(let reason, _):
      return reason
    }
  }

  var isWorking: Bool {
    switch self {
    case .checkingCapability, .applying:
      return true
    case .idle, .verified, .reverted:
      return false
    }
  }
}

extension Array where Element == BlockCategoryRule {
  func setting(_ id: BlockCategoryID, enabled: Bool) -> [BlockCategoryRule] {
    var rulesByID = Dictionary(uniqueKeysWithValues: map { ($0.id, $0) })
    rulesByID[id] = BlockCategoryRule(id: id, isEnabled: enabled)
    return BlockCategoryID.allCases.compactMap { rulesByID[$0] }
  }
}
