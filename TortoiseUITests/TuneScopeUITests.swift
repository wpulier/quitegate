import XCTest

/// Guards the two-lane Tune tab: the APPS lane (native block/limit/schedule,
/// with the honest "no tuning inside apps" framing) and the WEBSITES lane whose
/// scope card must always name Safari-on-this-iPhone as a surface — the exact
/// dishonesty the old "browser profiles only" card shipped with.
final class TuneScopeUITests: XCTestCase {
  private func launchTuning() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--tortoise-screenshot", "--tortoise-screenshot-section", "tuning"]
    app.launch()
    return app
  }

  private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: identifier).firstMatch
  }

  func testTuneShowsTwoLanes() {
    let app = launchTuning()

    XCTAssertTrue(element(app, "tune-apps-lane").waitForExistence(timeout: 8), "APPS lane card never appeared")
    XCTAssertTrue(element(app, "tune-scope-card").waitForExistence(timeout: 4), "WEBSITES scope card never appeared")
    XCTAssertTrue(
      element(app, "tune-scope-iphone-safari").waitForExistence(timeout: 4),
      "the Safari-on-this-iPhone chip must always be present"
    )
    XCTAssertEqual(app.state, .runningForeground, "app left the foreground rendering the Tune tab")
  }

  func testAppsLaneNavigatesToBlock() {
    let app = launchTuning()

    let appsLane = element(app, "tune-apps-lane")
    XCTAssertTrue(appsLane.waitForExistence(timeout: 8), "APPS lane card never appeared")
    appsLane.tap()

    XCTAssertTrue(app.staticTexts["Block"].firstMatch.waitForExistence(timeout: 8), "tapping the APPS lane card did not reach Block")
    XCTAssertEqual(app.state, .runningForeground)
  }

  func testBannerOpensSafariConnectSheet() {
    // Fixture has no active enforcement surface, so the setup-first banner is
    // deterministic; its CTA must open the one canonical connect sheet.
    let app = launchTuning()

    let banner = element(app, "tune-setup-first-banner")
    XCTAssertTrue(banner.waitForExistence(timeout: 8), "setup-first banner never appeared")
    app.buttons["Connect Safari"].firstMatch.tap()

    XCTAssertTrue(
      element(app, "safari-connect-sheet").waitForExistence(timeout: 6),
      "banner CTA did not open the Safari connect sheet"
    )
    XCTAssertEqual(app.state, .runningForeground)
  }

  func testXSiteShowsPlatformSafetyRow() {
    let app = launchTuning()

    let xTile = app.staticTexts["X"].firstMatch
    XCTAssertTrue(xTile.waitForExistence(timeout: 8), "X site tile never appeared")
    if !xTile.isHittable {
      app.swipeUp()
    }
    xTile.tap()

    XCTAssertTrue(
      element(app, "tune-x-platform-safety").waitForExistence(timeout: 6),
      "the X account-setting honesty row must lead the X tuning card"
    )
    XCTAssertEqual(app.state, .runningForeground)
  }

  func testAddComputerNavigatesToDevices() {
    // Fixture mode has no cloud devices, so the add-computer affordance is deterministic.
    let app = launchTuning()

    let addComputer = element(app, "tune-scope-add-computer")
    XCTAssertTrue(addComputer.waitForExistence(timeout: 8), "add-computer affordance never appeared")
    addComputer.tap()

    XCTAssertTrue(app.staticTexts["Devices"].firstMatch.waitForExistence(timeout: 8), "tapping add-computer did not reach Devices")
    XCTAssertEqual(app.state, .runningForeground)
  }
}
