import SwiftUI

struct ProtectionView: View {
  @Environment(\.scenePhase) private var scenePhase
  @EnvironmentObject private var store: ProtectionStore
  @EnvironmentObject private var appBlockingStore: AppBlockingStore
  @State private var refreshInFlight = false
  let openControl: () -> Void
  let openApps: () -> Void

  init(openControl: @escaping () -> Void = {}, openApps: @escaping () -> Void = {}) {
    self.openControl = openControl
    self.openApps = openApps
  }

  var body: some View {
    ProductPage(maxWidth: 820) {
      ProductHeader(
        title: "Setup",
        subtitle: subtitle,
        systemImage: store.blockingControlsReady ? "checkmark.shield.fill" : "shield"
      )

      if store.blockingControlsReady, store.browserBlockingConnected {
        SetupReadyPanel(
          openControl: openControl,
          openApps: openApps
        )
      } else if !store.blockingControlsReady {
        SetupCurrentStepPanel()
      }

      MacBlockingPanel(
        provider: macBlockingProvider,
        openApps: openApps
      )

      BrowserConnectorsPanel()

      BuiltInProtectionsPanel()

      if let setupMessage = store.setupMessage {
        Label(setupMessage, systemImage: "checkmark.circle")
          .font(.callout)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      }

      if let extensionBridgeMessage = store.extensionBridgeMessage {
        Label(extensionBridgeMessage, systemImage: "info.circle")
          .font(.callout)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      }

      if let browserProfileWatchMessage = store.browserProfileWatchMessage {
        Label(browserProfileWatchMessage, systemImage: "person.crop.circle.badge.clock")
          .font(.callout)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      }

      if let errorMessage = store.errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle")
          .foregroundStyle(.orange)
          .font(.callout)
          .textSelection(.enabled)
      }
    }
    .navigationTitle("Setup")
    .task {
      await refreshStatus()
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        refreshStatusLater()
      }
    }
  }

  private var subtitle: String {
    if !store.blockingControlsReady {
      return "QuietGate needs one browser connection before website controls can work."
    }
    let connector = store.primaryBrowserConnector
    if connector.isConnected {
      if let scopeText = connector.profileScopeText {
        return "\(scopeText) is connected. Use Home to choose blocks, timers, and schedules."
      }
      return "\(connector.displayName) is connected. Use Home to choose blocks, timers, and schedules."
    }
    return "Connect \(connector.displayName) so QuietGate can block websites and tune supported sites in \(connector.displayName)."
  }

  private var macBlockingProvider: BlockingProviderSnapshot {
    store
      .blockingProviders(includingLocalMac: appBlockingStore.providerSnapshot)
      .first { $0.id == .localMac } ?? appBlockingStore.providerSnapshot
  }

  @MainActor
  private func refreshStatus() async {
    guard !refreshInFlight else {
      return
    }

    refreshInFlight = true
    await store.refreshProtectionStatus()
    refreshInFlight = false
  }

  private func refreshStatusLater() {
    Task {
      await refreshStatus()
    }
  }
}

private struct SetupReadyPanel: View {
  @EnvironmentObject private var store: ProtectionStore
  let openControl: () -> Void
  let openApps: () -> Void

