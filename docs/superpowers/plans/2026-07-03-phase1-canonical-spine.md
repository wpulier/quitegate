# Phase 1 — Canonical Spine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the single shared data spine for the connect + tune redesign — one `ConnectionStatus` model and one `TuningCatalog` — and route the existing policy/preset code through them, so every surface answers "connected?" and "what does Focus mean?" identically. No UI changes.

**Architecture:** Add two pure, dependency-free Swift files to the *shared* source set (compiled into both the macOS `QuietGate` app and the iOS `Tortoise` app, plus the two iOS extensions that need the catalog). Then repoint the existing duplicated definitions (`TortoisePolicy.browserFeatureKeys`, `focusBrowserFeatureKeys`, mode presets in `AccessMode` and `SafariExtensionPolicy`) at the catalog, and delete the now-dead local-only write branch in `MacAccountStore`. This is spec §4 + §9.1 item 1. Views, the Add flow, and the Tune UI are out of scope (Phases 2–3).

**Tech Stack:** Swift 5, SwiftUI apps, XCTest, XcodeGen (`project.yml`), Clerk + Supabase-backed policy.

## Global Constraints

- Tests are a macOS XCTest bundle `QuietGateTests`, hosted by `QuietGate.app` (`@testable import QuietGate`). There is **no iOS unit-test target** — iOS-only types (e.g. `SafariExtensionPolicy` in `Tortoise/IOSEnforcementShared.swift`) cannot be unit-tested; verify them by (a) testing the shared catalog they derive from and (b) an iOS build.
- Shared model files must compile into **both** `QuietGate` (macOS) and `Tortoise` (iOS) targets. The `Tortoise` target includes the whole `Tortoise/` folder automatically; the `QuietGate` target lists shared files individually under `sources:` as `type: file`.
- After adding or removing any source file, regenerate the project: `xcodegen generate --spec project.yml --project .`
- Run macOS tests: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
- Verify iOS compiles (for tasks touching `Tortoise/` shared or extension code): `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
- Product name is **Tortoise** (rename in progress). Do not introduce new `QuietGate`-prefixed user-facing strings.

## Intentional behavior changes in this phase (call out in review)

1. **iOS Safari "Open" no longer force-enables `youtubeUsageTracking`.** Today `SafariExtensionPolicy.openFeatures` sets it `true`; the unified catalog "open" set turns every feature off, matching macOS `AccessMode.open` and the README ("Open: rules off"). Usage tracking returns whenever the mode is Focus/Strict (both include it).
2. **"Focus" becomes one definition everywhere** = the 13-feature set currently in `AccessMode.focus.tuningFeatures`. This changes `TortoisePolicy.focusBrowserFeatureKeys` (was 10) and `SafariExtensionPolicy.focusFeatures` (was a different 15) to match it.
3. **iOS Safari policy now carries all 42 feature flags** (was 40; adds `instagramProfileSuggestions`, `instagramNotifications`). The Safari content script ignores flags it doesn't implement, so this is safe; per-surface enforcement honesty is Phase 3.

---

### Task 1: `ConnectionStatus` shared model + resolver

**Files:**
- Create: `Tortoise/ConnectionStatus.swift`
- Modify: `project.yml` (add the file to the `QuietGate` target's `sources:`)
- Test: `QuietGateTests/ConnectionStatusTests.swift`

**Interfaces:**
- Produces: `enum TuningSurface: String, CaseIterable, Codable { case chromeExtension, firefoxExtension, iosSafari, iosScreenTime }`
- Produces: `enum ConnectionStatus: Equatable { case on; case attention(AttentionReason); case off }`
- Produces: `enum AttentionReason: Equatable { case setupIncomplete, stale, catchingUp }`
- Produces: `enum ConnectionFreshness { static let freshWindow: TimeInterval }`
- Produces: `ConnectionStatus.resolve(lastSeenAt: Date?, isEnforcingLatestPolicy: Bool, isPausedByUser: Bool, now: Date) -> ConnectionStatus`

- [ ] **Step 1: Create the model file**

Create `Tortoise/ConnectionStatus.swift`:

```swift
import Foundation

/// A surface that can enforce tuning. Used to describe where a feature actually applies.
enum TuningSurface: String, CaseIterable, Codable {
  case chromeExtension
  case firefoxExtension
  case iosSafari
  case iosScreenTime
}

