import ClerkKit
import ClerkKitUI
import FamilyControls
import SwiftUI
import UIKit

struct ContentView: View {
  @Environment(Clerk.self) private var clerk
  @StateObject private var model = AccountHubModel()
  @State private var authViewIsPresented = false

  var body: some View {
    Group {
      if TortoiseScreenshot.isEnabled {
        TortoiseMobileShell(
          accountLabel: "Tortoise account",
          model: model,
          clerk: clerk,
          initialSection: TortoiseScreenshot.initialSection,
          refresh: {}
        )
      } else if clerk.session == nil {
        SignedOutLanding(syncMessage: model.syncMessage, onSignIn: presentAuth)
      } else {
        TortoiseMobileShell(
          accountLabel: accountLabel,
          model: model,
          clerk: clerk,
          refresh: refresh
        )
      }
    }
    .preferredColorScheme(.dark)
    .onOpenURL { url in
      Task {
        try? await clerk.handle(url)
      }
    }
    .task(id: clerk.session?.id) {
      await model.refresh(using: clerk)
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
  }

  private var accountLabel: String {
    clerk.user?.primaryEmailAddress?.emailAddress
      ?? clerk.user?.username
      ?? clerk.user?.id
      ?? "Signed in"
  }

  private func presentAuth() {
    authViewIsPresented = true
    Task {
      _ = try? await clerk.refreshEnvironment()
    }
  }

  private func refresh() async {
    await model.refresh(using: clerk)
  }
}

private enum TortoiseDesign {
  static let background = Color(red: 0.055, green: 0.055, blue: 0.065)
  static let panel = Color(red: 0.118, green: 0.118, blue: 0.133)
  static let elevatedPanel = Color(red: 0.155, green: 0.155, blue: 0.175)
  static let hairline = Color.white.opacity(0.10)
  static let strongHairline = Color.white.opacity(0.15)
  static let primaryText = Color(red: 0.965, green: 0.965, blue: 0.980)
  static let secondaryText = Color(red: 0.620, green: 0.620, blue: 0.665)
  static let tertiaryText = Color(red: 0.470, green: 0.470, blue: 0.520)
  static let accent = Color(red: 0.245, green: 0.388, blue: 0.867)
  static let green = Color(red: 0.190, green: 0.800, blue: 0.360)
  static let red = Color(red: 1.000, green: 0.231, blue: 0.188)
  static let orange = Color(red: 1.000, green: 0.584, blue: 0.000)
  static let purple = Color(red: 0.435, green: 0.337, blue: 0.812)
}

private enum TortoiseScreenshot {
  static var isEnabled: Bool {
    ProcessInfo.processInfo.environment["TORTOISE_SCREENSHOT_MODE"] == "1"
      || ProcessInfo.processInfo.arguments.contains("--tortoise-screenshot")
  }

  static var initialSection: MobileSection {
    let environmentSection = ProcessInfo.processInfo.environment["TORTOISE_SCREENSHOT_SECTION"]
    let argumentSection = value(after: "--tortoise-screenshot-section")
    guard let section = environmentSection ?? argumentSection else {
      return .usage
    }
    return MobileSection(rawValue: section) ?? .usage
  }

  private static func value(after flag: String) -> String? {
    let arguments = ProcessInfo.processInfo.arguments
    guard let index = arguments.firstIndex(of: flag),
          arguments.indices.contains(index + 1) else {
      return nil
    }
    return arguments[index + 1]
  }
}

private struct SignedOutLanding: View {
  let syncMessage: String
  let onSignIn: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 28) {
      HStack {
        HStack(spacing: 10) {
          Image(systemName: "shield.checkered")
            .font(.headline)
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(TortoiseDesign.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
          Text("Tortoise")
            .font(.title3.bold())
        }
        Spacer()
        Button("Sign in", action: onSignIn)
          .buttonStyle(.bordered)
          .controlSize(.large)
      }

      Spacer(minLength: 56)

      VStack(alignment: .leading, spacing: 14) {
        Text("ACCOUNT HUB")
          .font(.caption.bold())
          .foregroundStyle(TortoiseDesign.tertiaryText)

        Text("Sync this iPhone into Tortoise.")
          .font(.largeTitle.bold())
          .foregroundStyle(TortoiseDesign.primaryText)
          .fixedSize(horizontal: false, vertical: true)

        Text("Use the same Tortoise profile for Mac, iPhone, browser helpers, usage summaries, and shared protection policy.")
          .font(.body)
          .foregroundStyle(TortoiseDesign.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }

      VStack(alignment: .leading, spacing: 12) {
        Button(action: onSignIn) {
          Text("Sign in")
            .fontWeight(.bold)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)

        Text(syncMessage)
          .font(.footnote)
          .foregroundStyle(TortoiseDesign.secondaryText)
      }

      Spacer()
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(TortoiseDesign.background)
  }
}

private struct TortoiseMobileShell: View {
  let accountLabel: String
  @ObservedObject var model: AccountHubModel
  let clerk: Clerk
  let refresh: () async -> Void

  @State private var section: MobileSection
  @State private var selectedSite = TuningCatalog.youtubeSiteID
  @StateObject private var screenTime = IOSYouTubeScreenTimeController()
  @Environment(\.scenePhase) private var scenePhase

  init(
    accountLabel: String,
    model: AccountHubModel,
    clerk: Clerk,
    initialSection: MobileSection = .usage,
    refresh: @escaping () async -> Void
  ) {
    self.accountLabel = accountLabel
    self.model = model
    self.clerk = clerk
    self.refresh = refresh
    _section = State(initialValue: initialSection)
  }

  var body: some View {
    ZStack(alignment: .bottom) {
      TortoiseDesign.background
        .ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          if section == .devices {
            if screenTime.connectionState != .connected {
              MobileIOSSetupCard(screenTime: screenTime)
            }
          } else if screenTime.connectionState != .connected {
            if section == .usage {
              MobileFinishSetupBanner(progress: screenTime.setupProgressText) {
                section = .devices
              }
            } else {
              MobileSetupNudge(
                text: screenTime.connectionTitle,
                progress: screenTime.setupRemainingText
              ) {
                section = .devices
              }
            }
          }
          screenContent
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 112)
      }
      .refreshable {
        await refresh()
        screenTime.refreshSetupStatus()
      }
      .task {
        // Optimistic Safari hand-off: stage policy flips into the App Group the
        // moment the user acts, so switching straight to Safari enforces them.
        model.onPolicyStaged = { [weak screenTime] policy in
          guard let screenTime, !screenTime.sessionLockedActive else { return }
          screenTime.applyPolicyFeatures(TuneScreen.iosSafariEnforcedFeatures(policy: policy))
        }
        screenTime.refreshSetupStatus()
      }
      .onChange(of: model.snapshot.policy?.policy.browser?.options?.youtubeDailyLimitMinutes, initial: true) { _, minutes in
        if !screenTime.sessionLockedActive {
          if let minutes {
            screenTime.dailyLimitMinutes = minutes
          }
        }
      }
      .onChange(of: model.snapshot.policy?.policy.browser?.features, initial: true) { _, _ in
        if !screenTime.sessionLockedActive {
          if let policy = model.snapshot.policy?.policy {
            screenTime.applyPolicyFeatures(TuneScreen.iosSafariEnforcedFeatures(policy: policy))
          }
        }
      }
      .onChange(of: screenTime.sessionLockedActive) { _, locked in
        if !locked {
          if let minutes = model.snapshot.policy?.policy.browser?.options?.youtubeDailyLimitMinutes {
            screenTime.dailyLimitMinutes = minutes
          }
          screenTime.applyPolicyFeatures(TuneScreen.iosSafariEnforcedFeatures(policy: model.snapshot.policy?.policy))
        }
      }
      .onChange(of: scenePhase) { _, newPhase in
        if newPhase == .active {
          screenTime.expireSessionIfNeeded()
        }
      }

      bottomTabBar
    }
  }

  @ViewBuilder
  private var screenContent: some View {
    switch section {
    case .usage:
      MobileUsageScreen(
        model: model,
        refreshUsage: { await model.refreshUsage(using: clerk) }
      )
    case .tuning:
      MobileTuningScreen(
        selectedSite: $selectedSite,
        model: model,
        screenTime: screenTime,
        setFeature: setTuningFeature,
        setFeatures: setTuningFeatures,
        setYoutubeProtection: setYoutubeProtection,
        setDailyLimit: setDailyLimit,
        openBlocking: { section = .blocking },
        openDevices: { section = .devices }
      )
    case .blocking:
      MobileBlockingScreen(
        model: model,
        screenTime: screenTime,
        accessMode: currentAccessMode,
        isSyncing: model.isSyncing,
        selectMode: setAccessMode,
        setDailyLimit: setDailyLimit
      )
    case .devices:
      MobileDevicesScreen(accountLabel: accountLabel, model: model, screenTime: screenTime)
    }
  }

  private var currentAccessMode: MobileAccessMode {
    if let mode = model.snapshot.policy?.policy.mode,
       let accessMode = MobileAccessMode(rawValue: mode) {
      return accessMode
    }
    return MobileAccessMode(iosMode: screenTime.enforcementMode) ?? .focus
  }

  private func setAccessMode(_ mode: MobileAccessMode) {
    guard !screenTime.sessionLockedActive else { return }
    if mode != .open && !screenTime.canTurnOn {
      section = .blocking
      screenTime.refreshSetupStatus()
      return
    }

    Task {
      if await model.setPolicyMode(mode.iosMode, using: clerk) != nil {
        screenTime.setMode(mode.iosMode)
      }
    }
  }

  private func setTuningFeature(_ id: String, _ enabled: Bool) {
    guard !screenTime.sessionLockedActive else { return }

    Task {
      _ = await model.setBrowserFeature(id, enabled: enabled, using: clerk)
    }
  }

