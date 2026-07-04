import Foundation

/// The single classification of a connected thing. Replaces the per-screen
/// copies previously inlined in ProtectionView (macOS) and ContentView (iOS).
enum DeviceKind: Equatable {
  case mac
  case iphone
  case browser(brand: String)  // brand is a lowercase key: "chrome","firefox","safari","edge","brave","arc"
  case other
}

extension TortoiseDevice {
  private var normalizedPlatform: String { (platform ?? "").lowercased() }

  var deviceKind: DeviceKind {
    let p = normalizedPlatform
    switch p {
    case "ios": return .iphone
    case "macos", "mac": return .mac
    default:
      for brand in ["chrome", "firefox", "safari", "edge", "brave", "arc"] where p.contains(brand) {
        return .browser(brand: brand)
      }
      return .other
    }
  }

  var isBrowserProfile: Bool {
    if case .browser = deviceKind { return true }
    return false
  }

  /// The user-facing name: the device's own name, else a label for its kind.
  var displayName: String {
    let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty { return trimmed }
    switch deviceKind {
    case .mac: return "Mac"
    case .iphone: return "iPhone"
    case .browser(let brand): return brand.capitalized
    case .other: return "Device"
    }
  }

  var initials: String {
    let letters = displayName.split(separator: " ").prefix(2).compactMap(\.first)
    if letters.isEmpty { return "T" }
    return String(letters).uppercased()
  }

  /// Real brand asset name for browser kinds (nil for mac/iphone/other, which use SF Symbols).
  var brandAssetName: String? {
    if case .browser(let brand) = deviceKind { return "Brand\(brand.capitalized)" }
    return nil
  }

  /// Parses the ISO8601 `lastSeenAt` string (with or without fractional seconds).
  var lastSeenDate: Date? {
    guard let lastSeenAt else { return nil }
    return DevicePresentationFormatters.withFractional.date(from: lastSeenAt)
      ?? DevicePresentationFormatters.plain.date(from: lastSeenAt)
  }
}

enum DevicePresentationFormatters {
  static let withFractional: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()
  static let plain: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()
}
