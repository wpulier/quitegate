import XCTest
@testable import QuietGate

final class AddDestinationTests: XCTestCase {
  private let base = URL(string: "https://www.yourtortoise.com")!

  func testThreeDestinations() {
    XCTAssertEqual(AddDestination.allCases, [.phone, .computer, .browser])
  }

  func testURLsPointAtRealPages() {
    XCTAssertEqual(AddDestination.phone.url(base: base).absoluteString, "https://www.yourtortoise.com/download/ios")
    XCTAssertEqual(AddDestination.computer.url(base: base).absoluteString, "https://www.yourtortoise.com/download/mac")
    XCTAssertEqual(AddDestination.browser.url(base: base).absoluteString, "https://www.yourtortoise.com/download/chrome")
  }

  func testEveryDestinationHasNonEmptyCopy() {
    for d in AddDestination.allCases {
      XCTAssertFalse(d.title.isEmpty)
      XCTAssertFalse(d.caption.isEmpty)
      XCTAssertFalse(d.systemImage.isEmpty)
    }
  }

  func testBrowserDestinationNamesTheThingBeingConnected() {
    XCTAssertEqual(AddDestination.browser.title, "Chrome extension")
    XCTAssertEqual(AddDestination.browser.systemImage, "puzzlepiece.extension")
  }
}