  private func setTuningFeatures(_ ids: [String], _ enabled: Bool) {
    guard !screenTime.sessionLockedActive else { return }
    guard !ids.isEmpty else {
      return
    }

    Task {
      _ = await model.setBrowserFeatures(ids, enabled: enabled, using: clerk)
    }
  }

  private func setYoutubeProtection(_ enabled: Bool) {
    guard !screenTime.sessionLockedActive else { return }

    if enabled && !screenTime.canTurnOn {
      section = .tuning
      screenTime.refreshSetupStatus()
      return
    }

    Task {
      let youtubeFeatureIDs = TuningCatalog.sites.first { $0.id == "youtube" }?.featureIDs ?? []
      let updatedPolicy = await model.updatePolicy(using: clerk) { policy in
        let basePolicy = enabled && policy.mode == "open" ? policy.settingMode("focus") : policy
        return basePolicy.settingBrowserFeatures(youtubeFeatureIDs, enabled: enabled)
      }
      guard updatedPolicy != nil else {
        return
      }
      if enabled {
        screenTime.turnOn()
      } else {
        screenTime.turnOff()
      }
    }
  }

  private func setDailyLimit(_ minutes: Int) {
    Task {
      _ = await model.setYouTubeDailyLimit(minutes: minutes, using: clerk)
    }
  }

  private var bottomTabBar: some View {
    HStack(spacing: 0) {
      ForEach(MobileSection.allCases) { tab in
        Button {
          section = tab
        } label: {
          VStack(spacing: 4) {
            Image(systemName: tab.systemImage)
              .symbolVariant(section == tab ? .fill : .none)
              .font(.system(size: 20, weight: .semibold))
            Text(tab.title)
              .font(.system(size: 10.5, weight: section == tab ? .bold : .semibold))
          }
          .foregroundStyle(section == tab ? TortoiseDesign.accent : TortoiseDesign.tertiaryText)
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.top, 12)
    .padding(.bottom, 6)
    .background(.ultraThinMaterial, ignoresSafeAreaEdges: .bottom)
    .overlay(alignment: .top) {
      Rectangle()
        .fill(TortoiseDesign.hairline)
        .frame(height: 1)
    }
  }
}

/// Usage per the iOS v1 redesign: one dominant number, an honest trend (only
/// once history exists), a 7-bar week, the web/iPhone split, and the app and
/// account detail folded away until asked for.
private struct MobileUsageScreen: View {
  @ObservedObject var model: AccountHubModel
  let refreshUsage: () async -> Void

  @State private var byAppOpen = true
  @State private var byAccountOpen = false

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      MobileHeader(kicker: todayLabel, title: "Usage")
      usageHero
      byAppCard
      byAccountCard
    }
    .task {
      while !Task.isCancelled {
        await refreshUsage()
        try? await Task.sleep(nanoseconds: 60_000_000_000)
      }
    }
  }

  // MARK: hero

