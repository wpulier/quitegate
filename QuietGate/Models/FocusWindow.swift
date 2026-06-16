import Foundation

struct FocusWindow: Identifiable, Codable, Equatable {
  let id: UUID
  var title: String
  var startMinute: Int
  var endMinute: Int
  var mode: AccessMode
  var isEnabled: Bool

  init(
    id: UUID = UUID(),
    title: String,
    startMinute: Int,
    endMinute: Int,
    mode: AccessMode,
    isEnabled: Bool = true
  ) {
    self.id = id
    self.title = title
    self.startMinute = Self.normalizedMinute(startMinute)
    self.endMinute = Self.normalizedMinute(endMinute)
    self.mode = mode == .open ? .focus : mode
    self.isEnabled = isEnabled
  }

  func contains(minute: Int) -> Bool {
    guard isEnabled, startMinute != endMinute else {
      return false
    }

    let minute = Self.normalizedMinute(minute)
    if startMinute < endMinute {
      return minute >= startMinute && minute < endMinute
    }
    return minute >= startMinute || minute < endMinute
  }

  var timeRangeTitle: String {
    "\(Self.timeText(startMinute))-\(Self.timeText(endMinute))"
  }

  static func normalizedMinute(_ value: Int) -> Int {
    min(1_439, max(0, value))
  }

  static func timeText(_ minute: Int) -> String {
    let minute = normalizedMinute(minute)
    let hour = minute / 60
    let minuteValue = minute % 60
    let period = hour < 12 ? "AM" : "PM"
    let displayHour = hour % 12 == 0 ? 12 : hour % 12
    return String(format: "%d:%02d %@", displayHour, minuteValue, period)
  }
}
