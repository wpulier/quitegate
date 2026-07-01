import ClerkKit
import ClerkKitUI
import FamilyControls
import SwiftUI

struct ContentView: View {
  @Environment(Clerk.self) private var clerk
  @StateObject private var model = AccountHubModel()
  @State private var authViewIsPresented = false

  var body: some View {
    Group {
      if clerk.session == nil {
        SignedOutLanding(syncMessage: model.syncMessage, onSignIn: presentAuth)
      } else {
        TortoiseMobileShell(
          accountLabel: accountLabel,
          model: model,
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
      ?? "willpulier1999@gmail.com"
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
          Text("QuietGate")
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

        Text("Sync this iPhone into QuietGate.")
          .font(.largeTitle.bold())
          .foregroundStyle(TortoiseDesign.primaryText)
          .fixedSize(horizontal: false, vertical: true)

        Text("Use the same QuietGate profile for Mac, iPhone, browser helpers, usage summaries, and shared protection policy.")
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
  let refresh: () async -> Void

  @State private var section = MobileSection.usage
  @State private var usageTab = MobileUsageTab.all
  @State private var accessMode = MobileAccessMode.focus
  @State private var selectedSite = MobileTuningSite.youtube
  @State private var conceptStates: [String: Bool] = ["porn": true, "gambling": false, "news": false]
  @State private var featureStates: [String: Bool] = MobileTuningSite.defaultFeatureStates
  @StateObject private var screenTime = IOSYouTubeScreenTimeController()

  var body: some View {
    ZStack(alignment: .bottom) {
      TortoiseDesign.background
        .ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          MobileIOSConnectionBanner(
            screenTime: screenTime,
            syncMessage: model.syncMessage,
            retrySync: refresh,
            fixSetup: { section = .blocking }
          )
          if screenTime.connectionState != .connected {
            MobileIOSGuidedSetupCard(screenTime: screenTime)
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
        screenTime.refreshSetupStatus()
      }

      bottomTabBar
    }
  }

  @ViewBuilder
  private var screenContent: some View {
    switch section {
    case .usage:
      MobileUsageScreen(selectedTab: $usageTab, model: model, screenTime: screenTime)
    case .blocking:
      MobileBlockingScreen(accessMode: $accessMode, conceptStates: $conceptStates, screenTime: screenTime)
    case .tuning:
      MobileTuningScreen(
        selectedSite: $selectedSite,
        featureStates: $featureStates,
        screenTime: screenTime
      )
    case .devices:
      MobileDevicesScreen(accountLabel: accountLabel, model: model, screenTime: screenTime)
    }
  }

  private var bottomTabBar: some View {
    VStack(spacing: 7) {
      HStack(spacing: 0) {
        ForEach(MobileSection.allCases) { tab in
          Button {
            section = tab
          } label: {
            VStack(spacing: 4) {
              Image(systemName: tab.systemImage)
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

      Capsule()
        .fill(Color.white.opacity(0.45))
        .frame(width: 134, height: 5)
        .padding(.bottom, 8)
    }
    .background(.ultraThinMaterial)
    .overlay(alignment: .top) {
      Rectangle()
        .fill(TortoiseDesign.hairline)
        .frame(height: 1)
    }
  }
}

private struct MobileUsageScreen: View {
  @Binding var selectedTab: MobileUsageTab
  @ObservedObject var model: AccountHubModel
  @ObservedObject var screenTime: IOSYouTubeScreenTimeController

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      MobileHeader(kicker: todayLabel, title: "Usage")
      usageTabs
      usageHero

      if selectedTab == .youtube {
        MobileIOSYouTubeStatusCard(screenTime: screenTime)
      }

      if selectedTab == .all {
        byAppCard
      }

      accountsCard
    }
  }

  private var usageTabs: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(MobileUsageTab.allCases) { tab in
          Button {
            selectedTab = tab
          } label: {
            Text(tab.title)
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(selectedTab == tab ? TortoiseDesign.primaryText : TortoiseDesign.secondaryText)
              .padding(.horizontal, 16)
              .padding(.vertical, 9)
              .background(
                selectedTab == tab ? TortoiseDesign.accent.opacity(0.24) : TortoiseDesign.elevatedPanel,
                in: Capsule()
              )
              .overlay {
                Capsule()
                  .strokeBorder(selectedTab == tab ? TortoiseDesign.accent : TortoiseDesign.hairline)
              }
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private var usageHero: some View {
    MobileCard {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text(display.hero.uppercased())
              .font(.system(size: 12, weight: .bold))
              .foregroundStyle(TortoiseDesign.tertiaryText)
            Text(display.total)
              .font(.system(size: 56, weight: .bold))
              .foregroundStyle(TortoiseDesign.primaryText)
              .lineLimit(1)
              .minimumScaleFactor(0.72)
          }
          Spacer()
          MobilePill(text: display.activity)
        }

        Text(display.subtitle)
          .font(.system(size: 14))
          .foregroundStyle(TortoiseDesign.secondaryText)

        HStack(spacing: 10) {
          MobileMetric(value: display.web, label: "Web browsers")
          MobileMetric(value: display.ios, label: "This iPhone")
        }
      }
    }
  }

  private var byAppCard: some View {
    MobileCard {
      VStack(alignment: .leading, spacing: 16) {
        MobileSectionLabel("By app")
        if display.apps.isEmpty {
          MobileEmptyState(
            title: "No usage reported yet",
            detail: "Connect browser helpers or set up iOS Screen Time targets for YouTube app and Safari."
          )
        } else {
          ForEach(display.apps) { app in
            MobileUsageAppRow(app: app)
          }
        }
      }
    }
  }

  private var accountsCard: some View {
    MobileCard {
      VStack(alignment: .leading, spacing: 15) {
        MobileSectionLabel("Accounts")
        if display.accounts.isEmpty {
          MobileEmptyState(
            title: "No account activity",
            detail: "QuietGate will show real synced browser and iOS entries here once they report usage."
          )
        } else {
          ForEach(display.accounts) { account in
            MobileAccountRow(account: account)
          }
        }
      }
    }
  }

  private var display: MobileUsageDisplay {
    if let summary = model.snapshot.siteUsageSummary {
      return MobileUsageDisplay(summary: summary, tab: selectedTab)
    }
    return .empty(tab: selectedTab)
  }

  private var todayLabel: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "'TODAY ·' EEE MMM d"
    return formatter.string(from: Date()).uppercased()
  }
}

private struct MobileBlockingScreen: View {
  @Binding var accessMode: MobileAccessMode
  @Binding var conceptStates: [String: Bool]
  @ObservedObject var screenTime: IOSYouTubeScreenTimeController

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      MobileHeader(
        kicker: nil,
        title: "Blocking",
        subtitle: "Set your mode, commit a session, and choose what's blocked on this iPhone."
      )

      VStack(spacing: 10) {
        ForEach(MobileAccessMode.allCases) { mode in
          Button {
            selectMode(mode)
          } label: {
            MobileModeRow(mode: mode, isSelected: accessMode == mode)
          }
          .buttonStyle(.plain)
        }
      }

      MobileIOSYouTubeStatusCard(screenTime: screenTime)

      MobileCard {
        VStack(alignment: .leading, spacing: 14) {
          Text("Commit to a session")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(TortoiseDesign.primaryText)
          Text("A locked Strict session can't be ended or weakened early - that's the point.")
            .font(.system(size: 13))
            .foregroundStyle(TortoiseDesign.secondaryText)
          HStack(spacing: 8) {
            MobileSessionButton("Focus · 25m") {
              selectMode(.focus)
            }
            MobileSessionButton("Focus · 1h") {
              selectMode(.focus)
            }
            MobileSessionButton("Lock Strict · 2h", systemImage: "lock") {
              selectMode(.strict)
            }
          }
        }
      }

      MobileSectionLabel("Concept blocking")
      MobileCard {
        VStack(spacing: 0) {
          ForEach(MobileConcept.allCases) { concept in
            MobileConceptRow(
              concept: concept,
              isOn: Binding(
                get: { conceptStates[concept.rawValue, default: concept == .porn] },
                set: { conceptStates[concept.rawValue] = $0 }
              )
            )
            if concept != .news {
              MobileDivider()
                .padding(.vertical, 13)
            }
          }
        }
      }

      MobileCard {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: "iphone.gen3")
            .foregroundStyle(TortoiseDesign.accent)
          Text("On iPhone, blocks run through the QuietGate app and Screen Time. Keep QuietGate allowed in Settings > Screen Time for full enforcement.")
            .font(.system(size: 13))
            .foregroundStyle(TortoiseDesign.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }

  private func selectMode(_ mode: MobileAccessMode) {
    accessMode = mode
    screenTime.setMode(mode.iosMode)
  }
}

private struct MobileTuningScreen: View {
  @Binding var selectedSite: MobileTuningSite
  @Binding var featureStates: [String: Bool]
  @ObservedObject var screenTime: IOSYouTubeScreenTimeController

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      MobileHeader(
        kicker: nil,
        title: "Tuning",
        subtitle: "Strip the noisy parts of a site. Applies to the accounts and devices each app is signed into."
      )

      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 150), spacing: 10)],
        spacing: 10
      ) {
        ForEach(MobileTuningSite.allCases) { site in
          Button {
            selectedSite = site
          } label: {
            MobileSiteTile(
              site: site,
              countText: countText(for: site),
              isSelected: selectedSite == site
            )
          }
          .buttonStyle(.plain)
        }

        MobileAddSiteTile()
      }

