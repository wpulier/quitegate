import SwiftUI

struct ControlView: View {
  @EnvironmentObject private var store: ProtectionStore
  @EnvironmentObject private var appBlockingStore: AppBlockingStore
  @State private var localAppStates: [String: Bool] = [
    "Slack": true,
    "Discord": true,
    "Steam": true,
    "Messages": false,
    "Mail": false,
    "Spotify": false
  ]
  @State private var pendingCategoryIDs: Set<BlockCategoryID> = []
  @State private var pendingSiteDomains: Set<String> = []
  @State private var addingCustomDomain = false

  init(openProtection: @escaping () -> Void = {}) {}

  var body: some View {
    QGPage(maxWidth: 820) {
      QGScreenHeader(
        title: "Blocking",
        subtitle: "Block whole concepts and the apps that pull you off course. Enforced wherever you're connected."
      )

      accessModeSection
      sessionCard
      coverageCard
      conceptSection
      lowerGrid

      if let errorMessage = store.errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle")
          .font(.system(size: 13))
          .foregroundStyle(QGDesign.orange)
          .textSelection(.enabled)
      }
    }
    .task {
      await store.refreshProtectionStatus()
      appBlockingStore.refreshAvailableApplications()
      appBlockingStore.startMonitoring()
    }
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
            Task { await store.setAccessMode(mode) }
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