/// The single, canonical connection state for any device or browser profile.
/// Replaces the scattered per-subsystem status enums (introduced here; the old
/// enums are removed in Phase 5).
enum ConnectionStatus: Equatable {
  case on
  case attention(AttentionReason)
  case off
}

/// The one concrete step left when a connection needs attention.
enum AttentionReason: Equatable {
  case setupIncomplete  // never checked in / connect not finished
  case stale            // checked in before, but not within the freshness window
  case catchingUp       // reachable, but not yet applying the latest policy
}

enum ConnectionFreshness {
  /// The single freshness window used everywhere. A device not seen within this
  /// window is never shown as "On".
  static let freshWindow: TimeInterval = 15 * 60
}

extension ConnectionStatus {
  /// The one place a connection's state is decided. Pure and time-injectable.
  static func resolve(
    lastSeenAt: Date?,
    isEnforcingLatestPolicy: Bool,
    isPausedByUser: Bool,
    now: Date
  ) -> ConnectionStatus {
    if isPausedByUser {
      return .off
    }
    guard let lastSeenAt else {
      return .attention(.setupIncomplete)
    }
    if now.timeIntervalSince(lastSeenAt) > ConnectionFreshness.freshWindow {
      return .attention(.stale)
    }
    if !isEnforcingLatestPolicy {
      return .attention(.catchingUp)
    }
    return .on
  }
}
```

- [ ] **Step 2: Add the file to the macOS target in `project.yml`**

In `project.yml`, under `targets: QuietGate: sources:`, add another `type: file` entry next to the existing shared files:

```yaml
      - path: Tortoise/TortoiseModels.swift
        type: file
      - path: Tortoise/ConnectionStatus.swift
        type: file
```

(The `Tortoise` iOS target already includes it via the `- Tortoise` folder entry.)

- [ ] **Step 3: Regenerate the project**

Run: `xcodegen generate --spec project.yml --project .`
Expected: `Created project at .../QuietGate.xcodeproj`

- [ ] **Step 4: Write the failing tests**

Create `QuietGateTests/ConnectionStatusTests.swift`:

```swift
import XCTest
@testable import QuietGate

final class ConnectionStatusTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_000_000)

  func testPausedIsOff() {
    let status = ConnectionStatus.resolve(
      lastSeenAt: now, isEnforcingLatestPolicy: true, isPausedByUser: true, now: now
    )
    XCTAssertEqual(status, .off)
  }

  func testNeverSeenIsSetupIncomplete() {
    let status = ConnectionStatus.resolve(
      lastSeenAt: nil, isEnforcingLatestPolicy: true, isPausedByUser: false, now: now
    )
    XCTAssertEqual(status, .attention(.setupIncomplete))
  }

  func testBeyondFreshWindowIsStale() {
    let old = now.addingTimeInterval(-(ConnectionFreshness.freshWindow + 1))
    let status = ConnectionStatus.resolve(
      lastSeenAt: old, isEnforcingLatestPolicy: true, isPausedByUser: false, now: now
    )
    XCTAssertEqual(status, .attention(.stale))
  }

  func testFreshButNotEnforcingIsCatchingUp() {
    let recent = now.addingTimeInterval(-60)
    let status = ConnectionStatus.resolve(
      lastSeenAt: recent, isEnforcingLatestPolicy: false, isPausedByUser: false, now: now
    )
    XCTAssertEqual(status, .attention(.catchingUp))
  }

  func testFreshAndEnforcingIsOn() {
    let recent = now.addingTimeInterval(-60)
    let status = ConnectionStatus.resolve(
      lastSeenAt: recent, isEnforcingLatestPolicy: true, isPausedByUser: false, now: now
    )
    XCTAssertEqual(status, .on)
  }
}
```

- [ ] **Step 5: Run the tests**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
Expected: `ConnectionStatusTests` — 5 tests PASS. (They pass immediately because Step 1 wrote the implementation; this task's value is the model + its regression tests.)

- [ ] **Step 6: Verify iOS still compiles**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 7: Commit**

```bash
git add Tortoise/ConnectionStatus.swift project.yml QuietGate.xcodeproj QuietGateTests/ConnectionStatusTests.swift
git commit -m "Add shared ConnectionStatus model + resolver"
```

---

### Task 2: `TuningCatalog` shared model

**Files:**
- Create: `Tortoise/TuningCatalog.swift`
- Modify: `project.yml` (add the file to the `QuietGate` target's `sources:`)
- Test: `QuietGateTests/TuningCatalogTests.swift`

**Interfaces:**
- Consumes: `TuningSurface` (Task 1).
- Produces: `enum TuningCatalog` with:
  - `struct Site { let id: String; let title: String; let brandAssetName: String; let featureIDs: [String] }`
  - `struct Feature { let id: String; let siteID: String; let enforceableOn: Set<TuningSurface> }`
  - `static let sites: [Site]`
  - `static let features: [Feature]`
  - `static let allFeatureIDs: [String]`
  - `static let openFeatureIDs: Set<String>`
  - `static let focusFeatureIDs: Set<String>`
  - `static var strictFeatureIDs: Set<String>`
  - `static func enabledFeatureFlags(for mode: String) -> [String: Bool]`
  - `static func siteID(forFeatureID id: String) -> String?`

- [ ] **Step 1: Create the catalog file**

Create `Tortoise/TuningCatalog.swift`. Feature id arrays must match `BrowserTuningFeature` case order exactly (verified against `QuietGate/Models/BrowserTuningFeature.swift`):

```swift
import Foundation

