import Darwin
import Foundation

let allowedChromiumExtensionID = "fedpnejbgmllajjlfkahlnjbgfmjjmmf"
let allowedFirefoxExtensionID = "quietgate@willpulier.com"
let allowedOrigin = "chrome-extension://\(allowedChromiumExtensionID)/"
let allowedBrowserIDs: Set<String> = ["chrome", "edge", "brave", "arc", "firefox"]
let supportedSiteIDs: [String] = ["youtube", "x", "instagram", "reddit"]
let supportedSiteIDSet = Set(supportedSiteIDs)

let defaultSettings: [String: Any] = [
  "mode": "open",
  "features": [
    "youtubeHome": false,
    "youtubeVideoSidebar": false,
    "youtubeShorts": false,
    "youtubeComments": false,
    "youtubeRecommendations": false,
    "youtubeSearch": false,
    "youtubeEndScreens": false,
    "youtubeEndScreenCards": false,
    "youtubeLiveChat": false,
    "youtubeAutoplay": false,
    "youtubePlaylists": false,
    "youtubeFundraisers": false,
    "youtubeMixes": false,
    "youtubeMerch": false,
    "youtubeVideoInfo": false,
    "youtubeTopHeader": false,
    "youtubeNotifications": false,
    "youtubeExplore": false,
    "youtubeMoreFromYouTube": false,
    "youtubeSubscriptions": false,
    "youtubeAnnotations": false,
    "youtubeUsageTracking": false,
    "youtubeDailyLimit": false,
    "xSensitiveMedia": false,
    "xExplicitContent": false,
    "xExplicitSearch": false,
    "xVideos": false,
    "xPhotos": false,
    "xMediaCards": false,
    "xExploreTrends": false,
    "instagramReels": false,
    "instagramExplore": false,
    "instagramSuggested": false,
    "instagramStories": false,
    "redditPopularAll": false,
    "redditRecommendations": false,
    "redditNSFW": false,
    "redditMedia": false,
    "redditSidebars": false
  ],
  "blockedDomains": [],
  "blockedCategories": [],
  "options": [
    "explicitHideStyle": "post",
    "youtubeDailyLimitMinutes": 30
  ],
  "settingsVersion": "mode=open|features=|domains=|categories=|options=explicitHideStyle=post,youtubeDailyLimitMinutes=30",
  "updatedAt": "1970-01-01T00:00:00Z"
]

func applicationSupportDirectory() -> URL {
  FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library", isDirectory: true)
    .appendingPathComponent("Application Support", isDirectory: true)
    .appendingPathComponent("QuietGate", isDirectory: true)
}

func settingsURL() -> URL {
  applicationSupportDirectory().appendingPathComponent("extension-settings.json")
}

func chromeStatusURL() -> URL {
  applicationSupportDirectory().appendingPathComponent("chrome-status.json")
}

func statusURL(browserID: String?) -> URL {
  let normalized = normalizedBrowserID(browserID) ?? "chrome"
  let filename = normalized == "chrome" ? "chrome-status.json" : "\(normalized)-status.json"
  return applicationSupportDirectory().appendingPathComponent(filename)
}

func youtubeUsageLedgerURL() -> URL {
  applicationSupportDirectory().appendingPathComponent("youtube-usage-summary.json")
}

func siteUsageLedgerURL() -> URL {
  applicationSupportDirectory().appendingPathComponent("site-usage-summary.json")
}

func localDateKey(_ date: Date = Date()) -> String {
  let formatter = DateFormatter()
  formatter.calendar = Calendar(identifier: .gregorian)
  formatter.locale = Locale(identifier: "en_US_POSIX")
  formatter.dateFormat = "yyyy-MM-dd"
  return formatter.string(from: date)
}

func browserDisplayName(_ browserID: String) -> String {
  switch browserID {
  case "chrome":
    return "Chrome"
  case "edge":
    return "Edge"
  case "brave":
    return "Brave"
  case "arc":
    return "Arc"
  case "firefox":
    return "Firefox"
  default:
    return "Browser"
  }
}

func trimmedString(_ value: Any?) -> String? {
  guard let string = value as? String else {
    return nil
  }
  let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
  return trimmed.isEmpty ? nil : trimmed
}

func intValue(_ value: Any?) -> Int {
  if let int = value as? Int {
    return max(int, 0)
  }
  if let number = value as? NSNumber {
    return max(Int(number.doubleValue.rounded(.down)), 0)
  }
  if let string = value as? String,
     let double = Double(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
    return max(Int(double.rounded(.down)), 0)
  }
  return 0
}

func positiveIntValue(_ value: Any?) -> Int? {
  let value = intValue(value)
  return value > 0 ? value : nil
}

