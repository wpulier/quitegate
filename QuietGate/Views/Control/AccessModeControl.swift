import SwiftUI

struct AccessModeControl: View {
  @EnvironmentObject private var store: ProtectionStore

  var body: some View {
    ProductPanel(
      title: "Protection categories",
      subtitle: "Choose the category QuietGate should use right now."
    ) {
      VStack(alignment: .leading, spacing: 12) {
        ViewThatFits(in: .horizontal) {
          HStack(alignment: .center, spacing: 16) {
            categoryPicker
              .frame(width: 280)
            SelectedCategoryLine(mode: store.accessMode)
          }

          VStack(alignment: .leading, spacing: 10) {
            categoryPicker
              .frame(maxWidth: 360)
            SelectedCategoryLine(mode: store.accessMode)
          }
        }

        if store.timedSessionLockedActive {
          Label("A locked timer is running, so the category cannot change until it ends.", systemImage: "lock")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if let reason = store.blockingCapabilityUnavailableReason {
          Label(reason, systemImage: "lock")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }

  private var categoryPicker: some View {
    Picker("Protection category", selection: accessModeBinding) {
      ForEach(AccessMode.allCases) { mode in
        Text(mode.title)
          .tag(mode)
      }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .disabled(categoryPickerDisabled)
    .accessibilityLabel("Protection category")
    .help("Choose the active protection category.")
  }

  private var accessModeBinding: Binding<AccessMode> {
    Binding {
      store.accessMode
    } set: { mode in
      guard mode != store.accessMode else {
        return
      }
      Task { await store.setAccessMode(mode) }
    }
  }

  private var categoryPickerDisabled: Bool {
    !store.blockingControlsReady || store.isWorking || store.timedSessionLockedActive
  }
}

private struct SelectedCategoryLine: View {
  let mode: AccessMode

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        titleLabel
        Text(categoryDetail)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      VStack(alignment: .leading, spacing: 3) {
        titleLabel
        Text(categoryDetail)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var titleLabel: some View {
    Label(mode.title, systemImage: mode.systemImage)
      .font(.callout.weight(.semibold))
      .foregroundStyle(titleTint)
      .labelStyle(.titleAndIcon)
  }

  private var titleTint: Color {
    mode == .open ? Color(nsColor: .secondaryLabelColor) : .accentColor
  }

  private var categoryDetail: String {
    switch mode {
    case .open:
      return "QuietGate is ready, but not blocking yet."
    case .focus:
      return "Blocks adult websites and quiets YouTube plus sensitive X media."
    case .strict:
      return "Adds stronger browser tuning for intentional viewing."
    }
  }
}