  var body: some View {
    ProductCallout(
      title: "QuietGate is ready",
      detail: detail,
      systemImage: "checkmark.circle.fill",
      tint: .green
    ) {
      ProductActionRow {
        Button(action: openControl) {
          Label("Open Home", systemImage: "house")
        }
        .buttonStyle(.borderedProminent)

        Button(action: openApps) {
          Label("Choose Apps", systemImage: "app.badge")
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var detail: String {
    let connector = store.primaryBrowserConnector
    if connector.isConnected {
      if let scopeText = connector.profileScopeText {
        return "\(scopeText) is connected. Use Home for website blocks, focus timers, and schedules."
      }
      return "\(connector.displayName) is connected. Use Home for website blocks, focus timers, and schedules."
    }
    return "Use Home to choose rules. Connect \(connector.displayName) below when you want those rules and site tuning to run in \(connector.displayName)."
  }
}

private struct MacBlockingPanel: View {
  let provider: BlockingProviderSnapshot
  let openApps: () -> Void

  var body: some View {
    ProductPanel(
      title: "This Mac",
      subtitle: "QuietGate can close selected Mac apps while it is running."
    ) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: statusIcon)
          .foregroundStyle(statusColor)
          .frame(width: 22)
          .padding(.top, 2)

        VStack(alignment: .leading, spacing: 8) {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(provider.title)
              .font(.headline)
            ProductStatusPill(text: statusLabel, tint: statusColor)
          }

          Text(provider.state.detail)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          ProductActionRow {
            Button(action: openApps) {
              Label("Choose Apps", systemImage: "app.badge")
            }
            .buttonStyle(.bordered)
          }
        }

        Spacer(minLength: 8)
      }
      .padding(.vertical, 12)
    }
  }

  private var statusLabel: String {
    switch provider.state {
    case .ready:
      return "Ready"
    case .disabled:
      return "Paused"
    case .actionNeeded:
      return "Needs attention"
    case .planned:
      return "Planned"
    }
  }

  private var statusIcon: String {
    switch provider.state {
    case .ready:
      return "checkmark.circle.fill"
    case .disabled:
      return "pause.circle"
    case .actionNeeded:
      return "exclamationmark.triangle.fill"
    case .planned:
      return "clock"
    }
  }

  private var statusColor: Color {
    switch provider.state {
    case .ready:
      return .green
    case .disabled:
      return .secondary
    case .actionNeeded:
      return .orange
    case .planned:
      return .secondary
    }
  }
}

private struct SetupCurrentStepPanel: View {
  var body: some View {
    BrowserFirstSetupPanel()
  }
}

private struct BrowserFirstSetupPanel: View {
  @EnvironmentObject private var store: ProtectionStore

  var body: some View {
    ProductPanel(title: title, subtitle: subtitle) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: iconName)
          .foregroundStyle(tint)
          .frame(width: 22)
          .padding(.top, 2)

        VStack(alignment: .leading, spacing: 8) {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(stepTitle)
              .font(.headline)
            ProductStatusPill(text: statusText, tint: tint)
          }

          Text(connector.state.detail)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          BrowserProfileStatusStack(connector: connector)

