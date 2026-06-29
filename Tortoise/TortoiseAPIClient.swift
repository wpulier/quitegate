import Foundation

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

struct TortoiseAPIClient {
  private let baseURL: URL
  private let session: URLSession

  init(baseURL: URL = AppConfig.apiBaseURL, session: URLSession = .shared) {
    self.baseURL = baseURL
    self.session = session
  }

  func fetchPolicy(token: String) async throws -> PolicyEnvelope {
    try await request(path: "/api/policy", token: token)
  }

  func fetchDevices(token: String) async throws -> DevicesEnvelope {
    try await request(path: "/api/devices", token: token)
  }

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
    token: String
  ) async throws -> Response {
    try await request(path: path, method: method, token: token, body: Optional<EmptyBody>.none)
  }

  private func request<Response: Decodable, Body: Encodable>(
    path: String,
    method: String = "GET",
    token: String,
    body: Body? = Optional<String>.none
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

    let envelope = try JSONDecoder().decode(ApiEnvelope<Response>.self, from: data)
    if envelope.ok, let data = envelope.data {
      return data
    }

    if let error = envelope.error {
      throw TortoiseAPIError.server(error.message)
    }

    throw TortoiseAPIError.server("Tortoise account sync failed with status \(httpResponse.statusCode).")
  }
}

private struct EmptyBody: Encodable {}
private struct EmptyResponse: Decodable {}
