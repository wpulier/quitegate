import ClerkKit
import SwiftUI

struct ProtectionView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.scenePhase) private var scenePhase
  @EnvironmentObject private var store: ProtectionStore
  @EnvironmentObject private var appBlockingStore: AppBlockingStore
  @EnvironmentObject private var accountStore: MacAccountStore
  @State private var refreshInFlight = false
  @State private var addSheetPresented = false

  var body: some View {
    QGPage(maxWidth: 820) {
      QGScreenHeader(
        title: "Devices & browser profiles",
        subtitle: "Mac and iPhone are the devices. Browser profiles sit under the browser and device where they run."
      )

      accountSummary

      VStack(alignment: .leading, spacing: 12) {
        QGSectionLabel(text: "Devices")
        QGCard {
          hubDeviceList
        }
      }

      // TODO(2c): fold local browserConnectors into hubRows
      VStack(alignment: .leading, spacing: 12) {
        QGSectionLabel(text: "Mac browsers")
        QGCard {
          macBrowsers
        }
      }

      connectButton

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
    .sheet(isPresented: $addSheetPresented) {
      AddSheetView()
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
  private var hubDeviceList: some View {
    VStack(spacing: 0) {
      ForEach(Array(hubRows.enumerated()), id: \.element.id) { index, row in
        if index > 0 {
          ProductDivider()
            .padding(.vertical, 14)
        }
        VStack(alignment: .leading, spacing: 0) {
          HubDeviceRow(row: row)

          if !row.profiles.isEmpty {
            VStack(spacing: 0) {
              ForEach(Array(row.profiles.enumerated()), id: \.element.id) { profileIndex, profile in
                if profileIndex > 0 {
                  ProductDivider()
                    .padding(.vertical, 10)
                }
                HubDeviceRow(row: profile)
              }
            }
            .padding(.leading, 50)
            .padding(.top, 12)
          }
        }
      }
    }
  }

  // TODO(2c): fold local browserConnectors into hubRows
  @ViewBuilder
  private var macBrowsers: some View {
    VStack(alignment: .leading, spacing: 0) {
      PlatformSubsectionHeader(
        systemImage: "globe",
        title: "Mac browsers",
        subtitle: "Each browser can have one or more connected profiles."
      )

      VStack(spacing: 0) {
        ForEach(Array(macBrowserGroups.enumerated()), id: \.element.id) { index, group in
          if index > 0 {
            ProductDivider()
              .padding(.vertical, 14)
          }
          BrowserProfileGroupRow(group: group)
        }
      }
      .padding(.top, 12)
    }
  }

  private var connectButton: some View {
    Button {
      addSheetPresented = true
    } label: {
      HStack {
        Image(systemName: "plus")
        Text("Connect another browser or device")
      }
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(QGPrimaryButtonStyle())
  }

  private var hubRows: [DeviceHubRow] {
    var devices = accountStore.snapshot.devices
    if let current = accountStore.snapshot.device, !devices.contains(where: { $0.id == current.id }) {
      devices.append(current)
    }
    return DevicesHub.rows(devices: devices, currentDeviceID: accountStore.snapshot.device?.id, now: Date())
  }

  private var connectionCount: Int {
    DevicesHub.connectedCount(hubRows)
  }

  private var macBrowserGroups: [BrowserProfileGroup] {
    let currentMacBrowsers = store.browserConnectors
      .filter { connector in
        connector.support == .supportedToday
          && (connector.isConnected || connector.isInstalled || connector.isPrimary)
      }
      .map(browserGroup)

    return currentMacBrowsers + [safariGroup]
  }

  private var safariGroup: BrowserProfileGroup {
    BrowserProfileGroup(
      id: "safari",
      systemImage: "safari",
      title: "Safari",
      subtitle: "Mac Safari support is planned.",
      status: "Soon",
      statusTint: QGDesign.secondaryText,
      profiles: [],
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

  private func browserGroup(_ connector: BrowserConnectorSnapshot) -> BrowserProfileGroup {
    let profiles = browserProfiles(for: connector)
    let profileCount = max(profiles.count, connector.connectedProfileLabels.count)
    let profileNoun = profileCount == 1 ? "profile" : "profiles"
    let status = connector.isConnected ? (connector.isCurrent ? "Connected" : "Pending") : "Not connected"
    let statusTint = connector.isConnected
      ? (connector.isCurrent ? QGDesign.green : QGDesign.accent)
      : QGDesign.secondaryText
    let subtitle: String

    if profileCount > 0 {
      subtitle = "\(profileCount) \(profileNoun) connected on this Mac"
    } else if connector.isConnected {
      subtitle = "Current profile connected on this Mac"
    } else {
      subtitle = connector.state.detail
    }

    return BrowserProfileGroup(
      id: connector.id.rawValue,
      systemImage: browserSystemImage(connector.id),
      title: connector.displayName,
      subtitle: subtitle,
      status: status,
      statusTint: statusTint,
      profiles: profiles,
      isConnected: connector.isConnected
    )
  }

  private func browserProfiles(for connector: BrowserConnectorSnapshot) -> [BrowserProfileDisplayRow] {
    if !connector.connectedProfileLabels.isEmpty {
      return connector.connectedProfileLabels.map { label in
        BrowserProfileDisplayRow(
          id: "\(connector.id.rawValue)-\(label)",
          avatar: avatar(for: label),
          title: label,
          subtitle: "\(connector.displayName) profile",
          status: "Connected",
          statusTint: QGDesign.green,
          isConnected: true
        )
      }
    }

    guard connector.isConnected else {
      return []
    }

    let label = connector.selectedProfileLabel ?? "Current profile"
    return [
      BrowserProfileDisplayRow(
        id: "\(connector.id.rawValue)-current",
        avatar: avatar(for: label),
        title: label,
        subtitle: "\(connector.displayName) profile",
        status: connector.isCurrent ? "Connected" : "Pending",
        statusTint: connector.isCurrent ? QGDesign.green : QGDesign.accent,
        isConnected: true
      )
    ]
  }

  private func browserSystemImage(_ id: BrowserConnectorID) -> String {
    switch id {
    case .safari:
      return "safari"
    case .firefox:
      return "flame"
    case .chrome, .edge, .brave, .arc:
      return "globe"
    }
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

private struct HubDeviceRow: View {
  let row: DeviceHubRow

  var body: some View {
    HStack(spacing: 13) {
      Image(systemName: HubStatusStyle.systemImage(for: row.kind))
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(QGDesign.secondaryText)
        .frame(width: 38, height: 38)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 7) {
          Text(row.title)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(QGDesign.primaryText)
          if row.isCurrentDevice {
            Text("THIS ONE").font(.system(size: 9, weight: .bold)).foregroundStyle(QGDesign.secondaryText)
          }
        }
        if !row.profiles.isEmpty {
          Text("\(row.profiles.count) profile\(row.profiles.count == 1 ? "" : "s")")
            .font(.system(size: 12)).foregroundStyle(QGDesign.secondaryText)
        }
      }
      Spacer()
      HStack(spacing: 7) {
        Text(HubStatusStyle.label(for: row.status))
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(HubStatusStyle.color(for: row.status))
        Circle().fill(HubStatusStyle.color(for: row.status)).frame(width: 8, height: 8)
      }
    }
  }
}

enum HubStatusStyle {
  static func label(for status: ConnectionStatus) -> String {
    switch status {
    case .on: return "On"
    case .attention: return "Tap"
    case .off: return "Off"
    }
  }
  static func color(for status: ConnectionStatus) -> Color {
    switch status {
    case .on: return QGDesign.green
    case .attention: return QGDesign.orange
    case .off: return QGDesign.secondaryText
    }
  }
  static func systemImage(for kind: DeviceKind) -> String {
    switch kind {
    case .mac: return "desktopcomputer"
    case .iphone: return "iphone"
    case .browser: return "globe"       // TODO: real brand mark via brandAssetName
    case .other: return "laptopcomputer"
    }
  }
}

private struct PlatformSubsectionHeader: View {
  let systemImage: String
  let title: String
  let subtitle: String

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: systemImage)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(QGDesign.secondaryText)
        .frame(width: 24, height: 24)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(QGDesign.primaryText)
        Text(subtitle)
          .font(.system(size: 12))
          .foregroundStyle(QGDesign.secondaryText)
      }
      Spacer()
    }
  }
}

private struct BrowserProfileGroupRow: View {
  let group: BrowserProfileGroup

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 13) {
        Image(systemName: group.systemImage)
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(group.statusTint)
          .frame(width: 38, height: 38)
          .background(group.statusTint.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

        VStack(alignment: .leading, spacing: 3) {
          Text(group.title)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(group.isConnected ? QGDesign.primaryText : QGDesign.secondaryText)
          Text(group.subtitle)
            .font(.system(size: 12))
            .foregroundStyle(QGDesign.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()
        QGPill(text: group.status, tint: group.statusTint)
      }

      if !group.profiles.isEmpty {
        VStack(spacing: 0) {
          ForEach(Array(group.profiles.enumerated()), id: \.element.id) { index, row in
            if index > 0 {
              ProductDivider()
                .padding(.vertical, 10)
            }
            BrowserProfileRow(row: row)
          }
        }
        .padding(.leading, 50)
        .padding(.top, 12)
      }
    }
  }
}

private struct BrowserProfileRow: View {
  let row: BrowserProfileDisplayRow

  var body: some View {
    HStack(spacing: 11) {
      QGAvatar(text: row.avatar, size: 30)
      VStack(alignment: .leading, spacing: 3) {
        Text(row.title)
          .font(.system(size: 13, weight: .semibold))
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

private struct BrowserProfileGroup: Identifiable {
  let id: String
  let systemImage: String
  let title: String
  let subtitle: String
  let status: String
  let statusTint: Color
  let profiles: [BrowserProfileDisplayRow]
  let isConnected: Bool
}

private struct BrowserProfileDisplayRow: Identifiable {
  let id: String
  let avatar: String
  let title: String
  let subtitle: String
  let status: String
  let statusTint: Color
  let isConnected: Bool
}
