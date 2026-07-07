import XCTest

/// Regression guard for the TestFlight 1.1 report: "app keeps auto closing
/// when I flip tabs". Drives every bottom tab repeatedly and asserts the app
/// stays in the foreground.
final class TabFlipUITests: XCTestCase {
  /// Signs in with a Clerk dev-instance test account (fixed OTP) so the tab
  /// flip exercises the real signed-in shell. Requires the app under test to
  /// be built with a pk_test publishable key; skips itself otherwise.
  func testSignedInTabFlipDoesNotCrash() throws {
    let app = XCUIApplication()
    app.launch()

    if !app.staticTexts["Usage"].firstMatch.waitForExistence(timeout: 6) {
      let signIn = app.buttons["Sign in"].firstMatch
      guard signIn.waitForExistence(timeout: 10) else {
        throw XCTSkip("No landing sign-in button; cannot drive auth.")
      }
      signIn.tap()

      let email = app.textFields.firstMatch
      guard email.waitForExistence(timeout: 12) else {
        throw XCTSkip("Auth sheet did not present an email field.")
      }
      email.tap()
      email.typeText("willpulier+clerk_test@example.com")
      app.buttons["Continue"].firstMatch.tap()

      // Dev-instance test accounts always verify with 424242.
      let codeField = app.textFields.firstMatch
      guard codeField.waitForExistence(timeout: 12) else {
        throw XCTSkip("No verification code field; app is likely on the production Clerk instance.")
      }
      if codeField.isHittable {
        codeField.tap()
      }
      app.typeText("424242")

      guard app.staticTexts["Usage"].firstMatch.waitForExistence(timeout: 20) else {
        throw XCTSkip("Sign-in did not reach the shell; cannot exercise signed-in tabs.")
      }
    }

    flipTabs(app, requireTabs: true)
  }

  func testFlippingTabsDoesNotCrash() {
    let app = XCUIApplication()
    app.launch()
    flipTabs(app, requireTabs: false)
  }

  private func flipTabs(_ app: XCUIApplication, requireTabs: Bool) {
    let tabTitles = ["Usage", "Tune", "Block", "Devices"]
    for round in 0..<3 {
      for title in tabTitles {
        let tab = app.staticTexts[title].firstMatch
        guard tab.waitForExistence(timeout: 8) else {
          if requireTabs {
            XCTFail("tab \(title) never appeared (round \(round)); app state: \(app.state.rawValue)")
          } else {
            // Signed-out landing has no tab bar; nothing to flip.
            XCTAssertEqual(app.state, .runningForeground, "app died before tabs appeared (round \(round))")
          }
          return
        }
        tab.tap()
        // Give the destination screen a beat to render its content.
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        XCTAssertEqual(
          app.state,
          .runningForeground,
          "app left the foreground after tapping \(title) (round \(round))"
        )
      }
    }
  }
}
