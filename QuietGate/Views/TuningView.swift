import Foundation
import SwiftUI

struct TuningView: View {
  @EnvironmentObject private var store: ProtectionStore
  @State private var selectedSite = BrowserTuningSite.youtube

  var body: some View {
    ProductPage(maxWidth: 720) {
      ProductHeader(
        title: "Tuning",
        subtitle: "Hide noisy parts of supported sites in the browser profiles you connect.",
        systemImage: "slider.horizontal.3"
      )

      sitePicker

      if tuningReady {
        SiteUsagePanel(
          usageTrackingEnabled: featureBinding(.youtubeUsageTracking),
          dailyLimitEnabled: featureBinding(.youtubeDailyLimit),
          dailyLimitMinutes: youtubeDailyLimitMinutesBinding
        )
        tuningRulesSection(for: selectedSite)
      } else {
        TuningNeedsBrowserPanel(site: selectedSite)
        TuningPreviewPanel(site: selectedSite)
      }

      if let extensionBridgeMessage = store.extensionBridgeMessage {
        Label(extensionBridgeMessage, systemImage: "info.circle")
          .font(.callout)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      }

      if let errorMessage = store.errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle")
          .foregroundStyle(.orange)
          .font(.callout)
      }
    }
    .navigationTitle("Tuning")
  }

  private var tuningReady: Bool {
    store.browserBlockingConnected
  }

  private var sitePicker: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Tuned services")
        .font(.headline)

      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 250), spacing: 10, alignment: .leading)],
        alignment: .leading,
        spacing: 10
      ) {
        siteButtons
      }
    }
  }

  @ViewBuilder
  private var siteButtons: some View {
    ForEach(BrowserTuningSite.allCases) { site in
      TuningServiceButton(
        site: site,
        isSelected: selectedSite == site
      ) {
        selectedSite = site
      }
    }
  }

  private func tuningRulesSection(for site: BrowserTuningSite) -> some View {
    ProductPanel(
      title: site.rulesTitle,
      subtitle: site.rulesSubtitle
    ) {
      VStack(alignment: .leading, spacing: 14) {
        TuningProfileRow(
          site: site,
          hasOverrides: hasOverrides(for: site)
        ) {
          store.resetTuningOverrides(for: site)
        }

        ProductDivider()

        VStack(spacing: 0) {
          TuningSiteAllRow(
            site: site,
            enabled: allFeaturesBinding(for: site),
            isAvailable: tuningReady
          )
          .disabled(store.timedSessionLockedActive)

          ForEach(visibleTuningFeatures(for: site)) { feature in
            TuningFeatureRow(
              feature: feature,
              enabled: featureBinding(feature),
              isAvailable: tuningReady
            )
            .disabled(store.timedSessionLockedActive)
          }
        }

        if usesExplicitHideStyle(site) {
          ProductDivider()

          ExplicitHideStyleRow(selection: explicitHideStyleBinding)
            .disabled(store.timedSessionLockedActive)
        }
      }
    }
  }

  private func featureBinding(_ feature: BrowserTuningFeature) -> Binding<Bool> {
    Binding {
      store.tuningFeatureEnabled(feature)
    } set: { enabled in
      store.setTuningFeature(feature, enabled: enabled)
    }
  }

  private func allFeaturesBinding(for site: BrowserTuningSite) -> Binding<Bool> {
    Binding {
      let features = visibleTuningFeatures(for: site)
      return !features.isEmpty && features.allSatisfy { store.tuningFeatureEnabled($0) }
    } set: { enabled in
      store.setTuningFeatures(visibleTuningFeatures(for: site), enabled: enabled)
    }
  }

  private func hasOverrides(for site: BrowserTuningSite) -> Bool {
    BrowserTuningFeature.features(for: site).contains { feature in
      store.tuningOverrides[feature.rawValue] != nil
    }
  }

  private var explicitHideStyleBinding: Binding<ExplicitHideStyle> {
    Binding {
      store.tuningOptions.explicitHideStyle
    } set: { style in
      store.setExplicitHideStyle(style)
    }
  }

  private var youtubeDailyLimitMinutesBinding: Binding<Int> {
    Binding {
      store.tuningOptions.youtubeDailyLimitMinutes
    } set: { minutes in
      store.setYouTubeDailyLimitMinutes(minutes)
    }
  }

  private func usesExplicitHideStyle(_ site: BrowserTuningSite) -> Bool {
    site == .x || site == .reddit
  }

  private func visibleTuningFeatures(for site: BrowserTuningSite) -> [BrowserTuningFeature] {
    let features = BrowserTuningFeature.features(for: site)
    guard site == .youtube else {
      return features
    }
    return features.filter { feature in
      feature != .youtubeUsageTracking && feature != .youtubeDailyLimit
    }
  }
}

