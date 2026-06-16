import XCTest

@testable import QuietGate

final class LocalMacBlockingProviderTests: XCTestCase {
  func testProviderSnapshotRepresentsOwnedMacBlocker() {
    let provider = LocalMacBlockingProvider(
      blockedApplications: [
        BlockedApplicationRule(
          bundleIdentifier: "com.example.Chat",
          displayName: "Chat"
        ),
        BlockedApplicationRule(
          bundleIdentifier: "com.example.Video",
          displayName: "Video",
          isEnabled: false
        ),
      ],
      runningApplications: [
        RunningApplicationSnapshot(
          bundleIdentifier: "com.example.Chat",
          displayName: "Chat"
        )
      ],
      enforcementEnabled: true,
      startupState: .enabled
    )

    XCTAssertEqual(provider.activeBlockedApplications.map(\.bundleIdentifier), ["com.example.Chat"])
    XCTAssertEqual(provider.runningBlockedApplications.map(\.bundleIdentifier), ["com.example.Chat"])
    XCTAssertEqual(provider.statusSummary, "Closing 1 blocked app now.")
    XCTAssertEqual(provider.providerSnapshot.id, .localMac)
    XCTAssertEqual(provider.providerSnapshot.title, "QuietGate Mac Blocker")
    XCTAssertEqual(provider.providerSnapshot.activeRuleCount, 1)
    XCTAssertEqual(provider.providerSnapshot.destinationNames, ["This Mac"])
    XCTAssertTrue(provider.providerSnapshot.isReady)
    XCTAssertFalse(provider.providerSnapshot.isLegacy)
  }

  func testProviderSnapshotShowsPausedMacBlocker() {
    let provider = LocalMacBlockingProvider(
      blockedApplications: [
        BlockedApplicationRule(
          bundleIdentifier: "com.example.Chat",
          displayName: "Chat"
        )
      ],
      runningApplications: [],
      enforcementEnabled: false,
      startupState: .off
    )

    XCTAssertEqual(provider.statusSummary, "1 app saved. App closing is paused.")
    XCTAssertFalse(provider.providerSnapshot.isReady)
    XCTAssertTrue(provider.providerSnapshot.state.detail.contains("paused"))
    XCTAssertEqual(provider.providerSnapshot.activeRuleCount, 1)
  }
}
