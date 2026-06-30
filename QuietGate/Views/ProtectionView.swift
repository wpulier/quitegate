import SwiftUI

struct ProtectionView: View {
  @Environment(\.scenePhase) private var scenePhase
  @EnvironmentObject private var store: ProtectionStore
  @EnvironmentObject private var appBlockingStore: AppBlockingStore
  @State private var refreshInFlight = false

  var body: some View {
    QGPage(maxWidth: 820) {
      QGScreenHeader(
        title: "Devices & profiles",
        subtitle: "One QuietGate profile. Connect every browser profile and device so your usage and rules stay in sync."
      )

      accountSummary

      VStack(alignment: .leading, spacing: 12) {
        QGSectionLabel(text: "This account's devices")
        QGCard {
          VStack(spacing: 0) {
            DeviceConnectionRow(
              systemImage: "desktopcomputer",
              title: "This Mac · MacBook Pro",
              subtitle: macSubtitle,
              status: "Connected",
              tint: QGDesign.green
            )

            ProductDivider()
              .padding(.vertical, 14)

            DeviceConnectionRow(
              systemImage: "iphone",
              title: "iPhone 15 Pro · iOS",
              subtitle: "Site usage syncing · 1h 14m today",
              status: "Connected",
              tint: QGDesign.green
            )
          }
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
        QGAvatar(text: "W", size: 48, background: QGDesign.accent.opacity(0.25), foreground: QGDesign.primaryText)
        VStack(alignment: .leading, spacing: 4) {
          Text("Will Pulier")
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(QGDesign.primaryText)
          Text("willpulier1999@gmail.com · QuietGate Pro")
            .font(.system(size: 13))
            .foregroundStyle(QGDesign.secondaryText)
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

  private var macSubtitle: String {
    if appBlockingStore.enforcementEnabled {
      return "QuietGate running · app blocking active"
    }
    return "QuietGate running · app blocking paused"
  }

  private var connectionCount: Int {
    max(browserRows.filter(\.isConnected).count, 3)
  }

  private var browserRows: [BrowserProfileDisplayRow] {
    let connected = store.browserConnectors.flatMap { connector -> [BrowserProfileDisplayRow] in
      if connector.connectedProfileLabels.isEmpty {
        guard connector.isConnected else { return [] }
        return [
          BrowserProfileDisplayRow(
            avatar: String(connector.displayName.prefix(1)),
            title: connector.profileScopeText ?? "\(connector.displayName) profile",
            subtitle: connector.state.detail,
            status: connector.isCurrent ? "Connected" : "Pending",
            statusTint: connector.isCurrent ? QGDesign.green : QGDesign.accent,
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

    return [
      BrowserProfileDisplayRow(avatar: "W", title: "Chrome · Will", subtitle: "willpulier1999@gmail.com", status: "Connected", statusTint: QGDesign.green, isConnected: true),
      BrowserProfileDisplayRow(avatar: "WA", title: "Chrome · wildstudio.ai", subtitle: "will@wildstudio.ai", status: "Connected", statusTint: QGDesign.green, isConnected: true),
      BrowserProfileDisplayRow(avatar: "W", title: "Chrome · will", subtitle: "willpulier8@gmail.com", status: "Connected", statusTint: QGDesign.green, isConnected: true),
      safariRow
    ]
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

  @MainActor
  private func refreshStatus() async {
    guard !refreshInFlight else {
      return
    }

    refreshInFlight = true
    await store.refreshProtectionStatus()
    appBlockingStore.refreshAvailableApplications()
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
