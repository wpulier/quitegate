# Phase 3a — Tune Sites (unified per-site tuning) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render the per-site Tune experience on Mac and iPhone from ONE shared, tested model driven by `TuningCatalog` + the cloud `TortoisePolicy` — mode selector + per-site quick state + tap-to-expand granular feature toggles (progressive disclosure) — replacing the two duplicate UI enums (`DesignTuningSite`, `MobileTuningSite`) and removing the fake TikTok stub (TikTok shown honestly as "coming soon" until its real tuner in Phase 4). Each feature toggle is labeled honestly per the catalog's per-surface enforceability.

**Architecture:** One shared, pure `TuneScreenModel` in `Tortoise/` maps `(TortoisePolicy?, TuningSurface)` → `[TuneSite]` (id, title, brand, enabled/total counts) and `[TuneFeature]` (id, title, detail, isOn, isEnforceable). Feature titles come from the existing `BrowserTuningFeature` (made available to iOS — it is pure Foundation), site metadata from `TuningCatalog.sites`. Both Tune screens render from this model; toggles write to the cloud policy through the existing store methods (`MacAccountStore.setTuningFeature`, `AccountHubModel.setBrowserFeature`).

**Tech Stack:** Swift 5, SwiftUI, XCTest, XcodeGen.

## Phase 3 decomposition

Phase 3 (Tune — verb 2) ships as three sub-plans:

