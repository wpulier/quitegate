import Foundation

/// One site row on the Tune screen (progressive disclosure: tap to expand into
/// its features). Sites come from the shared TuningCatalog, in catalog order.
struct TuneSite: Identifiable, Equatable {
  let id: String
  let title: String
  let brandAssetName: String
  let enabledCount: Int
  let totalCount: Int
}

/// One granular feature row inside an expanded site. `isEnforceable` reflects
/// whether the CURRENT surface can actually apply this feature (per the catalog).
struct TuneFeature: Identifiable, Equatable {
  let id: String
  let title: String
  let detail: String
  let isOn: Bool
  let isEnforceable: Bool
}

/// Maps the shared catalog + the cloud policy into the Tune screen's rows. Pure
/// and platform-agnostic; both the macOS and iOS Tune screens render from it.
enum TuneScreen {
  static func sites(policy: TortoisePolicy?, surface: TuningSurface) -> [TuneSite] {
    TuningCatalog.sites.map { site in
      let onCount = site.featureIDs.filter { policy?.browser?.features[$0] == true }.count
      return TuneSite(
        id: site.id,
        title: site.title,
        brandAssetName: site.brandAssetName,
        enabledCount: onCount,
        totalCount: site.featureIDs.count
      )
    }
  }

  static func features(forSiteID siteID: String, policy: TortoisePolicy?, surface: TuningSurface) -> [TuneFeature] {
    guard let site = TuningCatalog.sites.first(where: { $0.id == siteID }) else { return [] }
    return site.featureIDs.compactMap { id in
      guard let feature = BrowserTuningFeature(rawValue: id) else { return nil }
      let enforceable = TuningCatalog.features.first { $0.id == id }?.enforceableOn.contains(surface) ?? false
      return TuneFeature(
        id: id,
        title: feature.title,
        detail: feature.detail,
        isOn: policy?.browser?.features[id] == true,
        isEnforceable: enforceable
      )
    }
  }

  /// The per-feature map handed to the iOS Safari web extension: the real policy
  /// state for features Safari can enforce, and `false` for the ones it can't hook
  /// (so Safari never claims to apply them). Consumed by Task 4's writeSafariPolicy.
  static func iosSafariEnforcedFeatures(policy: TortoisePolicy?) -> [String: Bool] {
    Dictionary(uniqueKeysWithValues: TuningCatalog.allFeatureIDs.map { id in
      let enforceable = TuningCatalog.features.first { $0.id == id }?.enforceableOn.contains(.iosSafari) ?? false
      return (id, enforceable && (policy?.browser?.features[id] == true))
    })
  }
}