/// The single source of truth for tunable sites and features: ids, the site that
/// owns each, where each can be enforced, and what each mode preset turns on.
/// Shared by macOS, iOS, and iOS Safari enforcement.
enum TuningCatalog {
  struct Site {
    let id: String
    let title: String
    let brandAssetName: String
    let featureIDs: [String]
  }

  struct Feature {
    let id: String
    let siteID: String
    let enforceableOn: Set<TuningSurface>
  }

  private static let youtubeFeatureIDs = [
    "youtubeHome", "youtubeVideoSidebar", "youtubeRecommendations", "youtubeLiveChat",
    "youtubePlaylists", "youtubeFundraisers", "youtubeEndScreens", "youtubeEndScreenCards",
    "youtubeShorts", "youtubeComments", "youtubeMixes", "youtubeMerch", "youtubeVideoInfo",
    "youtubeTopHeader", "youtubeNotifications", "youtubeSearch", "youtubeExplore",
    "youtubeMoreFromYouTube", "youtubeSubscriptions", "youtubeAutoplay", "youtubeAnnotations",
    "youtubeUsageTracking", "youtubeDailyLimit",
  ]
  private static let xFeatureIDs = [
    "xSensitiveMedia", "xExplicitContent", "xExplicitSearch",
    "xVideos", "xPhotos", "xMediaCards", "xExploreTrends",
  ]
  private static let instagramFeatureIDs = [
    "instagramReels", "instagramExplore", "instagramSuggested", "instagramProfileSuggestions",
    "instagramMessages", "instagramNotifications", "instagramStories",
  ]
  private static let redditFeatureIDs = [
    "redditPopularAll", "redditRecommendations", "redditNSFW", "redditMedia", "redditSidebars",
  ]

  static let sites: [Site] = [
    Site(id: "youtube", title: "YouTube", brandAssetName: "BrandYouTube", featureIDs: youtubeFeatureIDs),
    Site(id: "x", title: "X", brandAssetName: "BrandX", featureIDs: xFeatureIDs),
    Site(id: "instagram", title: "Instagram", brandAssetName: "BrandInstagram", featureIDs: instagramFeatureIDs),
    Site(id: "reddit", title: "Reddit", brandAssetName: "BrandReddit", featureIDs: redditFeatureIDs),
  ]

  static let allFeatureIDs: [String] = sites.flatMap(\.featureIDs)

  /// Features the iOS Safari web extension can currently apply (all except two
  /// Instagram surfaces it has no hook for). Used for Phase 3 enforcement honesty.
  private static let iosSafariFeatureIDs: Set<String> = Set(allFeatureIDs)
    .subtracting(["instagramProfileSuggestions", "instagramNotifications"])

  /// Features enforced by iOS Screen Time rather than a content script.
  private static let iosScreenTimeFeatureIDs: Set<String> = ["youtubeDailyLimit"]

