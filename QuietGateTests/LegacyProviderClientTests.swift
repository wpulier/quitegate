import Foundation
import XCTest
@testable import QuietGate

final class LegacyProviderClientTests: XCTestCase {
  override func tearDown() {
    MockURLProtocol.requestHandler = nil
    super.tearDown()
  }

  func testGetParentalControlDecodesEnvelope() async throws {
    let session = makeSession { request in
      XCTAssertEqual(request.value(forHTTPHeaderField: "X-Api-Key"), "secret")
      XCTAssertEqual(request.url?.path, "/profiles/abc123/parentalControl")
      return self.response(
        for: request,
        body: """
        {
          "data": {
            "categories": [{"id": "porn", "active": true}],
            "safeSearch": true,
            "youtubeRestrictedMode": true,
            "blockBypass": true
          }
        }
        """
      )
    }

    let client = LegacyProviderClient(apiKey: "secret", baseURL: URL(string: "https://api.example.test")!, loader: session)
    let value = try await client.getParentalControl(profileID: "abc123")

    XCTAssertTrue(value.isQuietGateEnabled)
    XCTAssertEqual(value.categories, [LegacyProviderRuleItem(id: "porn", active: true)])
  }

  func testErrorEnvelopeThrowsForUserError() async {
    let session = makeSession { request in
      self.response(
        for: request,
        body: """
        {
          "errors": [
            {"code": "invalid", "detail": "Invalid domain."}
          ]
        }
        """
      )
    }

    let client = LegacyProviderClient(apiKey: "secret", baseURL: URL(string: "https://api.example.test")!, loader: session)

    do {
      _ = try await client.addDenylist(profileID: "abc123", domain: "bad.example")
      XCTFail("Expected API error")
    } catch LegacyProviderError.api(let errors) {
      XCTAssertEqual(errors.first?.detail, "Invalid domain.")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testAddDenylistTreatsSuccessfulResponseWithoutEnvelopeAsSuccess() async throws {
    let session = makeSession { request in
      XCTAssertEqual(request.url?.path, "/profiles/abc123/denylist")
      return self.response(for: request, body: "{}")
    }

    let client = LegacyProviderClient(apiKey: "secret", baseURL: URL(string: "https://api.example.test")!, loader: session)
    let item = try await client.addDenylist(profileID: "abc123", domain: "x.com")

    XCTAssertEqual(item, LegacyProviderRuleItem(id: "x.com", active: true))
  }

  func testGetDenylistReadsEveryPage() async throws {
    var pathsAndQueries: [String] = []
    let session = makeSession { request in
      pathsAndQueries.append(
        request.url!.path + "?" + (request.url?.query ?? "")
      )
      if request.url?.query?.contains("cursor=next") == true {
        return self.response(
          for: request,
          body: """
          {
            "data": [{"id": "x.com", "active": false}],
            "meta": {"pagination": {"cursor": null}}
          }
          """
        )
      }
      return self.response(
        for: request,
        body: """
        {
          "data": [{"id": "example.com", "active": true}],
          "meta": {"pagination": {"cursor": "next"}}
        }
        """
      )
    }

    let client = LegacyProviderClient(apiKey: "secret", baseURL: URL(string: "https://api.example.test")!, loader: session)
    let items = try await client.getDenylist(profileID: "abc123")

    XCTAssertEqual(
      pathsAndQueries,
      [
        "/profiles/abc123/denylist?",
        "/profiles/abc123/denylist?cursor=next",
      ])
    XCTAssertEqual(
      items,
      [
        LegacyProviderRuleItem(id: "example.com", active: true),
        LegacyProviderRuleItem(id: "x.com", active: false),
      ])
  }

  func testHTTPStatusThrowsForInvalidKey() async {
    let session = makeSession { request in
      self.response(for: request, statusCode: 401, body: "{}")
    }

    let client = LegacyProviderClient(apiKey: "wrong", baseURL: URL(string: "https://api.example.test")!, loader: session)

    do {
      _ = try await client.analyticsStatus(profileID: "abc123")
      XCTFail("Expected HTTP error")
    } catch LegacyProviderError.httpStatus(let status) {
      XCTAssertEqual(status, 401)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testBlockedLogsDecodeWithPaginationMetadata() async throws {
    let session = makeSession { request in
      XCTAssertEqual(request.url?.query, "status=blocked&limit=50")
      return self.response(
        for: request,
        body: """
        {
          "data": [
            {
              "id": "evt_1",
              "timestamp": "2021-03-18T02:56:14.182Z",
              "domain": "blocked.example",
              "root": "example",
              "protocol": "DNS-over-HTTPS",
              "client": "apple-profile",
              "status": "blocked",
              "reasons": [{"id": "parental:porn", "name": "Pornography"}]
            }
          ],
          "meta": {"pagination": {"cursor": "next"}}
        }
        """
      )
    }

    let client = LegacyProviderClient(apiKey: "secret", baseURL: URL(string: "https://api.example.test")!, loader: session)
    let logs = try await client.blockedLogs(profileID: "abc123", limit: 50)

    XCTAssertEqual(logs.count, 1)
    XCTAssertEqual(logs[0].id, "evt_1")
    XCTAssertEqual(logs[0].reasons.first?.name, "Pornography")
  }

  private func makeSession(
    handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
  ) -> URLSession {
    MockURLProtocol.requestHandler = handler
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: configuration)
  }

  private func response(
    for request: URLRequest,
    statusCode: Int = 200,
    body: String
  ) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: ["Content-Type": "application/json"]
    )!
    return (response, Data(body.utf8))
  }
}

final class MockURLProtocol: URLProtocol {
  static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    guard let requestHandler = Self.requestHandler else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }

    do {
      let (response, data) = try requestHandler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}
