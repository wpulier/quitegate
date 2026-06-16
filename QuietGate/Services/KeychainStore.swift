import Foundation
import Security

protocol SecretStoring {
  func readSecret() throws -> String?
  func readSecret(allowUserInteraction: Bool) throws -> String?
  func hasSecret() -> Bool
  func saveSecret(_ value: String) throws
  func deleteSecret() throws
}

extension SecretStoring {
  func readSecret(allowUserInteraction: Bool) throws -> String? {
    try readSecret()
  }

  func hasSecret() -> Bool {
    ((try? readSecret(allowUserInteraction: false)) ?? nil) != nil
  }
}

enum KeychainError: LocalizedError {
  case unexpectedStatus(OSStatus)
  case invalidData
  case unavailableWithoutUserInteraction

  var errorDescription: String? {
    switch self {
    case .unexpectedStatus(let status):
      return "Keychain returned status \(status)."
    case .invalidData:
      return "The saved Keychain item could not be read."
    case .unavailableWithoutUserInteraction:
      return "QuietGate needs permission to read a saved setup key. Click Allow Access and approve the Mac prompt, or connect again."
    }
  }
}

final class KeychainStore: SecretStoring {
  private let service: String
  private let account: String
  private let legacyService: String?
  private let legacyAccount: String?

  init(
    service: String = "QuietGate",
    account: String = "QuietGate saved setup key",
    legacyService: String? = KeychainStore.defaultLegacyService,
    legacyAccount: String? = KeychainStore.defaultLegacyAccount
  ) {
    self.service = service
    self.account = account
    self.legacyService = legacyService
    self.legacyAccount = legacyAccount
  }

  private static var defaultLegacyService: String? {
    #if DEBUG
    "com.willpulier.QuietGate.legacy-provider-key"
    #else
    nil
    #endif
  }

  private static var defaultLegacyAccount: String? {
    #if DEBUG
    "default"
    #else
    nil
    #endif
  }

  func readSecret() throws -> String? {
    try readSecret(allowUserInteraction: false)
  }

  func readSecret(allowUserInteraction: Bool) throws -> String? {
    if let primarySecret = try readSecret(
      service: service,
      account: account,
      allowUserInteraction: allowUserInteraction
    ) {
      return primarySecret
    }

    guard let legacyService, let legacyAccount else {
      return nil
    }

    let legacySecret = try readSecret(
      service: legacyService,
      account: legacyAccount,
      allowUserInteraction: false
    )
    if let legacySecret {
      try saveSecret(legacySecret)
    }
    return legacySecret
  }

  private func readSecret(
    service: String,
    account: String,
    allowUserInteraction: Bool
  ) throws -> String? {
    var query = baseQuery(service: service, account: account)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    if !allowUserInteraction {
      query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip
    }

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
      return nil
    }
    if Self.requiresUserInteraction(status) {
      throw KeychainError.unavailableWithoutUserInteraction
    }
    guard status == errSecSuccess else {
      throw KeychainError.unexpectedStatus(status)
    }
    guard let data = result as? Data,
          let value = String(data: data, encoding: .utf8) else {
      throw KeychainError.invalidData
    }
    return value
  }

  func hasSecret() -> Bool {
    hasSecret(service: service, account: account) || hasLegacySecret()
  }

  private func hasSecret(service: String, account: String) -> Bool {
    var query = baseQuery(service: service, account: account)
    query[kSecReturnAttributes as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecSuccess || Self.requiresUserInteraction(status) {
      return true
    }
    return false
  }

  private func hasLegacySecret() -> Bool {
    guard let legacyService, let legacyAccount else {
      return false
    }
    return hasSecret(service: legacyService, account: legacyAccount)
  }

  func saveSecret(_ value: String) throws {
    try deleteSecret()
    var item = baseQuery(service: service, account: account)
    item[kSecValueData as String] = Data(value.utf8)
    item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    item[kSecAttrLabel as String] = "QuietGate saved setup key"
    item[kSecAttrDescription as String] = "Lets QuietGate save your blocking choices."

    let status = SecItemAdd(item as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw KeychainError.unexpectedStatus(status)
    }
  }

  func deleteSecret() throws {
    let status = SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainError.unexpectedStatus(status)
    }

    if let legacyService, let legacyAccount {
      let legacyStatus = SecItemDelete(
        baseQuery(service: legacyService, account: legacyAccount) as CFDictionary
      )
      guard legacyStatus == errSecSuccess || legacyStatus == errSecItemNotFound else {
        throw KeychainError.unexpectedStatus(legacyStatus)
      }
    }
  }

  private func baseQuery(service: String, account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]
  }

  private static func requiresUserInteraction(_ status: OSStatus) -> Bool {
    status == errSecInteractionNotAllowed ||
      status == errSecUserCanceled ||
      status == errSecAuthFailed
  }
}
