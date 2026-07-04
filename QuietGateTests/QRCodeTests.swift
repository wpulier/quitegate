import XCTest
@testable import QuietGate

final class QRCodeTests: XCTestCase {
  func testGeneratesImageForValidURL() {
    XCTAssertNotNil(QRCode.cgImage(for: "https://www.yourtortoise.com/download/ios"))
  }

  func testImageHasPositiveDimensions() {
    let image = QRCode.cgImage(for: "https://www.yourtortoise.com/download/mac")
    XCTAssertNotNil(image)
    XCTAssertGreaterThan(image?.width ?? 0, 0)
    XCTAssertGreaterThan(image?.height ?? 0, 0)
  }

  func testNilForEmptyString() {
    XCTAssertNil(QRCode.cgImage(for: ""))
  }
}
