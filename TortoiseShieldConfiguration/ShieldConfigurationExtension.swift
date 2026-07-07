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

  private func selfShieldConfiguration() -> ShieldConfiguration {
    Self.appGroupDefaults?.set(Date().timeIntervalSince1970, forKey: Self.selfShieldKey)
    return makeConfiguration(
      subtitle: "A selection accidentally included Tortoise itself. Open Tortoise — it repairs this automatically."
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