func boolValue(_ value: Any?) -> Bool {
  if let bool = value as? Bool {
    return bool
  }
  if let number = value as? NSNumber {
    return number.boolValue
  }
  if let string = value as? String {
    return ["1", "true", "yes"].contains(string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
  }
  return false
}

func normalizedYouTubeUsage(_ value: Any?) -> [String: Any]? {
  guard let usage = value as? [String: Any],
        let date = trimmedString(usage["date"]) else {
    return nil
  }
  let totalSeconds = intValue(usage["totalSeconds"])
  let limitSeconds = positiveIntValue(usage["limitSeconds"])
  var normalized: [String: Any] = [
    "date": date,
    "totalSeconds": totalSeconds,
    "lifetimeSeconds": intValue(usage["lifetimeSeconds"]),
    "videoCount": intValue(usage["videoCount"]),
    "lifetimeVideoCount": intValue(usage["lifetimeVideoCount"]),
    "limitReached": boolValue(usage["limitReached"]) || (limitSeconds.map { totalSeconds >= $0 } ?? false)
  ]
  normalized["limitSeconds"] = limitSeconds ?? NSNull()
  normalized["lastUpdatedAt"] = trimmedString(usage["lastUpdatedAt"]) ?? NSNull()
  return normalized
}

func normalizedSiteID(_ value: Any?) -> String? {
  guard var siteID = trimmedString(value)?.lowercased() else {
    return nil
  }
  if siteID == "twitter" {
    siteID = "x"
  }
  return supportedSiteIDSet.contains(siteID) ? siteID : nil
}

func siteTitle(_ siteID: String) -> String {
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

func defaultActivityLabel(siteID: String) -> String? {
  siteID == "youtube" ? "videos" : nil
}

func normalizedSiteUsage(_ value: Any?, fallbackSiteID: String? = nil) -> [String: Any]? {
  guard let usage = value as? [String: Any] else {
    return nil
  }
  guard let siteID = normalizedSiteID(usage["siteID"]) ?? fallbackSiteID else {
    return nil
  }
  guard let date = trimmedString(usage["date"]) else {
    return nil
  }

  let totalSeconds = intValue(usage["totalSeconds"])
  let lifetimeSeconds = intValue(usage["lifetimeSeconds"])
  let activityCount = intValue(usage["activityCount"] ?? usage["videoCount"])
  let lifetimeActivityCount = intValue(usage["lifetimeActivityCount"] ?? usage["lifetimeVideoCount"])
  let limitSeconds = positiveIntValue(usage["limitSeconds"])
  let activityLabel = trimmedString(usage["activityLabel"])
    ?? (activityCount > 0 || lifetimeActivityCount > 0 ? defaultActivityLabel(siteID: siteID) : nil)

  var normalized: [String: Any] = [
    "siteID": siteID,
    "title": siteTitle(siteID),
    "date": date,
    "totalSeconds": totalSeconds,
    "lifetimeSeconds": lifetimeSeconds,
    "activityCount": activityCount,
    "lifetimeActivityCount": lifetimeActivityCount,
    "limitReached": boolValue(usage["limitReached"]) || (limitSeconds.map { totalSeconds >= $0 } ?? false)
  ]
  normalized["activityLabel"] = activityLabel ?? NSNull()
  normalized["limitSeconds"] = limitSeconds ?? NSNull()
  normalized["lastUpdatedAt"] = trimmedString(usage["lastUpdatedAt"]) ?? NSNull()

  if siteID == "youtube" {
    normalized["videoCount"] = activityCount
    normalized["lifetimeVideoCount"] = lifetimeActivityCount
  }

  return normalized
}

func siteUsageFromYouTubeUsage(_ value: Any?) -> [String: Any]? {
  guard let usage = normalizedYouTubeUsage(value) else {
    return nil
  }
  var siteUsage: [String: Any] = [
    "siteID": "youtube",
    "title": "YouTube",
    "date": trimmedString(usage["date"]) ?? localDateKey(),
    "totalSeconds": intValue(usage["totalSeconds"]),
    "lifetimeSeconds": intValue(usage["lifetimeSeconds"]),
    "activityCount": intValue(usage["videoCount"]),
    "lifetimeActivityCount": intValue(usage["lifetimeVideoCount"]),
    "activityLabel": "videos",
    "videoCount": intValue(usage["videoCount"]),
    "lifetimeVideoCount": intValue(usage["lifetimeVideoCount"]),
    "limitReached": boolValue(usage["limitReached"])
  ]
  siteUsage["limitSeconds"] = positiveIntValue(usage["limitSeconds"]) ?? NSNull()
  siteUsage["lastUpdatedAt"] = trimmedString(usage["lastUpdatedAt"]) ?? NSNull()
  return siteUsage
}

func normalizedSiteUsagePayload(_ value: Any?) -> [[String: Any]] {
  if let entries = value as? [[String: Any]] {
    return entries.compactMap { normalizedSiteUsage($0) }
  }
  guard let object = value as? [String: Any] else {
    return []
  }
  if let entries = object["sites"] as? [[String: Any]] {
    return entries.compactMap { normalizedSiteUsage($0) }
  }
  if let entries = object["entries"] as? [[String: Any]] {
    return entries.compactMap { normalizedSiteUsage($0) }
  }
  if let siteID = normalizedSiteID(object["siteID"]) {
    return normalizedSiteUsage(object, fallbackSiteID: siteID).map { [$0] } ?? []
  }
  return supportedSiteIDs.compactMap { siteID in
    normalizedSiteUsage(object[siteID], fallbackSiteID: siteID)
  }
}

func readYouTubeUsageRecords() -> [[String: Any]] {
  guard let data = try? Data(contentsOf: youtubeUsageLedgerURL()),
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let records = object["records"] as? [[String: Any]] else {
    return []
  }
  return records
}

func readSiteUsageRecords() -> [[String: Any]] {
  guard let data = try? Data(contentsOf: siteUsageLedgerURL()),
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let records = object["records"] as? [[String: Any]] else {
    return []
  }
  return records
}

func profileLabel(browserID: String, profile: [String: Any]?) -> String {
  let browser = browserDisplayName(browserID)
  guard let profile else {
    return browser
  }
  let label = trimmedString(profile["label"])
    ?? trimmedString(profile["name"])
    ?? trimmedString(profile["id"])
  guard let label else {
    return browser
  }
  return "\(browser) - \(label)"
}

func youtubeUsageRecord(from message: [String: Any], browserID: String, profile: [String: Any]?, seenAt: String) -> [String: Any]? {
  guard let usage = normalizedYouTubeUsage(message["youtubeUsage"]) else {
    return nil
  }
  let profileID = trimmedString(profile?["id"]) ?? "default"
  var record: [String: Any] = [
    "id": "\(browserID):\(profileID)",
    "browserID": browserID,
    "browserName": browserDisplayName(browserID),
    "profileID": profileID,
    "label": profileLabel(browserID: browserID, profile: profile),
    "youtubeUsage": usage,
    "lastSeenAt": seenAt
  ]
  record["profileName"] = trimmedString(profile?["name"]) ?? NSNull()
  return record
}

func sourceType(browserID: String, value: Any? = nil) -> String {
  if let explicit = trimmedString(value)?.lowercased(), ["browser", "web", "ios", "iphone", "ipad"].contains(explicit) {
    return explicit == "iphone" || explicit == "ipad" ? "ios" : explicit
  }
  return browserID == "ios" ? "ios" : "browser"
}

func siteUsageRecord(
  usage: [String: Any],
  message: [String: Any],
  browserID: String,
  profile: [String: Any]?,
  seenAt: String
) -> [String: Any]? {
  guard let siteID = normalizedSiteID(usage["siteID"]) else {
    return nil
  }
  let profileID = trimmedString(profile?["id"]) ?? "default"
  let source = sourceType(browserID: browserID, value: usage["sourceType"] ?? message["sourceType"])
  let sourceID = trimmedString(usage["sourceID"]) ?? "\(browserID):\(profileID)"
  var record: [String: Any] = [
    "id": "\(siteID):\(sourceID)",
    "siteID": siteID,
    "siteTitle": siteTitle(siteID),
    "sourceID": sourceID,
    "sourceType": source,
    "browserID": browserID,
    "browserName": browserDisplayName(browserID),
    "profileID": profileID,
    "label": trimmedString(usage["label"]) ?? profileLabel(browserID: browserID, profile: profile),
    "siteUsage": usage,
    "lastSeenAt": seenAt
  ]
  record["profileName"] = trimmedString(profile?["name"]) ?? NSNull()
  record["deviceName"] = trimmedString(usage["deviceName"]) ?? (source == "ios" ? "iOS" : browserDisplayName(browserID))
  return record
}

func siteUsageRecords(from message: [String: Any], browserID: String, profile: [String: Any]?, seenAt: String) -> [[String: Any]] {
  var usageValues = normalizedSiteUsagePayload(message["siteUsage"])
  let hasGenericYouTube = usageValues.contains { normalizedSiteID($0["siteID"]) == "youtube" }
  if !hasGenericYouTube, let youtubeUsage = siteUsageFromYouTubeUsage(message["youtubeUsage"]) {
    usageValues.append(youtubeUsage)
  }
  return usageValues.compactMap { usage in
    siteUsageRecord(
      usage: usage,
      message: message,
      browserID: browserID,
      profile: profile,
      seenAt: seenAt
    )
  }
}

func writeYouTubeUsageRecord(_ record: [String: Any], updatedAt: String) throws {
  guard let recordID = trimmedString(record["id"]) else {
    return
  }
  var records = readYouTubeUsageRecords().filter { trimmedString($0["id"]) != recordID }
  records.append(record)
  records.sort {
    let lhs = trimmedString($0["label"]) ?? trimmedString($0["id"]) ?? ""
    let rhs = trimmedString($1["label"]) ?? trimmedString($1["id"]) ?? ""
    return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
  }

  let data = try JSONSerialization.data(
    withJSONObject: [
      "schemaVersion": 1,
      "updatedAt": updatedAt,
      "records": records
    ],
    options: [.prettyPrinted, .sortedKeys]
  )
  try data.write(to: youtubeUsageLedgerURL(), options: .atomic)
}

func writeSiteUsageRecord(_ record: [String: Any], updatedAt: String) throws {
  guard let recordID = trimmedString(record["id"]) else {
    return
  }
  var records = readSiteUsageRecords().filter { trimmedString($0["id"]) != recordID }
  records.append(record)
  records.sort {
    let lhsSite = supportedSiteIDs.firstIndex(of: trimmedString($0["siteID"]) ?? "") ?? Int.max
    let rhsSite = supportedSiteIDs.firstIndex(of: trimmedString($1["siteID"]) ?? "") ?? Int.max
    if lhsSite != rhsSite {
      return lhsSite < rhsSite
    }
    let lhs = trimmedString($0["label"]) ?? trimmedString($0["id"]) ?? ""
    let rhs = trimmedString($1["label"]) ?? trimmedString($1["id"]) ?? ""
    return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
  }

  let data = try JSONSerialization.data(
    withJSONObject: [
      "schemaVersion": 1,
      "updatedAt": updatedAt,
      "records": records
    ],
    options: [.prettyPrinted, .sortedKeys]
  )
  try data.write(to: siteUsageLedgerURL(), options: .atomic)
}

func legacyYouTubeSiteUsageRecords() -> [[String: Any]] {
  readYouTubeUsageRecords().compactMap { record -> [String: Any]? in
    guard let usage = siteUsageFromYouTubeUsage(record["youtubeUsage"]) else {
      return nil
    }
    let browserID = trimmedString(record["browserID"]) ?? "chrome"
    let profileID = trimmedString(record["profileID"]) ?? "default"
    let sourceID = "\(browserID):\(profileID)"
    var mapped: [String: Any] = [
      "id": "youtube:\(sourceID)",
      "siteID": "youtube",
      "siteTitle": "YouTube",
      "sourceID": sourceID,
      "sourceType": "browser",
      "browserID": browserID,
      "browserName": trimmedString(record["browserName"]) ?? browserDisplayName(browserID),
      "profileID": profileID,
      "label": trimmedString(record["label"]) ?? "\(browserDisplayName(browserID)) - \(profileID)",
      "siteUsage": usage,
      "lastSeenAt": trimmedString(record["lastSeenAt"]) ?? NSNull()
    ]
    mapped["profileName"] = trimmedString(record["profileName"]) ?? NSNull()
    mapped["deviceName"] = trimmedString(record["deviceName"]) ?? browserDisplayName(browserID)
    return mapped
  }
}

func mergedSiteUsageRecords() -> [[String: Any]] {
  var recordsByID: [String: [String: Any]] = [:]
  for record in legacyYouTubeSiteUsageRecords() {
    if let id = trimmedString(record["id"]) {
      recordsByID[id] = record
    }
  }
  for record in readSiteUsageRecords() {
    if let id = trimmedString(record["id"]) {
      recordsByID[id] = record
    }
  }
  return Array(recordsByID.values)
}

func siteUsageEntry(from record: [String: Any]) -> [String: Any]? {
  guard let siteID = normalizedSiteID(record["siteID"]),
        let usage = normalizedSiteUsage(record["siteUsage"], fallbackSiteID: siteID) else {
    return nil
  }
  var entry: [String: Any] = [
    "id": trimmedString(record["id"]) ?? "",
    "siteID": siteID,
    "siteTitle": siteTitle(siteID),
    "sourceID": trimmedString(record["sourceID"]) ?? "",
    "sourceType": trimmedString(record["sourceType"]) ?? "browser",
    "browserID": trimmedString(record["browserID"]) ?? "",
    "browserName": trimmedString(record["browserName"]) ?? "",
    "profileID": trimmedString(record["profileID"]) ?? "",
    "label": trimmedString(record["label"]) ?? "",
    "date": trimmedString(usage["date"]) ?? "",
    "totalSeconds": intValue(usage["totalSeconds"]),
    "lifetimeSeconds": intValue(usage["lifetimeSeconds"]),
    "activityCount": intValue(usage["activityCount"]),
    "lifetimeActivityCount": intValue(usage["lifetimeActivityCount"]),
    "siteUsage": usage,
    "lastSeenAt": trimmedString(record["lastSeenAt"]) ?? NSNull()
  ]
  entry["profileName"] = trimmedString(record["profileName"]) ?? NSNull()
  entry["deviceName"] = trimmedString(record["deviceName"]) ?? NSNull()
  entry["activityLabel"] = trimmedString(usage["activityLabel"]) ?? NSNull()
  entry["limitSeconds"] = positiveIntValue(usage["limitSeconds"]) ?? NSNull()
  entry["limitReached"] = boolValue(usage["limitReached"])
  entry["lastUpdatedAt"] = trimmedString(usage["lastUpdatedAt"]) ?? trimmedString(record["lastSeenAt"]) ?? NSNull()
  if siteID == "youtube" {
    entry["videoCount"] = intValue(usage["videoCount"] ?? usage["activityCount"])
    entry["lifetimeVideoCount"] = intValue(usage["lifetimeVideoCount"] ?? usage["lifetimeActivityCount"])
  }
  return entry
}

func siteUsageSummary(for date: String = localDateKey()) -> [String: Any]? {
  let currentDayEntries = mergedSiteUsageRecords()
    .compactMap(siteUsageEntry)
    .filter { trimmedString($0["date"]) == date }
  guard !currentDayEntries.isEmpty else {
    return nil
  }

  let allEntries = mergedSiteUsageRecords().compactMap(siteUsageEntry)
  let sites = supportedSiteIDs.compactMap { siteID -> [String: Any]? in
    let entries = currentDayEntries
      .filter { normalizedSiteID($0["siteID"]) == siteID }
      .sorted { intValue($0["totalSeconds"]) > intValue($1["totalSeconds"]) }
    guard !entries.isEmpty else {
      return nil
    }
    let lifetimeEntries = allEntries.filter { normalizedSiteID($0["siteID"]) == siteID }
    let totalSeconds = entries.reduce(0) { $0 + intValue($1["totalSeconds"]) }
    let activityCount = entries.reduce(0) { $0 + intValue($1["activityCount"]) }
    let limitSeconds = entries.compactMap { positiveIntValue($0["limitSeconds"]) }.min()
    let lastUpdatedAt = entries
      .compactMap { trimmedString($0["lastUpdatedAt"]) ?? trimmedString($0["lastSeenAt"]) }
      .max()
    var site: [String: Any] = [
      "siteID": siteID,
      "title": siteTitle(siteID),
      "date": date,
      "totalSeconds": totalSeconds,
      "lifetimeSeconds": lifetimeEntries.reduce(0) { $0 + intValue($1["lifetimeSeconds"]) },
      "activityCount": activityCount,
      "lifetimeActivityCount": lifetimeEntries.reduce(0) { $0 + intValue($1["lifetimeActivityCount"]) },
      "limitReached": entries.contains { boolValue($0["limitReached"]) }
        || (limitSeconds.map { totalSeconds >= $0 } ?? false),
      "entries": entries
    ]
    let activityLabel = defaultActivityLabel(siteID: siteID)
      ?? entries.compactMap { trimmedString($0["activityLabel"]) }.first
    site["activityLabel"] = activityLabel ?? NSNull()
    site["limitSeconds"] = limitSeconds ?? NSNull()
    site["lastUpdatedAt"] = lastUpdatedAt ?? NSNull()
    if siteID == "youtube" {
      site["videoCount"] = activityCount
      site["lifetimeVideoCount"] = lifetimeEntries.reduce(0) { $0 + intValue($1["lifetimeVideoCount"]) }
    }
    return site
  }

  let totalSeconds = sites.reduce(0) { $0 + intValue($1["totalSeconds"]) }
  let lifetimeSeconds = sites.reduce(0) { $0 + intValue($1["lifetimeSeconds"]) }
  var summary: [String: Any] = [
    "schemaVersion": 1,
    "date": date,
    "totalSeconds": totalSeconds,
    "lifetimeSeconds": lifetimeSeconds,
    "activityCount": sites.reduce(0) { $0 + intValue($1["activityCount"]) },
    "lifetimeActivityCount": sites.reduce(0) { $0 + intValue($1["lifetimeActivityCount"]) },
    "sites": sites,
    "entries": currentDayEntries
  ]
  summary["lastUpdatedAt"] = sites.compactMap { trimmedString($0["lastUpdatedAt"]) }.max() ?? NSNull()
  return summary
}

func siteUsageSummaryValue() -> Any {
  siteUsageSummary() ?? NSNull()
}

func youtubeUsageSummary(for date: String = localDateKey()) -> [String: Any]? {
  let records = readYouTubeUsageRecords()
  let currentDayRecords = records.filter { record in
    guard let usage = record["youtubeUsage"] as? [String: Any] else {
      return false
    }
    return trimmedString(usage["date"]) == date
  }
  guard !currentDayRecords.isEmpty else {
    return nil
  }

  let allUsage = records.compactMap { $0["youtubeUsage"] as? [String: Any] }
  let datedUsage = currentDayRecords.compactMap { $0["youtubeUsage"] as? [String: Any] }
  let totalSeconds = datedUsage.reduce(0) { $0 + intValue($1["totalSeconds"]) }
  let videoCount = datedUsage.reduce(0) { $0 + intValue($1["videoCount"]) }
  let lifetimeSeconds = allUsage.reduce(0) { $0 + intValue($1["lifetimeSeconds"]) }
  let lifetimeVideoCount = allUsage.reduce(0) { $0 + intValue($1["lifetimeVideoCount"]) }
  let limitSeconds = datedUsage.compactMap { positiveIntValue($0["limitSeconds"]) }.min()
  let lastUpdatedAt = currentDayRecords
    .compactMap { record -> String? in
      guard let usage = record["youtubeUsage"] as? [String: Any] else {
        return trimmedString(record["lastSeenAt"])
      }
      return trimmedString(usage["lastUpdatedAt"]) ?? trimmedString(record["lastSeenAt"])
    }
    .max()

  let entries = currentDayRecords.map { record -> [String: Any] in
    var entry: [String: Any] = [
      "id": trimmedString(record["id"]) ?? "",
      "browserID": trimmedString(record["browserID"]) ?? "",
      "browserName": trimmedString(record["browserName"]) ?? "",
      "profileID": trimmedString(record["profileID"]) ?? "",
      "label": trimmedString(record["label"]) ?? "",
      "youtubeUsage": record["youtubeUsage"] as? [String: Any] ?? [:],
      "lastSeenAt": trimmedString(record["lastSeenAt"]) ?? NSNull()
    ]
    entry["profileName"] = trimmedString(record["profileName"]) ?? NSNull()
    return entry
  }

  var summary: [String: Any] = [
    "schemaVersion": 1,
    "date": date,
    "totalSeconds": totalSeconds,
    "lifetimeSeconds": lifetimeSeconds,
    "videoCount": videoCount,
    "lifetimeVideoCount": lifetimeVideoCount,
    "limitReached": datedUsage.contains { boolValue($0["limitReached"]) }
      || (limitSeconds.map { totalSeconds >= $0 } ?? false),
    "entries": entries
  ]
  summary["limitSeconds"] = limitSeconds ?? NSNull()
  summary["lastUpdatedAt"] = lastUpdatedAt ?? NSNull()
  return summary
}

func youtubeUsageSummaryValue() -> Any {
  youtubeUsageSummary() ?? NSNull()
}

func normalizedBrowserID(_ browserID: String?) -> String? {
  guard let browserID else {
    return nil
  }
  let value = browserID
    .trimmingCharacters(in: .whitespacesAndNewlines)
    .lowercased()
  return allowedBrowserIDs.contains(value) ? value : nil
}

func browserID(from message: [String: Any]) -> String {
  if let explicit = normalizedBrowserID(message["browserID"] as? String) {
    return explicit
  }
  return browserIDFromParentProcess() ?? "chrome"
}

func browserUserDataDirectory(browserID: String) -> URL? {
  let support = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library", isDirectory: true)
    .appendingPathComponent("Application Support", isDirectory: true)

  switch browserID {
  case "chrome":
    return support
      .appendingPathComponent("Google", isDirectory: true)
      .appendingPathComponent("Chrome", isDirectory: true)
  case "edge":
    return support.appendingPathComponent("Microsoft Edge", isDirectory: true)
  case "brave":
    return support
      .appendingPathComponent("BraveSoftware", isDirectory: true)
      .appendingPathComponent("Brave-Browser", isDirectory: true)
  case "arc":
    return support
      .appendingPathComponent("Arc", isDirectory: true)
      .appendingPathComponent("User Data", isDirectory: true)
  case "firefox":
    return support
      .appendingPathComponent("Firefox", isDirectory: true)
      .appendingPathComponent("Profiles", isDirectory: true)
  default:
    return nil
  }
}

func browserIDFromParentProcess() -> String? {
  guard let command = parentProcessCommand()?.lowercased(), !command.isEmpty else {
    return nil
  }

  let matches: [(needle: String, browserID: String)] = [
    ("google chrome", "chrome"),
    ("microsoft edge", "edge"),
    ("brave browser", "brave"),
    ("/arc.app/", "arc"),
    (" arc helper", "arc"),
    ("firefox.app/contents/macos/firefox", "firefox"),
    ("/firefox ", "firefox"),
  ]

  return matches.first { command.contains($0.needle) }?.browserID
}

func parentProcessCommand() -> String? {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/bin/ps")
  process.arguments = ["-p", String(getppid()), "-o", "command="]

  let pipe = Pipe()
  process.standardOutput = pipe
  process.standardError = Pipe()

  do {
    try process.run()
  } catch {
    return nil
  }

  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  process.waitUntilExit()

  guard process.terminationStatus == 0 else {
    return nil
  }
  return String(data: data, encoding: .utf8)?
    .trimmingCharacters(in: .whitespacesAndNewlines)
}

func selectedProfileID(browserID: String) -> String? {
  if browserID == "firefox" {
    return selectedFirefoxProfileID()
  }

  if let command = parentProcessCommand(),
     let profile = commandArgumentValue(named: "--profile-directory", in: command) {
    return profile
  }

  guard let userDataDirectory = browserUserDataDirectory(browserID: browserID) else {
    return nil
  }
  let localStateURL = userDataDirectory.appendingPathComponent("Local State")
  guard let data = try? Data(contentsOf: localStateURL),
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let profile = object["profile"] as? [String: Any],
        let lastUsed = profile["last_used"] as? String else {
    return nil
  }
  let trimmed = lastUsed.trimmingCharacters(in: .whitespacesAndNewlines)
  return trimmed.isEmpty ? nil : trimmed
}

func selectedFirefoxProfileID() -> String? {
  if let command = parentProcessCommand(),
     let profilePath = commandArgumentValue(named: "-profile", in: command)
      ?? commandArgumentValue(named: "--profile", in: command) {
    return URL(fileURLWithPath: profilePath).lastPathComponent
  }

  let sections = firefoxProfilesIniSections()
  if let defaultSection = sections.first(where: { $0["Default"] == "1" }),
     let path = defaultSection["Path"] {
    return URL(fileURLWithPath: path).lastPathComponent
  }
  if sections.count == 1, let path = sections[0]["Path"] {
    return URL(fileURLWithPath: path).lastPathComponent
  }
  return nil
}

func profileDisplayName(browserID: String, profileID: String) -> String? {
  if browserID == "firefox" {
    return firefoxProfileDisplayName(profileID: profileID)
  }
  return chromiumProfileDisplayName(browserID: browserID, profileID: profileID)
}

func chromiumProfileDisplayName(browserID: String, profileID: String) -> String? {
  guard let userDataDirectory = browserUserDataDirectory(browserID: browserID) else {
    return nil
  }

  let localStateURL = userDataDirectory.appendingPathComponent("Local State")
  if let data = try? Data(contentsOf: localStateURL),
     let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
     let profile = object["profile"] as? [String: Any],
     let infoCache = profile["info_cache"] as? [String: Any],
     let entry = infoCache[profileID] as? [String: Any],
     let displayName = firstProfileDisplayName(in: entry) {
    return displayName
  }

  let preferencesURL = userDataDirectory
    .appendingPathComponent(profileID, isDirectory: true)
    .appendingPathComponent("Preferences")
  guard let data = try? Data(contentsOf: preferencesURL),
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let profile = object["profile"] as? [String: Any] else {
    return nil
  }
  return firstProfileDisplayName(in: profile)
}

func firstProfileDisplayName(in object: [String: Any]) -> String? {
  let accountName = trimmedProfileValue(for: "user_name", in: object)
  for key in ["name", "local_profile_name", "gaia_name", "shortcut_name"] {
    guard let value = object[key] as? String else {
      continue
    }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty {
      if let accountName,
         accountName.contains("@"),
         accountName.caseInsensitiveCompare(trimmed) != .orderedSame {
        return "\(trimmed), \(accountName)"
      }
      return trimmed
    }
  }
  return accountName
}

func trimmedProfileValue(for key: String, in object: [String: Any]) -> String? {
  guard let value = object[key] as? String else {
    return nil
  }
  let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
  return trimmed.isEmpty ? nil : trimmed
}

func firefoxProfileDisplayName(profileID: String) -> String? {
  firefoxProfilesIniSections().first { section in
    guard let path = section["Path"] else {
      return false
    }
    return URL(fileURLWithPath: path).lastPathComponent == profileID
  }?["Name"]?.trimmingCharacters(in: .whitespacesAndNewlines)
}

func firefoxProfilesIniSections() -> [[String: String]] {
  guard let profilesDirectory = browserUserDataDirectory(browserID: "firefox") else {
    return []
  }
  let profilesIniURL = profilesDirectory
    .deletingLastPathComponent()
    .appendingPathComponent("profiles.ini")
  guard let contents = try? String(contentsOf: profilesIniURL, encoding: .utf8) else {
    return []
  }

  var sections: [[String: String]] = []
  var section: [String: String] = [:]

  func flushSection() {
    if !section.isEmpty {
      sections.append(section)
    }
  }

  for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
    let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
    if line.hasPrefix("[") && line.hasSuffix("]") {
      flushSection()
      section = [:]
      continue
    }
    guard let separator = line.firstIndex(of: "=") else {
      continue
    }
    let key = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
    let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
    section[String(key)] = String(value)
  }
  flushSection()

  return sections
}

func browserProfilePayload(browserID: String) -> [String: Any]? {
  guard let profileID = selectedProfileID(browserID: browserID) else {
    return nil
  }
  let profileName = profileDisplayName(browserID: browserID, profileID: profileID)
  let trimmedName = profileName?.trimmingCharacters(in: .whitespacesAndNewlines)
  let label: String
  if let trimmedName,
     !trimmedName.isEmpty,
     trimmedName.caseInsensitiveCompare(profileID) != .orderedSame {
    label = "\(trimmedName) (\(profileID))"
  } else {
    label = profileID
  }

  var payload: [String: Any] = [
    "id": profileID,
    "label": label
  ]
  if let trimmedName, !trimmedName.isEmpty {
    payload["name"] = trimmedName
  }
  return payload
}

func commandArgumentValue(named name: String, in command: String) -> String? {
  if let range = command.range(of: "\(name)=") {
    let tail = command[range.upperBound...]
    let value = tailValue(from: tail)
    return value.isEmpty ? nil : value
  }

  guard let range = command.range(of: "\(name) ") else {
    return nil
  }

  let tail = command[range.upperBound...]
  let value = tailValue(from: tail)
  return value.isEmpty ? nil : value
}

func tailValue(from tail: Substring) -> String {
  let value: Substring
  if let nextFlag = tail.range(of: " --") ?? tail.range(of: " -") {
    value = tail[..<nextFlag.lowerBound]
  } else {
    value = tail
  }

  return value
    .trimmingCharacters(in: .whitespacesAndNewlines)
    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
}

func callerOrigin() -> String? {
  CommandLine.arguments.dropFirst().first
}

func callerIsAllowed() -> Bool {
  let arguments = CommandLine.arguments.dropFirst()
  return arguments.contains(allowedOrigin) ||
    arguments.contains(allowedFirefoxExtensionID)
}

func expectedExtensionID(for browserID: String) -> String {
  browserID == "firefox" ? allowedFirefoxExtensionID : allowedChromiumExtensionID
}

func readMessage() throws -> [String: Any]? {
  let input = FileHandle.standardInput
  let header = input.readData(ofLength: 4)
  guard !header.isEmpty else { return nil }
  guard header.count == 4 else {
    throw NativeHostError.incompleteHeader
  }

  let length = header.withUnsafeBytes { pointer in
    pointer.load(as: UInt32.self).littleEndian
  }
  let body = input.readData(ofLength: Int(length))
  guard body.count == Int(length) else {
    throw NativeHostError.incompleteBody
  }

  return try JSONSerialization.jsonObject(with: body) as? [String: Any]
}

func normalizeDomain(_ value: String?) -> String? {
  guard var domain = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
        !domain.isEmpty else {
    return nil
  }
  if domain.hasPrefix("http://") || domain.hasPrefix("https://") {
    guard let url = URL(string: domain), let host = url.host else {
      return nil
    }
    domain = host
  }
  if domain.hasPrefix("*.") {
    domain.removeFirst(2)
  }
  while domain.hasSuffix(".") {
    domain.removeLast()
  }
  if domain.hasPrefix("www.") {
    domain.removeFirst(4)
  }
  guard domain.contains("."),
        !domain.contains("/"),
        !domain.contains(" "),
        domain.range(of: #"^[a-z0-9][a-z0-9.-]*[a-z0-9]$"#, options: .regularExpression) != nil else {
    return nil
  }
  return domain
}

func clampedYouTubeDailyLimitMinutes(_ value: Any?) -> Int {
  let minutes: Int
  if let int = value as? Int {
    minutes = int
  } else if let number = value as? NSNumber {
    minutes = number.intValue
  } else {
    minutes = 30
  }
  return min(max(minutes, 5), 480)
}

func normalizedStringArray(_ value: Any?) -> [String] {
  let array = value as? [Any] ?? []
  return Array(
    Set(
      array.compactMap { item -> String? in
        guard let string = item as? String else {
          return nil
        }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
      }
    )
  ).sorted()
}

func normalizedSettings(_ value: [String: Any]) -> [String: Any] {
  var settings = defaultSettings.merging(value) { _, new in new }
  let defaultFeatures = defaultSettings["features"] as? [String: Any] ?? [:]
  let savedFeatures = value["features"] as? [String: Any] ?? [:]
  settings["features"] = defaultFeatures.merging(savedFeatures) { _, new in new }

  let defaultOptions = defaultSettings["options"] as? [String: Any] ?? [:]
  let savedOptions = value["options"] as? [String: Any] ?? [:]
  var options = defaultOptions.merging(savedOptions) { _, new in new }
  options["youtubeDailyLimitMinutes"] = clampedYouTubeDailyLimitMinutes(
    options["youtubeDailyLimitMinutes"]
  )
  settings["options"] = options
  settings["blockedDomains"] = normalizedStringArray(settings["blockedDomains"])
  settings["blockedCategories"] = normalizedStringArray(settings["blockedCategories"])
  settings["settingsVersion"] = settingsVersion(for: settings)
  return settings
}

func readSettings() -> [String: Any] {
  guard let data = try? Data(contentsOf: settingsURL()),
        let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    return normalizedSettings(defaultSettings)
  }
  return normalizedSettings(value)
}