      MobileCard {
        HStack(spacing: 12) {
          MobileAvatar(text: selectedSite.letter, size: 44, background: selectedSite.color, foreground: selectedSite.foreground, cornerRadius: 10)
          VStack(alignment: .leading, spacing: 3) {
            Text("\(selectedSite.title) cleanup")
              .font(.system(size: 17, weight: .bold))
              .foregroundStyle(TortoiseDesign.primaryText)
            Text(selectedSite.domain)
              .font(.system(size: 13))
              .foregroundStyle(TortoiseDesign.secondaryText)
          }
          Spacer()
          Button(tuningActionTitle) {
            performTuningAction()
          }
          .buttonStyle(.bordered)
          .disabled(selectedSite == .youtube && !screenTime.canApplyShielding)
        }
      }

      if selectedSite == .youtube {
        MobileIOSYouTubeStatusCard(screenTime: screenTime)
      }

      if selectedSite == .youtube {
        MobileCard {
          VStack(alignment: .leading, spacing: 14) {
            MobileSectionLabel("iOS enforcement")
            MobileIOSPolicyRow(
              systemImage: "play.rectangle.fill",
              title: "YouTube app",
              detail: screenTime.selection.applicationTokens.isEmpty ? "Select the native app in Screen Time." : "Selected through Screen Time."
            )
            MobileDivider()
              .padding(.vertical, 2)
            MobileIOSPolicyRow(
              systemImage: "safari.fill",
              title: "YouTube in Safari",
              detail: screenTime.selection.webDomainTokens.isEmpty ? "Select youtube.com as a web domain." : "Selected through Screen Time."
            )
            MobileDivider()
              .padding(.vertical, 2)
            MobileIOSPolicyRow(
              systemImage: "hand.raised.fill",
              title: "Shielding",
              detail: screenTime.shieldingEnabled ? "Selected targets are blocked on this iPhone." : "Ready when you turn on iOS blocking."
            )
          }
        }
      } else {
        MobileCard {
          VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
              Image(systemName: "shield.checkered")
                .foregroundStyle(TortoiseDesign.green)
              Text("Active on")
                .font(.system(size: 13, weight: .bold))
              Text("· browser profiles")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(TortoiseDesign.secondaryText)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 142), spacing: 8)], spacing: 8) {
              MobileScopeChip(avatar: "W", title: "Chrome · Will")
              MobileScopeChip(avatar: "WA", title: "Chrome · wildstudio.ai")
              MobileScopeChip(avatar: "W", title: "Chrome · will")
            }
          }
        }

        MobileCard {
          VStack(spacing: 0) {
            ForEach(Array(selectedSite.features.enumerated()), id: \.element.id) { index, feature in
              if index > 0 {
                MobileDivider()
                  .padding(.vertical, 13)
              }
              MobileTuningFeatureRow(
                feature: feature,
                isOn: Binding(
                  get: { featureStates[feature.id, default: feature.defaultOn] },
                  set: { featureStates[feature.id] = $0 }
                )
              )
            }
          }
        }
      }
    }
  }

  private func enabledCount(for site: MobileTuningSite) -> Int {
    site.features.filter { featureStates[$0.id, default: $0.defaultOn] }.count
  }

  private func countText(for site: MobileTuningSite) -> String {
    if site == .youtube {
      return screenTime.shieldingEnabled ? "iOS on" : (screenTime.hasSelection ? "iOS ready" : "Setup")
    }
    return "\(enabledCount(for: site))/\(site.features.count)"
  }

  private var tuningActionTitle: String {
    if selectedSite == .youtube {
      return screenTime.shieldingEnabled ? "Turn off" : "Turn on"
    }
    return enabledCount(for: selectedSite) == selectedSite.features.count ? "Reset all" : "Hide all"
  }

  private func performTuningAction() {
    if selectedSite == .youtube {
      if screenTime.shieldingEnabled {
        screenTime.turnOff()
      } else {
        screenTime.turnOn()
      }
      return
    }
    toggleAll()
  }

  private func toggleAll() {
    let next = enabledCount(for: selectedSite) != selectedSite.features.count
    for feature in selectedSite.features {
      featureStates[feature.id] = next
    }
  }
}

