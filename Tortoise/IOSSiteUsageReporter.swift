import Foundation
import UIKit

enum IOSSiteUsageReporter {
  private static let localUsageKey = "TortoiseSiteUsageBySite"

  static func pendingReport(deviceName: String = UIDevice.current.name) -> SiteUsageReport? {
    guard let rawUsage = UserDefaults.standard.dictionary(forKey: localUsageKey) as? [String: [String: Any]] else {
      return nil
    }

    let sites = rawUsage.compactMap { siteID, value -> SiteUsageReportSite? in
      guard let normalizedSiteID = normalizedSiteID(siteID),
            let date = value["date"] as? String else {
        return nil
      }

      let totalSeconds = intValue(value["totalSeconds"])
      let lifetimeSeconds = intValue(value["lifetimeSeconds"])
      guard totalSeconds > 0 || lifetimeSeconds > 0 else {
        return nil
      }

      return SiteUsageReportSite(
        siteID: normalizedSiteID,
        title: title(for: normalizedSiteID),
        date: date,
        totalSeconds: totalSeconds,
        lifetimeSeconds: lifetimeSeconds,
        activityCount: optionalIntValue(value["activityCount"]),
        lifetimeActivityCount: optionalIntValue(value["lifetimeActivityCount"]),
        activityLabel: value["activityLabel"] as? String,
        lastUpdatedAt: value["lastUpdatedAt"] as? String ?? ISO8601DateFormatter().string(from: Date())
      )
    }

    guard !sites.isEmpty else {
      return nil
    }

    return SiteUsageReport(
      schemaVersion: 1,
      sites: sites,
      source: SiteUsageReportSource(
        sourceID: "ios:\(InstallationStore.installationId())",
        sourceType: "ios",
        label: UIDevice.current.model,
        deviceName: deviceName,
        platformMetadata: [
          "systemName": .string(UIDevice.current.systemName),
          "systemVersion": .string(UIDevice.current.systemVersion)
        ]
      )
    )
  }

  private static func normalizedSiteID(_ value: String) -> String? {
    let siteID = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if siteID == "twitter" {
      return "x"
    }
    return ["youtube", "x", "instagram", "reddit"].contains(siteID) ? siteID : nil
  }

  private static func title(for siteID: String) -> String {
    switch siteID {
    case "youtube":
      return "YouTube"
    case "x":
      return "X"
    case "instagram":
      return "Instagram"
    case "reddit":
      return "Reddit"
    default:
      return siteID
    }
  }

  private static func intValue(_ value: Any?) -> Int {
    if let int = value as? Int {
      return max(int, 0)
    }
    if let number = value as? NSNumber {
      return max(Int(number.doubleValue.rounded(.down)), 0)
    }
    if let string = value as? String, let double = Double(string) {
      return max(Int(double.rounded(.down)), 0)
    }
    return 0
  }

  private static func optionalIntValue(_ value: Any?) -> Int? {
    let value = intValue(value)
    return value > 0 ? value : nil
  }
}
