import Foundation

protocol LegacyProviderServicing {
  func getParentalControl(profileID: String) async throws -> ParentalControl
  func patchParentalControl(profileID: String, value: ParentalControl) async throws -> ParentalControl
  func getDenylist(profileID: String) async throws -> [LegacyProviderRuleItem]
  func addDenylist(profileID: String, domain: String) async throws -> LegacyProviderRuleItem
  func removeDenylist(profileID: String, domain: String) async throws
  func blockedLogs(profileID: String, limit: Int) async throws -> [LegacyProviderLogEntry]
  func analyticsStatus(profileID: String) async throws -> [LegacyProviderAnalyticsStatus]
}

enum LegacyProviderError: LocalizedError {
  case notConfigured
  case invalidResponse
  case emptyResponse
  case httpStatus(Int)
  case api([LegacyProviderAPIErrorDetail])
  case decoding(Error)

  var errorDescription: String? {
    switch self {
    case .notConfigured:
      return "This setup connection is not configured."
    case .invalidResponse:
      return "This setup connection returned an invalid response."
    case .emptyResponse:
      return "This setup connection returned an empty response."
    case .httpStatus(let status):
      return "This setup connection returned error \(status)."
    case .api(let errors):
      return errors.map(\.detail).joined(separator: "\n")
    case .decoding(let error):
      return "Could not read the setup connection response: \(error.localizedDescription)"
    }
  }
}

protocol ResolverStatusChecking {
  func check() async throws -> LegacyProviderResolverStatus
}

struct SystemLegacyProviderProfileStatus: Equatable {
  let anyLegacyProviderProfileInstalled: Bool
  let configuredLegacyProviderProfileInstalled: Bool
}

protocol SystemProfileChecking {
  func legacyProviderProfileStatus(profileID: String) -> SystemLegacyProviderProfileStatus
}

protocol LegacyProviderProfileGenerating {
  func writeProfile(profileID: String) throws -> URL
}

protocol LocalHostsBlockerScriptGenerating {
  func writeScript(domains: [String]) throws -> URL
  func installBlocklist(domains: [String]) throws
  func removeBlocklist() throws
  func localHostsBlocklistInstalled() -> Bool
  func localHostsBlocklistMatches(domains: [String]) -> Bool
}

enum LegacyProviderProfileError: LocalizedError {
  case missingProfileID
  case invalidProfile

  var errorDescription: String? {
    switch self {
    case .missingProfileID:
      return "Finish setup before preparing Mac approval."
    case .invalidProfile:
      return "The Mac approval could not be created."
    }
  }
}

enum LocalHostsBlockerScriptError: LocalizedError {
  case emptyBlocklist
  case privilegedCommandFailed(String)

  var errorDescription: String? {
    switch self {
    case .emptyBlocklist:
      return "Add a blocked site or turn on a category before setting up backup blocking."
    case .privilegedCommandFailed(let output):
      let detail = output.trimmingCharacters(in: .whitespacesAndNewlines)
      if detail.localizedCaseInsensitiveContains("user canceled") || detail.contains("(-128)") {
        return "Backup blocking was not updated because the Mac password prompt was canceled."
      }
      return detail.isEmpty
        ? "Backup blocking could not be updated. Try again and approve the Mac password prompt."
        : "Backup blocking could not be updated. Try again and approve the Mac password prompt."
    }
  }
}
