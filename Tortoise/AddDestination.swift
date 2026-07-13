import Foundation

/// What the user can add to their Tortoise account. Phone and computer use a
/// download handoff; the Mac app handles the Chrome-extension connection itself.
enum AddDestination: String, CaseIterable, Identifiable {
  case phone
  case computer
  case browser

  var id: String { rawValue }

  var title: String {
    switch self {
    case .phone: return "Phone"
    case .computer: return "Computer"
    case .browser: return "Chrome extension"
    }
  }

  var systemImage: String {
    switch self {
    case .phone: return "iphone"
    case .computer: return "desktopcomputer"
    case .browser: return "puzzlepiece.extension"
    }
  }

  /// One short line shown under the QR — no jargon.
  var caption: String {
    switch self {
    case .phone, .computer: return "Install Tortoise, sign in — it appears here."
    case .browser: return "Install it if needed, then connect your account in Chrome."
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
