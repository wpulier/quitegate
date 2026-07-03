import ClerkKit
import SwiftUI

struct ProtectionView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.scenePhase) private var scenePhase
  @EnvironmentObject private var store: ProtectionStore
  @EnvironmentObject private var appBlockingStore: AppBlockingStore
  @EnvironmentObject private var accountStore: MacAccountStore
  @State private var refreshInFlight = false

  var body: some View {
    QGPage(maxWidth: 820) {
      QGScreenHeader(
        title: "Devices & profiles",
        subtitle: "One Tortoise profile. Connect every browser profile and device so your usage and rules stay in sync."
      )

      accountSummary

      VStack(alignment: .leading, spacing: 12) {
        QGSectionLabel(text: "This account's devices")
        QGCard {
          deviceList
        }
      }

      VStack(alignment: .leading, spacing: 12) {
        QGSectionLabel(text: "Browser profiles")
        QGCard {
          VStack(spacing: 0) {
            ForEach(Array(browserRows.enumerated()), id: \.element.id) { index, row in
              if index > 0 {
                ProductDivider()
                  .padding(.vertical, 14)
              }
              BrowserProfileRow(row: row)
            }

            Button {
              if let primaryConnectAction {
                store.performReadinessAction(primaryConnectAction)
              }
            } label: {
              HStack {
                Image(systemName: "plus")
                Text("Connect another browser or device")
              }
              .frame(maxWidth: .infinity)
            }
            .buttonStyle(QGPrimaryButtonStyle())
            .padding(.top, 18)
            .disabled(primaryConnectAction == nil || store.isWorking)
          }
        }
      }

      if let setupMessage = store.setupMessage {
        Label(setupMessage, systemImage: "checkmark.circle")
          .font(.system(size: 13))
          .foregroundStyle(QGDesign.secondaryText)
          .textSelection(.enabled)
      }

      if let errorMessage = store.errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle")
          .font(.system(size: 13))
          .foregroundStyle(QGDesign.orange)
          .textSelection(.enabled)
      }
    }
    .task {
      await refreshStatus()
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        refreshStatusLater()
      }
    }
  }

  private var accountSummary: some View {
    QGCard {
      HStack(spacing: 14) {
        QGAvatar(text: accountStore.accountInitials, size: 48, background: QGDesign.accent.opacity(0.25), foreground: QGDesign.primaryText)
        VStack(alignment: .leading, spacing: 4) {
          Text(accountStore.accountDisplayName)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(QGDesign.primaryText)
          Text("\(accountStore.accountEmail) · \(accountStore.syncMessage)")
            .font(.system(size: 13))
            .foregroundStyle(QGDesign.secondaryText)
            .lineLimit(2)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          Text("\(connectionCount)")
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(QGDesign.primaryText)
          Text("active connections")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(QGDesign.secondaryText)
        }
      }
    }
  }

  @ViewBuilder
  private var deviceList: some View {
    let devices = accountDevices
    if devices.isEmpty {
      DeviceConnectionRow(
        systemImage: "desktopcomputer",
        title: "This Mac",
        subtitle: accountStore.isSignedIn ? "Waiting for device registration." : "Sign in to connect this Mac.",
        status: accountStore.macConnectionStatus,
        tint: accountStore.isSignedIn ? QGDesign.accent : QGDesign.secondaryText
      )
    } else {
      VStack(spacing: 0) {
        ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
          if index > 0 {
            ProductDivider()
              .padding(.vertical, 14)
          }
          DeviceConnectionRow(
            systemImage: deviceSystemImage(device),
            title: deviceTitle(device),
            subtitle: deviceSubtitle(device),
            status: deviceStatus(device),
            tint: deviceTint(device)
          )
        }
      }
    }
  }

  private var accountDevices: [TortoiseDevice] {
    var devicesByID = Dictionary(uniqueKeysWithValues: accountStore.snapshot.devices.map { ($0.id, $0) })
    if let current = accountStore.snapshot.device {
      devicesByID[current.id] = current
    }
    return devicesByID.values.sorted { lhs, rhs in
      let lhsDate = lhs.lastSeenAt.flatMap(Self.date(from:)) ?? .distantPast
      let rhsDate = rhs.lastSeenAt.flatMap(Self.date(from:)) ?? .distantPast
      return lhsDate > rhsDate
    }
  }

  private var macSubtitle: String {
    if appBlockingStore.enforcementEnabled {
      return "Tortoise running · app blocking active"
    }
    return "Tortoise running · app blocking paused"
  }

  private var connectionCount: Int {
    accountDevices.count + browserRows.filter(\.isConnected).count
  }

  private var browserRows: [BrowserProfileDisplayRow] {
    let connected = store.supportedBrowserConnectors.flatMap { connector -> [BrowserProfileDisplayRow] in
      if connector.connectedProfileLabels.isEmpty {
        return [
          BrowserProfileDisplayRow(
            avatar: String(connector.displayName.prefix(1)),
            title: connector.profileScopeText ?? "\(connector.displayName) profile",
            subtitle: connector.state.detail,
            status: connector.isConnected ? (connector.isCurrent ? "Connected" : "Pending") : "Not connected",
            statusTint: connector.isConnected ? (connector.isCurrent ? QGDesign.green : QGDesign.accent) : QGDesign.secondaryText,
            isConnected: connector.isConnected
          )
        ]
      }

      return connector.connectedProfileLabels.map { label in
        BrowserProfileDisplayRow(
          avatar: avatar(for: label),
          title: "\(connector.displayName) · \(label)",
          subtitle: "Synced recently",
          status: connector.isCurrent ? "Connected" : "Connected",
          statusTint: QGDesign.green,
          isConnected: true
        )
      }
    }

    if !connected.isEmpty {
      return connected + [safariRow]
    }

    return [safariRow]
  }

  private var safariRow: BrowserProfileDisplayRow {
    BrowserProfileDisplayRow(
      avatar: "S",
      title: "Safari",
      subtitle: "Connector planned",
      status: "Soon",
      statusTint: QGDesign.secondaryText,
      isConnected: false
    )
  }

  private var primaryConnectAction: ReadinessAction? {
    store.primaryBrowserConnector.nextAction
      ?? store.browserConnectors.compactMap(\.nextAction).first
  }

  private func avatar(for label: String) -> String {
    let letters = label
      .split(separator: " ")
      .prefix(2)
      .compactMap(\.first)
    let value = String(letters).uppercased()
    return value.isEmpty ? "W" : value
  }

  private func deviceSystemImage(_ device: TortoiseDevice) -> String {
    switch device.platform {
    case "ios":
      return "iphone"
    case "macos":
      return "desktopcomputer"
    case "chrome", "chrome_extension":
      return "globe"
    case "firefox":
      return "flame"
    default:
      return "macbook.and.iphone"
    }
  }

  private func deviceTitle(_ device: TortoiseDevice) -> String {
    let name = device.name?.trimmingCharacters(in: .whitespacesAndNewlines)
    let platform = device.platform?.uppercased() ?? "DEVICE"
    return "\(name?.isEmpty == false ? name! : "Tortoise device") · \(platform)"
  }

  private func deviceSubtitle(_ device: TortoiseDevice) -> String {
    let version = device.appVersion?.trimmingCharacters(in: .whitespacesAndNewlines)
    let seen = device.lastSeenAt.flatMap(Self.date(from:)).map(Self.relativeDate) ?? "No health check yet"
    if let version, !version.isEmpty {
      return "App \(version) · \(seen)"
    }
    return seen
  }

  private func deviceStatus(_ device: TortoiseDevice) -> String {
    guard let date = device.lastSeenAt.flatMap(Self.date(from:)) else {
      return "Setup needed"
    }
    return Date().timeIntervalSince(date) < 24 * 3600 ? "Connected" : "Stale"
  }

  private func deviceTint(_ device: TortoiseDevice) -> Color {
    deviceStatus(device) == "Connected" ? QGDesign.green : QGDesign.orange
  }

  private static func date(from value: String) -> Date? {
    ISO8601DateFormatter().date(from: value)
  }

  private static func relativeDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return "Seen \(formatter.localizedString(for: date, relativeTo: Date()))"
  }

  @MainActor
  private func refreshStatus() async {
    guard !refreshInFlight else {
      return
    }

    refreshInFlight = true
    await store.refreshProtectionStatus()
    appBlockingStore.refreshAvailableApplications()
    await accountStore.refresh(
      using: clerk,
      protectionStore: store,
      appBlockingStore: appBlockingStore
    )
    refreshInFlight = false
  }

  private func refreshStatusLater() {
    Task {
      await refreshStatus()
    }
  }
}