func settingsVersion(for settings: [String: Any]) -> String {
  let mode = settings["mode"] as? String ?? "open"
  let features = settings["features"] as? [String: Any] ?? [:]
  let featureToken = features.keys.sorted().map { key in
    let enabled: Bool
    if let bool = features[key] as? Bool {
      enabled = bool
    } else if let number = features[key] as? NSNumber {
      enabled = number.boolValue
    } else {
      enabled = false
    }
    return "\(key)=\(enabled ? "1" : "0")"
  }.joined(separator: ",")
  let domains = normalizedStringArray(settings["blockedDomains"]).joined(separator: ",")
  let categories = normalizedStringArray(settings["blockedCategories"]).joined(separator: ",")
  let options = settings["options"] as? [String: Any] ?? [:]
  let explicitHideStyle = options["explicitHideStyle"] as? String ?? "post"
  let youtubeDailyLimitMinutes = clampedYouTubeDailyLimitMinutes(
    options["youtubeDailyLimitMinutes"]
  )
  return "mode=\(mode)|features=\(featureToken)|domains=\(domains)|categories=\(categories)|options=explicitHideStyle=\(explicitHideStyle),youtubeDailyLimitMinutes=\(youtubeDailyLimitMinutes)"
}

func reportMissedAdultSite(from message: [String: Any]) throws -> [String: Any] {
  let requestedDomain = normalizeDomain(message["domain"] as? String)
    ?? normalizeDomain(message["url"] as? String)
  guard let domain = requestedDomain else {
    return ["ok": false, "error": "QuietGate could not read a valid domain from this page."]
  }

  var settings = readSettings()
  var blockedDomains = normalizedStringArray(settings["blockedDomains"])
  if !blockedDomains.contains(domain) {
    blockedDomains.append(domain)
    blockedDomains.sort()
  }
  settings["blockedDomains"] = blockedDomains
  settings["updatedAt"] = ISO8601DateFormatter().string(from: Date())
  settings["settingsVersion"] = settingsVersion(for: settings)

  try FileManager.default.createDirectory(
    at: applicationSupportDirectory(),
    withIntermediateDirectories: true
  )
  let settingsData = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
  try settingsData.write(to: settingsURL(), options: .atomic)

  let reportURL = applicationSupportDirectory().appendingPathComponent("missed-adult-sites.json")
  let existingReports: [[String: Any]]
  if let data = try? Data(contentsOf: reportURL),
     let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
    existingReports = parsed
  } else {
    existingReports = []
  }
  let report: [String: Any] = [
    "domain": domain,
    "url": message["url"] as? String ?? "",
    "title": message["title"] as? String ?? "",
    "reportedAt": ISO8601DateFormatter().string(from: Date())
  ]
  let reportData = try JSONSerialization.data(
    withJSONObject: existingReports + [report],
    options: [.prettyPrinted, .sortedKeys]
  )
  try reportData.write(to: reportURL, options: .atomic)

  return [
    "ok": true,
    "domain": domain,
    "settings": settings
  ]
}

