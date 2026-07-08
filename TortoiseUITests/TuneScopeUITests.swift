import XCTest

/// Guards the redesigned Tune tab (segmented surfaces + per-site accordions)
/// and the redesigned Block tab (radio mode cards + folded session). Fixture
/// mode has no synced policy and no connected surface, so the zero states
/// asserted here are deterministic.
final class TuneScopeUITests: XCTestCase {
  private func launch(section: String = "tuning") -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--tortoise-screenshot", "--tortoise-screenshot-section", section]
    app.launch()
    return app
  }

  private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: identifier).firstMatch
  }

  func testTuneShowsSurfacesAndAccordions() {
    let app = launch()

    XCTAssertTrue(app.staticTexts["In the browser"].firstMatch.waitForExistence(timeout: 8), "browser segment never appeared")
    XCTAssertTrue(app.staticTexts["Apps on iPhone"].firstMatch.exists, "apps segment never appeared")
    XCTAssertTrue(element(app, "tune-site-youtube").waitForExistence(timeout: 4), "YouTube accordion never appeared")
    XCTAssertTrue(element(app, "tune-site-x").exists, "X accordion never appeared")
    XCTAssertEqual(app.state, .runningForeground)
  }

  func testAppsSurfaceShowsLimits() {
    let app = launch()

    app.staticTexts["Apps on iPhone"].firstMatch.tap()

    XCTAssertTrue(
      app.staticTexts["YouTube daily limit"].firstMatch.waitForExistence(timeout: 6),
      "Apps surface did not show the YouTube limit"
    )
    XCTAssertTrue(
      app.staticTexts["All chosen apps together"].firstMatch.exists,
      "Apps surface did not show the combined limit"
    )
    XCTAssertEqual(app.state, .runningForeground)
  }

  func testBannerOpensSafariConnectSheet() {
    // Fixture has no active enforcement surface, so the setup-first banner is
    // deterministic; its CTA must open the one canonical connect sheet.
    let app = launch()

    let banner = element(app, "tune-setup-first-banner")
    XCTAssertTrue(banner.waitForExistence(timeout: 8), "setup-first banner never appeared")
    app.buttons["Connect Safari"].firstMatch.tap()

    XCTAssertTrue(
      element(app, "safari-connect-sheet").waitForExistence(timeout: 6),
      "banner CTA did not open the Safari connect sheet"
    )
    XCTAssertEqual(app.state, .runningForeground)
  }

  func testXAccordionShowsPlatformSafetyRow() {
    let app = launch()

    let xAccordion = element(app, "tune-site-x")
    XCTAssertTrue(xAccordion.waitForExistence(timeout: 8), "X accordion never appeared")
    if !xAccordion.isHittable {
      app.swipeUp()
    }
    xAccordion.tap()

    XCTAssertTrue(
      element(app, "tune-x-platform-safety").waitForExistence(timeout: 6),
      "the X account-setting honesty row must lead the open X accordion"
    )
    XCTAssertEqual(app.state, .runningForeground)
  }

  func testAllSettingsFoldExpands() {
    let app = launch()

    // YouTube opens by default (selectedSite initial value); its curated rows
    // end in the All settings fold.
    let fold = element(app, "tune-all-settings-youtube")
    XCTAssertTrue(fold.waitForExistence(timeout: 8), "All settings fold never appeared")
    if !fold.isHittable {
      app.swipeUp()
    }
    fold.tap()

    // A deep-catalog toggle only reachable through the fold (exact
    // BrowserTuningFeature titles):
    XCTAssertTrue(
      app.staticTexts["Disable Autoplay"].firstMatch.waitForExistence(timeout: 6)
        || app.staticTexts["Hide End Screen Feed"].firstMatch.waitForExistence(timeout: 2),
      "expanding All settings did not reveal the full catalog"
    )
    XCTAssertEqual(app.state, .runningForeground)
  }

  func testBlockShowsFourModeCardsAndSessionFold() {
    let app = launch(section: "blocking")

    XCTAssertTrue(element(app, "block-mode-open").waitForExistence(timeout: 8), "Open card never appeared")
    XCTAssertTrue(element(app, "block-mode-focus").exists, "Focus card never appeared")
    XCTAssertTrue(element(app, "block-mode-strict").exists, "Strict card never appeared")
    XCTAssertTrue(element(app, "block-mode-custom").exists, "Custom card never appeared")

    let fold = element(app, "block-session-fold")
    XCTAssertTrue(fold.waitForExistence(timeout: 4), "session fold never appeared")
    if !fold.isHittable {
      app.swipeUp()
    }
    fold.tap()
    XCTAssertTrue(
      app.buttons["Focus · 25m"].firstMatch.waitForExistence(timeout: 4),
      "expanding the session fold did not reveal the session buttons"
    )
    XCTAssertEqual(app.state, .runningForeground)
  }
}
