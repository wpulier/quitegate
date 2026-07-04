import Foundation

/// What the user can add to their Tortoise account. Each maps to the web page
/// that gets Tortoise onto that thing; after sign-in it appears in the hub.
/// Account-based — there are no pairing codes.
enum AddDestination: String, CaseIterable, Identifiable {
  case phone
  case computer
  case browser

  var id: String { rawValue }

  var title: String {
    switch self {
    case .phone: return "Phone"
    case .computer: return "Computer"
    case .browser: return "Browser"
    }
  }

  var systemImage: String {
    switch self {
    case .phone: return "iphone"
    case .computer: return "desktopcomputer"
    case .browser: return "globe"
    }
  }

  /// One short line shown under the QR — no jargon.
  var caption: String {
    switch self {
    case .phone, .computer: return "Install Tortoise, sign in — it appears here."
    case .browser: return "Add the extension, sign in — it appears here."
    }
  }

  private var path: String {
    switch self {
    case .phone: return "download/ios"
    case .computer: return "download/mac"
    case .browser: return "download/chrome"
    }
  }

  func url(base: URL = AppConfig.apiBaseURL) -> URL {
    base.appendingPathComponent(path)
  }
}
