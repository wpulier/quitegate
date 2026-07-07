import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

final class TortoiseDeviceActivityMonitorExtension: DeviceActivityMonitor {
  private let scheduleStore = ManagedSettingsStore(named: .tortoiseSchedule)
  private let limitStore = ManagedSettingsStore(named: .tortoiseLimit)
  private let managedAppsLimitStore = ManagedSettingsStore(named: .tortoiseManagedAppsLimit)

  override func intervalDidStart(for activity: DeviceActivityName) {
    if activity == .tortoiseManagedAppsDaily {
      // Fresh day for the managed-apps limit: no limit shield until the combined
      // threshold is reached again.
      managedAppsLimitStore.clearAllSettings()
      return
    }

    guard activity == .tortoiseDaily else {
      return
    }

    let snapshot = IOSEnforcementSharedStore.loadSnapshot()
    guard snapshot.shieldingEnabled, snapshot.mode != .open else {
      scheduleStore.clearAllSettings()
      return
    }

    IOSEnforcementShieldApplier.applySelection(
      IOSEnforcementSharedStore.loadSelection(),
      to: scheduleStore,
      adultWebFilterEnabled: snapshot.mode == .strict
    )
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    if activity == .tortoiseManagedAppsDaily {
      managedAppsLimitStore.clearAllSettings()
      return
    }
    guard activity == .tortoiseDaily else {
      return
    }
    scheduleStore.clearAllSettings()
    limitStore.clearAllSettings()
  }

  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    switch event {
    case .tortoiseDailyLimit:
      handleYouTubeLimitReached(event: event, activity: activity)
    case .managedAppsDailyLimit:
      handleManagedAppsLimitReached(event: event, activity: activity)
    default:
      return
    }
  }

  /// YouTube daily limit (Focus/Strict) — shields the YouTube selection into
  /// `.tortoiseLimit`. Behavior unchanged from Stage 1.
  private func handleYouTubeLimitReached(
    event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    guard activity == .tortoiseDaily else {
      return
    }

    let snapshot = IOSEnforcementSharedStore.loadSnapshot()
    guard snapshot.shieldingEnabled, snapshot.mode != .open else {
      limitStore.clearAllSettings()
      return
    }

    IOSEnforcementShieldApplier.applySelection(
      IOSEnforcementSharedStore.loadSelection(),
      to: limitStore,
      adultWebFilterEnabled: true
    )
    IOSEnforcementSharedStore.recordThresholdEvent(
      IOSEnforcementThresholdEvent(
        eventName: event.rawValue,
        activityName: activity.rawValue,
        reachedAt: Date()
      )
    )
  }

  /// Stage 2: combined managed-apps daily limit (OPEN governor). Shields the
  /// managed-apps selection into its OWN `.tortoiseManagedAppsLimit` store —
  /// shield fields ONLY, no adult filter — so the OS unions it with the Stage 1
  /// `.tortoiseManagedApps` shield. Applies regardless of mode (redundant-harmless
  /// in Focus/Strict). Gated defensively on the limit being enabled and the
  /// selection non-empty; otherwise the store is cleared (no stale limit shield).
  private func handleManagedAppsLimitReached(
    event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    guard activity == .tortoiseManagedAppsDaily else {
      return
    }

    let snapshot = IOSEnforcementSharedStore.loadSnapshot()
    let selection = IOSEnforcementSharedStore.loadManagedAppsSelection()
    let hasSelection = !selection.applicationTokens.isEmpty
      || !selection.categoryTokens.isEmpty
      || !selection.webDomainTokens.isEmpty
    guard snapshot.managedAppsLimitMinutes != nil, hasSelection else {
      managedAppsLimitStore.clearAllSettings()
      return
    }

    IOSEnforcementShieldApplier.applyShield(selection, to: managedAppsLimitStore)
    IOSEnforcementSharedStore.recordThresholdEvent(
      IOSEnforcementThresholdEvent(
        eventName: event.rawValue,
        activityName: activity.rawValue,
        reachedAt: Date()
      )
    )
  }
}
