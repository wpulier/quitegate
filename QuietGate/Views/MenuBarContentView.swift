import SwiftUI

struct MenuBarContentView: View {
  @Environment(\.openWindow) private var openWindow
  @EnvironmentObject private var store: ProtectionStore

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("QuietGate \(store.currentModeTitle)", systemImage: store.currentModeSystemImage)
        .font(.headline)

      Text(store.compactStatusLine)
        .font(.caption)
        .foregroundStyle(.secondary)

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

      Button("Open QuietGate") {
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
    .frame(width: 220, alignment: .leading)
    .padding(.vertical, 4)
  }

  private var blockingActionDisabled: Bool {
    !store.blockingControlsReady || store.isWorking || store.timedSessionLockedActive
  }
}