          if connector.nextAction != nil || addProfileAction != nil {
            ProductActionRow {
              if let action = connector.nextAction {
                Button {
                  store.performReadinessAction(action)
                } label: {
                  Label(setupActionTitle(for: action), systemImage: action.systemImage)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isWorking)
              }

              if let addProfileAction {
                if connector.nextAction == nil {
                  Button {
                    store.performReadinessAction(addProfileAction)
                  } label: {
                    Label(addProfileTitle, systemImage: "person.crop.circle.badge.plus")
                  }
                  .buttonStyle(.borderedProminent)
                  .disabled(store.isWorking)
                  .help("Open or switch to the browser profile you want QuietGate to use, then connect it.")
                } else {
                  Button {
                    store.performReadinessAction(addProfileAction)
                  } label: {
                    Label(addProfileTitle, systemImage: "person.crop.circle.badge.plus")
                  }
                  .buttonStyle(.bordered)
                  .disabled(store.isWorking)
                  .help("Open or switch to the browser profile you want QuietGate to use, then connect it.")
                }
              }
            }
          }
        }

        Spacer(minLength: 8)
      }
    }
  }

  private var connector: BrowserConnectorSnapshot {
    store.primaryBrowserConnector
  }

  private var title: String {
    switch connector.state {
    case .connected:
      return "\(connector.displayName) connected"
    case .connectedPending:
      return "Update \(connector.displayName)"
    case .actionNeeded:
      return connector.isInstalled ? "Connect \(connector.displayName)" : "Install \(connector.displayName)"
    case .comingSoon:
      return "\(connector.displayName) support"
    case .error:
      return "\(connector.displayName) needs attention"
    }
  }

  private var subtitle: String {
    "QuietGate needs one working browser connection before Home unlocks."
  }

  private var stepTitle: String {
    switch connector.state {
    case .connected:
      return connector.profileScopeText ?? "\(connector.displayName) is connected"
    case .connectedPending:
      return connector.profileScopeText ?? "\(connector.displayName) connection needs refresh"
    case .actionNeeded:
      if connector.isInstalled, let profileScopeText = connector.profileScopeText {
        return "\(profileScopeText) needs setup"
      }
      return connector.isInstalled ? "\(connector.displayName) needs a connection" : "\(connector.displayName) is not installed"
    case .comingSoon:
      return connector.isInstalled ? "\(connector.displayName) is installed" : "\(connector.displayName) is not available yet"
    case .error:
      return "\(connector.displayName) connection has an issue"
    }
  }

  private var statusText: String {
    switch connector.state {
    case .connected:
      return "Ready"
    case .connectedPending:
      return "Refresh"
    case .actionNeeded:
      return connector.isInstalled ? "Needed" : "Install"
    case .comingSoon:
      return connector.isInstalled ? "Installed" : "Planned"
    case .error:
      return "Issue"
    }
  }

  private var iconName: String {
    switch connector.state {
    case .connected:
      return "checkmark.circle.fill"
    case .connectedPending:
      return "clock.arrow.circlepath"
    case .actionNeeded:
      return connector.isInstalled ? "play.rectangle" : "arrow.down.circle"
    case .comingSoon:
      return "clock"
    case .error:
      return "exclamationmark.triangle.fill"
    }
  }

  private var tint: Color {
    switch connector.state {
    case .connected:
      return .green
    case .connectedPending:
      return .blue
    case .actionNeeded:
      return .blue
    case .comingSoon:
      return .secondary
    case .error:
      return .orange
    }
  }

  private var addProfileAction: ReadinessAction? {
    connector.profileConnectionAction(excluding: connector.nextAction)
  }

  private var addProfileTitle: String {
    connector.isConnected || !connector.connectedProfileLabels.isEmpty
      ? "Connect Another Profile"
      : "Connect Current Profile"
  }
}

private struct BrowserConnectorsPanel: View {
  @EnvironmentObject private var store: ProtectionStore

  var body: some View {
    ProductPanel(
      title: "Browser connections",
      subtitle: "Connect one supported browser. Chrome, Edge, Brave, Arc, and Firefox work today; Safari is planned."
    ) {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(store.browserConnectors.enumerated()), id: \.element.id) { index, connector in
          if index > 0 {
            ProductDivider()
          }
          BrowserConnectorRow(connector: connector, run: run)
        }
      }
    }
  }

  private func run(_ action: ReadinessAction) {
    store.performReadinessAction(action)
  }
}

