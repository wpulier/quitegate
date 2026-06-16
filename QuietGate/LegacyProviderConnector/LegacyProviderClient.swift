#if DEBUG
import Foundation

protocol HTTPDataLoading {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataLoading {}

final class LegacyProviderClient: LegacyProviderServicing {
  private let apiKey: String
  private let baseURL: URL
  private let loader: HTTPDataLoading
  private let decoder: JSONDecoder
  private let encoder: JSONEncoder

  init(
    apiKey: String,
    baseURL: URL = URL(string: "https://api.nextdns.io")!,
    loader: HTTPDataLoading = URLSession.shared
  ) {
    self.apiKey = apiKey
    self.baseURL = baseURL
    self.loader = loader
    decoder = JSONDecoder.legacyProviderDecoder()
    encoder = JSONEncoder()
  }

  func getParentalControl(profileID: String) async throws -> ParentalControl {
    try await sendEnvelope(request(endpoint: ["profiles", profileID, "parentalControl"], method: "GET"))
  }

  func patchParentalControl(profileID: String, value: ParentalControl) async throws -> ParentalControl {
    let request = try request(
      endpoint: ["profiles", profileID, "parentalControl"],
      method: "PATCH",
      body: value
    )
    do {
      return try await sendEnvelope(request)
    } catch LegacyProviderError.emptyResponse {
      return value
    }
  }

  func getDenylist(profileID: String) async throws -> [LegacyProviderRuleItem] {
    var items: [LegacyProviderRuleItem] = []
    var cursor: String?
    var seenCursors: Set<String> = []

    repeat {
      var queryItems: [URLQueryItem] = []
      if let cursor {
        queryItems.append(URLQueryItem(name: "cursor", value: cursor))
      }

      let envelope: APIEnvelope<[LegacyProviderRuleItem]> = try await sendEnvelopeWithMeta(
        request(endpoint: ["profiles", profileID, "denylist"], queryItems: queryItems, method: "GET")
      )
      items.append(contentsOf: envelope.data)

      let nextCursor = envelope.meta?.pagination?.cursor
      if let nextCursor, !nextCursor.isEmpty, !seenCursors.contains(nextCursor) {
        seenCursors.insert(nextCursor)
        cursor = nextCursor
      } else {
        cursor = nil
      }
    } while cursor != nil

    return items
  }

  func addDenylist(profileID: String, domain: String) async throws -> LegacyProviderRuleItem {
    let item = LegacyProviderRuleItem(id: domain, active: true)
    let request = try request(
      endpoint: ["profiles", profileID, "denylist"],
      method: "POST",
      body: LegacyProviderRuleRequest(id: domain, active: true)
    )
    let data = try await sendData(request)
    guard !data.isEmpty else {
      return item
    }
    return (try? decoder.decode(APIEnvelope<LegacyProviderRuleItem>.self, from: data).data) ?? item
  }

  func removeDenylist(profileID: String, domain: String) async throws {
    try await sendVoid(request(endpoint: ["profiles", profileID, "denylist", domain], method: "DELETE"))
  }

  func blockedLogs(profileID: String, limit: Int = 50) async throws -> [LegacyProviderLogEntry] {
    let query = [
      URLQueryItem(name: "status", value: "blocked"),
      URLQueryItem(name: "limit", value: String(limit))
    ]
    return try await sendEnvelope(request(endpoint: ["profiles", profileID, "logs"], queryItems: query, method: "GET"))
  }

  func analyticsStatus(profileID: String) async throws -> [LegacyProviderAnalyticsStatus] {
    try await sendEnvelope(request(endpoint: ["profiles", profileID, "analytics", "status"], method: "GET"))
  }

  private func request(
    endpoint: [String],
    queryItems: [URLQueryItem] = [],
    method: String
  ) -> URLRequest {
    var url = baseURL
    endpoint.forEach { url.appendPathComponent($0) }
    if !queryItems.isEmpty {
      var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
      components?.queryItems = queryItems
      url = components?.url ?? url
    }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return request
  }

  private func request<Body: Encodable>(
    endpoint: [String],
    method: String,
    body: Body
  ) throws -> URLRequest {
    var request = request(endpoint: endpoint, method: method)
    request.httpBody = try encoder.encode(body)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    return request
  }

  private func sendEnvelope<T: Decodable>(_ request: URLRequest) async throws -> T {
    try await sendEnvelopeWithMeta(request).data
  }

  private func sendEnvelopeWithMeta<T: Decodable>(_ request: URLRequest) async throws
    -> APIEnvelope<T>
  {
    let data = try await sendData(request)
    guard !data.isEmpty else { throw LegacyProviderError.emptyResponse }
    do {
      return try decoder.decode(APIEnvelope<T>.self, from: data)
    } catch {
      throw LegacyProviderError.decoding(error)
    }
  }

  private func sendVoid(_ request: URLRequest) async throws {
    _ = try await sendData(request)
  }

  private func sendData(_ request: URLRequest) async throws -> Data {
    let (data, response) = try await loader.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw LegacyProviderError.invalidResponse
    }

    if let envelope = try? decoder.decode(LegacyProviderErrorEnvelope.self, from: data),
       !envelope.errors.isEmpty {
      throw LegacyProviderError.api(envelope.errors)
    }

    guard (200..<300).contains(httpResponse.statusCode) else {
      throw LegacyProviderError.httpStatus(httpResponse.statusCode)
    }

    return data
  }
}

extension JSONDecoder {
  static func legacyProviderDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let value = try container.decode(String.self)
      if let date = ISO8601DateFormatter.withFractionalSeconds.date(from: value) {
        return date
      }
      if let date = ISO8601DateFormatter.standardInternetDateTime.date(from: value) {
        return date
      }
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid ISO-8601 date: \(value)"
      )
    }
    return decoder
  }
}

private extension ISO8601DateFormatter {
  static let withFractionalSeconds: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  static let standardInternetDateTime: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()
}
#endif