- **3a — Tune sites** *(this plan)*: unify the per-site Tune screen on the catalog; mode selector; progressive disclosure; honest per-surface enforceability; remove the fake TikTok stub.
- **3b — Fold Blocking into Tune**: bring the "Blocking" concerns (adult sites, apps, websites, focus/locked sessions) under the one "Tune" umbrella (spec §3). Remove the fake iOS "concept blocking"; make iOS timed/locked sessions real (matching Mac's `startTimedSession`).
- **3c — Mac augment knobs**: wire the unused Mac augment knobs (`ProtectionStore.setExplicitHideStyle`, `setYouTubeDailyLimitMinutes`) into the Tune UI; fix the hardcoded "45m" daily-limit label. *(iOS Safari per-feature enforcement was pulled into 3a — see Task 4.)*

> **iOS Safari per-feature enforcement is IN 3a (Task 4).** The Safari app-group policy already carries a per-feature `features` map, and the Safari content scripts already apply it per-feature (`TortoiseSafariExtension/content/youtube.js` `applySettings()` reads `features[feature]`). The only gap is that `IOSYouTubeScreenTimeController.writeSafariPolicy` fills that map from the *mode preset* (`SafariExtensionPolicy.policy(for: mode)`) instead of the real `policy.browser.features`. Task 4 feeds the real features, so **every** iOS per-feature toggle actually enforces on the iPhone's own Safari — except the 2 Instagram features the extension has no hook for (`instagramProfileSuggestions`, `instagramNotifications`), which the catalog marks non-enforceable and 3a keeps disabled on iOS. No content-script change needed.

## Global Constraints

- Tests are a macOS XCTest bundle `QuietGateTests` (`@testable import QuietGate`). No iOS unit-test target — testable `TuneScreenModel` logic lives in shared `Tortoise/` files (compiled into the macOS `QuietGate` target); SwiftUI views are build-verified only.
- Shared files in `Tortoise/` compile into BOTH targets: the iOS `Tortoise` target auto-includes the folder; the `QuietGate` macOS target lists each new shared file under `sources:` as `type: file`.
- After adding a source file (or adding an existing file to a new target), regenerate: `xcodegen generate --spec project.yml --project .` (the generated `QuietGate.xcodeproj` is tracked in git — stage it).
- macOS tests: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
- iOS build: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
- Product name **Tortoise**; minimal on-screen text; real brand marks (`brandAssetName`); no fake/demo data; cloud policy is the single source of truth; a feature toggle is honest about where it enforces (via the catalog's `enforceableOn`).

## Available from earlier phases (committed)

- `Tortoise/TuningCatalog.swift`: `sites: [Site{id,title,brandAssetName,featureIDs}]`, `features: [Feature{id,siteID,enforceableOn: Set<TuningSurface>}]`, `allFeatureIDs`. Chrome/Firefox extensions enforce ALL features; iOS Safari enforces all except `instagramProfileSuggestions`/`instagramNotifications`; iOS Screen Time enforces `youtubeDailyLimit`.
- `TuningSurface { chromeExtension, firefoxExtension, iosSafari, iosScreenTime }` (`Tortoise/ConnectionStatus.swift`).
- `QuietGate/Models/BrowserTuningFeature.swift`: `enum BrowserTuningFeature: String, CaseIterable` (42 cases) with `var title: String` and `var detail: String` — pure Foundation. Currently in the macOS target only.
- `TortoisePolicy` (`Tortoise/TortoiseModels.swift`): `mode: String`, `browser?.features: [String: Bool]`, `settingMode(_:)`, `settingBrowserFeature(_:enabled:)`, `settingBrowserFeatures(_:enabled:)`.
- Write paths: Mac `MacAccountStore.setTuningFeature(_ f: BrowserTuningFeature, enabled:using:protectionStore:appBlockingStore:)` + `setTuningFeatures(...)` + `setAccessMode(_:...)`; iOS `AccountHubModel.setBrowserFeature(_ id: String, enabled:using:)` + `setBrowserFeatures(_:enabled:using:)` + `setPolicyMode(_:using:)`.

---

### Task 1: Shared `TuneScreenModel` (+ make `BrowserTuningFeature` available to iOS)

**Files:**
- Create: `Tortoise/TuneScreenModel.swift`
- Modify: `project.yml` (add `Tortoise/TuneScreenModel.swift` to the `QuietGate` macOS target `sources:` as `type: file`; add `QuietGate/Models/BrowserTuningFeature.swift` to the iOS `Tortoise` target `sources:` as `type: file`)
- Test: `QuietGateTests/TuneScreenModelTests.swift`

**Interfaces:**
- Produces: `struct TuneSite: Identifiable, Equatable { let id, title, brandAssetName: String; let enabledCount, totalCount: Int }`
- Produces: `struct TuneFeature: Identifiable, Equatable { let id, title, detail: String; let isOn, isEnforceable: Bool }`
- Produces: `enum TuneScreen { static func sites(policy: TortoisePolicy?, surface: TuningSurface) -> [TuneSite]; static func features(forSiteID: String, policy: TortoisePolicy?, surface: TuningSurface) -> [TuneFeature]; static func iosSafariEnforcedFeatures(policy: TortoisePolicy?) -> [String: Bool] }`

- [ ] **Step 1: Create the model file**

Create `Tortoise/TuneScreenModel.swift`:

```swift
import Foundation

/// One site row on the Tune screen (progressive disclosure: tap to expand into
/// its features). Sites come from the shared TuningCatalog, in catalog order.
struct TuneSite: Identifiable, Equatable {
  let id: String
  let title: String
  let brandAssetName: String
  let enabledCount: Int
  let totalCount: Int
}

/// One granular feature row inside an expanded site. `isEnforceable` reflects
/// whether the CURRENT surface can actually apply this feature (per the catalog).
struct TuneFeature: Identifiable, Equatable {
  let id: String
  let title: String
  let detail: String
  let isOn: Bool
  let isEnforceable: Bool
}

/// Maps the shared catalog + the cloud policy into the Tune screen's rows. Pure
/// and platform-agnostic; both the macOS and iOS Tune screens render from it.
enum TuneScreen {
  static func sites(policy: TortoisePolicy?, surface: TuningSurface) -> [TuneSite] {
    TuningCatalog.sites.map { site in
      let onCount = site.featureIDs.filter { policy?.browser?.features[$0] == true }.count
      return TuneSite(
        id: site.id,
        title: site.title,
        brandAssetName: site.brandAssetName,
        enabledCount: onCount,
        totalCount: site.featureIDs.count
      )
    }
  }

  static func features(forSiteID siteID: String, policy: TortoisePolicy?, surface: TuningSurface) -> [TuneFeature] {
    guard let site = TuningCatalog.sites.first(where: { $0.id == siteID }) else { return [] }
    return site.featureIDs.compactMap { id in
      guard let feature = BrowserTuningFeature(rawValue: id) else { return nil }
      let enforceable = TuningCatalog.features.first { $0.id == id }?.enforceableOn.contains(surface) ?? false
      return TuneFeature(
        id: id,
        title: feature.title,
        detail: feature.detail,
        isOn: policy?.browser?.features[id] == true,
        isEnforceable: enforceable
      )
    }
  }

  /// The per-feature map handed to the iOS Safari web extension: the real policy
  /// state for features Safari can enforce, and `false` for the ones it can't hook
  /// (so Safari never claims to apply them). Consumed by Task 4's writeSafariPolicy.
  static func iosSafariEnforcedFeatures(policy: TortoisePolicy?) -> [String: Bool] {
    Dictionary(uniqueKeysWithValues: TuningCatalog.allFeatureIDs.map { id in
      let enforceable = TuningCatalog.features.first { $0.id == id }?.enforceableOn.contains(.iosSafari) ?? false
      return (id, enforceable && (policy?.browser?.features[id] == true))
    })
  }
}
```

- [ ] **Step 2: Wire the files in `project.yml`**

`TuneScreenModel.swift` uses `BrowserTuningFeature`, which today only compiles into the macOS target. Add BOTH entries:

Under the `QuietGate` (macOS) target `sources:` (next to the other shared `Tortoise/*.swift` `type: file` entries):
```yaml
      - path: Tortoise/TuneScreenModel.swift
        type: file
```
Under the iOS `Tortoise` target `sources:` (so `BrowserTuningFeature` is available to the shared model + iOS views):
```yaml
      - path: QuietGate/Models/BrowserTuningFeature.swift
        type: file
```
(`TuneScreenModel.swift` lives in `Tortoise/`, so the iOS target picks it up via its folder entry automatically — only `BrowserTuningFeature.swift` needs the explicit iOS entry. Confirm the exact `sources:` shape of each target before editing and match the existing convention.)

- [ ] **Step 3: Regenerate the project**

Run: `xcodegen generate --spec project.yml --project .`
Expected: `Created project at .../QuietGate.xcodeproj`

- [ ] **Step 4: Write the tests**

Create `QuietGateTests/TuneScreenModelTests.swift`:

```swift
import XCTest
@testable import QuietGate

final class TuneScreenModelTests: XCTestCase {
  private func policy(featuresOn: [String]) -> TortoisePolicy {
    var flags = TuningCatalog.enabledFeatureFlags(for: "open") // all-false baseline
    for id in featuresOn { flags[id] = true }
    return TortoisePolicy(
      schemaVersion: 1, mode: "open", adultBlockingEnabled: false,
      browser: BrowserPolicy(features: flags, blockedDomains: [], blockedCategories: [], options: nil),
      schedules: nil, applications: nil
    )
  }

  func testSitesAreCatalogSitesInOrder() {
    let sites = TuneScreen.sites(policy: nil, surface: .chromeExtension)
    XCTAssertEqual(sites.map(\.id), ["youtube", "x", "instagram", "reddit"])
    XCTAssertEqual(sites.map(\.title), ["YouTube", "X", "Instagram", "Reddit"])
  }

  func testSiteEnabledCountReflectsPolicy() {
    let sites = TuneScreen.sites(policy: policy(featuresOn: ["youtubeShorts", "youtubeHome"]), surface: .chromeExtension)
    let youtube = sites.first { $0.id == "youtube" }!
    XCTAssertEqual(youtube.enabledCount, 2)
    XCTAssertEqual(youtube.totalCount, 23)
    XCTAssertEqual(sites.first { $0.id == "x" }!.enabledCount, 0)
  }

  func testFeatureTitlesComeFromBrowserTuningFeature() {
    let features = TuneScreen.features(forSiteID: "youtube", policy: nil, surface: .chromeExtension)
    let shorts = features.first { $0.id == "youtubeShorts" }!
    XCTAssertEqual(shorts.title, BrowserTuningFeature.youtubeShorts.title)
    XCTAssertEqual(shorts.detail, BrowserTuningFeature.youtubeShorts.detail)
  }

  func testFeatureIsOnReflectsPolicy() {
    let features = TuneScreen.features(forSiteID: "youtube", policy: policy(featuresOn: ["youtubeShorts"]), surface: .chromeExtension)
    XCTAssertTrue(features.first { $0.id == "youtubeShorts" }!.isOn)
    XCTAssertFalse(features.first { $0.id == "youtubeHome" }!.isOn)
  }

  func testEnforceabilityIsSurfaceAware() {
    // Browser (chrome) enforces every feature.
    let browser = TuneScreen.features(forSiteID: "instagram", policy: nil, surface: .chromeExtension)
    XCTAssertTrue(browser.allSatisfy(\.isEnforceable))
    // iOS Safari cannot hook two Instagram surfaces.
    let safari = TuneScreen.features(forSiteID: "instagram", policy: nil, surface: .iosSafari)
    XCTAssertFalse(safari.first { $0.id == "instagramProfileSuggestions" }!.isEnforceable)
    XCTAssertFalse(safari.first { $0.id == "instagramNotifications" }!.isEnforceable)
    XCTAssertTrue(safari.first { $0.id == "instagramReels" }!.isEnforceable)
  }

  func testEveryCatalogFeatureResolvesToABrowserTuningFeature() {
    // Guards the model's BrowserTuningFeature(rawValue:) so no site row silently drops a feature.
    for id in TuningCatalog.allFeatureIDs {
      XCTAssertNotNil(BrowserTuningFeature(rawValue: id), "\(id) has no BrowserTuningFeature case")
    }
  }

  func testIosSafariEnforcedFeaturesReflectsPolicyAndDropsUnhookable() {
    let safari = TuneScreen.iosSafariEnforcedFeatures(
      policy: policy(featuresOn: ["youtubeShorts", "instagramReels", "instagramNotifications"])
    )
    XCTAssertEqual(Set(safari.keys), Set(TuningCatalog.allFeatureIDs))
    XCTAssertTrue(safari["youtubeShorts"]!)            // enforceable on iOS Safari + on
    XCTAssertTrue(safari["instagramReels"]!)           // enforceable + on
    XCTAssertFalse(safari["instagramNotifications"]!)  // on in policy but NOT hookable on iOS Safari
    XCTAssertFalse(safari["youtubeHome"]!)             // enforceable but off
  }
}
```

- [ ] **Step 5: Run macOS tests** — `xcodebuild ... -scheme QuietGate ... test`. Expected: `TuneScreenModelTests` 7/7 PASS; whole suite green. (If the `TortoisePolicy`/`BrowserPolicy` initializer arguments differ from the snippet, adjust to the actual memberwise init in `Tortoise/TortoiseModels.swift`.)

- [ ] **Step 6: iOS build** — `xcodebuild ... -scheme Tortoise ... build`. Expected: `BUILD SUCCEEDED` (this proves `BrowserTuningFeature` now compiles into the iOS target).

- [ ] **Step 7: Commit**
```bash
git add Tortoise/TuneScreenModel.swift project.yml QuietGate.xcodeproj QuietGateTests/TuneScreenModelTests.swift
git commit -m "Add shared TuneScreenModel; make BrowserTuningFeature available to iOS"
```

---

### Task 2: Rewire the Mac Tune screen on `TuneScreenModel`

**Files:**
- Modify: `QuietGate/Views/TuningView.swift`
- Test: none new (view layer; model covered by Task 1). Suite must stay green.

**Interfaces:**
- Consumes: `TuneScreen.sites(policy:surface:)`, `TuneScreen.features(forSiteID:policy:surface:)`, `TuneSite`, `TuneFeature` (Task 1); writes via `accountStore.setTuningFeature(_:enabled:using:protectionStore:appBlockingStore:)` and `setTuningFeatures(...)`.

- [ ] **Step 1: Read `QuietGate/Views/TuningView.swift` fully.** It currently uses a private `DesignTuningSite` enum (youtube/x/instagram/reddit/**tiktok**), `TuningFeatureDisplay` structs, a `localTikTokFeatures` `@State` fake, a `siteGrid`, `selectedSiteHeader`, `scopeCard`, and `featuresCard`. Note the existing `QGDesign` tokens + card helpers (`QGCard`, `QGSwitch`, `QGPrimaryButtonStyle`, `QGPage`) and how it reads state (`store.tuningFeatureEnabled(...)`) and the locked-session gate (`store.timedSessionLockedActive`).

- [ ] **Step 2: Source the sites/features from the model.** The Mac surface is the browser (chrome/firefox extensions enforce all features), so pass `surface: .chromeExtension`. Build the rows from the cloud policy:
```swift
  private var tunePolicy: TortoisePolicy? { accountStore.snapshot.policy?.policy }
  private var tuneSites: [TuneSite] { TuneScreen.sites(policy: tunePolicy, surface: .chromeExtension) }
  private func tuneFeatures(_ siteID: String) -> [TuneFeature] {
    TuneScreen.features(forSiteID: siteID, policy: tunePolicy, surface: .chromeExtension)
  }
```
Replace the `DesignTuningSite`-driven `siteGrid` with a grid over `tuneSites` (tile shows `site.title`, brand mark via `site.brandAssetName`, and `"\(site.enabledCount)/\(site.totalCount)"`), and the `featuresCard` with rows over `tuneFeatures(selectedSiteID)` where each row is a `TuneFeature` (title + detail + a `QGSwitch` bound to `feature.isOn`). Keep `selectedSite` as a `String` site id (default `"youtube"`).

- [ ] **Step 3: Wire the toggle writes.** A feature switch's `set` calls:
```swift
  Task {
    if let f = BrowserTuningFeature(rawValue: feature.id) {
      await accountStore.setTuningFeature(f, enabled: newValue, using: clerk, protectionStore: store, appBlockingStore: appBlockingStore)
    }
  }
```
Preserve the existing locked-session gate (disable switches when `store.timedSessionLockedActive`). Keep the "Hide all / Reset all" toggle-all button, now calling `accountStore.setTuningFeatures(tuneFeatures(selectedSiteID).compactMap { BrowserTuningFeature(rawValue: $0.id) }, enabled:...)`.

- [ ] **Step 4: TikTok = honest "coming soon".** Delete `DesignTuningSite`, `TuningFeatureDisplay`, and `localTikTokFeatures`. Add a single non-interactive "TikTok — Coming soon" tile after the real site tiles (dimmed, no toggles), so nothing fake ships. (Real TikTok tuner = Phase 4.)

- [ ] **Step 5: Build + full macOS suite.** `xcodebuild ... -scheme QuietGate ... test` → `BUILD SUCCEEDED`, suite green. Confirm no test referenced the removed `DesignTuningSite`/`localTikTokFeatures` (grep `QuietGateTests`).

- [ ] **Step 6: iOS build.** `xcodebuild ... -scheme Tortoise ... build` → `BUILD SUCCEEDED`.

- [ ] **Step 7: Commit**
```bash
git add QuietGate/Views/TuningView.swift
git commit -m "Render Mac Tune screen from shared TuneScreenModel; drop fake TikTok"
```

---

### Task 3: Rewire the iOS Tune screen on `TuneScreenModel`

**Files:**
- Modify: `Tortoise/ContentView.swift` — `MobileTuningScreen` and its `MobileTuningSite` / `MobileFeature` enums.
- Test: none new (iOS build-verified).

**Interfaces:**
- Consumes: `TuneScreen.sites(policy:surface:)` / `features(forSiteID:policy:surface:)` with `surface: .iosSafari`; writes via `model.setBrowserFeature(_ id: String, enabled:using:)` / `setBrowserFeatures(_:enabled:using:)`.

- [ ] **Step 1: Read `MobileTuningScreen`** (`Tortoise/ContentView.swift`) and its `MobileTuningSite`/`MobileFeature` enums fully. Note the `TortoiseDesign` tokens, the site grid + feature rows, the write path (`setFeature`/`toggleSite` → `AccountHubModel`), and the YouTube-specific Screen-Time card (`MobileIOSYouTubeStatusCard`) — that card stays (it is iOS enforcement detail, like the Devices "This iPhone" row kept in 2a).

- [ ] **Step 2: Source sites/features from the model** with `surface: .iosSafari`, from `model.snapshot.policy?.policy`:
```swift
  private var tunePolicy: TortoisePolicy? { model.snapshot.policy?.policy }
  private var tuneSites: [TuneSite] { TuneScreen.sites(policy: tunePolicy, surface: .iosSafari) }
  private func tuneFeatures(_ siteID: String) -> [TuneFeature] {
    TuneScreen.features(forSiteID: siteID, policy: tunePolicy, surface: .iosSafari)
  }
```
Render the site grid over `tuneSites` and the per-site feature rows over `tuneFeatures(selectedSiteID)`. A feature switch's `set` calls `Task { _ = await model.setBrowserFeature(feature.id, enabled: newValue, using: clerk) }`.

- [ ] **Step 3: Honesty for non-enforceable features.** For a `TuneFeature` with `isEnforceable == false` (on iOS: exactly `instagramProfileSuggestions`, `instagramNotifications`), render the row visibly de-emphasized with a small "browser only" caption and DISABLE its switch — the Safari extension has no hook for these. (Every OTHER iOS toggle actually enforces on iPhone Safari once Task 4 lands.)

- [ ] **Step 4: TikTok = honest "coming soon".** Delete `MobileTuningSite` and `MobileFeature`; add a non-interactive "TikTok — Coming soon" tile after the real sites. Keep the YouTube `MobileIOSYouTubeStatusCard`.

- [ ] **Step 5: iOS build.** `xcodebuild ... -scheme Tortoise ... build` → `BUILD SUCCEEDED`.
- [ ] **Step 6: macOS suite.** `xcodebuild ... -scheme QuietGate ... test` → suite green (shared files unchanged; only iOS view code).

- [ ] **Step 7: Commit**
```bash
git add Tortoise/ContentView.swift
git commit -m "Render iOS Tune screen from shared TuneScreenModel; honest enforceability; drop fake TikTok"
```

---

### Task 4: Make iPhone Safari honor per-feature toggles

**Files:**
- Modify: `Tortoise/IOSYouTubeScreenTimeController.swift` (`writeSafariPolicy` + a new `applyPolicyFeatures`)
- Modify: `Tortoise/ContentView.swift` (the iOS shell: push the policy's features into the controller on change)
- Test: none new — the pure mapping (`TuneScreen.iosSafariEnforcedFeatures`) is TDD'd in Task 1; this is iOS build-verified wiring.

**Interfaces:**
- Consumes: `TuneScreen.iosSafariEnforcedFeatures(policy:)` (Task 1), `SafariExtensionPolicy` (`Tortoise/IOSEnforcementShared.swift`, which already has a mutable `var features: [String: Bool]`).

**Why:** the Safari app-group policy already carries a per-feature `features` map, and the Safari content scripts already apply it per-feature (`TortoiseSafariExtension/content/youtube.js` `applySettings()` → `features[feature]`). The ONLY gap: `writeSafariPolicy` fills `features` from `SafariExtensionPolicy.policy(for: mode)` (a mode preset), so per-feature toggles never reach Safari. Feed the real policy features instead.

- [ ] **Step 1: Read** `IOSYouTubeScreenTimeController.writeSafariPolicy` (~line 528) and the iOS shell in `Tortoise/ContentView.swift` where `screenTime` (`IOSYouTubeScreenTimeController`) and `model` (`AccountHubModel`) coexist — note the existing `.onChange(of: model.snapshot.policy?.policy.browser?.options?.youtubeDailyLimitMinutes)` that already pushes the daily limit into `screenTime`; you'll add a sibling for features.

- [ ] **Step 2: Overlay the real features in `writeSafariPolicy`.** Add a stored `private var policyFeatures: [String: Bool] = [:]`, a public setter, and make `writeSafariPolicy` prefer it over the mode preset:
```swift
  func applyPolicyFeatures(_ features: [String: Bool]) {
    policyFeatures = features
    writeSafariPolicy()
  }

  private func writeSafariPolicy(mode overrideMode: IOSEnforcementMode? = nil) {
    let mode = overrideMode ?? (shieldingEnabled ? enforcementMode : .open)
    var policy = SafariExtensionPolicy.policy(
      for: mode,
      dailyLimitMinutes: dailyLimitMinutes,
      adultWebFilterEnabled: mode == .strict
    )
    if !policyFeatures.isEmpty {
      policy.features = policyFeatures  // real per-feature state (Safari-enforceable only) overrides the mode preset
    }
    IOSEnforcementSharedStore.saveSafariPolicy(policy)
  }
```
(This also fixes a pre-existing bug: tuning went inert whenever shielding was off — features now follow the real policy, independent of the Screen-Time shield mode.)

- [ ] **Step 3: Push the policy features from the shell.** In `Tortoise/ContentView.swift`, next to the existing daily-limit `.onChange`, add:
```swift
  .onChange(of: model.snapshot.policy?.policy.browser?.features, initial: true) { _, _ in
    screenTime.applyPolicyFeatures(TuneScreen.iosSafariEnforcedFeatures(policy: model.snapshot.policy?.policy))
  }
```
So on first load and on every tuning change (`AccountHubModel.setBrowserFeature` updates `snapshot.policy`), the Safari app-group policy's `features` are rewritten from the real policy.

- [ ] **Step 4: iOS build** — `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build` → `BUILD SUCCEEDED`.
- [ ] **Step 5: macOS suite** — `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test` → green (no shared logic changed here; `iosSafariEnforcedFeatures` is covered by Task 1).

- [ ] **Step 6: Commit**
```bash
git add Tortoise/IOSYouTubeScreenTimeController.swift Tortoise/ContentView.swift
git commit -m "iOS Safari: enforce real per-feature tuning, not just the mode preset"
```

---

## Self-Review

**Spec coverage (spec §6 Tune — per-site slice):**
- Unify both Tune screens on the shared catalog; delete `DesignTuningSite`/`MobileTuningSite` → Tasks 2-3 render from Task 1's `TuneScreenModel`. ✓
- Mode + per-site quick state + granular detail-on-demand → Task 1 model (site counts + feature rows); Tasks 2-3 progressive disclosure. ✓ (Mode selector already present in both screens; unchanged writes via `setAccessMode`/`setPolicyMode`.)
- Per-surface enforcement honesty (§6.3) → `TuneFeature.isEnforceable` from the catalog (Task 1); Task 3 disables the 2 unhookable iOS Instagram features; **Task 4 makes every other iOS toggle actually enforce on iPhone Safari** by feeding the real `policy.browser.features` to the Safari app-group policy. ✓ §6.3 fully met on iOS Safari (not deferred).
- Remove the fake TikTok stub → Tasks 2-3 delete the local-`@State` TikTok and show an honest "coming soon". ✓

**Placeholder scan:** No TBD/TODO left as work-in-a-step. iOS Safari per-feature enforcement is fully implemented here (Task 4), not deferred; the 2 genuinely unhookable Instagram features are disabled in the UI (Task 3).

**Type consistency:** `TuneSite`, `TuneFeature`, `TuneScreen.sites(policy:surface:)`, `TuneScreen.features(forSiteID:policy:surface:)`, `TuneScreen.iosSafariEnforcedFeatures(policy:)`, `TuningSurface`, `BrowserTuningFeature(rawValue:)`, `IOSYouTubeScreenTimeController.applyPolicyFeatures(_:)`, `SafariExtensionPolicy.features`, and the store write methods are used consistently across tasks.

**Out of scope (deferred):** folding Blocking (adult/apps/websites/sessions) into Tune + real iOS sessions (3b); the Mac augment-knob UI (`explicitHideStyle`, YouTube daily limit) + the "45m" label fix (3c); the `BrowserTuningSite` vs `TuningCatalog.sites` title duplication (Phase 5); real TikTok tuner (Phase 4).

## Whole-branch review outcome (Phase 3a)

Verdict: **Ready to merge — Yes.** No Critical/Important. Both Tune screens genuinely driven by the one tested `TuneScreenModel` (duplicate enums grep-confirmed gone); iOS honesty layered in 3 places; iPhone Safari enforces real per-feature (content scripts confirmed to read `features[feature]` for all 4 sites); mode/daily-limit/adult-filter not regressed; no fake data; real brand marks on both platforms.

**IMPORTANT follow-up (correctness/honesty — decision pending):** the two features marked non-enforceable on iOS Safari (`instagramProfileSuggestions`, `instagramNotifications`) are in fact **handled by the Safari content script** (`TortoiseSafariExtension/content/instagram.js:368-377` marks them; `instagram.css:13-20` hides them). The Phase-1 "no hook" assumption in `TuningCatalog` (`iosSafariFeatureIDs` exclusion) is therefore likely wrong, and the iOS "Browser only" label on those two rows is likely false. **Fix:** remove the 2-feature exclusion so `TuningCatalog` enforces all 42 on `.iosSafari` (they then behave like every other best-effort DOM tuner) — this also makes `TuneScreenModelTests.testEnforceabilityIsSurfaceAware` + `testIosSafariEnforcedFeaturesReflectsPolicyAndDropsUnhookable` need updating, and the Task-3 disabled-row / bulk-filter / Task-4 forced-false handling becomes inert (harmless). Address in 3b or as a 3a addendum, per the human's call.

**Deferred Minors (→ 3b):** nil-guard on the launch `onChange` (transient fail-closed Safari write before policy loads); surface-aware iOS counts (site/header counts include the currently-excluded features); `"youtube"` magic-string constant.
