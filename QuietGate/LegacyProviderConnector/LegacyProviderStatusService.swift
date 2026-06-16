#if DEBUG
import Foundation

final class LegacyProviderStatusService: ResolverStatusChecking {
  private let url: URL
  private let session: URLSession

  init(url: URL = URL(string: "https://test.nextdns.io/")!, session: URLSession = .shared) {
    self.url = url
    self.session = session
  }

  func check() async throws -> LegacyProviderResolverStatus {
    let (data, _) = try await session.data(from: url)
    do {
      return try Self.parseStatus(from: data)
    } catch ResolverStatusError.browserProbeRequired(let probeURLString) {
      guard let probeURL = URL(string: probeURLString) else {
        throw ResolverStatusError.browserProbeRequired(probeURLString)
      }
      let (probeData, _) = try await session.data(from: probeURL)
      return try Self.parseStatus(from: probeData)
    }
  }

  static func parseStatus(from data: Data) throws -> LegacyProviderResolverStatus {
    let decoder = JSONDecoder()
    if let status = try? decoder.decode(LegacyProviderResolverStatus.self, from: data) {
      return status
    }

    guard let body = String(data: data, encoding: .utf8) else {
      throw ResolverStatusError.unreadableResponse
    }

    if let probeURL = browserProbeURL(in: body) {
      throw ResolverStatusError.browserProbeRequired(probeURL)
    }

    if let jsonData = embeddedJSONData(in: body),
       let status = try? decoder.decode(LegacyProviderResolverStatus.self, from: jsonData) {
      return status
    }

    throw ResolverStatusError.unexpectedResponsePreview(body.trimmingCharacters(in: .whitespacesAndNewlines))
  }

  private static func browserProbeURL(in body: String) -> String? {
    guard let range = body.range(of: #"xhr\.open\('GET', '([^']+)'"#, options: .regularExpression) else {
      return nil
    }
    let match = String(body[range])
    guard let start = match.range(of: "'GET', '")?.upperBound,
          let end = match[start...].firstIndex(of: "'") else {
      return nil
    }
    return String(match[start..<end])
  }

  private static func embeddedJSONData(in body: String) -> Data? {
    guard let start = body.firstIndex(of: "{"),
          let end = body.lastIndex(of: "}"),
          start < end else {
      return nil
    }
    return String(body[start...end]).data(using: .utf8)
  }
}

enum ResolverStatusError: LocalizedError, Equatable {
  case unreadableResponse
  case browserProbeRequired(String)
  case unexpectedResponsePreview(String)

  var errorDescription: String? {
    switch self {
    case .unreadableResponse:
      return "QuietGate could not read the connection check."
    case .browserProbeRequired(let url):
      return "QuietGate could not finish the connection check at \(url)."
    case .unexpectedResponsePreview(let value):
      let preview = String(value.prefix(180))
      return "QuietGate received an unexpected connection response: \(preview)"
    }
  }
}
#endif
