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
        title: "Devices & browser connections",
        subtitle: "Manage this Mac, your iPhone, and each connected Chrome profile in one place."
      )

      accountSummary

      VStack(alignment: .leading, spacing: 12) {
        QGSectionLabel(text: "Devices")
        QGCard {
          hubDeviceList
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
        if accountStore.connectionFailed {
          Button {
            refreshStatusLater()
          } label: {
            Label("Retry", systemImage: "arrow.clockwise")
          }
          .buttonStyle(QGPrimaryButtonStyle())
          .disabled(refreshInFlight || accountStore.isSyncing)
          .help("Retry account connection")
        }
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