func writeBrowserStatus(from message: [String: Any]) throws {
  guard let settingsVersion = message["settingsVersion"] as? String,
        !settingsVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
    throw NativeHostError.missingSettingsVersion
  }

  try FileManager.default.createDirectory(
    at: applicationSupportDirectory(),
    withIntermediateDirectories: true
  )

  let browser = browserID(from: message)
  let extensionID = message["extensionID"] as? String ?? expectedExtensionID(for: browser)
  let profile = browserProfilePayload(browserID: browser)
  let seenAt = ISO8601DateFormatter().string(from: Date())
  let scriptVersions = (message["scriptVersions"] as? [String: Any] ?? [:])
    .compactMapValues { value -> String? in
      guard let string = value as? String else {
        return nil
      }
      let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? nil : trimmed
    }
  var status: [String: Any] = [
    "schemaVersion": 1,
    "browserID": browser,
    "extensionID": extensionID,
    "lastSeenAt": seenAt,
    "lastAppliedSettingsVersion": settingsVersion,
    "extensionVersion": message["extensionVersion"] as? String ?? "",
    "scriptVersions": scriptVersions,
    "blockedRuleCount": message["blockedRuleCount"] as? Int ?? 0,
    "lastError": message["lastError"] as? String ?? NSNull()
  ]
  if let platformControls = message["platformControls"] as? [String: Any] {
    status["platformControls"] = platformControls
  } else {
    status["platformControls"] = NSNull()
  }
  if let adultProtection = message["adultProtection"] as? [String: Any] {
    status["adultProtection"] = adultProtection
  } else {
    status["adultProtection"] = NSNull()
  }
  if let tunerHealth = message["tunerHealth"] as? [String: Any] {
    status["tunerHealth"] = tunerHealth
  } else {
    status["tunerHealth"] = NSNull()
  }
  if let youtubeUsage = message["youtubeUsage"] as? [String: Any] {
    status["youtubeUsage"] = youtubeUsage
  } else {
    status["youtubeUsage"] = NSNull()
  }
  if let siteUsage = message["siteUsage"] {
    status["siteUsage"] = siteUsage
  } else {
    status["siteUsage"] = NSNull()
  }
  if let usageRecord = youtubeUsageRecord(from: message, browserID: browser, profile: profile, seenAt: seenAt) {
    try writeYouTubeUsageRecord(usageRecord, updatedAt: seenAt)
  }
  for usageRecord in siteUsageRecords(from: message, browserID: browser, profile: profile, seenAt: seenAt) {
    try writeSiteUsageRecord(usageRecord, updatedAt: seenAt)
  }
  status["siteUsageSummary"] = siteUsageSummaryValue()
  status["youtubeUsageSummary"] = youtubeUsageSummaryValue()
  if let profileID = profile?["id"] as? String {
    status["profileID"] = profileID
  } else {
    status["profileID"] = NSNull()
  }
  if let profileName = profile?["name"] as? String {
    status["profileName"] = profileName
  } else {
    status["profileName"] = NSNull()
  }

  let data = try JSONSerialization.data(withJSONObject: status, options: [.prettyPrinted, .sortedKeys])
  try data.write(to: statusURL(browserID: browser), options: .atomic)
}

