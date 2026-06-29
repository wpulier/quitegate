import Foundation

struct SiteUsageEnvelope: Decodable {
  let siteUsageSummary: SiteUsageSummarySnapshot
}

struct SiteUsageSummarySnapshot: Codable, Equatable {
  let schemaVersion: Int?
  let date: String
  let totalSeconds: Int
  let lifetimeSeconds: Int
  let activityCount: Int?
  let lifetimeActivityCount: Int?
  let lastUpdatedAt: String?
  let sites: [SiteUsageSnapshot]
  let entries: [SiteUsageSourceSnapshot]?
}

struct SiteUsageSnapshot: Codable, Equatable, Identifiable {
  var id: String { siteID }

  let siteID: String
  let title: String?
  let date: String
  let totalSeconds: Int
  let lifetimeSeconds: Int
  let activityCount: Int?
  let lifetimeActivityCount: Int?
  let activityLabel: String?
  let videoCount: Int?
  let lifetimeVideoCount: Int?
  let limitSeconds: Int?
  let limitReached: Bool?
  let lastUpdatedAt: String?
  let entries: [SiteUsageSourceSnapshot]

  var displayTitle: String {
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
      return title ?? siteID
    }
  }
}

struct SiteUsageSourceSnapshot: Codable, Equatable, Identifiable {
  let id: String
  let siteID: String?
  let siteTitle: String?
  let sourceID: String?
  let sourceType: String?
  let browserID: String?
  let browserName: String?
  let profileID: String?
  let profileName: String?
  let label: String?
  let deviceName: String?
  let date: String?
  let totalSeconds: Int?
  let lifetimeSeconds: Int?
  let activityCount: Int?
  let lifetimeActivityCount: Int?
  let activityLabel: String?
  let videoCount: Int?
  let lifetimeVideoCount: Int?
  let lastUpdatedAt: String?
  let lastSeenAt: String?
  let siteUsage: SiteUsageValueSnapshot?
}

struct SiteUsageValueSnapshot: Codable, Equatable {
  let siteID: String?
  let title: String?
  let date: String
  let totalSeconds: Int
  let lifetimeSeconds: Int
  let activityCount: Int?
  let lifetimeActivityCount: Int?
  let activityLabel: String?
  let videoCount: Int?
  let lifetimeVideoCount: Int?
  let limitSeconds: Int?
  let limitReached: Bool?
  let lastUpdatedAt: String?
}

struct SiteUsageReport: Encodable {
  let schemaVersion: Int
  let sites: [SiteUsageReportSite]
  let source: SiteUsageReportSource
}

struct SiteUsageReportSite: Encodable {
  let siteID: String
  let title: String?
  let date: String
  let totalSeconds: Int
  let lifetimeSeconds: Int
  let activityCount: Int?
  let lifetimeActivityCount: Int?
  let activityLabel: String?
  let lastUpdatedAt: String?
}

struct SiteUsageReportSource: Encodable {
  let sourceID: String
  let sourceType: String
  let label: String
  let deviceName: String
  let platformMetadata: [String: JSONValue]
}
