import SwiftUI

struct ControlView: View {
  @EnvironmentObject private var store: ProtectionStore
  let openProtection: () -> Void

  init(openProtection: @escaping () -> Void = {}) {
    self.openProtection = openProtection
  }

  var body: some View {
    ProductPage(maxWidth: 860) {
      ProductHeader(
        title: "Home",
        subtitle: homeSubtitle,
        systemImage: store.currentModeSystemImage
      )

      if !store.blockingControlsReady {
        HomeStatusPanel(openProtection: openProtection)
      }

      if store.blockingControlsReady {
        AccessModeControl()
        BlockRulesSection(openProtection: openProtection)
        TimedSessionControl()
        FocusWindowScheduleControl()
      } else {
        ControlSetupGate(openProtection: openProtection)
      }

      if let errorMessage = store.errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle")
          .foregroundStyle(.orange)
          .font(.callout)
          .textSelection(.enabled)
      }
    }
    .navigationTitle("Home")
    .task {
      await store.refreshProtectionStatus()
    }
  }

  private var homeSubtitle: String {
    if store.blockingControlsReady {
      if let scopeText = store.connectedBrowserProfileScopeText {
        return "Choose website blocks, timers, and schedules for \(scopeText)."
      }
      return "Choose website blocks, timers, and schedules for connected browsers."
    }
    return store.blockingCapabilityUnavailableReason
      ?? "Finish setup before website controls can work."
  }
}

private struct HomeStatusPanel: View {
  @EnvironmentObject private var store: ProtectionStore
  let openProtection: () -> Void

  var body: some View {
    ProductCallout(
      title: title,
      detail: detail,
      systemImage: systemImage,
      tint: tint
    ) {
      ProductActionRow {
        Button(action: openProtection) {
          Label("Finish Setup", systemImage: "checkmark.shield")
        }
        .buttonStyle(.borderedProminent)
      }
    }
  }

  private var title: String {
    "Connection needed"
  }

  private var detail: String {
    store.blockingCapabilityUnavailableReason
      ?? "Open Setup and connect a browser before relying on website blocks, timers, or schedules."
  }

  private var systemImage: String {
    "lock.shield"
  }

  private var tint: Color {
    .orange
  }
}

private struct ControlSetupGate: View {
  @EnvironmentObject private var store: ProtectionStore
  let openProtection: () -> Void

  var body: some View {
    ProductPanel(title: "Controls are not ready", subtitle: "QuietGate shows these controls after a browser connection works.") {
      VStack(alignment: .leading, spacing: 14) {
        SetupPreviewLine(
          title: "Websites and adult content",
          detail: "Available after a browser connection is ready."
        )
        SetupPreviewLine(
          title: "Focus timers",
          detail: "Starts after QuietGate can apply the selected protection category."
        )
        SetupPreviewLine(
          title: "Daily schedule",
          detail: "Switches modes automatically after the connection is ready."
        )

        ProductActionRow {
          Button(action: openProtection) {
            Label("Finish Setup", systemImage: "checkmark.shield")
          }
          .buttonStyle(.borderedProminent)
        }
      }
    }
  }
}

private struct SetupPreviewLine: View {
  let title: String
  let detail: String

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "lock")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(width: 18)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.callout.weight(.medium))
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}
