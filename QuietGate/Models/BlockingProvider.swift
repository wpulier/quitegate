import Foundation

enum BlockingProviderID: String, CaseIterable, Hashable, Identifiable {
  case browserHelpers
  case localMac
  case legacyProvider

  var id: String { rawValue }
}

enum BlockingProviderKind: Equatable {
  case browser
  case localMac
  case dns
}

enum BlockingProviderState: Equatable {
  case ready(String)
  case actionNeeded(String)
  case planned(String)
  case disabled(String)

  var isReady: Bool {
    if case .ready = self {
      return true
    }
    return false
  }

  var detail: String {
    switch self {
    case .ready(let detail), .actionNeeded(let detail), .planned(let detail), .disabled(let detail):
      return detail
    }
  }
}

struct BlockingProviderSnapshot: Equatable, Identifiable {
  let id: BlockingProviderID
  let title: String
  let kind: BlockingProviderKind
  let state: BlockingProviderState
  let activeRuleCount: Int
  let destinationNames: [String]
  let isDefault: Bool
  let isLegacy: Bool

  var isReady: Bool {
    state.isReady
  }
}

struct BlockingProviderCatalog: Equatable {
  let providers: [BlockingProviderSnapshot]

  var defaultProvider: BlockingProviderSnapshot? {
    providers.first { $0.isDefault }
  }

  static func browserFirst(
    browser: BlockingProviderSnapshot,
    localMac: BlockingProviderSnapshot
  ) -> BlockingProviderCatalog {
    BlockingProviderCatalog(providers: [browser, localMac])
  }

  static func legacy(
    dns: BlockingProviderSnapshot,
    browser: BlockingProviderSnapshot,
    localMac: BlockingProviderSnapshot? = nil
  ) -> BlockingProviderCatalog {
    var providers = [dns, browser]
    if let localMac {
      providers.append(localMac)
    }
    return BlockingProviderCatalog(providers: providers)
  }
}

enum BrowserConnectorID: String, CaseIterable, Hashable, Identifiable {
  case chrome
  case edge
  case brave
  case arc
  case firefox
  case safari

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .chrome: return "Chrome"
    case .edge: return "Edge"
    case .brave: return "Brave"
    case .arc: return "Arc"
    case .firefox: return "Firefox"
    case .safari: return "Safari"
    }
  }

  var isSupportedToday: Bool {
    switch self {
    case .chrome, .edge, .brave, .arc, .firefox:
      return true
    case .safari:
      return false
    }
  }

  var applicationBundleNames: [String] {
    switch self {
    case .chrome: return ["Google Chrome.app"]
    case .edge: return ["Microsoft Edge.app"]
    case .brave: return ["Brave Browser.app"]
    case .arc: return ["Arc.app"]
    case .firefox: return ["Firefox.app"]
    case .safari: return ["Safari.app"]
    }
  }

  var applicationBundleIdentifier: String? {
    switch self {
    case .chrome: return "com.google.Chrome"
    case .edge: return "com.microsoft.edgemac"
    case .brave: return "com.brave.Browser"
    case .arc: return "company.thebrowser.Browser"
    case .firefox: return "org.mozilla.firefox"
    case .safari: return "com.apple.Safari"
    }
  }

  var executablePathFragment: String? {
    switch self {
    case .chrome:
      return "Google Chrome.app/Contents/MacOS/Google Chrome"
    case .edge:
      return "Microsoft Edge.app/Contents/MacOS/Microsoft Edge"
    case .brave:
      return "Brave Browser.app/Contents/MacOS/Brave Browser"
    case .arc:
      return "Arc.app/Contents/MacOS/Arc"
    case .firefox:
      return "Firefox.app/Contents/MacOS/firefox"
    case .safari:
      return "Safari.app/Contents/MacOS/Safari"
    }
  }

  var internalPageScheme: String? {
    switch self {
    case .chrome: return "chrome"
    case .edge: return "edge"
    case .brave: return "brave"
    case .arc: return "arc"
    case .firefox, .safari:
      return nil
    }
  }

  var downloadURL: URL? {
    switch self {
    case .chrome:
      return URL(string: "https://www.google.com/chrome/")
    case .edge:
      return URL(string: "https://www.microsoft.com/edge/download")
    case .brave:
      return URL(string: "https://brave.com/download/")
    case .arc:
      return URL(string: "https://arc.net/download")
    case .firefox:
      return URL(string: "https://www.mozilla.org/firefox/new/")
    case .safari:
      return nil
    }
  }

  var extensionStoreURL: URL? {
    switch self {
    case .chrome, .edge, .brave, .arc:
      return Self.infoPlistURL(forKey: "QuietGateChromiumExtensionStoreURL")
    case .firefox:
      return Self.infoPlistURL(forKey: "QuietGateFirefoxExtensionStoreURL")
    case .safari:
      return nil
    }
  }

  func defaultUserDataDirectory(fileManager: FileManager = .default) -> URL? {
    let support = fileManager.homeDirectoryForCurrentUser
      .appendingPathComponent("Library", isDirectory: true)
      .appendingPathComponent("Application Support", isDirectory: true)

    switch self {
    case .chrome:
      return support
        .appendingPathComponent("Google", isDirectory: true)
        .appendingPathComponent("Chrome", isDirectory: true)
    case .edge:
      return support.appendingPathComponent("Microsoft Edge", isDirectory: true)
    case .brave:
      return support
        .appendingPathComponent("BraveSoftware", isDirectory: true)
        .appendingPathComponent("Brave-Browser", isDirectory: true)
    case .arc:
      return support
        .appendingPathComponent("Arc", isDirectory: true)
        .appendingPathComponent("User Data", isDirectory: true)
    case .firefox:
      return support
        .appendingPathComponent("Firefox", isDirectory: true)
        .appendingPathComponent("Profiles", isDirectory: true)
    case .safari:
      return nil
    }
  }

  var likelyApplicationURLs: [URL] {
    let roots = [
      URL(fileURLWithPath: "/Applications", isDirectory: true),
      URL(fileURLWithPath: "/System/Applications", isDirectory: true),
      URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        .appendingPathComponent("Applications", isDirectory: true),
    ]

    return roots.flatMap { root in
      applicationBundleNames.map { root.appendingPathComponent($0, isDirectory: true) }
    }
  }

  func isInstalled(fileManager: FileManager = .default) -> Bool {
    likelyApplicationURLs.contains { fileManager.fileExists(atPath: $0.path) }
  }

  private static func infoPlistURL(forKey key: String) -> URL? {
    guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
      return nil
    }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
          let url = URL(string: trimmed),
          ["https"].contains(url.scheme?.lowercased() ?? "") else {
      return nil
    }
    return url
  }
}