  private var usageHero: some View {
    MobileCard {
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .lastTextBaseline) {
          Text(display.total)
            .font(.system(size: 44, weight: .bold))
            .tracking(-1)
            .foregroundStyle(TortoiseDesign.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
          Spacer()
          if let delta = yesterdayDelta, delta != 0 {
            trendChip(delta: delta)
          }
        }

        Text(UsageHistory.contextLine(yesterdayDelta: yesterdayDelta, averageDelta: averageDelta))
          .font(.system(size: 13))
          .foregroundStyle(TortoiseDesign.secondaryText)
          .padding(.top, 6)
          .fixedSize(horizontal: false, vertical: true)

        weekBars
          .padding(.top, 14)

        MobileDivider()
          .padding(.top, 13)
          .padding(.bottom, 11)

        HStack(spacing: 22) {
          legendEntry(color: TortoiseDesign.accent, label: "Web", value: display.web)
          legendEntry(color: TortoiseDesign.accent.opacity(0.55), label: "iPhone Safari", value: display.ios)
        }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("usage-hero")
  }

  private func trendChip(delta: Int) -> some View {
    let down = delta < 0
    let tint = down ? TortoiseDesign.green : TortoiseDesign.orange
    return HStack(spacing: 5) {
      Image(systemName: down ? "arrow.down" : "arrow.up")
        .font(.system(size: 11, weight: .heavy))
      Text(UsageHistory.shortDuration(abs(delta)))
        .font(.system(size: 12.5, weight: .bold))
    }
    .foregroundStyle(tint)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(tint.opacity(0.14), in: Capsule())
  }

  private var weekBars: some View {
    let bars = UsageHistory.sevenDayBars(history: history, today: today)
    let maxSeconds = max(bars.map(\.totalSeconds).max() ?? 0, 1)
    return HStack(alignment: .bottom, spacing: 6) {
      ForEach(bars) { bar in
        VStack(spacing: 6) {
          RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(bar.isToday ? TortoiseDesign.accent : Color.white.opacity(0.12))
            .frame(height: bar.hasData ? max(CGFloat(bar.totalSeconds) / CGFloat(maxSeconds) * 40, 4) : 4)
            .frame(maxHeight: 40, alignment: .bottom)
          Text(bar.weekdayLetter)
            .font(.system(size: 10, weight: bar.isToday ? .bold : .regular))
            .foregroundStyle(bar.isToday ? TortoiseDesign.primaryText : TortoiseDesign.tertiaryText)
        }
        .frame(maxWidth: .infinity)
      }
    }
  }

  private func legendEntry(color: Color, label: String, value: String) -> some View {
    HStack(spacing: 8) {
      RoundedRectangle(cornerRadius: 2, style: .continuous)
        .fill(color)
        .frame(width: 9, height: 9)
      Text(label)
        .font(.system(size: 13))
        .foregroundStyle(TortoiseDesign.secondaryText)
      Text(value)
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(TortoiseDesign.primaryText)
    }
  }

  // MARK: folded detail

  private var byAppCard: some View {
    MobileCard {
      VStack(alignment: .leading, spacing: 0) {
        Button {
          withAnimation(.easeInOut(duration: 0.25)) {
            byAppOpen.toggle()
          }
        } label: {
          foldHeader(
            systemImage: "chart.bar",
            title: "By app & site",
            count: "\(display.apps.count) item\(display.apps.count == 1 ? "" : "s")",
            isOpen: byAppOpen
          )
        }
        .buttonStyle(.plain)

        if byAppOpen {
          VStack(alignment: .leading, spacing: 15) {
            if display.apps.isEmpty {
              MobileEmptyState(
                title: "No usage reported yet",
                detail: "Browse in Safari here (or a connected browser) and today's time shows up within a minute."
              )
            } else {
              ForEach(display.apps) { app in
                MobileUsageAppRow(app: app)
              }
            }
          }
          .padding(.top, 14)
        }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("usage-by-app")
  }

  private var byAccountCard: some View {
    MobileCard {
      VStack(alignment: .leading, spacing: 0) {
        Button {
          withAnimation(.easeInOut(duration: 0.25)) {
            byAccountOpen.toggle()
          }
        } label: {
          foldHeader(
            systemImage: "person",
            title: "By account",
            count: "\(display.accounts.count) signed in",
            isOpen: byAccountOpen
          )
        }
        .buttonStyle(.plain)

        if byAccountOpen {
          VStack(alignment: .leading, spacing: 16) {
            if display.accounts.isEmpty {
              MobileEmptyState(
                title: "No account activity",
                detail: "Signed-in browser profiles and this iPhone's Safari appear here once they report usage."
              )
            } else {
              ForEach(display.accounts) { account in
                MobileAccountRow(account: account)
              }
            }
          }
          .padding(.top, 14)
        }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("usage-by-account")
  }

  private func foldHeader(systemImage: String, title: String, count: String, isOpen: Bool) -> some View {
    HStack(spacing: 11) {
      Image(systemName: systemImage)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(TortoiseDesign.secondaryText)
      Text(title)
        .font(.system(size: 15, weight: .bold))
        .foregroundStyle(TortoiseDesign.primaryText)
      Spacer(minLength: 8)
      Text(count)
        .font(.system(size: 13))
        .foregroundStyle(TortoiseDesign.secondaryText)
      Image(systemName: "chevron.down")
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(TortoiseDesign.tertiaryText)
        .rotationEffect(.degrees(isOpen ? 180 : 0))
    }
    .contentShape(Rectangle())
  }

  // MARK: data

  private var display: MobileUsageDisplay {
    if let summary = model.snapshot.siteUsageSummary, summary.date == today {
      return MobileUsageDisplay(summary: summary)
    }
    return .empty
  }

  private var today: String {
    SiteUsageDates.localDateKey()
  }

  /// Stored ledger merged with the live summary, so the bars and trend agree
  /// with the hero number even before the next refresh persists it.
  private var history: [UsageDayRecord] {
    var stored = UsageHistoryStore.load()
    if let summary = model.snapshot.siteUsageSummary, summary.date == today {
      stored = UsageHistory.record(
        UsageDayRecord(date: summary.date, totalSeconds: summary.totalSeconds, webSeconds: 0, iosSeconds: 0),
        into: stored
      )
    }
    return stored
  }

  private var yesterdayDelta: Int? {
    UsageHistory.yesterdayDelta(history: history, today: today)
  }

  private var averageDelta: Int? {
    UsageHistory.averageDelta(history: history, today: today)
  }

  private var todayLabel: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "'TODAY ·' EEE MMM d"
    return formatter.string(from: Date()).uppercased()
  }
}

private struct MobileBlockingScreen: View {
  @ObservedObject var model: AccountHubModel
  @ObservedObject var screenTime: IOSYouTubeScreenTimeController
  let accessMode: MobileAccessMode
  let isSyncing: Bool
  let selectMode: (MobileAccessMode) -> Void
  let setDailyLimit: (Int) -> Void

  @State private var appsPickerPresented = false

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      MobileHeader(
        kicker: nil,
        title: "Block",
        subtitle: "Set your mode and choose what's blocked on this iPhone."
      )

      VStack(spacing: 10) {
        ForEach(MobileAccessMode.allCases) { mode in
          Button {
            selectMode(mode)
          } label: {
            MobileModeRow(mode: mode, isSelected: accessMode == mode)
          }
          .buttonStyle(.plain)
          .disabled(isSyncing || screenTime.sessionLockedActive)
        }
      }

      MobileCard {
        VStack(alignment: .leading, spacing: 14) {
          Text("Commit to a session")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(TortoiseDesign.primaryText)
          Text("A locked Strict session can't be ended or weakened early - that's the point.")
            .font(.system(size: 13))
            .foregroundStyle(TortoiseDesign.secondaryText)

          if screenTime.sessionActive {
            HStack(spacing: 10) {
              Text(screenTime.sessionStatusLine)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(TortoiseDesign.primaryText)
              Spacer(minLength: 8)
              if screenTime.sessionLockedActive {
                Label("Locked until it ends", systemImage: "lock.fill")
                  .font(.system(size: 12, weight: .bold))
                  .foregroundStyle(TortoiseDesign.secondaryText)
              } else {
                Button("End session") {
                  screenTime.endSession()
                }
                .font(.system(size: 12, weight: .bold))
                .buttonStyle(.bordered)
              }
            }
          }

          HStack(spacing: 8) {
            MobileSessionButton("Focus · 25m") {
              screenTime.startSession(mode: .focus, duration: 25 * 60, locked: false)
            }
            .disabled(screenTime.sessionLockedActive)
            MobileSessionButton("Focus · 1h") {
              screenTime.startSession(mode: .focus, duration: 60 * 60, locked: false)
            }
            .disabled(screenTime.sessionLockedActive)
            MobileSessionButton("Lock Strict · 2h", systemImage: "lock") {
              screenTime.startSession(mode: .strict, duration: 2 * 3600, locked: true)
            }
            .disabled(screenTime.sessionLockedActive)
          }
        }
      }

      MobileCard {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: "iphone.gen3")
            .foregroundStyle(TortoiseDesign.accent)
          Text("On iPhone, blocks run through the Tortoise app and Screen Time. Keep Tortoise allowed in Settings > Screen Time for full enforcement.")
            .font(.system(size: 13))
            .foregroundStyle(TortoiseDesign.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      MobileCard {
        VStack(alignment: .leading, spacing: 14) {
          HStack(spacing: 8) {
            MobileSectionLabel("Apps")
            Spacer(minLength: 8)
            Button(screenTime.hasManagedAppsSelection ? "Edit" : "Choose apps") {
              presentAppsPicker()
            }
            .font(.system(size: 12, weight: .bold))
            .buttonStyle(.bordered)
            .disabled(screenTime.authorizationState != .approved || screenTime.sessionLockedActive)
          }

          Text(screenTime.managedAppsSummary)
            .font(.system(size: 13))
            .foregroundStyle(TortoiseDesign.secondaryText)
            .fixedSize(horizontal: false, vertical: true)

          if screenTime.hasManagedAppsSelection {
            VStack(alignment: .leading, spacing: 10) {
              ForEach(Array(screenTime.managedAppsSelection.applicationTokens), id: \.self) { token in
                Label(token)
                  .labelStyle(.titleAndIcon)
                  .font(.system(size: 14))
                  .foregroundStyle(TortoiseDesign.primaryText)
              }
              ForEach(Array(screenTime.managedAppsSelection.categoryTokens), id: \.self) { token in
                Label(token)
                  .labelStyle(.titleAndIcon)
                  .font(.system(size: 14))
                  .foregroundStyle(TortoiseDesign.primaryText)
              }
              if !screenTime.managedAppsSelection.webDomainTokens.isEmpty {
                let domainCount = screenTime.managedAppsSelection.webDomainTokens.count
                Text("\(domainCount) web domain\(domainCount == 1 ? "" : "s")")
                  .font(.system(size: 13, weight: .semibold))
                  .foregroundStyle(TortoiseDesign.secondaryText)
              }
            }
            .padding(.top, 2)
          }

          if screenTime.hasManagedAppsSelection {
            MobileDivider()

            HStack(spacing: 10) {
              VStack(alignment: .leading, spacing: 3) {
                Text("Daily limit")
                  .font(.system(size: 13, weight: .bold))
                  .foregroundStyle(TortoiseDesign.primaryText)
                Text(screenTime.managedAppsLimitSummary)
                  .font(.system(size: 12))
                  .foregroundStyle(TortoiseDesign.secondaryText)
                  .fixedSize(horizontal: false, vertical: true)
              }
              Spacer(minLength: 8)
              MobileSwitch(
                isOn: Binding(
                  get: { screenTime.managedAppsLimitEnabled },
                  set: { screenTime.setManagedAppsLimitEnabled($0) }
                ),
                isEnabled: !screenTime.sessionLockedActive
              )
            }

            if screenTime.managedAppsLimitEnabled {
              HStack(spacing: 8) {
                Spacer()
                MobileStepperButton(systemImage: "minus") {
                  screenTime.adjustManagedAppsLimit(by: -5)
                }
                .disabled(screenTime.sessionLockedActive)
                Text("\(screenTime.managedAppsLimitDisplayMinutes)m")
                  .font(.system(size: 13, weight: .bold))
                  .frame(width: 48)
                MobileStepperButton(systemImage: "plus") {
                  screenTime.adjustManagedAppsLimit(by: 5)
                }
                .disabled(screenTime.sessionLockedActive)
              }
            }
          }
        }
      }
      .familyActivityPicker(isPresented: $appsPickerPresented, selection: managedAppsBinding)

      MobileIOSYouTubeLimitCard(screenTime: screenTime, setDailyLimit: setDailyLimit)
    }
  }

  /// Routes every picker write through the controller's guard so the locked
  /// session freeze holds even while the picker is open. The getter reflects the
  /// controller's (possibly refused) authoritative selection back into the picker.
  private var managedAppsBinding: Binding<FamilyActivitySelection> {
    Binding(
      get: { screenTime.managedAppsSelection },
      set: { screenTime.setManagedAppsSelection($0) }
    )
  }

  private func presentAppsPicker() {
    guard !screenTime.sessionLockedActive else { return }
    appsPickerPresented = true
  }
}

private struct MobileTuningScreen: View {
  @Binding var selectedSite: String
  @ObservedObject var model: AccountHubModel
  @ObservedObject var screenTime: IOSYouTubeScreenTimeController
  @State private var safariConnectPresented = false
  let setFeature: (String, Bool) -> Void
  let setFeatures: ([String], Bool) -> Void
  let setYoutubeProtection: (Bool) -> Void
  let setDailyLimit: (Int) -> Void
  let openBlocking: () -> Void
  let openDevices: () -> Void

  private var tunePolicy: TortoisePolicy? { model.snapshot.policy?.policy }

  private var scopeState: TuneScopeState {
    TuneScope.iosState(
      safariExtensionState: screenTime.safariExtensionState,
      safariAcknowledged: screenTime.safariExtensionAcknowledged,
      safariHeartbeatFresh: screenTime.safariHeartbeatIsFresh,
      devices: model.snapshot.devices,
      now: Date()
    )
  }

  private var tuneSites: [TuneSite] {
    TuneScreen.sites(policy: tunePolicy, surface: .iosSafari)
  }

  private var selectedTuneSite: TuneSite? {
    tuneSites.first { $0.id == selectedSite }
  }

  private var selectedSiteFeatures: [TuneFeature] {
    TuneScreen.features(forSiteID: selectedSite, policy: tunePolicy, surface: .iosSafari)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      MobileHeader(
        kicker: nil,
        title: "Tune",
        subtitle: TuneScopeCopy.tuneSubtitle
      )

      MobileNativeAppsLaneCard(openBlocking: openBlocking)

      MobileSectionLabel(TuneScopeCopy.websitesLaneTitle)

      if scopeState.showSetupFirstBanner {
        MobileTuneSetupFirstBanner(enable: { safariConnectPresented = true })
      }

      scopeCard

      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 150), spacing: 10)],
        spacing: 10
      ) {
        ForEach(tuneSites) { site in
          Button {
            selectedSite = site.id
          } label: {
            MobileSiteTile(site: site, isSelected: selectedSite == site.id)
          }
          .buttonStyle(.plain)
        }

        MobileTikTokComingSoonTile()
      }

