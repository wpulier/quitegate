import ManagedSettings
import ManagedSettingsUI
import UIKit

final class TortoiseShieldConfigurationExtension: ShieldConfigurationDataSource {
  override func configuration(shielding application: Application) -> ShieldConfiguration {
    makeConfiguration(subtitle: "QuietGate is blocking this app during your active iOS session.")
  }

  override func configuration(
    shielding application: Application,
    in category: ActivityCategory
  ) -> ShieldConfiguration {
    makeConfiguration(subtitle: "QuietGate is blocking this app category during your active iOS session.")
  }

  override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
    makeConfiguration(subtitle: "QuietGate is blocking this site in Safari during your active iOS session.")
  }

  override func configuration(
    shielding webDomain: WebDomain,
    in category: ActivityCategory
  ) -> ShieldConfiguration {
    makeConfiguration(subtitle: "QuietGate is blocking this web category during your active iOS session.")
  }

  private func makeConfiguration(subtitle: String) -> ShieldConfiguration {
    ShieldConfiguration(
      backgroundBlurStyle: .systemUltraThinMaterialDark,
      backgroundColor: UIColor(red: 0.06, green: 0.08, blue: 0.10, alpha: 1),
      icon: UIImage(systemName: "shield.lefthalf.filled"),
      title: ShieldConfiguration.Label(
        text: "QuietGate is on",
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