private struct SiteUsagePanel: View {
  @EnvironmentObject private var store: ProtectionStore
  @Binding var usageTrackingEnabled: Bool
  @Binding var dailyLimitEnabled: Bool
  @Binding var dailyLimitMinutes: Int
  @State private var selectedTab = TortoiseUsageTab.all

  var body: some View {
    ProductPanel(
      title: "Tortoise usage",
      subtitle: "Today across connected browser profiles, with iOS ready when device sync reports data."
    ) {
      VStack(alignment: .leading, spacing: 16) {
        Picker("Usage app", selection: $selectedTab) {
          ForEach(TortoiseUsageTab.allCases) { tab in
            Text(tab.title).tag(tab)
          }
        }
        .pickerStyle(.segmented)

        statsGrid
        devicesList

        if selectedTab == .youtube {
          ProductDivider()
          youtubeControls
        }
      }
    }
  }

  private var statsGrid: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 150), spacing: 10, alignment: .leading)],
      alignment: .leading,
      spacing: 10
    ) {
      YouTubeUsageStatTile(
        title: "Today",
        value: durationText(selectedUsage.totalSeconds),
        systemImage: "clock"
      )
      YouTubeUsageStatTile(
        title: selectedUsage.activityTitle,
        value: selectedUsage.activityValue,
        systemImage: selectedTab == .youtube ? "play.rectangle" : "person.2"
      )
      YouTubeUsageStatTile(
        title: "All time",
        value: durationText(selectedUsage.lifetimeSeconds),
        systemImage: "chart.bar"
      )
      YouTubeUsageStatTile(
        title: "Status",
        value: statusText,
        systemImage: selectedUsage.limitReached ? "lock.fill" : "checkmark.circle"
      )
    }
  }

  private var devicesList: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Devices")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      VStack(spacing: 8) {
        ForEach(deviceRows) { row in
          HStack(spacing: 10) {
            Text(row.icon)
              .font(.caption.weight(.bold))
              .foregroundStyle(row.connected ? .primary : .secondary)
              .frame(width: 34, height: 34)
              .background(
                Color.secondary.opacity(row.connected ? 0.14 : 0.08),
                in: RoundedRectangle(cornerRadius: row.id == "ios" ? 10 : 17)
              )

            VStack(alignment: .leading, spacing: 2) {
              Text(row.title)
                .font(.callout.weight(.semibold))
              Text(row.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(row.connected ? durationText(row.totalSeconds) : "No data")
              .font(.callout.weight(.semibold))
              .foregroundStyle(row.connected ? .primary : .secondary)
          }
          .padding(10)
          .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
          .opacity(row.connected ? 1 : 0.58)
        }
      }
    }
  }

  private var youtubeControls: some View {
    VStack(alignment: .leading, spacing: 12) {
      Toggle(isOn: $usageTrackingEnabled) {
        Label("Track time and videos", systemImage: "clock")
      }
      .toggleStyle(.switch)
      .disabled(store.timedSessionLockedActive)

      Toggle(isOn: $dailyLimitEnabled) {
        Label("Daily time limit", systemImage: "timer")
      }
      .toggleStyle(.switch)
      .disabled(store.timedSessionLockedActive)

      Stepper(
        "Limit: \(dailyLimitMinutes) minutes",
        value: $dailyLimitMinutes,
        in: BrowserTuningOptions.youtubeDailyLimitRange,
        step: 5
      )
      .disabled(store.timedSessionLockedActive || !dailyLimitEnabled)
    }
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
    helperSnapshots
      .compactMap(\.siteUsageSummary)
      .sorted(by: { lhs, rhs in
        (lhs.lastUpdatedAt ?? .distantPast) > (rhs.lastUpdatedAt ?? .distantPast)
      })
      .first
  }

  private var latestYouTubeSummary: YouTubeUsageSummarySnapshot? {
    helperSnapshots
      .compactMap(\.youtubeUsageSummary)
      .sorted(by: { lhs, rhs in
        (lhs.lastUpdatedAt ?? .distantPast) > (rhs.lastUpdatedAt ?? .distantPast)
      })
      .first
  }

  private var latestYouTubeUsage: YouTubeUsageSnapshot? {
    helperSnapshots
      .map(\.youtubeUsage)
      .compactMap { $0 }
      .sorted { lhs, rhs in
        (lhs.lastUpdatedAt ?? .distantPast) > (rhs.lastUpdatedAt ?? .distantPast)
      }
      .first
  }

  private var selectedUsage: TortoiseUsageDisplay {
    if let summary = latestSiteSummary {
      switch selectedTab {
      case .all:
        return TortoiseUsageDisplay(
          id: "all",
          title: "All",
          totalSeconds: summary.totalSeconds,
          lifetimeSeconds: summary.lifetimeSeconds,
          activityCount: summary.activityCount ?? 0,
          activityLabel: nil,
          limitSeconds: nil,
          limitReached: false,
          sources: (summary.entries ?? summary.sites.flatMap(\.entries)).map(TortoiseUsageSource.init)
        )
      case .youtube, .x, .instagram, .reddit:
        if let site = summary.sites.first(where: { $0.siteID == selectedTab.rawValue }) {
          return TortoiseUsageDisplay(site: site)
        }
      }
    }

    if selectedTab == .all || selectedTab == .youtube {
      if let summary = latestYouTubeSummary {
        return TortoiseUsageDisplay(youtube: summary)
      }
      if let usage = latestYouTubeUsage {
        return TortoiseUsageDisplay(youtube: usage)
      }
    }

    return .empty(tab: selectedTab)
  }

  private var deviceRows: [TortoiseUsageDeviceRow] {
    let iosSources = selectedUsage.sources.filter(\.isIOS)
    let webSources = selectedUsage.sources.filter { !$0.isIOS }
    let browserNames = Set(webSources.map(\.browserName).filter { !$0.isEmpty }).sorted()
    return [
      TortoiseUsageDeviceRow(
        id: "web",
        title: "Web browser",
        subtitle: webSources.isEmpty ? "No browser data yet" : (browserNames.isEmpty ? "Connected profiles" : browserNames.joined(separator: ", ")),
        icon: "WEB",
        connected: !webSources.isEmpty,
        totalSeconds: webSources.reduce(0) { $0 + $1.totalSeconds }
      ),
      TortoiseUsageDeviceRow(
        id: "ios",
        title: "iOS",
        subtitle: iosSources.isEmpty ? "Not connected" : "Connected",
        icon: "iOS",
        connected: !iosSources.isEmpty,
        totalSeconds: iosSources.reduce(0) { $0 + $1.totalSeconds }
      )
    ]
  }

  private var statusText: String {
    guard selectedUsage.hasData else {
      return "Waiting"
    }
    if selectedUsage.limitReached {
      return "Limit hit"
    }
    guard let limitSeconds = selectedUsage.limitSeconds, limitSeconds > 0 else {
      return "Tracking"
    }
    let remaining = max(limitSeconds - selectedUsage.totalSeconds, 0)
    return "\(durationText(remaining)) left"
  }

  private func durationText(_ seconds: Int) -> String {
    let total = max(seconds, 0)
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    if hours > 0 {
      return "\(hours)h \(String(format: "%02d", minutes))m"
    }
    return "\(minutes)m"
  }
}

