import Foundation
import Security

enum InstallationStore {
  private static let service = "com.yourtortoise.Tortoise"
  private static let account = "installation-id"

  static func installationId() -> String {
    if let existing = read() {
      return existing
    }

    let created = UUID().uuidString
    save(created)
    return created
  }

  private static func read() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]

    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
          let data = item as? Data
    else {
      return nil
    }

    return String(data: data, encoding: .utf8)
  }

  private static func save(_ value: String) {
    let data = Data(value.utf8)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]
    let attributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ]

    let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      var item = query
      item.merge(attributes) { _, new in new }
      SecItemAdd(item as CFDictionary, nil)
    }
  }
}
