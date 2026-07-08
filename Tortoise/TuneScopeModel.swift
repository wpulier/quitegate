import Foundation

/// One chip in the Tune screen's "where this applies" scope card: the iPhone's
/// own Safari extension, or one connected desktop browser profile.
struct TuneScopeEntry: Identifiable, Equatable {
  enum Kind: Equatable {
    case iphoneSafari
    case desktopProfile(brand: String)
  }

  let id: String
  let kind: Kind
  let title: String
  /// The one next-step line for attention states; nil when nothing is needed.
  let detail: String?
  let status: ConnectionStatus
}

/// Everything the Tune scope UI needs, pure-computed so both the card and the
/// zero-surface banner render from one honest answer to "what is enforcing
/// these toggles right now?".
struct TuneScopeState: Equatable {
  let iphoneSafari: TuneScopeEntry
  let desktopProfiles: [TuneScopeEntry]
  let showAddComputerAffordance: Bool
  let hasAnyActiveSurface: Bool
  let showSetupFirstBanner: Bool
}

enum TuneScope {
  /// Maps the controller-resolved Safari extension state onto the canonical
  /// ConnectionStatus. `.unavailable` (manual setup, no SFSafariExtensionManager)
  /// counts as on only when acknowledged AND heartbeat-fresh — the same rule as
  /// IOSYouTubeScreenTimeController.safariExtensionConnected.
  static func safariConnectionStatus(
    state: IOSSafariExtensionState,
    acknowledged: Bool,
    heartbeatFresh: Bool
  ) -> ConnectionStatus {
    switch state {
    case .connected:
      return .on
    case .enabledWaitingForHeartbeat, .unknown:
      return .attention(.catchingUp)
    case .disabled, .failed:
      return .attention(.setupIncomplete)
    case .unavailable:
      return (acknowledged && heartbeatFresh) ? .on : .attention(.setupIncomplete)
    }
  }

  /// The chip's next-step line. Silent when the surface is on or still resolving.
  static func safariHint(
    state: IOSSafariExtensionState,
    acknowledged: Bool,
    heartbeatFresh: Bool
  ) -> String? {
    switch state {
    case .connected, .unknown:
      return nil
    case .enabledWaitingForHeartbeat:
      return TuneScopeCopy.safariHintVerify
    case .disabled, .failed:
      return TuneScopeCopy.safariHintNeedsSetup
    case .unavailable:
      if acknowledged && heartbeatFresh { return nil }
      return acknowledged ? TuneScopeCopy.safariHintVerify : TuneScopeCopy.safariHintNeedsSetup
    }
  }

  /// The iOS Tune tab's scope state. The Safari entry comes from the local
  /// enforcement controller (NOT the cloud device list — the iPhone's extension
  /// is not a registered device); desktop profiles come from the account devices.
  static func iosState(
    safariExtensionState: IOSSafariExtensionState,
    safariAcknowledged: Bool,
    safariHeartbeatFresh: Bool,
    devices: [TortoiseDevice],
    now: Date
  ) -> TuneScopeState {
    let safariStatus = safariConnectionStatus(
      state: safariExtensionState,
      acknowledged: safariAcknowledged,
      heartbeatFresh: safariHeartbeatFresh
    )
    let iphoneSafari = TuneScopeEntry(
      id: "iphone-safari",
      kind: .iphoneSafari,
      title: TuneScopeCopy.iphoneSafariChip,
      detail: safariHint(
        state: safariExtensionState,
        acknowledged: safariAcknowledged,
        heartbeatFresh: safariHeartbeatFresh
      ),
      status: safariStatus
    )

    let desktopProfiles = devices
      .filter(\.isBrowserProfile)
      .sorted { lhs, rhs in
        switch (lhs.lastSeenDate, rhs.lastSeenDate) {
        case let (l?, r?): return l > r
        case (_?, nil): return true
        case (nil, _?): return false
        case (nil, nil): return lhs.id < rhs.id
        }
      }
      .compactMap { device -> TuneScopeEntry? in
        guard case .browser(let brand) = device.deviceKind else { return nil }
        return TuneScopeEntry(
          id: device.id,
          kind: .desktopProfile(brand: brand),
          title: "\(brand.capitalized) · \(device.displayName)",
          detail: nil,
          status: ConnectionStatus.resolve(
            lastSeenAt: device.lastSeenDate,
            isEnforcingLatestPolicy: true,
            isPausedByUser: false,
            now: now
          )
        )
      }

    let hasAnyActiveSurface = safariStatus == .on || desktopProfiles.contains { $0.status == .on }
    return TuneScopeState(
      iphoneSafari: iphoneSafari,
      desktopProfiles: desktopProfiles,
      showAddComputerAffordance: desktopProfiles.isEmpty,
      hasAnyActiveSurface: hasAnyActiveSurface,
      // .unknown is a launch-transient; suppress the banner until the state is determinate.
      showSetupFirstBanner: !hasAnyActiveSurface && safariExtensionState != .unknown
    )
  }

  /// The Mac Tune scope card's iPhone chips: one per account iOS device, status
  /// from device freshness only (Safari-extension liveness isn't readable from
  /// the cloud device list yet).
  static func macIPhoneEntries(devices: [TortoiseDevice], now: Date) -> [TuneScopeEntry] {
    devices
      .filter { $0.deviceKind == .iphone }
      .map { device in
        TuneScopeEntry(
          id: device.id,
          kind: .iphoneSafari,
          title: "\(device.displayName) · Safari",
          detail: nil,
          status: ConnectionStatus.resolve(
            lastSeenAt: device.lastSeenDate,
            isEnforcingLatestPolicy: true,
            isPausedByUser: false,
            now: now
          )
        )
      }
  }
}

/// Every user-facing string for the tuning-scope UX, in one place. The framing
/// rule: name what a control affects (the websites / the apps), never the
/// mechanism (extensions), and always pair a state with its next step.
enum TuneScopeCopy {
  // APPS lane (this iPhone)
  static let appsLaneTitle = "Apps on this iPhone"
  static let appsLaneDetail = "Block, daily limit, schedule. Apple doesn't allow tuning inside apps."

  // WEBSITES lane
  static let websitesLaneTitle = "Websites"
  static let websitesLaneDetail = "Synced everywhere you browse"
  static let iphoneSafariChip = "Safari on this iPhone"
  static let safariHintNeedsSetup = "Enable in Safari settings"
  static let safariHintVerify = "Open Safari to verify"
  static let addComputerTitle = "Add your computer"
  static let addComputerDetail = "Tuning also works in Chrome and Firefox on desktop."

  // Zero-active-surface banner
  static let setupFirstTitle = "Nothing is enforcing these yet"
  static let setupFirstDetail = "Turn on the Safari extension so tuning takes effect on this iPhone."
  static let setupFirstCTA = "Enable Safari extension"

  // Tune header
  static let tuneSubtitle = "Shape the websites you visit — in Safari here and in your computer's browsers."
}
