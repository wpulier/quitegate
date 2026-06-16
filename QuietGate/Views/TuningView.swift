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
        if selectedSite == .youtube {
          YouTubeUsagePanel(
            usageTrackingEnabled: featureBinding(.youtubeUsageTracking),
            dailyLimitEnabled: featureBinding(.youtubeDailyLimit),
            dailyLimitMinutes: youtubeDailyLimitMinutesBinding
          )
        }
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

private struct YouTubeUsagePanel: View {
  @EnvironmentObject private var store: ProtectionStore
  @Binding var usageTrackingEnabled: Bool
  @Binding var dailyLimitEnabled: Bool
  @Binding var dailyLimitMinutes: Int

  var body: some View {
    ProductPanel(
      title: "YouTube guardrails",
      subtitle: "Track active YouTube time, count watched videos, and stop playback after a daily cap."
    ) {
      VStack(alignment: .leading, spacing: 16) {
        statsGrid

        ProductDivider()

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
        value: durationText(usage?.totalSeconds ?? 0),
        systemImage: "clock"
      )
      YouTubeUsageStatTile(
        title: "Videos",
        value: "\(usage?.videoCount ?? 0)",
        systemImage: "play.rectangle"
      )
      YouTubeUsageStatTile(
        title: "All time",
        value: durationText(usage?.lifetimeSeconds ?? 0),
        systemImage: "chart.bar"
      )
      YouTubeUsageStatTile(
        title: "Status",
        value: statusText,
        systemImage: usage?.limitReached == true ? "lock.fill" : "checkmark.circle"
      )
    }
  }

  private var usage: YouTubeUsageSnapshot? {
    let connected = store.connectedBrowserConnectors.compactMap {
      store.browserHelperSnapshots[$0.id]?.youtubeUsage
    }
    let candidates = connected.isEmpty
      ? [store.browserHelperSnapshots[store.primaryBrowserConnector.id]?.youtubeUsage]
      : connected.map(Optional.some)
    return candidates
      .compactMap { $0 }
      .sorted { lhs, rhs in
        (lhs.lastUpdatedAt ?? .distantPast) > (rhs.lastUpdatedAt ?? .distantPast)
      }
      .first
  }

  private var statusText: String {
    guard let usage else {
      return "Waiting"
    }
    if usage.limitReached {
      return "Limit hit"
    }
    guard let limitSeconds = usage.limitSeconds, limitSeconds > 0 else {
      return "Tracking"
    }
    let remaining = max(limitSeconds - usage.totalSeconds, 0)
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

      if store.browserSettingsApplyNeeded {
        Button {
          store.applyPrimaryBrowserChanges()
        } label: {
          Label(store.browserSettingsApplyTitle, systemImage: "arrow.up.forward.app")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(store.isWorking)
      }

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

          Text("\(activeFeatureCount) of \(featureCount) active")
            .font(.caption)
            .foregroundStyle(.secondary)
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

  private var activeFeatureCount: Int {
    BrowserTuningFeature.features(for: site).filter { store.tuningFeatureEnabled($0) }.count
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
      return "Reload the QuietGate extension in \(browser.displayName), then refresh X so \(site.title) tuning uses the latest code."
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
