import AppKit
import ClerkKit
import ClerkKitUI
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
  case devices
  case tuning
  case blocking
  case usage

  var id: String { rawValue }

  var title: String {
    switch self {
    case .devices: return "Devices"
    case .tuning: return "Tune"
    case .blocking: return "Block"
    case .usage: return "Usage"
    }
  }

  var systemImage: String {
    switch self {
    case .devices: return "macbook.and.iphone"
    case .tuning: return "slider.horizontal.3"
    case .blocking: return "shield"
    case .usage: return "chart.bar"
    }
  }
}

struct ContentView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.scenePhase) private var scenePhase
  @EnvironmentObject private var store: ProtectionStore
  @EnvironmentObject private var appBlockingStore: AppBlockingStore
  @EnvironmentObject private var accountStore: MacAccountStore
  @EnvironmentObject private var appUpdater: AppUpdateCoordinator
  @SceneStorage("quietgate.selectedSection") private var selectedSectionID =
    AppSection.devices.rawValue
  @State private var authViewIsPresented = false

  private var selectedSection: Binding<AppSection> {
    Binding {
      AppSection(rawValue: selectedSectionID) ?? .devices
    } set: { newValue in
      selectedSectionID = newValue.rawValue
    }
  }

  var body: some View {
    Group {
      if clerk.session == nil {
        MacSignedOutLanding(syncMessage: accountStore.syncMessage) {
          authViewIsPresented = true
        }
      } else {
        appShell
      }
    }
    .onOpenURL { url in
      Task {
        try? await clerk.handle(url)
      }
    }
    .task(id: clerk.session?.id) {
      await accountStore.refresh(
        using: clerk,
        protectionStore: store,
        appBlockingStore: appBlockingStore
      )
    }
    .task {
      store.refreshAppUpdateStatus()
      appUpdater.checkForUpdatesInBackground()
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      // SwiftUI's scene phase does not reliably cycle when a macOS user moves
      // between apps, so listen to AppKit for update checks on every return.
      store.refreshAppUpdateStatus()
      appUpdater.checkForUpdatesInBackground()
    }
    .task {
      for await event in clerk.auth.events {
        switch event {
        case .signInNeedsContinuation, .signUpNeedsContinuation:
          authViewIsPresented = true
        default:
          break
        }
      }
    }
    .onChange(of: clerk.session?.tasks, initial: true) { _, newValue in
      if newValue?.isEmpty == false {
        authViewIsPresented = true
      }
    }
    .sheet(isPresented: $authViewIsPresented) {
      AuthView(mode: .signInOrUp)
        .frame(width: 560, height: 620)
    }
  }

  private var appShell: some View {
    VStack(spacing: 0) {
      QGWindowBar(modeText: modeText)

      HStack(spacing: 0) {
        QGSidebar(selection: selectedSection)

        detailView
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .background(QGDesign.background)
      }
    }
    .frame(minWidth: 980, minHeight: 700)
    .background(QGDesign.background)
    .foregroundStyle(QGDesign.primaryText)
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        store.refreshAppUpdateStatus()
        appUpdater.checkForUpdatesInBackground()
        Task {
          await accountStore.refresh(
            using: clerk,
            protectionStore: store,
            appBlockingStore: appBlockingStore
          )
        }
      }
    }
  }

  @ViewBuilder
  private var detailView: some View {
    switch selectedSection.wrappedValue {
    case .devices:
      ProtectionView()
    case .tuning:
      TuningView()
    case .blocking:
      BlockingView()
    case .usage:
      QuietGateUsageView()
    }
  }

  private var modeText: String {
    switch store.accessMode {
    case .open:
      return "Open mode"
    case .focus:
      return "Focus mode"
    case .strict:
      return store.timedSessionLockedActive ? "Locked strict" : "Strict mode"
    }
  }
}

private struct MacSignedOutLanding: View {
  let syncMessage: String
  let onSignIn: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      QGWindowBar(modeText: "Account setup")

