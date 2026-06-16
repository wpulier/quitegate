import Foundation

protocol PlatformControlsChecking {
  func snapshot(
    browserSnapshot: ChromeHelperSnapshot?,
    quietGateTunersReady: Bool,
    now: Date
  ) async -> BuiltInProtectionsSnapshot
}

protocol ChromePolicyReading {
  func value(for key: String) -> Any?
}

struct SystemChromePolicyReader: ChromePolicyReading {
  private let fileManager: FileManager
  private let policyURLs: [URL]

  init(fileManager: FileManager = .default, policyURLs: [URL]? = nil) {
    self.fileManager = fileManager
    self.policyURLs = policyURLs ?? [
      URL(fileURLWithPath: "/Library/Managed Preferences/com.google.Chrome.plist"),
      URL(fileURLWithPath: "/Library/Preferences/com.google.Chrome.plist"),
      FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library", isDirectory: true)
        .appendingPathComponent("Preferences", isDirectory: true)
        .appendingPathComponent("com.google.Chrome.plist")
    ]
  }

  func value(for key: String) -> Any? {
    for url in policyURLs where fileManager.fileExists(atPath: url.path) {
      guard let data = try? Data(contentsOf: url),
            let propertyList = try? PropertyListSerialization.propertyList(
              from: data,
              options: [],
              format: nil
            ),
            let object = propertyList as? [String: Any],
            let value = object[key] else {
        continue
      }
      return value
    }
    return CFPreferencesCopyAppValue(key as CFString, "com.google.Chrome" as CFString)
  }
}

struct PlatformControlsChecker: PlatformControlsChecking {
  private static let googleSafeSearchAddresses = Set([
    "216.239.38.120",
    "2001:4860:4802:32::78"
  ])

  private let hostsTextProvider: () -> String?
  private let domainResolver: DomainResolutionChecking
  private let chromePolicyReader: ChromePolicyReading

  init(
    hostsTextProvider: @escaping () -> String? = {
      try? String(contentsOfFile: "/private/etc/hosts", encoding: .utf8)
    },
    domainResolver: DomainResolutionChecking = SystemDomainResolver(),
    chromePolicyReader: ChromePolicyReading = SystemChromePolicyReader()
  ) {
    self.hostsTextProvider = hostsTextProvider
    self.domainResolver = domainResolver
    self.chromePolicyReader = chromePolicyReader
  }

  func snapshot(
    browserSnapshot: ChromeHelperSnapshot?,
    quietGateTunersReady: Bool,
    now: Date
  ) async -> BuiltInProtectionsSnapshot {
    async let googleSafeSearchItem = googleSafeSearchStatus(now: now)
    let platformControls = browserSnapshot?.platformControls
    let items = await [
      appleScreenTimeWebStatus(now: now),
      appleSensitiveContentWarningStatus(now: now),
      cloudflareFamilyDNSStatus(now: now),
      cleanBrowsingFamilyDNSStatus(now: now),
      googleSafeSearchItem,
      chromeGoogleSafeSearchPolicyStatus(now: now),
      chromeYouTubeRestrictedModeStatus(now: now),
      xSensitiveMediaStatus(platformControls?.x, now: now),
      xSensitiveSearchStatus(platformControls?.x, now: now),
      redditMatureContentStatus(platformControls?.reddit, now: now),
      redditBlurMatureMediaStatus(platformControls?.reddit, now: now),
      quietGateTunerStatus(quietGateTunersReady: quietGateTunersReady, now: now)
    ]
    return BuiltInProtectionsSnapshot(checkedAt: now, items: items)
  }

  private func appleScreenTimeWebStatus(now: Date) -> PlatformControlItem {
    PlatformControlItem(
      id: .appleScreenTimeWeb,
      title: "Apple Screen Time web limits",
      detail: "Open Screen Time and set Web Content to Limit Adult Websites. QuietGate cannot reliably read this private setting directly.",
      state: .manualCheck,
      actionTitle: "Open Screen Time",
      actionURLString: "x-apple.systempreferences:com.apple.Screen-Time-Settings.extension",
      checkedAt: now
    )
  }

  private func appleSensitiveContentWarningStatus(now: Date) -> PlatformControlItem {
    PlatformControlItem(
      id: .appleSensitiveContentWarning,
      title: "Apple Sensitive Content Warning",
      detail: "Open Privacy & Security and enable Sensitive Content Warning for Apple-supported surfaces such as Messages and shared photos.",
      state: .manualCheck,
      actionTitle: "Open Privacy",
      actionURLString: "x-apple.systempreferences:com.apple.preference.security?Privacy",
      checkedAt: now
    )
  }

  private func cloudflareFamilyDNSStatus(now: Date) -> PlatformControlItem {
    PlatformControlItem(
      id: .cloudflareFamilyDNS,
      title: "Cloudflare Family DNS",
      detail: "For network-level coverage, configure Cloudflare 1.1.1.3 / 1.0.0.3 or its family DoH endpoint to block malware and adult content before pages reach the browser.",
      state: .manualCheck,
      actionTitle: "Open Setup",
      actionURLString: "https://developers.cloudflare.com/1.1.1.1/setup/",
      checkedAt: now
    )
  }