func writeMessage(_ value: [String: Any]) throws {
  let body = try JSONSerialization.data(withJSONObject: value)
  var length = UInt32(body.count).littleEndian
  let header = Data(bytes: &length, count: 4)
  FileHandle.standardOutput.write(header)
  FileHandle.standardOutput.write(body)
}

enum NativeHostError: LocalizedError {
  case incompleteHeader
  case incompleteBody
  case unauthorizedOrigin(String?)
  case missingSettingsVersion

  var errorDescription: String? {
    switch self {
    case .incompleteHeader:
      return "Incomplete native messaging header."
    case .incompleteBody:
      return "Incomplete native messaging body."
    case .unauthorizedOrigin(let origin):
      return "QuietGate browser helper is not authorized for \(origin ?? "this caller")."
    case .missingSettingsVersion:
      return "QuietGate browser helper did not report a settings version."
    }
  }
}

do {
  guard callerIsAllowed() else {
    throw NativeHostError.unauthorizedOrigin(callerOrigin())
  }

  guard let message = try readMessage(),
        let type = message["type"] as? String else {
    try writeMessage(["ok": false, "error": "Unsupported request."])
    exit(0)
  }

  switch type {
  case "getSettings":
    let browser = browserID(from: message)
    let profile: Any = browserProfilePayload(browserID: browser) ?? NSNull()
    try writeMessage([
      "ok": true,
      "settings": readSettings(),
      "browserID": browser,
      "profile": profile,
      "siteUsageSummary": siteUsageSummaryValue(),
      "youtubeUsageSummary": youtubeUsageSummaryValue()
    ])
  case "recordAppliedSettings":
    try writeBrowserStatus(from: message)
    let browser = browserID(from: message)
    let profile: Any = browserProfilePayload(browserID: browser) ?? NSNull()
    try writeMessage([
      "ok": true,
      "browserID": browser,
      "profile": profile,
      "siteUsageSummary": siteUsageSummaryValue(),
      "youtubeUsageSummary": youtubeUsageSummaryValue()
    ])
  case "reportMissedAdultSite":
    try writeMessage(reportMissedAdultSite(from: message))
  default:
    try writeMessage(["ok": false, "error": "Unsupported request."])
  }
} catch {
  try? writeMessage([
    "ok": false,
    "error": error.localizedDescription
  ])
}
