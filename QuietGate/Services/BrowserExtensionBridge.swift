import AppKit
import Foundation

protocol BrowserExtensionBridging {
  var chromeExtensionDirectoryURL: URL { get }
  var settingsURL: URL { get }
  var chromeStatusURL: URL { get }
  var installedNativeHostURL: URL { get }
  var nativeMessagingManifestURL: URL { get }
  func extensionDirectoryURL(for browser: BrowserConnectorID) -> URL
  func chromeExtensionAvailable() -> Bool
  func chromeExtensionStatus() -> ChromeExtensionStatus
  func chromeExtensionLoaded() -> Bool
  func writeSettings(_ settings: BrowserTuningSettings) throws
  func installNativeMessagingHost() throws
  func nativeMessagingHostInstalled() -> Bool
  func chromeHelperSnapshot() -> ChromeHelperSnapshot?
  func chromeHelperState(currentSettingsVersion: String, now: Date) -> ChromeHelperState
  func extensionAvailable(for browser: BrowserConnectorID) -> Bool
  func extensionStatus(for browser: BrowserConnectorID) -> ChromeExtensionStatus
  func extensionLoaded(for browser: BrowserConnectorID) -> Bool
  func installNativeMessagingHost(for browser: BrowserConnectorID) throws
  func nativeMessagingHostInstalled(for browser: BrowserConnectorID) -> Bool
  func helperSnapshot(for browser: BrowserConnectorID) -> ChromeHelperSnapshot?
  func helperState(
    for browser: BrowserConnectorID,
    currentSettingsVersion: String,
    now: Date
  ) -> ChromeHelperState
  func helperState(
    for browser: BrowserConnectorID,
    currentSettingsVersion: String,
    now: Date,
    extensionStatus: ChromeExtensionStatus
  ) -> ChromeHelperState
  func nativeMessagingManifestURL(for browser: BrowserConnectorID) -> URL
  func statusWatchURLs(for browser: BrowserConnectorID) -> [URL]
}

final class BrowserExtensionBridge: BrowserExtensionBridging {
  static let hostName = "com.willpulier.quietgate"
  static let chromiumExtensionID = "fedpnejbgmllajjlfkahlnjbgfmjjmmf"
  static let firefoxExtensionID = "quietgate@willpulier.com"
  static let extensionID = chromiumExtensionID

  private let fileManager: FileManager
  private let applicationSupportDirectory: URL
  private let nativeHostScriptURL: URL
  private let nativeMessagingHostsDirectories: [BrowserConnectorID: URL]
  private let extensionDirectoryURL: URL
  private let extensionDirectoryURLs: [BrowserConnectorID: URL]
  private let browserUserDataDirectoryURLs: [BrowserConnectorID: URL]
  private let runningBrowserCommandsProvider: () -> [String]

  init(
    fileManager: FileManager = .default,
    applicationSupportDirectory: URL? = nil,
    nativeHostScriptURL: URL? = nil,
    nativeMessagingHostsDirectory: URL? = nil,
    nativeMessagingHostsDirectories: [BrowserConnectorID: URL] = [:],
    chromeExtensionDirectoryURL: URL? = nil,
    firefoxExtensionDirectoryURL: URL? = nil,
    browserExtensionDirectoryURLs: [BrowserConnectorID: URL] = [:],
    chromeUserDataDirectoryURL: URL? = nil,
    browserUserDataDirectoryURLs: [BrowserConnectorID: URL] = [:],
    runningChromeCommandsProvider: @escaping () -> [String] = BrowserExtensionBridge.defaultRunningChromeCommands
  ) {
    self.fileManager = fileManager
    self.applicationSupportDirectory = applicationSupportDirectory ?? Self.defaultApplicationSupportDirectory()
    self.nativeHostScriptURL = nativeHostScriptURL ?? Self.defaultNativeHostScriptURL()
    self.extensionDirectoryURL = chromeExtensionDirectoryURL ?? Self.defaultChromeExtensionDirectoryURL()
    var extensionDirectories: [BrowserConnectorID: URL] = [
      .chrome: self.extensionDirectoryURL,
      .edge: self.extensionDirectoryURL,
      .brave: self.extensionDirectoryURL,
      .arc: self.extensionDirectoryURL,
      .firefox: firefoxExtensionDirectoryURL ?? Self.defaultFirefoxExtensionDirectoryURL(),
    ]
    browserExtensionDirectoryURLs.forEach { extensionDirectories[$0.key] = $0.value }
    self.extensionDirectoryURLs = extensionDirectories

    var userDataDirectories = Self.defaultBrowserUserDataDirectories(fileManager: fileManager)
    if let chromeUserDataDirectoryURL {
      userDataDirectories[.chrome] = chromeUserDataDirectoryURL
    }
    browserUserDataDirectoryURLs.forEach { userDataDirectories[$0.key] = $0.value }
    self.browserUserDataDirectoryURLs = userDataDirectories

    var manifestDirectories = userDataDirectories.mapValues {
      $0.appendingPathComponent("NativeMessagingHosts", isDirectory: true)
    }
    if BrowserConnectorID.firefox.isSupportedToday {
      manifestDirectories[.firefox] = Self.defaultFirefoxNativeMessagingHostsDirectory(fileManager: fileManager)
    }
    if let nativeMessagingHostsDirectory {
      manifestDirectories[.chrome] = nativeMessagingHostsDirectory
    }
    nativeMessagingHostsDirectories.forEach { manifestDirectories[$0.key] = $0.value }
    self.nativeMessagingHostsDirectories = manifestDirectories
    self.runningBrowserCommandsProvider = runningChromeCommandsProvider
  }