  private var coverageCard: some View {
    QGCard {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          Label("Blocks are enforced across these accounts & devices", systemImage: "shield.checkered")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(QGDesign.primaryText)
          Spacer()
          Button {
            if let connectAction {
              store.performReadinessAction(connectAction)
            }
          } label: {
            Label("Expand to another device", systemImage: "plus")
          }
          .buttonStyle(QGPrimaryButtonStyle())
          .disabled(connectAction == nil || store.isWorking)
        }

        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 150), spacing: 8, alignment: .leading)],
          alignment: .leading,
          spacing: 8
        ) {
          ForEach(coverageChips) { chip in
            CoverageChip(chip: chip)
          }
        }
      }
    }
  }

  private var conceptSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      QGSectionLabel(text: "Concept blocking")
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
            set: { appBlockingStore.enforcementEnabled = $0 }
          ))
        }

        VStack(spacing: 0) {
          ForEach(distractingApps) { app in
            AppBlockingToggleRow(
              app: app,
              isOn: appBinding(for: app)
            )
            if app.id != distractingApps.last?.id {
              ProductDivider()
                .padding(.vertical, 10)
            }
          }
        }
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

  private var coverageChips: [CoverageChipModel] {
    let connected = store.browserConnectors.flatMap { connector in
      connector.connectedProfileLabels.map { label in
        CoverageChipModel(avatar: avatar(for: label), title: "\(connector.displayName) · \(label)", isOn: true)
      }
    }

    if !connected.isEmpty {
      return connected + [
        CoverageChipModel(avatar: "M", title: "This Mac", isOn: true),
        CoverageChipModel(avatar: "iP", title: "iPhone 15 Pro", isOn: true)
      ]
    }

    return [
      CoverageChipModel(avatar: "W", title: "Chrome · Will", isOn: true),
      CoverageChipModel(avatar: "WA", title: "Chrome · wildstudio.ai", isOn: true),
      CoverageChipModel(avatar: "W", title: "Chrome · will", isOn: true),
      CoverageChipModel(avatar: "M", title: "This Mac", isOn: true),
      CoverageChipModel(avatar: "iP", title: "iPhone 15 Pro", isOn: true)
    ]
  }

  private var connectAction: ReadinessAction? {
    store.primaryBrowserConnector.nextAction
      ?? store.browserConnectors.compactMap(\.nextAction).first
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
      ),
      ConceptRowModel(
        categoryID: .adultContent,
        icon: "dice",
        iconTint: QGDesign.orange,
        iconBackground: QGDesign.orange.opacity(0.16),
        title: "Gambling & betting",
        badge: nil,
        detail: "Blocks sportsbook, casino, and betting domains.",
        isActionable: false,
        binding: Binding(get: { false }, set: { _ in })
      ),
      ConceptRowModel(
        categoryID: .adultContent,
        icon: "newspaper",
        iconTint: QGDesign.accent,
        iconBackground: QGDesign.accent.opacity(0.16),
        title: "News & doomscroll sites",
        badge: nil,
        detail: "Blocks major news aggregators while a session is running.",
        isActionable: false,
        binding: Binding(get: { false }, set: { _ in })
      )
    ]
  }

  private var distractingApps: [DistractingAppModel] {
    [
      DistractingAppModel(name: "Slack", avatar: "S", color: Color(red: 0.290, green: 0.082, blue: 0.294)),
      DistractingAppModel(name: "Discord", avatar: "D", color: Color(red: 0.345, green: 0.396, blue: 0.949)),
      DistractingAppModel(name: "Steam", avatar: "St", color: Color(red: 0.106, green: 0.157, blue: 0.220)),
      DistractingAppModel(name: "Messages", avatar: "M", color: QGDesign.green),
      DistractingAppModel(name: "Mail", avatar: "Ma", color: Color(red: 0.114, green: 0.560, blue: 1.000)),
      DistractingAppModel(name: "Spotify", avatar: "Sp", color: Color(red: 0.114, green: 0.725, blue: 0.329))
    ]
  }

  private var displayedSites: [BlockedSiteRule] {
    if !store.blockedSites.isEmpty {
      return store.blockedSites
    }
    return [
      BlockedSiteRule(domain: "espn.com"),
      BlockedSiteRule(domain: "cnn.com"),
      BlockedSiteRule(domain: "amazon.com"),
      BlockedSiteRule(domain: "news.ycombinator.com")
    ]
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
      await MainActor.run {
        _ = pendingSiteDomains.remove(domain)
      }
    }
  }

  private func appBinding(for app: DistractingAppModel) -> Binding<Bool> {
    Binding {
      actualBlockedApp(named: app.name)?.isEnabled ?? localAppStates[app.name, default: false]
    } set: { enabled in
      if let actual = actualBlockedApp(named: app.name) {
        appBlockingStore.setBlockedApplication(actual.bundleIdentifier, enabled: enabled)
      } else if enabled, let available = availableApp(named: app.name) {
        appBlockingStore.addBlockedApplication(available)
      } else {
        localAppStates[app.name] = enabled
      }
    }
  }

  private func actualBlockedApp(named name: String) -> BlockedApplicationRule? {
    appBlockingStore.blockedApplications.first {
      $0.displayName.localizedCaseInsensitiveContains(name)
    }
  }

  private func availableApp(named name: String) -> RunningApplicationSnapshot? {
    appBlockingStore.availableApplications.first {
      $0.displayName.localizedCaseInsensitiveContains(name)
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
      return "No QuietGate rules applied. Everything is available."
    case .focus:
      return "Adult blocking on. Feeds, Shorts, Reels & recommendations hidden."
    case .strict:
      return "Everything tuned to intentional use. Daily limits enforced."
    }
  }
}

private struct CoverageChip: View {
  let chip: CoverageChipModel

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
  let app: DistractingAppModel
  @Binding var isOn: Bool

  var body: some View {
    HStack(spacing: 12) {
      QGAvatar(text: app.avatar, size: 34, background: app.color, foreground: .white, cornerRadius: 8)
      Text(app.name)
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(QGDesign.primaryText)
      Spacer()
      QGSwitch(isOn: $isOn)
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

private struct CoverageChipModel: Identifiable {
  let id = UUID()
  let avatar: String
  let title: String
  let isOn: Bool
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

private struct DistractingAppModel: Identifiable {
  var id: String { name }
  let name: String
  let avatar: String
  let color: Color
}
