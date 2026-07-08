import Foundation

/// One recorded local calendar day of usage. `date` uses the same
/// "yyyy-MM-dd" local-day key as the extension and `SiteUsageSummarySnapshot`,
/// so history lines up with what the rest of the pipeline calls "a day".
struct UsageDayRecord: Codable, Equatable {
  let date: String
  let totalSeconds: Int
  let webSeconds: Int
  let iosSeconds: Int
}

/// One bar of the Usage hero sparkline: a calendar day, oldest first,
/// today last. Missing days render as faint stubs — never invented data.
struct UsageHistoryBar: Equatable, Identifiable {
  let date: String
  let weekdayLetter: String
  let totalSeconds: Int
  let hasData: Bool
  let isToday: Bool

  var id: String { date }
}

/// Pure on-device usage history: the backend only ever serves a single day,
/// so the iPhone folds each fresh summary into a local ledger and derives the
/// trend chip, 7-day bars, and hero context line from what it actually saw.
/// Every function is date-string driven so it tests deterministically on macOS.
enum UsageHistory {
  static let maxRecords = 30

  /// Upserts one day. Same-day totals never shrink (they're monotonic within
  /// a day; a stale or partial response must not erase recorded time). Result
  /// is date-sorted ascending and pruned to the newest `maxRecords`.
  static func record(_ day: UsageDayRecord, into history: [UsageDayRecord]) -> [UsageDayRecord] {
    var byDate = Dictionary(uniqueKeysWithValues: history.map { ($0.date, $0) })
    let existingTotal = byDate[day.date]?.totalSeconds ?? -1
    if day.totalSeconds > existingTotal {
      byDate[day.date] = day
    }
    return Array(byDate.values.sorted { $0.date < $1.date }.suffix(maxRecords))
  }

  /// Today − yesterday, in seconds; nil when yesterday wasn't recorded.
  static func yesterdayDelta(history: [UsageDayRecord], today: String) -> Int? {
    guard let todayRecord = history.first(where: { $0.date == today }),
          let yesterdayKey = dayKey(byAdding: -1, to: today),
          let yesterdayRecord = history.first(where: { $0.date == yesterdayKey }) else {
      return nil
    }
    return todayRecord.totalSeconds - yesterdayRecord.totalSeconds
  }

  /// Today vs the mean of up to the 7 most recent recorded days before today;
  /// nil when nothing prior was recorded.
  static func averageDelta(history: [UsageDayRecord], today: String) -> Int? {
    guard let todayRecord = history.first(where: { $0.date == today }) else {
      return nil
    }
    let priors = history.filter { $0.date < today }.sorted { $0.date < $1.date }.suffix(7)
    guard !priors.isEmpty else {
      return nil
    }
    let mean = priors.reduce(0) { $0 + $1.totalSeconds } / priors.count
    return todayRecord.totalSeconds - mean
  }

  /// Seven bars ending on `today`, spanning month boundaries correctly.
  static func sevenDayBars(history: [UsageDayRecord], today: String) -> [UsageHistoryBar] {
    let byDate = Dictionary(uniqueKeysWithValues: history.map { ($0.date, $0) })
    return (-6...0).compactMap { offset in
      guard let key = dayKey(byAdding: offset, to: today) else {
        return nil
      }
      let record = byDate[key]
      return UsageHistoryBar(
        date: key,
        weekdayLetter: weekdayLetter(for: key),
        totalSeconds: record?.totalSeconds ?? 0,
        hasData: record != nil,
        isToday: offset == 0
      )
    }
  }

  /// The hero sentence under the big number. Honest at every stage of
  /// history: silent about trends it can't compute yet.
  static func contextLine(yesterdayDelta: Int?, averageDelta: Int?) -> String {
    guard yesterdayDelta != nil || averageDelta != nil else {
      return "Trends appear after a day of history."
    }

    var parts: [String] = []
    if let delta = yesterdayDelta {
      if delta < 0 {
        parts.append("Less than yesterday.")
      } else if delta > 0 {
        parts.append("More than yesterday.")
      } else {
        parts.append("Same as yesterday.")
      }
    }
    if let average = averageDelta {
      if average < 0 {
        parts.append("\(shortDuration(-average)) under your 7-day average.")
      } else if average > 0 {
        parts.append("\(shortDuration(average)) over your 7-day average.")
      } else {
        parts.append("Right at your 7-day average.")
      }
    }
    return parts.joined(separator: " ")
  }

  /// Splits entry seconds into web vs iOS by the same descriptor heuristic the
  /// Usage display uses (sourceType/browser/device/profile/label mashed into
  /// one string) so recording and rendering can never disagree.
  static func webIOSSplit(entries: [(descriptor: String, totalSeconds: Int)]) -> (web: Int, ios: Int) {
    var web = 0
    var ios = 0
    for entry in entries {
      if entry.descriptor.range(of: #"ios|iphone|ipad"#, options: [.regularExpression, .caseInsensitive]) != nil {
        ios += entry.totalSeconds
      } else {
        web += entry.totalSeconds
      }
    }
    return (web, ios)
  }

  /// "18m" / "1h 15m" — minutes granularity, matching the hero chip.
  static func shortDuration(_ seconds: Int) -> String {
    let totalMinutes = max(seconds, 0) / 60
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours > 0 {
      return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
    }
    return "\(minutes)m"
  }

  // MARK: - Day-key math

  private static func dayFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }

  private static func dayKey(byAdding days: Int, to key: String) -> String? {
    let formatter = dayFormatter()
    guard let date = formatter.date(from: key),
          let shifted = Calendar(identifier: .gregorian).date(byAdding: .day, value: days, to: date) else {
      return nil
    }
    return formatter.string(from: shifted)
  }

  private static func weekdayLetter(for key: String) -> String {
    let formatter = dayFormatter()
    guard let date = formatter.date(from: key) else {
      return ""
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
    let symbols = ["S", "M", "T", "W", "T", "F", "S"]
    return symbols[calendar.component(.weekday, from: date) - 1]
  }
}

/// App Group persistence for the ledger. `recordSummary` is the single choke
/// point every fresh `siteUsageSummary` flows through.
enum UsageHistoryStore {
  static let storageKey = "TortoiseUsageHistory"

  static func load(defaults: UserDefaults? = groupDefaults()) -> [UsageDayRecord] {
    guard let data = defaults?.data(forKey: storageKey),
          let history = try? JSONDecoder().decode([UsageDayRecord].self, from: data) else {
      return []
    }
    return history
  }

  static func save(_ history: [UsageDayRecord], defaults: UserDefaults? = groupDefaults()) {
    guard let data = try? JSONEncoder().encode(history) else {
      return
    }
    defaults?.set(data, forKey: storageKey)
  }

  @discardableResult
  static func recordSummary(
    date: String,
    totalSeconds: Int,
    webSeconds: Int,
    iosSeconds: Int,
    defaults: UserDefaults? = groupDefaults()
  ) -> [UsageDayRecord] {
    let updated = UsageHistory.record(
      UsageDayRecord(date: date, totalSeconds: totalSeconds, webSeconds: webSeconds, iosSeconds: iosSeconds),
      into: load(defaults: defaults)
    )
    save(updated, defaults: defaults)
    return updated
  }

  private static func groupDefaults() -> UserDefaults? {
    UserDefaults(suiteName: TortoiseAppGroup.identifier)
  }
}
