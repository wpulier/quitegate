import Foundation

/// Pure, cross-platform decision logic for the general "Apps" Screen-Time
/// layer (Stage 1). Kept free of `FamilyControls`/`ManagedSettings` (iOS-only)
/// so it compiles and is unit-tested on macOS, mirroring `IOSSession`.
///
/// The managed-apps selection is shielded under Focus/Strict and cleared under
/// Open ("block under mode"). During a *locked* Strict session the commitment is
/// frozen: the selection may grow but must not shrink or clear (precommitment).
enum ManagedAppsShield {
  /// Whether the managed-apps store carries a shield for `mode`.
  /// Focus and Strict shield the managed selection; Custom shields its own
  /// picked group (same store, different source); Open clears.
  static func shouldShield(mode: IOSEnforcementMode) -> Bool {
    switch mode {
    case .focus, .strict, .custom:
      return true
    case .open:
      return false
    }
  }

  /// The tokens Custom actually shields: the picked group minus the per-app
  /// switches the user turned off.
  static func customShieldTokens<Token: Hashable>(selected: Set<Token>, excluded: Set<Token>) -> Set<Token> {
    selected.subtracting(excluded)
  }

  /// Per-app custom switches obey precommitment: while a locked session is
  /// active a switch may turn ON (tighten) but never OFF (loosen).
  static func canToggleCustomApp(lockedActive: Bool, turningOn: Bool) -> Bool {
    turningOn || !lockedActive
  }

  /// A change from `old` to `new` *shrinks* the commitment when any previously
  /// committed token is dropped — i.e. `old` is not a subset of `new`. Pure
  /// additions (`old ⊆ new`) grow and are never a shrink; swapping one token for
  /// another (equal count, different membership) drops a committed token and is
  /// therefore a shrink.
  static func isShrink<Token: Hashable>(old: Set<Token>, new: Set<Token>) -> Bool {
    !old.isSubset(of: new)
  }

  /// Whether an edit may be applied given the locked state. Unlocked: any edit is
  /// allowed. Locked-active: growing/unchanged is allowed, shrinking/clearing is
  /// refused.
  static func canApplyEdit(lockedActive: Bool, isShrink: Bool) -> Bool {
    if lockedActive {
      return !isShrink
    }
    return true
  }

  /// Clamps a raw daily-limit value to the supported 5–480 minute range (mirrors
  /// the YouTube `dailyLimitMinutes` bounds).
  static func clampManagedAppsLimitMinutes(_ minutes: Int) -> Int {
    min(max(minutes, 5), 480)
  }

  /// The combined managed-apps daily-limit monitor is armed only when the limit
  /// is enabled AND at least one target is selected. (Mode is irrelevant — the
  /// limit is an OPEN governor and is redundant-harmless in Focus/Strict.)
  static func shouldArmManagedAppsLimit(limitEnabled: Bool, hasSelection: Bool) -> Bool {
    limitEnabled && hasSelection
  }

  /// The adult web/media filter applies in Strict (always rides the mode) and
  /// in Custom (rides the group's own "Adult websites" toggle) — never in
  /// Open/Focus, and always independent of any app/site selection.
  static func shouldApplyAdultFilter(mode: IOSEnforcementMode, adultEnabled: Bool) -> Bool {
    switch mode {
    case .strict, .custom:
      return adultEnabled
    case .open, .focus:
      return false
    }
  }

  /// Enforcement is "active" (for status reporting) when any of the enforcement
  /// sources is engaged: a YouTube selection, a managed-apps selection, or the
  /// adult filter. Decouples status from requiring a *YouTube* selection.
  static func isEnforcementActive(
    youtubeSelected: Bool, managedAppsSelected: Bool, adultFilterOn: Bool
  ) -> Bool {
    youtubeSelected || managedAppsSelected || adultFilterOn
  }

  /// Raw category shields were removed (an opaque category can contain Tortoise
  /// itself, and iOS would then close Tortoise — the "Tortoise can't block
  /// Tortoise" invariant). Category picks now enforce through their member-app
  /// tokens expanded at pick time. A selection holding ONLY category tokens
  /// therefore enforces nothing and needs a re-pick.
  static func selectionNeedsRepick(
    categoryCount: Int, applicationCount: Int, webDomainCount: Int
  ) -> Bool {
    categoryCount > 0 && applicationCount == 0 && webDomainCount == 0
  }
}
