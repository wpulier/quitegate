import Foundation

enum ConnectionState: Equatable {
  case notConfigured
  case checking
  case connected
  case misconfigured(String)
  case error(String)

  var title: String {
    switch self {
    case .notConfigured: return "Not configured"
    case .checking: return "Checking"
    case .connected: return "Connected"
    case .misconfigured: return "Needs attention"
    case .error: return "Error"
    }
  }

  var detail: String {
    switch self {
    case .notConfigured:
      return "Connect Tortoise."
    case .checking:
      return "Checking your Tortoise connection."
    case .connected:
      return "Tortoise is connected."
    case .misconfigured(let message), .error(let message):
      return message
    }
  }
}
