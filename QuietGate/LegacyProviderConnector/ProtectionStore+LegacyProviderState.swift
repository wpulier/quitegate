import AppKit
import Foundation

extension ProtectionStore {
  #if DEBUG
  static func makeLegacyProviderRuntimeStore() -> ProtectionStore {
    ProtectionStore(
      makeClient: { LegacyProviderClient(apiKey: $0) },
      resolverService: LegacyProviderStatusService(),
      systemProfileChecker: MacConfigurationProfileService(),
      appleProfileGenerator: LegacyProviderAppleProfileGenerator(),
      localHostsScriptGenerator: LocalHostsBlockerScriptGenerator()
    )
  }
  #endif

  var legacyProviderControlConnected: Bool {
    guard configured,
          !legacyProviderKeyNeedsPermission,
          let legacyProviderVerifiedProfileID,
          !trimmedProfileID.isEmpty
    else {
      return false
    }
    return legacyProviderVerifiedProfileID.caseInsensitiveCompare(trimmedProfileID) == .orderedSame
  }

  var legacyProviderSetupStarted: Bool {
    configured || hasAPIKey || !trimmedProfileID.isEmpty || macOSLegacyProviderProfileInstalled
      || generatedAppleProfileURL != nil || resolverStatus != nil
  }

  var legacyProviderMacSetupURL: URL {
    #if DEBUG
    var components = URLComponents()
    components.scheme = "https"
    components.host = "apple.nextdns.io"
    components.path = "/"
    if !trimmedProfileID.isEmpty {
      components.queryItems = [
        URLQueryItem(name: "configuration", value: trimmedProfileID)
      ]
    }
    return components.url ?? URL(string: "https://apple.nextdns.io/")!
    #else
    return URL(fileURLWithPath: "/")
    #endif
  }

  var legacyProviderRulesURL: URL {
    #if DEBUG
    let profilePath = trimmedProfileID.isEmpty ? "" : "\(trimmedProfileID)/"
    return URL(string: "https://my.nextdns.io/\(profilePath)denylist")!
    #else
    return URL(fileURLWithPath: "/")
    #endif
  }

  var legacyMacConnectionReady: Bool {
    legacyMacConnectionUsesProvider && legacyMacConnectionProfileMatchesConfiguredProfile
  }

  var legacyMacConnectionUsesProvider: Bool {
    resolverStatus?.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "ok"
  }

  var legacyMacConnectionUsesAppleProfile: Bool {
    resolverStatus?.clientName?.trimmingCharacters(in: .whitespacesAndNewlines)
      .localizedCaseInsensitiveContains("apple-profile") == true
  }

  var detectedLegacyProviderProfileID: String? {
    guard let profile = resolverStatus?.profile?.trimmingCharacters(in: .whitespacesAndNewlines),
          !profile.isEmpty
    else {
      return nil
    }
    return profile
  }

  var legacyMacConnectionProfileDetected: Bool {
    detectedLegacyProviderProfileID != nil
  }

  var detectedLegacyProviderProfileLooksLikeAppleFingerprint: Bool {
    guard let detectedLegacyProviderProfileID else {
      return false
    }

    return detectedLegacyProviderProfileID.range(
      of: #"^fp[0-9a-f]{8,}$"#,
      options: [.regularExpression, .caseInsensitive]
    ) != nil
  }

  var legacyMacConnectionProfileMatchesConfiguredProfile: Bool {
    guard configured,
          let detectedLegacyProviderProfileID,
          !trimmedProfileID.isEmpty
    else {
      return false
    }
    if detectedLegacyProviderProfileID.caseInsensitiveCompare(trimmedProfileID) == .orderedSame {
      return true
    }

    // Apple encrypted DNS profiles can report an internal fp... identifier from
    // test.nextdns.io instead of the public profile ID visible in System Settings.
    return macOSConfiguredLegacyProviderProfileInstalled
      && (legacyMacConnectionUsesAppleProfile || detectedLegacyProviderProfileLooksLikeAppleFingerprint)
  }

  var legacyMacConnectionProfileMismatch: Bool {
    legacyMacConnectionUsesProvider && legacyMacConnectionProfileDetected && !legacyMacConnectionProfileMatchesConfiguredProfile
  }

  var legacyProviderHardBlockReady: Bool {
    legacyProviderControlConnected && legacyMacConnectionReady && !legacyProviderRulesSyncPending
  }

  var legacyProviderManagedRestrictionsActive: Bool {
    parentalControl?.quietGateManagedRestrictionActive == true
  }

  var hiddenLegacyProviderManagedRestrictionsActive: Bool {
    !hiddenLegacyProviderManagedRestrictionNames.isEmpty
  }