  var chromeExtensionDirectoryURL: URL {
    extensionDirectoryURL
  }

  var settingsURL: URL {
    applicationSupportDirectory.appendingPathComponent("extension-settings.json")
  }

  var chromeStatusURL: URL {
    statusURL(for: .chrome)
  }

  var installedNativeHostURL: URL {
    applicationSupportDirectory
      .appendingPathComponent("NativeHost", isDirectory: true)
      .appendingPathComponent("quietgate-native-host")
  }

  var nativeMessagingManifestURL: URL {
    nativeMessagingManifestURL(for: .chrome)
  }

  func extensionDirectoryURL(for browser: BrowserConnectorID) -> URL {
    extensionDirectoryURLs[browser] ?? extensionDirectoryURL
  }

  func writeSettings(_ settings: BrowserTuningSettings) throws {
    try fileManager.createDirectory(
      at: applicationSupportDirectory,
      withIntermediateDirectories: true
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(settings)
    try data.write(to: settingsURL, options: .atomic)
  }

  func chromeExtensionAvailable() -> Bool {
    extensionAvailable(for: .chrome)
  }

  func extensionAvailable(for browser: BrowserConnectorID) -> Bool {
    guard browser.isSupportedToday else {
      return false
    }
    return fileManager.fileExists(
      atPath: extensionDirectoryURL(for: browser)
        .appendingPathComponent("manifest.json")
        .path
    )
  }

  func chromeExtensionLoaded() -> Bool {
    extensionLoaded(for: .chrome)
  }

  func extensionLoaded(for browser: BrowserConnectorID) -> Bool {
    extensionStatus(for: browser).ready
  }

  func chromeExtensionStatus() -> ChromeExtensionStatus {
    extensionStatus(for: .chrome)
  }

  func extensionStatus(for browser: BrowserConnectorID) -> ChromeExtensionStatus {
    guard browser.isSupportedToday else {
      return .empty
    }

    if browser == .firefox {
      return firefoxExtensionStatus()
    }

    let runningCommands = runningBrowserCommandsProvider()
    return extensionStatus(for: browser, runningCommands: runningCommands)
  }

  private func extensionStatus(
    for browser: BrowserConnectorID,
    runningCommands: [String]
  ) -> ChromeExtensionStatus {
    var loadedProfiles: [String] = []
    var disabledProfiles: [String] = []
    var profileDisplayNames = chromiumProfileDisplayNames(for: browser)

    let profilePreferences = profilePreferences(for: browser)
    for profilePreference in profilePreferences {
      var sawExtensionSettings = false
      var sawDisabledState = false

      if profileDisplayNames[profilePreference.name] == nil,
         let displayName = chromeProfileDisplayName(from: profilePreference.preferencesURL) {
        profileDisplayNames[profilePreference.name] = displayName
      }

      for settingsURL in profilePreference.settingsURLs {
        guard let data = try? Data(contentsOf: settingsURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let extensions = object["extensions"] as? [String: Any],
              let settings = extensions["settings"] as? [String: Any],
              let extensionSettings = settings[Self.chromiumExtensionID] as? [String: Any] else {
          continue
        }

        sawExtensionSettings = true
        if extensionSettings["state"] as? Int == 0 {
          sawDisabledState = true
        } else {
          sawDisabledState = false
          break
        }
      }

      guard sawExtensionSettings else {
        continue
      }

      if sawDisabledState {
        disabledProfiles.append(profilePreference.name)
      } else {
        loadedProfiles.append(profilePreference.name)
      }
    }

    return ChromeExtensionStatus(
      selectedProfile: selectedProfile(for: browser, runningCommands: runningCommands),
      profileCount: profilePreferences.count,
      loadedProfiles: loadedProfiles.sorted(),
      disabledProfiles: disabledProfiles.sorted(),
      sessionProfiles: sessionLoadedProfiles(for: browser, runningCommands: runningCommands),
      profileDisplayNames: profileDisplayNames
    )
  }

  func installNativeMessagingHost() throws {
    try installNativeMessagingHost(for: .chrome)
  }

  func installNativeMessagingHost(for browser: BrowserConnectorID) throws {
    guard browser.isSupportedToday else {
      throw BrowserExtensionBridgeError.unsupportedBrowser(browser.displayName)
    }
    guard fileManager.fileExists(atPath: nativeHostScriptURL.path) else {
      throw BrowserExtensionBridgeError.missingNativeHost(nativeHostScriptURL.path)
    }

    try fileManager.createDirectory(
      at: installedNativeHostURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    if fileManager.fileExists(atPath: installedNativeHostURL.path) {
      try fileManager.removeItem(at: installedNativeHostURL)
    }
    try fileManager.copyItem(at: nativeHostScriptURL, to: installedNativeHostURL)
    try fileManager.setAttributes(
      [.posixPermissions: NSNumber(value: Int16(0o755))],
      ofItemAtPath: installedNativeHostURL.path
    )

    let data: Data
    if browser == .firefox {
      let manifest = FirefoxNativeMessagingManifest(
        name: Self.hostName,
        description: "QuietGate Firefox settings bridge",
        path: installedNativeHostURL.path,
        type: "stdio",
        allowedExtensions: [Self.firefoxExtensionID]
      )
      data = try Self.manifestData(manifest)
    } else {
      let manifest = NativeMessagingManifest(
        name: Self.hostName,
        description: "QuietGate \(browser.displayName) settings bridge",
        path: installedNativeHostURL.path,
        type: "stdio",
        allowedOrigins: ["chrome-extension://\(Self.chromiumExtensionID)/"]
      )
      data = try Self.manifestData(manifest)
    }

    try fileManager.createDirectory(
      at: nativeMessagingManifestURL(for: browser).deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try data.write(to: nativeMessagingManifestURL(for: browser), options: .atomic)
  }

  func nativeMessagingHostInstalled() -> Bool {
    nativeMessagingHostInstalled(for: .chrome)
  }

  func nativeMessagingHostInstalled(for browser: BrowserConnectorID) -> Bool {
    guard browser.isSupportedToday,
          fileManager.isExecutableFile(atPath: installedNativeHostURL.path),
          let data = try? Data(contentsOf: nativeMessagingManifestURL(for: browser)) else {
      return false
    }

    if browser == .firefox {
      guard let manifest = try? JSONDecoder().decode(FirefoxNativeMessagingManifest.self, from: data) else {
        return false
      }
      return manifest.name == Self.hostName &&
        manifest.path == installedNativeHostURL.path &&
        manifest.type == "stdio" &&
        manifest.allowedExtensions == [Self.firefoxExtensionID]
    }

    guard let manifest = try? JSONDecoder().decode(NativeMessagingManifest.self, from: data) else {
      return false
    }
    return manifest.name == Self.hostName &&
      manifest.path == installedNativeHostURL.path &&
      manifest.type == "stdio" &&
      manifest.allowedOrigins == ["chrome-extension://\(Self.chromiumExtensionID)/"]
  }

  func chromeHelperSnapshot() -> ChromeHelperSnapshot? {
    helperSnapshot(for: .chrome)
  }

  func helperSnapshot(for browser: BrowserConnectorID) -> ChromeHelperSnapshot? {
    guard browser.isSupportedToday,
          let data = try? Data(contentsOf: statusURL(for: browser)) else {
      return nil
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try? decoder.decode(ChromeHelperSnapshot.self, from: data)
  }

  func chromeHelperState(currentSettingsVersion: String, now: Date = Date()) -> ChromeHelperState {
    helperState(for: .chrome, currentSettingsVersion: currentSettingsVersion, now: now)
  }

  func helperState(
    for browser: BrowserConnectorID,
    currentSettingsVersion: String,
    now: Date = Date()
  ) -> ChromeHelperState {
    helperState(
      for: browser,
      currentSettingsVersion: currentSettingsVersion,
      now: now,
      extensionStatus: extensionStatus(for: browser)
    )
  }

  func helperState(
    for browser: BrowserConnectorID,
    currentSettingsVersion: String,
    now: Date = Date(),
    extensionStatus: ChromeExtensionStatus
  ) -> ChromeHelperState {
    guard browser.isSupportedToday else {
      return .notInstalled
    }

    guard nativeMessagingHostInstalled(for: browser) else {
      return extensionStatus.ready ? .nativeHostMissing : .notInstalled
    }

    guard let snapshot = helperSnapshot(for: browser) else {
      return extensionStatus.ready ? .needsChromeOpen : .notInstalled
    }
    guard snapshot.extensionID == Self.extensionID(for: browser) else {
      return .error("\(browser.displayName) reported the wrong QuietGate extension.")
    }
    if let selectedProfile = extensionStatus.selectedProfile?
      .trimmingCharacters(in: .whitespacesAndNewlines),
       !selectedProfile.isEmpty,
       let reportedProfile = snapshot.profileID?
      .trimmingCharacters(in: .whitespacesAndNewlines),
       !reportedProfile.isEmpty,
       reportedProfile != selectedProfile {
      return extensionStatus.ready ? .needsChromeOpen : .notInstalled
    }
    if let expectedVersion = expectedExtensionVersion(for: browser),
       let reportedVersion = snapshot.extensionVersion?
       .trimmingCharacters(in: .whitespacesAndNewlines),
       !reportedVersion.isEmpty,
       reportedVersion != expectedVersion {
      return .extensionNeedsReload
    }
    let expectedScriptVersions = expectedTunerVersions(for: browser)
    if !expectedScriptVersions.isEmpty {
      guard let reportedScriptVersions = snapshot.scriptVersions else {
        return .extensionNeedsReload
      }
      for (name, expectedVersion) in expectedScriptVersions {
        let reportedVersion = reportedScriptVersions[name]?
          .trimmingCharacters(in: .whitespacesAndNewlines)
        if reportedVersion != expectedVersion {
          return .extensionNeedsReload
        }
      }
    }
    if let error = snapshot.lastError,
       !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return .error(error)
    }
    guard snapshot.lastAppliedSettingsVersion == currentSettingsVersion else {
      return .needsSync
    }
    if now.timeIntervalSince(snapshot.lastSeenAt) > Self.chromeHelperStaleInterval {
      return .stale
    }
    return .current
  }

  private static let chromeHelperStaleInterval: TimeInterval = 24 * 60 * 60

  private static func defaultApplicationSupportDirectory() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library", isDirectory: true)
      .appendingPathComponent("Application Support", isDirectory: true)
      .appendingPathComponent("QuietGate", isDirectory: true)
  }

  private static func defaultChromeNativeMessagingHostsDirectory(fileManager: FileManager) -> URL {
    defaultUserDataDirectory(for: .chrome, fileManager: fileManager)
      .appendingPathComponent("NativeMessagingHosts", isDirectory: true)
  }

  private static func defaultFirefoxNativeMessagingHostsDirectory(fileManager: FileManager) -> URL {
    fileManager.homeDirectoryForCurrentUser
      .appendingPathComponent("Library", isDirectory: true)
      .appendingPathComponent("Application Support", isDirectory: true)
      .appendingPathComponent("Mozilla", isDirectory: true)
      .appendingPathComponent("NativeMessagingHosts", isDirectory: true)
  }

  private static func defaultChromeUserDataDirectory(fileManager: FileManager) -> URL {
    defaultUserDataDirectory(for: .chrome, fileManager: fileManager)
  }

  private static func defaultBrowserUserDataDirectories(
    fileManager: FileManager
  ) -> [BrowserConnectorID: URL] {
    Dictionary(
      uniqueKeysWithValues: BrowserConnectorID.allCases.compactMap { browser in
        guard browser.isSupportedToday,
              let url = browser.defaultUserDataDirectory(fileManager: fileManager) else {
          return nil
        }
        return (browser, url)
      }
    )
  }

  private static func defaultUserDataDirectory(
    for browser: BrowserConnectorID,
    fileManager: FileManager
  ) -> URL {
    browser.defaultUserDataDirectory(fileManager: fileManager)
      ?? fileManager.homeDirectoryForCurrentUser
        .appendingPathComponent("Library", isDirectory: true)
        .appendingPathComponent("Application Support", isDirectory: true)
        .appendingPathComponent(browser.displayName, isDirectory: true)
  }

  private static func defaultNativeHostScriptURL() -> URL {
    if let bundledURL = Bundle.main.url(forResource: "quietgate-native-host", withExtension: nil) {
      return bundledURL
    }

    let sourceURL = URL(fileURLWithPath: #filePath)
    return sourceURL
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("NativeHost", isDirectory: true)
      .appendingPathComponent("build", isDirectory: true)
      .appendingPathComponent("quietgate-native-host")
  }

  private static func defaultChromeExtensionDirectoryURL() -> URL {
    if let bundledURL = Bundle.main.url(forResource: "ChromeExtension", withExtension: nil) {
      return bundledURL
    }

    let sourceURL = URL(fileURLWithPath: #filePath)
    return sourceURL
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("ChromeExtension", isDirectory: true)
  }

  private static func defaultFirefoxExtensionDirectoryURL() -> URL {
    if let bundledURL = Bundle.main.url(forResource: "FirefoxExtension", withExtension: nil) {
      return bundledURL
    }

    let sourceURL = URL(fileURLWithPath: #filePath)
    return sourceURL
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("FirefoxExtension", isDirectory: true)
  }

  private static func extensionID(for browser: BrowserConnectorID) -> String {
    browser == .firefox ? firefoxExtensionID : chromiumExtensionID
  }

  private func expectedExtensionVersion(for browser: BrowserConnectorID) -> String? {
    let manifestURL = extensionDirectoryURL(for: browser).appendingPathComponent("manifest.json")
    guard let data = try? Data(contentsOf: manifestURL),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let version = object["version"] as? String else {
      return nil
    }

    let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private func expectedTunerVersions(for browser: BrowserConnectorID) -> [String: String] {
    let contentDirectoryURL = extensionDirectoryURL(for: browser)
      .appendingPathComponent("content", isDirectory: true)
    let tunerFiles = [
      "youtube": "youtube.js",
      "x": "x.js",
      "reddit": "reddit.js",
    ]

    var versions: [String: String] = [:]
    for (name, fileName) in tunerFiles {
      let tunerURL = contentDirectoryURL.appendingPathComponent(fileName)
      guard let source = try? String(contentsOf: tunerURL, encoding: .utf8),
            let version = Self.javaScriptConstant(named: "TUNER_VERSION", in: source) else {
        continue
      }
      versions[name] = version
    }
    return versions
  }

  private static func javaScriptConstant(named name: String, in source: String) -> String? {
    let pattern = #"const\s+\#(name)\s*=\s*"([^"]+)""#
    guard let expression = try? NSRegularExpression(pattern: pattern) else {
      return nil
    }
    let range = NSRange(source.startIndex..<source.endIndex, in: source)
    guard let match = expression.firstMatch(in: source, range: range),
          match.numberOfRanges > 1,
          let valueRange = Range(match.range(at: 1), in: source) else {
      return nil
    }
    let value = String(source[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
  }

  private static func manifestData<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(value)
  }

  private static func defaultRunningChromeCommands() -> [String] {
    defaultRunningBrowserCommands()
  }

  private static func defaultRunningBrowserCommands() -> [String] {
    NSWorkspace.shared.runningApplications.compactMap { application in
      application.executableURL?.path
    }
  }

  private func statusURL(for browser: BrowserConnectorID) -> URL {
    let name = browser == .chrome ? "chrome-status.json" : "\(browser.rawValue)-status.json"
    return applicationSupportDirectory.appendingPathComponent(name)
  }

  func nativeMessagingManifestURL(for browser: BrowserConnectorID) -> URL {
    let directory = nativeMessagingHostsDirectories[browser]
      ?? Self.defaultChromeNativeMessagingHostsDirectory(fileManager: fileManager)
    return directory.appendingPathComponent("\(Self.hostName).json")
  }

  func statusWatchURLs(for browser: BrowserConnectorID) -> [URL] {
    guard browser.isSupportedToday else {
      return []
    }

    var urls: [URL] = [
      statusURL(for: browser),
      statusURL(for: browser).deletingLastPathComponent(),
      nativeMessagingManifestURL(for: browser),
      nativeMessagingManifestURL(for: browser).deletingLastPathComponent(),
    ]

    let userDataURL = userDataDirectory(for: browser)

    if browser == .firefox {
      let profilesIniURL = userDataURL
        .deletingLastPathComponent()
        .appendingPathComponent("profiles.ini")
      urls.append(profilesIniURL)
      urls.append(contentsOf: firefoxProfileExtensionURLs())
    } else {
      urls.append(userDataURL.appendingPathComponent("Local State"))
      urls.append(contentsOf: profileMetadataWatchURLs(for: browser))
    }

    var seen = Set<String>()
    return urls.filter { url in
      let path = url.standardizedFileURL.path
      guard !seen.contains(path) else {
        return false
      }
      seen.insert(path)
      return true
    }
  }

  private func userDataDirectory(for browser: BrowserConnectorID) -> URL {
    browserUserDataDirectoryURLs[browser]
      ?? Self.defaultUserDataDirectory(for: browser, fileManager: fileManager)
  }

  private func profileMetadataWatchURLs(for browser: BrowserConnectorID) -> [URL] {
    guard let profileURLs = try? fileManager.contentsOfDirectory(
      at: userDataDirectory(for: browser),
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }

    return profileURLs.flatMap { profileURL -> [URL] in
      guard let values = try? profileURL.resourceValues(forKeys: [.isDirectoryKey]),
            values.isDirectory == true else {
        return []
      }
      return [
        profileURL.appendingPathComponent("Preferences"),
        profileURL.appendingPathComponent("Secure Preferences"),
      ]
    }
  }

  private func chromeProfileDisplayName(from preferencesURL: URL) -> String? {
    guard let data = try? Data(contentsOf: preferencesURL),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }
    return Self.profileDisplayName(fromPreferencesObject: object)
  }

  private func selectedProfile(
    for browser: BrowserConnectorID,
    runningCommands: [String]? = nil
  ) -> String? {
    if browser == .firefox {
      return selectedFirefoxProfile()
    }

    let runningProfiles = runningMainBrowserProfiles(for: browser, runningCommands: runningCommands)
    if runningProfiles.count == 1 {
      return runningProfiles[0]
    }

    let localStateURL = userDataDirectory(for: browser).appendingPathComponent("Local State")
    guard let data = try? Data(contentsOf: localStateURL),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let profile = object["profile"] as? [String: Any],
          let lastUsed = profile["last_used"] as? String,
          !lastUsed.isEmpty else {
      return nil
    }
    return lastUsed
  }

  private func chromiumProfileDisplayNames(for browser: BrowserConnectorID) -> [String: String] {
    let localStateURL = userDataDirectory(for: browser).appendingPathComponent("Local State")
    guard let data = try? Data(contentsOf: localStateURL),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let profile = object["profile"] as? [String: Any],
          let infoCache = profile["info_cache"] as? [String: Any] else {
      return [:]
    }

    var displayNames: [String: String] = [:]
    for (profileID, value) in infoCache {
      guard let entry = value as? [String: Any],
            let displayName = Self.firstProfileDisplayName(in: entry) else {
        continue
      }
      displayNames[profileID] = displayName
    }
    return displayNames
  }

  private static func profileDisplayName(fromPreferencesObject object: [String: Any]) -> String? {
    guard let profile = object["profile"] as? [String: Any] else {
      return nil
    }
    return firstProfileDisplayName(in: profile)
  }

  private static func firstProfileDisplayName(in object: [String: Any]) -> String? {
    let accountName = trimmedProfileValue(for: "user_name", in: object)
    for key in ["name", "local_profile_name", "gaia_name", "shortcut_name"] {
      guard let value = object[key] as? String else {
        continue
      }
      let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty {
        if let accountName,
           accountName.contains("@"),
           accountName.caseInsensitiveCompare(trimmed) != .orderedSame {
          return "\(trimmed), \(accountName)"
        }
        return trimmed
      }
    }
    return accountName
  }

  private static func trimmedProfileValue(
    for key: String,
    in object: [String: Any]
  ) -> String? {
    guard let value = object[key] as? String else {
      return nil
    }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private func runningMainBrowserProfiles(
    for browser: BrowserConnectorID,
    runningCommands: [String]? = nil
  ) -> [String] {
    let commands = runningCommands ?? runningBrowserCommandsProvider()
    let profiles = commands.compactMap { command -> String? in
      guard Self.isMainBrowserCommand(command, browser: browser) else {
        return nil
      }
      return Self.commandArgumentValue(named: "--profile-directory", in: command) ?? "Default"
    }

    return Array(Set(profiles)).sorted()
  }

  private static func isMainBrowserCommand(_ command: String, browser: BrowserConnectorID) -> Bool {
    guard let executablePathFragment = browser.executablePathFragment else {
      return false
    }
    return command.contains(executablePathFragment)
  }

  private func sessionLoadedProfiles(
    for browser: BrowserConnectorID,
    runningCommands: [String]? = nil
  ) -> [String] {
    guard browser != .firefox else {
      return []
    }

    let commands = runningCommands ?? runningBrowserCommandsProvider()
    let selectedProfile = selectedProfile(for: browser, runningCommands: commands)
    let extensionPath = extensionDirectoryURL(for: browser).path
    let profiles = commands.compactMap { command -> String? in
      guard Self.isMainBrowserCommand(command, browser: browser) else {
        return nil
      }
      guard command.contains("--load-extension"),
            command.contains(extensionPath) else {
        return nil
      }

      return Self.commandArgumentValue(named: "--profile-directory", in: command) ??
        selectedProfile ??
        "Default"
    }

    return Array(Set(profiles)).sorted()
  }

  private static func commandArgumentValue(named name: String, in command: String) -> String? {
    if let range = command.range(of: "\(name)=") {
      let tail = command[range.upperBound...]
      let value = tailValue(from: tail)
      return value.isEmpty ? nil : value
    }

    guard let range = command.range(of: "\(name) ") else {
      return nil
    }

    let tail = command[range.upperBound...]
    let value = tailValue(from: tail)
    return value.isEmpty ? nil : value
  }

  private static func tailValue(from tail: Substring) -> String {
    let value: Substring
    if let nextFlag = tail.range(of: " --") {
      value = tail[..<nextFlag.lowerBound]
    } else {
      value = tail
    }

    return value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
  }

  private func profilePreferences(for browser: BrowserConnectorID) -> [ChromeProfilePreference] {
    guard let profileURLs = try? fileManager.contentsOfDirectory(
      at: userDataDirectory(for: browser),
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }

    return profileURLs.compactMap { profileURL in
      guard let values = try? profileURL.resourceValues(forKeys: [.isDirectoryKey]),
            values.isDirectory == true else {
        return nil
      }
      let preferencesURL = profileURL.appendingPathComponent("Preferences")
      let securePreferencesURL = profileURL.appendingPathComponent("Secure Preferences")
      let settingsURLs = [preferencesURL, securePreferencesURL]
        .filter { fileManager.fileExists(atPath: $0.path) }
      return settingsURLs.isEmpty
        ? nil
        : ChromeProfilePreference(
          name: profileURL.lastPathComponent,
          preferencesURL: preferencesURL,
          settingsURLs: settingsURLs
        )
    }
  }

  private func firefoxExtensionStatus() -> ChromeExtensionStatus {
    let profiles = firefoxProfileExtensionDatabases()
    var loadedProfiles: [String] = []
    var disabledProfiles: [String] = []
    let profileDisplayNames = firefoxProfileDisplayNames()

    for profile in profiles {
      guard let addon = profile.database.addons.first(where: { $0.id == Self.firefoxExtensionID }) else {
        continue
      }
      if addon.active != false && addon.userDisabled != true {
        loadedProfiles.append(profile.name)
      } else {
        disabledProfiles.append(profile.name)
      }
    }

    let loaded = loadedProfiles.sorted()
    return ChromeExtensionStatus(
      selectedProfile: loaded.count == 1 ? loaded[0] : nil,
      profileCount: profiles.count,
      loadedProfiles: loaded,
      disabledProfiles: disabledProfiles.sorted(),
      sessionProfiles: [],
      profileDisplayNames: profileDisplayNames
    )
  }

  private func selectedFirefoxProfile() -> String? {
    let status = firefoxExtensionStatus()
    return status.readyProfiles.count == 1 ? status.readyProfiles[0] : nil
  }

  private func firefoxProfileExtensionDatabases() -> [FirefoxProfileExtensionDatabase] {
    firefoxProfileExtensionURLs().compactMap { extensionsURL in
      guard let data = try? Data(contentsOf: extensionsURL),
            let database = try? JSONDecoder().decode(FirefoxExtensionsDatabase.self, from: data) else {
        return nil
      }
      return FirefoxProfileExtensionDatabase(
        name: extensionsURL.deletingLastPathComponent().lastPathComponent,
        database: database
      )
    }
  }

  private func firefoxProfileExtensionURLs() -> [URL] {
    guard let profileURLs = try? fileManager.contentsOfDirectory(
      at: userDataDirectory(for: .firefox),
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }

    return profileURLs.compactMap { profileURL in
      guard let values = try? profileURL.resourceValues(forKeys: [.isDirectoryKey]),
            values.isDirectory == true else {
        return nil
      }
      return profileURL.appendingPathComponent("extensions.json")
    }
  }

  private func firefoxProfileDisplayNames() -> [String: String] {
    let profilesIniURL = userDataDirectory(for: .firefox)
      .deletingLastPathComponent()
      .appendingPathComponent("profiles.ini")
    guard let contents = try? String(contentsOf: profilesIniURL, encoding: .utf8) else {
      return [:]
    }

    var displayNames: [String: String] = [:]
    var section: [String: String] = [:]

    func flushSection() {
      guard let path = section["Path"],
            let name = section["Name"]?.trimmingCharacters(in: .whitespacesAndNewlines),
            !name.isEmpty else {
        return
      }
      let profileID = URL(fileURLWithPath: path).lastPathComponent
      if !profileID.isEmpty {
        displayNames[profileID] = name
      }
    }

    for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
      let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
      if line.hasPrefix("[") && line.hasSuffix("]") {
        flushSection()
        section = [:]
        continue
      }
      guard let separator = line.firstIndex(of: "=") else {
        continue
      }
      let key = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
      let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
      section[String(key)] = String(value)
    }
    flushSection()

    return displayNames
  }
}

private struct ChromeProfilePreference {
  let name: String
  let preferencesURL: URL
  let settingsURLs: [URL]
}

private struct FirefoxProfileExtensionDatabase {
  let name: String
  let database: FirefoxExtensionsDatabase
}

private struct FirefoxExtensionsDatabase: Decodable {
  let addons: [FirefoxAddon]
}

private struct FirefoxAddon: Decodable {
  let id: String
  let active: Bool?
  let userDisabled: Bool?
}

enum BrowserExtensionBridgeError: LocalizedError, Equatable {
  case missingNativeHost(String)
  case unsupportedBrowser(String)

  var errorDescription: String? {
    switch self {
    case .missingNativeHost(let path):
      return "QuietGate native messaging host was not found at \(path)."
    case .unsupportedBrowser(let name):
      return "\(name) is not supported by this QuietGate helper yet."
    }
  }
}

private struct NativeMessagingManifest: Codable {
  let name: String
  let description: String
  let path: String
  let type: String
  let allowedOrigins: [String]

  enum CodingKeys: String, CodingKey {
    case name
    case description
    case path
    case type
    case allowedOrigins = "allowed_origins"
  }
}

private struct FirefoxNativeMessagingManifest: Codable {
  let name: String
  let description: String
  let path: String
  let type: String
  let allowedExtensions: [String]

  enum CodingKeys: String, CodingKey {
    case name
    case description
    case path
    case type
    case allowedExtensions = "allowed_extensions"
  }
}