      if let selectedTuneSite {
        MobileCard {
          HStack(spacing: 12) {
            MobileTuneBrandMark(assetName: selectedTuneSite.brandAssetName, size: 44, cornerRadius: 10)
            VStack(alignment: .leading, spacing: 3) {
              Text("\(selectedTuneSite.title) cleanup")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(TortoiseDesign.primaryText)
              Text("\(enabledFeatureCount)/\(selectedSiteFeatures.count) hidden")
                .font(.system(size: 13))
                .foregroundStyle(TortoiseDesign.secondaryText)
            }
            Spacer()
            Button(tuningActionTitle) {
              performTuningAction()
            }
            .buttonStyle(.bordered)
            .disabled(model.isSyncing || screenTime.sessionLockedActive)
          }
        }

        if selectedTuneSite.id == "x" {
          MobileXPlatformSafetyRow()
        }

        MobileCard {
          VStack(spacing: 0) {
            ForEach(Array(selectedSiteFeatures.enumerated()), id: \.element.id) { index, feature in
              if index > 0 {
                MobileDivider()
                  .padding(.vertical, 13)
              }
              MobileTuningFeatureRow(
                feature: feature,
                isOn: Binding(
                  get: { feature.isOn },
                  set: { setFeature(feature.id, $0) }
                ),
                isEnabled: !model.isSyncing && !screenTime.sessionLockedActive
              )
            }
          }
        }

        if let writeError = model.writeErrorMessage {
          Label(writeError, systemImage: "exclamationmark.triangle")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(TortoiseDesign.orange)
            .accessibilityIdentifier("tune-write-error")
        }
      }
    }
    .sheet(isPresented: $safariConnectPresented) {
      MobileSafariConnectSheet(screenTime: screenTime)
    }
  }

  /// The honest answer to "what is enforcing these toggles?": the iPhone's own
  /// Safari extension (from the local controller — it is not a cloud device)
  /// plus each connected desktop browser profile.
  private var scopeCard: some View {
    MobileCard {
      VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 8) {
          Image(systemName: "shield.checkered")
            .foregroundStyle(TortoiseDesign.green)
          Text(TuneScopeCopy.websitesLaneDetail)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(TortoiseDesign.secondaryText)
        }
        VStack(spacing: 8) {
          MobileTuneScopeChip(entry: scopeState.iphoneSafari, action: safariChipAction)
            .accessibilityIdentifier("tune-scope-iphone-safari")
          ForEach(scopeState.desktopProfiles) { entry in
            MobileTuneScopeChip(entry: entry)
          }
          if scopeState.showAddComputerAffordance {
            Button(action: openDevices) {
              HStack(spacing: 8) {
                Image(systemName: "plus")
                  .font(.system(size: 12, weight: .bold))
                Text(TuneScopeCopy.addComputerTitle)
                  .font(.system(size: 12, weight: .bold))
                  .lineLimit(1)
                Spacer(minLength: 0)
              }
              .foregroundStyle(TortoiseDesign.accent)
              .padding(.horizontal, 9)
              .padding(.vertical, 10)
              .background(TortoiseDesign.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("tune-scope-add-computer")
          }
        }
      }
    }
    // .contain makes the card its own accessibility container: without it the
    // card identifier propagates onto the chips and CLOBBERS their identifiers
    // whenever a chip renders as a Button (any attention state).
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("tune-scope-card")
  }

  /// Any attention state makes the Safari chip actionable: it opens the one
  /// canonical connect sheet, which carries the enable/allow/verify branching.
  private var safariChipAction: (() -> Void)? {
    switch scopeState.iphoneSafari.status {
    case .attention:
      return { safariConnectPresented = true }
    case .on, .off:
      return nil
    }
  }

  private var enabledFeatureCount: Int {
    selectedSiteFeatures.filter(\.isOn).count
  }

  /// Only the features this surface (iOS Safari) can actually enforce. The bulk
  /// "Hide all" / "Reset all" action must stay within this subset defensively,
  /// even though every iOS Safari feature is enforceable today.
  private var enforceableSiteFeatures: [TuneFeature] {
    selectedSiteFeatures.filter(\.isEnforceable)
  }

  private var enabledEnforceableFeatureCount: Int {
    enforceableSiteFeatures.filter(\.isOn).count
  }

  private var tuningActionTitle: String {
    if selectedSite == TuningCatalog.youtubeSiteID {
      if !screenTime.shieldingEnabled && !screenTime.canTurnOn {
        return "Finish setup"
      }
      return screenTime.shieldingEnabled ? "Turn off" : "Turn on"
    }
    let countableFeatures = enforceableSiteFeatures.count
    guard countableFeatures > 0 else {
      return "Connect"
    }
    return enabledEnforceableFeatureCount == countableFeatures ? "Reset all" : "Hide all"
  }

  private func performTuningAction() {
    if selectedSite == TuningCatalog.youtubeSiteID {
      setYoutubeProtection(!screenTime.shieldingEnabled)
      return
    }
    toggleAll()
  }

  private func toggleAll() {
    let countableFeatures = enforceableSiteFeatures.count
    guard countableFeatures > 0 else {
      return
    }
    let next = enabledEnforceableFeatureCount != countableFeatures
    setFeatures(enforceableSiteFeatures.map(\.id), next)
  }

}

/// Devices per the iOS v1 redesign: just access & setup. One account card
/// whose Connections row expands to everything on the account (this iPhone,
/// devices, nested browser profiles); the setup block collapses to a single
/// green "all set" row once the checklist is done.
private struct MobileDevicesScreen: View {
  let accountLabel: String
  @ObservedObject var model: AccountHubModel
  @ObservedObject var screenTime: IOSYouTubeScreenTimeController
  @State private var addSheetPresented = false
  @State private var connectionsOpen = false
  @State private var allSetExpanded = false
  @State private var editAppsPresented = false

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      MobileHeader(kicker: nil, title: "Devices")

      accountCard

      if screenTime.connectionState == .connected {
        allSetCard
      }
    }
    .sheet(isPresented: $addSheetPresented) { MobileAddSheet() }
    .familyActivityPicker(isPresented: $editAppsPresented, selection: $screenTime.selection)
  }

  // MARK: account + connections

  private var accountCard: some View {
    MobileCard {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 12) {
          MobileAvatar(text: accountInitials, size: 48, background: TortoiseDesign.accent.opacity(0.28))
          VStack(alignment: .leading, spacing: 3) {
            Text(accountTitle)
              .font(.system(size: 17, weight: .bold))
            Text(accountLabel)
              .font(.system(size: 13))
              .foregroundStyle(TortoiseDesign.secondaryText)
              .lineLimit(1)
          }
          Spacer()
        }

        MobileDivider()
          .padding(.top, 16)
          .padding(.bottom, 14)

        Button {
          withAnimation(.easeInOut(duration: 0.25)) {
            connectionsOpen.toggle()
          }
        } label: {
          HStack(spacing: 12) {
            Image(systemName: "macbook.and.iphone")
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(TortoiseDesign.secondaryText)
            Text("Connections")
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(TortoiseDesign.primaryText)
            Spacer(minLength: 8)
            Text("\(connectionCount)")
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(TortoiseDesign.primaryText)
              .padding(.horizontal, 9)
              .padding(.vertical, 4)
              .background(Color.white.opacity(0.09), in: Capsule())
            Image(systemName: "chevron.down")
              .font(.system(size: 12, weight: .bold))
              .foregroundStyle(TortoiseDesign.tertiaryText)
              .rotationEffect(.degrees(connectionsOpen ? 180 : 0))
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("devices-connections-row")

        if connectionsOpen {
          VStack(alignment: .leading, spacing: 0) {
            MobileDivider()
              .padding(.top, 14)
              .padding(.bottom, 13)

            MobileIOSDeviceStatusRow(screenTime: screenTime)

            ForEach(deviceRows) { row in
              MobileDivider()
                .padding(.vertical, 13)
              MobileHubRow(row: row)
            }

            ForEach(browserHubRows) { row in
              MobileDivider()
                .padding(.vertical, 13)
              VStack(alignment: .leading, spacing: 0) {
                MobileHubRow(row: row)
                if !row.profiles.isEmpty {
                  VStack(spacing: 0) {
                    ForEach(Array(row.profiles.enumerated()), id: \.element.id) { profileIndex, profile in
                      if profileIndex > 0 {
                        MobileDivider()
                          .padding(.vertical, 10)
                      }
                      MobileHubRow(row: profile)
                    }
                  }
                  .padding(.leading, 48)
                  .padding(.top, 10)
                }
              }
            }

            Button {
              addSheetPresented = true
            } label: {
              Label("Connect another device", systemImage: "plus")
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 16)
          }
        }
      }
    }
  }

  // MARK: setup all-set

  private var allSetCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button {
        withAnimation(.easeInOut(duration: 0.25)) {
          allSetExpanded.toggle()
        }
      } label: {
        HStack(spacing: 12) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 20))
            .foregroundStyle(TortoiseDesign.green)
          VStack(alignment: .leading, spacing: 2) {
            Text("This iPhone is all set")
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(TortoiseDesign.primaryText)
            Text("Protection on · all \(Self.steps.count) steps done")
              .font(.system(size: 13))
              .foregroundStyle(TortoiseDesign.secondaryText)
          }
          Spacer(minLength: 8)
          Image(systemName: "chevron.down")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(TortoiseDesign.tertiaryText)
            .rotationEffect(.degrees(allSetExpanded ? 180 : 0))
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      if allSetExpanded {
        MobileDivider()
          .padding(.top, 15)
          .padding(.bottom, 4)
        ForEach(Self.steps, id: \.self) { step in
          HStack(spacing: 11) {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 16))
              .foregroundStyle(TortoiseDesign.green)
            Text(step.title)
              .font(.system(size: 14))
              .foregroundStyle(TortoiseDesign.secondaryText)
            Spacer(minLength: 8)
            if step == .targets {
              Button("Edit") {
                editAppsPresented = true
              }
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(TortoiseDesign.accent)
              .buttonStyle(.plain)
              .disabled(screenTime.sessionLockedActive)
            }
          }
          .padding(.vertical, 10)
        }
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(TortoiseDesign.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(TortoiseDesign.green.opacity(0.28))
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("devices-setup-allset")
  }

  private static let steps = IOSEnforcementController.userSetupSteps

  // MARK: data

  private var hubRows: [DeviceHubRow] {
    DevicesHub.rows(
      devices: model.snapshot.devices,
      currentDeviceID: model.snapshot.device?.id,
      now: Date()
    )
  }

  private var deviceRows: [DeviceHubRow] {
    hubRows.filter { row in
      if case .browser = row.kind { return false }
      return !row.isCurrentDevice
    }
  }

  private var browserHubRows: [DeviceHubRow] {
    hubRows.filter { row in
      if case .browser = row.kind { return true }
      return false
    }
  }

  private var connectionCount: Int {
    DevicesHub.connectedCount(hubRows)
  }

  private var accountTitle: String {
    let base = accountLabel.components(separatedBy: "@").first ?? accountLabel
    let cleaned = base
      .replacingOccurrences(of: ".", with: " ")
      .replacingOccurrences(of: "_", with: " ")
      .replacingOccurrences(of: "-", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned.isEmpty ? "Tortoise account" : cleaned.capitalized
  }

  private var accountInitials: String {
    String(accountTitle.split(separator: " ").prefix(2).compactMap(\.first)).uppercased()
  }
}

