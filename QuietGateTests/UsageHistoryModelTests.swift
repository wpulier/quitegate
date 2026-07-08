import XCTest
@testable import QuietGate

/// Guards the on-device usage history that feeds the Usage hero: the trend
/// chip and 7-day bars must only ever claim what was actually recorded —
/// missing days stay empty, and a backend hiccup can never shrink a day.
final class UsageHistoryModelTests: XCTestCase {
  private func day(_ date: String, _ total: Int, web: Int = 0, ios: Int = 0) -> UsageDayRecord {
    UsageDayRecord(date: date, totalSeconds: total, webSeconds: web, iosSeconds: ios)
  }

  // MARK: record / upsert

  func testRecordAppendsNewDaySorted() {
    let history = [day("2026-07-06", 100)]
    let updated = UsageHistory.record(day("2026-07-07", 200), into: history)
    XCTAssertEqual(updated.map(\.date), ["2026-07-06", "2026-07-07"])
    XCTAssertEqual(updated.last?.totalSeconds, 200)
  }

  func testRecordSameDayLargerTotalWins() {
    let history = [day("2026-07-07", 100)]
    let updated = UsageHistory.record(day("2026-07-07", 260, web: 200, ios: 60), into: history)
    XCTAssertEqual(updated.count, 1)
    XCTAssertEqual(updated[0].totalSeconds, 260)
    XCTAssertEqual(updated[0].webSeconds, 200)
    XCTAssertEqual(updated[0].iosSeconds, 60)
  }

  func testRecordSameDaySmallerTotalNeverShrinksADay() {
    // Totals are monotonic within a day; a stale/partial backend response
    // must not erase already-recorded time.
    let history = [day("2026-07-07", 260, web: 200, ios: 60)]
    let updated = UsageHistory.record(day("2026-07-07", 40), into: history)
    XCTAssertEqual(updated[0].totalSeconds, 260)
    XCTAssertEqual(updated[0].webSeconds, 200)
  }

  func testRecordPrunesToNewestThirty() {
    let history = (1...30).map { day(String(format: "2026-06-%02d", $0), $0) }
    let updated = UsageHistory.record(day("2026-07-01", 500), into: history)
    XCTAssertEqual(updated.count, UsageHistory.maxRecords)
    XCTAssertEqual(updated.first?.date, "2026-06-02")
    XCTAssertEqual(updated.last?.date, "2026-07-01")
  }

  // MARK: trend deltas

  func testYesterdayDeltaNilWithoutYesterday() {
    let history = [day("2026-07-05", 100), day("2026-07-07", 200)]
    XCTAssertNil(UsageHistory.yesterdayDelta(history: history, today: "2026-07-07"))
  }

  func testYesterdayDeltaSigned() {
    let history = [day("2026-07-06", 3_000), day("2026-07-07", 1_560)]
    XCTAssertEqual(UsageHistory.yesterdayDelta(history: history, today: "2026-07-07"), -1_440)
    let up = [day("2026-07-06", 600), day("2026-07-07", 900)]
    XCTAssertEqual(UsageHistory.yesterdayDelta(history: up, today: "2026-07-07"), 300)
  }

  func testAverageDeltaUsesOnlyRecordedPriorDays() {
    // Prior recorded days: 600 and 1200 → mean 900. Today 600 → 300 under.
    let history = [
      day("2026-07-01", 600),
      day("2026-07-05", 1_200),
      day("2026-07-07", 600)
    ]
    XCTAssertEqual(UsageHistory.averageDelta(history: history, today: "2026-07-07"), -300)
  }

  func testAverageDeltaNilWithoutPriorDays() {
    let history = [day("2026-07-07", 600)]
    XCTAssertNil(UsageHistory.averageDelta(history: history, today: "2026-07-07"))
  }

  func testAverageDeltaCapsAtSevenMostRecentPriorDays() {
    // 8 prior days: the oldest (9_999) must be excluded from the mean.
    var history = (1...8).map { day(String(format: "2026-07-%02d", $0), $0 == 1 ? 9_999 : 700) }
    history.append(day("2026-07-09", 700))
    XCTAssertEqual(UsageHistory.averageDelta(history: history, today: "2026-07-09"), 0)
  }

  // MARK: seven-day bars

  func testSevenDayBarsEndTodayAndSpanMonthBoundary() {
    let history = [day("2026-06-28", 900), day("2026-07-02", 1_800)]
    let bars = UsageHistory.sevenDayBars(history: history, today: "2026-07-02")
    XCTAssertEqual(bars.count, 7)
    XCTAssertEqual(bars.first?.date, "2026-06-26")
    XCTAssertEqual(bars.last?.date, "2026-07-02")
    XCTAssertTrue(bars.last!.isToday)
    XCTAssertEqual(bars.filter(\.hasData).map(\.date), ["2026-06-28", "2026-07-02"])
    XCTAssertEqual(bars.first?.totalSeconds, 0)
    XCTAssertFalse(bars.first!.hasData)
  }

  func testSevenDayBarsWeekdayLetters() {
    // 2026-07-08 is a Wednesday.
    let bars = UsageHistory.sevenDayBars(history: [], today: "2026-07-08")
    XCTAssertEqual(bars.last?.weekdayLetter, "W")
    XCTAssertEqual(bars.first?.weekdayLetter, "T") // Thursday 2026-07-02
  }

  // MARK: context line

  func testContextLineFirstDay() {
    let line = UsageHistory.contextLine(yesterdayDelta: nil, averageDelta: nil)
    XCTAssertEqual(line, "Trends appear after a day of history.")
  }

  func testContextLineDownAndUnderAverage() {
    let line = UsageHistory.contextLine(yesterdayDelta: -1_440, averageDelta: -1_080)
    XCTAssertEqual(line, "Less than yesterday. 18m under your 7-day average.")
  }

  func testContextLineUpAndOverAverage() {
    let line = UsageHistory.contextLine(yesterdayDelta: 300, averageDelta: 4_500)
    XCTAssertEqual(line, "More than yesterday. 1h 15m over your 7-day average.")
  }

  func testContextLineSameAsYesterday() {
    let line = UsageHistory.contextLine(yesterdayDelta: 0, averageDelta: 0)
    XCTAssertEqual(line, "Same as yesterday. Right at your 7-day average.")
  }

  // MARK: web/iOS split

  func testWebIOSSplitClassifiesByDescriptor() {
    let split = UsageHistory.webIOSSplit(entries: [
      (descriptor: "browser Chrome · Personal alex@gmail.com", totalSeconds: 500),
      (descriptor: "ios iPhone Safari This iPhone", totalSeconds: 300),
      (descriptor: "Alex's iPad", totalSeconds: 100)
    ])
    XCTAssertEqual(split.web, 500)
    XCTAssertEqual(split.ios, 400)
  }

  // MARK: persistence round-trip

  func testHistoryCodableRoundTrip() throws {
    let history = [day("2026-07-07", 260, web: 200, ios: 60)]
    let data = try JSONEncoder().encode(history)
    let decoded = try JSONDecoder().decode([UsageDayRecord].self, from: data)
    XCTAssertEqual(decoded, history)
  }
}
