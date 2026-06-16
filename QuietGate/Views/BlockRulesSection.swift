import SwiftUI

struct BlockRulesSection: View {
  @EnvironmentObject private var store: ProtectionStore
  @State private var pendingCategoryIDs: Set<BlockCategoryID> = []
  @State private var pendingSiteDomains: Set<String> = []
  @State private var addingCustomDomain = false
  @State private var resolvingHiddenRestrictions = false
  let openProtection: () -> Void

  init(openProtection: @escaping () -> Void = {}) {
    self.openProtection = openProtection
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      if store.legacyBlockingProviderEnabled,
         let hiddenRestrictions = store.legacyManagedRestrictionsText {
        HiddenRestrictionsNotice(
          restrictions: hiddenRestrictions,
          isWorking: resolvingHiddenRestrictions || store.isWorking,
          action: turnOffHiddenRestrictions
        )
      }

      if legacySyncPending {
        CheckingBlocksNotice()
      }

      if store.browserSettingsApplyNeeded {
        BrowserChangesNotice(
          title: store.browserSettingsApplyTitle,
          detail: store.browserSettingsApplyDetail,
          isWorking: store.isWorking,
          action: store.applyPrimaryBrowserChanges
        )
      }

      if !legacySyncPending,
         let attentionTitle = store.blockApplicationAttentionTitle,
         let attentionDetail = store.blockApplicationAttentionDetail {
        BlocksNeedSetupNotice(
          title: attentionTitle,
          detail: attentionDetail,
          action: openProtection
        )
      }

      if let browserAttentionTitle = store.blockBrowserAttentionTitle,
         let browserAttentionDetail = store.blockBrowserAttentionDetail {
        ChromeSpeedNotice(
          title: browserAttentionTitle,
          detail: browserAttentionDetail,
          action: openProtection
        )
      }

      if let profileScopeDetail = store.browserRuleProfileScopeDetail,
         let profileScope = store.connectedBrowserProfileScopeText {
        ProductScopeLine(
          title: "Browser profile scope",
          detail: profileScope,
          caption: profileScopeDetail,
          systemImage: "person.crop.circle.badge.checkmark",
          tint: .green
        )
      }

      ProductPanel(
        title: "What gets blocked",
        subtitle: store.legacyBlockingProviderEnabled
          ? "These switches change what QuietGate blocks on this Mac."
          : "These switches change what QuietGate blocks in connected browsers."
      ) {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(store.blockCategories) { rule in
            FriendlyCategoryRow(
              rule: rule,
              applicationStatus: store.blockCategoryApplicationStatus(rule),
              transaction: store.blockCategoryTransaction(rule.id),
              isOn: Binding(
                get: { categoryRule(rule.id).isEnabled },
                set: { enabled in toggleCategory(rule.id, enabled: enabled) }
              ),
              toggleDisabled: !store.blockRuleEditingReady || pendingCategoryIDs.contains(rule.id)
            )
          }

          ProductDivider()

          specificWebsitesSection
        }
      }
    }
  }

  private var specificWebsitesSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Specific websites")
          .font(.headline)
        Text(specificWebsitesSubtitle)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.top, 16)

      HStack(spacing: 10) {
        TextField("example.com", text: $store.customDomainDraft)
          .textFieldStyle(.roundedBorder)
          .disabled(addingCustomDomain || !store.blockRuleEditingReady)
          .onSubmit {
            addCustomDomain()
          }

        Button {
          addCustomDomain()
        } label: {
          Label("Add", systemImage: "plus")
        }
        .disabled(
          store.customDomainDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || addingCustomDomain || !store.blockRuleEditingReady)
      }

      if store.blockedSites.isEmpty {
        ContentUnavailableView(
          "No specific websites yet",
          systemImage: "plus.circle",
          description: Text("Add one above when you want QuietGate to block a site by name.")
        )
        .frame(maxWidth: .infinity, minHeight: 140)
      } else {
        VStack(spacing: 0) {
          ForEach(store.blockedSites) { site in
            FriendlySiteRow(
              site: site,
              applicationStatus: store.blockedSiteApplicationStatus(site),
              transaction: store.blockedSiteTransaction(site.domain),
              isOn: Binding(
                get: { blockedSite(site.domain).isEnabled },
                set: { enabled in
                  toggleSite(site.domain, enabled: enabled)
                }
              ),
              toggleDisabled: !store.blockRuleEditingReady
                || pendingSiteDomains.contains(site.domain),
              deleteDisabled: pendingSiteDomains.contains(site.domain)
                || !store.blockRuleEditingReady
                || (store.timedSessionLockedActive && site.isEnabled),
              deleteAction: {
                deleteSite(site.domain)
              }
            )
          }
        }
      }
    }
  }

  private var specificWebsitesSubtitle: String {
    if store.blockedSites.isEmpty {
      return "Add websites you do not want to open."
    }
    let enabledCount = store.enabledBlockedSites.count
    let totalCount = store.blockedSites.count
    return "\(enabledCount) blocked now. \(totalCount) saved."
  }

  private var legacySyncPending: Bool {
    store.legacyProviderSyncPending
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

  private func toggleSite(_ domain: String, enabled: Bool) {
    guard !pendingSiteDomains.contains(domain) else {
      return
    }
    pendingSiteDomains.insert(domain)
    Task {
      await store.setBlockedSite(domain, enabled: enabled)
      await MainActor.run {
        _ = pendingSiteDomains.remove(domain)
      }
    }
  }

  private func deleteSite(_ domain: String) {
    guard !pendingSiteDomains.contains(domain) else {
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

  private func turnOffHiddenRestrictions() {
    guard !resolvingHiddenRestrictions else {
      return
    }
    resolvingHiddenRestrictions = true
    Task {
      await store.refresh()
      await MainActor.run {
        resolvingHiddenRestrictions = false
      }
    }
  }

  private func categoryRule(_ id: BlockCategoryID) -> BlockCategoryRule {
    store.blockCategories.first { $0.id == id } ?? BlockCategoryRule(id: id, isEnabled: false)
  }

  private func blockedSite(_ domain: String) -> BlockedSiteRule {
    store.blockedSites.first { $0.domain == domain }
      ?? BlockedSiteRule(domain: domain, isEnabled: false)
  }
}

private struct HiddenRestrictionsNotice: View {
  let restrictions: String
  let isWorking: Bool
  let action: () -> Void

  var body: some View {
    ProductCallout(
      title: "Another web setting is still on",
      detail: "Still active: \(restrictions). Turn it off here if you want QuietGate to be the only setting changing web results.",
      systemImage: "exclamationmark.triangle.fill",
      tint: .orange
    ) {
      Button(action: action) {
        Label(
          isWorking ? "Checking" : "Turn Off Extra Setting",
          systemImage: isWorking ? "arrow.triangle.2.circlepath" : "power"
        )
      }
      .buttonStyle(.borderedProminent)
      .disabled(isWorking)
    }
  }
}

private struct CheckingBlocksNotice: View {
  var body: some View {
    ProductCallout(
      title: "Applying your change",
      detail: "This usually finishes in about a minute. Browser tabs that were already open can take a little longer to catch up.",
      systemImage: "clock.arrow.circlepath",
      tint: .blue
    )
  }
}

private struct BrowserChangesNotice: View {
  let title: String
  let detail: String
  let isWorking: Bool
  let action: () -> Void

  var body: some View {
    ProductCallout(
      title: "Browser changes saved",
      detail: detail,
      systemImage: "arrow.up.forward.app",
      tint: .blue
    ) {
      Button(action: action) {
        Label(title, systemImage: "arrow.up.forward.app")
      }
      .buttonStyle(.borderedProminent)
      .disabled(isWorking)
    }
  }
}

private struct BlocksNeedSetupNotice: View {
  let title: String
  let detail: String
  let action: () -> Void

  var body: some View {
    ProductCallout(
      title: title,
      detail: detail,
      systemImage: "lock.shield",
      tint: .orange
    ) {
      Button(action: action) {
        Label("Open Setup", systemImage: "checkmark.shield")
      }
      .buttonStyle(.borderedProminent)
    }
  }
}

private struct ChromeSpeedNotice: View {
  let title: String
  let detail: String
  let action: () -> Void

  var body: some View {
    ProductCallout(
      title: title,
      detail: detail,
      systemImage: "play.rectangle",
      tint: .blue
    ) {
      Button(action: action) {
        Label("Connect Browser", systemImage: "play.rectangle")
      }
    }
  }
}

private struct FriendlyCategoryRow: View {
  let rule: BlockCategoryRule
  let applicationStatus: BlockApplicationStatus
  let transaction: BlockingControlTransactionState
  @Binding var isOn: Bool
  let toggleDisabled: Bool

  var body: some View {
    HStack(alignment: .center, spacing: 14) {
      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 8) {
          Image(systemName: "shield.lefthalf.filled")
            .foregroundStyle(isOn ? .green : .secondary)
            .frame(width: 20)
          Text("Adult websites")
            .font(.headline)
        }

        Text("Blocks known adult sites and common ways around search filters.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        Text(statusText)
          .font(.caption)
          .foregroundStyle(statusColor)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 12)

      Toggle("", isOn: $isOn)
        .labelsHidden()
        .toggleStyle(.switch)
        .disabled(toggleDisabled)
        .accessibilityLabel("Adult websites")
    }
    .padding(.vertical, 12)
  }

  private var statusText: String {
    if let message = transaction.message {
      return friendlyTransactionMessage(message)
    }
    if isOn {
      if applicationStatus.tone == .positive {
        return "Blocking is on. Browser tabs can take about a minute to catch up."
      }
      return friendlyStatus(applicationStatus.text)
    }
    if applicationStatus.tone == .warning {
      return friendlyStatus(applicationStatus.text)
    }
    return "Off"
  }

  private var statusColor: Color {
    if transaction.message != nil {
      return transactionColor
    }
    switch applicationStatus.tone {
    case .positive:
      return isOn ? .green : .secondary
    case .warning:
      return .orange
    case .secondary:
      return .secondary
    }
  }

  private var transactionColor: Color {
    switch transaction {
    case .verified:
      return .green
    case .reverted:
      return .orange
    case .applying, .checkingCapability, .idle:
      return .secondary
    }
  }
}

private struct FriendlySiteRow: View {
  let site: BlockedSiteRule
  let applicationStatus: BlockApplicationStatus
  let transaction: BlockingControlTransactionState
  @Binding var isOn: Bool
  let toggleDisabled: Bool
  let deleteDisabled: Bool
  let deleteAction: () -> Void

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(site.domain)
          .font(.headline)
          .textSelection(.enabled)

        Text(statusText)
          .font(.caption)
          .foregroundStyle(statusColor)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer()

      Toggle("", isOn: $isOn)
        .labelsHidden()
        .toggleStyle(.switch)
        .disabled(toggleDisabled)
        .accessibilityLabel(site.domain)

      Button(role: .destructive, action: deleteAction) {
        Image(systemName: "trash")
      }
      .buttonStyle(.borderless)
      .disabled(deleteDisabled)
      .accessibilityLabel("Delete \(site.domain)")
      .help("Delete \(site.domain)")
    }
    .padding(.vertical, 10)
    .overlay(alignment: .bottom) {
      ProductDivider()
    }
  }

  private var statusText: String {
    if let message = transaction.message {
      return friendlyTransactionMessage(message)
    }
    if isOn {
      if applicationStatus.tone == .positive {
        return "Blocked by QuietGate. Browser tabs can take about a minute to catch up."
      }
      return friendlyStatus(applicationStatus.text)
    }
    if applicationStatus.tone == .warning {
      return friendlyStatus(applicationStatus.text)
    }
    return "Allowed by QuietGate"
  }

  private var statusColor: Color {
    if transaction.message != nil {
      return transactionColor
    }
    switch applicationStatus.tone {
    case .positive:
      return isOn ? .green : .secondary
    case .warning:
      return .orange
    case .secondary:
      return .secondary
    }
  }

  private var transactionColor: Color {
    switch transaction {
    case .verified:
      return .green
    case .reverted:
      return .orange
    case .applying, .checkingCapability, .idle:
      return .secondary
    }
  }
}

private func friendlyStatus(_ text: String) -> String {
  switch text {
  case "On here - finishing setup", "On here - not confirmed yet":
    return "Turning on. This usually takes about a minute."
  case "Off here - still blocked by account":
    return "Off in QuietGate. Another saved setting may still block it."
  case "Off here - this Mac still blocks it":
    return "Off in QuietGate. Something else on this Mac may still block it."
  case "Off here - checking":
    return "Turning off. This usually takes about a minute."
  case "Off here - waiting for check":
    return "Turning off. This usually takes about a minute."
  case "Cannot prove off":
    return "Off in QuietGate. This Mac is still catching up."
  case "Off - verified":
    return "Allowed by QuietGate"
  default:
    return text
  }
}

private func friendlyTransactionMessage(_ message: String) -> String {
  message
    .replacingOccurrences(of: "Blocking is on and verified.", with: "Blocking is on. Browser tabs can take about a minute to catch up.")
    .replacingOccurrences(of: "Blocking is off and verified.", with: "Allowed by QuietGate.")
}