/// The "Add" sheet on iOS: pick Phone / Computer / Browser, then scan the QR
/// (or tap the link) on that thing and sign in — it shows up in the hub. No codes.
private struct MobileAddSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var selected: AddDestination?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 14) {
          if let selected {
            detail(selected)
          } else {
            ForEach(AddDestination.allCases) { d in
              Button { selected = d } label: { tile(d) }.buttonStyle(.plain)
            }
          }
        }
        .padding(20)
      }
      .background(TortoiseDesign.background)
      .navigationTitle(selected.map { "Add \($0.title.lowercased())" } ?? "Add")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          if selected != nil {
            Button("Back") { selected = nil }
          } else {
            Button("Close") { dismiss() }
          }
        }
      }
    }
    .preferredColorScheme(.dark)
  }

  private func tile(_ d: AddDestination) -> some View {
    HStack(spacing: 14) {
      Image(systemName: d.systemImage)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(TortoiseDesign.secondaryText)
        .frame(width: 40, height: 40)
        .background(TortoiseDesign.elevatedPanel, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
      Text(d.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(TortoiseDesign.primaryText)
      Spacer()
      Image(systemName: "chevron.right").foregroundStyle(TortoiseDesign.tertiaryText)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(TortoiseDesign.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(TortoiseDesign.strongHairline) }
  }

  @ViewBuilder private func detail(_ d: AddDestination) -> some View {
    VStack(spacing: 18) {
      if let cg = QRCode.cgImage(for: d.url().absoluteString) {
        Image(decorative: cg, scale: 1)
          .interpolation(.none).resizable()
          .frame(width: 200, height: 200)
          .padding(12)
          .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
      Link(destination: d.url()) {
        Text(d.url().absoluteString).font(.system(size: 13, weight: .semibold)).foregroundStyle(TortoiseDesign.accent)
      }
      Text(d.caption)
        .font(.system(size: 14)).foregroundStyle(TortoiseDesign.secondaryText)
        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
    }
    .padding(.top, 12)
  }
}

/// One-line pointer to the Devices tab while setup is incomplete. Keeps
/// Usage/Tune/Block free of the full setup checklist.
private struct MobileSetupNudge: View {
  let text: String
  let progress: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: "exclamationmark.circle.fill")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(TortoiseDesign.orange)
        Text(text)
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(TortoiseDesign.primaryText)
          .lineLimit(1)
        Spacer(minLength: 8)
        Text(progress)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(TortoiseDesign.secondaryText)
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(TortoiseDesign.tertiaryText)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(TortoiseDesign.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(TortoiseDesign.hairline)
      }
    }
    .buttonStyle(.plain)
  }
}

/// The landing-screen setup banner (iOS v1 redesign): setup no longer hijacks
/// navigation — while the checklist is incomplete, Usage carries this one
/// orange line stating the consequence and linking to Devices.
private struct MobileFinishSetupBanner: View {
  let progress: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 11) {
        Image(systemName: "exclamationmark.triangle")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(TortoiseDesign.orange)
        VStack(alignment: .leading, spacing: 2) {
          Text("Finish setting up this iPhone")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(TortoiseDesign.primaryText)
          Text("Blocking & tuning stay off until setup is done")
            .font(.system(size: 12))
            .foregroundStyle(TortoiseDesign.secondaryText)
        }
        Spacer(minLength: 8)
        Text(progress)
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(TortoiseDesign.orange)
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(TortoiseDesign.orange)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .background(TortoiseDesign.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .strokeBorder(TortoiseDesign.orange.opacity(0.28))
      }
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("usage-finish-setup-banner")
  }
}

/// The single "get connected" card: four rows, one action each, no prose.
/// Replaces the old banner + seven-step checklist pair — once connected the
/// device row carries the status and this card disappears entirely.
private struct MobileIOSSetupCard: View {
  @ObservedObject var screenTime: IOSYouTubeScreenTimeController
  @State private var pickerPresented = false
  @State private var safariConnectPresented = false

  private static let steps = IOSEnforcementController.userSetupSteps

  var body: some View {
    MobileCard {
      VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 8) {
          Text("Set up this iPhone")
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(TortoiseDesign.primaryText)
          Spacer()
          Text(screenTime.setupProgressText)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(TortoiseDesign.secondaryText)
          Button {
            screenTime.refreshSetupStatus()
          } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
              .font(.system(size: 12, weight: .bold))
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
        }

        if screenTime.connectionState == .repairRequired {
          Text(screenTime.repairDetail)
            .font(.system(size: 12))
            .foregroundStyle(TortoiseDesign.red)
            .fixedSize(horizontal: false, vertical: true)
        }

        if screenTime.authorizationState != .approved {
          HStack(spacing: 8) {
            ForEach(IOSEnforcementAuthorizationMode.allCases) { mode in
              Button {
                screenTime.authorizationMode = mode
              } label: {
                Label(mode.title, systemImage: mode.systemImage)
                  .font(.system(size: 12, weight: .bold))
                  .lineLimit(1)
                  .minimumScaleFactor(0.75)
                  .frame(maxWidth: .infinity)
              }
              .buttonStyle(.bordered)
              .tint(screenTime.authorizationMode == mode ? TortoiseDesign.accent : TortoiseDesign.secondaryText)
            }
          }
          if screenTime.authorizationMode == .child {
            Text("Needs Family Sharing and a child Apple Account.")
              .font(.system(size: 12))
              .foregroundStyle(TortoiseDesign.orange)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        VStack(spacing: 0) {
          ForEach(Array(Self.steps.enumerated()), id: \.element.id) { index, step in
            if index > 0 {
              MobileDivider()
                .padding(.vertical, 11)
            }
            MobileIOSSetupStepRow(
              step: step,
              status: screenTime.setupStatus(for: step),
              hint: hint(for: step),
              actionTitle: actionTitle(for: step),
              isCurrent: step == currentStep,
              isDisabled: isDisabled(step),
              action: { perform(step) }
            )
          }
        }
      }
    }
    .familyActivityPicker(isPresented: $pickerPresented, selection: $screenTime.selection)
    .sheet(isPresented: $safariConnectPresented) {
      MobileSafariConnectSheet(screenTime: screenTime)
    }
    .onAppear {
      screenTime.refreshSetupStatus()
    }
  }

  /// The first unfinished step gets the prominent button — the eye lands on
  /// exactly one next action.
  private var currentStep: IOSEnforcementSetupStep? {
    Self.steps.first { screenTime.setupStatus(for: $0) != .complete }
  }

  /// One short line, and only when the next move isn't obvious from the button.
  private func hint(for step: IOSEnforcementSetupStep) -> String? {
    switch step {
    case .safariExtension:
      switch screenTime.safariExtensionState {
      case .enabledWaitingForHeartbeat:
        return "Allow it in Safari"
      case .failed:
        return "Check failed — retry"
      default:
        return nil
      }
    case .screenTimePermission:
      return screenTime.authorizationState == .denied ? "Blocked in Settings" : nil
    default:
      return nil
    }
  }

  private func actionTitle(for step: IOSEnforcementSetupStep) -> String? {
    switch step {
    case .screenTimePermission:
      return screenTime.authorizationState == .approved ? nil : (screenTime.authorizationState == .denied ? "Retry" : "Allow")
    case .targets:
      return screenTime.authorizationState == .approved ? (screenTime.hasSelection ? "Edit" : "Choose") : nil
    case .safariExtension:
      // One label for every unfinished state: the connect sheet carries the
      // enable/allow/verify branching, because iOS can't tell us which of
      // those the user still needs.
      return screenTime.safariExtensionState == .connected ? nil : "Connect"
    case .mode:
      return screenTime.shieldingEnabled ? nil : "Turn on"
    case .account, .authorizationMode, .sync:
      return nil
    }
  }

  private func isDisabled(_ step: IOSEnforcementSetupStep) -> Bool {
    switch step {
    case .targets:
      return screenTime.sessionLockedActive
    case .mode:
      return !screenTime.canTurnOn && !screenTime.shieldingEnabled
    default:
      return false
    }
  }

  private func perform(_ step: IOSEnforcementSetupStep) {
    switch step {
    case .screenTimePermission:
      Task {
        await screenTime.requestAuthorization()
      }
    case .targets:
      guard !screenTime.sessionLockedActive else { return }
      pickerPresented = true
    case .safariExtension:
      safariConnectPresented = true
    case .mode:
      screenTime.turnOn()
    case .sync, .account, .authorizationMode:
      screenTime.refreshSetupStatus()
    }
  }
}

private struct MobileIOSSetupStepRow: View {
  let step: IOSEnforcementSetupStep
  let status: IOSEnforcementSetupStatus
  let hint: String?
  let actionTitle: String?
  var isCurrent: Bool = false
  var isDisabled: Bool = false
  let action: () -> Void

  var body: some View {
    HStack(alignment: .center, spacing: 11) {
      Image(systemName: status.systemImage(default: "circle"))
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(status == .needsAction ? TortoiseDesign.tertiaryText : status.tint)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 2) {
        Text(step.title)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(status == .complete ? TortoiseDesign.secondaryText : TortoiseDesign.primaryText)
        if let hint {
          Text(hint)
            .font(.system(size: 12))
            .foregroundStyle(status == .failed ? TortoiseDesign.red : TortoiseDesign.secondaryText)
        }
      }

      Spacer(minLength: 8)

      if let actionTitle {
        Group {
          if isCurrent {
            Button(actionTitle, action: action)
              .buttonStyle(.borderedProminent)
          } else {
            Button(actionTitle, action: action)
              .buttonStyle(.bordered)
          }
        }
        .font(.system(size: 12, weight: .bold))
        .controlSize(.small)
        .disabled(isDisabled)
      }
    }
  }
}