private struct BrowserConnectorRow: View {
  let connector: BrowserConnectorSnapshot
  let run: (ReadinessAction) -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: iconName)
        .foregroundStyle(statusColor)
        .frame(width: 22)
        .padding(.top, 2)

      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(title)
            .font(.headline)
          ProductStatusPill(text: statusLabel, tint: statusColor)
        }

        Text(connector.state.detail)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        BrowserProfileStatusStack(connector: connector)

        if connector.nextAction != nil || addProfileAction != nil {
          ProductActionRow {
            if let action = connector.nextAction {
              Button {
                run(action)
              } label: {
                Label(setupActionTitle(for: action), systemImage: action.systemImage)
              }
              .buttonStyle(.borderedProminent)
            }

            if let addProfileAction {
              if connector.nextAction == nil {
                Button {
                  run(addProfileAction)
                } label: {
                  Label(addProfileTitle, systemImage: "person.crop.circle.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .help("Open or switch to the browser profile you want QuietGate to use, then connect it.")
              } else {
                Button {
                  run(addProfileAction)
                } label: {
                  Label(addProfileTitle, systemImage: "person.crop.circle.badge.plus")
                }
                .buttonStyle(.bordered)
                .help("Open or switch to the browser profile you want QuietGate to use, then connect it.")
              }
            }
          }
        }
      }

      Spacer(minLength: 8)
    }
    .padding(.vertical, 12)
  }

  private var title: String {
    if connector.isConnected {
      if let profileScopeText = connector.profileScopeText {
        return profileScopeText
      }
      return "\(connector.displayName) is connected"
    }
    if connector.support == .supportedToday,
       connector.isInstalled,
       let profileScopeText = connector.profileScopeText {
      return profileScopeText
    }
    if connector.support == .supportedToday, !connector.isInstalled {
      return "\(connector.displayName) is not installed"
    }
    if connector.support == .planned, connector.isInstalled {
      return "\(connector.displayName) is installed"
    }
    return connector.displayName
  }

  private var iconName: String {
    switch connector.state {
    case .connected:
      return "checkmark.circle.fill"
    case .connectedPending:
      return "clock.arrow.circlepath"
    case .actionNeeded:
      return "play.rectangle"
    case .comingSoon:
      return "clock"
    case .error:
      return "exclamationmark.triangle.fill"
    }
  }

  private var statusLabel: String {
    switch connector.state {
    case .connected:
      return "Ready"
    case .connectedPending:
      return "Pending"
    case .actionNeeded:
      if connector.id == .chrome, !connector.isInstalled {
        return "Install"
      }
      return connector.isPrimary ? "Needed" : "Connect"
    case .comingSoon:
      return connector.isInstalled ? "Installed" : "Coming soon"
    case .error:
      return "Needs attention"
    }
  }

  private var statusColor: Color {
    switch connector.state {
    case .connected:
      return .green
    case .connectedPending:
      return .blue
    case .actionNeeded:
      return connector.isPrimary ? .blue : .orange
    case .comingSoon:
      return .secondary
    case .error:
      return .orange
    }
  }

  private var addProfileAction: ReadinessAction? {
    connector.profileConnectionAction(excluding: connector.nextAction)
  }

  private var addProfileTitle: String {
    connector.isConnected || !connector.connectedProfileLabels.isEmpty
      ? "Connect Another Profile"
      : "Connect Current Profile"
  }
}

private struct BrowserProfileStatusStack: View {
  let connector: BrowserConnectorSnapshot

