import Foundation

struct BlockedApplicationRule: Codable, Equatable, Identifiable {
  var bundleIdentifier: String
  var displayName: String
  var isEnabled: Bool
  var addedAt: Date

  var id: String { bundleIdentifier }

  init(
    bundleIdentifier: String,
    displayName: String,
    isEnabled: Bool = true,
    addedAt: Date = Date()
  ) {
    self.bundleIdentifier = bundleIdentifier
    self.displayName = displayName
    self.isEnabled = isEnabled
    self.addedAt = addedAt
  }
}

struct RunningApplicationSnapshot: Equatable, Identifiable {
  var bundleIdentifier: String
  var displayName: String

  var id: String { bundleIdentifier }
}

struct ApplicationQuitResult: Equatable {
  var bundleIdentifier: String
  var displayName: String
  var didRequestQuit: Bool
}

enum MacStartupState: Equatable {
  case enabled
  case needsApproval
  case off
  case unavailable(String)

  var isOn: Bool {
    switch self {
    case .enabled, .needsApproval:
      return true
    case .off, .unavailable:
      return false
    }
  }

  var statusLabel: String {
    switch self {
    case .enabled:
      return "On"
    case .needsApproval:
      return "Approve"
    case .off:
      return "Off"
    case .unavailable:
      return "Unavailable"
    }
  }

  var detail: String {
    switch self {
    case .enabled:
      return "QuietGate starts when you sign in, so app blocking can keep working."
    case .needsApproval:
      return "macOS needs your approval before QuietGate can start when you sign in."
    case .off:
      return "Turn this on so QuietGate can keep app blocking ready after a restart."
    case .unavailable(let message):
      return message
    }
  }
}
