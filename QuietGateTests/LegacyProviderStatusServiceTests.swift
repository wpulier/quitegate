import XCTest
@testable import QuietGate

final class LegacyProviderStatusServiceTests: XCTestCase {
  func testParseStatusDecodesRawJSON() throws {
    let status = try LegacyProviderStatusService.parseStatus(from: Data("""
    {
      "status": "ok",
      "profile": "abc123",
      "client": "apple-profile",
      "clientName": "Mac",
      "protocol": "DOH"
    }
    """.utf8))

    XCTAssertEqual(status.status, "ok")
    XCTAssertEqual(status.profile, "abc123")
    XCTAssertEqual(status.protocolName, "DOH")
  }

  func testParseStatusDecodesEmbeddedJSON() throws {
    let status = try LegacyProviderStatusService.parseStatus(from: Data("""
    <html><body>{"status":"unconfigured","resolver":"1.1.1.1"}</body></html>
    """.utf8))

    XCTAssertEqual(status.status, "unconfigured")
    XCTAssertNil(status.profile)
  }

  func testParseStatusReportsUnexpectedBodyInsteadOfRawDecoderMessage() {
    XCTAssertThrowsError(try LegacyProviderStatusService.parseStatus(from: Data("not-json".utf8))) { error in
      XCTAssertEqual(error as? ResolverStatusError, .unexpectedResponsePreview("not-json"))
      XCTAssertTrue(error.localizedDescription.contains("QuietGate received an unexpected connection response"))
    }
  }
}