  var body: some View {
    if !rows.isEmpty {
      VStack(alignment: .leading, spacing: 4) {
        ForEach(rows, id: \.text) { row in
          Label(row.text, systemImage: row.systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(.top, 1)
    }
  }

  private var rows: [ProfileStatusRow] {
    var rows: [ProfileStatusRow] = []
    if let selectedProfileLabel = connector.selectedProfileLabel {
      rows.append(ProfileStatusRow(
        text: "Current profile: \(selectedProfileLabel)",
        systemImage: "person.crop.circle"
      ))
    }
    if !connector.connectedProfileLabels.isEmpty {
      rows.append(ProfileStatusRow(
        text: "QuietGate enabled in: \(formattedList(connector.connectedProfileLabels))",
        systemImage: "puzzlepiece.extension"
      ))
    }
    return rows
  }

  private func formattedList(_ values: [String]) -> String {
    switch values.count {
    case 0:
      return ""
    case 1:
      return values[0]
    case 2:
      return "\(values[0]) and \(values[1])"
    default:
      return values.dropLast().joined(separator: ", ") + ", and " + values.last!
    }
  }

  private struct ProfileStatusRow {
    let text: String
    let systemImage: String
  }
}

private struct BuiltInProtectionsPanel: View {
  @EnvironmentObject private var store: ProtectionStore

  var body: some View {
    ProductPanel(
      title: "Built-in protections",
      subtitle: "QuietGate checks platform controls separately from app updates and browser tuner freshness. These controls add coverage but do not replace QuietGate tuning."
    ) {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(store.builtInProtectionsSnapshot.items.enumerated()), id: \.element.id) {
          index,
          item in
          if index > 0 {
            ProductDivider()
          }
          BuiltInProtectionRow(item: item) {
            store.openBuiltInProtectionAction(item.actionURLString)
          }
        }
      }
    }
  }
}

private struct BuiltInProtectionRow: View {
  let item: PlatformControlItem
  let runAction: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: iconName)
        .foregroundStyle(tint)
        .frame(width: 22)
        .padding(.top, 2)

      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(item.title)
            .font(.headline)
          ProductStatusPill(text: statusLabel, tint: tint)
        }

        Text(item.detail)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        if let actionTitle = item.actionTitle {
          ProductActionRow {
            Button(action: runAction) {
              Label(actionTitle, systemImage: actionIconName)
            }
            .buttonStyle(.bordered)
          }
        }
      }

      Spacer(minLength: 8)
    }
    .padding(.vertical, 12)
  }

  private var statusLabel: String {
    switch item.state {
    case .enabled:
      return "On"
    case .needsAction:
      return "Needs setup"
    case .checkInBrowser:
      return "Open to check"
    case .manualCheck:
      return "Manual check"
    case .unavailable:
      return "Unavailable"
    case .unknown:
      return "Unknown"
    }
  }

  private var iconName: String {
    switch item.state {
    case .enabled:
      return "checkmark.circle.fill"
    case .needsAction:
      return "exclamationmark.triangle.fill"
    case .checkInBrowser:
      return "safari"
    case .manualCheck:
      return "gearshape"
    case .unavailable:
      return "minus.circle"
    case .unknown:
      return "questionmark.circle"
    }
  }

  private var actionIconName: String {
    switch item.id {
    case .appleScreenTimeWeb, .appleSensitiveContentWarning:
      return "apple.logo"
    case .cloudflareFamilyDNS, .cleanBrowsingFamilyDNS:
      return "network"
    case .googleSafeSearch, .chromeGoogleSafeSearchPolicy, .chromeYouTubeRestrictedMode:
      return "magnifyingglass"
    case .xSensitiveMedia, .xSensitiveSearch:
      return "slider.horizontal.3"
    case .redditMatureContent, .redditBlurMatureMedia:
      return "gearshape"
    case .quietGateTuners:
      return "checkmark.shield"
    }
  }

  private var tint: Color {
    switch item.state {
    case .enabled:
      return .green
    case .needsAction:
      return .orange
    case .checkInBrowser:
      return .blue
    case .manualCheck:
      return .secondary
    case .unavailable:
      return .secondary
    case .unknown:
      return .orange
    }
  }
}

private extension BrowserConnectorSnapshot {
  func profileConnectionAction(excluding currentAction: ReadinessAction?) -> ReadinessAction? {
    guard support == .supportedToday, isInstalled else {
      return nil
    }

    let action: ReadinessAction = id == .chrome
      ? .launchChromeTunerSession
      : .launchBrowserTunerSession(id)
    return action == currentAction ? nil : action
  }
}

private func setupActionTitle(for action: ReadinessAction) -> String {
  switch action {
  case .allowSavedProviderCredentialAccess:
    return "Allow Access"
  case .refreshProtectionStatus, .checkThisMac, .checkLegacyMacConnection:
    return "Update Status"
  case .openLegacyProviderAccount:
    return "Open Setup"
  case .openLegacyMacPermissionSetup:
    return "Open Settings"
  case .createLegacyMacPermissionProfile:
    return "Prepare Settings"
  case .openSystemProfiles:
    return "Open System Settings"
  case .installLocalBlockerBackup:
    return "Set Up Backup"
  case .launchChromeTunerSession:
    return "Connect Chrome"
  case .openChromeDownload:
    return "Get Chrome"
  case .showChromeExtensionFolder:
    return "Load Browser"
  case .installChromeSync:
    return "Update Chrome"
  case .applyBrowserChanges:
    return "Refresh Browser"
  case .openBrowserExtensionsPage:
    return "Open Extensions"
  case .launchBrowserTunerSession(let browser):
    return "Connect \(browser.displayName)"
  case .openBrowserDownload(let browser):
    return "Get \(browser.displayName)"
  case .installBrowserSync(let browser):
    return "Update \(browser.displayName)"
  }
}
