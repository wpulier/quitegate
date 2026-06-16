import SwiftUI

struct SettingsView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HeaderView(
        title: "Settings",
        subtitle: "Setup and everyday controls live in the main QuietGate window.",
        systemImage: "gearshape"
      )

      Text("Use Setup to connect QuietGate. Use Home for blocked sites, protection categories, timers, and daily schedules.")
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(28)
    .frame(maxWidth: 460, alignment: .leading)
  }
}
