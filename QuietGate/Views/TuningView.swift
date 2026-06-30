import SwiftUI

struct TuningView: View {
  @EnvironmentObject private var store: ProtectionStore
  @State private var selectedSite = DesignTuningSite.youtube
  @State private var localTikTokFeatures: [String: Bool] = [
    "tt_foryou": true,
    "tt_live": true,
    "tt_explore": false,
    "tt_track": true,
    "tt_limit": false
  ]

  var body: some View {
    QGPage(maxWidth: 820) {
      QGScreenHeader(
        title: "Tuning",
        subtitle: "Strip the noisy parts of a site without blocking it. Applies in every connected browser profile."
      )

      siteGrid
      selectedSiteHeader
      scopeCard
      featuresCard

      if let extensionBridgeMessage = store.extensionBridgeMessage {
        Label(extensionBridgeMessage, systemImage: "info.circle")
          .font(.system(size: 13))
          .foregroundStyle(QGDesign.secondaryText)
          .textSelection(.enabled)
      }

      if let errorMessage = store.errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle")
          .font(.system(size: 13))
          .foregroundStyle(QGDesign.orange)
      }
    }
  }

  private var siteGrid: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 132), spacing: 10, alignment: .leading)],
      alignment: .leading,
      spacing: 10
    ) {
      ForEach(DesignTuningSite.allCases) { site in
        Button {
          selectedSite = site
        } label: {
          TuningSiteTile(
            site: site,
            countText: countText(for: site),
            isSelected: selectedSite == site
          )
        }
        .buttonStyle(.plain)
      }

      VStack(alignment: .leading, spacing: 12) {
        Image(systemName: "plus")
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(QGDesign.accent)
        Text("Add app")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(QGDesign.primaryText)
      }
      .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
      .padding(12)
      .background(QGDesign.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(QGDesign.hairline)
      }
      .opacity(0.62)
    }
  }

  private var selectedSiteHeader: some View {
    QGCard {
      HStack(spacing: 14) {
        QGAvatar(
          text: selectedSite.letter,
          size: 44,
          background: selectedSite.color,
          foreground: selectedSite.foreground,
          cornerRadius: 10
        )
        VStack(alignment: .leading, spacing: 3) {
          Text("\(selectedSite.title) cleanup")
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(QGDesign.primaryText)
          Text(selectedSite.domain)
            .font(.system(size: 13))
            .foregroundStyle(QGDesign.secondaryText)
        }
        Spacer()
        Button(toggleAllLabel) {
          toggleAll()
        }
        .buttonStyle(QGPrimaryButtonStyle())
        .disabled(selectedSite == .tiktok ? false : store.timedSessionLockedActive)
      }
    }
  }

  private var scopeCard: some View {
    QGCard {
      VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 8) {
          Image(systemName: "shield.checkered")
            .foregroundStyle(QGDesign.green)
          Text("Where \(selectedSite.title) tuning is active")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(QGDesign.primaryText)
          Text("· \(scopeCountText)")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(QGDesign.secondaryText)
        }

        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 150), spacing: 8, alignment: .leading)],
          alignment: .leading,
          spacing: 8
        ) {
          ForEach(scopeChips) { chip in
            TuningScopeChip(chip: chip)
          }
          Button {
            if let connectAction {
              store.performReadinessAction(connectAction)
            }
          } label: {
            Label("Add browser account", systemImage: "plus")
          }
          .buttonStyle(QGPrimaryButtonStyle())
          .disabled(connectAction == nil || store.isWorking)
          Button {
            if let connectAction {
              store.performReadinessAction(connectAction)
            }
          } label: {
            Label("Add iPhone (iOS)", systemImage: "plus")
          }
          .buttonStyle(QGPrimaryButtonStyle())
          .disabled(connectAction == nil || store.isWorking)
        }
      }
    }
  }

  private var featuresCard: some View {
    QGCard {
      VStack(spacing: 0) {
        ForEach(Array(siteFeatures.enumerated()), id: \.element.id) { index, feature in
          if index > 0 {
            ProductDivider()
              .padding(.vertical, 13)
          }
          TuningFeatureDisplayRow(
            feature: feature,
            isOn: binding(for: feature),
            isEnabled: selectedSite == .tiktok || !store.timedSessionLockedActive
          )
        }
      }
    }
  }

  private var siteFeatures: [TuningFeatureDisplay] {
    selectedSite.features
  }

  private var selectedFeatureCount: Int {
    siteFeatures.filter { binding(for: $0).wrappedValue }.count
  }

  private var toggleAllLabel: String {
    selectedFeatureCount == siteFeatures.count ? "Reset all" : "Hide all"
  }

  private var scopeCountText: String {
    let accountCount = scopeChips.filter { !$0.title.localizedCaseInsensitiveContains("iPhone") }.count
    return "\(accountCount) accounts"
  }

  private var scopeChips: [TuningScopeChipModel] {
    let connected = store.browserConnectors.flatMap { connector in
      connector.connectedProfileLabels.map { label in
        TuningScopeChipModel(avatar: avatar(for: label), title: "\(connector.displayName) · \(label)", isOn: true)
      }
    }

    if !connected.isEmpty {
      return connected
    }

    return [
      TuningScopeChipModel(avatar: "W", title: "Chrome · Will", isOn: true),
      TuningScopeChipModel(avatar: "WA", title: "Chrome · wildstudio.ai", isOn: true),
      TuningScopeChipModel(avatar: "W", title: "Chrome · will", isOn: true)
    ]
  }

  private var connectAction: ReadinessAction? {
    store.primaryBrowserConnector.nextAction
      ?? store.browserConnectors.compactMap(\.nextAction).first
  }

  private func countText(for site: DesignTuningSite) -> String {
    let features = site.features
    let count = features.filter { binding(for: $0).wrappedValue }.count
    return "\(count)/\(features.count) on"
  }

  private func toggleAll() {
    let nextValue = selectedFeatureCount != siteFeatures.count
    if selectedSite == .tiktok {
      for feature in siteFeatures {
        localTikTokFeatures[feature.id] = nextValue
      }
      return
    }

    let features = siteFeatures.compactMap(\.storeFeature)
    store.setTuningFeatures(features, enabled: nextValue)
  }

  private func binding(for feature: TuningFeatureDisplay) -> Binding<Bool> {
    if let storeFeature = feature.storeFeature {
      return Binding {
        store.tuningFeatureEnabled(storeFeature)
      } set: { enabled in
        store.setTuningFeature(storeFeature, enabled: enabled)
      }
    }

    return Binding {
      localTikTokFeatures[feature.id, default: false]
    } set: { enabled in
      localTikTokFeatures[feature.id] = enabled
    }
  }

  private func avatar(for label: String) -> String {
    let letters = label
      .split(separator: " ")
      .prefix(2)
      .compactMap(\.first)
    let value = String(letters).uppercased()
    return value.isEmpty ? "W" : value
  }
}