  static let features: [Feature] = sites.flatMap { site in
    site.featureIDs.map { id -> Feature in
      var surfaces: Set<TuningSurface> = [.chromeExtension, .firefoxExtension]
      if iosSafariFeatureIDs.contains(id) { surfaces.insert(.iosSafari) }
      if iosScreenTimeFeatureIDs.contains(id) { surfaces.insert(.iosScreenTime) }
      return Feature(id: id, siteID: site.id, enforceableOn: surfaces)
    }
  }

  static let openFeatureIDs: Set<String> = []

  static let focusFeatureIDs: Set<String> = [
    "youtubeHome", "youtubeShorts", "youtubeUsageTracking",
    "xSensitiveMedia", "xVideos",
    "instagramReels", "instagramExplore", "instagramSuggested", "instagramProfileSuggestions",
    "instagramMessages", "instagramNotifications",
    "redditPopularAll", "redditRecommendations",
  ]

  static var strictFeatureIDs: Set<String> { Set(allFeatureIDs) }

  /// A full flag map (every feature id → on/off) for a mode string.
  static func enabledFeatureFlags(for mode: String) -> [String: Bool] {
    let on: Set<String>
    switch mode {
    case "strict": on = strictFeatureIDs
    case "focus": on = focusFeatureIDs
    default: on = openFeatureIDs
    }
    return Dictionary(uniqueKeysWithValues: allFeatureIDs.map { ($0, on.contains($0)) })
  }

  static func siteID(forFeatureID id: String) -> String? {
    features.first { $0.id == id }?.siteID
  }
}
```

- [ ] **Step 2: Add the file to the macOS target in `project.yml`**

Under `targets: QuietGate: sources:`, add:

```yaml
      - path: Tortoise/TuningCatalog.swift
        type: file
```

- [ ] **Step 3: Regenerate the project**

Run: `xcodegen generate --spec project.yml --project .`
Expected: `Created project at .../QuietGate.xcodeproj`

- [ ] **Step 4: Write the failing tests**

Create `QuietGateTests/TuningCatalogTests.swift`:

```swift
import XCTest
@testable import QuietGate

final class TuningCatalogTests: XCTestCase {
  func testCatalogHasEveryFeatureExactlyOnceInEnumOrder() {
    XCTAssertEqual(TuningCatalog.allFeatureIDs, BrowserTuningFeature.allCases.map(\.rawValue))
    XCTAssertEqual(Set(TuningCatalog.allFeatureIDs).count, TuningCatalog.allFeatureIDs.count)
    XCTAssertEqual(TuningCatalog.allFeatureIDs.count, 42)
  }

  func testEveryFeatureMapsToAKnownSite() {
    let siteIDs = Set(TuningCatalog.sites.map(\.id))
    for feature in TuningCatalog.features {
      XCTAssertTrue(siteIDs.contains(feature.siteID), "\(feature.id) has unknown site \(feature.siteID)")
    }
  }

  func testSiteFeatureIDsUnionEqualsAllFeatureIDs() {
    XCTAssertEqual(TuningCatalog.sites.flatMap(\.featureIDs), TuningCatalog.allFeatureIDs)
  }

  func testWebFeaturesAreAllEnforceableInChromeAndFirefox() {
    for feature in TuningCatalog.features {
      XCTAssertTrue(feature.enforceableOn.contains(.chromeExtension), "\(feature.id)")
      XCTAssertTrue(feature.enforceableOn.contains(.firefoxExtension), "\(feature.id)")
    }
  }