  private func cleanBrowsingFamilyDNSStatus(now: Date) -> PlatformControlItem {
    PlatformControlItem(
      id: .cleanBrowsingFamilyDNS,
      title: "CleanBrowsing filters",
      detail: "CleanBrowsing Adult and Family filters can add DNS-level adult-site blocking for browsers and apps that QuietGate cannot tune directly.",
      state: .manualCheck,
      actionTitle: "Open Filters",
      actionURLString: "https://cleanbrowsing.org/filters/",
      checkedAt: now
    )
  }

  private func googleSafeSearchStatus(now: Date) async -> PlatformControlItem {
    async let googleAddresses = domainResolver.addresses(for: "www.google.com")
    async let safeSearchAddresses = domainResolver.addresses(for: "forcesafesearch.google.com")
    let hostsLocked = hostsForcesSafeSearch()
    let resolvedGoogleAddresses = Set(await googleAddresses)
    let resolvedSafeSearchAddresses = Set(await safeSearchAddresses)
    let dnsLocked =
      !resolvedGoogleAddresses.isEmpty &&
      (
        !resolvedGoogleAddresses.intersection(Self.googleSafeSearchAddresses).isEmpty ||
        (!resolvedSafeSearchAddresses.isEmpty &&
          !resolvedGoogleAddresses.intersection(resolvedSafeSearchAddresses).isEmpty)
      )
    let locked = hostsLocked || dnsLocked
    return PlatformControlItem(
      id: .googleSafeSearch,
      title: "Google SafeSearch lock",
      detail: locked
        ? "Google search domains appear mapped to SafeSearch."
        : "Google SafeSearch is not locked by local hosts or DNS readback. Use Google's guided SafeSearch lock setup for stronger search filtering.",
      state: locked ? .enabled : .needsAction,
      actionTitle: "Open SafeSearch",
      actionURLString: "https://www.google.com/safesearch",
      checkedAt: now
    )
  }

  private func chromeGoogleSafeSearchPolicyStatus(now: Date) -> PlatformControlItem {
    let enabled = booleanPolicy("ForceGoogleSafeSearch") == true
    return PlatformControlItem(
      id: .chromeGoogleSafeSearchPolicy,
      title: "Chrome Google SafeSearch policy",
      detail: enabled
        ? "Chrome policy forces Google SafeSearch."
        : "Chrome policy ForceGoogleSafeSearch is not enabled.",
      state: enabled ? .enabled : .needsAction,
      actionTitle: "Open Policies",
      actionURLString: "chrome://policy",
      checkedAt: now
    )
  }

  private func chromeYouTubeRestrictedModeStatus(now: Date) -> PlatformControlItem {
    let value = chromePolicyReader.value(for: "ForceYouTubeRestrict")
    let enabled: Bool
    if let number = value as? NSNumber {
      enabled = number.intValue > 0
    } else if let string = value as? String, let integer = Int(string) {
      enabled = integer > 0
    } else {
      enabled = false
    }
    return PlatformControlItem(
      id: .chromeYouTubeRestrictedMode,
      title: "Chrome YouTube Restricted Mode",
      detail: enabled
        ? "Chrome policy forces YouTube Restricted Mode."
        : "Chrome policy ForceYouTubeRestrict is not enabled.",
      state: enabled ? .enabled : .needsAction,
      actionTitle: "Open Policies",
      actionURLString: "chrome://policy",
      checkedAt: now
    )
  }

  private func xSensitiveMediaStatus(
    _ snapshot: XAccountPlatformControlsSnapshot?,
    now: Date
  ) -> PlatformControlItem {
    guard let snapshot else {
      return PlatformControlItem(
        id: .xSensitiveMedia,
        title: "X sensitive media setting",
        detail: "Open X Content you see settings while connected so QuietGate can audit whether sensitive media display is off.",
        state: .checkInBrowser,
        actionTitle: "Open X Settings",
        actionURLString: "https://x.com/settings/content_you_see",
        checkedAt: nil
      )
    }
    let display = snapshot.displaySensitiveMedia
    return PlatformControlItem(
      id: .xSensitiveMedia,
      title: "X sensitive media setting",
      detail: detail(
        known: display,
        goodWhen: false,
        enabledText: "X is configured not to display media that it labels sensitive.",
        actionText: "X is currently allowed to display media that it labels sensitive.",
        unknownText: "QuietGate saw X settings, but could not read the sensitive media toggle."
      ),
      state: state(known: display, goodWhen: false),
      actionTitle: "Open X Settings",
      actionURLString: "https://x.com/settings/content_you_see",
      checkedAt: snapshot.checkedAt ?? now
    )
  }

