import XCTest
@testable import QuietGate

final class SiteUsageMergeTests: XCTestCase {
  private let today = "2026-07-07"
  private let yesterday = "2026-07-06"

  func testReturnsNilWhenNoCandidates() {
    XCTAssertNil(SiteUsageSummaryMerge.today(local: [], cloud: nil, today: today))
  }

  func testRejectsSummariesFromOtherDays() {
    let stale = summary(date: yesterday, sites: [
      site(id: "youtube", seconds: 3600, entries: [entry(site: "youtube", source: "chrome-a", seconds: 3600)])
    ])

    XCTAssertNil(SiteUsageSummaryMerge.today(local: [stale], cloud: stale, today: today))
  }

  func testPassesThroughSingleTodaySummary() throws {
    let local = summary(date: today, sites: [
      site(id: "youtube", seconds: 120, entries: [entry(site: "youtube", source: "chrome-a", seconds: 120)])
    ])

    let merged = try XCTUnwrap(SiteUsageSummaryMerge.today(local: [local], cloud: nil, today: today))
    XCTAssertEqual(merged.date, today)
    XCTAssertEqual(merged.totalSeconds, 120)
    XCTAssertEqual(merged.sites.map(\.siteID), ["youtube"])
  }

  func testDeduplicatesSameSourceAcrossLocalAndCloudKeepingFreshest() throws {
    let older = Date(timeIntervalSince1970: 1_000)
    let newer = Date(timeIntervalSince1970: 2_000)
    let cloud = summary(date: today, sites: [
      site(id: "youtube", seconds: 300, entries: [
        entry(site: "youtube", source: "chrome-a", seconds: 300, updatedAt: older)
      ])
    ])
    let local = summary(date: today, sites: [
      site(id: "youtube", seconds: 420, entries: [
        entry(site: "youtube", source: "chrome-a", seconds: 420, updatedAt: newer)
      ])
    ])

    let merged = try XCTUnwrap(SiteUsageSummaryMerge.today(local: [local], cloud: cloud, today: today))
    XCTAssertEqual(merged.totalSeconds, 420, "same source must not double-count; freshest entry wins")
    XCTAssertEqual(merged.sites.first?.entries.count, 1)
  }

  func testKeepsCloudOnlyIOSEntriesAlongsideLocalWebEntries() throws {
    let local = summary(date: today, sites: [
      site(id: "youtube", seconds: 600, entries: [
        entry(site: "youtube", source: "chrome-a", seconds: 600)
      ])
    ])
    let cloud = summary(date: today, sites: [
      site(id: "youtube", seconds: 900, entries: [
        entry(site: "youtube", source: "chrome-a", seconds: 540),
        entry(site: "youtube", source: "ios-device", seconds: 360, sourceType: "ios")
      ])
    ])

    let merged = try XCTUnwrap(SiteUsageSummaryMerge.today(local: [local], cloud: cloud, today: today))
    let youtube = try XCTUnwrap(merged.sites.first { $0.siteID == "youtube" })
    XCTAssertEqual(youtube.entries.count, 2, "iOS entry from cloud must survive the merge")
    XCTAssertEqual(youtube.totalSeconds, 960, "600 local chrome (fresher via larger total fallback) + 360 iOS")
  }

  func testMergesDistinctSitesFromDifferentCandidates() throws {
    let local = summary(date: today, sites: [
      site(id: "youtube", seconds: 100, entries: [entry(site: "youtube", source: "chrome-a", seconds: 100)])
    ])
    let cloud = summary(date: today, sites: [
      site(id: "reddit", seconds: 50, entries: [entry(site: "reddit", source: "chrome-a", seconds: 50)])
    ])

    let merged = try XCTUnwrap(SiteUsageSummaryMerge.today(local: [local], cloud: cloud, today: today))
    XCTAssertEqual(Set(merged.sites.map(\.siteID)), ["youtube", "reddit"])
    XCTAssertEqual(merged.totalSeconds, 150)
  }

  func testSitesOrderedByTotalSecondsDescending() throws {
    let local = summary(date: today, sites: [
      site(id: "reddit", seconds: 50, entries: [entry(site: "reddit", source: "a", seconds: 50)]),
      site(id: "youtube", seconds: 500, entries: [entry(site: "youtube", source: "a", seconds: 500)])
    ])

    let merged = try XCTUnwrap(SiteUsageSummaryMerge.today(local: [local], cloud: nil, today: today))
    XCTAssertEqual(merged.sites.map(\.siteID), ["youtube", "reddit"])
  }

  func testStaleLocalIsIgnoredWhileTodayCloudSurvives() throws {
    let staleLocal = summary(date: yesterday, sites: [
      site(id: "youtube", seconds: 34_380, entries: [entry(site: "youtube", source: "chrome-a", seconds: 34_380)])
    ])
    let cloud = summary(date: today, sites: [
      site(id: "youtube", seconds: 60, entries: [entry(site: "youtube", source: "chrome-a", seconds: 60)])
    ])

    let merged = try XCTUnwrap(SiteUsageSummaryMerge.today(local: [staleLocal], cloud: cloud, today: today))
    XCTAssertEqual(merged.totalSeconds, 60)
  }

  func testLocalDateKeyMatchesExtensionFormat() {
    let key = SiteUsageSummaryMerge.localDateKey(Date(timeIntervalSince1970: 0), timeZone: TimeZone(identifier: "UTC")!)
    XCTAssertEqual(key, "1970-01-01")
  }

  // MARK: - Fixtures

  private func summary(date: String, sites: [SiteUsageSnapshot]) -> SiteUsageSummarySnapshot {
    SiteUsageSummarySnapshot(
      date: date,
      totalSeconds: sites.reduce(0) { $0 + $1.totalSeconds },
      lifetimeSeconds: 0,
      activityCount: nil,
      lifetimeActivityCount: nil,
      lastUpdatedAt: sites.compactMap(\.lastUpdatedAt).max(),
      sites: sites,
      entries: sites.flatMap(\.entries)
    )
  }

  private func site(
    id: String,
    seconds: Int,
    entries: [SiteUsageSourceSnapshot]
  ) -> SiteUsageSnapshot {
    SiteUsageSnapshot(
      siteID: id,
      title: nil,
      date: today,
      totalSeconds: seconds,
      lifetimeSeconds: 0,
      activityCount: nil,
      lifetimeActivityCount: nil,
      activityLabel: nil,
      videoCount: nil,
      lifetimeVideoCount: nil,
      limitSeconds: nil,
      limitReached: nil,
      lastUpdatedAt: entries.compactMap(\.lastUpdatedAt).max(),
      entries: entries
    )
  }

  private func entry(
    site: String,
    source: String,
    seconds: Int,
    updatedAt: Date? = nil,
    sourceType: String? = "browser"
  ) -> SiteUsageSourceSnapshot {
    SiteUsageSourceSnapshot(
      id: "\(site):\(source)",
      siteID: site,
      siteTitle: nil,
      sourceID: source,
      sourceType: sourceType,
      browserID: nil,
      browserName: sourceType == "ios" ? "iOS" : "Chrome",
      profileID: nil,
      profileName: nil,
      label: nil,
      deviceName: nil,
      date: nil,
      totalSeconds: seconds,
      lifetimeSeconds: nil,
      activityCount: nil,
      lifetimeActivityCount: nil,
      activityLabel: nil,
      videoCount: nil,
      lifetimeVideoCount: nil,
      lastUpdatedAt: updatedAt,
      lastSeenAt: nil,
      siteUsage: nil
    )
  }
}