private struct MobileIOSDeviceStatusRow: View {
  @ObservedObject var screenTime: IOSYouTubeScreenTimeController

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "iphone")
        .foregroundStyle(screenTime.connectionState.tint)
        .frame(width: 36, height: 36)
        .background(screenTime.connectionState.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text("This iPhone")
            .font(.system(size: 14, weight: .bold))
          MobileIOSStatusBadge(text: screenTime.connectionState.shortTitle, tint: screenTime.connectionState.tint)
        }
        Text(screenTime.deviceStatusSubtitle)
          .font(.system(size: 12))
          .foregroundStyle(TortoiseDesign.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

private struct MobileIOSStatusBadge: View {
  let text: String
  let tint: Color

  var body: some View {
    Text(text.uppercased())
      .font(.system(size: 9, weight: .bold))
      .foregroundStyle(tint)
      .lineLimit(1)
      .minimumScaleFactor(0.65)
      .padding(.horizontal, 7)
      .padding(.vertical, 4)
      .background(tint.opacity(0.14), in: Capsule())
  }
}

/// Compact YouTube daily-limit control, parked on the Block tab until the
/// Tune "Apps on iPhone" surface (build 14) absorbs it as a per-app row.
private struct MobileIOSYouTubeLimitCard: View {
  @ObservedObject var screenTime: IOSYouTubeScreenTimeController
  var setDailyLimit: ((Int) -> Void)? = nil

  var body: some View {
    MobileCard {
      HStack(spacing: 10) {
        VStack(alignment: .leading, spacing: 3) {
          Text("YouTube daily limit")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(TortoiseDesign.primaryText)
          Text("YouTube app + Safari on this iPhone")
            .font(.system(size: 12))
            .foregroundStyle(TortoiseDesign.secondaryText)
        }
        Spacer()
        HStack(spacing: 8) {
          MobileStepperButton(systemImage: "minus") {
            adjustDailyLimit(by: -5)
          }
          .disabled(screenTime.sessionLockedActive)
          Text("\(screenTime.dailyLimitMinutes)m")
            .font(.system(size: 14, weight: .bold))
            .frame(width: 48)
          MobileStepperButton(systemImage: "plus") {
            adjustDailyLimit(by: 5)
          }
          .disabled(screenTime.sessionLockedActive)
        }
      }
    }
  }

  private func adjustDailyLimit(by delta: Int) {
    guard !screenTime.sessionLockedActive else { return }
    let nextMinutes = min(max(screenTime.dailyLimitMinutes + delta, 5), 480)
    screenTime.dailyLimitMinutes = nextMinutes
    setDailyLimit?(nextMinutes)
  }
}

private struct MobileStepperButton: View {
  let systemImage: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 12, weight: .bold))
        .frame(width: 28, height: 28)
    }
    .buttonStyle(.bordered)
    .accessibilityIdentifier("stepper-\(systemImage)")
  }
}

private struct MobileEmptyState: View {
  let title: String
  let detail: String

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title)
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(TortoiseDesign.primaryText)
      Text(detail)
        .font(.system(size: 12.5))
        .foregroundStyle(TortoiseDesign.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(TortoiseDesign.elevatedPanel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}

private struct MobileHeader: View {
  let kicker: String?
  let title: String
  var subtitle: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let kicker {
        Text(kicker)
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(TortoiseDesign.tertiaryText)
      }
      Text(title)
        .font(.system(size: 32, weight: .bold))
        .foregroundStyle(TortoiseDesign.primaryText)
      if let subtitle {
        Text(subtitle)
          .font(.system(size: 14))
          .foregroundStyle(TortoiseDesign.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

private struct MobileCard<Content: View>: View {
  private let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      content
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(TortoiseDesign.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(TortoiseDesign.strongHairline)
    }
  }
}

private struct MobileAvatar: View {
  let text: String
  var size: CGFloat = 34
  var background: Color = Color.white.opacity(0.11)
  var foreground: Color = TortoiseDesign.primaryText
  var cornerRadius: CGFloat?

  var body: some View {
    Text(text)
      .font(.system(size: max(10, size * 0.34), weight: .bold))
      .foregroundStyle(foreground)
      .frame(width: size, height: size)
      .background(background, in: RoundedRectangle(cornerRadius: cornerRadius ?? size / 2.7, style: .continuous))
  }
}

private struct MobilePill: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.system(size: 12, weight: .bold))
      .foregroundStyle(TortoiseDesign.primaryText)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(Color.white.opacity(0.08), in: Capsule())
  }
}

private struct MobileSectionLabel: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    Text(text.uppercased())
      .font(.system(size: 12, weight: .bold))
      .foregroundStyle(TortoiseDesign.tertiaryText)
      .tracking(1.1)
  }
}

private struct MobileDivider: View {
  var body: some View {
    Rectangle()
      .fill(TortoiseDesign.hairline)
      .frame(height: 1)
  }
}

private struct MobileMetric: View {
  let value: String
  let label: String

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(value)
        .font(.system(size: 17, weight: .bold))
      Text(label)
        .font(.system(size: 12))
        .foregroundStyle(TortoiseDesign.secondaryText)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(TortoiseDesign.elevatedPanel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}

private struct MobileUsageAppRow: View {
  let app: MobileUsageApp

  var body: some View {
    HStack(spacing: 12) {
      MobileAvatar(text: app.letter, size: 32, background: app.color, foreground: app.foreground, cornerRadius: 9)
      VStack(alignment: .leading, spacing: 5) {
        HStack {
          Text(app.name)
            .font(.system(size: 14, weight: .bold))
          Spacer()
          Text(app.time)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(TortoiseDesign.secondaryText)
        }
        if let detail = app.detail {
          Text(detail)
            .font(.system(size: 12))
            .foregroundStyle(TortoiseDesign.tertiaryText)
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

private struct MobileAccountRow: View {
  let account: MobileUsageAccount

  var body: some View {
    HStack(spacing: 12) {
      MobileAvatar(text: account.avatar, size: 34)
      VStack(alignment: .leading, spacing: 3) {
        Text(account.name)
          .font(.system(size: 14, weight: .bold))
        Text(account.subtitle)
          .font(.system(size: 12))
          .foregroundStyle(TortoiseDesign.secondaryText)
          .lineLimit(1)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 3) {
        Text(account.time)
          .font(.system(size: 14, weight: .bold))
        Text(account.activity)
          .font(.system(size: 12))
          .foregroundStyle(TortoiseDesign.secondaryText)
      }
    }
  }
}

private struct MobileModeRow: View {
  let mode: MobileAccessMode
  let isSelected: Bool

  var body: some View {
    HStack(spacing: 13) {
      Image(systemName: mode.systemImage)
        .foregroundStyle(isSelected ? TortoiseDesign.accent : TortoiseDesign.secondaryText)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 4) {
        Text(mode.title)
          .font(.system(size: 15, weight: .bold))
        Text(mode.detail)
          .font(.system(size: 12))
          .foregroundStyle(TortoiseDesign.secondaryText)
      }
      Spacer()
      if isSelected {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(TortoiseDesign.accent)
      }
    }
    .padding(14)
    .background(TortoiseDesign.panel, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 15, style: .continuous)
        .strokeBorder(isSelected ? TortoiseDesign.accent : TortoiseDesign.hairline)
    }
  }
}

private struct MobileSessionButton: View {
  let title: String
  var systemImage: String?
  let action: () -> Void

  init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
    self.title = title
    self.systemImage = systemImage
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      if let systemImage {
        Label(title, systemImage: systemImage)
      } else {
        Text(title)
      }
    }
    .font(.system(size: 12, weight: .bold))
    .buttonStyle(.bordered)
  }
}

private struct MobileSwitch: View {
  @Binding var isOn: Bool
  var isEnabled = true

  var body: some View {
    Button {
      guard isEnabled else { return }
      isOn.toggle()
    } label: {
      RoundedRectangle(cornerRadius: 13, style: .continuous)
        .fill(isOn ? TortoiseDesign.green : Color.white.opacity(0.20))
        .frame(width: 42, height: 26)
        .overlay(alignment: isOn ? .trailing : .leading) {
          Circle()
            .fill(.white)
            .frame(width: 21, height: 21)
            .padding(.horizontal, 3)
        }
    }
    .buttonStyle(.plain)
    .opacity(isEnabled ? 1 : 0.45)
  }
}

private struct MobileSiteTile: View {
  let site: TuneSite
  let isSelected: Bool

  var body: some View {
    HStack(spacing: 10) {
      MobileTuneBrandMark(assetName: site.brandAssetName, size: 34, cornerRadius: 8)
      VStack(alignment: .leading, spacing: 2) {
        Text(site.title)
          .font(.system(size: 14, weight: .bold))
        Text("\(site.enabledCount)/\(site.totalCount)")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(TortoiseDesign.secondaryText)
      }
      Spacer()
    }
    .padding(12)
    .frame(maxWidth: .infinity, minHeight: 66)
    .background(isSelected ? TortoiseDesign.accent.opacity(0.18) : TortoiseDesign.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(isSelected ? TortoiseDesign.accent : TortoiseDesign.hairline)
    }
  }
}

/// Renders a site's real brand mark asset, falling back to a plain glyph if the
/// asset isn't bundled for this target (e.g. brand art that only ships in the
/// macOS asset catalog today).
private struct MobileTuneBrandMark: View {
  let assetName: String?
  var size: CGFloat = 34
  var cornerRadius: CGFloat = 8

  private var resolvedImage: Image? {
    guard let assetName, UIImage(named: assetName) != nil else { return nil }
    return Image(assetName)
  }

