import ClerkKit
import SwiftUI

struct TuningView: View {
  @Environment(Clerk.self) private var clerk
  @EnvironmentObject private var store: ProtectionStore
  @EnvironmentObject private var appBlockingStore: AppBlockingStore
  @EnvironmentObject private var accountStore: MacAccountStore
  @State private var selectedSite = TuningCatalog.youtubeSiteID
  @State private var addSheetPresented = false
  @State private var pendingCategoryIDs: Set<BlockCategoryID> = []
  @State private var pendingSiteDomains: Set<String> = []
  @State private var addingCustomDomain = false

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
        title: "Tune",
        subtitle: "Set your mode, shape each site, and choose what's blocked. Enforced wherever you're connected."
      )

      accessModeSection

      siteGrid
      selectedSiteHeader
      scopeCard
      featuresCard

      conceptSection
      lowerGrid

      sessionCard

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
    .task {
      await store.refreshProtectionStatus()
      appBlockingStore.refreshAvailableApplications()
      appBlockingStore.startMonitoring()
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

  private var accessModeSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      QGSectionLabel(text: "Access mode")
      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 230), spacing: 12)],
        alignment: .leading,
        spacing: 12
      ) {
        ForEach(AccessMode.allCases) { mode in
          Button {
            guard !store.timedSessionLockedActive else { return }
            Task {
              await accountStore.setAccessMode(
                mode,
                using: clerk,
                protectionStore: store,
                appBlockingStore: appBlockingStore
              )
            }
          } label: {
            ModeChoiceCard(mode: mode, isSelected: store.accessMode == mode)
          }
          .buttonStyle(.plain)
          .disabled(!store.blockingControlsReady || store.isWorking || store.timedSessionLockedActive)
        }
      }
      if let reason = store.blockingCapabilityUnavailableReason {
        Label(reason, systemImage: "lock")
          .font(.system(size: 12))
          .foregroundStyle(QGDesign.secondaryText)
      }
    }
  }

  private var sessionCard: some View {
    QGCard {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 5) {
            Text("Commit to a session")
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(QGDesign.primaryText)
            Text(sessionDetail)
              .font(.system(size: 13))
              .foregroundStyle(QGDesign.secondaryText)
          }
          Spacer()
          Text(store.timedSessionActive ? store.timedSessionStatusLine : "Returns to Open when the timer ends")
            .font(.system(size: 12))
            .foregroundStyle(QGDesign.secondaryText)
        }

        HStack(spacing: 10) {
          sessionButton(title: "Focus · 25m", mode: .focus, duration: 25 * 60)
          sessionButton(title: "Focus · 1h", mode: .focus, duration: 60 * 60)
          sessionButton(title: "Lock Strict · 2h", mode: .strict, duration: 2 * 3600, locked: true, systemImage: "lock")

          if store.timedSessionActive && !store.timedSessionLockedActive {
            Button(role: .destructive) {
              Task { await store.endTimedSession() }
            } label: {
              Text("End")
            }
            .buttonStyle(QGPrimaryButtonStyle(tint: QGDesign.red))
          }
        }
      }
    }
  }

  private var sessionDetail: String {
    if store.timedSessionActive {
      return store.timedSessionLockedActive
        ? "A locked Strict session can't be ended, weakened, or quit early - that's the point."
        : "Your focus session is running. End it early or let it return to Open."
    }
    return "Lock in a block of time. A locked Strict session can't be ended, weakened, or quit early - that's the point."
  }

  private func sessionButton(
    title: String,
    mode: AccessMode,
    duration: TimeInterval,
    locked: Bool = false,
    systemImage: String? = nil
  ) -> some View {
    Button {
      Task {
        await store.startTimedSession(mode: mode, duration: duration, locked: locked)
      }
    } label: {
      if let systemImage {
        Label(title, systemImage: systemImage)
      } else {
        Text(title)
      }
    }
    .buttonStyle(QGPrimaryButtonStyle(tint: locked ? QGDesign.purple : QGDesign.accent))
    .disabled(!store.blockingControlsReady || store.isWorking || store.timedSessionLockedActive)
  }

  private var conceptSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      QGSectionLabel(text: "Adult sites")
      QGCard {
        VStack(spacing: 0) {
          ForEach(Array(conceptRows.enumerated()), id: \.element.id) { index, row in
            if index > 0 {
              ProductDivider()
                .padding(.vertical, 12)
            }
            ConceptBlockingRow(
              row: row,
              isOn: row.binding,
              isEnabled: row.isActionable
                && store.blockRuleEditingReady
                && !store.timedSessionLockedActive
                && !pendingCategoryIDs.contains(row.categoryID)
            ) { enabled in
              if row.isActionable {
                toggleCategory(row.categoryID, enabled: enabled)
              }
            }
          }
        }
      }
    }
  }

  private var lowerGrid: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 330), spacing: 14, alignment: .top)],
      alignment: .leading,
      spacing: 14
    ) {
      distractingAppsCard
      blockedWebsitesCard
    }
  }

  private var distractingAppsCard: some View {
    QGCard {
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top, spacing: 12) {
          VStack(alignment: .leading, spacing: 3) {
            Text("Distracting apps")
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(QGDesign.primaryText)
            Text(appBlockingStore.enforcementEnabled ? "Closed on launch while a session runs." : "Saved, but app closing is paused.")
              .font(.system(size: 12))
              .foregroundStyle(QGDesign.secondaryText)
          }
          Spacer()
          QGSwitch(isOn: Binding(
            get: { appBlockingStore.enforcementEnabled },
            set: { enabled in
              appBlockingStore.enforcementEnabled = enabled
              Task {
                await accountStore.pushLocalPolicy(
                  using: clerk,
                  protectionStore: store,
                  appBlockingStore: appBlockingStore
                )
              }
            }
          ))
        }

        if appBlockingStore.blockedApplications.isEmpty {
          Text("No apps blocked yet — add one below.")
            .font(.system(size: 12))
            .foregroundStyle(QGDesign.secondaryText)
        } else {
          VStack(spacing: 0) {
            ForEach(appBlockingStore.blockedApplications) { rule in
              AppBlockingToggleRow(
                displayName: rule.displayName,
                avatar: avatar(for: rule.displayName),
                isOn: blockedAppBinding(for: rule),
                removeAction: { appBlockingStore.removeBlockedApplication(rule.bundleIdentifier) }
              )
              if rule.id != appBlockingStore.blockedApplications.last?.id {
                ProductDivider()
                  .padding(.vertical, 10)
              }
            }
          }
        }

        addAppMenu
      }
    }
  }

  private var addAppMenu: some View {
    Group {
      if appBlockingStore.availableApplications.isEmpty {
        Text("Scanning installed apps…")
          .font(.system(size: 12))
          .foregroundStyle(QGDesign.secondaryText)
      } else if addableApplications.isEmpty {
        Text("Every scanned app is already blocked.")
          .font(.system(size: 12))
          .foregroundStyle(QGDesign.secondaryText)
      } else {
        Menu {
          ForEach(addableApplications) { app in
            Button(app.displayName) {
              appBlockingStore.addBlockedApplication(app)
              Task {
                await accountStore.pushLocalPolicy(
                  using: clerk,
                  protectionStore: store,
                  appBlockingStore: appBlockingStore
                )
              }
            }
          }
        } label: {
          Label("Add app", systemImage: "plus")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
      }
    }
  }

  private var blockedWebsitesCard: some View {
    QGCard {
      VStack(alignment: .leading, spacing: 14) {
        Text("Blocked websites")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(QGDesign.primaryText)

        HStack(spacing: 8) {
          TextField("Add a domain...", text: $store.customDomainDraft)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(QGDesign.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(QGDesign.field, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .disabled(addingCustomDomain || !store.blockRuleEditingReady)
            .onSubmit(addCustomDomain)

          Button("Add", action: addCustomDomain)
            .buttonStyle(QGPrimaryButtonStyle())
            .disabled(
              store.customDomainDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || addingCustomDomain
                || !store.blockRuleEditingReady
            )
        }

        if displayedSites.isEmpty {
          Text("No blocked sites yet — add a domain above.")
            .font(.system(size: 12))
            .foregroundStyle(QGDesign.secondaryText)
        } else {
          VStack(spacing: 0) {
            ForEach(displayedSites) { site in
              BlockedWebsiteRow(
                site: site,
                isPending: pendingSiteDomains.contains(site.domain),
                deleteAction: { deleteSite(site.domain) }
              )
              if site.id != displayedSites.last?.id {
                ProductDivider()
                  .padding(.vertical, 10)
              }
            }
          }
        }
      }
    }
  }

  private var conceptRows: [ConceptRowModel] {
    [
      ConceptRowModel(
        categoryID: .adultContent,
        icon: "figure.mixed.cardio",
        iconTint: QGDesign.red,
        iconBackground: QGDesign.red.opacity(0.16),
        title: "Pornography & adult content",
        badge: "LOCKED IN STRICT",
        detail: "Blocks adult domains, adult-host media, and high-confidence explicit pages across every connected browser.",
        isActionable: true,
        binding: categoryBinding(.adultContent)
      )
    ]
  }

  private var addableApplications: [RunningApplicationSnapshot] {
    let blockedIDs = Set(appBlockingStore.blockedApplications.map(\.bundleIdentifier))
    return appBlockingStore.availableApplications.filter { !blockedIDs.contains($0.bundleIdentifier) }
  }

  private var displayedSites: [BlockedSiteRule] {
    store.blockedSites
  }

  private func categoryBinding(_ id: BlockCategoryID) -> Binding<Bool> {
    Binding {
      store.blockCategories.first { $0.id == id }?.isEnabled ?? (store.accessMode != .open)
    } set: { enabled in
      toggleCategory(id, enabled: enabled)
    }
  }

  private func toggleCategory(_ id: BlockCategoryID, enabled: Bool) {
    guard !pendingCategoryIDs.contains(id) else {
      return
    }
    pendingCategoryIDs.insert(id)
    Task {
      await store.setBlockCategory(id, enabled: enabled)
      await accountStore.pushLocalPolicy(
        using: clerk,
        protectionStore: store,
        appBlockingStore: appBlockingStore
      )
      await MainActor.run {
        _ = pendingCategoryIDs.remove(id)
      }
    }
  }

  private func addCustomDomain() {
    guard !addingCustomDomain else {
      return
    }
    addingCustomDomain = true
    Task {
      await store.addCustomDomain()
      await accountStore.pushLocalPolicy(
        using: clerk,
        protectionStore: store,
        appBlockingStore: appBlockingStore
      )
      await MainActor.run {
        addingCustomDomain = false
      }
    }
  }

  private func deleteSite(_ domain: String) {
    guard !pendingSiteDomains.contains(domain), store.blockedSites.contains(where: { $0.domain == domain }) else {
      return
    }
    pendingSiteDomains.insert(domain)
    Task {
      await store.deleteBlockedSite(domain)
      await accountStore.pushLocalPolicy(
        using: clerk,
        protectionStore: store,
        appBlockingStore: appBlockingStore
      )
      await MainActor.run {
        _ = pendingSiteDomains.remove(domain)
      }
    }
  }

  private func blockedAppBinding(for rule: BlockedApplicationRule) -> Binding<Bool> {
    Binding {
      rule.isEnabled
    } set: { enabled in
      appBlockingStore.setBlockedApplication(rule.bundleIdentifier, enabled: enabled)
      Task {
        await accountStore.pushLocalPolicy(
          using: clerk,
          protectionStore: store,
          appBlockingStore: appBlockingStore
        )
      }
    }
  }
}

private struct ModeChoiceCard: View {
  let mode: AccessMode
  let isSelected: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Image(systemName: mode.systemImage)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(isSelected ? QGDesign.accent : QGDesign.secondaryText)
        Spacer()
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(QGDesign.accent)
        }
      }

      VStack(alignment: .leading, spacing: 5) {
        Text(mode.title)
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(QGDesign.primaryText)
        Text(detail)
          .font(.system(size: 12))
          .foregroundStyle(QGDesign.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
    .background(QGDesign.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(isSelected ? QGDesign.accent : QGDesign.strongHairline)
    }
  }

  private var detail: String {
    switch mode {
    case .open:
      return "No Tortoise rules applied. Everything is available."
    case .focus:
      return "Adult blocking on. Feeds, Shorts, Reels & recommendations hidden."
    case .strict:
      return "Everything tuned to intentional use. Daily limits enforced."
    }
  }
}

private struct ConceptBlockingRow: View {
  let row: ConceptRowModel
  @Binding var isOn: Bool
  let isEnabled: Bool
  let action: (Bool) -> Void

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: row.icon)
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(row.iconTint)
        .frame(width: 38, height: 38)
        .background(row.iconBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 8) {
          Text(row.title)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(QGDesign.primaryText)
          if let badge = row.badge {
            QGPill(text: badge, tint: QGDesign.purple)
          }
        }
        Text(row.detail)
          .font(.system(size: 12))
          .foregroundStyle(QGDesign.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 14)

      QGSwitch(isOn: Binding(get: { isOn }, set: { value in
        isOn = value
        action(value)
      }), isEnabled: isEnabled)
    }
  }
}

