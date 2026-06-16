import Foundation

enum ExplicitHideStyle: String, CaseIterable, Codable, Equatable, Identifiable {
  case post
  case media
  case placeholder

  var id: String { rawValue }

  var title: String {
    switch self {
    case .post: return "Whole post"
    case .media: return "Media only"
    case .placeholder: return "Placeholder"
    }
  }
}

struct BrowserTuningOptions: Codable, Equatable {
  static let defaultYouTubeDailyLimitMinutes = 30
  static let youtubeDailyLimitRange = 5...480

  var explicitHideStyle: ExplicitHideStyle
  var youtubeDailyLimitMinutes: Int

  static let defaultValue = BrowserTuningOptions(
    explicitHideStyle: .post,
    youtubeDailyLimitMinutes: defaultYouTubeDailyLimitMinutes
  )

  private enum CodingKeys: String, CodingKey {
    case explicitHideStyle
    case youtubeDailyLimitMinutes
  }

  init(
    explicitHideStyle: ExplicitHideStyle,
    youtubeDailyLimitMinutes: Int = Self.defaultYouTubeDailyLimitMinutes
  ) {
    self.explicitHideStyle = explicitHideStyle
    self.youtubeDailyLimitMinutes = Self.clampedYouTubeDailyLimitMinutes(youtubeDailyLimitMinutes)
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    explicitHideStyle = try container.decodeIfPresent(ExplicitHideStyle.self, forKey: .explicitHideStyle)
      ?? .post
    youtubeDailyLimitMinutes = Self.clampedYouTubeDailyLimitMinutes(
      try container.decodeIfPresent(Int.self, forKey: .youtubeDailyLimitMinutes)
        ?? Self.defaultYouTubeDailyLimitMinutes
    )
  }

  static func clampedYouTubeDailyLimitMinutes(_ value: Int) -> Int {
    min(max(value, youtubeDailyLimitRange.lowerBound), youtubeDailyLimitRange.upperBound)
  }
}

struct BrowserTuningSettings: Codable, Equatable {
  let mode: AccessMode
  let features: [String: Bool]
  let blockedDomains: [String]
  let blockedCategories: [String]
  let options: BrowserTuningOptions
  let settingsVersion: String
  let updatedAt: Date

  private enum CodingKeys: String, CodingKey {
    case mode
    case features
    case blockedDomains
    case blockedCategories
    case options
    case settingsVersion
    case updatedAt
  }

  init(
    mode: AccessMode,
    features: [String: Bool],
    blockedDomains: [String] = [],
    blockedCategories: [String] = [],
    options: BrowserTuningOptions = .defaultValue,
    settingsVersion: String? = nil,
    updatedAt: Date = Date()
  ) {
    self.mode = mode
    self.features = features
    self.blockedDomains = Self.normalizedDomains(blockedDomains)
    self.blockedCategories = Self.normalizedCategories(blockedCategories)
    self.options = options
    self.settingsVersion =
      settingsVersion
      ?? Self.settingsVersion(
        mode: mode,
        features: features,
        blockedDomains: Self.normalizedDomains(blockedDomains),
        blockedCategories: Self.normalizedCategories(blockedCategories),
        options: options
      )
    self.updatedAt = updatedAt
  }

  init(
    mode: AccessMode,
    blockedDomains: [String] = [],
    blockedCategories: [String] = [],
    options: BrowserTuningOptions = .defaultValue,
    settingsVersion: String? = nil,
    updatedAt: Date = Date()
  ) {
    self.init(
      mode: mode,
      features: Dictionary(
        uniqueKeysWithValues: BrowserTuningFeature.allCases.map { feature in
          (feature.rawValue, mode.tuningFeatures.contains(feature))
        }
      ),
      blockedDomains: blockedDomains,
      blockedCategories: blockedCategories,
      options: options,
      settingsVersion: settingsVersion,
      updatedAt: updatedAt
    )
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    mode = try container.decode(AccessMode.self, forKey: .mode)
    features = try container.decode([String: Bool].self, forKey: .features)
    blockedDomains = Self.normalizedDomains(
      try container.decodeIfPresent([String].self, forKey: .blockedDomains) ?? []
    )
    blockedCategories = Self.normalizedCategories(
      try container.decodeIfPresent([String].self, forKey: .blockedCategories) ?? []
    )
    options = try container.decodeIfPresent(BrowserTuningOptions.self, forKey: .options)
      ?? .defaultValue
    settingsVersion = try container.decode(String.self, forKey: .settingsVersion)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
  }

  static func settingsVersion(
    mode: AccessMode,
    features: [String: Bool],
    blockedDomains: [String],
    blockedCategories: [String] = [],
    options: BrowserTuningOptions = .defaultValue
  ) -> String {
    let featureToken = features
      .sorted { $0.key < $1.key }
      .map { "\($0.key)=\($0.value ? "1" : "0")" }
      .joined(separator: ",")
    let domainToken = normalizedDomains(blockedDomains).joined(separator: ",")
    let categoryToken = normalizedCategories(blockedCategories).joined(separator: ",")
    return
      "mode=\(mode.rawValue)|features=\(featureToken)|domains=\(domainToken)|categories=\(categoryToken)|options=explicitHideStyle=\(options.explicitHideStyle.rawValue),youtubeDailyLimitMinutes=\(options.youtubeDailyLimitMinutes)"
  }

  private static func normalizedDomains(_ domains: [String]) -> [String] {
    Array(
      Set(
        domains
          .map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
              .lowercased()
              .replacingOccurrences(of: #"^\*\."#, with: "", options: .regularExpression)
              .trimmingCharacters(in: CharacterSet(charactersIn: "."))
          }
          .filter { !$0.isEmpty }
      )
    )
    .sorted()
  }

  private static func normalizedCategories(_ categories: [String]) -> [String] {
    Array(
      Set(
        categories
          .map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
          }
          .filter { !$0.isEmpty }
      )
    )
    .sorted()
  }

  func withBlockedDomains(_ domains: [String]) -> BrowserTuningSettings {
    BrowserTuningSettings(
      mode: mode,
      features: features,
      blockedDomains: domains,
      blockedCategories: blockedCategories,
      options: options,
      updatedAt: updatedAt
    )
  }
}