  func testModeFlagMapsCoverEveryFeature() {
    for mode in ["open", "focus", "strict"] {
      XCTAssertEqual(Set(TuningCatalog.enabledFeatureFlags(for: mode).keys), Set(TuningCatalog.allFeatureIDs))
    }
    XCTAssertTrue(TuningCatalog.enabledFeatureFlags(for: "open").values.allSatisfy { $0 == false })
    XCTAssertTrue(TuningCatalog.enabledFeatureFlags(for: "strict").values.allSatisfy { $0 == true })
  }
}
```

- [ ] **Step 5: Run the tests**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
Expected: `TuningCatalogTests` — 5 tests PASS. If `testCatalogHasEveryFeatureExactlyOnceInEnumOrder` fails, the id arrays don't match `BrowserTuningFeature` order — fix the arrays, not the test.

- [ ] **Step 6: Verify iOS still compiles**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 7: Commit**

```bash
git add Tortoise/TuningCatalog.swift project.yml QuietGate.xcodeproj QuietGateTests/TuningCatalogTests.swift
git commit -m "Add shared TuningCatalog (single site/feature source of truth)"
```

---

### Task 3: Route `TortoisePolicy` through the catalog (fixes the Instagram desync)

**Files:**
- Modify: `Tortoise/TortoiseModels.swift:72-126` (the `browserFeatureKeys`, `focusBrowserFeatureKeys`, `defaultFeatures(for:)` definitions)
- Test: `QuietGateTests/TortoisePolicyCatalogTests.swift`

**Interfaces:**
- Consumes: `TuningCatalog.allFeatureIDs`, `TuningCatalog.focusFeatureIDs`, `TuningCatalog.enabledFeatureFlags(for:)` (Task 2).
- Produces: unchanged public shapes — `TortoisePolicy.browserFeatureKeys: [String]`, `TortoisePolicy.focusBrowserFeatureKeys: Set<String>`, `TortoisePolicy.settingBrowserFeature(_:enabled:)`, `TortoisePolicy.settingMode(_:)`. Now `browserFeatureKeys` contains all 42 ids, so `ProtectionStore.accountSupportedBrowserFeatures` (which derives from it) and `accountPolicySnapshot` (which iterates it) automatically stop dropping `instagramProfileSuggestions` / `instagramMessages` / `instagramNotifications`.

- [ ] **Step 1: Write the failing test**

Create `QuietGateTests/TortoisePolicyCatalogTests.swift`:

```swift
import XCTest
@testable import QuietGate

final class TortoisePolicyCatalogTests: XCTestCase {
  func testBrowserFeatureKeysEqualsCatalog() {
    XCTAssertEqual(TortoisePolicy.browserFeatureKeys, TuningCatalog.allFeatureIDs)
  }

  func testEveryTuningFeatureIsABrowserFeatureKey() {
    let keys = Set(TortoisePolicy.browserFeatureKeys)
    for feature in BrowserTuningFeature.allCases {
      XCTAssertTrue(keys.contains(feature.rawValue), "\(feature.rawValue) missing from browserFeatureKeys")
    }
  }

  func testPreviouslyDroppedInstagramFeatureNowPersists() {
    // instagramMessages was absent from the 39-key list and silently dropped.
    let base = TortoisePolicy.open
    let updated = base.settingBrowserFeature("instagramMessages", enabled: true)
    XCTAssertEqual(updated.browser?.features["instagramMessages"], true)
  }

  func testFocusKeysMatchCatalog() {
    XCTAssertEqual(TortoisePolicy.focusBrowserFeatureKeys, TuningCatalog.focusFeatureIDs)
  }
}
```

Note: this test references `TortoisePolicy.open`, a small fixture added in Step 2 so tests can build a base policy without the network layer.

- [ ] **Step 2: Repoint the definitions at the catalog**

In `Tortoise/TortoiseModels.swift`, replace the `browserFeatureKeys` array literal (lines 73-113) and the `focusBrowserFeatureKeys` literal (lines 115-126) with catalog-derived values, and replace the body of `defaultFeatures(for:)` (lines 209-218):

```swift
extension TortoisePolicy {
  static var browserFeatureKeys: [String] { TuningCatalog.allFeatureIDs }

