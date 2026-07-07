import ClerkKit
import SwiftUI

/// The Block screen: access mode, committed sessions, adult-site blocking,
/// distracting apps, and blocked websites. Tuning (per-site feature toggles)
/// lives in `TuningView`.
struct BlockingView: View {
  @Environment(Clerk.self) private var clerk
  @EnvironmentObject private var store: ProtectionStore
  @EnvironmentObject private var appBlockingStore: AppBlockingStore
  @EnvironmentObject private var accountStore: MacAccountStore
  @State private var pendingCategoryIDs: Set<BlockCategoryID> = []
  @State private var pendingSiteDomains: Set<String> = []
  @State private var addingCustomDomain = false

  var body: some View {
    QGPage(maxWidth: 820) {
      QGScreenHeader(
        title: "Block",
        subtitle: "Set your mode and choose what's blocked. Enforced wherever you're connected."
      )

      accessModeSection
      sessionCard

      conceptSection
      lowerGrid

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

          ProductDivider()
            .padding(.vertical, 12)

          ExplicitHideStyleRow(
            selected: store.tuningOptions.explicitHideStyle,
            isEnabled: !store.timedSessionLockedActive,
            onSelect: setExplicitHideStyle
          )
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

  private func setExplicitHideStyle(_ style: ExplicitHideStyle) {
    store.setExplicitHideStyle(style)
    Task {
      await accountStore.pushLocalPolicy(
        using: clerk,
        protectionStore: store,
        appBlockingStore: appBlockingStore
      )
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

/// A Block-level option: how flagged explicit content is hidden across every
/// connected browser (not tied to a single site). Reads the real persisted
/// style from `store.tuningOptions`.
private struct ExplicitHideStyleRow: View {
  let selected: ExplicitHideStyle
  let isEnabled: Bool
  let onSelect: (ExplicitHideStyle) -> Void

  var body: some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 5) {
        Text("Hide style")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(QGDesign.primaryText)
        Text("How flagged explicit content is hidden across every connected browser.")
          .font(.system(size: 12))
          .foregroundStyle(QGDesign.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 14)
      ExplicitHideStyleSegmented(selected: selected, isEnabled: isEnabled, onSelect: onSelect)
    }
  }
}

/// A lightweight segmented control over `ExplicitHideStyle.allCases`, styled to
/// match the app's design tokens rather than the system segmented control.
private struct ExplicitHideStyleSegmented: View {
  let selected: ExplicitHideStyle
  let isEnabled: Bool
  let onSelect: (ExplicitHideStyle) -> Void

  var body: some View {
    HStack(spacing: 3) {
      ForEach(ExplicitHideStyle.allCases) { style in
        Button {
          guard isEnabled, style != selected else { return }
          onSelect(style)
        } label: {
          Text(style.title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(style == selected ? QGDesign.primaryText : QGDesign.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
              style == selected ? QGDesign.elevatedPanel : Color.clear,
              in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(.plain)
      }
    }
    .padding(3)
    .background(QGDesign.field, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    .opacity(isEnabled ? 1 : 0.45)
  }
}