private struct TuningSiteTile: View {
  let site: DesignTuningSite
  let countText: String
  let isSelected: Bool

  var body: some View {
    HStack(spacing: 10) {
      QGAvatar(text: site.letter, size: 34, background: site.color, foreground: site.foreground, cornerRadius: 8)
      VStack(alignment: .leading, spacing: 2) {
        Text(site.title)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(QGDesign.primaryText)
        Text(countText)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(QGDesign.secondaryText)
      }
      Spacer(minLength: 0)
    }
    .padding(12)
    .frame(maxWidth: .infinity, minHeight: 68)
    .background(isSelected ? QGDesign.accent.opacity(0.18) : QGDesign.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(isSelected ? QGDesign.accent : QGDesign.hairline)
    }
  }
}

private struct TuningFeatureDisplayRow: View {
  let feature: TuningFeatureDisplay
  @Binding var isOn: Bool
  let isEnabled: Bool

  var body: some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 5) {
        Text(feature.title)
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(QGDesign.primaryText)
        Text(feature.detail)
          .font(.system(size: 12))
          .foregroundStyle(QGDesign.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 14)
      QGSwitch(isOn: $isOn, isEnabled: isEnabled)
    }
  }
}

private struct TuningScopeChip: View {
  let chip: TuningScopeChipModel

  var body: some View {
    HStack(spacing: 8) {
      QGAvatar(text: chip.avatar, size: 24)
      Text(chip.title)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(QGDesign.primaryText)
      Circle()
        .fill(chip.isOn ? QGDesign.green : QGDesign.tertiaryText)
        .frame(width: 7, height: 7)
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 7)
    .background(QGDesign.elevatedPanel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .strokeBorder(QGDesign.hairline)
    }
  }
}

private struct TuningScopeChipModel: Identifiable {
  let id = UUID()
  let avatar: String
  let title: String
  let isOn: Bool
}