private enum TortoiseUsageTab: String, CaseIterable, Identifiable {
  case all
  case youtube
  case x
  case instagram
  case reddit

  var id: String { rawValue }

  var title: String {
    switch self {
    case .all: return "All"
    case .youtube: return "YouTube"
    case .x: return "X"
    case .instagram: return "Instagram"
    case .reddit: return "Reddit"
    }
  }
}

private struct TortoiseUsageDisplay {
  let id: String
  let title: String
  let totalSeconds: Int
  let lifetimeSeconds: Int
  let activityCount: Int
  let activityLabel: String?
  let limitSeconds: Int?
  let limitReached: Bool
  let sources: [TortoiseUsageSource]

  var hasData: Bool {
    totalSeconds > 0 || !sources.isEmpty
  }

  var activityTitle: String {
    if activityLabel == "videos" {
      return "Videos"
    }
    return "Accounts"
  }

  var activityValue: String {
    if activityLabel == "videos" {
      return "\(activityCount)"
    }
    return "\(Set(sources.map(\.accountKey)).count)"
  }

  static func empty(tab: TortoiseUsageTab) -> TortoiseUsageDisplay {
    TortoiseUsageDisplay(
      id: tab.rawValue,
      title: tab.title,
      totalSeconds: 0,
      lifetimeSeconds: 0,
      activityCount: 0,
      activityLabel: tab == .youtube ? "videos" : nil,
      limitSeconds: nil,
      limitReached: false,
      sources: []
    )
  }

