import SwiftUI

struct MenuBarContentView: View {
  @Environment(\.openWindow) private var openWindow
  @EnvironmentObject private var store: ProtectionStore

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Tortoise \(store.currentModeTitle)", systemImage: store.currentModeSystemImage)
        .font(.headline)

      Text(store.compactStatusLine)
        .font(.caption)
        .foregroundStyle(.secondary)

      MenuBarUsageSummaryView()

      if store.timedSessionActive {
        Text(store.timedSessionStatusLine)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if !store.focusWindows.isEmpty {
        Text(store.focusWindowScheduleStatusLine)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 10) {
        Label("Blocking \(store.blockerStatusLabel)", systemImage: "checkmark.shield")
        Label("Tuning \(store.tunerStatusLabel)", systemImage: "slider.horizontal.3")
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      if store.blockingControlsReady {
        Divider()

        Button("Focus 25m") {
          Task { await store.startTimedSession(mode: .focus, duration: 25 * 60) }
        }
        .disabled(blockingActionDisabled)

        Button("Strict 25m") {
          Task { await store.startTimedSession(mode: .strict, duration: 25 * 60) }
        }
        .disabled(blockingActionDisabled)

        Button("Lock Strict 1h") {
          Task { await store.startTimedSession(mode: .strict, duration: 60 * 60, locked: true) }
        }
        .disabled(blockingActionDisabled)

        if store.timedSessionActive && !store.timedSessionLockedActive {
          Button("End Session") {
            Task { await store.endTimedSession() }
          }
          .disabled(!store.blockingControlsReady || store.isWorking)
        }

        Divider()

        if !store.focusWindows.isEmpty {
          Button(store.focusWindowScheduleEnabled ? "Pause Schedule" : "Resume Schedule") {
            store.setFocusWindowScheduleEnabled(!store.focusWindowScheduleEnabled)
            Task { await store.evaluateFocusWindowSchedule() }
          }
          .disabled(!store.blockingControlsReady || store.isWorking)
        }

        Button("Open") {
          Task { await store.setAccessMode(.open) }
        }
        .disabled(blockingActionDisabled)

        Button("Focus") {
          Task { await store.setAccessMode(.focus) }
        }
        .disabled(blockingActionDisabled)

        Button("Strict") {
          Task { await store.setAccessMode(.strict) }
        }
        .disabled(blockingActionDisabled)
      } else {
        Divider()

        Text(store.blockingCapabilityUnavailableReason ?? "Connect QuietGate before using blocking controls.")
          .font(.caption)
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)

        Button("Finish Setup") {
          openWindow(id: "main")
          NSApp.activate(ignoringOtherApps: true)
        }
      }

      Button("Open Tortoise") {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
      }

      Divider()

      Button("Quit") {
        NSApp.terminate(nil)
      }
      .keyboardShortcut("q")
      .disabled(store.timedSessionLockedActive)
    }
    .frame(width: 260, alignment: .leading)
    .padding(.vertical, 4)
  }

  private var blockingActionDisabled: Bool {
    !store.blockingControlsReady || store.isWorking || store.timedSessionLockedActive
  }
}

private struct MenuBarUsageSummaryView: View {
  @EnvironmentObject private var store: ProtectionStore
  @State private var selectedTab = MenuBarUsageTab.all

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Picker("Usage app", selection: $selectedTab) {
        ForEach(MenuBarUsageTab.allCases) { tab in
          Text(tab.shortTitle).tag(tab)
        }
      }
      .labelsHidden()
      .pickerStyle(.segmented)

      Text("\(selectedTab.title): \(durationText(selectedSeconds)) today")
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
  }

  private var helperSnapshots: [ChromeHelperSnapshot] {
    let connectedSnapshots = store.connectedBrowserConnectors.compactMap {
      store.browserHelperSnapshots[$0.id]
    }
    return connectedSnapshots.isEmpty
      ? [store.browserHelperSnapshots[store.primaryBrowserConnector.id]].compactMap { $0 }
      : connectedSnapshots
  }

  private var selectedSeconds: Int {
    if let summary = helperSnapshots.compactMap(\.siteUsageSummary).first {
      switch selectedTab {
      case .all:
        return summary.totalSeconds
      case .youtube, .x, .instagram, .reddit:
        return summary.sites.first(where: { $0.siteID == selectedTab.rawValue })?.totalSeconds ?? 0
      }
    }
    if selectedTab == .all || selectedTab == .youtube {
      return helperSnapshots.compactMap(\.youtubeUsageSummary).first?.totalSeconds
        ?? helperSnapshots.compactMap(\.youtubeUsage).first?.totalSeconds
        ?? 0
    }
    return 0
  }

  private func durationText(_ seconds: Int) -> String {
    let total = max(seconds, 0)
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    if hours > 0 {
      return "\(hours)h \(String(format: "%02d", minutes))m"
    }
    return "\(minutes)m"
  }
}

private enum MenuBarUsageTab: String, CaseIterable, Identifiable {
  case all
  case youtube
  case x
  case instagram
  case reddit

  var id: String { rawValue }

  var title: String {
    switch self {
    case .all: return "All"
    case .youtube: return "YouTube"
    case .x: return "X"
    case .instagram: return "Instagram"
    case .reddit: return "Reddit"
    }
  }

  var shortTitle: String {
    switch self {
    case .instagram: return "IG"
    default: return title
    }
  }
}
