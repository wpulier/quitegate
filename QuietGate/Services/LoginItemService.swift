import Foundation
import ServiceManagement

protocol LoginItemServicing {
  var state: MacStartupState { get }
  func setEnabled(_ enabled: Bool) throws
}

struct MacLoginItemService: LoginItemServicing {
  var state: MacStartupState {
    switch SMAppService.mainApp.status {
    case .enabled:
      return .enabled
    case .requiresApproval:
      return .needsApproval
    case .notRegistered:
      return .off
    case .notFound:
      return .unavailable("QuietGate could not find the installed app yet. Move it to Applications, then turn this on.")
    @unknown default:
      return .unavailable("macOS could not read the startup setting.")
    }
  }

  func setEnabled(_ enabled: Bool) throws {
    let service = SMAppService.mainApp
    if enabled {
      guard service.status != .enabled, service.status != .requiresApproval else {
        return
      }
      try service.register()
    } else {
      guard service.status != .notRegistered else {
        return
      }
      try service.unregister()
    }
  }
}