  static var focusBrowserFeatureKeys: Set<String> { TuningCatalog.focusFeatureIDs }
```

Replace `private static func defaultFeatures(for mode: String) -> [String: Bool] { ... }` with:

```swift
  private static func defaultFeatures(for mode: String) -> [String: Bool] {
    TuningCatalog.enabledFeatureFlags(for: mode)
  }
```

- [ ] **Step 3: Add the `open` test fixture**

Still in `Tortoise/TortoiseModels.swift`, add to the `extension TortoisePolicy` block:

```swift
  /// A blank baseline policy (Open mode, no features) for tests and first-run.
  static var open: TortoisePolicy {
    TortoisePolicy(
      schemaVersion: 1,
      mode: "open",
      adultBlockingEnabled: false,
      browser: BrowserPolicy(
        features: TuningCatalog.enabledFeatureFlags(for: "open"),
        blockedDomains: [],
        blockedCategories: [],
        options: BrowserPolicyOptions(explicitHideStyle: "post", youtubeDailyLimitMinutes: 30)
      ),
      schedules: SchedulePolicy(enabled: false, dailyFocusWindows: []),
      applications: ApplicationsPolicy(enforcementEnabled: true, blocked: [], allowed: [])
    )
  }
```

- [ ] **Step 4: Run the tests**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
Expected: `TortoisePolicyCatalogTests` — 4 tests PASS. All pre-existing tests still PASS.

- [ ] **Step 5: Verify iOS still compiles**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 6: Commit**

```bash
git add Tortoise/TortoiseModels.swift QuietGateTests/TortoisePolicyCatalogTests.swift
git commit -m "Derive TortoisePolicy feature keys + presets from TuningCatalog"
```

---

### Task 4: Unify the `AccessMode` and `SafariExtensionPolicy` presets on the catalog

**Files:**
- Modify: `QuietGate/Models/AccessMode.swift:54-69` (the `tuningFeatures` computed property)
- Modify: `Tortoise/IOSEnforcementShared.swift:181-252` (the `openFeatures` / `focusFeatures` / `strictFeatures` definitions)
- Modify: `project.yml` (add `TuningCatalog.swift` + `ConnectionStatus.swift` to the two iOS extension targets that compile `IOSEnforcementShared.swift`)
- Test: `QuietGateTests/PresetUnificationTests.swift`

**Interfaces:**
- Consumes: `TuningCatalog.focusFeatureIDs`, `TuningCatalog.enabledFeatureFlags(for:)`, `BrowserTuningFeature` (Task 2/3).
- Produces: `AccessMode.tuningFeatures` unchanged type (`[BrowserTuningFeature]`); `SafariExtensionPolicy.policy(for:...)` unchanged signature, now catalog-driven feature dict.

- [ ] **Step 1: Write the failing test (macOS-visible parity)**

Create `QuietGateTests/PresetUnificationTests.swift`:

```swift
import XCTest
@testable import QuietGate

final class PresetUnificationTests: XCTestCase {
  func testAccessModeFocusMatchesCatalog() {
    XCTAssertEqual(Set(AccessMode.focus.tuningFeatures.map(\.rawValue)), TuningCatalog.focusFeatureIDs)
  }

  func testAccessModeStrictIsEveryFeature() {
    XCTAssertEqual(AccessMode.strict.tuningFeatures, BrowserTuningFeature.allCases)
  }

  func testAccessModeOpenIsEmpty() {
    XCTAssertTrue(AccessMode.open.tuningFeatures.isEmpty)
  }

