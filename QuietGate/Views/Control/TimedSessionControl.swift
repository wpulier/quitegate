import SwiftUI

struct TimedSessionControl: View {
  @EnvironmentObject private var store: ProtectionStore

  var body: some View {
    ProductPanel(
      title: "Focus timer",
      subtitle: "Turn on a temporary protection category. QuietGate switches back when the timer ends."
    ) {
      HStack(alignment: .firstTextBaseline) {
        TimelineView(.periodic(from: Date(), by: 30)) { _ in
          ProductStatusPill(
            text: store.timedSessionActive ? store.timedSessionStatusLine : "No timer running",
            tint: store.timedSessionActive ? .green : .secondary
          )
        }
        Spacer(minLength: 8)
      }

      ViewThatFits(in: .horizontal) {
        HStack(spacing: 10) {
          timerButtons
        }

        VStack(alignment: .leading, spacing: 10) {
          timerButtons
        }
      }

      if store.timedSessionActive && !store.timedSessionLockedActive {
        Button(role: .destructive) {
          Task { await store.endTimedSession() }
        } label: {
          Label("End Timer", systemImage: "stop.circle")
        }
        .disabled(!store.blockingControlsReady || store.isWorking)
      }

      if let reason = store.blockingCapabilityUnavailableReason {
        Label(reason, systemImage: "lock")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var timerButtons: some View {
    Group {
      TimerButton(title: "25 min", subtitle: "Focus", systemImage: "timer") {
        Task { await store.startTimedSession(mode: .focus, duration: 25 * 60) }
      }
      .disabled(timerButtonsDisabled)

      TimerButton(title: "50 min", subtitle: "Focus", systemImage: "timer") {
        Task { await store.startTimedSession(mode: .focus, duration: 50 * 60) }
      }
      .disabled(timerButtonsDisabled)

      TimerButton(title: "25 min", subtitle: "Strict", systemImage: "lock") {
        Task { await store.startTimedSession(mode: .strict, duration: 25 * 60) }
      }
      .disabled(timerButtonsDisabled)

      TimerButton(title: "1 hour", subtitle: "Locked Strict", systemImage: "lock.shield") {
        Task { await store.startTimedSession(mode: .strict, duration: 60 * 60, locked: true) }
      }
      .disabled(timerButtonsDisabled)
    }
  }

  private var timerButtonsDisabled: Bool {
    !store.blockingControlsReady || store.isWorking || store.timedSessionLockedActive
  }
}

private struct TimerButton: View {
  let title: String
  let subtitle: String
  let systemImage: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: systemImage)
          .frame(width: 18)
        VStack(alignment: .leading, spacing: 1) {
          Text(title)
            .font(.callout.weight(.semibold))
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .frame(minWidth: 122, alignment: .leading)
    }
  }
}
