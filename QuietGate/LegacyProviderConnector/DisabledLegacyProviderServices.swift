import Foundation

enum DisabledLegacyProviderServiceError: LocalizedError {
  case disabled

  var errorDescription: String? {
    "This setup path is not available in this QuietGate build."
  }
}

struct DisabledLegacySecretStore: SecretStoring {
  func readSecret() throws -> String? { nil }
  func readSecret(allowUserInteraction: Bool) throws -> String? { nil }
  func hasSecret() -> Bool { false }
  func saveSecret(_ value: String) throws {
    throw DisabledLegacyProviderServiceError.disabled
  }
  func deleteSecret() throws {}
}

struct DisabledLegacyProviderService: LegacyProviderServicing {
  func getParentalControl(profileID: String) async throws -> ParentalControl {
    throw DisabledLegacyProviderServiceError.disabled
  }

  func patchParentalControl(
    profileID: String,
    value: ParentalControl
  ) async throws -> ParentalControl {
    throw DisabledLegacyProviderServiceError.disabled
  }

  func getDenylist(profileID: String) async throws -> [LegacyProviderRuleItem] {
    throw DisabledLegacyProviderServiceError.disabled
  }

  func addDenylist(profileID: String, domain: String) async throws -> LegacyProviderRuleItem {
    throw DisabledLegacyProviderServiceError.disabled
  }

  func removeDenylist(profileID: String, domain: String) async throws {
    throw DisabledLegacyProviderServiceError.disabled
  }

  func blockedLogs(profileID: String, limit: Int) async throws -> [LegacyProviderLogEntry] {
    throw DisabledLegacyProviderServiceError.disabled
  }

  func analyticsStatus(profileID: String) async throws -> [LegacyProviderAnalyticsStatus] {
    throw DisabledLegacyProviderServiceError.disabled
  }
}

struct DisabledResolverStatusService: ResolverStatusChecking {
  func check() async throws -> LegacyProviderResolverStatus {
    throw DisabledLegacyProviderServiceError.disabled
  }
}

struct DisabledSystemProfileChecker: SystemProfileChecking {
  func legacyProviderProfileStatus(profileID: String) -> SystemLegacyProviderProfileStatus {
    SystemLegacyProviderProfileStatus(
      anyLegacyProviderProfileInstalled: false,
      configuredLegacyProviderProfileInstalled: false
    )
  }
}

struct DisabledLegacyProviderProfileGenerator: LegacyProviderProfileGenerating {
  func writeProfile(profileID: String) throws -> URL {
    throw DisabledLegacyProviderServiceError.disabled
  }
}

struct DisabledLocalHostsScriptGenerator: LocalHostsBlockerScriptGenerating {
  func writeScript(domains: [String]) throws -> URL {
    throw DisabledLegacyProviderServiceError.disabled
  }

  func installBlocklist(domains: [String]) throws {
    throw DisabledLegacyProviderServiceError.disabled
  }

  func removeBlocklist() throws {
    throw DisabledLegacyProviderServiceError.disabled
  }

  func localHostsBlocklistInstalled() -> Bool {
    false
  }

  func localHostsBlocklistMatches(domains: [String]) -> Bool {
    false
  }
}