  func testPolicyFocusFlagsMatchCatalog() {
    let focusOn = TortoisePolicy.open.settingMode("focus").browser?.features
      .filter { $0.value }.keys.sorted()
    XCTAssertEqual(Set(focusOn ?? []), TuningCatalog.focusFeatureIDs)
  }
}
```

- [ ] **Step 2: Repoint `AccessMode.tuningFeatures` at the catalog**

In `QuietGate/Models/AccessMode.swift`, replace the `focus` case of `tuningFeatures` so the set comes from the catalog while preserving enum order (keeps the existing `AccessModeTests` order assertion green):

```swift
  var tuningFeatures: [BrowserTuningFeature] {
    switch self {
    case .open:
      return []
    case .focus:
      return BrowserTuningFeature.allCases.filter { TuningCatalog.focusFeatureIDs.contains($0.rawValue) }
    case .strict:
      return BrowserTuningFeature.allCases
    }
  }
```

- [ ] **Step 3: Repoint `SafariExtensionPolicy` feature sets at the catalog**

In `Tortoise/IOSEnforcementShared.swift`, replace the `openFeatures` stored property (lines 181-222), the `focusFeatures` computed property (lines 224-244), and the `strictFeatures` computed property (lines 246-252) with catalog-derived maps:

```swift
  private static var openFeatures: [String: Bool] { TuningCatalog.enabledFeatureFlags(for: "open") }
  private static var focusFeatures: [String: Bool] { TuningCatalog.enabledFeatureFlags(for: "focus") }
  private static var strictFeatures: [String: Bool] { TuningCatalog.enabledFeatureFlags(for: "strict") }
```

(The `SafariExtensionPolicy.open` static and `policy(for:...)` keep working unchanged — they read these three properties.)

- [ ] **Step 4: Make the catalog available to the iOS extension targets**

`IOSEnforcementShared.swift` is compiled into `TortoiseDeviceActivityMonitor` and `TortoiseSafariExtension`; both now reference `TuningCatalog`, and `TuningCatalog` references `TuningSurface` (in `ConnectionStatus.swift`). In `project.yml`, add both files to each of those two targets' `sources:`:

```yaml
  TortoiseDeviceActivityMonitor:
    ...
    sources:
      - TortoiseDeviceActivityMonitor
      - path: Tortoise/IOSEnforcementShared.swift
        type: file
      - path: Tortoise/ConnectionStatus.swift
        type: file
      - path: Tortoise/TuningCatalog.swift
        type: file
```

```yaml
  TortoiseSafariExtension:
    ...
    sources:
      - TortoiseSafariExtension
      - path: Tortoise/IOSEnforcementShared.swift
        type: file
      - path: Tortoise/ConnectionStatus.swift
        type: file
      - path: Tortoise/TuningCatalog.swift
        type: file
```

- [ ] **Step 5: Regenerate the project**

Run: `xcodegen generate --spec project.yml --project .`
Expected: `Created project at .../QuietGate.xcodeproj`

- [ ] **Step 6: Run the macOS tests**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
Expected: `PresetUnificationTests` — 4 tests PASS; existing `AccessModeTests` — 4 tests still PASS.

- [ ] **Step 7: Verify iOS + extensions compile**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
Expected: `BUILD SUCCEEDED` (this also builds the embedded `TortoiseDeviceActivityMonitor` and `TortoiseSafariExtension` targets).

- [ ] **Step 8: Commit**

```bash
git add QuietGate/Models/AccessMode.swift Tortoise/IOSEnforcementShared.swift project.yml QuietGate.xcodeproj QuietGateTests/PresetUnificationTests.swift
git commit -m "Unify AccessMode + Safari presets on TuningCatalog"
```

---

### Task 5: Delete the dead local-only write branch in `MacAccountStore`

**Files:**
- Modify: `QuietGate/Services/MacAccountStore.swift:279-323` (`setTuningFeature` / `setTuningFeatures`)
- Test: `QuietGateTests/TuningSyncInvariantTests.swift`

**Interfaces:**
- Consumes: `TortoisePolicy.browserFeatureKeys` (now all 42, Task 3).
- Produces: `MacAccountStore.setTuningFeature(_:enabled:using:protectionStore:appBlockingStore:)` and `setTuningFeatures(...)` unchanged signatures; both now always route through `updatePolicy` (the account/cloud writer), never the local-only `protectionStore.setTuningFeature` fallback.

- [ ] **Step 1: Write the invariant regression test**

The removal is safe only while every feature is a `browserFeatureKey`. Lock that invariant so no future feature can silently reintroduce a local-only path. Create `QuietGateTests/TuningSyncInvariantTests.swift`:

```swift
import XCTest
@testable import QuietGate

final class TuningSyncInvariantTests: XCTestCase {
  // Guards the Task 5 removal: if any BrowserTuningFeature stops being a
  // browserFeatureKey, MacAccountStore could silently drop it locally again.
  func testEveryTuningFeatureSyncsThroughThePolicy() {
    let keys = Set(TortoisePolicy.browserFeatureKeys)
    for feature in BrowserTuningFeature.allCases {
      XCTAssertTrue(keys.contains(feature.rawValue), "\(feature.rawValue) would not sync to the account")
    }
  }
}
```

- [ ] **Step 2: Run it to confirm it passes (invariant already holds after Task 3)**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test -only-testing:QuietGateTests/TuningSyncInvariantTests`
Expected: 1 test PASS.

- [ ] **Step 3: Remove the dead branches**

In `QuietGate/Services/MacAccountStore.swift`, replace `setTuningFeature` (lines 279-298) and `setTuningFeatures` (lines 300-323) with versions that drop the now-always-false guard:

```swift
  func setTuningFeature(
    _ feature: BrowserTuningFeature,
    enabled: Bool,
    using clerk: Clerk,
    protectionStore: ProtectionStore,
    appBlockingStore: AppBlockingStore
  ) async {
    await updatePolicy(
      using: clerk,
      protectionStore: protectionStore,
      appBlockingStore: appBlockingStore
    ) { policy in
      policy.settingBrowserFeature(feature.rawValue, enabled: enabled)
    }
  }

  func setTuningFeatures(
    _ features: [BrowserTuningFeature],
    enabled: Bool,
    using clerk: Clerk,
    protectionStore: ProtectionStore,
    appBlockingStore: AppBlockingStore
  ) async {
    await updatePolicy(
      using: clerk,
      protectionStore: protectionStore,
      appBlockingStore: appBlockingStore
    ) { policy in
      policy.settingBrowserFeatures(features.map(\.rawValue), enabled: enabled)
    }
  }
```

- [ ] **Step 4: Run the full test suite**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
Expected: all tests PASS (including `TuningSyncInvariantTests`), `BUILD SUCCEEDED`.

- [ ] **Step 5: Verify iOS still compiles**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 6: Commit**

```bash
git add QuietGate/Services/MacAccountStore.swift QuietGateTests/TuningSyncInvariantTests.swift
git commit -m "Route all Mac tuning writes through the account policy"
```

---

## Self-Review

**Spec coverage (spec §4 + §9.1 item 1):**
- §4.1 one connection status + single freshness rule → Task 1. ✓ (Old enums intentionally left for Phase 5 cleanup, per scope.)
- §4.2 one site/feature catalog with per-surface enforceability → Task 2. ✓
- §4.2 reconcile `browserFeatureKeys` (39→42) → Task 3 (transitively fixes `ProtectionStore.accountSupportedBrowserFeatures` + `accountPolicySnapshot`, which derive from it). ✓
- §4.3 modes derive from the catalog; "focus" identical everywhere → Tasks 3 (TortoisePolicy) + 4 (AccessMode, SafariExtensionPolicy). ✓
- §7 cloud policy is the only writer (delete local-only Mac branch) → Task 5. ✓

**Placeholder scan:** No TBD/TODO. Every code step shows complete code. iOS-untestable `SafariExtensionPolicy` is covered by (a) the macOS-visible catalog tests and (b) an explicit iOS build step — noted in Global Constraints, not a placeholder.

**Type consistency:** `TuningSurface`, `ConnectionStatus`, `AttentionReason`, `ConnectionFreshness.freshWindow`, `TuningCatalog.{sites,features,allFeatureIDs,openFeatureIDs,focusFeatureIDs,strictFeatureIDs,enabledFeatureFlags(for:),siteID(forFeatureID:)}`, `TortoisePolicy.{browserFeatureKeys,focusBrowserFeatureKeys,open,settingBrowserFeature,settingMode}`, `AccessMode.tuningFeatures`, `SafariExtensionPolicy.{openFeatures,focusFeatures,strictFeatures,policy(for:...)}` are used consistently across tasks with matching signatures. `browserFeatureKeys` changes from `let [String]` to `var [String]` (computed) — callers use it read-only, so source-compatible.

**Out of scope (correctly deferred):** removing the 7 legacy status enums (Phase 5); per-surface enforcement honesty in the UI (Phase 3); TikTok (Phase 4); any view/Add-flow/Tune-UI change (Phases 2–3).

## Follow-ups surfaced in the whole-branch review (for later phases)

The Phase 1 review passed with no Critical/Important findings. These deferred items must be carried forward so the "single source of truth" is truly complete:

1. **`NativeHost/QuietGateNativeHost.swift:11-53` holds a 4th, divergent copy of the feature list** (the old 39-key set, missing the 3 Instagram keys). It is structurally isolated (a standalone single-file `swiftc` build that cannot import the shared catalog without a build restructure) and functionally inert today (its `normalizedSettings` merge preserves the app's 42-key writes). **Phase 5:** generate/reconcile this dict against `TuningCatalog`, or add a smoke test asserting `defaultSettings["features"].keys == TuningCatalog.allFeatureIDs`.
2. **`BrowserTuningSite.title`/`brandAssetName` (`QuietGate/Models/BrowserTuningFeature.swift:3-90`) duplicate `TuningCatalog.sites`** with no drift guard. **Phase 2/3 (UI) or Phase 5:** collapse the site type into the catalog, or add a drift-guard test in the interim.
3. **`TuningCatalog.siteID(forFeatureID:)` currently has no production consumer** (foundation API for the Tune UI). Wired in Phase 2; leave as-is or add a one-line test.
