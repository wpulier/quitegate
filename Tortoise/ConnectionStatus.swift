import Foundation

/// A surface that can enforce tuning. Used to describe where a feature actually applies.
enum TuningSurface: String, CaseIterable, Codable {
  case chromeExtension
  case firefoxExtension
  case iosSafari
  case iosScreenTime
}

/// The single, canonical connection state for any device or browser profile.
/// Replaces the scattered per-subsystem status enums (introduced here; the old
/// enums are removed in Phase 5).
enum ConnectionStatus: Equatable {
  case on
  case attention(AttentionReason)
  case off
}

/// The one concrete step left when a connection needs attention.
enum AttentionReason: Equatable {
  case setupIncomplete  // never checked in / connect not finished
  case stale            // checked in before, but not within the freshness window
  case catchingUp       // reachable, but not yet applying the latest policy
}

enum ConnectionFreshness {
  /// The single freshness window used everywhere. A device not seen within this
  /// window is never shown as "On".
  static let freshWindow: TimeInterval = 15 * 60
}

extension ConnectionStatus {
  /// The one place a connection's state is decided. Pure and time-injectable.
  static func resolve(
    lastSeenAt: Date?,
    isEnforcingLatestPolicy: Bool,
    isPausedByUser: Bool,
    now: Date
  ) -> ConnectionStatus {
    if isPausedByUser {
      return .off
    }
    guard let lastSeenAt else {
      return .attention(.setupIncomplete)
    }
    if now.timeIntervalSince(lastSeenAt) > ConnectionFreshness.freshWindow {
      return .attention(.stale)
    }
    if !isEnforcingLatestPolicy {
      return .attention(.catchingUp)
    }
    return .on
  }
}
