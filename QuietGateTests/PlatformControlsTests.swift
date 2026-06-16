import Foundation
import XCTest
@testable import QuietGate

final class PlatformControlsTests: XCTestCase {
  func testLocalSafeSearchAndChromePoliciesCanBeEnabled() async {
    let resolver = FakeDomainResolver()
    let policies = FakeChromePolicyReader(values: [
      "ForceGoogleSafeSearch": true,
      "ForceYouTubeRestrict": 2
    ])
    let checker = PlatformControlsChecker(
      hostsTextProvider: { "216.239.38.120 www.google.com # forcesafesearch.google.com" },
      domainResolver: resolver,
      chromePolicyReader: policies
    )

    let snapshot = await checker.snapshot(
      browserSnapshot: nil,
      quietGateTunersReady: true,
      now: Date(timeIntervalSince1970: 10)
    )

    XCTAssertEqual(snapshot.item(.googleSafeSearch)?.state, .enabled)
    XCTAssertEqual(snapshot.item(.chromeGoogleSafeSearchPolicy)?.state, .enabled)
    XCTAssertEqual(snapshot.item(.chromeYouTubeRestrictedMode)?.state, .enabled)
    XCTAssertEqual(snapshot.item(.quietGateTuners)?.state, .enabled)
  }

  func testBrowserAccountAuditsSurfaceNeededActions() async {
    let checker = PlatformControlsChecker(
      hostsTextProvider: { "" },
      domainResolver: FakeDomainResolver(),
      chromePolicyReader: FakeChromePolicyReader()
    )
    let browserSnapshot = ChromeHelperSnapshot(
      extensionID: BrowserExtensionBridge.chromiumExtensionID,
      lastSeenAt: Date(timeIntervalSince1970: 20),
      lastAppliedSettingsVersion: "settings",
      extensionVersion: "0.1.0",
      platformControls: BrowserAccountPlatformControlsSnapshot(
        x: XAccountPlatformControlsSnapshot(
          checkedAt: Date(timeIntervalSince1970: 21),
          url: "https://x.com/settings/content_you_see",
          displaySensitiveMedia: true,
          hideSensitiveSearch: false
        ),
        reddit: RedditAccountPlatformControlsSnapshot(
          checkedAt: Date(timeIntervalSince1970: 22),
          url: "https://www.reddit.com/settings/preferences",
          showMatureContent: false,
          blurMatureMedia: true
        )
      ),
      blockedRuleCount: 0
    )

    let snapshot = await checker.snapshot(
      browserSnapshot: browserSnapshot,
      quietGateTunersReady: false,
      now: Date(timeIntervalSince1970: 23)
    )

    XCTAssertEqual(snapshot.item(.xSensitiveMedia)?.state, .needsAction)
    XCTAssertEqual(snapshot.item(.xSensitiveSearch)?.state, .needsAction)
    XCTAssertEqual(snapshot.item(.redditMatureContent)?.state, .enabled)
    XCTAssertEqual(snapshot.item(.redditBlurMatureMedia)?.state, .enabled)
    XCTAssertEqual(snapshot.item(.quietGateTuners)?.state, .needsAction)
  }

  func testBrowserSnapshotDecodesPlatformControls() throws {
    let data = Data(
      """
      {
        "schemaVersion": 1,
        "extensionID": "\(BrowserExtensionBridge.chromiumExtensionID)",
        "lastSeenAt": "2026-06-02T20:00:00Z",
        "lastAppliedSettingsVersion": "settings",
        "extensionVersion": "0.1.6",
        "scriptVersions": { "x": "2026.06.11.01", "reddit": "2026.06.11.01" },
        "adultProtection": {
          "enabled": true,
          "mode": "focus",
          "domainListCount": 240391,
          "seedDomainCount": 11,
          "staticRulesetsEnabled": ["adult-static-1"],
          "dynamicRuleCount": 15001,
          "scriptVersions": { "x": "2026.06.11.01", "reddit": "2026.06.11.01" },
          "canaryDomains": ["redgifs.com", "www.redgifs.com"],
          "checkedAt": "2026-06-02T20:00:03Z"
        },
        "platformControls": {
          "x": {
            "checkedAt": "2026-06-02T20:00:01Z",
            "url": "https://x.com/settings/search",
            "displaySensitiveMedia": false,
            "hideSensitiveSearch": true
          },
          "reddit": {
            "checkedAt": "2026-06-02T20:00:02Z",
            "url": "https://www.reddit.com/settings/preferences",
            "showMatureContent": false,
            "blurMatureMedia": true
          }
        },
        "blockedRuleCount": 3,
        "lastError": null
      }
      """.utf8
    )
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let snapshot = try decoder.decode(ChromeHelperSnapshot.self, from: data)

    XCTAssertEqual(snapshot.platformControls?.x?.displaySensitiveMedia, false)
    XCTAssertEqual(snapshot.adultProtection?.enabled, true)
    XCTAssertEqual(snapshot.adultProtection?.domainListCount, 240391)
    XCTAssertEqual(snapshot.adultProtection?.staticRulesetsEnabled, ["adult-static-1"])
    XCTAssertEqual(snapshot.adultProtection?.scriptVersions?["reddit"], "2026.06.11.01")
    XCTAssertEqual(snapshot.platformControls?.x?.hideSensitiveSearch, true)
    XCTAssertEqual(snapshot.platformControls?.reddit?.showMatureContent, false)
    XCTAssertEqual(snapshot.platformControls?.reddit?.blurMatureMedia, true)
  }
}

private struct FakeChromePolicyReader: ChromePolicyReading {
  var values: [String: Any] = [:]

  func value(for key: String) -> Any? {
    values[key]
  }
}
