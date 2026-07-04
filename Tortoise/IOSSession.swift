import Foundation

/// A device-local focus/lock session. `mode` is `.focus` or `.strict` (never
/// `.open`); the session applies that mode until `endsAt`. A `locked` session
/// cannot be ended, weakened, or mode-switched before it expires — precommitment.
struct IOSSessionState: Codable, Equatable {
  var mode: IOSEnforcementMode
  var endsAt: Date
  var locked: Bool
}

/// Pure decision logic for iOS sessions (mirrors Mac's timedSession* rules).
/// Time-injectable so it is fully testable on macOS.
enum IOSSession {
  static func isActive(_ session: IOSSessionState?, now: Date) -> Bool {
    guard let session, session.mode != .open else { return false }
    return session.endsAt > now
  }

  static func isLockedActive(_ session: IOSSessionState?, now: Date) -> Bool {
    guard let session, session.locked else { return false }
    return isActive(session, now: now)
  }

  /// True once a started session's window has elapsed (so the app should revert).
  static func hasExpired(_ session: IOSSessionState?, now: Date) -> Bool {
    guard let session else { return false }
    return session.endsAt <= now
  }

  /// The user may end early only when there is no locked-active session.
  static func canEndEarly(_ session: IOSSessionState?, now: Date) -> Bool {
    !isLockedActive(session, now: now)
  }

  /// The mode may be changed only when there is no locked-active session.
  static func canChangeMode(_ session: IOSSessionState?, now: Date) -> Bool {
    !isLockedActive(session, now: now)
  }

  static func remaining(_ session: IOSSessionState?, now: Date) -> TimeInterval {
    guard let session else { return 0 }
    return max(0, session.endsAt.timeIntervalSince(now))
  }
}