  init(
    id: String,
    title: String,
    totalSeconds: Int,
    lifetimeSeconds: Int,
    activityCount: Int,
    activityLabel: String?,
    limitSeconds: Int?,
    limitReached: Bool,
    sources: [TortoiseUsageSource]
  ) {
    self.id = id
    self.title = title
    self.totalSeconds = totalSeconds
    self.lifetimeSeconds = lifetimeSeconds
    self.activityCount = activityCount
    self.activityLabel = activityLabel
    self.limitSeconds = limitSeconds
    self.limitReached = limitReached
    self.sources = sources
  }

  init(site: SiteUsageSnapshot) {
    self.init(
      id: site.siteID,
      title: site.displayTitle,
      totalSeconds: site.totalSeconds,
      lifetimeSeconds: site.lifetimeSeconds,
      activityCount: site.activityCount ?? site.videoCount ?? 0,
      activityLabel: site.activityLabel,
      limitSeconds: site.limitSeconds,
      limitReached: site.limitReached ?? false,
      sources: site.entries.map(TortoiseUsageSource.init)
    )
  }

  init(youtube summary: YouTubeUsageSummarySnapshot) {
    self.init(
      id: "youtube",
      title: "YouTube",
      totalSeconds: summary.totalSeconds,
      lifetimeSeconds: summary.lifetimeSeconds,
      activityCount: summary.videoCount,
      activityLabel: "videos",
      limitSeconds: summary.limitSeconds,
      limitReached: summary.limitReached,
      sources: summary.entries.map(TortoiseUsageSource.init)
    )
  }

  init(youtube usage: YouTubeUsageSnapshot) {
    self.init(
      id: "youtube",
      title: "YouTube",
      totalSeconds: usage.totalSeconds,
      lifetimeSeconds: usage.lifetimeSeconds,
      activityCount: usage.videoCount,
      activityLabel: "videos",
      limitSeconds: usage.limitSeconds,
      limitReached: usage.limitReached,
      sources: []
    )
  }
}