enum BrowserConnectorSupport: Equatable {
  case supportedToday
  case planned
}

enum BrowserConnectorState: Equatable {
  case connected(String)
  case connectedPending(String)
  case actionNeeded(String)
  case comingSoon(String)
  case error(String)

  var isConnected: Bool {
    switch self {
    case .connected, .connectedPending:
      return true
    case .actionNeeded, .comingSoon, .error:
      return false
    }
  }

  var isCurrent: Bool {
    if case .connected = self {
      return true
    }
    return false
  }

  var detail: String {
    switch self {
    case .connected(let detail), .connectedPending(let detail), .actionNeeded(let detail),
      .comingSoon(let detail), .error(let detail):
      return detail
    }
  }
}

struct BrowserConnectorSnapshot: Equatable, Identifiable {
  let id: BrowserConnectorID
  let support: BrowserConnectorSupport
  let isInstalled: Bool
  let state: BrowserConnectorState
  let activeRuleCount: Int
  let settingsVersion: String
  let selectedProfile: String?
  let selectedProfileLabel: String?
  let connectedProfiles: [String]
  let connectedProfileLabels: [String]
  let lastSeenAt: Date?
  let nextAction: ReadinessAction?
  let isPrimary: Bool

  var displayName: String {
    id.displayName
  }

  var isConnected: Bool {
    state.isConnected
  }

  var isCurrent: Bool {
    state.isCurrent
  }

  var profileScopeText: String? {
    if !connectedProfileLabels.isEmpty {
      let noun = connectedProfileLabels.count == 1 ? "profile" : "profiles"
      return "\(displayName) \(noun): \(Self.formattedList(connectedProfileLabels))"
    }
    if let selectedProfileLabel {
      return "\(displayName) profile: \(selectedProfileLabel)"
    }
    return nil
  }

  var currentProfileScopeText: String? {
    guard let selectedProfileLabel else {
      return nil
    }
    return "\(displayName) profile: \(selectedProfileLabel)"
  }

  private static func formattedList(_ values: [String]) -> String {
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