private struct MobileDevicesScreen: View {
  let accountLabel: String
  @ObservedObject var model: AccountHubModel
  @ObservedObject var screenTime: IOSYouTubeScreenTimeController

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      MobileHeader(
        kicker: nil,
        title: "Devices",
        subtitle: "One QuietGate profile. This iPhone plus every browser profile, kept in sync."
      )

      MobileCard {
        HStack(spacing: 12) {
          MobileAvatar(text: "W", size: 48, background: TortoiseDesign.accent.opacity(0.28))
          VStack(alignment: .leading, spacing: 3) {
            Text("Will Pulier")
              .font(.system(size: 17, weight: .bold))
            Text("\(accountLabel) · Pro")
              .font(.system(size: 13))
              .foregroundStyle(TortoiseDesign.secondaryText)
              .lineLimit(1)
          }
          Spacer()
          VStack(alignment: .trailing, spacing: 1) {
            Text("\(connectionCount)")
              .font(.system(size: 25, weight: .bold))
            Text("connections")
              .font(.system(size: 11, weight: .bold))
              .foregroundStyle(TortoiseDesign.secondaryText)
          }
        }
      }

      MobileSectionLabel("Devices")
      MobileCard {
        VStack(spacing: 0) {
          MobileIOSDeviceStatusRow(screenTime: screenTime, syncMessage: model.syncMessage)
          MobileDivider()
            .padding(.vertical, 13)
          MobileDeviceRow(systemImage: "desktopcomputer", title: "MacBook Pro", badge: nil, subtitle: "QuietGate running · app blocking active")
        }
      }

