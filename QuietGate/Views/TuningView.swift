import ClerkKit
import SwiftUI

struct TuningView: View {
  @Environment(Clerk.self) private var clerk
  @EnvironmentObject private var store: ProtectionStore
  @EnvironmentObject private var appBlockingStore: AppBlockingStore
  @EnvironmentObject private var accountStore: MacAccountStore
  @State private var selectedSite = TuningCatalog.youtubeSiteID
  @State private var addSheetPresented = false

  private var tunePolicy: TortoisePolicy? { accountStore.snapshot.policy?.policy }

  private var tuneSites: [TuneSite] {
    TuneScreen.sites(policy: tunePolicy, surface: .chromeExtension)
  }

  private var selectedTuneSite: TuneSite? {
    tuneSites.first { $0.id == selectedSite }
  }

  private var selectedSiteFeatures: [TuneFeature] {
    TuneScreen.features(forSiteID: selectedSite, policy: tunePolicy, surface: .chromeExtension)
  }

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
    .sheet(isPresented: $addSheetPresented) {
      AddSheetView()
    }
  }

  private var siteGrid: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 132), spacing: 10, alignment: .leading)],
      alignment: .leading,
      spacing: 10
    ) {
      ForEach(tuneSites) { site in
        Button {
          selectedSite = site.id
        } label: {
          TuningSiteTile(site: site, isSelected: selectedSite == site.id)
        }
        .buttonStyle(.plain)
      }

      TuningComingSoonTile(title: "TikTok")

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
        TuneBrandMark(assetName: selectedTuneSite?.brandAssetName, size: 44, cornerRadius: 10)
        VStack(alignment: .leading, spacing: 3) {
          Text("\(selectedTuneSite?.title ?? "") cleanup")
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(QGDesign.primaryText)
          Text("\(selectedFeatureCount)/\(selectedSiteFeatures.count) hidden")
            .font(.system(size: 13))
            .foregroundStyle(QGDesign.secondaryText)
        }
        Spacer()
        Button(toggleAllLabel) {
          toggleAll()
        }
        .buttonStyle(QGPrimaryButtonStyle())
        .disabled(store.timedSessionLockedActive)
      }
    }
  }

  private var scopeCard: some View {
    QGCard {
      VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 8) {
          Image(systemName: "shield.checkered")
            .foregroundStyle(QGDesign.green)
          Text("Where \(selectedTuneSite?.title ?? "") tuning is active")
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
            addSheetPresented = true
          } label: {
            Label("Add", systemImage: "plus")
          }
          .buttonStyle(QGPrimaryButtonStyle())
        }
      }
    }
  }

  private var featuresCard: some View {
    QGCard {
      VStack(spacing: 0) {
        ForEach(Array(selectedSiteFeatures.enumerated()), id: \.element.id) { index, feature in
          if index > 0 {
            ProductDivider()
              .padding(.vertical, 13)
          }
          TuningFeatureRow(
            feature: feature,
            isOn: binding(for: feature),
            isEnabled: !store.timedSessionLockedActive
          )
        }
      }
    }
  }

  private var selectedFeatureCount: Int {
    selectedSiteFeatures.filter(\.isOn).count
  }

  private var toggleAllLabel: String {
    selectedFeatureCount == selectedSiteFeatures.count ? "Reset all" : "Hide all"
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

    return connected
  }

  private func toggleAll() {
    let nextValue = selectedFeatureCount != selectedSiteFeatures.count
    let features = selectedSiteFeatures.compactMap { BrowserTuningFeature(rawValue: $0.id) }
    Task {
      await accountStore.setTuningFeatures(
        features,
        enabled: nextValue,
        using: clerk,
        protectionStore: store,
        appBlockingStore: appBlockingStore
      )
    }
  }

  private func binding(for feature: TuneFeature) -> Binding<Bool> {
    Binding {
      feature.isOn
    } set: { newValue in
      Task {
        if let f = BrowserTuningFeature(rawValue: feature.id) {
          await accountStore.setTuningFeature(
            f,
            enabled: newValue,
            using: clerk,
            protectionStore: store,
            appBlockingStore: appBlockingStore
          )
        }
      }
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
  let site: TuneSite
  let isSelected: Bool

  var body: some View {
    HStack(spacing: 10) {
      TuneBrandMark(assetName: site.brandAssetName, size: 34, cornerRadius: 8)
      VStack(alignment: .leading, spacing: 2) {
        Text(site.title)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(QGDesign.primaryText)
        Text("\(site.enabledCount)/\(site.totalCount)")
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

/// A dimmed, non-interactive tile for a site that isn't tunable yet. No toggles,
/// no fake data - just an honest placeholder until the real tuner ships.
private struct TuningComingSoonTile: View {
  let title: String

  var body: some View {
    HStack(spacing: 10) {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(Color.white.opacity(0.06))
        .frame(width: 34, height: 34)
        .overlay {
          Image(systemName: "hourglass")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(QGDesign.tertiaryText)
        }
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(QGDesign.secondaryText)
        Text("Coming soon")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(QGDesign.tertiaryText)
      }
      Spacer(minLength: 0)
    }
    .padding(12)
    .frame(maxWidth: .infinity, minHeight: 68)
    .background(QGDesign.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(QGDesign.hairline)
    }
    .opacity(0.55)
  }
}

/// Renders a site's real brand mark asset, falling back to a plain glyph if the
/// asset name is unavailable (e.g. before the policy has loaded).
private struct TuneBrandMark: View {
  let assetName: String?
  var size: CGFloat = 34
  var cornerRadius: CGFloat = 8

  var body: some View {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      .fill(Color.white.opacity(0.08))
      .frame(width: size, height: size)
      .overlay {
        if let assetName {
          Image(assetName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(size * 0.2)
        } else {
          Image(systemName: "globe")
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(QGDesign.secondaryText)
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
  }
}

private struct TuningFeatureRow: View {
  let feature: TuneFeature
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
