import Foundation

protocol WebsiteBlockingProviding {
  var activeBlockedDomains: [String] { get }
  var settings: BrowserTuningSettings { get }
  func providerSnapshot(
    destinationNames: [String],
    isDefault: Bool
  ) -> BlockingProviderSnapshot
}

struct BrowserBlockingProvider: Equatable, WebsiteBlockingProviding {
  let accessMode: AccessMode
  let blockCategories: [BlockCategoryRule]
  let blockedSites: [BlockedSiteRule]
  let tuningOverrides: [String: Bool]
  var tuningOptions: BrowserTuningOptions = .defaultValue

  var effectiveTuningFeatures: [BrowserTuningFeature] {
    BrowserTuningFeature.allCases.filter { tuningFeatureEnabled($0) }
  }

  var tunerEnabled: Bool {
    !effectiveTuningFeatures.isEmpty
  }

  var effectiveTuningFeatureMap: [String: Bool] {
    Dictionary(
      uniqueKeysWithValues: BrowserTuningFeature.allCases.map { feature in
        (feature.rawValue, tuningFeatureEnabled(feature))
      }
    )
  }

  var activeCategoryBlockedDomains: [String] {
    Self.activeCategoryBlockedDomains(for: blockCategories)
  }

  var activeBlockedDomains: [String] {
    Self.activeBlockedDomains(sites: blockedSites, categories: blockCategories)
  }

  var activeBlockedCategoryIDs: [String] {
    blockCategories
      .filter(\.isEnabled)
      .map { $0.id.rawValue }
      .sorted()
  }

  var settings: BrowserTuningSettings {
    BrowserTuningSettings(
      mode: accessMode,
      features: effectiveTuningFeatureMap,
      blockedDomains: activeBlockedDomains,
      blockedCategories: activeBlockedCategoryIDs,
      options: tuningOptions
    )
  }

  func tuningFeatureEnabled(_ feature: BrowserTuningFeature) -> Bool {
    tuningOverrides[feature.rawValue] ?? accessMode.tuningFeatures.contains(feature)
  }

  func providerSnapshot(
    destinationNames: [String],
    isDefault: Bool = true
  ) -> BlockingProviderSnapshot {
    let state: BlockingProviderState =
      destinationNames.isEmpty
      ? .actionNeeded(
        "Connect Chrome, Edge, Brave, Arc, or Firefox before using website blocks or site tuning."
      )
      : .ready(
        "Website blocks apply in connected browsers. New changes may take about a minute or a browser reload to catch up."
      )

    return BlockingProviderSnapshot(
      id: .browserHelpers,
      title: "Browsers",
      kind: .browser,
      state: state,
      activeRuleCount: activeBlockedDomains.count,
      destinationNames: destinationNames,
      isDefault: isDefault,
      isLegacy: false
    )
  }

  static func activeCategoryBlockedDomains(for categories: [BlockCategoryRule]) -> [String] {
    let domains =
      categories
      .filter(\.isEnabled)
      .flatMap { $0.id.domains }
    return Array(Set(domains)).sorted()
  }

  static func activeBlockedDomains(
    sites: [BlockedSiteRule],
    categories: [BlockCategoryRule]
  ) -> [String] {
    Array(activeBlockedDomainSet(sites: sites, categories: categories)).sorted()
  }

  static func activeBlockedDomainSet(
    sites: [BlockedSiteRule],
    categories: [BlockCategoryRule]
  ) -> Set<String> {
    let siteDomains =
      sites
      .filter(\.isEnabled)
      .map(\.domain)
    return Set(siteDomains + activeCategoryBlockedDomains(for: categories))
  }
}
