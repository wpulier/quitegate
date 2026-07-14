import XCTest
@testable import QuietGate

@MainActor
final class MacAccountStoreTests: XCTestCase {
  func testFailedSyncUsesClearRetryableStatus() {
    let store = MacAccountStore()

    store.syncState = .failed("Unauthorized.")

    XCTAssertTrue(store.connectionFailed)
    XCTAssertEqual(store.accountFooterText, "Connection failed")
  }

  func testCurrentSyncIsNotReportedAsFailed() {
    let store = MacAccountStore()

    store.syncState = .current

    XCTAssertFalse(store.connectionFailed)
  }
}
