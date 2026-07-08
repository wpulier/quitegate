import XCTest

/// Guards the iOS v1 redesign structure (docs/design/ios-v1-handoff/):
/// Usage leads with a hero + folded detail and carries the finish-setup
/// banner while setup is incomplete; Devices is one account card whose
/// Connections row expands. Fixture mode has no synced data and no connected
/// enforcement surface, so every asserted state is deterministic.
final class RedesignUITests: XCTestCase {
  private func launch(section: String) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--tortoise-screenshot", "--tortoise-screenshot-section", section]
    app.launch()
    return app
  }

  private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: identifier).firstMatch
  }

  func testUsageLandsFirstWithHeroAndSetupBanner() {
    // No section arg: the app must land on Usage (the redesign's tab order).
    let app = XCUIApplication()
    app.launchArguments = ["--tortoise-screenshot"]
    app.launch()

    XCTAssertTrue(element(app, "usage-hero").waitForExistence(timeout: 8), "Usage hero never appeared on launch")
    XCTAssertTrue(
      element(app, "usage-finish-setup-banner").waitForExistence(timeout: 4),
      "finish-setup banner must show while setup is incomplete"
    )
    XCTAssertEqual(app.state, .runningForeground)
  }

  func testUsageSetupBannerRoutesToDevices() {
    let app = launch(section: "usage")

    let banner = element(app, "usage-finish-setup-banner")
    XCTAssertTrue(banner.waitForExistence(timeout: 8), "setup banner never appeared")
    banner.tap()

    XCTAssertTrue(
      element(app, "devices-connections-row").waitForExistence(timeout: 6),
      "tapping the setup banner did not land on Devices"
    )
    XCTAssertEqual(app.state, .runningForeground)
  }

  func testUsageFoldsToggle() {
    let app = launch(section: "usage")

    let byApp = element(app, "usage-by-app")
    XCTAssertTrue(byApp.waitForExistence(timeout: 8), "by-app card never appeared")
    // Default open (zero state shows the honest empty explainer); tap folds it.
    byApp.tap()
    let byAccount = element(app, "usage-by-account")
    XCTAssertTrue(byAccount.waitForExistence(timeout: 4), "by-account card never appeared")
    byAccount.tap()

    XCTAssertTrue(element(app, "usage-hero").exists, "hero vanished while folding cards")
    XCTAssertEqual(app.state, .runningForeground, "app left the foreground while folding usage cards")
  }

  func testDevicesConnectionsRowExpands() {
    let app = launch(section: "devices")

    let row = element(app, "devices-connections-row")
    XCTAssertTrue(row.waitForExistence(timeout: 8), "connections row never appeared")
    row.tap()

    XCTAssertTrue(
      app.buttons["Connect another device"].firstMatch.waitForExistence(timeout: 6),
      "expanding connections did not reveal the connect affordance"
    )
    XCTAssertEqual(app.state, .runningForeground)
  }
}
