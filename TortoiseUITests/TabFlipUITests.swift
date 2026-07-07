import XCTest

/// Regression guard for the TestFlight 1.1 report: "app keeps auto closing
/// when I flip tabs". Drives every bottom tab repeatedly and asserts the app
/// stays in the foreground.
final class TabFlipUITests: XCTestCase {
  func testFlippingTabsDoesNotCrash() {
    let app = XCUIApplication()
    app.launch()

    let tabTitles = ["Usage", "Tune", "Block", "Devices"]
    for round in 0..<3 {
      for title in tabTitles {
        let tab = app.staticTexts[title].firstMatch
        guard tab.waitForExistence(timeout: 8) else {
          // Signed-out landing has no tab bar; nothing to flip.
          XCTAssertEqual(app.state, .runningForeground, "app died before tabs appeared (round \(round))")
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