  var hiddenLegacyProviderManagedRestrictionNames: [String] {
    guard !adultContentBlockingEnabled,
          let parentalControl
    else {
      return []
    }

    var names: [String] = []
    if parentalControl.safeSearch {
      names.append("Google SafeSearch")
    }
    if parentalControl.youtubeRestrictedMode {
      names.append("YouTube Restricted Mode")
    }
    if parentalControl.blockBypass {
      names.append("bypass blocking")
    }
    if parentalControl.pornCategoryActive {
      names.append("adult-content category")
    }
    return names
  }

  var hiddenLegacyProviderManagedRestrictionsText: String? {
    let names = hiddenLegacyProviderManagedRestrictionNames
    guard !names.isEmpty else {
      return nil
    }
    return Self.legacyProviderFormattedList(names)
  }

  var legacyManagedRestrictionsText: String? {
    hiddenLegacyProviderManagedRestrictionsText
  }

  var legacyProviderSyncPending: Bool {
    legacyProviderConnectorEnabled && legacyProviderRulesSyncPending
  }

  var legacyBlockingProviderEnabled: Bool {
    legacyProviderConnectorEnabled
  }

  var legacyProviderAccountCheck: ReadinessCheck {
    let state: ReadinessState = legacyProviderControlConnected ? .ready : .actionNeeded
    let detail: String
    let action: ReadinessAction?
    if legacyProviderControlConnected {
      detail = "QuietGate can update the saved rules."
      action = nil
    } else if legacyProviderKeyNeedsPermission {
      detail =
        "macOS is protecting a saved setup key. Allow QuietGate to read it so blocking changes can sync."
      action = .allowSavedProviderCredentialAccess
    } else if case .error = connectionState {
      detail =
        "QuietGate could not use the saved connection. Connect again, then save again."
      action = .openLegacyProviderAccount
    } else if configured {
      detail = "The setup details are saved, but QuietGate has not verified them yet."
      action = .refreshProtectionStatus
    } else {
      detail = "Add the two connection codes."
      action = .openLegacyProviderAccount
    }

    return ReadinessCheck(
      id: .legacyProviderAccount,
      title: "Setup access",
      detail: detail,
      state: state,
      action: action
    )
  }

  var websiteBlockingCheck: ReadinessCheck {
    let detail: String
    if websiteBlockingReady {
      detail = "Blocking is ready on this Mac."
    } else if legacyProviderHardBlockReady {
      detail = "QuietGate needs a fresh status check before it can promise blocking is ready."
    } else if legacyMacConnectionReady && !legacyProviderControlConnected {
      detail = "This Mac is connected, but QuietGate still needs to verify saved access."
    } else if legacyProviderRulesSyncPending && legacyProviderControlConnected {
      detail =
        legacyProviderKeyNeedsPermission
        ? "Changes are saved. Allow setup access so QuietGate can send them."
        : "Changes are saved. Check the connection so QuietGate can confirm them."
    } else {
      detail = "Finish connection codes and Mac approval before saved blocks can work."
    }

    let action: ReadinessAction?
    if websiteBlockingReady || (configured && !legacyProviderControlConnected) {
      action = nil
    } else if legacyProviderRulesSyncPending && legacyProviderControlConnected {
      action = legacyProviderKeyNeedsPermission ? .allowSavedProviderCredentialAccess : .refreshProtectionStatus
    } else if !configured || legacyProviderKeyNeedsPermission {
      action = legacyProviderKeyNeedsPermission ? .allowSavedProviderCredentialAccess : .openLegacyProviderAccount
    } else if !legacyMacConnectionReady {
      action = legacyMacConnectionAction(checked: resolverStatus != nil)
    } else {
      action = .refreshProtectionStatus
    }

    return ReadinessCheck(
      id: .websiteBlocking,
      title: "System blocking",
      detail: detail,
      state: websiteBlockingReady ? .ready : .actionNeeded,
      action: action
    )
  }

  var legacyMacPermissionCheck: ReadinessCheck {
    let hasProfileID = !trimmedProfileID.isEmpty
    let detail: String
    let ready = macOSConfiguredLegacyProviderProfileInstalled || legacyMacConnectionReady
    if legacyMacConnectionReady {
      detail = "This Mac is using the approved QuietGate profile."
    } else if macOSConfiguredLegacyProviderProfileInstalled {
      detail = "QuietGate is approved in Device Management."
    } else if legacyMacConnectionUsesAppleProfile {
      detail =
        "This Mac has a blocking permission, but QuietGate cannot find its approved permission yet."
    } else if macOSLegacyProviderProfileInstalled {
      detail =
        "A blocking permission is approved, but QuietGate cannot match it to the saved setup."
    } else if generatedAppleProfileURL != nil {
      detail =
        "Mac approval is ready. Approve QuietGate in System Settings, then return here."
    } else if hasProfileID {
      detail = "Prepare Mac approval for this setup."
    } else {
      detail = "Finish setup, then prepare Mac approval."
    }

    return ReadinessCheck(
      id: .legacyMacPermission,
      title: "Mac permission",
      detail: detail,
      state: ready ? .ready : .actionNeeded,
      action: ready ? nil : appleProfileSetupAction
    )
  }

