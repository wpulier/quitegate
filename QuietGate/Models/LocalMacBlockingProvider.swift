import Foundation

struct LocalMacBlockingProvider: Equatable {
  let blockedApplications: [BlockedApplicationRule]
  let runningApplications: [RunningApplicationSnapshot]
  let enforcementEnabled: Bool
  let startupState: MacStartupState

  var activeBlockedApplications: [BlockedApplicationRule] {
    blockedApplications.filter(\.isEnabled)
  }

  var runningBlockedApplications: [RunningApplicationSnapshot] {
    let blockedIDs = Set(activeBlockedApplications.map(\.bundleIdentifier))
    return runningApplications.filter { blockedIDs.contains($0.bundleIdentifier) }
  }

  var statusSummary: String {
    if activeBlockedApplications.isEmpty {
      return "No Mac apps are blocked yet."
    }
    let activeText =
      "\(activeBlockedApplications.count) \(activeBlockedApplications.count == 1 ? "app" : "apps")"
    if !enforcementEnabled {
      return "\(activeText) saved. App closing is paused."
    }
    if runningBlockedApplications.isEmpty {
      switch startupState {
      case .enabled:
        return "\(activeText) will close when opened."
      case .needsApproval:
        return "\(activeText) will close while QuietGate is open. Approve startup to keep it ready after restart."
      case .off, .unavailable:
        return "\(activeText) will close while QuietGate is open."
      }
    }
    let runningText =
      "\(runningBlockedApplications.count) blocked \(runningBlockedApplications.count == 1 ? "app" : "apps")"
    if startupState == .enabled {
      return "Closing \(runningText) now."
    }
    return "Closing \(runningText) now. Keep QuietGate open for app blocking."
  }

  var startupDetail: String {
    startupState.detail
  }

  var providerSnapshot: BlockingProviderSnapshot {
    let state: BlockingProviderState
    if enforcementEnabled {
      state = .ready(providerDetail)
    } else {
      state = .disabled(
        "App closing is paused. Turn it on in Apps when you want QuietGate to close selected apps."
      )
    }

    return BlockingProviderSnapshot(
      id: .localMac,
      title: "QuietGate Mac Blocker",
      kind: .localMac,
      state: state,
      activeRuleCount: activeBlockedApplications.count,
      destinationNames: ["This Mac"],
      isDefault: false,
      isLegacy: false
    )
  }

  private var providerDetail: String {
    if activeBlockedApplications.isEmpty {
      return startupState == .enabled
        ? "Ready on this Mac. QuietGate starts when you sign in."
        : "Ready on this Mac. Turn on startup so app blocking is ready after restart."
    }
    return statusSummary
  }
}
