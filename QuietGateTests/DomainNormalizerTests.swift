import XCTest
@testable import QuietGate

final class DomainNormalizerTests: XCTestCase {
  func testNormalizesURLToDomain() throws {
    XCTAssertEqual(try DomainNormalizer.normalize("HTTPS://WWW.Example.COM/path?q=1"), "www.example.com")
  }

  func testNormalizesWildcardDomain() throws {
    XCTAssertEqual(try DomainNormalizer.normalize("*.Example.com."), "example.com")
  }

  func testRejectsInvalidDomain() {
    XCTAssertThrowsError(try DomainNormalizer.normalize("not a domain"))
    XCTAssertThrowsError(try DomainNormalizer.normalize("127.0.0.1"))
    XCTAssertThrowsError(try DomainNormalizer.normalize("-bad.example"))
  }
}