private struct DeviceConnectionRow: View {
  let systemImage: String
  let title: String
  let subtitle: String
  let status: String
  let tint: Color

  var body: some View {
    HStack(spacing: 13) {
      Image(systemName: systemImage)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(tint)
        .frame(width: 38, height: 38)
        .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(QGDesign.primaryText)
        Text(subtitle)
          .font(.system(size: 12))
          .foregroundStyle(QGDesign.secondaryText)
      }

      Spacer()
      QGPill(text: status, tint: tint)
    }
  }
}

private struct BrowserProfileRow: View {
  let row: BrowserProfileDisplayRow

  var body: some View {
    HStack(spacing: 12) {
      QGAvatar(text: row.avatar, size: 36)
      VStack(alignment: .leading, spacing: 3) {
        Text(row.title)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(row.isConnected ? QGDesign.primaryText : QGDesign.secondaryText)
        Text(row.subtitle)
          .font(.system(size: 12))
          .foregroundStyle(QGDesign.secondaryText)
      }
      Spacer()
      QGPill(text: row.status, tint: row.statusTint)
    }
  }
}

private struct BrowserProfileDisplayRow: Identifiable {
  let id = UUID()
  let avatar: String
  let title: String
  let subtitle: String
  let status: String
  let statusTint: Color
  let isConnected: Bool
}
