import Foundation

/// Combines today's site-usage summaries from local browser bridges and the
/// Tortoise cloud account into one honest picture. Summaries from any other
/// day are rejected so stale data can never masquerade as "Today".
enum SiteUsageSummaryMerge {
  static func localDateKey(_ date: Date = Date(), timeZone: TimeZone = .current) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  static func today(
    local: [SiteUsageSummarySnapshot],
    cloud: SiteUsageSummarySnapshot?,
    today: String
  ) -> SiteUsageSummarySnapshot? {
    let candidates = (local + [cloud].compactMap { $0 }).filter { $0.date == today }
    guard !candidates.isEmpty else {
      return nil
    }

    // Deduplicate per-source entries across candidates: the same Chrome
    // profile reports both to the local bridge and to the cloud, so keep
    // only the freshest copy of each (site, source) pair.
    var bestEntries: [String: SiteUsageSourceSnapshot] = [:]
    var siteTemplates: [String: SiteUsageSnapshot] = [:]
    for candidate in candidates {
      for site in candidate.sites {
        if let existing = siteTemplates[site.siteID] {
          if isNewer(site.lastUpdatedAt, than: existing.lastUpdatedAt) {
            siteTemplates[site.siteID] = site
          }
        } else {
          siteTemplates[site.siteID] = site
        }
        let entries = site.entries.isEmpty ? [fallbackEntry(for: site)] : site.entries
        for entry in entries {
          guard entry.date == nil || entry.date == today else {
            continue
          }
          let key = mergeKey(entry, siteID: site.siteID)
          if let existing = bestEntries[key] {
            if wins(entry, over: existing) {
              bestEntries[key] = entry
            }
          } else {
            bestEntries[key] = entry
          }
        }
      }
    }

    let mergedSites = siteTemplates.values.map { template -> SiteUsageSnapshot in
      let siteEntries = bestEntries
        .filter { $0.key.hasPrefix("\(template.siteID)|") }
        .map(\.value)
        .sorted { ($0.totalSeconds ?? 0) > ($1.totalSeconds ?? 0) }
      let totalSeconds = siteEntries.reduce(0) { $0 + ($1.totalSeconds ?? 0) }
      let activityCounts = siteEntries.compactMap(\.activityCount)
      return SiteUsageSnapshot(
        siteID: template.siteID,
        title: template.title,
        date: today,
        totalSeconds: totalSeconds,
        lifetimeSeconds: template.lifetimeSeconds,
        activityCount: activityCounts.isEmpty ? nil : activityCounts.reduce(0, +),
        lifetimeActivityCount: template.lifetimeActivityCount,
        activityLabel: template.activityLabel,
        videoCount: template.siteID == "youtube" && !activityCounts.isEmpty
          ? activityCounts.reduce(0, +)
          : template.videoCount,
        lifetimeVideoCount: template.lifetimeVideoCount,
        limitSeconds: template.limitSeconds,
        limitReached: template.limitReached,
        lastUpdatedAt: siteEntries.compactMap(\.lastUpdatedAt).max() ?? template.lastUpdatedAt,
        entries: siteEntries
      )
    }
    .sorted { $0.totalSeconds > $1.totalSeconds }

    let allEntries = mergedSites.flatMap(\.entries)
      .sorted { ($0.totalSeconds ?? 0) > ($1.totalSeconds ?? 0) }
    let activityCounts = mergedSites.compactMap(\.activityCount)
    return SiteUsageSummarySnapshot(
      date: today,
      totalSeconds: mergedSites.reduce(0) { $0 + $1.totalSeconds },
      lifetimeSeconds: candidates.map(\.lifetimeSeconds).max() ?? 0,
      activityCount: activityCounts.isEmpty ? nil : activityCounts.reduce(0, +),
      lifetimeActivityCount: candidates.compactMap(\.lifetimeActivityCount).max(),
      lastUpdatedAt: allEntries.compactMap(\.lastUpdatedAt).max()
        ?? candidates.compactMap(\.lastUpdatedAt).max(),
      sites: mergedSites,
      entries: allEntries
    )
  }

  private static func mergeKey(_ entry: SiteUsageSourceSnapshot, siteID: String) -> String {
    let source = entry.sourceID
      ?? [entry.browserID, entry.profileID].compactMap { $0 }.joined(separator: "/").nilIfEmpty
      ?? entry.label
      ?? entry.id
    return "\(siteID)|\(source)"
  }

  private static func fallbackEntry(for site: SiteUsageSnapshot) -> SiteUsageSourceSnapshot {
    SiteUsageSourceSnapshot(
      id: "summary-fallback:\(site.siteID)",
      siteID: site.siteID,
      siteTitle: site.title,
      sourceID: "summary-fallback:\(site.siteID)",
      sourceType: nil,
      browserID: nil,
      browserName: nil,
      profileID: nil,
      profileName: nil,
      label: nil,
      deviceName: nil,
      date: site.date,
      totalSeconds: site.totalSeconds,
      lifetimeSeconds: site.lifetimeSeconds,
      activityCount: site.activityCount,
      lifetimeActivityCount: site.lifetimeActivityCount,
      activityLabel: site.activityLabel,
      videoCount: site.videoCount,
      lifetimeVideoCount: site.lifetimeVideoCount,
      lastUpdatedAt: site.lastUpdatedAt,
      lastSeenAt: nil,
      siteUsage: nil
    )
  }

  private static func wins(
    _ candidate: SiteUsageSourceSnapshot,
    over existing: SiteUsageSourceSnapshot
  ) -> Bool {
    switch (candidate.lastUpdatedAt, existing.lastUpdatedAt) {
    case let (candidateDate?, existingDate?) where candidateDate != existingDate:
      return candidateDate > existingDate
    case (.some, nil):
      return true
    case (nil, .some):
      return false
    default:
      return (candidate.totalSeconds ?? 0) > (existing.totalSeconds ?? 0)
    }
  }

  private static func isNewer(_ candidate: Date?, than existing: Date?) -> Bool {
    (candidate ?? .distantPast) > (existing ?? .distantPast)
  }
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