private struct TortoiseUsageSource {
  let id: String
  let sourceType: String
  let browserName: String
  let profileID: String
  let profileName: String
  let label: String
  let totalSeconds: Int

  var accountKey: String {
    email(in: label) ?? email(in: profileName) ?? "\(browserName):\(profileID)"
  }

  var isIOS: Bool {
    [sourceType, browserName, profileID, profileName, label, id]
      .joined(separator: " ")
      .range(of: #"ios|iphone|ipad"#, options: [.regularExpression, .caseInsensitive]) != nil
  }

  init(_ source: SiteUsageSourceSnapshot) {
    id = source.id
    sourceType = source.sourceType ?? "browser"
    browserName = source.browserName ?? source.deviceName ?? ""
    profileID = source.profileID ?? ""
    profileName = source.profileName ?? ""
    label = source.label ?? ""
    totalSeconds = source.totalSeconds ?? source.siteUsage?.totalSeconds ?? 0
  }

  init(_ source: YouTubeUsageSourceSnapshot) {
    id = source.id
    sourceType = "browser"
    browserName = source.browserName ?? ""
    profileID = source.profileID ?? ""
    profileName = source.profileName ?? ""
    label = source.label ?? ""
    totalSeconds = source.youtubeUsage.totalSeconds
  }

  private func email(in value: String) -> String? {
    let pattern = #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#
    return value.range(of: pattern, options: [.regularExpression, .caseInsensitive]).map {
      String(value[$0]).lowercased()
    }
  }
}

private struct TortoiseUsageDeviceRow: Identifiable {
  let id: String
  let title: String
  let subtitle: String
  let icon: String
  let connected: Bool
  let totalSeconds: Int
}

private struct YouTubeUsageStatTile: View {
  let title: String
  let value: String
  let systemImage: String

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      Image(systemName: systemImage)
        .foregroundStyle(.red)
        .frame(width: 18)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(value)
          .font(.headline.weight(.semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.82)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
    .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct ExplicitHideStyleRow: View {
  let selection: Binding<ExplicitHideStyle>

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .center, spacing: 14) {
        label
        Spacer(minLength: 16)
        picker
          .frame(width: 310)
      }

      VStack(alignment: .leading, spacing: 10) {
        label
        picker
      }
    }
  }

  private var label: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "rectangle.compress.vertical")
        .font(.callout.weight(.semibold))
        .foregroundStyle(.blue)
        .frame(width: 22)
        .padding(.top, 1)

      VStack(alignment: .leading, spacing: 3) {
        Text("Explicit content action")
          .font(.callout.weight(.semibold))
        Text("Controls X explicit-cue posts and Reddit NSFW posts.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var picker: some View {
    Picker("Explicit content action", selection: selection) {
      ForEach(ExplicitHideStyle.allCases) { style in
        Text(style.title).tag(style)
      }
    }
    .labelsHidden()
    .pickerStyle(.segmented)
  }
}