  private func xSensitiveSearchStatus(
    _ snapshot: XAccountPlatformControlsSnapshot?,
    now: Date
  ) -> PlatformControlItem {
    guard let snapshot else {
      return PlatformControlItem(
        id: .xSensitiveSearch,
        title: "X sensitive search setting",
        detail: "Open X Search settings while connected so QuietGate can audit whether sensitive search results are hidden.",
        state: .checkInBrowser,
        actionTitle: "Open X Search",
        actionURLString: "https://x.com/settings/search",
        checkedAt: nil
      )
    }
    let hide = snapshot.hideSensitiveSearch
    return PlatformControlItem(
      id: .xSensitiveSearch,
      title: "X sensitive search setting",
      detail: detail(
        known: hide,
        goodWhen: true,
        enabledText: "X is configured to hide sensitive content in search.",
        actionText: "X search may show sensitive results.",
        unknownText: "QuietGate saw X settings, but could not read the search sensitive-content toggle."
      ),
      state: state(known: hide, goodWhen: true),
      actionTitle: "Open X Search",
      actionURLString: "https://x.com/settings/search",
      checkedAt: snapshot.checkedAt ?? now
    )
  }

  private func redditMatureContentStatus(
    _ snapshot: RedditAccountPlatformControlsSnapshot?,
    now: Date
  ) -> PlatformControlItem {
    guard let snapshot else {
      return PlatformControlItem(
        id: .redditMatureContent,
        title: "Reddit mature content setting",
        detail: "Open Reddit preferences while connected so QuietGate can audit whether mature content is hidden.",
        state: .checkInBrowser,
        actionTitle: "Open Reddit Settings",
        actionURLString: "https://www.reddit.com/settings/preferences",
        checkedAt: nil
      )
    }
    let show = snapshot.showMatureContent
    return PlatformControlItem(
      id: .redditMatureContent,
      title: "Reddit mature content setting",
      detail: detail(
        known: show,
        goodWhen: false,
        enabledText: "Reddit is configured not to show mature content.",
        actionText: "Reddit is currently allowed to show mature content.",
        unknownText: "QuietGate saw Reddit settings, but could not read the mature-content toggle."
      ),
      state: state(known: show, goodWhen: false),
      actionTitle: "Open Reddit Settings",
      actionURLString: "https://www.reddit.com/settings/preferences",
      checkedAt: snapshot.checkedAt ?? now
    )
  }

  private func redditBlurMatureMediaStatus(
    _ snapshot: RedditAccountPlatformControlsSnapshot?,
    now: Date
  ) -> PlatformControlItem {
    guard let snapshot else {
      return PlatformControlItem(
        id: .redditBlurMatureMedia,
        title: "Reddit mature media blur",
        detail: "Open Reddit preferences while connected so QuietGate can audit whether mature media is blurred.",
        state: .checkInBrowser,
        actionTitle: "Open Reddit Settings",
        actionURLString: "https://www.reddit.com/settings/preferences",
        checkedAt: nil
      )
    }
    let blur = snapshot.blurMatureMedia
    return PlatformControlItem(
      id: .redditBlurMatureMedia,
      title: "Reddit mature media blur",
      detail: detail(
        known: blur,
        goodWhen: true,
        enabledText: "Reddit is configured to blur mature media.",
        actionText: "Reddit mature media blur is off.",
        unknownText: "QuietGate saw Reddit settings, but could not read the mature media blur toggle."
      ),
      state: state(known: blur, goodWhen: true),
      actionTitle: "Open Reddit Settings",
      actionURLString: "https://www.reddit.com/settings/preferences",
      checkedAt: snapshot.checkedAt ?? now
    )
  }

  private func quietGateTunerStatus(quietGateTunersReady: Bool, now: Date) -> PlatformControlItem {
    PlatformControlItem(
      id: .quietGateTuners,
      title: "QuietGate browser tuners",
      detail: quietGateTunersReady
        ? "QuietGate browser tuning is connected. Built-in controls are additive."
        : "Connect a browser so QuietGate tuners can cover unlabeled and dynamic content.",
      state: quietGateTunersReady ? .enabled : .needsAction,
      actionTitle: nil,
      actionURLString: nil,
      checkedAt: now
    )
  }

  private func hostsForcesSafeSearch() -> Bool {
    let text = hostsTextProvider()?.lowercased() ?? ""
    guard text.contains("forcesafesearch.google.com") else {
      return false
    }
    return text.contains("www.google.")
  }

  private func booleanPolicy(_ key: String) -> Bool? {
    let value = chromePolicyReader.value(for: key)
    if let bool = value as? Bool {
      return bool
    }
    if let number = value as? NSNumber {
      return number.boolValue
    }
    if let string = value as? String {
      switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
      case "1", "true", "yes":
        return true
      case "0", "false", "no":
        return false
      default:
        return nil
      }
    }
    return nil
  }

  private func state(known: Bool?, goodWhen: Bool) -> PlatformControlState {
    guard let known else {
      return .unknown
    }
    return known == goodWhen ? .enabled : .needsAction
  }

  private func detail(
    known: Bool?,
    goodWhen: Bool,
    enabledText: String,
    actionText: String,
    unknownText: String
  ) -> String {
    guard let known else {
      return unknownText
    }
    return known == goodWhen ? enabledText : actionText
  }
}