private struct AppBlockingToggleRow: View {
  let displayName: String
  let avatar: String
  @Binding var isOn: Bool
  let removeAction: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      QGAvatar(text: avatar, size: 34, cornerRadius: 8)
      Text(displayName)
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(QGDesign.primaryText)
      Spacer()
      QGSwitch(isOn: $isOn)
      Button(action: removeAction) {
        Image(systemName: "xmark")
          .font(.system(size: 11, weight: .bold))
      }
      .buttonStyle(.plain)
      .foregroundStyle(QGDesign.secondaryText)
    }
  }
}

private struct BlockedWebsiteRow: View {
  let site: BlockedSiteRule
  let isPending: Bool
  let deleteAction: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "lock")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(QGDesign.orange)
        .frame(width: 28, height: 28)
        .background(QGDesign.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      Text(site.domain)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(QGDesign.primaryText)
      Spacer()
      Button(action: deleteAction) {
        Image(systemName: "xmark")
          .font(.system(size: 11, weight: .bold))
      }
      .buttonStyle(.plain)
      .foregroundStyle(QGDesign.secondaryText)
      .disabled(isPending)
    }
    .opacity(site.isEnabled ? 1 : 0.55)
  }
}

private struct ConceptRowModel: Identifiable {
  let id = UUID()
  let categoryID: BlockCategoryID
  let icon: String
  let iconTint: Color
  let iconBackground: Color
  let title: String
  let badge: String?
  let detail: String
  let isActionable: Bool
  let binding: Binding<Bool>
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