      VStack(spacing: 28) {
        Spacer(minLength: 30)

        VStack(spacing: 16) {
          Image(systemName: "shield.checkered")
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 64, height: 64)
            .background(
              LinearGradient(
                colors: [QGDesign.accent, QGDesign.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )

          VStack(spacing: 8) {
            Text("Start with your Tortoise account")
              .font(.system(size: 34, weight: .bold))
              .foregroundStyle(QGDesign.primaryText)
            Text("Use one account to sync your Mac, iPhone, browser tuning, and blocking rules.")
              .font(.system(size: 15))
              .foregroundStyle(QGDesign.secondaryText)
              .multilineTextAlignment(.center)
              .frame(maxWidth: 460)
          }
        }

        QGCard {
          VStack(alignment: .leading, spacing: 14) {
            setupRow(icon: "person.crop.circle.badge.checkmark", title: "Create or use your account", detail: "Your settings follow you across devices.")
            ProductDivider()
            setupRow(icon: "macbook.and.iphone", title: "Register this Mac", detail: "Tortoise will show this Mac as connected in the dashboard.")
            ProductDivider()
            setupRow(icon: "slider.horizontal.3", title: "Sync tuning", detail: "YouTube, Reddit, Instagram, X, blocking, and app rules stay aligned.")
          }
        }
        .frame(maxWidth: 520)

        Button(action: onSignIn) {
          Text("Sign in or create account")
            .frame(minWidth: 230)
        }
        .buttonStyle(QGPrimaryButtonStyle())

        Text(syncMessage)
          .font(.system(size: 12))
          .foregroundStyle(QGDesign.tertiaryText)

        Spacer(minLength: 30)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(40)
      .background(QGDesign.background)
    }
    .frame(minWidth: 780, minHeight: 620)
    .background(QGDesign.background)
    .foregroundStyle(QGDesign.primaryText)
  }

  private func setupRow(icon: String, title: String, detail: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(QGDesign.accent)
        .frame(width: 34, height: 34)
        .background(QGDesign.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(QGDesign.primaryText)
        Text(detail)
          .font(.system(size: 12))
          .foregroundStyle(QGDesign.secondaryText)
      }
      Spacer()
    }
  }
}

/// The persistent window bar: app name, the running version (always visible —
/// "what version am I on?" should never require a hover), the mode pill, and
/// the update affordance the moment a newer Tortoise exists anywhere.
private struct QGWindowBar: View {
  @EnvironmentObject private var store: ProtectionStore
  @EnvironmentObject private var appUpdater: AppUpdateCoordinator
  let modeText: String