private struct TuningProfileRow: View {
  @EnvironmentObject private var store: ProtectionStore
  let site: BrowserTuningSite
  let hasOverrides: Bool
  let resetOverrides: () -> Void

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: 14) {
        profileSummary
        Spacer(minLength: 16)
        actionRow
          .padding(.top, 2)
      }

      VStack(alignment: .leading, spacing: 12) {
        profileSummary
        actionRow
      }
    }
  }

  private var profileSummary: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "person.crop.circle.badge.checkmark")
        .font(.callout.weight(.semibold))
        .foregroundStyle(.green)
        .frame(width: 22)
        .padding(.top, 1)

      VStack(alignment: .leading, spacing: 3) {
        Text("Where tuning runs")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(profileScopeText)
          .font(.callout.weight(.semibold))
          .foregroundStyle(.primary)
          .fixedSize(horizontal: false, vertical: true)
        Text("Uses the \(site.title) account signed into each listed profile. To add another profile, open it first.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var actionRow: some View {
    ProductActionRow {
      Button {
        runConnectionAction()
      } label: {
        Label(connectionActionTitle, systemImage: connectionActionSystemImage)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      .disabled(store.isWorking)
      .help("Open the browser profile you want to add, then click Add Profile.")

      if hasOverrides {
        Button {
          resetOverrides()
        } label: {
          Label("Reset", systemImage: "arrow.counterclockwise")
        }
        .controlSize(.small)
        .disabled(store.timedSessionLockedActive)
        .help("Reset \(site.title) tuning to the current mode defaults.")
      }
    }
  }

  private var browser: BrowserConnectorSnapshot {
    store.primaryBrowserConnector
  }

  private var helperState: ChromeHelperState {
    browser.id == .chrome
      ? store.chromeHelperState
      : (store.browserHelperStates[browser.id] ?? .notInstalled)
  }

  private var profileScopeText: String {
    store.connectedBrowserProfileScopeText
      ?? "\(browser.displayName) profile: connected"
  }

  private var connectionActionTitle: String {
    if helperState == .nativeHostMissing {
      return "Update Connection"
    }
    if helperState == .extensionNeedsReload {
      return "Open Extensions"
    }
    return "Add Profile"
  }

  private var connectionActionSystemImage: String {
    if helperState == .nativeHostMissing {
      return "arrow.triangle.2.circlepath"
    }
    if helperState == .extensionNeedsReload {
      return "puzzlepiece.extension"
    }
    return "person.crop.circle.badge.plus"
  }

  private func runConnectionAction() {
    if helperState == .nativeHostMissing {
      store.installBrowserBridge(browser.id)
    } else if helperState == .extensionNeedsReload {
      store.openBrowserExtensionsPage(browser.id)
    } else {
      store.launchBrowserTunerSession(browser.id)
    }
  }
}

private struct TuningServiceButton: View {
  @EnvironmentObject private var store: ProtectionStore
  let site: BrowserTuningSite
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(alignment: .center, spacing: 12) {
        TuningServiceIcon(site: site)

        VStack(alignment: .leading, spacing: 3) {
          Text(site.title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)

          Text(site.domainsLabel)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)

          Text("\(configuredFeatureCount) of \(featureCount) configured")
            .font(.caption)
            .foregroundStyle(.secondary)

          if let tunerHealthText {
            Text(tunerHealthText)
              .font(.caption2)
              .foregroundStyle(tunerHealthColor)
              .lineLimit(1)
          }
        }

        Spacer(minLength: 6)

        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.title3.weight(.semibold))
          .foregroundStyle(isSelected ? .blue : .secondary)
          .accessibilityHidden(true)
      }
      .padding(12)
      .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
      .background(background, in: RoundedRectangle(cornerRadius: 8))
      .overlay {
        RoundedRectangle(cornerRadius: 8)
          .strokeBorder(borderColor, lineWidth: isSelected ? 1.5 : 1)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(site.title), \(site.domainsLabel)")
    .accessibilityValue(isSelected ? "Selected" : "Not selected")
    .help("Show \(site.title) tuning switches.")
  }

  private var background: Color {
    isSelected ? Color.blue.opacity(0.11) : Color.secondary.opacity(0.07)
  }

  private var borderColor: Color {
    isSelected ? Color.blue.opacity(0.60) : Color(nsColor: .separatorColor).opacity(0.35)
  }

  private var featureCount: Int {
    BrowserTuningFeature.features(for: site).count
  }

  private var configuredFeatureCount: Int {
    BrowserTuningFeature.features(for: site).filter { store.tuningFeatureEnabled($0) }.count
  }

  private var tunerHealth: BrowserTunerHealthSnapshot? {
    let connected = store.connectedBrowserConnectors.compactMap { connector in
      store.browserHelperSnapshots[connector.id]?.tunerHealth?[site.rawValue]
    }
    let candidates = connected.isEmpty
      ? [store.browserHelperSnapshots[store.primaryBrowserConnector.id]?.tunerHealth?[site.rawValue]].compactMap { $0 }
      : connected
    return candidates
      .sorted { lhs, rhs in
        (lhs.lastCheckedAt ?? .distantPast) > (rhs.lastCheckedAt ?? .distantPast)
      }
      .first
  }

  private var tunerHealthText: String? {
    guard store.browserBlockingConnected else {
      return nil
    }
    guard let tunerHealth else {
      return "Waiting for browser check"
    }
    if tunerHealth.staleTabCount > 0 {
      return "Browser tuner needs refresh"
    }
    if tunerHealth.loadedTabCount == 0 {
      return "No open \(site.title) tabs checked"
    }
    if tunerHealth.hiddenCount > 0 {
      let noun = tunerHealth.hiddenCount == 1 ? "surface" : "surfaces"
      return "\(tunerHealth.hiddenCount) \(noun) hidden in open tabs"
    }
    if site == .instagram, !tunerHealth.activeFeatureKeys.isEmpty {
      return "No matching Instagram surfaces hidden"
    }
    return "Fresh tuner checked in open tabs"
  }

  private var tunerHealthColor: Color {
    guard let tunerHealth else {
      return .secondary
    }
    if tunerHealth.staleTabCount > 0 {
      return .orange
    }
    if site == .instagram,
       tunerHealth.loadedTabCount > 0,
       tunerHealth.hiddenCount == 0,
       !tunerHealth.activeFeatureKeys.isEmpty {
      return .secondary
    }
    return .secondary
  }
}

