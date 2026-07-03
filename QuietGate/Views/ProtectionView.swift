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
        title: "Devices & browser profiles",
        subtitle: "Mac and iPhone are the devices. Browser profiles sit under the browser and device where they run."
      )

      accountSummary

      VStack(alignment: .leading, spacing: 12) {
        QGSectionLabel(text: "Mac")
        QGCard {
          macConnections
        }
      }

      VStack(alignment: .leading, spacing: 12) {
        QGSectionLabel(text: "iPhone")
        QGCard {
          iphoneConnections
        }
      }

      if !otherConnections.isEmpty {
        VStack(alignment: .leading, spacing: 12) {
          QGSectionLabel(text: "Other connections")
          QGCard {
            otherConnectionList
          }
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
  private var macConnections: some View {
    VStack(alignment: .leading, spacing: 0) {
      macDeviceList

      ProductDivider()
        .padding(.vertical, 16)

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

  @ViewBuilder
  private var macDeviceList: some View {
    let devices = macDevices
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
            title: macDeviceTitle(device),
            subtitle: macDeviceSubtitle(device),
            status: deviceStatus(device),
            tint: deviceTint(device)
          )
        }
      }
    }
  }

  @ViewBuilder
  private var iphoneConnections: some View {
    VStack(alignment: .leading, spacing: 0) {
      iphoneDeviceList

      ProductDivider()
        .padding(.vertical, 16)

      PlatformSubsectionHeader(
        systemImage: "safari",
        title: "iPhone browsers",
        subtitle: "iPhone browser coverage is synced by the iPhone app, not separate Mac profiles."
      )

      DeviceConnectionRow(
        systemImage: "safari",
        title: "Safari on iPhone",
        subtitle: iphoneBrowserSubtitle,
        status: iphoneBrowserStatus,
        tint: iphoneBrowserTint
      )
      .padding(.top, 12)
    }
  }

  @ViewBuilder
  private var iphoneDeviceList: some View {
    let devices = iphoneDevices
    if devices.isEmpty {
      DeviceConnectionRow(
        systemImage: "iphone",
        title: "iPhone",
        subtitle: accountStore.isSignedIn ? "Install QuietGate on iPhone to sync iOS blocking and usage." : "Sign in to connect an iPhone.",
        status: accountStore.isSignedIn ? "Not connected" : "Sign in",
        tint: QGDesign.secondaryText
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
            title: iphoneDeviceTitle(device),
            subtitle: deviceSubtitle(device),
            status: deviceStatus(device),
            tint: deviceTint(device)
          )
        }
      }
    }
  }

  @ViewBuilder
  private var otherConnectionList: some View {
    VStack(spacing: 0) {
      ForEach(Array(otherConnections.enumerated()), id: \.element.id) { index, device in
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

  private var connectButton: some View {
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
    .disabled(primaryConnectAction == nil || store.isWorking)
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

  private var macDevices: [TortoiseDevice] {
    accountDevices.filter(isMacDevice)
  }

  private var iphoneDevices: [TortoiseDevice] {
    accountDevices.filter(isIPhoneDevice)
  }

  private var otherConnections: [TortoiseDevice] {
    accountDevices.filter { device in
      !isMacDevice(device) && !isIPhoneDevice(device)
    }
  }

  private var macSubtitle: String {
    if appBlockingStore.enforcementEnabled {
      return "Tortoise running · app blocking active"
    }
    return "Tortoise running · app blocking paused"
  }

  private var connectionCount: Int {
    macDevices.count + iphoneDevices.count + otherConnections.count + macBrowserGroups.filter(\.isConnected).count
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

  private func deviceSystemImage(_ device: TortoiseDevice) -> String {
    switch normalizedPlatform(device) {
    case "ios":
      return "iphone"
    case "macos", "mac":
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
    let platform = platformLabel(device)
    return "\(name?.isEmpty == false ? name! : "Tortoise device") · \(platform)"
  }

  private func macDeviceTitle(_ device: TortoiseDevice) -> String {
    let name = device.name?.trimmingCharacters(in: .whitespacesAndNewlines)
    if accountStore.snapshot.device?.id == device.id {
      guard let name, !name.isEmpty else {
        return "This Mac"
      }
      return "This Mac · \(name)"
    }
    return "\(name?.isEmpty == false ? name! : "Mac") · Mac"
  }

  private func macDeviceSubtitle(_ device: TortoiseDevice) -> String {
    accountStore.snapshot.device?.id == device.id ? macSubtitle : deviceSubtitle(device)
  }

  private func iphoneDeviceTitle(_ device: TortoiseDevice) -> String {
    let name = device.name?.trimmingCharacters(in: .whitespacesAndNewlines)
    return "\(name?.isEmpty == false ? name! : "iPhone") · iOS"
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

  private var iphoneBrowserSubtitle: String {
    if iphoneDevices.isEmpty {
      return "Connect an iPhone to sync Safari and iOS web usage."
    }
    return "Safari tuning and iOS web usage sync through the iPhone app."
  }

  private var iphoneBrowserStatus: String {
    if iphoneDevices.isEmpty {
      return "Not connected"
    }
    return iphoneDevices.contains { deviceStatus($0) == "Connected" } ? "Connected" : "Stale"
  }

  private var iphoneBrowserTint: Color {
    iphoneBrowserStatus == "Connected" ? QGDesign.green : QGDesign.secondaryText
  }

  private func isMacDevice(_ device: TortoiseDevice) -> Bool {
    ["macos", "mac"].contains(normalizedPlatform(device))
  }

  private func isIPhoneDevice(_ device: TortoiseDevice) -> Bool {
    normalizedPlatform(device) == "ios"
  }

  private func normalizedPlatform(_ device: TortoiseDevice) -> String {
    (device.platform ?? "").lowercased()
  }

  private func platformLabel(_ device: TortoiseDevice) -> String {
    switch normalizedPlatform(device) {
    case "ios":
      return "iOS"
    case "macos", "mac":
      return "Mac"
    case "chrome_extension", "chrome":
      return "Chrome"
    case "firefox_extension", "firefox":
      return "Firefox"
    case "safari_extension", "safari":
      return "Safari"
    default:
      return device.platform?.isEmpty == false
        ? device.platform!.replacingOccurrences(of: "_", with: " ").capitalized
        : "Device"
    }
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
