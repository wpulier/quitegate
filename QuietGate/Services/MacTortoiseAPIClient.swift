import Foundation

struct MacTortoiseAPIClient {
  private let baseURL: URL
  private let session: URLSession

  init(baseURL: URL = AppConfig.apiBaseURL, session: URLSession = .shared) {
    self.baseURL = baseURL
    self.session = session
  }

  func fetchPolicy(token: String) async throws -> PolicyEnvelope {
    try await request(path: "/api/policy", token: token)
  }

  func updatePolicy(
    token: String,
    policy: TortoisePolicy,
    expectedSettingsVersion: Int
  ) async throws -> PolicyEnvelope {
    try await request(
      path: "/api/policy",
      method: "PUT",
      token: token,
      body: PolicyUpdateRequest(
        expectedSettingsVersion: expectedSettingsVersion,
        policy: policy
      )
    )
  }

  func fetchDevices(token: String) async throws -> DevicesEnvelope {
    try await request(path: "/api/devices", token: token)
  }

  func fetchSiteUsage(token: String, date: String) async throws -> SiteUsageSummarySnapshot? {
    let envelope: SiteUsageEnvelope = try await request(
      path: "/api/usage?date=\(date)",
      token: token,
      decoder: Self.usageDecoder
    )
    return envelope.siteUsageSummary
  }

  /// The backend emits ISO-8601 timestamps with fractional seconds
  /// (JavaScript `toISOString()`), which Swift's plain `.iso8601`
  /// strategy rejects — so try both.
  private static let usageDecoder: JSONDecoder = {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let value = try container.decode(String.self)
      if let date = fractional.date(from: value) ?? plain.date(from: value) {
        return date
      }
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Unrecognized date format: \(value)"
      )
    }
    return decoder
  }()

  func registerDevice(token: String, registration: DeviceRegistration) async throws -> DeviceEnvelope {
    try await request(path: "/api/devices", method: "POST", token: token, body: registration)
  }

  func postHealth(token: String, deviceId: String, health: DeviceHealth) async throws {
    let _: EmptyResponse = try await request(
      path: "/api/devices/\(deviceId)/health",
      method: "POST",
      token: token,
      body: health
    )
  }

  private func request<Response: Decodable>(
    path: String,
    method: String = "GET",
    token: String,
    decoder: JSONDecoder = JSONDecoder()
  ) async throws -> Response {
    try await request(
      path: path,
      method: method,
      token: token,
      body: Optional<EmptyBody>.none,
      decoder: decoder
    )
  }

  private func request<Response: Decodable, Body: Encodable>(
    path: String,
    method: String = "GET",
    token: String,
    body: Body?,
    decoder: JSONDecoder = JSONDecoder()
  ) async throws -> Response {
    guard let url = URL(string: path, relativeTo: baseURL) else {
      throw TortoiseAPIError.invalidResponse
    }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    if let body {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONEncoder().encode(body)
    }

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw TortoiseAPIError.invalidResponse
    }

    let envelope = try decoder.decode(ApiEnvelope<Response>.self, from: data)
    if envelope.ok, let data = envelope.data {
      return data
    }

    if let error = envelope.error {
      throw TortoiseAPIError.server(error.message)
    }

    throw TortoiseAPIError.server("Tortoise account sync failed with status \(httpResponse.statusCode).")
  }
}

enum TortoiseAPIError: LocalizedError {
  case invalidResponse
  case server(String)
  case missingSessionToken

  var errorDescription: String? {
    switch self {
    case .invalidResponse:
      return "Tortoise could not read the account response."
    case .server(let message):
      return message
    case .missingSessionToken:
      return "Sign in again to refresh your account session."
    }
  }
}

private struct EmptyBody: Encodable {}
private struct EmptyResponse: Decodable {}

private struct SiteUsageEnvelope: Decodable {
  let siteUsageSummary: SiteUsageSummarySnapshot?
}