private struct TuningServiceIcon: View {
  let site: BrowserTuningSite

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.white)

      Image(site.brandAssetName)
        .resizable()
        .renderingMode(.original)
        .scaledToFit()
        .padding(iconPadding)
    }
    .frame(width: 46, height: 46)
    .overlay {
      RoundedRectangle(cornerRadius: 8)
        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35))
    }
    .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
    .accessibilityHidden(true)
  }

  private var iconPadding: CGFloat {
    switch site {
    case .youtube: return 8
    case .x: return 10
    case .instagram: return 8
    case .reddit: return 7
    }
  }
}

private struct TuningNeedsBrowserPanel: View {
  @EnvironmentObject private var store: ProtectionStore
  let site: BrowserTuningSite

  var body: some View {
    ProductCallout(
      title: site.connectionTitle,
      detail: detail,
      systemImage: site.systemImage,
      tint: .blue
    ) {
      Button {
        runConnectionAction()
      } label: {
        Label(actionTitle, systemImage: actionSystemImage)
      }
      .buttonStyle(.borderedProminent)
      .disabled(store.isWorking)
    }
  }

  private var detail: String {
    let browser = store.primaryBrowserConnector
    let state = browser.id == .chrome
      ? store.chromeHelperState
      : (store.browserHelperStates[browser.id] ?? .notInstalled)

    switch state {
    case .current:
      return "\(browser.displayName) is connected."
    case .nativeHostMissing:
      return "Update the \(browser.displayName) connection, then open \(browser.displayName) once so QuietGate can check it."
    case .needsChromeOpen, .needsSync, .stale:
      return "Open \(browser.displayName) once so QuietGate can confirm \(site.title) tuning will run."
    case .extensionNeedsReload:
      return "Reload the QuietGate extension in \(browser.displayName), then refresh \(site.title) so tuning uses the latest code."
    case .error(let message):
      return "\(browser.displayName) needs attention: \(message)"
    case .notInstalled:
      return "QuietGate needs one supported browser connection because site tuning changes pages inside the browser."
    }
  }

  private var actionTitle: String {
    let browser = store.primaryBrowserConnector
    let state = browser.id == .chrome
      ? store.chromeHelperState
      : (store.browserHelperStates[browser.id] ?? .notInstalled)
    if state == .nativeHostMissing {
      return "Update \(browser.displayName)"
    }
    if state == .extensionNeedsReload {
      return "Open Extensions"
    }
    return "Connect \(browser.displayName)"
  }