  var body: some View {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      .fill(Color.white.opacity(0.11))
      .frame(width: size, height: size)
      .overlay {
        if let resolvedImage {
          resolvedImage
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(size * 0.2)
        } else {
          Image(systemName: "globe")
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(TortoiseDesign.secondaryText)
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
  }
}

/// A dimmed, non-interactive tile for a site that isn't tunable yet. No toggles,
/// no fake data - just an honest placeholder until the real tuner ships.
private struct MobileTikTokComingSoonTile: View {
  var body: some View {
    HStack(spacing: 10) {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(Color.white.opacity(0.06))
        .frame(width: 34, height: 34)
        .overlay {
          Image(systemName: "hourglass")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(TortoiseDesign.tertiaryText)
        }
      VStack(alignment: .leading, spacing: 2) {
        Text("TikTok")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(TortoiseDesign.secondaryText)
        Text("Coming soon")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(TortoiseDesign.tertiaryText)
      }
      Spacer()
    }
    .padding(12)
    .frame(maxWidth: .infinity, minHeight: 66)
    .background(TortoiseDesign.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(TortoiseDesign.hairline)
    }
    .opacity(0.55)
  }
}


/// The APPS lane: names what this iPhone can do to native apps (block, limit,
/// schedule) and states the ceiling — tuning inside apps isn't possible — so
/// the website tuners below are never mistaken for app controls.
private struct MobileNativeAppsLaneCard: View {
  let openBlocking: () -> Void

  var body: some View {
    Button(action: openBlocking) {
      MobileCard {
        HStack(spacing: 12) {
          Image(systemName: "square.grid.2x2")
            .foregroundStyle(TortoiseDesign.accent)
            .frame(width: 36, height: 36)
            .background(TortoiseDesign.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
          VStack(alignment: .leading, spacing: 3) {
            Text(TuneScopeCopy.appsLaneTitle)
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(TortoiseDesign.primaryText)
            Text(TuneScopeCopy.appsLaneDetail)
              .font(.system(size: 12))
              .foregroundStyle(TortoiseDesign.secondaryText)
              .multilineTextAlignment(.leading)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(TortoiseDesign.secondaryText)
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("tune-apps-lane")
  }
}

/// Shown only when nothing anywhere is enforcing the website tuners (Safari
/// extension off and no fresh desktop profile). Toggles stay live — settings
/// persist to the account — but the user is told plainly nothing acts yet.
/// The one canonical "connect Safari" flow, launched from every Safari
/// affordance (setup step, Tune banner, scope chip). iOS gives no API to read
/// extension enablement, and an ENABLED extension still runs nowhere until
/// the user allows it on websites inside Safari — so the honest instructions
/// are always the same three steps. The extension's heartbeat auto-verifies
/// the moment they're done; no state guessing.
private struct MobileSafariConnectSheet: View {
  @ObservedObject var screenTime: IOSYouTubeScreenTimeController

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack {
        Text("Connect Safari")
          .font(.system(size: 19, weight: .bold))
          .foregroundStyle(TortoiseDesign.primaryText)
        Spacer()
        if screenTime.safariExtensionConnected {
          Label("Connected", systemImage: "checkmark.circle.fill")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(TortoiseDesign.green)
        }
      }

      step(
        number: "1",
        title: "Enable the extension",
        detail: "Settings → Apps → Safari → Extensions → Tortoise.",
        actionTitle: "Open Settings",
        action: { screenTime.openSafariExtensionSettings() }
      )
      step(
        number: "2",
        title: "Allow it on websites",
        detail: "In Safari, tap the extensions icon in the address bar → Tortoise → Always Allow → on Every Website. Without this, the extension is on but runs nowhere.",
        actionTitle: nil,
        action: nil
      )
      step(
        number: "3",
        title: "Open Safari to verify",
        detail: "Tortoise checks in from the page automatically.",
        actionTitle: "Open Safari",
        action: { screenTime.openSafariVerificationPage() }
      )

      Spacer(minLength: 0)
    }
    .padding(22)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(TortoiseDesign.background)
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("safari-connect-sheet")
    .onAppear {
      screenTime.refreshSetupStatus()
    }
  }

  private func step(
    number: String,
    title: String,
    detail: String,
    actionTitle: String?,
    action: (() -> Void)?
  ) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Text(number)
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(TortoiseDesign.accent)
        .frame(width: 22, height: 22)
        .background(TortoiseDesign.accent.opacity(0.14), in: Circle())
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(TortoiseDesign.primaryText)
        Text(detail)
          .font(.system(size: 12))
          .foregroundStyle(TortoiseDesign.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
        if let actionTitle, let action {
          Button(actionTitle, action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 3)
        }
      }
      Spacer(minLength: 0)
    }
  }
}

private struct MobileTuneSetupFirstBanner: View {
  let enable: () -> Void

  var body: some View {
    MobileCard {
      VStack(alignment: .leading, spacing: 8) {
        Label(TuneScopeCopy.setupFirstTitle, systemImage: "exclamationmark.triangle.fill")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(TortoiseDesign.orange)
        Text(TuneScopeCopy.setupFirstDetail)
          .font(.system(size: 12))
          .foregroundStyle(TortoiseDesign.secondaryText)
        Button(TuneScopeCopy.setupFirstCTA, action: enable)
          .buttonStyle(.borderedProminent)
      }
    }
    .accessibilityIdentifier("tune-setup-first-banner")
  }
}

/// The X account-setting honesty row: X's own "display sensitive media"
/// setting decides whether X serves adult media raw (server-side, everywhere,
/// including the X app), so its state leads the X tuning card. Reloaded on
/// appear and on app-return, because the Safari extension records it while
/// the user is on X's settings page.
private struct MobileXPlatformSafetyRow: View {
  @Environment(\.openURL) private var openURL
  @Environment(\.scenePhase) private var scenePhase
  @State private var snapshot: PlatformControlsSnapshot?

  private var status: XPlatformSafety.Status {
    XPlatformSafety.status(snapshot: snapshot)
  }

  var body: some View {
    MobileCard {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: icon)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(iconColor)
          .padding(.top, 1)
        VStack(alignment: .leading, spacing: 3) {
          Text(XPlatformSafetyCopy.title)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(TortoiseDesign.primaryText)
          Text(XPlatformSafety.detail(for: status))
            .font(.system(size: 12))
            .foregroundStyle(TortoiseDesign.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
          if let actionTitle = XPlatformSafety.actionTitle(for: status) {
            Button(actionTitle) {
              openURL(XPlatformSafety.settingsURL)
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
          }
        }
        Spacer(minLength: 0)
      }
    }
    // Same identifier scoping as the scope card: keep the row id off the
    // inner CTA Button.
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("tune-x-platform-safety")
    .onAppear(perform: reload)
    .onChange(of: scenePhase) { _, phase in
      if phase == .active {
        reload()
      }
    }
  }

  private var icon: String {
    switch status {
    case .unknown: return "questionmark.circle"
    case .exposed: return "exclamationmark.triangle.fill"
    case .protected: return "checkmark.shield.fill"
    }
  }

  private var iconColor: Color {
    switch status {
    case .unknown: return TortoiseDesign.secondaryText
    case .exposed: return TortoiseDesign.orange
    case .protected: return TortoiseDesign.green
    }
  }

  private func reload() {
    snapshot = IOSEnforcementSharedStore.loadPlatformControls(site: "x")
  }
}

private struct MobileTuneScopeChip: View {
  let entry: TuneScopeEntry
  var action: (() -> Void)? = nil

  var body: some View {
    if let action {
      Button(action: action) { content }
        .buttonStyle(.plain)
    } else {
      content
    }
  }

  private var content: some View {
    HStack(spacing: 8) {
      icon
      VStack(alignment: .leading, spacing: 1) {
        Text(entry.title)
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(TortoiseDesign.primaryText)
          .lineLimit(1)
        if let detail = entry.detail {
          Text(detail)
            .font(.system(size: 10))
            .foregroundStyle(TortoiseDesign.secondaryText)
            .lineLimit(1)
        }
      }
      Spacer(minLength: 4)
      HStack(spacing: 5) {
        Text(MobileHubStatusStyle.label(for: entry.status))
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(MobileHubStatusStyle.color(for: entry.status))
        Circle()
          .fill(MobileHubStatusStyle.color(for: entry.status))
          .frame(width: 7, height: 7)
      }
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 7)
    .background(TortoiseDesign.elevatedPanel, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
  }

  @ViewBuilder
  private var icon: some View {
    switch entry.kind {
    case .iphoneSafari:
      Image(systemName: "safari")
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(TortoiseDesign.accent)
        .frame(width: 24, height: 24)
    case .desktopProfile:
      MobileAvatar(text: initials, size: 24)
    }
  }

  private var initials: String {
    let letters = entry.title.split(separator: " ").prefix(2).compactMap(\.first)
    return letters.isEmpty ? "T" : String(letters).uppercased()
  }
}

private struct MobileTuningFeatureRow: View {
  let feature: TuneFeature
  @Binding var isOn: Bool
  var isEnabled = true

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 5) {
        Text(feature.title)
          .font(.system(size: 14, weight: .bold))
        Text(feature.detail)
          .font(.system(size: 12))
          .foregroundStyle(TortoiseDesign.secondaryText)
      }
      Spacer()
      MobileSwitch(isOn: $isOn, isEnabled: isEnabled)
    }
    .opacity(isEnabled ? 1 : 0.55)
  }
}

/// A status-dot row for one `DeviceHubRow`. Mirrors the mac `HubDeviceRow` +
/// `HubStatusStyle` pairing (ProtectionView.swift), scoped locally since that
/// styling type is private to the macOS view file.
private struct MobileHubRow: View {
  let row: DeviceHubRow

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: MobileHubStatusStyle.systemImage(for: row.kind))
        .foregroundStyle(TortoiseDesign.accent)
        .frame(width: 36, height: 36)
        .background(TortoiseDesign.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(row.title)
            .font(.system(size: 14, weight: .bold))
          if row.isCurrentDevice {
            Text("CURRENT")
              .font(.system(size: 9, weight: .bold))
              .foregroundStyle(TortoiseDesign.accent)
          }
        }
        if !row.profiles.isEmpty {
          Text("\(row.profiles.count) profile\(row.profiles.count == 1 ? "" : "s")")
            .font(.system(size: 12))
            .foregroundStyle(TortoiseDesign.secondaryText)
        }
      }
      Spacer()
      HStack(spacing: 6) {
        Text(MobileHubStatusStyle.label(for: row.status))
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(MobileHubStatusStyle.color(for: row.status))
        Circle()
          .fill(MobileHubStatusStyle.color(for: row.status))
          .frame(width: 7, height: 7)
      }
    }
  }
}

