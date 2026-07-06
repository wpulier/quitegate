import Foundation

/// Pure, cross-platform decision logic for the general "Apps" Screen-Time
/// layer (Stage 1). Kept free of `FamilyControls`/`ManagedSettings` (iOS-only)
/// so it compiles and is unit-tested on macOS, mirroring `IOSSession`.
///
/// The managed-apps selection is shielded under Focus/Strict and cleared under
/// Open ("block under mode"). During a *locked* Strict session the commitment is
/// frozen: the selection may grow but must not shrink or clear (precommitment).
enum ManagedAppsShield {
  /// Whether the managed-apps shield is applied for `mode`.
  /// Focus and Strict shield; Open clears.
  static func shouldShield(mode: IOSEnforcementMode) -> Bool {
    switch mode {
    case .focus, .strict:
      return true
    case .open:
      return false
    }
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
}