  private var actionSystemImage: String {
    let browser = store.primaryBrowserConnector
    let state = browser.id == .chrome
      ? store.chromeHelperState
      : (store.browserHelperStates[browser.id] ?? .notInstalled)
    if state == .nativeHostMissing {
      return "arrow.triangle.2.circlepath"
    }
    if state == .extensionNeedsReload {
      return "puzzlepiece.extension"
    }
    return "play.circle"
  }

  private func runConnectionAction() {
    let browser = store.primaryBrowserConnector
    let state = browser.id == .chrome
      ? store.chromeHelperState
      : (store.browserHelperStates[browser.id] ?? .notInstalled)
    if state == .nativeHostMissing {
      store.installBrowserBridge(browser.id)
    } else if state == .extensionNeedsReload {
      store.openBrowserExtensionsPage(browser.id)
    } else {
      store.launchBrowserTunerSession(browser.id)
    }
  }
}

private struct TuningPreviewPanel: View {
  let site: BrowserTuningSite

  var body: some View {
    ProductPanel(title: "What unlocks after a browser connects", subtitle: site.subtitle) {
      VStack(alignment: .leading, spacing: 12) {
        ForEach(BrowserTuningFeature.features(for: site)) { feature in
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
              .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
              Text(feature.title)
                .font(.callout.weight(.medium))
              Text(feature.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
      }
    }
  }
}

private struct TuningFeatureRow: View {
  let feature: BrowserTuningFeature
  @Binding var enabled: Bool
  let isAvailable: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: iconName)
        .foregroundStyle(iconColor)
        .frame(width: 18)
        .help(helpText)

      VStack(alignment: .leading, spacing: 3) {
        Text(feature.title)
          .font(.callout.weight(.medium))
        Text(feature.detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 12)

      Toggle(feature.title, isOn: $enabled)
        .labelsHidden()
        .toggleStyle(.switch)
        .help(helpText)
    }
    .padding(.vertical, 9)
    .overlay(alignment: .bottom) {
      ProductDivider()
    }
  }

  private var iconName: String {
    if !isAvailable {
      return "lock"
    }
    return enabled ? "checkmark.circle.fill" : "circle"
  }

  private var iconColor: Color {
    if !isAvailable {
      return .secondary
    }
    return enabled ? .green : .secondary
  }

  private var helpText: String {
    if !isAvailable {
      return "Connect a browser before changing \(feature.site.title) tuning."
    }
    return enabled ? "\(feature.title) is on." : "\(feature.title) is off."
  }
}

private struct TuningSiteAllRow: View {
  let site: BrowserTuningSite
  @Binding var enabled: Bool
  let isAvailable: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: iconName)
        .foregroundStyle(iconColor)
        .frame(width: 18)
        .help(helpText)

      VStack(alignment: .leading, spacing: 3) {
        Text("All")
          .font(.callout.weight(.semibold))
        Text("Turns every \(site.title) cleanup option on or off.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 12)

      Toggle("All \(site.title) cleanup options", isOn: $enabled)
        .labelsHidden()
        .toggleStyle(.switch)
        .help(helpText)
    }
    .padding(.vertical, 9)
    .overlay(alignment: .bottom) {
      ProductDivider()
    }
  }

  private var iconName: String {
    if !isAvailable {
      return "lock"
    }
    return enabled ? "checkmark.circle.fill" : "circle"
  }

  private var iconColor: Color {
    if !isAvailable {
      return .secondary
    }
    return enabled ? .green : .secondary
  }

  private var helpText: String {
    if !isAvailable {
      return "Connect a browser before changing \(site.title) tuning."
    }
    return enabled ? "All \(site.title) cleanup options are on." : "Some \(site.title) cleanup options are off."
  }
}