private enum MobileHubStatusStyle {
  static func label(for status: ConnectionStatus) -> String {
    switch status {
    case .on: return "On"
    case .attention: return "Tap"
    case .off: return "Off"
    }
  }

  static func color(for status: ConnectionStatus) -> Color {
    switch status {
    case .on: return TortoiseDesign.green
    case .attention: return TortoiseDesign.orange
    case .off: return TortoiseDesign.secondaryText
    }
  }

  static func systemImage(for kind: DeviceKind) -> String {
    switch kind {
    case .mac: return "desktopcomputer"
    case .iphone: return "iphone"
    case .browser: return "globe"
    case .other: return "laptopcomputer"
    }
  }
}

/// Case order is the tab order. Usage leads — it's the daily-use screen;
/// Devices is "set once," so it's last. While setup is incomplete, Usage
/// carries a finish-setup banner that links to Devices, so setup never
/// hijacks navigation. (iOS v1 redesign, docs/design/ios-v1-handoff/.)
private enum MobileSection: String, CaseIterable, Identifiable {
  case usage
  case tuning
  case blocking
  case devices

  var id: String { rawValue }

  var title: String {
    switch self {
    case .usage: return "Usage"
    case .tuning: return "Tune"
    case .blocking: return "Block"
    case .devices: return "Devices"
    }
  }

  var systemImage: String {
    switch self {
    case .usage: return "chart.bar"
    case .tuning: return "slider.horizontal.3"
    case .blocking: return "shield"
    case .devices: return "macbook.and.iphone"
    }
  }
}

private enum MobileAccessMode: String, CaseIterable, Identifiable {
  case open
  case focus
  case strict

  var id: String { rawValue }

  var title: String { rawValue.capitalized }

  var systemImage: String {
    switch self {
    case .open: return "circle"
    case .focus: return "scope"
    case .strict: return "lock.shield"
    }
  }

  var detail: String {
    switch self {
    case .open: return "Clear iOS shields, monitoring, and Safari tuners."
    case .focus: return "Apply selected app/site shields and focus Safari tuners."
    case .strict: return "Apply immediate shields, adult filtering, Safari tuners, and daily limits."
    }
  }

  var iosMode: IOSEnforcementMode {
    switch self {
    case .open:
      return .open
    case .focus:
      return .focus
    case .strict:
      return .strict
    }
  }

  init?(iosMode: IOSEnforcementMode) {
    switch iosMode {
    case .open:
      self = .open
    case .focus:
      self = .focus
    case .strict:
      self = .strict
    }
  }
}

private extension IOSEnforcementConnectionState {
  var shortTitle: String {
    switch self {
    case .connected:
      return "Connected"
    case .partial:
      return "Partial"
    case .setupRequired:
      return "Setup"
    case .repairRequired:
      return "Repair"
    }
  }

  var systemImage: String {
    switch self {
    case .connected:
      return "checkmark.shield.fill"
    case .partial:
      return "circle.lefthalf.filled"
    case .setupRequired:
      return "exclamationmark.circle"
    case .repairRequired:
      return "wrench.and.screwdriver"
    }
  }

  var tint: Color {
    switch self {
    case .connected:
      return TortoiseDesign.green
    case .partial:
      return TortoiseDesign.orange
    case .setupRequired:
      return TortoiseDesign.accent
    case .repairRequired:
      return TortoiseDesign.red
    }
  }
}

private extension IOSEnforcementSetupStep {
  var title: String {
    switch self {
    case .account:
      return "Account"
    case .authorizationMode:
      return "Setup type"
    case .screenTimePermission:
      return "Allow Screen Time"
    case .targets:
      return "Choose apps"
    case .safariExtension:
      return "Safari extension"
    case .mode:
      return "Turn on protection"
    case .sync:
      return "Verify"
    }
  }

  var systemImage: String {
    switch self {
    case .account:
      return "person.crop.circle"
    case .authorizationMode:
      return "iphone"
    case .screenTimePermission:
      return "checkmark.shield"
    case .targets:
      return "square.grid.2x2"
    case .safariExtension:
      return "safari"
    case .mode:
      return "power"
    case .sync:
      return "arrow.triangle.2.circlepath"
    }
  }
}

private extension IOSEnforcementSetupStatus {
  var title: String {
    switch self {
    case .complete:
      return "Done"
    case .needsAction:
      return "Needed"
    case .checking:
      return "Checking"
    case .failed:
      return "Fix"
    }
  }

  var tint: Color {
    switch self {
    case .complete:
      return TortoiseDesign.green
    case .needsAction:
      return TortoiseDesign.accent
    case .checking:
      return TortoiseDesign.orange
    case .failed:
      return TortoiseDesign.red
    }
  }

  func systemImage(default systemImage: String) -> String {
    switch self {
    case .complete:
      return "checkmark.circle.fill"
    case .checking:
      return "clock"
    case .failed:
      return "exclamationmark.triangle.fill"
    case .needsAction:
      return systemImage
    }
  }
}

private extension IOSEnforcementAuthorizationMode {
  var title: String {
    switch self {
    case .individual:
      return "My iPhone"
    case .child:
      return "Child device"
    }
  }

  var systemImage: String {
    switch self {
    case .individual:
      return "iphone"
    case .child:
      return "person.2"
    }
  }
}

private struct MobileUsageDisplay {
  let total: String
  let web: String
  let ios: String
  let apps: [MobileUsageApp]
  let accounts: [MobileUsageAccount]

  init(summary: SiteUsageSummarySnapshot) {
    let entries = summary.entries ?? summary.sites.flatMap(\.entries)
    let webSeconds = entries.filter { !Self.isIOSEntry($0) }.reduce(0) { $0 + ($1.totalSeconds ?? 0) }
    let iosSeconds = entries.filter(Self.isIOSEntry).reduce(0) { $0 + ($1.totalSeconds ?? 0) }

    total = Self.duration(summary.totalSeconds)
    web = webSeconds > 0 ? Self.duration(webSeconds) : "No data"
    ios = iosSeconds > 0 ? Self.duration(iosSeconds) : "No data"
    apps = Self.apps(from: summary)
    accounts = entries.map(Self.account(from:))
  }

  static let empty = MobileUsageDisplay(
    total: "0m",
    web: "No data",
    ios: "No data",
    apps: [],
    accounts: []
  )

  private init(
    total: String,
    web: String,
    ios: String,
    apps: [MobileUsageApp],
    accounts: [MobileUsageAccount]
  ) {
    self.total = total
    self.web = web
    self.ios = ios
    self.apps = apps
    self.accounts = accounts
  }

  private static func apps(from summary: SiteUsageSummarySnapshot) -> [MobileUsageApp] {
    let sorted = summary.sites.sorted { $0.totalSeconds > $1.totalSeconds }
    // Bars scale to the biggest destination (mockup), not the day total.
    let maxSeconds = max(sorted.first?.totalSeconds ?? 0, 1)
    return sorted.prefix(6).map { site in
      let theme = MobileUsageApp.theme(for: site.siteID)
      let percent = Int((Double(site.totalSeconds) / Double(maxSeconds) * 100).rounded())
      return MobileUsageApp(
        letter: theme.letter,
        name: site.displayTitle,
        time: duration(site.totalSeconds),
        detail: Self.activityDetail(for: site),
        percent: max(percent, 3),
        color: theme.color,
        foreground: theme.foreground
      )
    }
  }

  /// "42 videos watched" for YouTube today; lights up for any site the moment
  /// its extension reports an activity count + label (posts land in build 14).
  private static func activityDetail(for site: SiteUsageSnapshot) -> String? {
    let count = site.activityCount ?? site.videoCount ?? 0
    guard count > 0 else {
      return nil
    }
    if site.activityLabel == "videos" || site.siteID == "youtube" {
      return "\(count) video\(count == 1 ? "" : "s") watched"
    }
    if let label = site.activityLabel, !label.isEmpty {
      return "~\(count) \(label) seen"
    }
    return nil
  }

  private static func account(from entry: SiteUsageSourceSnapshot) -> MobileUsageAccount {
    let label = entry.label ?? entry.profileName ?? entry.browserName ?? "Browser profile"
    let email = Self.email(in: label) ?? Self.email(in: entry.profileName ?? "") ?? ""
    let name = entry.profileName?.isEmpty == false ? entry.profileName! : label.components(separatedBy: " · ").first ?? label
    let avatar = String(name.prefix(2)).uppercased()
    return MobileUsageAccount(
      avatar: avatar,
      name: name,
      subtitle: email.isEmpty ? label : "\(email) · \(entry.browserName ?? "Browser")",
      time: duration(entry.totalSeconds ?? 0),
      activity: entry.activityCount.map { "\($0) events" } ?? ""
    )
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

  private static func email(in value: String) -> String? {
    let pattern = #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#
    return value.range(of: pattern, options: [.regularExpression, .caseInsensitive]).map {
      String(value[$0]).lowercased()
    }
  }
}

private struct MobileUsageApp: Identifiable {
  let id = UUID()
  let letter: String
  let name: String
  let time: String
  let detail: String?
  let percent: Int
  let color: Color
  let foreground: Color

  static func theme(for siteID: String) -> (letter: String, color: Color, foreground: Color) {
    switch siteID.lowercased() {
    case "youtube": return ("YT", .red, .white)
    case "x", "twitter": return ("X", .black, .white)
    case "instagram": return ("IG", .pink, .white)
    case "reddit": return ("RD", .orange, .white)
    case "tiktok": return ("TT", .black, .cyan)
    default: return (String(siteID.prefix(2)).uppercased(), TortoiseDesign.elevatedPanel, TortoiseDesign.primaryText)
    }
  }
}

private struct MobileUsageAccount: Identifiable {
  let id = UUID()
  let avatar: String
  let name: String
  let subtitle: String
  let time: String
  let activity: String
}
