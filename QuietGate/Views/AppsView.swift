import AppKit
import SwiftUI

struct AppsView: View {
  @ObservedObject var store: AppBlockingStore
  @State private var appSearchText = ""

  var body: some View {
    ProductPage(maxWidth: 820) {
      ProductHeader(
        title: "Apps",
        subtitle: "Close distracting Mac apps and keep QuietGate ready after restart.",
        systemImage: "app.badge"
      )

      StartupPanel(store: store)

      ProductCallout(
        title: "Close blocked apps",
        detail: "QuietGate watches for selected apps and closes them as soon as they launch. The app may briefly appear; stronger launch prevention is planned.",
        systemImage: "macwindow.badge.plus",
        tint: .blue
      ) {
        ProductActionRow {
          Toggle("Close blocked apps", isOn: $store.enforcementEnabled)
            .toggleStyle(.switch)

          Button {
            store.enforceNow()
          } label: {
            Label("Close Now", systemImage: "xmark.app")
          }
          .disabled(!store.enforcementEnabled || store.activeBlockedApplications.isEmpty)
        }
      }

      ProductPanel(title: "Blocked apps", subtitle: store.statusSummary) {
        if store.blockedApplications.isEmpty {
          ContentUnavailableView(
            "No apps blocked",
            systemImage: "app",
            description: Text("Choose an app below to add it here.")
          )
          .frame(maxWidth: .infinity, minHeight: 140)
        } else {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(store.blockedApplications.enumerated()), id: \.element.id) { index, rule in
              if index > 0 {
                ProductDivider()
              }
              BlockedApplicationRow(rule: rule, store: store)
            }
          }
        }
      }

      ProductPanel(title: "Choose apps", subtitle: "Pick an installed app, or open an app and refresh if it is missing.") {
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 12) {
            TextField("Search apps", text: $appSearchText)
              .textFieldStyle(.roundedBorder)
              .frame(maxWidth: 320)

            Button {
              store.refreshAvailableApplications()
            } label: {
              Label("Refresh Apps", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
          }

          if filteredAvailableApplications.isEmpty {
            ContentUnavailableView(
              "No apps found",
              systemImage: "app.dashed",
              description: Text("Try another search, or open the app once and refresh.")
            )
            .frame(maxWidth: .infinity, minHeight: 140)
          } else {
            VStack(alignment: .leading, spacing: 0) {
              ForEach(Array(filteredAvailableApplications.enumerated()), id: \.element.id) { index, app in
                if index > 0 {
                  ProductDivider()
                }
                AvailableApplicationRow(app: app, store: store)
              }
            }
          }
        }
      }
    }
    .navigationTitle("Apps")
    .task {
      store.refreshAvailableApplications()
      store.startMonitoring()
    }
  }

  private var filteredAvailableApplications: [RunningApplicationSnapshot] {
    let query = appSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else {
      return store.availableApplications
    }
    return store.availableApplications.filter {
      $0.displayName.localizedCaseInsensitiveContains(query)
    }
  }
}

private struct StartupPanel: View {
  @ObservedObject var store: AppBlockingStore

  var body: some View {
    ProductCallout(
      title: "Start QuietGate when you sign in",
      detail: store.startupStatusSummary,
      systemImage: "power.circle",
      tint: tint
    ) {
      ProductActionRow {
        Toggle("Start at login", isOn: Binding(
          get: { store.startupState.isOn },
          set: { store.setStartAtLoginEnabled($0) }
        ))
        .toggleStyle(.switch)
        .disabled(startupSettingUnavailable)

        if case .needsApproval = store.startupState {
          Button {
            openLoginItemsSettings()
          } label: {
            Label("Open Settings", systemImage: "gear")
          }
          .buttonStyle(.bordered)
        }
      }

      if let startupMessage = store.startupMessage {
        Label(startupMessage, systemImage: "checkmark.circle")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if let startupErrorMessage = store.startupErrorMessage {
        Label(startupErrorMessage, systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(.orange)
      }
    }
  }

  private var startupSettingUnavailable: Bool {
    if case .unavailable = store.startupState {
      return true
    }
    return false
  }

  private var tint: Color {
    switch store.startupState {
    case .enabled:
      return .green
    case .needsApproval:
      return .orange
    case .off:
      return .blue
    case .unavailable:
      return .secondary
    }
  }

  private func openLoginItemsSettings() {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else {
      return
    }
    NSWorkspace.shared.open(url)
  }
}

private struct BlockedApplicationRow: View {
  let rule: BlockedApplicationRule
  @ObservedObject var store: AppBlockingStore

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Image(systemName: "app.fill")
        .foregroundStyle(rule.isEnabled ? .blue : .secondary)
        .frame(width: 22)

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Text(rule.displayName)
            .font(.headline)
          ProductStatusPill(text: rule.isEnabled ? "Blocked" : "Paused", tint: rule.isEnabled ? .blue : .secondary)
        }
        Text(rule.isEnabled ? "Closes when opened." : "Saved, but not closing.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 12)

      Toggle("", isOn: Binding(
        get: { rule.isEnabled },
        set: { store.setBlockedApplication(rule.bundleIdentifier, enabled: $0) }
      ))
      .toggleStyle(.switch)
      .labelsHidden()

      Button {
        store.removeBlockedApplication(rule.bundleIdentifier)
      } label: {
        Label("Remove", systemImage: "trash")
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
      .help("Remove \(rule.displayName)")
    }
    .padding(.vertical, 12)
  }
}

private struct AvailableApplicationRow: View {
  let app: RunningApplicationSnapshot
  @ObservedObject var store: AppBlockingStore

  private var isBlocked: Bool {
    store.blockedApplications.contains {
      $0.bundleIdentifier == app.bundleIdentifier && $0.isEnabled
    }
  }

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Image(systemName: "macwindow")
        .foregroundStyle(.secondary)
        .frame(width: 22)

      VStack(alignment: .leading, spacing: 4) {
        Text(app.displayName)
          .font(.headline)
      }

      Spacer(minLength: 12)

      if isBlocked {
        ProductStatusPill(text: "Blocked", tint: .blue)
      } else {
        Button {
          store.addBlockedApplication(app)
        } label: {
          Label("Block", systemImage: "plus")
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(.vertical, 12)
  }
}