private enum DesignTuningSite: String, CaseIterable, Identifiable {
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
    case .youtube:
      return QGDesign.red
    case .x, .tiktok:
      return .black
    case .instagram:
      return .pink
    case .reddit:
      return .orange
    }
  }

  var foreground: Color {
    switch self {
    case .tiktok:
      return .cyan
    default:
      return .white
    }
  }

  var features: [TuningFeatureDisplay] {
    switch self {
    case .youtube:
      return [
        TuningFeatureDisplay(id: "yt_home", title: "Hide Home Feed", detail: "Open YouTube straight to search and subscriptions - no recommendation wall.", storeFeature: .youtubeHome),
        TuningFeatureDisplay(id: "yt_shorts", title: "Hide Shorts", detail: "Remove Shorts shelves, links, and the full-screen Shorts player.", storeFeature: .youtubeShorts),
        TuningFeatureDisplay(id: "yt_recs", title: "Hide Recommended", detail: "Strip recommended videos from the watch sidebar and end screens.", storeFeature: .youtubeRecommendations),
        TuningFeatureDisplay(id: "yt_autoplay", title: "Disable Autoplay", detail: "Stop the next video from rolling automatically.", storeFeature: .youtubeAutoplay),
        TuningFeatureDisplay(id: "yt_comments", title: "Hide Comments", detail: "Remove the comment section from watch pages.", storeFeature: .youtubeComments),
        TuningFeatureDisplay(id: "yt_track", title: "Track Time & Videos", detail: "Count active time and unique videos across connected profiles.", storeFeature: .youtubeUsageTracking),
        TuningFeatureDisplay(id: "yt_limit", title: "Daily Time Limit · 45m", detail: "Block YouTube once the daily limit is reached.", storeFeature: .youtubeDailyLimit)
      ]
    case .x:
      return [
        TuningFeatureDisplay(id: "x_sensitive", title: "Hide Sensitive Media", detail: "Hide flagged sensitive media and high-confidence explicit posts.", storeFeature: .xSensitiveMedia),
        TuningFeatureDisplay(id: "x_video", title: "Hide Videos & GIFs", detail: "Remove autoplaying video and GIF players from the timeline.", storeFeature: .xVideos),
        TuningFeatureDisplay(id: "x_explore", title: "Hide Explore & Trends", detail: "Remove trend modules and Explore entry points.", storeFeature: .xExploreTrends),
        TuningFeatureDisplay(id: "x_photos", title: "Hide Tweet Photos", detail: "Remove inline photos while keeping text and avatars.", storeFeature: .xPhotos),
        TuningFeatureDisplay(id: "x_cards", title: "Hide Media Cards", detail: "Remove rich link cards with large media previews.", storeFeature: .xMediaCards)
      ]
    case .instagram:
      return [
        TuningFeatureDisplay(id: "ig_reels", title: "Hide Reels", detail: "Remove Reels trays, links, and the Reels player.", storeFeature: .instagramReels),
        TuningFeatureDisplay(id: "ig_explore", title: "Hide Explore", detail: "Remove Explore and redirect it back to your feed.", storeFeature: .instagramExplore),
        TuningFeatureDisplay(id: "ig_suggested", title: "Hide Suggested Posts", detail: "Remove recommended and promoted posts from the feed.", storeFeature: .instagramSuggested),
        TuningFeatureDisplay(id: "ig_stories", title: "Hide Stories", detail: "Remove the stories tray at the top of the feed.", storeFeature: .instagramStories),
        TuningFeatureDisplay(id: "ig_dms", title: "Hide DMs", detail: "Remove direct-message entry points.", storeFeature: .instagramMessages)
      ]
    case .reddit:
      return [
        TuningFeatureDisplay(id: "rd_popular", title: "Hide Popular & All", detail: "Remove r/popular and r/all and redirect them home.", storeFeature: .redditPopularAll),
        TuningFeatureDisplay(id: "rd_recs", title: "Hide Recommendations", detail: "Remove recommended and promoted community modules.", storeFeature: .redditRecommendations),
        TuningFeatureDisplay(id: "rd_nsfw", title: "Hide NSFW Posts & Communities", detail: "Remove mature posts, communities, and adult media.", storeFeature: .redditNSFW),
        TuningFeatureDisplay(id: "rd_media", title: "Hide Media Posts", detail: "Remove image and video posts while keeping text.", storeFeature: .redditMedia),
        TuningFeatureDisplay(id: "rd_sidebars", title: "Hide Sidebars", detail: "Remove right-rail sidebars and community panels.", storeFeature: .redditSidebars)
      ]
    case .tiktok:
      return [
        TuningFeatureDisplay(id: "tt_foryou", title: "Hide For You Feed", detail: "Open TikTok to Following instead of the For You loop.", storeFeature: nil),
        TuningFeatureDisplay(id: "tt_live", title: "Hide LIVE", detail: "Remove LIVE entry points and shelves.", storeFeature: nil),
        TuningFeatureDisplay(id: "tt_explore", title: "Hide Explore", detail: "Remove the Explore tab.", storeFeature: nil),
        TuningFeatureDisplay(id: "tt_track", title: "Track Time", detail: "Count active time across connected profiles.", storeFeature: nil),
        TuningFeatureDisplay(id: "tt_limit", title: "Daily Time Limit · 20m", detail: "Block TikTok once the daily limit is reached.", storeFeature: nil)
      ]
    }
  }
}

private struct TuningFeatureDisplay: Identifiable {
  let id: String
  let title: String
  let detail: String
  let storeFeature: BrowserTuningFeature?
}
