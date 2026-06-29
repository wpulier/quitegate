import Foundation

enum AppConfig {
  static var clerkPublishableKey: String {
    stringValue(for: "CLERK_PUBLISHABLE_KEY")
  }

  static var apiBaseURL: URL {
    URL(string: stringValue(for: "TORTOISE_API_BASE_URL")) ?? URL(string: "https://www.yourtortoise.com")!
  }

  private static func stringValue(for key: String) -> String {
    if let environmentValue = normalized(ProcessInfo.processInfo.environment[key]) {
      return environmentValue
    }

    return normalized(Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? ""
  }

  private static func normalized(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return nil
    }

    return value
  }
}
