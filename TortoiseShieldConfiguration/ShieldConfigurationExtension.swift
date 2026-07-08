import ManagedSettings
import ManagedSettingsUI
import UIKit

final class TortoiseShieldConfigurationExtension: ShieldConfigurationDataSource {
  /// Only shield extensions may read a shielded app's bundle identifier, so this
  /// is the one place the "Tortoise can't block Tortoise" invariant can be
  /// verified. On detection, flag the App Group (key mirrored in
  /// IOSEnforcementSharedStore.selfShieldKey — that file isn't compiled here)
  /// so the main app repairs the offending selection on next launch.
  private static let tortoiseBundleID = "com.yourtortoise.Tortoise"
  private static let selfShieldKey = "TortoiseSelfShieldDetectedAt"
  private static let appGroupDefaults = UserDefaults(suiteName: "group.com.yourtortoise.Tortoise")

  override func configuration(shielding application: Application) -> ShieldConfiguration {
    if isTortoise(application) {
      return selfShieldConfiguration()
    }
    return makeConfiguration(subtitle: "Tortoise is blocking this app during your active iOS session.")
  }

  override func configuration(
    shielding application: Application,
    in category: ActivityCategory
  ) -> ShieldConfiguration {
    if isTortoise(application) {
      return selfShieldConfiguration()
    }
    return makeConfiguration(subtitle: "Tortoise is blocking this app category during your active iOS session.")
  }

  private func isTortoise(_ application: Application) -> Bool {
    application.bundleIdentifier == Self.tortoiseBundleID
  }

  /// Every Tortoise store name ever shipped, mirrored verbatim from
  /// ManagedSettingsStore.Name.tortoiseAllStores in IOSEnforcementShared.swift
  /// (not compiled into this target). Append-only, like the original.
  private static let allStoreNames = [
    "tortoise.immediate",
    "tortoise.schedule",
    "tortoise.limit",
    "tortoise.managedApps",
    "tortoise.managedApps.limit",
    "tortoise.youtube",
  ]

  /// Keys mirrored from IOSEnforcementSharedStore's selection storage.
  private static let selectionKeys = [
    "TortoiseIOSEnforcementSelection",
    "TortoiseIOSManagedAppsSelection",
  ]

  private func selfShieldConfiguration() -> ShieldConfiguration {
    Self.appGroupDefaults?.set(Date().timeIntervalSince1970, forKey: Self.selfShieldKey)
    // Heal in place, not just flag: when Tortoise itself is shielded, iOS
    // kills the main app on every foreground, so this extension may be the
    // only Tortoise code that ever runs. Drop every shield and the persisted
    // selections that caused them; the main app's launch recovery finishes
    // the cleanup once it can stay alive.
    for name in Self.allStoreNames {
      ManagedSettingsStore(named: .init(name)).clearAllSettings()
    }
    for key in Self.selectionKeys {
      Self.appGroupDefaults?.removeObject(forKey: key)
    }
    return makeConfiguration(
      subtitle: "A selection accidentally included Tortoise itself. Tortoise cleared it — reopen the app and pick your apps again."
    )
  }

  override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
    makeConfiguration(subtitle: "Tortoise is blocking this site in Safari during your active iOS session.")
  }

  override func configuration(
    shielding webDomain: WebDomain,
    in category: ActivityCategory
  ) -> ShieldConfiguration {
    makeConfiguration(subtitle: "Tortoise is blocking this web category during your active iOS session.")
  }

  private func makeConfiguration(subtitle: String) -> ShieldConfiguration {
    ShieldConfiguration(
      backgroundBlurStyle: .systemUltraThinMaterialDark,
      backgroundColor: UIColor(red: 0.06, green: 0.08, blue: 0.10, alpha: 1),
      icon: UIImage(systemName: "shield.lefthalf.filled"),
      title: ShieldConfiguration.Label(
        text: "Tortoise is on",
        color: .white
      ),
      subtitle: ShieldConfiguration.Label(
        text: subtitle,
        color: UIColor(white: 0.82, alpha: 1)
      ),
      primaryButtonLabel: ShieldConfiguration.Label(
        text: "Close",
        color: .white
      ),
      primaryButtonBackgroundColor: UIColor(red: 0.18, green: 0.49, blue: 0.95, alpha: 1),
      secondaryButtonLabel: ShieldConfiguration.Label(
        text: "Keep blocking",
        color: UIColor(white: 0.86, alpha: 1)
      )
    )
  }
}
