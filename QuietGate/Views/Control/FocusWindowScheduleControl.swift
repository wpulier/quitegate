import SwiftUI

struct FocusWindowScheduleControl: View {
  @EnvironmentObject private var store: ProtectionStore
  @State private var startDate = Self.defaultStartDate(hour: 9)
  @State private var endDate = Self.defaultStartDate(hour: 17)
  @State private var mode = AccessMode.focus

  var body: some View {
    ProductPanel(
      title: "Daily schedule",
      subtitle: "Let QuietGate switch protection on at the same time each day while the app is running."
    ) {
      HStack(alignment: .center, spacing: 12) {
        Toggle("Schedule", isOn: scheduleEnabledBinding)
          .toggleStyle(.switch)
          .disabled(!store.blockingControlsReady)

        ProductStatusPill(
          text: store.focusWindowScheduleStatusLine,
          tint: store.focusWindowScheduleEnabled ? .green : .secondary
        )
      }

      ViewThatFits(in: .horizontal) {
        HStack(spacing: 10) {
          scheduleFields
        }

        VStack(alignment: .leading, spacing: 10) {
          scheduleFields
        }
      }

      if let reason = store.blockingCapabilityUnavailableReason {
        Label(reason, systemImage: "lock")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      if store.focusWindows.isEmpty {
        Text("No daily schedule yet.")
          .font(.callout)
          .foregroundStyle(.secondary)
      } else {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(Array(store.focusWindows.enumerated()), id: \.element.id) { index, window in
            if index > 0 {
              ProductDivider()
            }
            FocusWindowRow(window: window)
          }
        }
      }
    }
  }

  private var scheduleFields: some View {
    Group {
      Picker("Category", selection: $mode) {
        ForEach([AccessMode.focus, .strict]) { mode in
          Label(mode.title, systemImage: mode.systemImage)
            .tag(mode)
        }
      }
      .frame(width: 135)

      LabeledContent("From") {
        DatePicker("From", selection: $startDate, displayedComponents: .hourAndMinute)
          .labelsHidden()
      }

      LabeledContent("To") {
        DatePicker("To", selection: $endDate, displayedComponents: .hourAndMinute)
          .labelsHidden()
      }

      Button {
        addWindow()
      } label: {
        Label("Add", systemImage: "plus")
      }
      .disabled(startMinute == endMinute || !store.blockingControlsReady)
    }
  }

  private var scheduleEnabledBinding: Binding<Bool> {
    Binding {
      store.focusWindowScheduleEnabled
    } set: { enabled in
      store.setFocusWindowScheduleEnabled(enabled)
      Task { await store.evaluateFocusWindowSchedule() }
    }
  }

  private var startMinute: Int {
    minuteOfDay(from: startDate)
  }

  private var endMinute: Int {
    minuteOfDay(from: endDate)
  }

  private func addWindow() {
    let title = "\(mode.title) \(FocusWindow.timeText(startMinute))"
    store.addFocusWindow(
      title: title,
      startMinute: startMinute,
      endMinute: endMinute,
      mode: mode
    )
    Task { await store.evaluateFocusWindowSchedule() }
  }

  private func minuteOfDay(from date: Date) -> Int {
    let components = Calendar.current.dateComponents([.hour, .minute], from: date)
    return ((components.hour ?? 0) * 60) + (components.minute ?? 0)
  }

  private static func defaultStartDate(hour: Int) -> Date {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: Date())
    return calendar.date(byAdding: .hour, value: hour, to: startOfDay) ?? Date()
  }
}

private struct FocusWindowRow: View {
  @EnvironmentObject private var store: ProtectionStore
  let window: FocusWindow

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      Image(systemName: window.mode.systemImage)
        .foregroundStyle(iconColor)
        .frame(width: 18)

      VStack(alignment: .leading, spacing: 2) {
        Text(window.title)
          .font(.callout.weight(.medium))
        Text("\(window.mode.title), \(window.timeRangeTitle)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 12)

      Toggle("Enabled", isOn: enabledBinding)
        .labelsHidden()
        .toggleStyle(.switch)
        .disabled(!store.blockingControlsReady)

      Button {
        store.removeFocusWindow(window.id)
        Task { await store.evaluateFocusWindowSchedule() }
      } label: {
        Image(systemName: "trash")
      }
      .buttonStyle(.borderless)
      .disabled(!store.blockingControlsReady)
      .help("Remove \(window.title)")
    }
    .padding(.vertical, 10)
  }

  private var enabledBinding: Binding<Bool> {
    Binding {
      window.isEnabled
    } set: { enabled in
      store.setFocusWindow(window.id, isEnabled: enabled)
      Task { await store.evaluateFocusWindowSchedule() }
    }
  }

  private var iconColor: Color {
    store.activeFocusWindow?.id == window.id ? .green : .secondary
  }
}