  var body: some View {
    ZStack {
      HStack(spacing: 8) {
        Text("Tortoise")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(QGDesign.secondaryText)
        if let version = store.currentAppVersion {
          Text("v\(version.displayText)")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(QGDesign.tertiaryText)
            .help(store.appUpdateDetail)
        }
      }

      HStack {
        Spacer()

        if store.appUpdateAvailable {
          Button {
            store.relaunchToInstalledUpdate()
          } label: {
            Label("Update ready — relaunch", systemImage: "arrow.triangle.2.circlepath")
              .font(.system(size: 12, weight: .bold))
          }
          .buttonStyle(.plain)
          .foregroundStyle(QGDesign.green)
          .padding(.horizontal, 11)
          .padding(.vertical, 6)
          .background(QGDesign.green.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
          .disabled(store.isWorking)
          .help(store.appUpdateDetail)
          .padding(.trailing, 10)
        } else if store.remoteAppRelease != nil {
          Button {
            appUpdater.installLatestUpdate()
          } label: {
            Label(appUpdater.actionTitle, systemImage: appUpdater.actionSystemImage)
              .font(.system(size: 12, weight: .bold))
          }
          .buttonStyle(.plain)
          .foregroundStyle(QGDesign.green)
          .padding(.horizontal, 11)
          .padding(.vertical, 6)
          .background(QGDesign.green.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
          .disabled(appUpdater.actionDisabled)
          .help(appUpdater.detailText)
          .padding(.trailing, 10)
        }

        HStack(spacing: 7) {
          Circle()
            .fill(QGDesign.accent)
            .frame(width: 7, height: 7)
          Text(modeText)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(QGDesign.primaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(QGDesign.accent.opacity(0.20), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.trailing, 16)
      }
    }
    .frame(height: 42)
    .background(QGDesign.sidebar)
    .overlay(alignment: .bottom) {
      ProductDivider()
    }
  }
}

private struct QGSidebar: View {
  @Environment(Clerk.self) private var clerk
  @EnvironmentObject private var store: ProtectionStore
  @EnvironmentObject private var appBlockingStore: AppBlockingStore
  @EnvironmentObject private var accountStore: MacAccountStore
  @Binding var selection: AppSection

  var body: some View {
    VStack(alignment: .leading, spacing: 26) {
      HStack(spacing: 12) {
        Image(systemName: "shield.checkered")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 32, height: 32)
          .background(
            LinearGradient(
              colors: [QGDesign.accent, QGDesign.purple],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
          )

        Text("Tortoise")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(QGDesign.primaryText)
      }
      .padding(.top, 22)
      .padding(.horizontal, 22)

      VStack(spacing: 6) {
        ForEach(AppSection.allCases) { section in
          Button {
            selection = section
          } label: {
            HStack(spacing: 12) {
              Image(systemName: section.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 18)
              Text(section.title)
                .font(.system(size: 14, weight: .bold))
              Spacer()
            }
            .foregroundStyle(selection == section ? QGDesign.primaryText : QGDesign.secondaryText)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(
              selection == section ? Color.white.opacity(0.13) : Color.clear,
              in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(alignment: .leading) {
              if selection == section {
                Rectangle()
                  .fill(QGDesign.accent)
                  .frame(width: 3, height: 18)
                  .offset(x: -14)
              }
            }
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 16)

      Spacer()

      HStack(spacing: 11) {
        QGAvatar(text: accountStore.accountInitials, size: 31)
        VStack(alignment: .leading, spacing: 2) {
          Text(accountStore.accountDisplayName)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(QGDesign.primaryText)
            .lineLimit(1)
          Text(accountStore.accountFooterText)
            .font(.system(size: 12))
            .foregroundStyle(QGDesign.secondaryText)
            .lineLimit(1)
        }
        Spacer()
        Button {
          Task {
            try? await clerk.auth.signOut()
            await accountStore.refresh(
              using: clerk,
              protectionStore: store,
              appBlockingStore: appBlockingStore
            )
          }
        } label: {
          Image(systemName: "rectangle.portrait.and.arrow.right")
            .font(.system(size: 12, weight: .semibold))
        }
        .buttonStyle(.plain)
        .help("Sign out")
      }
      .padding(10)
      .background(QGDesign.elevatedPanel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      .padding(.horizontal, 14)
      .padding(.bottom, 16)
    }
    .frame(width: 232)
    .background(QGDesign.sidebar)
    .overlay(alignment: .trailing) {
      Rectangle()
        .fill(QGDesign.hairline)
        .frame(width: 1)
    }
  }
}

struct QuietGateUsageView: View {
  @Environment(Clerk.self) private var clerk
  @EnvironmentObject private var store: ProtectionStore
  @EnvironmentObject private var accountStore: MacAccountStore
  @State private var selectedTab = QGUsageTab.all

  var body: some View {
    QGPage(maxWidth: 820) {
      QGScreenHeader(
        title: "Usage",
        subtitle: "Today across every connected browser profile and device."
      )

      usageTabs
      heroCard

      if selectedTab == .all, !display.apps.isEmpty {
        byAppCard
      }

      if !display.accounts.isEmpty {
        accountsCard
      }
    }
    .task {
      while !Task.isCancelled {
        await accountStore.refreshUsage(using: clerk)
        try? await Task.sleep(nanoseconds: 60_000_000_000)
      }
    }
  }

  private var usageTabs: some View {
    HStack(spacing: 8) {
      ForEach(QGUsageTab.allCases) { tab in
        Button {
          selectedTab = tab
        } label: {
          Text(tab.title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(selectedTab == tab ? QGDesign.primaryText : QGDesign.secondaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
              selectedTab == tab ? QGDesign.accent.opacity(0.24) : QGDesign.elevatedPanel,
              in: Capsule()
            )
            .overlay {
              Capsule()
                .strokeBorder(selectedTab == tab ? QGDesign.accent : QGDesign.hairline)
            }
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var heroCard: some View {
    QGCard {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 10) {
          Text(display.hero)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(QGDesign.tertiaryText)
          Text(display.total)
            .font(.system(size: 54, weight: .bold))
            .foregroundStyle(QGDesign.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
          Text(display.subtitle)
            .font(.system(size: 14))
            .foregroundStyle(QGDesign.secondaryText)
        }

        Spacer(minLength: 24)

        VStack(alignment: .trailing, spacing: 14) {
          QGPill(text: display.activity, tint: QGDesign.secondaryText)
          HStack(spacing: 12) {
            UsageMetric(value: display.web, title: "Web")
            UsageMetric(value: display.ios, title: "iOS")
          }
        }
      }
    }
  }

  private var byAppCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      QGSectionLabel(text: "By app")
      QGCard {
        VStack(spacing: 14) {
          ForEach(display.apps) { app in
            UsageAppRow(app: app)
          }
        }
      }
    }
  }

  private var accountsCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      QGSectionLabel(text: "Accounts")
      QGCard {
        VStack(spacing: 0) {
          ForEach(Array(display.accounts.enumerated()), id: \.element.id) { index, account in
            if index > 0 {
              ProductDivider()
                .padding(.vertical, 12)
            }
            UsageAccountRow(account: account)
          }
        }
      }
    }
  }

  private var display: QGUsageDisplay {
    if let summary = latestSiteSummary {
      return QGUsageDisplay(summary: summary, tab: selectedTab)
    }
    return QGUsageDisplay.empty(tab: selectedTab)
  }

  private var helperSnapshots: [ChromeHelperSnapshot] {
    let connectedSnapshots = store.connectedBrowserConnectors.compactMap {
      store.browserHelperSnapshots[$0.id]
    }
    return connectedSnapshots.isEmpty
      ? [store.browserHelperSnapshots[store.primaryBrowserConnector.id]].compactMap { $0 }
      : connectedSnapshots
  }

  private var latestSiteSummary: SiteUsageSummarySnapshot? {
    SiteUsageSummaryMerge.today(
      local: helperSnapshots.compactMap(\.siteUsageSummary),
      cloud: accountStore.snapshot.siteUsageSummary,
      today: SiteUsageSummaryMerge.localDateKey()
    )
  }
}

private struct UsageMetric: View {
  let value: String
  let title: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value)
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(QGDesign.primaryText)
      Text(title)
        .font(.system(size: 12))
        .foregroundStyle(QGDesign.tertiaryText)
    }
    .frame(width: 110, alignment: .leading)
    .padding(12)
    .background(QGDesign.elevatedPanel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
  }
}

private struct UsageAppRow: View {
  let app: QGUsageApp

  var body: some View {
    HStack(spacing: 12) {
      QGAvatar(text: app.letter, size: 34, background: app.color, foreground: app.foreground, cornerRadius: 8)
      VStack(alignment: .leading, spacing: 7) {
        HStack {
          Text(app.name)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(QGDesign.primaryText)
          Spacer()
          Text(app.time)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(QGDesign.secondaryText)
        }
        GeometryReader { geometry in
          ZStack(alignment: .leading) {
            Capsule()
              .fill(Color.white.opacity(0.10))
            Capsule()
              .fill(app.color)
              .frame(width: geometry.size.width * CGFloat(app.percent) / 100)
          }
        }
        .frame(height: 5)
      }
    }
  }
}

private struct UsageAccountRow: View {
  let account: QGUsageAccount

  var body: some View {
    HStack(spacing: 12) {
      QGAvatar(text: account.avatar, size: 34)
      VStack(alignment: .leading, spacing: 3) {
        Text(account.name)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(QGDesign.primaryText)
        Text(account.subtitle)
          .font(.system(size: 12))
          .foregroundStyle(QGDesign.secondaryText)
      }
      Spacer(minLength: 14)
      VStack(alignment: .trailing, spacing: 3) {
        Text(account.time)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(QGDesign.primaryText)
        Text(account.activity)
          .font(.system(size: 12))
          .foregroundStyle(QGDesign.secondaryText)
      }
    }
  }
}

private enum QGUsageTab: String, CaseIterable, Identifiable {
  case all
  case youtube
  case x
  case instagram
  case reddit
  case tiktok

  var id: String { rawValue }

  var title: String {
    switch self {
    case .all: return "All"
    case .youtube: return "YouTube"
    case .x: return "X"
    case .instagram: return "Instagram"
    case .reddit: return "Reddit"
    case .tiktok: return "TikTok"
    }
  }
}

private struct QGUsageDisplay {
  let hero: String
  let total: String
  let subtitle: String
  let activity: String
  let web: String
  let ios: String
  let apps: [QGUsageApp]
  let accounts: [QGUsageAccount]

  init(summary: SiteUsageSummarySnapshot, tab: QGUsageTab, now: Date = Date()) {
    let site = tab == .all ? nil : summary.sites.first { $0.siteID == tab.rawValue }
    let entries = site?.entries ?? summary.entries ?? summary.sites.flatMap(\.entries)
    let totalSeconds = site?.totalSeconds ?? summary.totalSeconds
    let webSeconds = entries.filter { !Self.isIOSEntry($0) }.reduce(0) { $0 + ($1.totalSeconds ?? 0) }
    let iosSeconds = entries.filter(Self.isIOSEntry).reduce(0) { $0 + ($1.totalSeconds ?? 0) }
    let updatedAt = site?.lastUpdatedAt ?? summary.lastUpdatedAt

    hero = tab == .all ? "Today" : "\(tab.title) today"
    total = Self.duration(totalSeconds)
    subtitle = Self.freshness(updatedAt, now: now).map { "Updated \($0)" } ?? "Today"
    activity = tab == .youtube ? "\(site?.activityCount ?? site?.videoCount ?? 0) videos" : "\(Set(entries.map(Self.accountKey)).count) accounts"
    web = webSeconds > 0 ? Self.duration(webSeconds) : "No data"
    ios = iosSeconds > 0 ? Self.duration(iosSeconds) : "No data"
    apps = tab == .all ? Self.apps(from: summary) : []
    accounts = entries.map(Self.account(from:))
  }

  static func empty(tab: QGUsageTab) -> QGUsageDisplay {
    QGUsageDisplay(
      hero: tab == .all ? "Today" : "\(tab.title) today",
      total: "0m",
      subtitle: "No usage recorded yet today",
      activity: tab == .youtube ? "0 videos" : "0 accounts",
      web: "No data",
      ios: "No data",
      apps: [],
      accounts: []
    )
  }

  private init(
    hero: String,
    total: String,
    subtitle: String,
    activity: String,
    web: String,
    ios: String,
    apps: [QGUsageApp],
    accounts: [QGUsageAccount]
  ) {
    self.hero = hero
    self.total = total
    self.subtitle = subtitle
    self.activity = activity
    self.web = web
    self.ios = ios
    self.apps = apps
    self.accounts = accounts
  }


  private static func apps(from summary: SiteUsageSummarySnapshot) -> [QGUsageApp] {
    let total = max(summary.totalSeconds, 1)
    return summary.sites.prefix(6).map { site in
      let percent = Int((Double(site.totalSeconds) / Double(total) * 100).rounded())
      let theme = QGUsageApp.theme(for: site.siteID)
      return QGUsageApp(
        letter: theme.letter,
        name: site.displayTitle,
        time: duration(site.totalSeconds),
        percent: max(percent, 3),
        color: theme.color,
        foreground: theme.foreground
      )
    }
  }

  private static func account(from entry: SiteUsageSourceSnapshot) -> QGUsageAccount {
    let label = entry.label ?? entry.profileName ?? entry.browserName ?? "Browser profile"
    let email = Self.email(in: label) ?? Self.email(in: entry.profileName ?? "") ?? ""
    let name = entry.profileName?.isEmpty == false ? entry.profileName! : label.components(separatedBy: " · ").first ?? label
    let avatar = String(name.prefix(2)).uppercased()
    return QGUsageAccount(
      avatar: avatar,
      name: name,
      subtitle: email.isEmpty ? label : "\(email) · \(entry.browserName ?? "Browser")",
      time: duration(entry.totalSeconds ?? 0),
      activity: entry.activityCount.map { "\($0) events" } ?? ""
    )
  }

  private static func accountKey(_ entry: SiteUsageSourceSnapshot) -> String {
    email(in: entry.label ?? "") ?? email(in: entry.profileName ?? "") ?? entry.id
  }

  private static func isIOSEntry(_ entry: SiteUsageSourceSnapshot) -> Bool {
    [entry.sourceType, entry.browserName, entry.deviceName, entry.profileName, entry.label]
      .compactMap { $0 }
      .joined(separator: " ")
      .range(of: #"ios|iphone|ipad"#, options: [.regularExpression, .caseInsensitive]) != nil
  }

  private static func duration(_ seconds: Int) -> String {
    let totalMinutes = max(seconds, 0) / 60
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours > 0 {
      return "\(hours)h \(minutes)m"
    }
    return "\(minutes)m"
  }

  private static func freshness(_ updatedAt: Date?, now: Date) -> String? {
    guard let updatedAt else {
      return nil
    }
    let seconds = Int(now.timeIntervalSince(updatedAt))
    if seconds < 90 {
      return "just now"
    }
    let minutes = seconds / 60
    if minutes < 60 {
      return "\(minutes)m ago"
    }
    return "\(minutes / 60)h ago"
  }

  private static func email(in value: String) -> String? {
    let pattern = #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#
    return value.range(of: pattern, options: [.regularExpression, .caseInsensitive]).map {
      String(value[$0]).lowercased()
    }
  }
}

private struct QGUsageApp: Identifiable {
  let id = UUID()
  let letter: String
  let name: String
  let time: String
  let percent: Int
  let color: Color
  let foreground: Color

  static func theme(for siteID: String) -> (letter: String, color: Color, foreground: Color) {
    switch siteID.lowercased() {
    case "youtube":
      return ("YT", .red, .white)
    case "x", "twitter":
      return ("X", .black, .white)
    case "instagram":
      return ("IG", .pink, .white)
    case "reddit":
      return ("RD", .orange, .white)
    case "tiktok":
      return ("TT", .black, .cyan)
    default:
      return (String(siteID.prefix(2)).uppercased(), QGDesign.elevatedPanel, QGDesign.primaryText)
    }
  }
}

private struct QGUsageAccount: Identifiable {
  let id = UUID()
  let avatar: String
  let name: String
  let subtitle: String
  let time: String
  let activity: String
}
