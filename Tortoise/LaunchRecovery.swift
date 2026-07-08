import Foundation

/// Crash-loop backstop for iOS Screen Time self-shielding.
///
/// If a shield ever catches Tortoise itself (tokens are opaque, so this is
/// undetectable at apply time), iOS kills the app moments after every
/// foreground with no crash log — which means no migration that runs inside a
/// launch can be trusted to finish, and none that runs once can be trusted to
/// have worked. The one honest signal is the loop itself: the process
/// repeatedly dying young while enforcement is active. The controller records
/// a pending launch at init, marks it survived on reaching background or
/// after a grace period, and asks here whether the streak of early deaths
/// warrants wiping all enforcement state (safe mode).
enum LaunchRecovery {
  /// Consecutive early deaths (while enforcing) that trigger safe mode.
  static let safeModeThreshold = 2

  struct Assessment: Equatable {
    /// The updated consecutive-early-death count to persist.
    let earlyDeathCount: Int
    /// True when this launch should wipe all enforcement state.
    let shouldEnterSafeMode: Bool
  }

  /// - Parameters:
  ///   - previousLaunchDiedEarly: the prior launch never marked itself survived.
  ///   - wasEnforcing: the prior launch had shields on or a selection saved —
  ///     if not, Screen Time cannot have been the killer, so the streak resets.
  ///   - priorEarlyDeathCount: persisted streak before this launch.
  static func assess(
    previousLaunchDiedEarly: Bool,
    wasEnforcing: Bool,
    priorEarlyDeathCount: Int
  ) -> Assessment {
    guard previousLaunchDiedEarly, wasEnforcing else {
      return Assessment(earlyDeathCount: 0, shouldEnterSafeMode: false)
    }
    let count = priorEarlyDeathCount + 1
    return Assessment(
      earlyDeathCount: count,
      shouldEnterSafeMode: count >= safeModeThreshold
    )
  }
}
