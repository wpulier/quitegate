import Foundation

enum ReadinessCheckID: String, Codable, CaseIterable {
  case websiteBlocking
  case legacyProviderAccount
  case legacyMacPermission
  case legacyMacConnection
  case browserConnection
  case browserSettings
}

enum ReadinessScope {
  case all
  case blocker
  case tuner
  case selectedMode
}

enum ReadinessState: Equatable {
  case ready
  case actionNeeded
  case unknown

  var title: String {
    switch self {
    case .ready: return "Ready"
    case .actionNeeded: return "Action needed"
    case .unknown: return "Check"
    }
  }
}

enum ReadinessAction: Equatable {
  case allowSavedProviderCredentialAccess
  case refreshProtectionStatus
  case openLegacyProviderAccount
  case openLegacyMacPermissionSetup
  case createLegacyMacPermissionProfile
  case openSystemProfiles
  case checkThisMac
  case checkLegacyMacConnection
  case installLocalBlockerBackup
  case launchChromeTunerSession
  case openChromeDownload
  case showChromeExtensionFolder
  case installChromeSync
  case applyBrowserChanges(BrowserConnectorID)
  case openBrowserExtensionsPage(BrowserConnectorID)
  case launchBrowserTunerSession(BrowserConnectorID)
  case openBrowserDownload(BrowserConnectorID)
  case installBrowserSync(BrowserConnectorID)

  var title: String {
    switch self {
    case .allowSavedProviderCredentialAccess: return "Allow Access"
    case .refreshProtectionStatus: return "Update Status"
    case .openLegacyProviderAccount: return "Open Setup"
    case .openLegacyMacPermissionSetup: return "Open Settings"
    case .createLegacyMacPermissionProfile: return "Prepare Settings"
    case .openSystemProfiles: return "Approve"
    case .checkThisMac: return "Update This Mac"
    case .checkLegacyMacConnection: return "Update Connection"
    case .installLocalBlockerBackup: return "Set Up Backup"
    case .launchChromeTunerSession: return "Connect Chrome"
    case .openChromeDownload: return "Get Chrome"
    case .showChromeExtensionFolder: return "Connect Chrome"
    case .installChromeSync: return "Update Chrome"
    case .applyBrowserChanges(let browser): return "Apply to \(browser.displayName)"
    case .openBrowserExtensionsPage(let browser): return "Open \(browser.displayName) Extensions"
    case .launchBrowserTunerSession(let browser): return "Connect \(browser.displayName)"
    case .openBrowserDownload(let browser): return "Get \(browser.displayName)"
    case .installBrowserSync(let browser): return "Update \(browser.displayName)"
    }
  }

  var systemImage: String {
    switch self {
    case .allowSavedProviderCredentialAccess: return "key"
    case .refreshProtectionStatus: return "arrow.clockwise"
    case .openLegacyProviderAccount: return "person.crop.circle"
    case .openLegacyMacPermissionSetup: return "apple.logo"
    case .createLegacyMacPermissionProfile: return "doc.badge.plus"
    case .openSystemProfiles: return "checkmark.seal"
    case .checkThisMac: return "checklist"
    case .checkLegacyMacConnection: return "network"
    case .installLocalBlockerBackup: return "lock.shield"
    case .launchChromeTunerSession: return "play.circle"
    case .openChromeDownload: return "arrow.down.circle"
    case .showChromeExtensionFolder: return "puzzlepiece.extension"
    case .installChromeSync: return "arrow.triangle.2.circlepath"
    case .applyBrowserChanges: return "arrow.up.forward.app"
    case .openBrowserExtensionsPage: return "puzzlepiece.extension"
    case .launchBrowserTunerSession: return "play.circle"
    case .openBrowserDownload: return "arrow.down.circle"
    case .installBrowserSync: return "arrow.triangle.2.circlepath"
    }
  }
}

struct ReadinessCheck: Identifiable, Equatable {
  let id: ReadinessCheckID
  let title: String
  let detail: String
  let state: ReadinessState
  let action: ReadinessAction?
}
