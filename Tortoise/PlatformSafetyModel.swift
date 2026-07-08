import Foundation

/// The X account-setting status row on the X tuning card: a pure mapping from
/// the stored platform-controls snapshot to one honest line and one next step.
/// X's own "Display media that may contain sensitive content" setting decides
/// whether X serves adult media raw — server-side, everywhere, including the
/// native X app — so surfacing it is the highest-leverage layer of the
/// explicit-content defense.
enum XPlatformSafety {
  enum Status: Equatable {
    /// Never observed: the extension only reads the setting when the user
    /// visits X's settings page, so prompt them to check it once.
    case unknown
    /// displaySensitiveMedia is ON: X shows adult media without warnings.
    case exposed
    /// displaySensitiveMedia is OFF: X's own filter gates flagged media.
    case protected
  }

  static let displaySensitiveMediaKey = "displaySensitiveMedia"
  static let settingsURL = URL(string: "https://x.com/settings/content_you_see")!

  static func status(snapshot: PlatformControlsSnapshot?) -> Status {
    guard let snapshot, snapshot.site == "x",
          let displaySensitiveMedia = snapshot.controls[displaySensitiveMediaKey] else {
      return .unknown
    }
    return displaySensitiveMedia ? .exposed : .protected
  }

  static func detail(for status: Status) -> String {
    let base: String
    switch status {
    case .unknown:
      base = XPlatformSafetyCopy.unknownDetail
    case .exposed:
      base = XPlatformSafetyCopy.exposedDetail
    case .protected:
      base = XPlatformSafetyCopy.protectedDetail
    }
    return base + " " + XPlatformSafetyCopy.screeningNote
  }

  /// The row's action title; nil when there is nothing left to do.
  static func actionTitle(for status: Status) -> String? {
    switch status {
    case .unknown:
      return XPlatformSafetyCopy.unknownCTA
    case .exposed:
      return XPlatformSafetyCopy.exposedCTA
    case .protected:
      return nil
    }
  }
}

enum XPlatformSafetyCopy {
  static let title = "X's own filter"
  static let exposedDetail = "Your X account shows sensitive media without warnings. Turn that off so X hides adult content too — everywhere, including the X app."
  static let exposedCTA = "Fix in X settings"
  static let unknownDetail = "X can hide sensitive media itself. Open your X setting once — Tortoise reads it and remembers."
  static let unknownCTA = "Check X setting"
  static let protectedDetail = "X hides media it flags as sensitive. Tortoise cleans up the rest."
  /// Appended to every status detail: what screen-until-verified means here.
  static let screeningNote = "New media stays blurred in Safari until Tortoise verifies the post and its account — tap a blurred post to show it."
}