      MobileSectionLabel("Browser profiles")
      MobileCard {
        VStack(spacing: 0) {
          ForEach(Array(browserRows.enumerated()), id: \.element.id) { index, row in
            if index > 0 {
              MobileDivider()
                .padding(.vertical, 13)
            }
            MobileBrowserProfileRow(row: row)
          }
          Button {
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

  private var connectionCount: Int {
    max(browserRows.count, 3)
  }

  private var browserRows: [MobileBrowserProfile] {
    [
      MobileBrowserProfile(avatar: "W", title: "Chrome · Will", subtitle: "willpulier1999@gmail.com"),
      MobileBrowserProfile(avatar: "WA", title: "Chrome · wildstudio.ai", subtitle: "will@wildstudio.ai"),
      MobileBrowserProfile(avatar: "W", title: "Chrome · will", subtitle: "willpulier8@gmail.com")
    ]
  }
}

private struct MobileIOSConnectionBanner: View {
  @ObservedObject var screenTime: IOSYouTubeScreenTimeController
  let syncMessage: String
  let retrySync: () async -> Void
  let fixSetup: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: screenTime.connectionState.systemImage)
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(screenTime.connectionState.tint)
          .frame(width: 36, height: 36)
          .background(screenTime.connectionState.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 8) {
            Text(screenTime.connectionTitle)
              .font(.system(size: 15, weight: .bold))
              .foregroundStyle(TortoiseDesign.primaryText)
            MobileIOSStatusBadge(text: screenTime.setupProgressText, tint: screenTime.connectionState.tint)
          }
          Text(screenTime.connectionDetail)
            .font(.system(size: 12.5))
            .foregroundStyle(TortoiseDesign.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
          Text(syncMessage)
            .font(.system(size: 11.5))
            .foregroundStyle(TortoiseDesign.tertiaryText)
            .lineLimit(2)
        }

        Spacer(minLength: 0)
      }

      HStack(spacing: 8) {
        Button {
          fixSetup()
        } label: {
          Label(screenTime.connectionState == .connected ? "View setup" : "Fix setup", systemImage: "list.bullet.clipboard")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)

        Button {
          Task {
            await retrySync()
            screenTime.refreshSetupStatus()
          }
        } label: {
          Label("Recheck", systemImage: "arrow.triangle.2.circlepath")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(screenTime.connectionState.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(screenTime.connectionState.tint.opacity(0.35))
    }
  }
}

private struct MobileIOSGuidedSetupCard: View {
  @ObservedObject var screenTime: IOSYouTubeScreenTimeController
  @State private var pickerPresented = false

  var body: some View {
    MobileCard {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top, spacing: 12) {
          MobileAvatar(text: "ON", size: 42, background: TortoiseDesign.green, foreground: .white, cornerRadius: 10)
          VStack(alignment: .leading, spacing: 4) {
            Text("Turn on iOS")
              .font(.system(size: 18, weight: .bold))
              .foregroundStyle(TortoiseDesign.primaryText)
            Text("Finish each setup item once. QuietGate will keep showing exactly what is connected and what still needs attention.")
              .font(.system(size: 13))
              .foregroundStyle(TortoiseDesign.secondaryText)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

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

        VStack(spacing: 0) {
          ForEach(Array(IOSEnforcementSetupStep.allCases.enumerated()), id: \.element.id) { index, step in
            if index > 0 {
              MobileDivider()
                .padding(.vertical, 11)
            }
            MobileIOSSetupStepRow(
              step: step,
              status: screenTime.setupStatus(for: step),
              detail: detail(for: step),
              actionTitle: actionTitle(for: step),
              action: { perform(step) }
            )
          }
        }

        if screenTime.authorizationMode == .child && screenTime.authorizationState != .approved {
          Text("Child device setup requires Family Sharing and a child Apple Account before Screen Time authorization can finish.")
            .font(.system(size: 12))
            .foregroundStyle(TortoiseDesign.orange)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .familyActivityPicker(isPresented: $pickerPresented, selection: $screenTime.selection)
    .onAppear {
      screenTime.refreshSetupStatus()
    }
  }

  private func detail(for step: IOSEnforcementSetupStep) -> String {
    switch step {
    case .account:
      return "Signed in and ready to sync this iPhone."
    case .authorizationMode:
      return "Use My iPhone for self-control or Child device for Family Sharing setup."
    case .screenTimePermission:
      return screenTime.screenTimeStatusTitle
    case .targets:
      return screenTime.targetStatusTitle
    case .safariExtension:
      return screenTime.safariStatusTitle
    case .mode:
      return screenTime.shieldingEnabled ? "\(screenTime.enforcementMode.rawValue.capitalized) is on." : "Turn on Focus or Strict after targets are selected."
    case .sync:
      return screenTime.syncHealth
    }
  }

  private func actionTitle(for step: IOSEnforcementSetupStep) -> String? {
    switch step {
    case .account, .authorizationMode:
      return nil
    case .screenTimePermission:
      return screenTime.authorizationState == .approved ? nil : (screenTime.authorizationState == .denied ? "Retry" : "Allow")
    case .targets:
      return screenTime.authorizationState == .approved ? (screenTime.hasSelection ? "Edit" : "Select") : nil
    case .safariExtension:
      switch screenTime.safariExtensionState {
      case .connected:
        return nil
      case .enabledWaitingForHeartbeat:
        return "Verify"
      default:
        return "Open"
      }
    case .mode:
      return screenTime.shieldingEnabled ? nil : "Turn on"
    case .sync:
      return "Recheck"
    }
  }

  private func perform(_ step: IOSEnforcementSetupStep) {
    switch step {
    case .screenTimePermission:
      Task {
        await screenTime.requestAuthorization()
      }
    case .targets:
      pickerPresented = true
    case .safariExtension:
      if screenTime.safariExtensionState == .enabledWaitingForHeartbeat {
        screenTime.openSafariVerificationPage()
      } else {
        screenTime.openSafariExtensionSettings()
      }
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
  let detail: String
  let actionTitle: String?
  let action: () -> Void

  var body: some View {
    HStack(alignment: .center, spacing: 11) {
      Image(systemName: status.systemImage(default: step.systemImage))
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(status.tint)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 7) {
          Text(step.title)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(TortoiseDesign.primaryText)
          MobileIOSStatusBadge(text: status.title, tint: status.tint)
        }
        Text(detail)
          .font(.system(size: 12))
          .foregroundStyle(TortoiseDesign.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 8)

      if let actionTitle {
        Button(actionTitle, action: action)
          .font(.system(size: 12, weight: .bold))
          .buttonStyle(.bordered)
          .controlSize(.small)
      }
    }
  }
}

private struct MobileIOSDeviceStatusRow: View {
  @ObservedObject var screenTime: IOSYouTubeScreenTimeController
  let syncMessage: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "iphone")
        .foregroundStyle(screenTime.connectionState.tint)
        .frame(width: 36, height: 36)
        .background(screenTime.connectionState.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 6) {
          Text("This iPhone")
            .font(.system(size: 14, weight: .bold))
          Text("CURRENT")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(TortoiseDesign.accent)
          MobileIOSStatusBadge(text: screenTime.connectionState.shortTitle, tint: screenTime.connectionState.tint)
        }
        Text(screenTime.deviceStatusSubtitle)
          .font(.system(size: 12))
          .foregroundStyle(TortoiseDesign.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 8) {
          MobileIOSStatusBadge(text: screenTime.screenTimeStatusTitle, tint: screenTime.authorizationState == .approved ? TortoiseDesign.green : TortoiseDesign.orange)
          MobileIOSStatusBadge(text: screenTime.safariStateTitle, tint: screenTime.safariExtensionConnected ? TortoiseDesign.green : TortoiseDesign.orange)
        }
        Text(syncMessage)
          .font(.system(size: 11.5))
          .foregroundStyle(TortoiseDesign.tertiaryText)
          .lineLimit(2)
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

private struct MobileIOSYouTubeStatusCard: View {
  @ObservedObject var screenTime: IOSYouTubeScreenTimeController
  @State private var pickerPresented = false

  var body: some View {
    MobileCard {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top, spacing: 12) {
          MobileAvatar(text: "iOS", size: 42, background: TortoiseDesign.accent, foreground: .white, cornerRadius: 10)
          VStack(alignment: .leading, spacing: 4) {
            Text("Turn on iOS protection")
              .font(.system(size: 17, weight: .bold))
              .foregroundStyle(TortoiseDesign.primaryText)
            Text("Screen Time blocks selected apps/sites. Safari handles page tuners and web usage.")
              .font(.system(size: 13))
              .foregroundStyle(TortoiseDesign.secondaryText)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 8)
          IOSScreenTimeBadge(state: screenTime.authorizationState)
        }

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

        HStack(spacing: 9) {
          MobileIOSCoverageMetric(title: "Selected", value: screenTime.coverageSummary)
          MobileIOSCoverageMetric(title: "Mode", value: screenTime.enforcementMode.rawValue.capitalized)
          MobileIOSCoverageMetric(title: "Safari", value: screenTime.safariStateTitle)
        }

        Text(screenTime.statusMessage)
          .font(.system(size: 12.5))
          .foregroundStyle(TortoiseDesign.secondaryText)
          .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: 9) {
          if screenTime.authorizationState != .approved {
            Button {
              Task {
                await screenTime.requestAuthorization()
              }
            } label: {
              Label("Allow Screen Time", systemImage: "checkmark.shield")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
          }

          Button {
            pickerPresented = true
          } label: {
            Label(screenTime.hasSelection ? "Edit targets" : "Select targets", systemImage: "plus")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .disabled(screenTime.authorizationState != .approved)
        }

        HStack(spacing: 9) {
          Button {
            if screenTime.shieldingEnabled {
              screenTime.turnOff()
            } else {
              screenTime.turnOn()
            }
          } label: {
            Label(screenTime.shieldingEnabled ? "Turn off" : "Turn on", systemImage: screenTime.shieldingEnabled ? "power" : "shield.checkered")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .disabled(!screenTime.canTurnOn && !screenTime.shieldingEnabled)

          Button {
            screenTime.refreshSetupStatus()
          } label: {
            Label("Recheck", systemImage: "arrow.triangle.2.circlepath")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
        }

        MobileDivider()

        VStack(alignment: .leading, spacing: 10) {
          MobileIOSPolicyRow(
            systemImage: "safari",
            title: screenTime.safariStateTitle,
            detail: safariExtensionDetail
          )
          HStack(spacing: 8) {
            Button {
              screenTime.openSafariExtensionSettings()
            } label: {
              Label("Safari settings", systemImage: "gearshape")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
              screenTime.openSafariVerificationPage()
            } label: {
              Label("Verify", systemImage: "safari")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
          }

          if screenTime.safariExtensionState == .unavailable || screenTime.safariExtensionState == .failed {
            HStack(spacing: 12) {
              Text("Manual fallback")
                .font(.system(size: 12.5, weight: .bold))
              Spacer()
              MobileSwitch(
                isOn: Binding(
                  get: { screenTime.safariExtensionAcknowledged },
                  set: { screenTime.safariExtensionAcknowledged = $0 }
                )
              )
            }
            Text(screenTime.safariManualSetupText)
              .font(.system(size: 11.5))
              .foregroundStyle(TortoiseDesign.secondaryText)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        HStack(spacing: 10) {
          VStack(alignment: .leading, spacing: 3) {
            Text("Daily selected-target limit")
              .font(.system(size: 13, weight: .bold))
            Text(screenTime.limitStatusTitle)
              .font(.system(size: 12))
              .foregroundStyle(TortoiseDesign.secondaryText)
          }
          Spacer()
          HStack(spacing: 8) {
            MobileStepperButton(systemImage: "minus") {
              screenTime.dailyLimitMinutes -= 5
            }
            Text("\(screenTime.dailyLimitMinutes)m")
              .font(.system(size: 13, weight: .bold))
              .frame(width: 48)
            MobileStepperButton(systemImage: "plus") {
              screenTime.dailyLimitMinutes += 5
            }
          }
        }

        VStack(spacing: 0) {
          MobileIOSEnforcementChecklistRow(
            systemImage: "checkmark.shield",
            title: "Screen Time",
            detail: screenTime.screenTimeStatusTitle,
            isComplete: screenTime.authorizationState == .approved
          )
          MobileDivider()
            .padding(.vertical, 11)
          MobileIOSEnforcementChecklistRow(
            systemImage: "square.grid.2x2",
            title: "Targets",
            detail: screenTime.targetStatusTitle,
            isComplete: screenTime.hasSelection
          )
          MobileDivider()
            .padding(.vertical, 11)
          MobileIOSEnforcementChecklistRow(
            systemImage: "safari",
            title: "Safari extension",
            detail: screenTime.safariStatusTitle,
            isComplete: screenTime.safariExtensionConnected
          )
          MobileDivider()
            .padding(.vertical, 11)
          MobileIOSEnforcementChecklistRow(
            systemImage: "calendar.badge.clock",
            title: "Schedules",
            detail: screenTime.schedulesStatusTitle,
            isComplete: screenTime.scheduleActive
          )
          MobileDivider()
            .padding(.vertical, 11)
          MobileIOSEnforcementChecklistRow(
            systemImage: "arrow.triangle.2.circlepath",
            title: "Sync",
            detail: screenTime.syncHealth,
            isComplete: screenTime.syncHealth.contains("current")
          )
        }

        if screenTime.hasSelection {
          Button(role: .destructive) {
            screenTime.clearSelection()
          } label: {
            Label("Clear iOS targets", systemImage: "trash")
              .font(.system(size: 12.5, weight: .bold))
          }
          .buttonStyle(.bordered)
        }
      }
    }
    .familyActivityPicker(isPresented: $pickerPresented, selection: $screenTime.selection)
    .onAppear {
      screenTime.refreshSetupStatus()
    }
  }

  private var safariExtensionDetail: String {
    switch screenTime.safariExtensionState {
    case .connected:
      return "QuietGate has seen the Safari extension recently."
    case .enabledWaitingForHeartbeat:
      return "Open YouTube in Safari once so QuietGate can verify the extension heartbeat."
    case .disabled:
      return "Turn on QuietGate Safari in Settings, then return and recheck."
    case .unavailable:
      return "Use the manual path below on this iOS version, then open YouTube in Safari."
    case .failed:
      return screenTime.safariExtensionStatusError ?? "QuietGate could not read Safari extension status."
    case .unknown:
      return "QuietGate is checking Safari extension status."
    }
  }
}

private struct MobileIOSEnforcementChecklistRow: View {
  let systemImage: String
  let title: String
  let detail: String
  let isComplete: Bool

  var body: some View {
    HStack(spacing: 11) {
      Image(systemName: isComplete ? "checkmark.circle.fill" : systemImage)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(isComplete ? TortoiseDesign.green : TortoiseDesign.secondaryText)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(TortoiseDesign.primaryText)
        Text(detail)
          .font(.system(size: 12))
          .foregroundStyle(TortoiseDesign.secondaryText)
          .lineLimit(2)
          .minimumScaleFactor(0.82)
      }
      Spacer()
    }
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
  }
}

private struct IOSScreenTimeBadge: View {
  let state: IOSScreenTimeAuthorizationState

  var body: some View {
    Text(state.title.uppercased())
      .font(.system(size: 9, weight: .bold))
      .foregroundStyle(state == .approved ? TortoiseDesign.green : TortoiseDesign.orange)
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(Color.white.opacity(0.08), in: Capsule())
  }
}

private struct MobileIOSCoverageMetric: View {
  let title: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title.uppercased())
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(TortoiseDesign.tertiaryText)
      Text(value)
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(TortoiseDesign.primaryText)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(TortoiseDesign.elevatedPanel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}

private struct MobileIOSPolicyRow: View {
  let systemImage: String
  let title: String
  let detail: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(TortoiseDesign.accent)
        .frame(width: 36, height: 36)
        .background(TortoiseDesign.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(TortoiseDesign.primaryText)
        Text(detail)
          .font(.system(size: 12.5))
          .foregroundStyle(TortoiseDesign.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
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
      MobileAvatar(text: app.letter, size: 30, background: app.color, foreground: app.foreground, cornerRadius: 8)
      VStack(alignment: .leading, spacing: 7) {
        HStack {
          Text(app.name)
            .font(.system(size: 14, weight: .bold))
          Spacer()
          Text(app.time)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(TortoiseDesign.secondaryText)
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

private struct MobileConceptRow: View {
  let concept: MobileConcept
  @Binding var isOn: Bool

  var body: some View {
    HStack(spacing: 13) {
      Image(systemName: concept.systemImage)
        .foregroundStyle(concept.tint)
        .frame(width: 38, height: 38)
        .background(concept.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 7) {
          Text(concept.title)
            .font(.system(size: 14, weight: .bold))
          if concept == .porn {
            Text("LOCKED IN STRICT")
              .font(.system(size: 9, weight: .bold))
              .foregroundStyle(TortoiseDesign.purple)
          }
        }
        Text(concept.detail)
          .font(.system(size: 12))
          .foregroundStyle(TortoiseDesign.secondaryText)
      }
      Spacer()
      MobileSwitch(isOn: $isOn, isEnabled: concept == .porn)
    }
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
  let site: MobileTuningSite
  let countText: String
  let isSelected: Bool

  var body: some View {
    HStack(spacing: 10) {
      MobileAvatar(text: site.letter, size: 34, background: site.color, foreground: site.foreground, cornerRadius: 8)
      VStack(alignment: .leading, spacing: 2) {
        Text(site.title)
          .font(.system(size: 14, weight: .bold))
        Text(countText)
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

private struct MobileAddSiteTile: View {
  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "plus")
        .font(.system(size: 18, weight: .bold))
        .foregroundStyle(TortoiseDesign.accent)
      Text("Add app")
        .font(.system(size: 14, weight: .bold))
      Spacer()
    }
    .padding(12)
    .frame(maxWidth: .infinity, minHeight: 66)
    .background(TortoiseDesign.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(TortoiseDesign.hairline)
    }
    .opacity(0.62)
  }
}

private struct MobileScopeChip: View {
  let avatar: String
  let title: String

  var body: some View {
    HStack(spacing: 8) {
      MobileAvatar(text: avatar, size: 24)
      Text(title)
        .font(.system(size: 12, weight: .bold))
        .lineLimit(1)
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 7)
    .background(TortoiseDesign.elevatedPanel, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
  }
}

private struct MobileTuningFeatureRow: View {
  let feature: MobileFeature
  @Binding var isOn: Bool

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
      MobileSwitch(isOn: $isOn)
    }
  }
}

private struct MobileDeviceRow: View {
  let systemImage: String
  let title: String
  let badge: String?
  let subtitle: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .foregroundStyle(TortoiseDesign.accent)
        .frame(width: 36, height: 36)
        .background(TortoiseDesign.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(title)
            .font(.system(size: 14, weight: .bold))
          if let badge {
            Text(badge)
              .font(.system(size: 9, weight: .bold))
              .foregroundStyle(TortoiseDesign.accent)
          }
        }
        Text(subtitle)
          .font(.system(size: 12))
          .foregroundStyle(TortoiseDesign.secondaryText)
      }
    }
  }
}

private struct MobileBrowserProfileRow: View {
  let row: MobileBrowserProfile

  var body: some View {
    HStack(spacing: 12) {
      MobileAvatar(text: row.avatar, size: 34)
      VStack(alignment: .leading, spacing: 3) {
        Text(row.title)
          .font(.system(size: 14, weight: .bold))
        Text(row.subtitle)
          .font(.system(size: 12))
          .foregroundStyle(TortoiseDesign.secondaryText)
      }
    }
  }
}

private enum MobileSection: String, CaseIterable, Identifiable {
  case usage
  case blocking
  case tuning
  case devices

  var id: String { rawValue }

  var title: String {
    switch self {
    case .usage: return "Usage"
    case .blocking: return "Blocking"
    case .tuning: return "Tuning"
    case .devices: return "Devices"
    }
  }

  var systemImage: String {
    switch self {
    case .usage: return "chart.bar"
    case .blocking: return "shield.lefthalf.filled"
    case .tuning: return "slider.horizontal.3"
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
      return "Screen Time"
    case .targets:
      return "Targets"
    case .safariExtension:
      return "Safari extension"
    case .mode:
      return "Turn on"
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

private enum MobileConcept: String, CaseIterable, Identifiable {
  case porn
  case gambling
  case news

  var id: String { rawValue }

  var title: String {
    switch self {
    case .porn: return "Pornography"
    case .gambling: return "Gambling"
    case .news: return "News & doomscroll"
    }
  }

  var detail: String {
    switch self {
    case .porn: return "Blocks adult domains, adult-host media, and explicit pages."
    case .gambling: return "Blocks sportsbook, casino, and betting domains."
    case .news: return "Blocks news aggregators while a session runs."
    }
  }

  var systemImage: String {
    switch self {
    case .porn: return "figure.mixed.cardio"
    case .gambling: return "dice"
    case .news: return "newspaper"
    }
  }

  var tint: Color {
    switch self {
    case .porn: return TortoiseDesign.red
    case .gambling: return TortoiseDesign.orange
    case .news: return TortoiseDesign.accent
    }
  }
}

private enum MobileUsageTab: String, CaseIterable, Identifiable {
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

private enum MobileTuningSite: String, CaseIterable, Identifiable {
  case youtube
  case x
  case instagram
  case reddit
  case tiktok

  var id: String { rawValue }

  var title: String {
    switch self {
    case .youtube: return "YouTube"
    case .x: return "X"
    case .instagram: return "Instagram"
    case .reddit: return "Reddit"
    case .tiktok: return "TikTok"
    }
  }

  var letter: String {
    switch self {
    case .youtube: return "YT"
    case .x: return "X"
    case .instagram: return "IG"
    case .reddit: return "RD"
    case .tiktok: return "TT"
    }
  }

  var domain: String {
    switch self {
    case .youtube: return "youtube.com"
    case .x: return "x.com · twitter.com"
    case .instagram: return "instagram.com"
    case .reddit: return "reddit.com"
    case .tiktok: return "tiktok.com"
    }
  }

  var color: Color {
    switch self {
    case .youtube: return TortoiseDesign.red
    case .x, .tiktok: return .black
    case .instagram: return .pink
    case .reddit: return .orange
    }
  }

  var foreground: Color {
    self == .tiktok ? .cyan : .white
  }

  var features: [MobileFeature] {
    switch self {
    case .youtube:
      return [
        MobileFeature(id: "yt_home", title: "Hide Home Feed", detail: "Open straight to search and subscriptions - no recommendation wall.", defaultOn: true),
        MobileFeature(id: "yt_shorts", title: "Hide Shorts", detail: "Remove Shorts shelves, links, and the Shorts player.", defaultOn: true),
        MobileFeature(id: "yt_recs", title: "Hide Recommended", detail: "Strip recommended videos from the watch sidebar.", defaultOn: true),
        MobileFeature(id: "yt_autoplay", title: "Disable Autoplay", detail: "Stop the next video from rolling automatically.", defaultOn: true),
        MobileFeature(id: "yt_comments", title: "Hide Comments", detail: "Remove the comment section from watch pages.", defaultOn: false),
        MobileFeature(id: "yt_track", title: "Track Time & Videos", detail: "Count active time and unique videos.", defaultOn: true)
      ]
    case .x:
      return [
        MobileFeature(id: "x_sensitive", title: "Hide Sensitive Media", detail: "Hide flagged sensitive and high-confidence explicit posts.", defaultOn: true),
        MobileFeature(id: "x_video", title: "Hide Videos & GIFs", detail: "Remove autoplaying video and GIF players.", defaultOn: true),
        MobileFeature(id: "x_explore", title: "Hide Explore & Trends", detail: "Remove trend modules and Explore entry points.", defaultOn: true),
        MobileFeature(id: "x_photos", title: "Hide Tweet Photos", detail: "Remove inline photos while keeping text.", defaultOn: false),
        MobileFeature(id: "x_cards", title: "Hide Media Cards", detail: "Remove rich link cards with large previews.", defaultOn: false)
      ]
    case .instagram:
      return [
        MobileFeature(id: "ig_reels", title: "Hide Reels", detail: "Remove Reels trays, links, and the Reels player.", defaultOn: true),
        MobileFeature(id: "ig_explore", title: "Hide Explore", detail: "Remove Explore and redirect it back to your feed.", defaultOn: true),
        MobileFeature(id: "ig_suggested", title: "Hide Suggested Posts", detail: "Remove recommended and promoted posts.", defaultOn: true),
        MobileFeature(id: "ig_stories", title: "Hide Stories", detail: "Remove the stories tray at the top of the feed.", defaultOn: false),
        MobileFeature(id: "ig_dms", title: "Hide DMs", detail: "Remove direct-message entry points.", defaultOn: false)
      ]
    case .reddit:
      return [
        MobileFeature(id: "rd_popular", title: "Hide Popular & All", detail: "Remove r/popular and r/all and redirect home.", defaultOn: true),
        MobileFeature(id: "rd_recs", title: "Hide Recommendations", detail: "Remove recommended community modules.", defaultOn: true),
        MobileFeature(id: "rd_nsfw", title: "Hide NSFW Posts & Communities", detail: "Remove mature posts and adult media.", defaultOn: true),
        MobileFeature(id: "rd_media", title: "Hide Media Posts", detail: "Remove image and video posts, keep text.", defaultOn: false),
        MobileFeature(id: "rd_sidebars", title: "Hide Sidebars", detail: "Remove right-rail sidebars and panels.", defaultOn: false)
      ]
    case .tiktok:
      return [
        MobileFeature(id: "tt_foryou", title: "Hide For You Feed", detail: "Open to Following instead of the For You loop.", defaultOn: true),
        MobileFeature(id: "tt_live", title: "Hide LIVE", detail: "Remove LIVE entry points and shelves.", defaultOn: true),
        MobileFeature(id: "tt_explore", title: "Hide Explore", detail: "Remove the Explore tab.", defaultOn: false),
        MobileFeature(id: "tt_track", title: "Track Time", detail: "Count active time across connected profiles.", defaultOn: true),
        MobileFeature(id: "tt_limit", title: "Daily Time Limit · 20m", detail: "Block TikTok after your daily limit.", defaultOn: false)
      ]
    }
  }

  static var defaultFeatureStates: [String: Bool] {
    Dictionary(uniqueKeysWithValues: Self.allCases.flatMap(\.features).map { ($0.id, $0.defaultOn) })
  }
}

private struct MobileFeature: Identifiable {
  let id: String
  let title: String
  let detail: String
  let defaultOn: Bool
}

private struct MobileBrowserProfile: Identifiable {
  let id = UUID()
  let avatar: String
  let title: String
  let subtitle: String
}

private struct MobileUsageDisplay {
  let hero: String
  let total: String
  let subtitle: String
  let activity: String
  let web: String
  let ios: String
  let apps: [MobileUsageApp]
  let accounts: [MobileUsageAccount]

  init(summary: SiteUsageSummarySnapshot, tab: MobileUsageTab) {
    let site = tab == .all ? nil : summary.sites.first { $0.siteID == tab.rawValue }
    let entries = tab == .all ? summary.entries ?? summary.sites.flatMap(\.entries) : site?.entries ?? []
    let totalSeconds = tab == .all ? summary.totalSeconds : site?.totalSeconds ?? 0
    let webSeconds = entries.filter { !Self.isIOSEntry($0) }.reduce(0) { $0 + ($1.totalSeconds ?? 0) }
    let iosSeconds = entries.filter(Self.isIOSEntry).reduce(0) { $0 + ($1.totalSeconds ?? 0) }

    hero = tab == .all ? "Today" : "\(tab.title) today"
    total = Self.duration(totalSeconds)
    subtitle = tab == .all ? "Across connected apps and accounts" : "Today"
    activity = tab == .youtube ? "\(site?.activityCount ?? site?.videoCount ?? 0) videos" : "\(Set(entries.map(Self.accountKey)).count) accounts"
    web = webSeconds > 0 ? Self.duration(webSeconds) : "No data"
    ios = iosSeconds > 0 ? Self.duration(iosSeconds) : "No data"
    apps = tab == .all ? Self.apps(from: summary) : []
    accounts = entries.map(Self.account(from:))
  }

  static func empty(tab: MobileUsageTab) -> MobileUsageDisplay {
    MobileUsageDisplay(
      hero: tab == .all ? "Today" : "\(tab.title) today",
      total: "0m",
      subtitle: tab == .all ? "No synced usage yet" : "No synced \(tab.title) usage yet",
      activity: tab == .youtube ? "0 videos" : "0 accounts",
      web: "No data",
      ios: "No data",
      apps: [],
      accounts: []
    )
  }

  static func mock(tab: MobileUsageTab) -> MobileUsageDisplay {
    switch tab {
    case .all:
      return MobileUsageDisplay(
        hero: "Today",
        total: "9h 33m",
        subtitle: "Across 5 apps and 3 accounts",
        activity: "3 accounts",
        web: "8h 19m",
        ios: "1h 14m",
        apps: [
          MobileUsageApp(letter: "YT", name: "YouTube", time: "6h 39m", percent: 70, color: .red, foreground: .white),
          MobileUsageApp(letter: "X", name: "X", time: "1h 12m", percent: 13, color: .black, foreground: .white),
          MobileUsageApp(letter: "IG", name: "Instagram", time: "48m", percent: 8, color: .pink, foreground: .white),
          MobileUsageApp(letter: "RD", name: "Reddit", time: "33m", percent: 6, color: .orange, foreground: .white),
          MobileUsageApp(letter: "TT", name: "TikTok", time: "21m", percent: 4, color: .black, foreground: .cyan)
        ],
        accounts: mockAccounts
      )
    case .youtube:
      return MobileUsageDisplay(hero: "YouTube today", total: "6h 39m", subtitle: "Today · 62 videos watched", activity: "62 videos", web: "6h 39m", ios: "32m", apps: [], accounts: [
        MobileUsageAccount(avatar: "W", name: "Will", subtitle: "willpulier1999@gmail.com · Chrome", time: "2h 46m", activity: "28 vids"),
        MobileUsageAccount(avatar: "WA", name: "wildstudio.ai", subtitle: "will@wildstudio.ai · Chrome", time: "2h 46m", activity: "28 vids"),
        MobileUsageAccount(avatar: "W", name: "will", subtitle: "willpulier8@gmail.com · Chrome", time: "1h 05m", activity: "6 vids")
      ])
    case .x:
      return MobileUsageDisplay(hero: "X today", total: "1h 12m", subtitle: "Today", activity: "2 accounts", web: "1h 12m", ios: "No data", apps: [], accounts: [
        MobileUsageAccount(avatar: "W", name: "Will", subtitle: "willpulier1999@gmail.com · Chrome", time: "52m", activity: ""),
        MobileUsageAccount(avatar: "WA", name: "wildstudio.ai", subtitle: "will@wildstudio.ai · Chrome", time: "20m", activity: "")
      ])
    case .instagram:
      return MobileUsageDisplay(hero: "Instagram today", total: "48m", subtitle: "Today", activity: "1 account", web: "34m", ios: "14m", apps: [], accounts: [
        MobileUsageAccount(avatar: "WA", name: "wildstudio.ai", subtitle: "will@wildstudio.ai · Chrome", time: "48m", activity: "")
      ])
    case .reddit:
      return MobileUsageDisplay(hero: "Reddit today", total: "33m", subtitle: "Today", activity: "1 account", web: "33m", ios: "No data", apps: [], accounts: [
        MobileUsageAccount(avatar: "W", name: "Will", subtitle: "willpulier1999@gmail.com · Chrome", time: "33m", activity: "")
      ])
    case .tiktok:
      return MobileUsageDisplay(hero: "TikTok today", total: "21m", subtitle: "Today", activity: "1 account", web: "7m", ios: "14m", apps: [], accounts: [
        MobileUsageAccount(avatar: "W", name: "will", subtitle: "willpulier8@gmail.com · Chrome", time: "21m", activity: "")
      ])
    }
  }

  private init(
    hero: String,
    total: String,
    subtitle: String,
    activity: String,
    web: String,
    ios: String,
    apps: [MobileUsageApp],
    accounts: [MobileUsageAccount]
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

  private static let mockAccounts = [
    MobileUsageAccount(avatar: "W", name: "Will", subtitle: "willpulier1999@gmail.com · Chrome", time: "4h 41m", activity: "YouTube, X"),
    MobileUsageAccount(avatar: "WA", name: "wildstudio.ai", subtitle: "will@wildstudio.ai · Chrome", time: "3h 12m", activity: "YT, IG"),
    MobileUsageAccount(avatar: "W", name: "will", subtitle: "willpulier8@gmail.com · Chrome", time: "1h 40m", activity: "YT, TikTok")
  ]

  private static func apps(from summary: SiteUsageSummarySnapshot) -> [MobileUsageApp] {
    let total = max(summary.totalSeconds, 1)
    return summary.sites.prefix(6).map { site in
      let theme = MobileUsageApp.theme(for: site.siteID)
      let percent = Int((Double(site.totalSeconds) / Double(total) * 100).rounded())
      return MobileUsageApp(
        letter: theme.letter,
        name: site.displayTitle,
        time: duration(site.totalSeconds),
        percent: max(percent, 3),
        color: theme.color,
        foreground: theme.foreground
      )
    }
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
