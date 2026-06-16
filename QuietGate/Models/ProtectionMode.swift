import Foundation

enum ProtectionMode: String, Codable {
  case on
  case off

  var title: String {
    switch self {
    case .on: return "On"
    case .off: return "Off"
    }
  }

  var actionTitle: String {
    switch self {
    case .on: return "Turn Off"
    case .off: return "Turn On"
    }
  }

  var systemImage: String {
    switch self {
    case .on: return "shield.lefthalf.filled"
    case .off: return "shield"
    }
  }
}