  var legacyMacConnectionCheck: ReadinessCheck {
    let ready = legacyMacConnectionReady
    let checked = resolverStatus != nil
    let detail: String
    if ready {
      if detectedLegacyProviderProfileID?.caseInsensitiveCompare(trimmedProfileID) == .orderedSame {
        detail = "This Mac is using the permission QuietGate updates."
      } else {
        detail =
          "This Mac is using the approved QuietGate permission. No action is needed."
      }
    } else if legacyMacConnectionUsesAppleProfile {
      detail =
        "This Mac has a blocking permission, but QuietGate cannot confirm it belongs to QuietGate. Approve the QuietGate permission, then return to QuietGate."
    } else if legacyMacConnectionUsesProvider && legacyMacConnectionProfileDetected {
      detail =
        "This Mac is using a different blocking setup. Open System Settings and switch this Mac to QuietGate, then return to QuietGate."
    } else if legacyMacConnectionUsesProvider {
      detail =
        "This Mac is using a blocking setup, but QuietGate cannot confirm which one. Install or enable the QuietGate approval."
    } else if let resolverStatus {
      detail =
        "This Mac reports \(resolverStatus.status). Install or enable the QuietGate permission."
    } else {
      detail = "Check whether this Mac is using QuietGate's approved permission."
    }

    return ReadinessCheck(
      id: .legacyMacConnection,
      title: "Mac permission",
      detail: detail,
      state: ready ? .ready : (checked ? .actionNeeded : .unknown),
      action: ready ? nil : legacyMacConnectionAction(checked: checked)
    )
  }

  func legacyMacConnectionAction(checked: Bool) -> ReadinessAction {
    guard checked else {
      return .checkLegacyMacConnection
    }
    if legacyMacConnectionProfileMismatch {
      if legacyMacConnectionUsesAppleProfile && !macOSConfiguredLegacyProviderProfileInstalled {
        return appleProfileSetupAction
      }
      return .openSystemProfiles
    }
    return appleProfileSetupAction
  }

  var legacyProviderCoverageStatus: String {
    guard configured else {
      return "Not configured"
    }
    if legacyProviderKeyNeedsPermission {
      return "Needs permission"
    }
    guard legacyProviderControlConnected else {
      return "Not connected"
    }
    if legacyProviderRulesSyncPending {
      return "Sync needed"
    }
    return legacyMacConnectionReady ? "Verified" : "Configured, not verified"
  }

  var appleProfileSetupAction: ReadinessAction {
    if generatedAppleProfileURL != nil {
      return .openSystemProfiles
    }
    return trimmedProfileID.isEmpty ? .openLegacyMacPermissionSetup : .createLegacyMacPermissionProfile
  }

  func openLegacyMacPermissionSetup() {
    #if DEBUG
    NSWorkspace.shared.open(legacyProviderMacSetupURL)
    #else
    errorMessage = DisabledLegacyProviderServiceError.disabled.localizedDescription
    #endif
  }

  func openLegacyProviderMacSetup() {
    openLegacyMacPermissionSetup()
  }

  func openLegacyProviderDashboard() {
    #if DEBUG
    openLegacyProviderConnectorURL("https://my.nextdns.io")
    #else
    errorMessage = DisabledLegacyProviderServiceError.disabled.localizedDescription
    #endif
  }

  func openLegacyProviderAccount() {
    #if DEBUG
    openLegacyProviderConnectorURL("https://my.nextdns.io/account")
    #else
    errorMessage = DisabledLegacyProviderServiceError.disabled.localizedDescription
    #endif
  }

  func openLegacyProviderAccountPage() {
    openLegacyProviderAccount()
  }

  func openLegacyProviderRules() {
    #if DEBUG
    NSWorkspace.shared.open(legacyProviderRulesURL)
    #else
    errorMessage = DisabledLegacyProviderServiceError.disabled.localizedDescription
    #endif
  }

  func openLegacyProviderAPIReference() {
    #if DEBUG
    openLegacyProviderConnectorURL("https://nextdns.github.io/api/")
    #else
    errorMessage = DisabledLegacyProviderServiceError.disabled.localizedDescription
    #endif
  }

  private func openLegacyProviderConnectorURL(_ value: String) {
    guard let url = URL(string: value) else {
      return
    }
    NSWorkspace.shared.open(url)
  }

  private static func legacyProviderFormattedList(_ values: [String]) -> String {
    switch values.count {
    case 0:
      return ""
    case 1:
      return values[0]
    case 2:
      return "\(values[0]) and \(values[1])"
    default:
      return values.dropLast().joined(separator: ", ") + ", and " + values.last!
    }
  }
}
