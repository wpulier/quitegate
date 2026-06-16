import XCTest
@testable import QuietGate

final class BrowserExtensionBridgeTests: XCTestCase {
  func testWriteSettingsUsesExtensionStorageShape() throws {
    let root = try temporaryDirectory()
    let bridge = BrowserExtensionBridge(
      applicationSupportDirectory: root.appendingPathComponent("Application Support")
    )

    let settings = BrowserTuningSettings(
      mode: .strict,
      updatedAt: Date(timeIntervalSince1970: 0)
    )
    try bridge.writeSettings(settings)

    let data = try Data(contentsOf: bridge.settingsURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(BrowserTuningSettings.self, from: data)

    XCTAssertEqual(decoded.mode, .strict)
    XCTAssertEqual(decoded.features["youtubeHome"], true)
    XCTAssertEqual(decoded.features["youtubeVideoSidebar"], true)
    XCTAssertEqual(decoded.features["youtubeComments"], true)
    XCTAssertEqual(decoded.features["youtubeRecommendations"], true)
    XCTAssertEqual(decoded.features["youtubeEndScreenCards"], true)
    XCTAssertEqual(decoded.features["youtubeFundraisers"], true)
    XCTAssertEqual(decoded.features["youtubeMixes"], true)
    XCTAssertEqual(decoded.features["youtubeMerch"], true)
    XCTAssertEqual(decoded.features["youtubeVideoInfo"], true)
    XCTAssertEqual(decoded.features["youtubeTopHeader"], true)
    XCTAssertEqual(decoded.features["youtubeNotifications"], true)
    XCTAssertEqual(decoded.features["youtubeExplore"], true)
    XCTAssertEqual(decoded.features["youtubeMoreFromYouTube"], true)
    XCTAssertEqual(decoded.features["youtubeSubscriptions"], true)
    XCTAssertEqual(decoded.features["youtubeAutoplay"], true)
    XCTAssertEqual(decoded.features["youtubeAnnotations"], true)
    XCTAssertEqual(decoded.features["youtubeUsageTracking"], true)
    XCTAssertEqual(decoded.features["youtubeDailyLimit"], true)
    XCTAssertEqual(decoded.features["xSensitiveMedia"], true)
    XCTAssertEqual(decoded.features["xExplicitContent"], true)
    XCTAssertEqual(decoded.features["xExplicitSearch"], true)
    XCTAssertEqual(decoded.features["xVideos"], true)
    XCTAssertEqual(decoded.features["xExploreTrends"], true)
    XCTAssertEqual(decoded.features["instagramReels"], true)
    XCTAssertEqual(decoded.features["instagramSuggested"], true)
    XCTAssertEqual(decoded.features["redditPopularAll"], true)
    XCTAssertEqual(decoded.features["redditNSFW"], true)
    XCTAssertEqual(decoded.features["redditSidebars"], true)
    XCTAssertEqual(decoded.options.explicitHideStyle, .post)
    XCTAssertEqual(decoded.options.youtubeDailyLimitMinutes, 30)
    XCTAssertEqual(decoded.blockedDomains, [])
    XCTAssertEqual(decoded.blockedCategories, [])
    XCTAssertEqual(decoded.settingsVersion, settings.settingsVersion)
    XCTAssertTrue(decoded.settingsVersion.contains("mode=strict"))
    XCTAssertTrue(decoded.settingsVersion.contains("categories="))
  }

  func testSettingsVersionIncludesTuningFeaturesAndOptions() {
    let base = BrowserTuningSettings(mode: .open)
    var features = base.features
    features[BrowserTuningFeature.xVideos.rawValue] = true

    let tuned = BrowserTuningSettings(mode: .open, features: features)
    let styled = BrowserTuningSettings(
      mode: .open,
      features: features,
      options: BrowserTuningOptions(explicitHideStyle: .media)
    )

    XCTAssertNotEqual(base.settingsVersion, tuned.settingsVersion)
    XCTAssertNotEqual(tuned.settingsVersion, styled.settingsVersion)
    XCTAssertTrue(tuned.settingsVersion.contains("xVideos=1"))
    XCTAssertTrue(styled.settingsVersion.contains("categories="))
    XCTAssertTrue(styled.settingsVersion.contains("options=explicitHideStyle=media"))
    XCTAssertTrue(styled.settingsVersion.contains("youtubeDailyLimitMinutes=30"))
  }

  func testBrowserTuningSettingsDecodesLegacySettingsWithoutOptions() throws {
    let data = """
      {
        "mode": "open",
        "features": {},
        "blockedDomains": [],
        "settingsVersion": "legacy",
        "updatedAt": "1970-01-01T00:00:00Z"
      }
      """.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let decoded = try decoder.decode(BrowserTuningSettings.self, from: data)

    XCTAssertEqual(decoded.options, .defaultValue)
    XCTAssertEqual(decoded.blockedCategories, [])
  }

  func testChromeHelperStateRequiresChromeOriginHeartbeat() throws {
    let root = try temporaryDirectory()
    let applicationSupportURL = root.appendingPathComponent("Application Support")
    let nativeHostsURL = root.appendingPathComponent("NativeMessagingHosts")
    let hostURL = root.appendingPathComponent("quietgate-native-host")
    try "#!/usr/bin/env node\n".write(to: hostURL, atomically: true, encoding: .utf8)
    let chromeURL = root.appendingPathComponent("Chrome", isDirectory: true)
    let profileURL = chromeURL.appendingPathComponent("Default", isDirectory: true)
    try FileManager.default.createDirectory(at: profileURL, withIntermediateDirectories: true)
    try writeLocalState(selectedProfile: "Default", to: chromeURL)
    try writeChromePreferences(
      [
        "extensions": [
          "settings": [
            "fedpnejbgmllajjlfkahlnjbgfmjjmmf": [
              "state": 1
            ]
          ]
        ]
      ],
      to: profileURL.appendingPathComponent("Preferences")
    )

    let bridge = BrowserExtensionBridge(
      applicationSupportDirectory: applicationSupportURL,
      nativeHostScriptURL: hostURL,
      nativeMessagingHostsDirectory: nativeHostsURL,
      chromeUserDataDirectoryURL: chromeURL,
      runningChromeCommandsProvider: { [] }
    )
    try bridge.installNativeMessagingHost()

    let version = "mode=focus|features=|domains=x.com"
    XCTAssertEqual(
      bridge.chromeHelperState(currentSettingsVersion: version, now: Date(timeIntervalSince1970: 10)),
      .needsChromeOpen
    )

    try writeChromeStatus(
      to: bridge.chromeStatusURL,
      settingsVersion: version,
      seenAt: Date(timeIntervalSince1970: 5)
    )

    XCTAssertEqual(
      bridge.chromeHelperState(currentSettingsVersion: version, now: Date(timeIntervalSince1970: 10)),
      .current
    )
    XCTAssertEqual(
      bridge.chromeHelperState(currentSettingsVersion: "new-version", now: Date(timeIntervalSince1970: 10)),
      .needsSync
    )
  }

  func testChromeHelperStateIgnoresHeartbeatFromDifferentSelectedProfile() throws {
    let root = try temporaryDirectory()
    let applicationSupportURL = root.appendingPathComponent("Application Support")
    let nativeHostsURL = root.appendingPathComponent("NativeMessagingHosts")
    let hostURL = root.appendingPathComponent("quietgate-native-host")
    try "#!/usr/bin/env node\n".write(to: hostURL, atomically: true, encoding: .utf8)
    let chromeURL = root.appendingPathComponent("Chrome", isDirectory: true)
    let defaultProfileURL = chromeURL.appendingPathComponent("Default", isDirectory: true)
    let otherProfileURL = chromeURL.appendingPathComponent("Profile 10", isDirectory: true)
    try FileManager.default.createDirectory(at: defaultProfileURL, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: otherProfileURL, withIntermediateDirectories: true)
    try writeLocalState(selectedProfile: "Default", to: chromeURL)
    let preferences: [String: Any] = [
      "extensions": [
        "settings": [
          "fedpnejbgmllajjlfkahlnjbgfmjjmmf": [
            "state": 1
          ]
        ]
      ]
    ]
    try writeChromePreferences(preferences, to: defaultProfileURL.appendingPathComponent("Preferences"))
    try writeChromePreferences(preferences, to: otherProfileURL.appendingPathComponent("Preferences"))

    let bridge = BrowserExtensionBridge(
      applicationSupportDirectory: applicationSupportURL,
      nativeHostScriptURL: hostURL,
      nativeMessagingHostsDirectory: nativeHostsURL,
      chromeUserDataDirectoryURL: chromeURL,
      runningChromeCommandsProvider: { [] }
    )
    try bridge.installNativeMessagingHost()

    let version = "mode=focus|features=|domains=x.com"
    try writeChromeStatus(
      to: bridge.chromeStatusURL,
      settingsVersion: version,
      seenAt: Date(timeIntervalSince1970: 5),
      profileID: "Profile 10",
      profileName: "Other"
    )

    XCTAssertEqual(
      bridge.chromeHelperState(currentSettingsVersion: version, now: Date(timeIntervalSince1970: 10)),
      .needsChromeOpen
    )
  }

  func testChromeHelperStateTreatsOlderExtensionVersionAsReloadRequired() throws {
    let root = try temporaryDirectory()
    let applicationSupportURL = root.appendingPathComponent("Application Support")
    let nativeHostsURL = root.appendingPathComponent("NativeMessagingHosts")
    let hostURL = root.appendingPathComponent("quietgate-native-host")
    let extensionURL = root.appendingPathComponent("ChromeExtension", isDirectory: true)
    try "#!/usr/bin/env node\n".write(to: hostURL, atomically: true, encoding: .utf8)
    try FileManager.default.createDirectory(at: extensionURL, withIntermediateDirectories: true)
    try #"{"manifest_version":3,"version":"0.1.2"}"#
      .write(to: extensionURL.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)

    let bridge = BrowserExtensionBridge(
      applicationSupportDirectory: applicationSupportURL,
      nativeHostScriptURL: hostURL,
      nativeMessagingHostsDirectory: nativeHostsURL,
      chromeExtensionDirectoryURL: extensionURL,
      runningChromeCommandsProvider: { [] }
    )
    try bridge.installNativeMessagingHost()

    let version = "mode=focus|features=|domains=x.com"
    try writeChromeStatus(
      to: bridge.chromeStatusURL,
      settingsVersion: version,
      seenAt: Date(timeIntervalSince1970: 5),
      extensionVersion: "0.1.0"
    )

    XCTAssertEqual(
      bridge.chromeHelperState(currentSettingsVersion: version, now: Date(timeIntervalSince1970: 10)),
      .extensionNeedsReload
    )
  }

  func testChromeHelperStateTreatsMissingTunerVersionAsReloadRequired() throws {
    let root = try temporaryDirectory()
    let applicationSupportURL = root.appendingPathComponent("Application Support")
    let nativeHostsURL = root.appendingPathComponent("NativeMessagingHosts")
    let hostURL = root.appendingPathComponent("quietgate-native-host")
    let extensionURL = root.appendingPathComponent("ChromeExtension", isDirectory: true)
    let contentURL = extensionURL.appendingPathComponent("content", isDirectory: true)
    try "#!/usr/bin/env node\n".write(to: hostURL, atomically: true, encoding: .utf8)
    try FileManager.default.createDirectory(at: contentURL, withIntermediateDirectories: true)
    try #"{"manifest_version":3,"version":"0.1.5"}"#
      .write(to: extensionURL.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
    try #"const TUNER_VERSION = "2026.06.04.01";"#
      .write(to: contentURL.appendingPathComponent("x.js"), atomically: true, encoding: .utf8)

    let bridge = BrowserExtensionBridge(
      applicationSupportDirectory: applicationSupportURL,
      nativeHostScriptURL: hostURL,
      nativeMessagingHostsDirectory: nativeHostsURL,
      chromeExtensionDirectoryURL: extensionURL,
      runningChromeCommandsProvider: { [] }
    )
    try bridge.installNativeMessagingHost()

    let version = "mode=focus|features=|domains=x.com"
    try writeChromeStatus(
      to: bridge.chromeStatusURL,
      settingsVersion: version,
      seenAt: Date(timeIntervalSince1970: 5),
      extensionVersion: "0.1.5",
      scriptVersions: nil
    )

    XCTAssertEqual(
      bridge.chromeHelperState(currentSettingsVersion: version, now: Date(timeIntervalSince1970: 10)),
      .extensionNeedsReload
    )
  }

  func testChromeHelperStateTreatsOlderTunerVersionAsReloadRequired() throws {
    let root = try temporaryDirectory()
    let applicationSupportURL = root.appendingPathComponent("Application Support")
    let nativeHostsURL = root.appendingPathComponent("NativeMessagingHosts")
    let hostURL = root.appendingPathComponent("quietgate-native-host")
    let extensionURL = root.appendingPathComponent("ChromeExtension", isDirectory: true)
    let contentURL = extensionURL.appendingPathComponent("content", isDirectory: true)
    try "#!/usr/bin/env node\n".write(to: hostURL, atomically: true, encoding: .utf8)
    try FileManager.default.createDirectory(at: contentURL, withIntermediateDirectories: true)
    try #"{"manifest_version":3,"version":"0.1.5"}"#
      .write(to: extensionURL.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
    try #"const TUNER_VERSION = "2026.06.04.01";"#
      .write(to: contentURL.appendingPathComponent("x.js"), atomically: true, encoding: .utf8)

    let bridge = BrowserExtensionBridge(
      applicationSupportDirectory: applicationSupportURL,
      nativeHostScriptURL: hostURL,
      nativeMessagingHostsDirectory: nativeHostsURL,
      chromeExtensionDirectoryURL: extensionURL,
      runningChromeCommandsProvider: { [] }
    )
    try bridge.installNativeMessagingHost()

    let version = "mode=focus|features=|domains=x.com"
    try writeChromeStatus(
      to: bridge.chromeStatusURL,
      settingsVersion: version,
      seenAt: Date(timeIntervalSince1970: 5),
      extensionVersion: "0.1.5",
      scriptVersions: ["x": "2026.06.02.7"]
    )

    XCTAssertEqual(
      bridge.chromeHelperState(currentSettingsVersion: version, now: Date(timeIntervalSince1970: 10)),
      .extensionNeedsReload
    )
  }

  func testFreshChromeHeartbeatCountsBeforePreferencesFlush() throws {
    let root = try temporaryDirectory()
    let applicationSupportURL = root.appendingPathComponent("Application Support")
    let nativeHostsURL = root.appendingPathComponent("NativeMessagingHosts")
    let hostURL = root.appendingPathComponent("quietgate-native-host")
    try "#!/usr/bin/env node\n".write(to: hostURL, atomically: true, encoding: .utf8)
    let chromeURL = root.appendingPathComponent("Chrome", isDirectory: true)
    let profileURL = chromeURL.appendingPathComponent("Default", isDirectory: true)
    try FileManager.default.createDirectory(at: profileURL, withIntermediateDirectories: true)
    try writeLocalState(selectedProfile: "Default", to: chromeURL)
    try writeChromePreferences([:], to: profileURL.appendingPathComponent("Preferences"))

    let bridge = BrowserExtensionBridge(
      applicationSupportDirectory: applicationSupportURL,
      nativeHostScriptURL: hostURL,
      nativeMessagingHostsDirectory: nativeHostsURL,
      chromeUserDataDirectoryURL: chromeURL,
      runningChromeCommandsProvider: { [] }
    )
    try bridge.installNativeMessagingHost()

    let version = "mode=focus|features=|domains=x.com"
    try writeChromeStatus(
      to: bridge.chromeStatusURL,
      settingsVersion: version,
      seenAt: Date(timeIntervalSince1970: 5)
    )

    XCTAssertFalse(bridge.chromeExtensionLoaded())
    XCTAssertEqual(
      bridge.chromeHelperState(currentSettingsVersion: version, now: Date(timeIntervalSince1970: 10)),
      .current
    )
  }

  func testInstallNativeMessagingHostWritesChromeManifest() throws {
    let root = try temporaryDirectory()
    let hostURL = root.appendingPathComponent("quietgate-native-host")
    try "#!/usr/bin/env node\n".write(to: hostURL, atomically: true, encoding: .utf8)

    let nativeHostsURL = root.appendingPathComponent("NativeMessagingHosts")
    let bridge = BrowserExtensionBridge(
      applicationSupportDirectory: root.appendingPathComponent("Application Support"),
      nativeHostScriptURL: hostURL,
      nativeMessagingHostsDirectory: nativeHostsURL
    )

    try bridge.installNativeMessagingHost()

    let manifestURL = nativeHostsURL.appendingPathComponent("com.willpulier.quietgate.json")
    let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any]

    XCTAssertEqual(manifest?["name"] as? String, "com.willpulier.quietgate")
    XCTAssertEqual(manifest?["path"] as? String, bridge.installedNativeHostURL.path)
    XCTAssertEqual(manifest?["type"] as? String, "stdio")
    XCTAssertEqual(
      manifest?["allowed_origins"] as? [String],
      ["chrome-extension://fedpnejbgmllajjlfkahlnjbgfmjjmmf/"]
    )
    XCTAssertTrue(FileManager.default.isExecutableFile(atPath: bridge.installedNativeHostURL.path))
    XCTAssertTrue(bridge.nativeMessagingHostInstalled())
  }

  func testInstallNativeMessagingHostWritesEdgeBraveAndArcManifests() throws {
    let root = try temporaryDirectory()
    let hostURL = root.appendingPathComponent("quietgate-native-host")
    try "#!/usr/bin/env node\n".write(to: hostURL, atomically: true, encoding: .utf8)

    let edgeHostsURL = root.appendingPathComponent("EdgeNativeMessagingHosts")
    let braveHostsURL = root.appendingPathComponent("BraveNativeMessagingHosts")
    let arcHostsURL = root.appendingPathComponent("ArcNativeMessagingHosts")
    let bridge = BrowserExtensionBridge(
      applicationSupportDirectory: root.appendingPathComponent("Application Support"),
      nativeHostScriptURL: hostURL,
      nativeMessagingHostsDirectories: [
        .edge: edgeHostsURL,
        .brave: braveHostsURL,
        .arc: arcHostsURL,
      ]
    )

    try bridge.installNativeMessagingHost(for: .edge)
    try bridge.installNativeMessagingHost(for: .brave)
    try bridge.installNativeMessagingHost(for: .arc)

    XCTAssertTrue(bridge.nativeMessagingHostInstalled(for: .edge))
    XCTAssertTrue(bridge.nativeMessagingHostInstalled(for: .brave))
    XCTAssertTrue(bridge.nativeMessagingHostInstalled(for: .arc))
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: edgeHostsURL.appendingPathComponent("com.willpulier.quietgate.json").path
      )
    )
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: braveHostsURL.appendingPathComponent("com.willpulier.quietgate.json").path
      )
    )
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: arcHostsURL.appendingPathComponent("com.willpulier.quietgate.json").path
      )
    )
  }

  func testInstallNativeMessagingHostWritesFirefoxManifest() throws {
    let root = try temporaryDirectory()
    let hostURL = root.appendingPathComponent("quietgate-native-host")
    try "#!/usr/bin/env node\n".write(to: hostURL, atomically: true, encoding: .utf8)

    let firefoxHostsURL = root.appendingPathComponent("FirefoxNativeMessagingHosts")
    let bridge = BrowserExtensionBridge(
      applicationSupportDirectory: root.appendingPathComponent("Application Support"),
      nativeHostScriptURL: hostURL,
      nativeMessagingHostsDirectories: [.firefox: firefoxHostsURL]
    )

    try bridge.installNativeMessagingHost(for: .firefox)

    let manifestURL = firefoxHostsURL.appendingPathComponent("com.willpulier.quietgate.json")
    let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any]

    XCTAssertEqual(manifest?["name"] as? String, "com.willpulier.quietgate")
    XCTAssertEqual(manifest?["path"] as? String, bridge.installedNativeHostURL.path)
    XCTAssertEqual(manifest?["type"] as? String, "stdio")
    XCTAssertEqual(manifest?["allowed_extensions"] as? [String], ["quietgate@willpulier.com"])
    XCTAssertNil(manifest?["allowed_origins"])
    XCTAssertTrue(FileManager.default.isExecutableFile(atPath: bridge.installedNativeHostURL.path))
    XCTAssertTrue(bridge.nativeMessagingHostInstalled(for: .firefox))
  }

  func testChromeExtensionAvailabilityUsesManifest() throws {
    let root = try temporaryDirectory()
    let extensionURL = root.appendingPathComponent("ChromeExtension", isDirectory: true)
    try FileManager.default.createDirectory(at: extensionURL, withIntermediateDirectories: true)
    try "{}".write(
      to: extensionURL.appendingPathComponent("manifest.json"),
      atomically: true,
      encoding: .utf8
    )

    let bridge = BrowserExtensionBridge(chromeExtensionDirectoryURL: extensionURL)

    XCTAssertEqual(bridge.chromeExtensionDirectoryURL, extensionURL)
    XCTAssertTrue(bridge.chromeExtensionAvailable())
  }

  func testFirefoxExtensionAvailabilityUsesFirefoxManifest() throws {
    let root = try temporaryDirectory()
    let chromeExtensionURL = root.appendingPathComponent("ChromeExtension", isDirectory: true)
    let firefoxExtensionURL = root.appendingPathComponent("FirefoxExtension", isDirectory: true)
    try FileManager.default.createDirectory(at: chromeExtensionURL, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: firefoxExtensionURL, withIntermediateDirectories: true)
    try "{}".write(
      to: firefoxExtensionURL.appendingPathComponent("manifest.json"),
      atomically: true,
      encoding: .utf8
    )

    let bridge = BrowserExtensionBridge(
      chromeExtensionDirectoryURL: chromeExtensionURL,
      firefoxExtensionDirectoryURL: firefoxExtensionURL
    )

    XCTAssertEqual(bridge.extensionDirectoryURL(for: .firefox), firefoxExtensionURL)
    XCTAssertTrue(bridge.extensionAvailable(for: .firefox))
    XCTAssertFalse(bridge.chromeExtensionAvailable())
  }

  func testChromeExtensionUsesDNRInsteadOfDocumentWriteBlocker() throws {
    let extensionURL = try XCTUnwrap(
      Bundle.main.url(forResource: "ChromeExtension", withExtension: nil)
    )
    let background = try String(
      contentsOf: extensionURL.appendingPathComponent("background.js"),
      encoding: .utf8
    )
    let manifest = try String(
      contentsOf: extensionURL.appendingPathComponent("manifest.json"),
      encoding: .utf8
    )
    let youtube = try String(
      contentsOf: extensionURL
        .appendingPathComponent("content")
        .appendingPathComponent("youtube.js"),
      encoding: .utf8
    )
    let xTuner = try String(
      contentsOf: extensionURL
        .appendingPathComponent("content")
        .appendingPathComponent("x.js"),
      encoding: .utf8
    )
    let xPageDetector = try String(
      contentsOf: extensionURL
        .appendingPathComponent("content")
        .appendingPathComponent("x-page.js"),
      encoding: .utf8
    )
    let instagramTuner = try String(
      contentsOf: extensionURL
        .appendingPathComponent("content")
        .appendingPathComponent("instagram.js"),
      encoding: .utf8
    )
    let redditTuner = try String(
      contentsOf: extensionURL
        .appendingPathComponent("content")
        .appendingPathComponent("reddit.js"),
      encoding: .utf8
    )

    XCTAssertTrue(background.contains("declarativeNetRequest.updateDynamicRules"))
    XCTAssertTrue(background.contains("urlFilter: `||${domain}^`"))
    XCTAssertTrue(background.contains("type: \"redirect\""))
    XCTAssertTrue(background.contains("extensionPath: \"/blocked/blocked.html\""))
    XCTAssertTrue(background.contains("recordAppliedSettings"))
    XCTAssertTrue(background.contains("lastAppliedSettingsVersion !== settings.settingsVersion"))
    XCTAssertTrue(background.contains("action: { type: \"block\" }"))
    XCTAssertTrue(background.contains("initiatorDomains: X_INITIATOR_DOMAINS"))
    XCTAssertTrue(background.contains("REDDIT_INITIATOR_DOMAINS"))
    XCTAssertTrue(background.contains("SOCIAL_ADULT_PREVIEW_DOMAINS"))
    XCTAssertTrue(background.contains("\"redgifs.com\""))
    XCTAssertTrue(background.contains("||video.twimg.com^"))
    XCTAssertTrue(background.contains("pageJs: \"content/x-page.js\""))
    XCTAssertTrue(background.contains("world: \"MAIN\""))
    XCTAssertTrue(background.contains("X_TUNER_VERSION"))
    XCTAssertTrue(background.contains("REDDIT_TUNER_VERSION"))
    XCTAssertTrue(background.contains("YOUTUBE_TUNER_VERSION"))
    XCTAssertTrue(background.contains("tunerNeedsInjection"))
    XCTAssertFalse(background.contains("chrome.alarms"))
    XCTAssertFalse(manifest.contains("\"alarms\""))
    XCTAssertFalse(manifest.contains("content/blocker.js"))
    XCTAssertTrue(manifest.contains("\"https://x.com/*\""))
    XCTAssertTrue(manifest.contains("\"https://twitter.com/*\""))
    XCTAssertTrue(manifest.contains("\"js\": [\"content/x-page.js\"]"))
    XCTAssertTrue(manifest.contains("\"world\": \"MAIN\""))
    XCTAssertTrue(manifest.contains("\"css\": [\"content/x.css\"]"))
    XCTAssertTrue(manifest.contains("\"content/x.js\""))
    XCTAssertTrue(manifest.contains("\"content/platform-controls.js\""))
    XCTAssertTrue(manifest.contains("\"https://www.instagram.com/*\""))
    XCTAssertTrue(manifest.contains("\"css\": [\"content/instagram.css\"]"))
    XCTAssertTrue(manifest.contains("\"js\": [\"content/instagram.js\"]"))
    XCTAssertTrue(manifest.contains("\"https://www.reddit.com/*\""))
    XCTAssertTrue(manifest.contains("\"css\": [\"content/reddit.css\"]"))
    XCTAssertTrue(manifest.contains("\"content/reddit.js\""))
    XCTAssertFalse(youtube.contains("setInterval"))
    XCTAssertTrue(youtube.contains("quietgateTunerVersion"))
    XCTAssertTrue(youtube.contains("youtubeUsageTracking"))
    XCTAssertTrue(youtube.contains("youtubeDailyLimit"))
    XCTAssertFalse(xTuner.contains("setInterval"))
    XCTAssertTrue(xPageDetector.contains("window.__quietgateXSensitiveDetectorInstalled"))
    XCTAssertTrue(xPageDetector.contains("possibly_sensitive"))
    XCTAssertTrue(xPageDetector.contains("sensitive_media_warning"))
    XCTAssertTrue(xPageDetector.contains("mediaVisibilityResults"))
    XCTAssertTrue(xPageDetector.contains("media_key"))
    XCTAssertTrue(xPageDetector.contains("mediaIDs"))
    XCTAssertTrue(xPageDetector.contains("window.postMessage"))
    XCTAssertFalse(xPageDetector.contains("classList.add"))
    XCTAssertFalse(instagramTuner.contains("setInterval"))
    XCTAssertFalse(redditTuner.contains("setInterval"))
    XCTAssertTrue(xTuner.contains("quietgate.syncNativeSettings"))
    XCTAssertTrue(xTuner.contains("storage.onChanged"))
    XCTAssertTrue(xTuner.contains("quietgateXTunerVersion"))
    XCTAssertTrue(xTuner.contains("__quietgateXTunerController"))
    XCTAssertTrue(xTuner.contains("quietgateXSensitiveMediaCount"))
    XCTAssertTrue(xTuner.contains("hasSensitiveMediaID"))
    XCTAssertTrue(xTuner.contains("xExplicitContent"))
    XCTAssertTrue(xTuner.contains("xExplicitSearch"))
    XCTAssertTrue(instagramTuner.contains("quietgate.syncNativeSettings"))
    XCTAssertTrue(redditTuner.contains("quietgate.syncNativeSettings"))
    XCTAssertTrue(redditTuner.contains("quietgateRedditTunerVersion"))
    XCTAssertTrue(redditTuner.contains("redditNSFW"))
    XCTAssertTrue(redditTuner.contains("redgifs.com"))
  }

  func testBrowserHelpersUseQuietGateBlockPages() throws {
    let chromeExtensionURL = try XCTUnwrap(
      Bundle.main.url(forResource: "ChromeExtension", withExtension: nil)
    )
    let firefoxExtensionURL = try XCTUnwrap(
      Bundle.main.url(forResource: "FirefoxExtension", withExtension: nil)
    )

    let chromeManifest = try String(
      contentsOf: chromeExtensionURL.appendingPathComponent("manifest.json"),
      encoding: .utf8
    )
    let firefoxManifest = try String(
      contentsOf: firefoxExtensionURL.appendingPathComponent("manifest.json"),
      encoding: .utf8
    )
    let chromeBlockPage = try String(
      contentsOf: chromeExtensionURL
        .appendingPathComponent("blocked")
        .appendingPathComponent("blocked.html"),
      encoding: .utf8
    )
    let firefoxBlockPage = try String(
      contentsOf: firefoxExtensionURL
        .appendingPathComponent("blocked")
        .appendingPathComponent("blocked.html"),
      encoding: .utf8
    )
    let firefoxBackground = try String(
      contentsOf: firefoxExtensionURL.appendingPathComponent("background.js"),
      encoding: .utf8
    )
    let firefoxYouTube = try String(
      contentsOf: firefoxExtensionURL
        .appendingPathComponent("content")
        .appendingPathComponent("youtube.js"),
      encoding: .utf8
    )
    let firefoxX = try String(
      contentsOf: firefoxExtensionURL
        .appendingPathComponent("content")
        .appendingPathComponent("x.js"),
      encoding: .utf8
    )
    let chromeX = try String(
      contentsOf: chromeExtensionURL
        .appendingPathComponent("content")
        .appendingPathComponent("x.js"),
      encoding: .utf8
    )
    let chromeXPageDetector = try String(
      contentsOf: chromeExtensionURL
        .appendingPathComponent("content")
        .appendingPathComponent("x-page.js"),
      encoding: .utf8
    )
    let firefoxXPageDetector = try String(
      contentsOf: firefoxExtensionURL
        .appendingPathComponent("content")
        .appendingPathComponent("x-page.js"),
      encoding: .utf8
    )
    let chromeXCSS = try String(
      contentsOf: chromeExtensionURL
        .appendingPathComponent("content")
        .appendingPathComponent("x.css"),
      encoding: .utf8
    )
    let firefoxXCSS = try String(
      contentsOf: firefoxExtensionURL
        .appendingPathComponent("content")
        .appendingPathComponent("x.css"),
      encoding: .utf8
    )
    let chromeReddit = try String(
      contentsOf: chromeExtensionURL
        .appendingPathComponent("content")
        .appendingPathComponent("reddit.js"),
      encoding: .utf8
    )
    let chromeRedditCSS = try String(
      contentsOf: chromeExtensionURL
        .appendingPathComponent("content")
        .appendingPathComponent("reddit.css"),
      encoding: .utf8
    )
    let firefoxRedditCSS = try String(
      contentsOf: firefoxExtensionURL
        .appendingPathComponent("content")
        .appendingPathComponent("reddit.css"),
      encoding: .utf8
    )
    let firefoxInstagram = try String(
      contentsOf: firefoxExtensionURL
        .appendingPathComponent("content")
        .appendingPathComponent("instagram.js"),
      encoding: .utf8
    )
    let firefoxReddit = try String(
      contentsOf: firefoxExtensionURL
        .appendingPathComponent("content")
        .appendingPathComponent("reddit.js"),
      encoding: .utf8
    )

    XCTAssertTrue(chromeManifest.contains("\"blocked/*\""))
    XCTAssertTrue(chromeManifest.contains("\"content/x-page.js\""))
    XCTAssertTrue(chromeManifest.contains("\"content/platform-controls.js\""))
    XCTAssertTrue(firefoxManifest.contains("\"blocked/*\""))
    XCTAssertTrue(firefoxManifest.contains("\"content/x-page.js\""))
    XCTAssertTrue(firefoxManifest.contains("\"content/platform-controls.js\""))
    XCTAssertTrue(chromeBlockPage.contains("This site is blocked"))
    XCTAssertTrue(firefoxBlockPage.contains("This site is blocked"))
    XCTAssertTrue(firefoxBackground.contains("redirectUrl: quietGateBlockPageURL(match)"))
    XCTAssertTrue(firefoxBackground.contains("{ cancel: true }"))
    XCTAssertTrue(firefoxBackground.contains("xMediaRequestShouldBlock"))
    XCTAssertTrue(firefoxBackground.contains("socialAdultPreviewRequestShouldBlock"))
    XCTAssertTrue(firefoxBackground.contains("X_INITIATOR_DOMAINS"))
    XCTAssertTrue(firefoxBackground.contains("REDDIT_INITIATOR_DOMAINS"))
    XCTAssertFalse(firefoxBackground.contains("setInterval"))
    XCTAssertFalse(firefoxManifest.contains("content/blocker.js"))
    XCTAssertTrue(firefoxManifest.contains("\"https://x.com/*\""))
    XCTAssertTrue(firefoxManifest.contains("\"https://twitter.com/*\""))
    XCTAssertTrue(firefoxManifest.contains("\"content/x.js\""))
    XCTAssertTrue(firefoxManifest.contains("\"content/platform-controls.js\""))
    XCTAssertTrue(firefoxManifest.contains("\"https://www.instagram.com/*\""))
    XCTAssertTrue(firefoxManifest.contains("\"https://www.reddit.com/*\""))
    XCTAssertFalse(firefoxYouTube.contains("setInterval"))
    XCTAssertTrue(firefoxYouTube.contains("quietgateTunerVersion"))
    XCTAssertTrue(firefoxYouTube.contains("youtubeUsageTracking"))
    XCTAssertTrue(firefoxYouTube.contains("youtubeDailyLimit"))
    XCTAssertFalse(firefoxX.contains("setInterval"))
    XCTAssertFalse(firefoxInstagram.contains("setInterval"))
    XCTAssertFalse(firefoxReddit.contains("setInterval"))
    XCTAssertEqual(chromeX, firefoxX)
    XCTAssertEqual(chromeXPageDetector, firefoxXPageDetector)
    XCTAssertEqual(chromeXCSS, firefoxXCSS)
    XCTAssertEqual(chromeReddit, firefoxReddit)
    XCTAssertEqual(chromeRedditCSS, firefoxRedditCSS)
    XCTAssertTrue(firefoxX.contains("content/x-page.js"))
    XCTAssertTrue(firefoxXPageDetector.contains("window.__quietgateXSensitiveDetectorInstalled"))
    XCTAssertTrue(firefoxXPageDetector.contains("possibly_sensitive"))
    XCTAssertTrue(firefoxXPageDetector.contains("mediaVisibilityResults"))
    XCTAssertTrue(firefoxXPageDetector.contains("media_key"))
    XCTAssertTrue(firefoxXPageDetector.contains("mediaIDs"))
    XCTAssertFalse(firefoxXPageDetector.contains("classList.add"))
    XCTAssertTrue(firefoxX.contains("quietgate.syncNativeSettings"))
    XCTAssertTrue(firefoxX.contains("storage.onChanged"))
    XCTAssertTrue(firefoxX.contains("quietgateXSensitiveMediaCount"))
    XCTAssertTrue(firefoxInstagram.contains("quietgate.syncNativeSettings"))
    XCTAssertTrue(firefoxReddit.contains("quietgate.syncNativeSettings"))
    XCTAssertTrue(firefoxReddit.contains("redditNSFW"))
  }

  func testChromeExtensionUnavailableWithoutManifest() throws {
    let root = try temporaryDirectory()
    let extensionURL = root.appendingPathComponent("ChromeExtension", isDirectory: true)
    try FileManager.default.createDirectory(at: extensionURL, withIntermediateDirectories: true)

    let bridge = BrowserExtensionBridge(chromeExtensionDirectoryURL: extensionURL)

    XCTAssertFalse(bridge.chromeExtensionAvailable())
  }

  func testChromeExtensionLoadedFromChromeProfilePreferences() throws {
    let chromeURL = try temporaryDirectory()
    let profileURL = chromeURL.appendingPathComponent("Default", isDirectory: true)
    try FileManager.default.createDirectory(at: profileURL, withIntermediateDirectories: true)
    try writeLocalState(selectedProfile: "Default", to: chromeURL)
    try writeChromePreferences(
      [
        "extensions": [
          "settings": [
            "fedpnejbgmllajjlfkahlnjbgfmjjmmf": [
              "state": 1
            ]
          ]
        ]
      ],
      to: profileURL.appendingPathComponent("Preferences")
    )

    let bridge = BrowserExtensionBridge(
      chromeUserDataDirectoryURL: chromeURL,
      runningChromeCommandsProvider: { [] }
    )
    let status = bridge.chromeExtensionStatus()

    XCTAssertTrue(bridge.chromeExtensionLoaded())
    XCTAssertTrue(status.ready)
    XCTAssertEqual(status.selectedProfile, "Default")
    XCTAssertEqual(status.profileCount, 1)
    XCTAssertEqual(status.loadedProfiles, ["Default"])
  }

  func testChromeExtensionLoadedFromChromeSecurePreferences() throws {
    let chromeURL = try temporaryDirectory()
    let profileURL = chromeURL.appendingPathComponent("Profile 10", isDirectory: true)
    try FileManager.default.createDirectory(at: profileURL, withIntermediateDirectories: true)
    try writeLocalState(
      selectedProfile: "Profile 10",
      to: chromeURL,
      profileDisplayNames: ["Profile 10": "wildstudio.ai"],
      profileEmails: ["Profile 10": "will@wildstudio.ai"]
    )
    try writeChromePreferences(
      [
        "extensions": [
          "settings": [
            "fedpnejbgmllajjlfkahlnjbgfmjjmmf": [
              "location": 4,
              "path": "/tmp/QuietGate/ChromeExtension",
            ]
          ]
        ]
      ],
      to: profileURL.appendingPathComponent("Secure Preferences")
    )

    let bridge = BrowserExtensionBridge(
      chromeUserDataDirectoryURL: chromeURL,
      runningChromeCommandsProvider: { [] }
    )
    let status = bridge.chromeExtensionStatus()

    XCTAssertTrue(bridge.chromeExtensionLoaded())
    XCTAssertTrue(status.ready)
    XCTAssertEqual(status.selectedProfile, "Profile 10")
    XCTAssertEqual(status.profileCount, 1)
    XCTAssertEqual(status.loadedProfiles, ["Profile 10"])
    XCTAssertEqual(status.readyProfileLabels, ["wildstudio.ai, will@wildstudio.ai (Profile 10)"])
  }

  func testExtensionLoadedFromEdgeProfilePreferences() throws {
    let root = try temporaryDirectory()
    let edgeURL = root.appendingPathComponent("Microsoft Edge", isDirectory: true)
    let profileURL = edgeURL.appendingPathComponent("Default", isDirectory: true)
    try FileManager.default.createDirectory(at: profileURL, withIntermediateDirectories: true)
    try writeLocalState(selectedProfile: "Default", to: edgeURL)
    try writeChromePreferences(
      [
        "extensions": [
          "settings": [
            "fedpnejbgmllajjlfkahlnjbgfmjjmmf": [
              "state": 1
            ]
          ]
        ]
      ],
      to: profileURL.appendingPathComponent("Preferences")
    )

    let bridge = BrowserExtensionBridge(
      browserUserDataDirectoryURLs: [.edge: edgeURL],
      runningChromeCommandsProvider: { [] }
    )
    let status = bridge.extensionStatus(for: .edge)

    XCTAssertTrue(bridge.extensionLoaded(for: .edge))
    XCTAssertTrue(status.ready)
    XCTAssertEqual(status.selectedProfile, "Default")
    XCTAssertEqual(status.loadedProfiles, ["Default"])
  }

  func testExtensionLoadedFromArcProfilePreferences() throws {
    let root = try temporaryDirectory()
    let arcURL = root
      .appendingPathComponent("Arc", isDirectory: true)
      .appendingPathComponent("User Data", isDirectory: true)
    let profileURL = arcURL.appendingPathComponent("Default", isDirectory: true)
    try FileManager.default.createDirectory(at: profileURL, withIntermediateDirectories: true)
    try writeLocalState(selectedProfile: "Default", to: arcURL)
    try writeChromePreferences(
      [
        "extensions": [
          "settings": [
            "fedpnejbgmllajjlfkahlnjbgfmjjmmf": [
              "state": 1
            ]
          ]
        ]
      ],
      to: profileURL.appendingPathComponent("Preferences")
    )

    let bridge = BrowserExtensionBridge(
      browserUserDataDirectoryURLs: [.arc: arcURL],
      runningChromeCommandsProvider: { [] }
    )
    let status = bridge.extensionStatus(for: .arc)

    XCTAssertTrue(bridge.extensionLoaded(for: .arc))
    XCTAssertTrue(status.ready)
    XCTAssertEqual(status.selectedProfile, "Default")
    XCTAssertEqual(status.loadedProfiles, ["Default"])
  }

  func testExtensionLoadedFromFirefoxProfileExtensionsDatabase() throws {
    let root = try temporaryDirectory()
    let firefoxProfilesURL = root
      .appendingPathComponent("Firefox", isDirectory: true)
      .appendingPathComponent("Profiles", isDirectory: true)
    let profileURL = firefoxProfilesURL.appendingPathComponent("abcd.default-release", isDirectory: true)
    try FileManager.default.createDirectory(at: profileURL, withIntermediateDirectories: true)
    try writeFirefoxExtensions(
      addons: [
        [
          "id": "quietgate@willpulier.com",
          "active": true,
          "userDisabled": false,
        ]
      ],
      to: profileURL.appendingPathComponent("extensions.json")
    )

    let bridge = BrowserExtensionBridge(
      browserUserDataDirectoryURLs: [.firefox: firefoxProfilesURL],
      runningChromeCommandsProvider: { [] }
    )
    let status = bridge.extensionStatus(for: .firefox)

    XCTAssertTrue(bridge.extensionLoaded(for: .firefox))
    XCTAssertTrue(status.ready)
    XCTAssertEqual(status.selectedProfile, "abcd.default-release")
    XCTAssertEqual(status.loadedProfiles, ["abcd.default-release"])
  }

  func testFirefoxHelperStateAcceptsFirefoxExtensionHeartbeat() throws {
    let root = try temporaryDirectory()
    let applicationSupportURL = root.appendingPathComponent("Application Support")
    let nativeHostsURL = root.appendingPathComponent("FirefoxNativeMessagingHosts")
    let hostURL = root.appendingPathComponent("quietgate-native-host")
    try "#!/usr/bin/env node\n".write(to: hostURL, atomically: true, encoding: .utf8)

    let firefoxProfilesURL = root
      .appendingPathComponent("Firefox", isDirectory: true)
      .appendingPathComponent("Profiles", isDirectory: true)
    let profileURL = firefoxProfilesURL.appendingPathComponent("abcd.default-release", isDirectory: true)
    try FileManager.default.createDirectory(at: profileURL, withIntermediateDirectories: true)
    try writeFirefoxExtensions(
      addons: [
        [
          "id": "quietgate@willpulier.com",
          "active": true,
          "userDisabled": false,
        ]
      ],
      to: profileURL.appendingPathComponent("extensions.json")
    )

    let bridge = BrowserExtensionBridge(
      applicationSupportDirectory: applicationSupportURL,
      nativeHostScriptURL: hostURL,
      nativeMessagingHostsDirectories: [.firefox: nativeHostsURL],
      browserUserDataDirectoryURLs: [.firefox: firefoxProfilesURL],
      runningChromeCommandsProvider: { [] }
    )
    try bridge.installNativeMessagingHost(for: .firefox)

    let version = "mode=focus|features=|domains=x.com"
    try writeChromeStatus(
      to: applicationSupportURL.appendingPathComponent("firefox-status.json"),
      settingsVersion: version,
      seenAt: Date(timeIntervalSince1970: 5),
      extensionID: "quietgate@willpulier.com"
    )

    XCTAssertEqual(
      bridge.helperState(for: .firefox, currentSettingsVersion: version, now: Date(timeIntervalSince1970: 10)),
      .current
    )
  }

  func testChromeExtensionLoadedRequiresSelectedProfileWhenKnown() throws {
    let chromeURL = try temporaryDirectory()
    let defaultURL = chromeURL.appendingPathComponent("Default", isDirectory: true)
    let otherProfileURL = chromeURL.appendingPathComponent("Profile 1", isDirectory: true)
    try FileManager.default.createDirectory(at: defaultURL, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: otherProfileURL, withIntermediateDirectories: true)
    try writeLocalState(selectedProfile: "Default", to: chromeURL)
    try writeChromePreferences([:], to: defaultURL.appendingPathComponent("Preferences"))
    try writeChromePreferences(
      [
        "extensions": [
          "settings": [
            "fedpnejbgmllajjlfkahlnjbgfmjjmmf": [
              "state": 1
            ]
          ]
        ]
      ],
      to: otherProfileURL.appendingPathComponent("Preferences")
    )

    let bridge = BrowserExtensionBridge(
      chromeUserDataDirectoryURL: chromeURL,
      runningChromeCommandsProvider: { [] }
    )
    let status = bridge.chromeExtensionStatus()

    XCTAssertFalse(bridge.chromeExtensionLoaded())
    XCTAssertFalse(status.ready)
    XCTAssertTrue(status.loadedElsewhere)
    XCTAssertEqual(status.selectedProfile, "Default")
    XCTAssertEqual(status.profileCount, 2)
    XCTAssertEqual(status.loadedProfiles, ["Profile 1"])
  }

  func testChromeExtensionStatusUsesFriendlyProfileNamesFromLocalState() throws {
    let chromeURL = try temporaryDirectory()
    let defaultURL = chromeURL.appendingPathComponent("Default", isDirectory: true)
    let workURL = chromeURL.appendingPathComponent("Profile 1", isDirectory: true)
    try FileManager.default.createDirectory(at: defaultURL, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: workURL, withIntermediateDirectories: true)
    try writeLocalState(
      selectedProfile: "Profile 1",
      to: chromeURL,
      profileDisplayNames: [
        "Default": "Personal",
        "Profile 1": "Work",
      ],
      profileEmails: [
        "Profile 1": "willpulier1999@gmail.com",
      ]
    )
    try writeChromePreferences([:], to: defaultURL.appendingPathComponent("Preferences"))
    try writeChromePreferences(
      [
        "extensions": [
          "settings": [
            "fedpnejbgmllajjlfkahlnjbgfmjjmmf": [
              "state": 1
            ]
          ]
        ]
      ],
      to: workURL.appendingPathComponent("Preferences")
    )

    let bridge = BrowserExtensionBridge(
      chromeUserDataDirectoryURL: chromeURL,
      runningChromeCommandsProvider: { [] }
    )
    let status = bridge.chromeExtensionStatus()

    XCTAssertTrue(status.ready)
    XCTAssertEqual(status.selectedProfile, "Profile 1")
    XCTAssertEqual(status.selectedProfileLabel, "Work, willpulier1999@gmail.com (Profile 1)")
    XCTAssertEqual(status.readyProfileLabels, ["Work, willpulier1999@gmail.com (Profile 1)"])
    XCTAssertEqual(status.profileLabel(for: "Default"), "Personal (Default)")
  }

  func testChromeExtensionStatusFallsBackToRawProfileIDWhenFriendlyNameIsMissing() throws {
    let chromeURL = try temporaryDirectory()
    let profileURL = chromeURL.appendingPathComponent("Profile 1", isDirectory: true)
    try FileManager.default.createDirectory(at: profileURL, withIntermediateDirectories: true)
    try writeLocalState(selectedProfile: "Profile 1", to: chromeURL)
    try writeChromePreferences(
      [
        "extensions": [
          "settings": [
            "fedpnejbgmllajjlfkahlnjbgfmjjmmf": [
              "state": 1
            ]
          ]
        ]
      ],
      to: profileURL.appendingPathComponent("Preferences")
    )

    let bridge = BrowserExtensionBridge(
      chromeUserDataDirectoryURL: chromeURL,
      runningChromeCommandsProvider: { [] }
    )
    let status = bridge.chromeExtensionStatus()

    XCTAssertTrue(status.ready)
    XCTAssertEqual(status.selectedProfileLabel, "Profile 1")
    XCTAssertEqual(status.readyProfileLabels, ["Profile 1"])
  }

  func testChromeExtensionLoadedIgnoresDisabledProfileEntry() throws {
    let chromeURL = try temporaryDirectory()
    let profileURL = chromeURL.appendingPathComponent("Profile 1", isDirectory: true)
    try FileManager.default.createDirectory(at: profileURL, withIntermediateDirectories: true)
    try writeChromePreferences(
      [
        "extensions": [
          "settings": [
            "fedpnejbgmllajjlfkahlnjbgfmjjmmf": [
              "state": 0
            ]
          ]
        ]
      ],
      to: profileURL.appendingPathComponent("Preferences")
    )

    let bridge = BrowserExtensionBridge(
      chromeUserDataDirectoryURL: chromeURL,
      runningChromeCommandsProvider: { [] }
    )
    let status = bridge.chromeExtensionStatus()

    XCTAssertFalse(bridge.chromeExtensionLoaded())
    XCTAssertFalse(status.ready)
    XCTAssertEqual(status.disabledProfiles, ["Profile 1"])
  }

  func testChromeExtensionLoadedFromActiveTunerSession() throws {
    let root = try temporaryDirectory()
    let chromeURL = root.appendingPathComponent("Chrome", isDirectory: true)
    let extensionURL = root.appendingPathComponent("ChromeExtension", isDirectory: true)
    let profileURL = chromeURL.appendingPathComponent("Default", isDirectory: true)
    try FileManager.default.createDirectory(at: extensionURL, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: profileURL, withIntermediateDirectories: true)
    try writeLocalState(selectedProfile: "Default", to: chromeURL)
    try writeChromePreferences([:], to: profileURL.appendingPathComponent("Preferences"))

    let bridge = BrowserExtensionBridge(
      chromeExtensionDirectoryURL: extensionURL,
      chromeUserDataDirectoryURL: chromeURL,
      runningChromeCommandsProvider: {
        [
          "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --profile-directory=Default --load-extension=\(extensionURL.path)"
        ]
      }
    )
    let status = bridge.chromeExtensionStatus()

    XCTAssertTrue(bridge.chromeExtensionLoaded())
    XCTAssertTrue(status.ready)
    XCTAssertTrue(status.sessionReady)
    XCTAssertFalse(status.persistentReady)
    XCTAssertEqual(status.sessionProfiles, ["Default"])
    XCTAssertEqual(status.readyProfiles, ["Default"])
  }

  func testActiveSessionProfileOverridesStaleLocalStateProfile() throws {
    let root = try temporaryDirectory()
    let chromeURL = root.appendingPathComponent("Chrome", isDirectory: true)
    let extensionURL = root.appendingPathComponent("ChromeExtension", isDirectory: true)
    let defaultURL = chromeURL.appendingPathComponent("Default", isDirectory: true)
    let otherProfileURL = chromeURL.appendingPathComponent("Profile 1", isDirectory: true)
    try FileManager.default.createDirectory(at: extensionURL, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: defaultURL, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: otherProfileURL, withIntermediateDirectories: true)
    try writeLocalState(selectedProfile: "Default", to: chromeURL)
    try writeChromePreferences([:], to: defaultURL.appendingPathComponent("Preferences"))
    try writeChromePreferences([:], to: otherProfileURL.appendingPathComponent("Preferences"))

    let bridge = BrowserExtensionBridge(
      chromeExtensionDirectoryURL: extensionURL,
      chromeUserDataDirectoryURL: chromeURL,
      runningChromeCommandsProvider: {
        [
          "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --profile-directory=Profile 1 --load-extension=\(extensionURL.path)"
        ]
      }
    )
    let status = bridge.chromeExtensionStatus()

    XCTAssertTrue(bridge.chromeExtensionLoaded())
    XCTAssertTrue(status.ready)
    XCTAssertFalse(status.loadedElsewhere)
    XCTAssertEqual(status.selectedProfile, "Profile 1")
    XCTAssertEqual(status.sessionProfiles, ["Profile 1"])
    XCTAssertEqual(status.readyProfiles, ["Profile 1"])
  }

  func testStatusWatchURLsIncludeChromeStatusAndProfileSources() throws {
    let root = try temporaryDirectory()
    let applicationSupportURL = root.appendingPathComponent("Application Support")
    let nativeHostsURL = root.appendingPathComponent("NativeMessagingHosts")
    let chromeURL = root.appendingPathComponent("Chrome", isDirectory: true)
    let profileURL = chromeURL.appendingPathComponent("Profile 1", isDirectory: true)
    try FileManager.default.createDirectory(at: profileURL, withIntermediateDirectories: true)
    try writeLocalState(selectedProfile: "Profile 1", to: chromeURL)
    try writeChromePreferences([:], to: profileURL.appendingPathComponent("Preferences"))
    try writeChromePreferences([:], to: profileURL.appendingPathComponent("Secure Preferences"))

    let bridge = BrowserExtensionBridge(
      applicationSupportDirectory: applicationSupportURL,
      nativeMessagingHostsDirectory: nativeHostsURL,
      chromeUserDataDirectoryURL: chromeURL,
      runningChromeCommandsProvider: { [] }
    )

    let paths = Set(bridge.statusWatchURLs(for: .chrome).map { $0.standardizedFileURL.path })

    XCTAssertTrue(paths.contains(bridge.chromeStatusURL.standardizedFileURL.path))
    XCTAssertTrue(paths.contains(applicationSupportURL.standardizedFileURL.path))
    XCTAssertFalse(paths.contains(chromeURL.standardizedFileURL.path))
    XCTAssertTrue(paths.contains(chromeURL.appendingPathComponent("Local State").standardizedFileURL.path))
    XCTAssertTrue(paths.contains(profileURL.appendingPathComponent("Preferences").standardizedFileURL.path))
    XCTAssertTrue(paths.contains(profileURL.appendingPathComponent("Secure Preferences").standardizedFileURL.path))
    XCTAssertTrue(paths.contains(nativeHostsURL.appendingPathComponent("com.willpulier.quietgate.json").standardizedFileURL.path))
  }

  func testStatusWatchURLsDoNotWatchBroadFirefoxProfileDirectories() throws {
    let root = try temporaryDirectory()
    let applicationSupportURL = root.appendingPathComponent("Application Support")
    let nativeHostsURL = root.appendingPathComponent("FirefoxNativeMessagingHosts")
    let firefoxURL = root.appendingPathComponent("Firefox", isDirectory: true)
    let firefoxProfilesURL = firefoxURL.appendingPathComponent("Profiles", isDirectory: true)
    let profileURL = firefoxProfilesURL.appendingPathComponent("abcd.default-release", isDirectory: true)
    let profilesIniURL = firefoxURL.appendingPathComponent("profiles.ini")
    try FileManager.default.createDirectory(at: profileURL, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: nativeHostsURL, withIntermediateDirectories: true)
    try """
      [Profile0]
      Name=default-release
      Path=Profiles/abcd.default-release
      IsRelative=1
      """.write(to: profilesIniURL, atomically: true, encoding: .utf8)
    try writeFirefoxExtensions(
      addons: [
        [
          "id": "quietgate@willpulier.com",
          "active": true,
          "userDisabled": false,
        ]
      ],
      to: profileURL.appendingPathComponent("extensions.json")
    )

    let bridge = BrowserExtensionBridge(
      applicationSupportDirectory: applicationSupportURL,
      nativeMessagingHostsDirectories: [.firefox: nativeHostsURL],
      browserUserDataDirectoryURLs: [.firefox: firefoxProfilesURL],
      runningChromeCommandsProvider: { [] }
    )

    let paths = Set(bridge.statusWatchURLs(for: .firefox).map { $0.standardizedFileURL.path })

    XCTAssertTrue(paths.contains(applicationSupportURL.appendingPathComponent("firefox-status.json").standardizedFileURL.path))
    XCTAssertTrue(paths.contains(applicationSupportURL.standardizedFileURL.path))
    XCTAssertTrue(paths.contains(profilesIniURL.standardizedFileURL.path))
    XCTAssertTrue(paths.contains(profileURL.appendingPathComponent("extensions.json").standardizedFileURL.path))
    XCTAssertTrue(paths.contains(nativeHostsURL.appendingPathComponent("com.willpulier.quietgate.json").standardizedFileURL.path))
    XCTAssertFalse(paths.contains(firefoxURL.standardizedFileURL.path))
    XCTAssertFalse(paths.contains(firefoxProfilesURL.standardizedFileURL.path))
  }

  private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("QuietGateTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: url)
    }
    return url
  }

  private func writeChromePreferences(_ value: [String: Any], to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url)
  }

  private func writeLocalState(
    selectedProfile: String,
    to url: URL,
    profileDisplayNames: [String: String] = [:],
    profileEmails: [String: String] = [:]
  ) throws {
    var profile: [String: Any] = [
      "last_used": selectedProfile
    ]
    if !profileDisplayNames.isEmpty || !profileEmails.isEmpty {
      let profileIDs = Set(profileDisplayNames.keys).union(profileEmails.keys)
      profile["info_cache"] = Dictionary(
        uniqueKeysWithValues: profileIDs.map { profileID in
          var entry: [String: String] = [:]
          if let displayName = profileDisplayNames[profileID] {
            entry["name"] = displayName
          }
          if let email = profileEmails[profileID] {
            entry["user_name"] = email
          }
          return (profileID, entry)
        }
      )
    }
    let data = try JSONSerialization.data(
      withJSONObject: [
        "profile": profile
      ],
      options: [.prettyPrinted, .sortedKeys]
    )
    try data.write(to: url.appendingPathComponent("Local State"))
  }

  private func writeChromeStatus(
    to url: URL,
    settingsVersion: String,
    seenAt: Date,
    extensionID: String = "fedpnejbgmllajjlfkahlnjbgfmjjmmf",
    extensionVersion: String = "0.1.12",
    scriptVersions: [String: String]? = [
      "youtube": "2026.06.12.01",
      "x": "2026.06.11.01",
      "reddit": "2026.06.11.01",
    ],
    profileID: String? = nil,
    profileName: String? = nil
  ) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(
      ChromeHelperSnapshot(
        extensionID: extensionID,
        lastSeenAt: seenAt,
        lastAppliedSettingsVersion: settingsVersion,
        extensionVersion: extensionVersion,
        scriptVersions: scriptVersions,
        blockedRuleCount: 1,
        profileID: profileID,
        profileName: profileName
      )
    )
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try data.write(to: url)
  }

  private func writeFirefoxExtensions(addons: [[String: Any]], to url: URL) throws {
    let data = try JSONSerialization.data(
      withJSONObject: ["addons": addons],
      options: [.prettyPrinted, .sortedKeys]
    )
    try data.write(to: url)
  }

}
