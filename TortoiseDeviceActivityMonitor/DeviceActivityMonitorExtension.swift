import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

final class TortoiseDeviceActivityMonitorExtension: DeviceActivityMonitor {
  private let scheduleStore = ManagedSettingsStore(named: .tortoiseSchedule)
  private let limitStore = ManagedSettingsStore(named: .tortoiseLimit)

  override func intervalDidStart(for activity: DeviceActivityName) {
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
    guard activity == .tortoiseDaily, event == .tortoiseDailyLimit else {
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
}
