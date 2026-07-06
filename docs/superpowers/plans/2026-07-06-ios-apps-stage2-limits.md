# iOS "Apps" Screen-Time Layer — Stage 2 (Daily Limits + YouTube-Independence Fix) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a **combined daily limit** to the Stage 1 managed-apps selection: in **Open** mode the picked apps are *allowed but capped* — after N minutes/day of combined use they shield until midnight (via a distinct `DeviceActivityEvent` shielding into a NEW `.tortoiseManagedAppsLimit` store the OS unions with the Stage 1 `.tortoiseManagedApps` shield); in **Focus/Strict** they stay blocked outright (Stage 1). Fold in the Stage-1-flagged coupling fix so the **Strict adult web filter** and the **enforcement status** no longer require a *YouTube* selection. All additive and non-breaking versus the existing YouTube daily limit (`.tortoiseLimit`/`startDailyMonitoring`/`dailyLimitMinutes`) and the Stage 1 managed-apps shield.

**Architecture:** The limit is an **advisory Open governor** on its **own** DeviceActivity (`DeviceActivityName.tortoiseManagedAppsDaily`) with a distinct `DeviceActivityEvent.Name.managedAppsDailyLimit` over the managed-apps selection — kept fully separate from the YouTube `.tortoiseDaily` activity so the YouTube path's start/stop lifecycle is untouched. The controller **arms/re-arms** this monitor from the `applyCurrentMode()` seam (via a new `reconcileManagedAppsLimitMonitoring()` that runs on **both** the Open and Focus/Strict branches, so the limit works in Open) whenever the limit is enabled + selection non-empty + Screen Time authorized; otherwise it stops the monitor and clears `.tortoiseManagedAppsLimit`. The `TortoiseDeviceActivityMonitor` extension routes strictly by name: `.tortoiseDailyLimit` → `.tortoiseLimit` (YouTube, unchanged); `.managedAppsDailyLimit` → shields the managed-apps selection (shield-fields-only, no adult filter) into `.tortoiseManagedAppsLimit`; `intervalDidStart`/`intervalDidEnd` for `.tortoiseManagedAppsDaily` clear that store (daily reset). The limit value (`managedAppsLimitMinutes: Int?`, nil = off) is `@Published` on the controller, clamped 5–480, persisted in `PersistedIOSEnforcementState` **and** the shared `IOSEnforcementSnapshot` (Int? — cross-platform safe). The independence fix decouples the OS adult filter (a new `reconcileAdultWebFilter()` driving `immediateStore.webContent.blockedByFilter`/`media.denyExplicitContent` purely from mode==Strict), the Safari policy (non-enforce branch now writes the real-mode policy instead of forcing `.open`), and the status (`connectionState`/`syncHealth`/`updateStatusMessage` OR-in the managed-apps selection). All new pure decisions extend `ManagedAppsShield` (TDD'd on macOS).

**Tech Stack:** Swift 5, SwiftUI, FamilyControls / ManagedSettings / DeviceActivity (iOS-only), XCTest (macOS), XcodeGen.

## Global Constraints

- Tests are a macOS XCTest bundle `QuietGateTests` (`@testable import QuietGate`). There is **no iOS unit-test target** — pure cross-platform logic in `Tortoise/` is TDD'd on macOS; the `FamilyControls`/`ManagedSettings`/`DeviceActivity`/SwiftUI wiring is **build-verified only** (on-device shield behavior is manual QA).
- **iOS builds are SLOW (~15–25 min).** Run `xcodebuild` via the **Bash tool ONLY** (never an Xcode/xcodebuild MCP tool — that has hung); one build at a time, foreground, let it finish.
- `FamilyControls`/`ManagedSettings`/`DeviceActivity` are **iOS-only** — keep new such code inside `#if os(iOS)`; the shared `IOSEnforcementSnapshot` and `ManagedAppsShield` stay free of them (`managedAppsLimitMinutes` is an `Int?` — safe cross-platform). **Editing existing files needs no xcodegen.** Both files this plan touches for pure logic (`Tortoise/ManagedAppsShield.swift`) and tests (`QuietGateTests/ManagedAppsShieldTests.swift`) are **already** registered in their targets — no new shared file is created, so **no `xcodegen generate` is required anywhere in this plan.**
- macOS tests: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
- iOS build: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
- Product name **Tortoise**; minimal on-screen text; **no fake/demo data**; **additive/non-breaking** vs the YouTube limit (`.tortoiseLimit` / `startDailyMonitoring()` / `DeviceActivityName.tortoiseDaily` / `DeviceActivityEvent.Name.tortoiseDailyLimit` / `dailyLimitMinutes` untouched) AND the Stage 1 managed-apps shield (`.tortoiseManagedApps` / `applyManagedAppsShield()` unchanged in behavior). The limit is an **Open governor** (Focus/Strict still block outright); `.tortoiseManagedAppsLimit` is **NOT** in `tortoiseEnforcementStores` (owned by its own reconcile paths, like `.tortoiseManagedApps`).
- Commit per task with `git add <specific files>` — **NEVER `git add .`** (a gitignored `Secrets.xcconfig` is present). End every commit message with the `Co-Authored-By` trailer shown in each task.

## Available from earlier phases (committed)

- `Tortoise/ManagedAppsShield.swift` (Stage 1) — cross-platform `enum ManagedAppsShield` with `shouldShield(mode:)`, `isShrink(old:new:)`, `canApplyEdit(lockedActive:isShrink:)`; **already listed** in the `QuietGate` macOS target `sources:` (`project.yml` line 56). Free of `FamilyControls`/`ManagedSettings`.
- `QuietGateTests/ManagedAppsShieldTests.swift` (Stage 1) — 12 tests; `QuietGateTests` target includes the whole `QuietGateTests` folder, so appended methods compile without regenerate.
- `Tortoise/IOSEnforcementShared.swift` — `IOSEnforcementMode { open, focus, strict }` (Codable); `struct IOSEnforcementSnapshot: Codable, Equatable` (with `mode`, `shieldingEnabled`, `dailyLimitMinutes`, and a trailing region of defaulted optional fields ending `var session: IOSSessionState? = nil`) + `.empty`; `IOSEnforcementSharedStore` (iOS-only `loadManagedAppsSelection()`/`saveManagedAppsSelection(_:)`, `loadSnapshot()`/`saveSnapshot(_:)`, `recordThresholdEvent(_:)`); `IOSEnforcementShieldApplier.applyShield(_:to:)` (shield-fields-only, no adult filter) and `applySelection(_:to:adultWebFilterEnabled:)` (adds `webContent.blockedByFilter`/`media.denyExplicitContent`); `extension ManagedSettingsStore.Name` (`.tortoiseImmediate`/`.tortoiseSchedule`/`.tortoiseLimit`/`.tortoiseManagedApps`; `tortoiseEnforcementStores = [.tortoiseImmediate, .tortoiseSchedule, .tortoiseLimit]`); `extension DeviceActivityName` (`.tortoiseDaily`); `extension DeviceActivityEvent.Name` (`.tortoiseDailyLimit = Self("tortoise.youtube.dailyLimit")`). This file is compiled into the `QuietGate` (macOS), `Tortoise` (iOS), `TortoiseDeviceActivityMonitor`, and `TortoiseSafariExtension` targets — iOS-only additions must stay behind `#if os(iOS)`.
- `Tortoise/IOSYouTubeScreenTimeController.swift` — `typealias IOSYouTubeScreenTimeController = IOSEnforcementController` (`@MainActor final class`, iOS-only): `@Published var selection` (YouTube), `@Published private(set) var managedAppsSelection`, `@Published var dailyLimitMinutes` (clamped 5–480 in didSet), `private let immediateStore`/`managedAppsStore`, `private let activityCenter = DeviceActivityCenter()`; `hasSelection`/`hasManagedAppsSelection`/`managedAppsSummary`; `canApplyShielding = authorizationState.isApproved && hasSelection`; `applyCurrentMode()` (the single seam: `applyManagedAppsShield()` then a `shouldEnforce` branch), `applyManagedAppsShield()`, `startDailyMonitoring()` (the YouTube `DeviceActivitySchedule` + `DeviceActivityEvent(threshold:)` + `activityCenter.startMonitoring(.tortoiseDaily, during:events:)` pattern to MIRROR), `writeSafariPolicy(mode:)`, `saveSnapshot(lastError:)`, `connectionState`, `updateStatusMessage()`, `setManagedAppsSelection(_:)`, `private struct PersistedIOSEnforcementState` + `persistState()`/`loadState()`.
- `TortoiseDeviceActivityMonitor/DeviceActivityMonitorExtension.swift` — `final class TortoiseDeviceActivityMonitorExtension: DeviceActivityMonitor` with `scheduleStore`/`limitStore`, `intervalDidStart`/`intervalDidEnd`/`eventDidReachThreshold`, reading `IOSEnforcementSharedStore.loadSnapshot()` (`snapshot.shieldingEnabled`/`snapshot.mode`).
- `Tortoise/ContentView.swift` — `MobileTuningScreen` with the "Apps" `MobileCard` (Stage 1), `@State private var appsPickerPresented`, `managedAppsBinding`, `presentAppsPicker()`; the YouTube daily-limit control pattern (a `HStack` with `MobileStepperButton(systemImage: "minus"/"plus")` + `Text("\(...)m")`, disabled while `sessionLockedActive`); `MobileCard`/`MobileSectionLabel`/`MobileDivider`/`MobileSwitch`/`MobileStepperButton`; `TortoiseDesign` tokens (`primaryText`, `secondaryText`, `accent`).

---

### Task 1: Pure decision logic — extend `ManagedAppsShield` (macOS TDD, no iOS build)

Add four cross-platform functions to the existing `ManagedAppsShield`, TDD'd on macOS. **No `FamilyControls`/`ManagedSettings` dependency** — `clampManagedAppsLimitMinutes` is `Int`-only, the others are `Bool` predicates. Both files are already in their targets, so **no `project.yml` / `xcodegen` change.**

**Files:**
- Modify: `Tortoise/ManagedAppsShield.swift` (append four functions before the enum's closing brace)
- Modify: `QuietGateTests/ManagedAppsShieldTests.swift` (append test methods before the class's closing brace)

**Interfaces produced (consumed by Tasks 2–4):**
- `static func clampManagedAppsLimitMinutes(_ minutes: Int) -> Int` — `min(max(minutes, 5), 480)`.
- `static func shouldArmManagedAppsLimit(limitEnabled: Bool, hasSelection: Bool) -> Bool` — `limitEnabled && hasSelection`.
- `static func shouldApplyAdultFilter(mode: IOSEnforcementMode, adultEnabled: Bool) -> Bool` — `mode == .strict && adultEnabled`.
- `static func isEnforcementActive(youtubeSelected: Bool, managedAppsSelected: Bool, adultFilterOn: Bool) -> Bool` — OR of the three.

- [ ] **Step 1: Write the failing tests**

In `QuietGateTests/ManagedAppsShieldTests.swift`, find the final closing brace of the class:

```swift
  func testLockedAllowsGrow() {
    XCTAssertTrue(ManagedAppsShield.canApplyEdit(lockedActive: true, isShrink: false))
  }
}
```

Replace it with (keeps `testLockedAllowsGrow`, then appends the new tests before `}`):

```swift
  func testLockedAllowsGrow() {
    XCTAssertTrue(ManagedAppsShield.canApplyEdit(lockedActive: true, isShrink: false))
  }

  // MARK: clampManagedAppsLimitMinutes(_:)

  func testClampBelowMinimumRaisesToFive() {
    XCTAssertEqual(ManagedAppsShield.clampManagedAppsLimitMinutes(0), 5)
    XCTAssertEqual(ManagedAppsShield.clampManagedAppsLimitMinutes(4), 5)
    XCTAssertEqual(ManagedAppsShield.clampManagedAppsLimitMinutes(-30), 5)
  }

  func testClampAboveMaximumLowersToFourEighty() {
    XCTAssertEqual(ManagedAppsShield.clampManagedAppsLimitMinutes(481), 480)
    XCTAssertEqual(ManagedAppsShield.clampManagedAppsLimitMinutes(10_000), 480)
  }

  func testClampWithinRangeIsUnchanged() {
    XCTAssertEqual(ManagedAppsShield.clampManagedAppsLimitMinutes(5), 5)
    XCTAssertEqual(ManagedAppsShield.clampManagedAppsLimitMinutes(30), 30)
    XCTAssertEqual(ManagedAppsShield.clampManagedAppsLimitMinutes(480), 480)
  }

  // MARK: shouldArmManagedAppsLimit(limitEnabled:hasSelection:)

  func testArmsOnlyWhenEnabledAndSelectionPresent() {
    XCTAssertTrue(ManagedAppsShield.shouldArmManagedAppsLimit(limitEnabled: true, hasSelection: true))
  }

  func testDoesNotArmWhenDisabled() {
    XCTAssertFalse(ManagedAppsShield.shouldArmManagedAppsLimit(limitEnabled: false, hasSelection: true))
  }

  func testDoesNotArmWhenSelectionEmpty() {
    XCTAssertFalse(ManagedAppsShield.shouldArmManagedAppsLimit(limitEnabled: true, hasSelection: false))
  }

  // MARK: shouldApplyAdultFilter(mode:adultEnabled:)

  func testAdultFilterAppliesOnlyInStrictWhenEnabled() {
    XCTAssertTrue(ManagedAppsShield.shouldApplyAdultFilter(mode: .strict, adultEnabled: true))
  }

  func testAdultFilterOffWhenAdultDisabledEvenInStrict() {
    XCTAssertFalse(ManagedAppsShield.shouldApplyAdultFilter(mode: .strict, adultEnabled: false))
  }

  func testAdultFilterOffInOpenAndFocus() {
    XCTAssertFalse(ManagedAppsShield.shouldApplyAdultFilter(mode: .open, adultEnabled: true))
    XCTAssertFalse(ManagedAppsShield.shouldApplyAdultFilter(mode: .focus, adultEnabled: true))
  }

  // MARK: isEnforcementActive(youtubeSelected:managedAppsSelected:adultFilterOn:)

  func testEnforcementActiveWhenYouTubeSelected() {
    XCTAssertTrue(ManagedAppsShield.isEnforcementActive(
      youtubeSelected: true, managedAppsSelected: false, adultFilterOn: false))
  }

  func testEnforcementActiveWhenManagedAppsSelected() {
    XCTAssertTrue(ManagedAppsShield.isEnforcementActive(
      youtubeSelected: false, managedAppsSelected: true, adultFilterOn: false))
  }

  func testEnforcementActiveWhenAdultFilterOn() {
    XCTAssertTrue(ManagedAppsShield.isEnforcementActive(
      youtubeSelected: false, managedAppsSelected: false, adultFilterOn: true))
  }

  func testEnforcementInactiveWhenNothingActive() {
    XCTAssertFalse(ManagedAppsShield.isEnforcementActive(
      youtubeSelected: false, managedAppsSelected: false, adultFilterOn: false))
  }
}
```

- [ ] **Step 2: Add deliberately-wrong stubs (so it compiles and the assertions fail red)**

In `Tortoise/ManagedAppsShield.swift`, find the end of `canApplyEdit(...)` and the enum's closing brace:

```swift
  static func canApplyEdit(lockedActive: Bool, isShrink: Bool) -> Bool {
    if lockedActive {
      return !isShrink
    }
    return true
  }
}
```

Replace with (appends stubs returning wrong values):

```swift
  static func canApplyEdit(lockedActive: Bool, isShrink: Bool) -> Bool {
    if lockedActive {
      return !isShrink
    }
    return true
  }

  static func clampManagedAppsLimitMinutes(_ minutes: Int) -> Int {
    minutes
  }

  static func shouldArmManagedAppsLimit(limitEnabled: Bool, hasSelection: Bool) -> Bool {
    true
  }

  static func shouldApplyAdultFilter(mode: IOSEnforcementMode, adultEnabled: Bool) -> Bool {
    true
  }

  static func isEnforcementActive(
    youtubeSelected: Bool, managedAppsSelected: Bool, adultFilterOn: Bool
  ) -> Bool {
    false
  }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData -only-testing:QuietGateTests/ManagedAppsShieldTests test`
Expected: builds, then FAILS — e.g. `testClampBelowMinimumRaisesToFive`, `testDoesNotArmWhenDisabled`, `testAdultFilterOffInOpenAndFocus`, `testEnforcementInactiveWhenNothingActive` fail their assertions.

- [ ] **Step 4: Write the real implementation**

In `Tortoise/ManagedAppsShield.swift`, replace the four stub bodies just added with the real logic:

```swift
  /// Clamps a raw daily-limit value to the supported 5–480 minute range (mirrors
  /// the YouTube `dailyLimitMinutes` bounds).
  static func clampManagedAppsLimitMinutes(_ minutes: Int) -> Int {
    min(max(minutes, 5), 480)
  }

  /// The combined managed-apps daily-limit monitor is armed only when the limit
  /// is enabled AND at least one target is selected. (Mode is irrelevant — the
  /// limit is an OPEN governor and is redundant-harmless in Focus/Strict.)
  static func shouldArmManagedAppsLimit(limitEnabled: Bool, hasSelection: Bool) -> Bool {
    limitEnabled && hasSelection
  }

  /// The adult web/media filter applies only in Strict with adult blocking on —
  /// independent of any app/site selection.
  static func shouldApplyAdultFilter(mode: IOSEnforcementMode, adultEnabled: Bool) -> Bool {
    mode == .strict && adultEnabled
  }

  /// Enforcement is "active" (for status reporting) when any of the enforcement
  /// sources is engaged: a YouTube selection, a managed-apps selection, or the
  /// adult filter. Decouples status from requiring a *YouTube* selection.
  static func isEnforcementActive(
    youtubeSelected: Bool, managedAppsSelected: Bool, adultFilterOn: Bool
  ) -> Bool {
    youtubeSelected || managedAppsSelected || adultFilterOn
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData -only-testing:QuietGateTests/ManagedAppsShieldTests test`
Expected: `ManagedAppsShieldTests` all green (12 Stage 1 + 16 new = 28 tests PASS).

- [ ] **Step 6: Run the full macOS suite (no regressions)**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
Expected: whole suite green.

- [ ] **Step 7: Commit**

```bash
git add Tortoise/ManagedAppsShield.swift QuietGateTests/ManagedAppsShieldTests.swift
git commit -m "feat(ios-apps): add Stage 2 pure decisions to ManagedAppsShield (TDD)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Shared plumbing + controller monitoring + independence fix (iOS build-verified)

Add the shared names/snapshot field, then wire the controller: hold `managedAppsLimitMinutes`, persist it, arm the managed-apps limit monitor on the `applyCurrentMode()` seam (works in Open), and fold in the independence fix (OS adult filter + Safari policy + status). Folds spec decomposition items 2 + 3 into ONE iOS build — the shared names are only exercised by the controller, and each build costs ~15–25 min. A macOS snapshot round-trip test runs first (catches the Codable/backward-compat regression) before the slow iOS build.

**Files:**
- Modify: `Tortoise/IOSEnforcementShared.swift` (snapshot field; `.tortoiseManagedAppsLimit` store name; `.tortoiseManagedAppsDaily` activity name; `.managedAppsDailyLimit` event name)
- Modify: `Tortoise/IOSYouTubeScreenTimeController.swift` (store property; `@Published managedAppsLimitMinutes`; init load; UI helpers; limit setters; `applyCurrentMode` wiring; `applyManagedAppsShield` returns Bool; `reconcileManagedAppsLimitMonitoring`; `reconcileAdultWebFilter`; `connectionState`; `updateStatusMessage`; `saveSnapshot`; `PersistedIOSEnforcementState`/`persistState`/`loadState`)
- Modify: `QuietGateTests/ManagedAppsShieldTests.swift` (snapshot round-trip tests)

**Interfaces:**
- Consumes (Task 1): `ManagedAppsShield.clampManagedAppsLimitMinutes(_:)`, `.shouldArmManagedAppsLimit(limitEnabled:hasSelection:)`, `.shouldApplyAdultFilter(mode:adultEnabled:)`, `.isEnforcementActive(...)`, plus Stage 1 `.shouldShield(mode:)`.
- Produces (consumed by Tasks 3–4): `IOSEnforcementSnapshot.managedAppsLimitMinutes: Int?`; `ManagedSettingsStore.Name.tortoiseManagedAppsLimit`; `DeviceActivityName.tortoiseManagedAppsDaily`; `DeviceActivityEvent.Name.managedAppsDailyLimit`; controller `@Published var managedAppsLimitMinutes: Int?`, `managedAppsLimitEnabled`, `managedAppsLimitDisplayMinutes`, `managedAppsLimitSummary`, `setManagedAppsLimitEnabled(_:)`, `adjustManagedAppsLimit(by:)`.

#### Part A — `IOSEnforcementShared.swift`

- [ ] **Step 1: Add `managedAppsLimitMinutes` to the shared snapshot (trailing defaulted region — keeps the memberwise-init call sites valid)**

Find:

```swift
  var lastSetupCheckAt: Date? = nil
  var session: IOSSessionState? = nil

  var hasSelectedTargets: Bool {
```

Replace with:

```swift
  var lastSetupCheckAt: Date? = nil
  var session: IOSSessionState? = nil
  /// Stage 2: combined managed-apps daily limit (minutes). `nil` = off. Persisted
  /// so the DeviceActivity monitor extension can gate the limit shield. `Int?` is
  /// cross-platform safe — no `FamilyControls`/`ManagedSettings` type leaks here.
  var managedAppsLimitMinutes: Int? = nil

  var hasSelectedTargets: Bool {
```

- [ ] **Step 2: Add the `.tortoiseManagedAppsLimit` store name (NOT in the clear-sweep)**

Find:

```swift
  static let tortoiseManagedApps = Self("tortoise.managedApps")

  static let tortoiseEnforcementStores: [Self] = [
    .tortoiseImmediate,
    .tortoiseSchedule,
    .tortoiseLimit
  ]
}
```

Replace with:

```swift
  static let tortoiseManagedApps = Self("tortoise.managedApps")

  /// Stage 2: the combined managed-apps DAILY-LIMIT shield store. Written by the
  /// DeviceActivity monitor extension when the Open-mode combined threshold is
  /// reached; the OS UNIONS it with `.tortoiseManagedApps` (Stage 1) and the
  /// YouTube `.tortoiseImmediate` shield automatically. Like `.tortoiseManagedApps`
  /// it is deliberately NOT in `tortoiseEnforcementStores` — it is owned by its own
  /// reconcile paths (`reconcileManagedAppsLimitMonitoring()` disarm + the
  /// extension's `intervalDidStart`/`intervalDidEnd`), so the YouTube
  /// `clearAllStores()` sweep never touches it.
  static let tortoiseManagedAppsLimit = Self("tortoise.managedApps.limit")

  static let tortoiseEnforcementStores: [Self] = [
    .tortoiseImmediate,
    .tortoiseSchedule,
    .tortoiseLimit
  ]
}
```

- [ ] **Step 3: Add the distinct DeviceActivity + event names**

Find:

```swift
extension DeviceActivityName {
  static let tortoiseDaily = Self("tortoise.daily")
}

extension DeviceActivityEvent.Name {
  static let tortoiseDailyLimit = Self("tortoise.youtube.dailyLimit")
}
#endif
```

Replace with:

```swift
extension DeviceActivityName {
  static let tortoiseDaily = Self("tortoise.daily")

  /// Stage 2: the managed-apps limit runs on its OWN DeviceActivity so it is
  /// independent of the YouTube `.tortoiseDaily` start/stop lifecycle and can run
  /// in Open mode (where `.tortoiseDaily` is stopped).
  static let tortoiseManagedAppsDaily = Self("tortoise.managedApps.daily")
}

extension DeviceActivityEvent.Name {
  static let tortoiseDailyLimit = Self("tortoise.youtube.dailyLimit")

  /// Stage 2: combined managed-apps daily-limit threshold event. Routed by NAME in
  /// the extension to `.tortoiseManagedAppsLimit`.
  static let managedAppsDailyLimit = Self("tortoise.managedApps.dailyLimit")
}
#endif
```

#### Part B — `IOSYouTubeScreenTimeController.swift`

- [ ] **Step 4: Add the limit store property**

Find:

```swift
  private let managedAppsStore = ManagedSettingsStore(named: .tortoiseManagedApps)
  private let activityCenter = DeviceActivityCenter()
```

Replace with:

```swift
  private let managedAppsStore = ManagedSettingsStore(named: .tortoiseManagedApps)
  private let managedAppsLimitStore = ManagedSettingsStore(named: .tortoiseManagedAppsLimit)
  private let activityCenter = DeviceActivityCenter()
```

- [ ] **Step 5: Add the `@Published managedAppsLimitMinutes` (clamped in didSet, mirroring `dailyLimitMinutes`)**

Find:

```swift
  @Published var dailyLimitMinutes: Int {
    didSet {
      dailyLimitMinutes = min(max(dailyLimitMinutes, 5), 480)
      persistState()
      applyCurrentMode()
    }
  }
```

Replace with:

```swift
  @Published var dailyLimitMinutes: Int {
    didSet {
      dailyLimitMinutes = min(max(dailyLimitMinutes, 5), 480)
      persistState()
      applyCurrentMode()
    }
  }

  /// Stage 2: combined managed-apps daily limit (minutes). `nil` = off. Clamped
  /// 5–480 when set. Advisory OPEN governor — `applyCurrentMode()` re-arms the
  /// `.tortoiseManagedAppsDaily` monitor. (Assigning within didSet does not
  /// re-fire the observer, so the clamp converges — same pattern as
  /// `dailyLimitMinutes`.)
  @Published var managedAppsLimitMinutes: Int? {
    didSet {
      if let minutes = managedAppsLimitMinutes {
        managedAppsLimitMinutes = ManagedAppsShield.clampManagedAppsLimitMinutes(minutes)
      }
      persistState()
      applyCurrentMode()
    }
  }
```

- [ ] **Step 6: Load it on init**

Find:

```swift
    dailyLimitMinutes = persisted.dailyLimitMinutes
    safariExtensionAcknowledged = persisted.safariExtensionAcknowledged
```

Replace with:

```swift
    dailyLimitMinutes = persisted.dailyLimitMinutes
    managedAppsLimitMinutes = persisted.managedAppsLimitMinutes
    safariExtensionAcknowledged = persisted.safariExtensionAcknowledged
```

- [ ] **Step 7: Add the UI helpers (below `managedAppsSummary`)**

Find the closing of `managedAppsSummary`:

```swift
    if domains > 0 { parts.append("\(domains) web domain\(domains == 1 ? "" : "s")") }
    return parts.joined(separator: " · ") + " blocked in Focus & Strict"
  }
```

Replace with:

```swift
    if domains > 0 { parts.append("\(domains) web domain\(domains == 1 ? "" : "s")") }
    return parts.joined(separator: " · ") + " blocked in Focus & Strict"
  }

  var managedAppsLimitEnabled: Bool { managedAppsLimitMinutes != nil }

  /// Value shown in the stepper — defaults to 30 when the limit is off.
  var managedAppsLimitDisplayMinutes: Int { managedAppsLimitMinutes ?? 30 }

  /// Honest one-line copy for the Apps-card limit control.
  var managedAppsLimitSummary: String {
    guard let minutes = managedAppsLimitMinutes else {
      return "No daily limit"
    }
    return "Allowed \(minutes)m/day in Open · blocked in Focus & Strict"
  }
```

- [ ] **Step 8: Add the limit setters (below `setManagedAppsSelection(_:)`)**

Find the closing of `setManagedAppsSelection(_:)`:

```swift
    managedAppsSelection = newValue
    IOSEnforcementSharedStore.saveManagedAppsSelection(newValue)
    applyCurrentMode()
  }
```

Replace with:

```swift
    managedAppsSelection = newValue
    IOSEnforcementSharedStore.saveManagedAppsSelection(newValue)
    applyCurrentMode()
  }

  /// Turns the combined managed-apps daily limit on (default 30m) or off. Advisory
  /// OPEN governor; disabled while a locked session is active (the apps are blocked
  /// outright then, so the limit is moot — spec §4/§7).
  func setManagedAppsLimitEnabled(_ enabled: Bool) {
    guard !sessionLockedActive else { return }
    if enabled {
      if managedAppsLimitMinutes == nil {
        managedAppsLimitMinutes = 30
      }
    } else {
      managedAppsLimitMinutes = nil
    }
  }

  /// Raises/lowers the limit by `delta` minutes (clamped 5–480). Clears any
  /// already-applied limit shield first so the change takes effect immediately
  /// (raising regains access; `applyCurrentMode()` re-arms at the new threshold).
  /// No-op when the limit is off or a locked session is active.
  func adjustManagedAppsLimit(by delta: Int) {
    guard !sessionLockedActive, let current = managedAppsLimitMinutes else { return }
    managedAppsLimitStore.clearAllSettings()
    managedAppsLimitMinutes = ManagedAppsShield.clampManagedAppsLimitMinutes(current + delta)
  }
```

- [ ] **Step 9: Wire `applyCurrentMode()` (arm the limit monitor on both branches; fold in the adult-filter + Safari-policy + syncHealth independence fix)**

Find the whole method:

```swift
  private func applyCurrentMode() {
    guard !isApplying else {
      return
    }
    isApplying = true
    defer {
      isApplying = false
      updateStatusMessage()
    }

    applyManagedAppsShield()

    let shouldEnforce = shieldingEnabled && enforcementMode != .open && canApplyShielding
    if !shouldEnforce {
      IOSEnforcementShieldApplier.clearAllStores()
      activityCenter.stopMonitoring([.tortoiseDaily])
      scheduleActive = false
      syncHealth = "Open mode"
      writeSafariPolicy(mode: .open)
      saveSnapshot(lastError: lastError)
      return
    }

    let adultWebFilterEnabled = enforcementMode == .strict
    IOSEnforcementShieldApplier.applySelection(
      selection,
      to: immediateStore,
      adultWebFilterEnabled: adultWebFilterEnabled
    )
    startDailyMonitoring()
    writeSafariPolicy()
    saveSnapshot(lastError: lastError)
    syncHealth = "Screen Time and Safari policy current"
  }
```

Replace with:

```swift
  private func applyCurrentMode() {
    guard !isApplying else {
      return
    }
    isApplying = true
    defer {
      isApplying = false
      updateStatusMessage()
    }

    let managedAppsShielded = applyManagedAppsShield()
    reconcileManagedAppsLimitMonitoring()

    let shouldEnforce = shieldingEnabled && enforcementMode != .open && canApplyShielding
    if !shouldEnforce {
      IOSEnforcementShieldApplier.clearAllStores()
      activityCenter.stopMonitoring([.tortoiseDaily])
      scheduleActive = false
      // Independence fix: the Strict adult filter rides MODE, not the YouTube
      // selection — re-apply it after clearAllStores() wiped immediateStore, and
      // write the REAL-mode Safari policy (not a forced `.open`), so Strict's
      // adult web/media filter holds even with no YouTube target picked.
      reconcileAdultWebFilter()
      writeSafariPolicy()
      let adultActive = ManagedAppsShield.shouldApplyAdultFilter(
        mode: enforcementMode, adultEnabled: shieldingEnabled)
      syncHealth = (managedAppsShielded || adultActive)
        ? "Screen Time and Safari policy current"
        : "Open mode"
      saveSnapshot(lastError: lastError)
      return
    }

    let adultWebFilterEnabled = enforcementMode == .strict
    IOSEnforcementShieldApplier.applySelection(
      selection,
      to: immediateStore,
      adultWebFilterEnabled: adultWebFilterEnabled
    )
    startDailyMonitoring()
    writeSafariPolicy()
    saveSnapshot(lastError: lastError)
    syncHealth = "Screen Time and Safari policy current"
  }
```

- [ ] **Step 10: Make `applyManagedAppsShield()` return whether it shielded**

Find:

```swift
  private func applyManagedAppsShield() {
    let shouldShield = ManagedAppsShield.shouldShield(mode: enforcementMode)
      && authorizationState.isApproved
      && hasManagedAppsSelection
    if shouldShield {
      IOSEnforcementShieldApplier.applyShield(managedAppsSelection, to: managedAppsStore)
    } else {
      managedAppsStore.clearAllSettings()
    }
  }
```

Replace with:

```swift
  @discardableResult
  private func applyManagedAppsShield() -> Bool {
    let shouldShield = ManagedAppsShield.shouldShield(mode: enforcementMode)
      && authorizationState.isApproved
      && hasManagedAppsSelection
    if shouldShield {
      IOSEnforcementShieldApplier.applyShield(managedAppsSelection, to: managedAppsStore)
    } else {
      managedAppsStore.clearAllSettings()
    }
    return shouldShield
  }

  /// Stage 2: arms/re-arms the combined managed-apps daily-limit monitor in its OWN
  /// DeviceActivity (`.tortoiseManagedAppsDaily`) so it runs regardless of mode —
  /// the limit is an OPEN governor (in Focus/Strict the Stage 1 shield already
  /// blocks the apps, making the limit shield a harmless redundant union). Armed
  /// only when the limit is enabled, the selection is non-empty, and Screen Time is
  /// authorized; otherwise the monitor is stopped and `.tortoiseManagedAppsLimit`
  /// cleared so no stale limit shield survives (spec §11).
  private func reconcileManagedAppsLimitMonitoring() {
    let shouldArm = ManagedAppsShield.shouldArmManagedAppsLimit(
      limitEnabled: managedAppsLimitMinutes != nil,
      hasSelection: hasManagedAppsSelection
    ) && authorizationState.isApproved

    guard shouldArm, let minutes = managedAppsLimitMinutes else {
      activityCenter.stopMonitoring([.tortoiseManagedAppsDaily])
      managedAppsLimitStore.clearAllSettings()
      return
    }

    let schedule = DeviceActivitySchedule(
      intervalStart: DateComponents(hour: 0, minute: 0),
      intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
      repeats: true
    )
    let event = DeviceActivityEvent(
      applications: managedAppsSelection.applicationTokens,
      categories: managedAppsSelection.categoryTokens,
      webDomains: managedAppsSelection.webDomainTokens,
      threshold: DateComponents(minute: minutes)
    )
    do {
      try activityCenter.startMonitoring(
        .tortoiseManagedAppsDaily,
        during: schedule,
        events: [.managedAppsDailyLimit: event]
      )
      lastError = nil
    } catch {
      lastError = error.localizedDescription
    }
  }

  /// Stage 2 independence fix: applies the OS-level adult web/media content filter
  /// to `immediateStore` driven PURELY by mode (Strict + adult on) — independent of
  /// the YouTube `selection`. Called on the non-enforce branch (where
  /// `clearAllStores()` wiped the filter) so Strict's adult filter holds with no
  /// YouTube target. On the enforce branch `applySelection(...)` already sets it.
  private func reconcileAdultWebFilter() {
    let apply = ManagedAppsShield.shouldApplyAdultFilter(
      mode: enforcementMode, adultEnabled: shieldingEnabled)
    immediateStore.webContent.blockedByFilter = apply ? .auto() : nil
    immediateStore.media.denyExplicitContent = apply ? true : nil
  }
```

- [ ] **Step 11: Decouple `connectionState` from the YouTube selection**

Find:

```swift
    if authorizationState != .approved || !hasSelection {
      return .setupRequired
    }
```

Replace with:

```swift
    if authorizationState != .approved || (!hasSelection && !hasManagedAppsSelection) {
      return .setupRequired
    }
```

- [ ] **Step 12: Decouple `updateStatusMessage()` from the YouTube selection (three `where` guards)**

Find:

```swift
    case .approved where shieldingEnabled && enforcementMode == .strict && hasSelection:
      statusMessage = "Strict is active. Selected apps/sites are shielded, Safari tuners are on, and the daily limit monitor is running."
    case .approved where shieldingEnabled && hasSelection:
      statusMessage = "Focus is active. Selected apps/sites are shielded and Safari tuners are synced."
    case .approved where hasSelection:
      statusMessage = "Ready. Turn on iOS enforcement to shield selected apps/sites and sync Safari tuners."
```

Replace with:

```swift
    case .approved where shieldingEnabled && enforcementMode == .strict && (hasSelection || hasManagedAppsSelection):
      statusMessage = "Strict is active. Selected apps/sites are shielded, Safari tuners are on, and the daily limit monitor is running."
    case .approved where shieldingEnabled && (hasSelection || hasManagedAppsSelection):
      statusMessage = "Focus is active. Selected apps/sites are shielded and Safari tuners are synced."
    case .approved where (hasSelection || hasManagedAppsSelection):
      statusMessage = "Ready. Turn on iOS enforcement to shield selected apps/sites and sync Safari tuners."
```

- [ ] **Step 13: Persist the limit in the shared snapshot**

Find:

```swift
    snapshot.session = session
    if let previousMode = IOSEnforcementSharedStore.loadSnapshot().lastSafariPolicyMode {
```

Replace with:

```swift
    snapshot.session = session
    snapshot.managedAppsLimitMinutes = managedAppsLimitMinutes
    if let previousMode = IOSEnforcementSharedStore.loadSnapshot().lastSafariPolicyMode {
```

- [ ] **Step 14: Persist the limit across launches (`PersistedIOSEnforcementState` + both sites)**

14a. Find the struct:

```swift
private struct PersistedIOSEnforcementState: Codable {
  let authorizationMode: IOSEnforcementAuthorizationMode
  let enforcementMode: IOSEnforcementMode
  let shieldingEnabled: Bool
  let dailyLimitMinutes: Int
  let safariExtensionAcknowledged: Bool
}
```

Replace with (optional field → missing key decodes to `nil` for pre-Stage-2 persisted state):

```swift
private struct PersistedIOSEnforcementState: Codable {
  let authorizationMode: IOSEnforcementAuthorizationMode
  let enforcementMode: IOSEnforcementMode
  let shieldingEnabled: Bool
  let dailyLimitMinutes: Int
  let managedAppsLimitMinutes: Int?
  let safariExtensionAcknowledged: Bool
}
```

14b. Find in `persistState()`:

```swift
    let state = PersistedIOSEnforcementState(
      authorizationMode: authorizationMode,
      enforcementMode: enforcementMode,
      shieldingEnabled: shieldingEnabled,
      dailyLimitMinutes: dailyLimitMinutes,
      safariExtensionAcknowledged: safariExtensionAcknowledged
    )
```

Replace with:

```swift
    let state = PersistedIOSEnforcementState(
      authorizationMode: authorizationMode,
      enforcementMode: enforcementMode,
      shieldingEnabled: shieldingEnabled,
      dailyLimitMinutes: dailyLimitMinutes,
      managedAppsLimitMinutes: managedAppsLimitMinutes,
      safariExtensionAcknowledged: safariExtensionAcknowledged
    )
```

14c. Find in `loadState()`:

```swift
    return PersistedIOSEnforcementState(
      authorizationMode: .individual,
      enforcementMode: .open,
      shieldingEnabled: false,
      dailyLimitMinutes: 30,
      safariExtensionAcknowledged: false
    )
```

Replace with:

```swift
    return PersistedIOSEnforcementState(
      authorizationMode: .individual,
      enforcementMode: .open,
      shieldingEnabled: false,
      dailyLimitMinutes: 30,
      managedAppsLimitMinutes: nil,
      safariExtensionAcknowledged: false
    )
```

#### Part C — snapshot round-trip tests + verify

- [ ] **Step 15: Add snapshot round-trip tests (macOS, backward-compat)**

In `QuietGateTests/ManagedAppsShieldTests.swift`, find the class closing brace added in Task 1:

```swift
  func testEnforcementInactiveWhenNothingActive() {
    XCTAssertFalse(ManagedAppsShield.isEnforcementActive(
      youtubeSelected: false, managedAppsSelected: false, adultFilterOn: false))
  }
}
```

Replace with:

```swift
  func testEnforcementInactiveWhenNothingActive() {
    XCTAssertFalse(ManagedAppsShield.isEnforcementActive(
      youtubeSelected: false, managedAppsSelected: false, adultFilterOn: false))
  }

  // MARK: IOSEnforcementSnapshot.managedAppsLimitMinutes

  func testSnapshotDefaultsManagedAppsLimitToNil() {
    XCTAssertNil(IOSEnforcementSnapshot.empty.managedAppsLimitMinutes)
  }

  func testSnapshotRoundTripsManagedAppsLimit() throws {
    var snapshot = IOSEnforcementSnapshot.empty
    snapshot.managedAppsLimitMinutes = 45
    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(IOSEnforcementSnapshot.self, from: data)
    XCTAssertEqual(decoded.managedAppsLimitMinutes, 45)
  }

  func testLegacySnapshotJSONWithoutLimitDecodesToNil() throws {
    // A snapshot persisted before Stage 2 has no managedAppsLimitMinutes key; the
    // JSON below carries exactly the non-defaulted required keys.
    let legacy = """
    {"mode":"open","authorizationMode":"individual","shieldingEnabled":false,\
    "dailyLimitMinutes":30,"adultWebFilterEnabled":false,"safariExtensionEnabled":false,\
    "selectedApplicationCount":0,"selectedCategoryCount":0,"selectedWebDomainCount":0,\
    "scheduleActive":false}
    """
    let decoded = try JSONDecoder().decode(IOSEnforcementSnapshot.self, from: Data(legacy.utf8))
    XCTAssertNil(decoded.managedAppsLimitMinutes)
  }
}
```

- [ ] **Step 16: Run the full macOS suite (shared code compiles + Codable round-trip green)**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
Expected: whole suite green, including the three new snapshot tests. (The macOS target compiles `IOSEnforcementShared.swift`; the new store/activity/event names are inside `#if os(iOS)` and compile out here — this step verifies the snapshot field + macOS-visible edits didn't regress. The controller is iOS-only and is verified next.)

- [ ] **Step 17: iOS build**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
Expected: `BUILD SUCCEEDED`. (Also compiles the embedded `TortoiseDeviceActivityMonitor`/`TortoiseSafariExtension`, which include `IOSEnforcementShared.swift`; the new names are unreferenced there yet and must not break their build.)

- [ ] **Step 18: Commit**

```bash
git add Tortoise/IOSEnforcementShared.swift Tortoise/IOSYouTubeScreenTimeController.swift QuietGateTests/ManagedAppsShieldTests.swift
git commit -m "feat(ios-apps): arm managed-apps daily limit + decouple adult filter & status

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Extension routing — shield the managed-apps limit into `.tortoiseManagedAppsLimit` (iOS build-verified)

Route the new `.managedAppsDailyLimit` event (on `.tortoiseManagedAppsDaily`) STRICTLY by name to shield the managed-apps selection (shield-fields-only, no adult filter) into `.tortoiseManagedAppsLimit`; clear that store on `intervalDidStart`/`intervalDidEnd` (daily reset). The YouTube path (`.tortoiseDailyLimit` → `.tortoiseLimit`) is refactored into a named helper with its behavior byte-for-byte unchanged.

**Files:**
- Modify: `TortoiseDeviceActivityMonitor/DeviceActivityMonitorExtension.swift`

**Interfaces consumed (Task 2):** `ManagedSettingsStore.Name.tortoiseManagedAppsLimit`, `DeviceActivityName.tortoiseManagedAppsDaily`, `DeviceActivityEvent.Name.managedAppsDailyLimit`, `IOSEnforcementSnapshot.managedAppsLimitMinutes`; Stage 1 `IOSEnforcementSharedStore.loadManagedAppsSelection()`, `IOSEnforcementShieldApplier.applyShield(_:to:)`.

- [ ] **Step 1: Add the limit store property**

Find:

```swift
  private let scheduleStore = ManagedSettingsStore(named: .tortoiseSchedule)
  private let limitStore = ManagedSettingsStore(named: .tortoiseLimit)
```

Replace with:

```swift
  private let scheduleStore = ManagedSettingsStore(named: .tortoiseSchedule)
  private let limitStore = ManagedSettingsStore(named: .tortoiseLimit)
  private let managedAppsLimitStore = ManagedSettingsStore(named: .tortoiseManagedAppsLimit)
```

- [ ] **Step 2: Clear the limit store at the managed-apps interval boundaries**

Find:

```swift
  override func intervalDidStart(for activity: DeviceActivityName) {
    guard activity == .tortoiseDaily else {
      return
    }
```

Replace with:

```swift
  override func intervalDidStart(for activity: DeviceActivityName) {
    if activity == .tortoiseManagedAppsDaily {
      // Fresh day for the managed-apps limit: no limit shield until the combined
      // threshold is reached again.
      managedAppsLimitStore.clearAllSettings()
      return
    }

    guard activity == .tortoiseDaily else {
      return
    }
```

Then find:

```swift
  override func intervalDidEnd(for activity: DeviceActivityName) {
    guard activity == .tortoiseDaily else {
      return
    }
    scheduleStore.clearAllSettings()
    limitStore.clearAllSettings()
  }
```

Replace with:

```swift
  override func intervalDidEnd(for activity: DeviceActivityName) {
    if activity == .tortoiseManagedAppsDaily {
      managedAppsLimitStore.clearAllSettings()
      return
    }
    guard activity == .tortoiseDaily else {
      return
    }
    scheduleStore.clearAllSettings()
    limitStore.clearAllSettings()
  }
```

- [ ] **Step 3: Route `eventDidReachThreshold` by event name**

Find the whole method:

```swift
  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    guard activity == .tortoiseDaily, event == .tortoiseDailyLimit else {
      return
    }

    let snapshot = IOSEnforcementSharedStore.loadSnapshot()
    guard snapshot.shieldingEnabled, snapshot.mode != .open else {
      limitStore.clearAllSettings()
      return
    }

    IOSEnforcementShieldApplier.applySelection(
      IOSEnforcementSharedStore.loadSelection(),
      to: limitStore,
      adultWebFilterEnabled: true
    )
    IOSEnforcementSharedStore.recordThresholdEvent(
      IOSEnforcementThresholdEvent(
        eventName: event.rawValue,
        activityName: activity.rawValue,
        reachedAt: Date()
      )
    )
  }
```

Replace with:

```swift
  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    switch event {
    case .tortoiseDailyLimit:
      handleYouTubeLimitReached(event: event, activity: activity)
    case .managedAppsDailyLimit:
      handleManagedAppsLimitReached(event: event, activity: activity)
    default:
      return
    }
  }

  /// YouTube daily limit (Focus/Strict) — shields the YouTube selection into
  /// `.tortoiseLimit`. Behavior unchanged from Stage 1.
  private func handleYouTubeLimitReached(
    event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    guard activity == .tortoiseDaily else {
      return
    }

    let snapshot = IOSEnforcementSharedStore.loadSnapshot()
    guard snapshot.shieldingEnabled, snapshot.mode != .open else {
      limitStore.clearAllSettings()
      return
    }

    IOSEnforcementShieldApplier.applySelection(
      IOSEnforcementSharedStore.loadSelection(),
      to: limitStore,
      adultWebFilterEnabled: true
    )
    IOSEnforcementSharedStore.recordThresholdEvent(
      IOSEnforcementThresholdEvent(
        eventName: event.rawValue,
        activityName: activity.rawValue,
        reachedAt: Date()
      )
    )
  }

  /// Stage 2: combined managed-apps daily limit (OPEN governor). Shields the
  /// managed-apps selection into its OWN `.tortoiseManagedAppsLimit` store —
  /// shield fields ONLY, no adult filter — so the OS unions it with the Stage 1
  /// `.tortoiseManagedApps` shield. Applies regardless of mode (redundant-harmless
  /// in Focus/Strict). Gated defensively on the limit being enabled and the
  /// selection non-empty; otherwise the store is cleared (no stale limit shield).
  private func handleManagedAppsLimitReached(
    event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    guard activity == .tortoiseManagedAppsDaily else {
      return
    }

    let snapshot = IOSEnforcementSharedStore.loadSnapshot()
    let selection = IOSEnforcementSharedStore.loadManagedAppsSelection()
    let hasSelection = !selection.applicationTokens.isEmpty
      || !selection.categoryTokens.isEmpty
      || !selection.webDomainTokens.isEmpty
    guard snapshot.managedAppsLimitMinutes != nil, hasSelection else {
      managedAppsLimitStore.clearAllSettings()
      return
    }

    IOSEnforcementShieldApplier.applyShield(selection, to: managedAppsLimitStore)
    IOSEnforcementSharedStore.recordThresholdEvent(
      IOSEnforcementThresholdEvent(
        eventName: event.rawValue,
        activityName: activity.rawValue,
        reachedAt: Date()
      )
    )
  }
```

- [ ] **Step 4: iOS build**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add TortoiseDeviceActivityMonitor/DeviceActivityMonitorExtension.swift
git commit -m "feat(ios-apps): route managed-apps limit event to its own shield store

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Daily-limit control in the Apps card (iOS build-verified)

Add the limit control to the Stage 1 Apps `MobileCard` in `MobileTuningScreen`, styled like the YouTube daily-limit control: an on/off `MobileSwitch` + a minutes stepper (`MobileStepperButton` -5/+5, `Text("\(...)m")`), shown only when a managed-apps selection exists, off by default, disabled while `sessionLockedActive`. All state lives on the controller (Task 2); this task is pure view code.

**Files:**
- Modify: `Tortoise/ContentView.swift` (`MobileTuningScreen` Apps card — insert after the selected-rows block, inside the card's `VStack`)

**Interfaces consumed (Task 2):** `screenTime.hasManagedAppsSelection`, `.managedAppsLimitEnabled`, `.managedAppsLimitDisplayMinutes`, `.managedAppsLimitSummary`, `.setManagedAppsLimitEnabled(_:)`, `.adjustManagedAppsLimit(by:)`, `.sessionLockedActive`; existing `MobileDivider`, `MobileSwitch`, `MobileStepperButton`, `TortoiseDesign`.

- [ ] **Step 1: Insert the limit control into the Apps card**

Find (the end of the selected-rows block + the card/picker close):

```swift
            }
            .padding(.top, 2)
          }
        }
      }
      .familyActivityPicker(isPresented: $appsPickerPresented, selection: managedAppsBinding)
```

Replace with:

```swift
            }
            .padding(.top, 2)
          }

          if screenTime.hasManagedAppsSelection {
            MobileDivider()

            HStack(spacing: 10) {
              VStack(alignment: .leading, spacing: 3) {
                Text("Daily limit")
                  .font(.system(size: 13, weight: .bold))
                  .foregroundStyle(TortoiseDesign.primaryText)
                Text(screenTime.managedAppsLimitSummary)
                  .font(.system(size: 12))
                  .foregroundStyle(TortoiseDesign.secondaryText)
                  .fixedSize(horizontal: false, vertical: true)
              }
              Spacer(minLength: 8)
              MobileSwitch(
                isOn: Binding(
                  get: { screenTime.managedAppsLimitEnabled },
                  set: { screenTime.setManagedAppsLimitEnabled($0) }
                )
              )
              .disabled(screenTime.sessionLockedActive)
            }

            if screenTime.managedAppsLimitEnabled {
              HStack(spacing: 8) {
                Spacer()
                MobileStepperButton(systemImage: "minus") {
                  screenTime.adjustManagedAppsLimit(by: -5)
                }
                .disabled(screenTime.sessionLockedActive)
                Text("\(screenTime.managedAppsLimitDisplayMinutes)m")
                  .font(.system(size: 13, weight: .bold))
                  .frame(width: 48)
                MobileStepperButton(systemImage: "plus") {
                  screenTime.adjustManagedAppsLimit(by: 5)
                }
                .disabled(screenTime.sessionLockedActive)
              }
            }
          }
        }
      }
      .familyActivityPicker(isPresented: $appsPickerPresented, selection: managedAppsBinding)
```

- [ ] **Step 2: iOS build**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Tortoise/ContentView.swift
git commit -m "feat(ios-apps): add managed-apps daily-limit control to the Apps card

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 4: Manual on-device QA checklist (record results; not a blocker for the commit above)**

  1. **Open limit bites.** Tune → Apps: pick apps. The "Daily limit" row appears (off). Toggle on → default 30m; set a small value (5m) via the stepper. Stay in **Open**, use the picked apps past the threshold → they shield (`.tortoiseManagedAppsLimit`). Next day (or after `intervalDidEnd`) → usable again.
  2. **Raise-to-regain.** After the limit bites in Open, tap **+** to raise it → the limit shield lifts immediately (store cleared on adjust); it re-arms and re-bites only if you exceed the new threshold.
  3. **Focus/Strict still block.** Switch to **Focus** → the picked apps are blocked outright (Stage 1 `.tortoiseManagedApps` union) regardless of the limit. Back to **Open** with limit off → apps usable, no limit shield.
  4. **YouTube unchanged.** The YouTube daily limit (`.tortoiseLimit` / `dailyLimitMinutes`) behaves exactly as before; a YouTube-only selection still shields in Focus/Strict and still caps in its own path.
  5. **Independence — adult filter.** Enter **Strict** with a managed-apps selection but NO YouTube target → the adult web/media filter now applies (previously it required a YouTube selection). Confirm an adult domain is blocked in Safari/apps.
  6. **Independence — status.** With managed apps selected (no YouTube), the connection status no longer reports "iOS setup needed"/"Open" while apps are shielded (Focus/Strict) — it reports partial/active, and the checklist "Sync" shows current.
  7. **Locked session.** Start **Lock Strict · 2h** → the Daily-limit toggle/steppers are disabled; the apps are blocked outright (limit moot). Session ends → the control re-enables.

---

## Self-Review

**1. Spec coverage** (against `docs/superpowers/specs/2026-07-06-ios-apps-stage2-limits-design.md`):

- **§2/§3 combined limit + wiring.** `@Published managedAppsLimitMinutes: Int?` (nil=off, clamped 5–480) → Task 2 Steps 5/8; persisted in the shared snapshot (§6) → Steps 1/13 + `PersistedIOSEnforcementState` Step 14. Distinct `DeviceActivityEvent.Name.managedAppsDailyLimit` over the managed-apps selection, armed only when limit enabled + selection non-empty (+authorized) → Steps 3 + 10 (`reconcileManagedAppsLimitMonitoring` via `ManagedAppsShield.shouldArmManagedAppsLimit`). New `.tortoiseManagedAppsLimit` store, extension routes THAT event by name → Task 3 Step 3 (`handleManagedAppsLimitReached` → `applyShield` into `managedAppsLimitStore`); cleared on `intervalDidStart`/`intervalDidEnd`/disable/empty → Task 3 Step 2 + Task 2 Step 10 disarm branch. OS unions with `.tortoiseManagedApps` (separate store, not in `tortoiseEnforcementStores`) → Step 2. ✔ **Open-governor correctness:** the limit runs on its OWN `.tortoiseManagedAppsDaily` activity reconciled on BOTH branches of `applyCurrentMode()`, so it is armed in Open (where `.tortoiseDaily` is stopped) — the load-bearing design decision. ✔
- **§4 UI limit control** styled like the YouTube control, off by default, disabled while `sessionLockedActive`, only shown when a selection exists → Task 4 Step 1 (`MobileSwitch` + `MobileStepperButton` inside `if screenTime.hasManagedAppsSelection`). Honest copy "Allowed <N>m/day in Open · blocked in Focus & Strict" → Task 2 `managedAppsLimitSummary`. ✔
- **§5 independence fix.** Adult filter: `reconcileAdultWebFilter()` drives `immediateStore.webContent.blockedByFilter`/`media.denyExplicitContent` from `shouldApplyAdultFilter(mode:adultEnabled:)` on the non-enforce branch, AND the non-enforce branch now writes the real-mode Safari policy (`writeSafariPolicy()` not `writeSafariPolicy(mode: .open)`) → Task 2 Step 9. Status: `connectionState` (Step 11) + `updateStatusMessage` (Step 12) + `syncHealth` (Step 9) OR-in `hasManagedAppsSelection`/adult-active. **Additive — the YouTube shield (`.tortoiseImmediate`/`applySelection`/`selection`) and the Stage 1 managed-apps shield are untouched.** ✔
- **§6 persistence & pure logic.** `Int?` in snapshot (no `FamilyControls`/`ManagedSettings` leak); the four pure decisions extend `ManagedAppsShield`, TDD'd on macOS → Task 1. ✔
- **§7 precommitment.** Limit is freely editable (advisory), disabled while locked (moot then) → `setManagedAppsLimitEnabled`/`adjustManagedAppsLimit` guard `!sessionLockedActive`; the Stage 1 selection freeze is untouched. ✔
- **§8 testing.** Pure decisions + snapshot Codable round-trip on macOS (Tasks 1 + 2 Step 15); DeviceActivity/extension/UI build-verified + the §8 on-device QA → Task 4 Step 4. ✔
- **§9 success criteria / §10 out-of-scope.** No per-app limits, no time-of-day schedules, no locked limits, no YouTube unification, no Mac/browser-extension change — nothing in the plan adds them. ✔
- **§11 risks.** Store hygiene (cleared on `intervalDidStart`/`intervalDidEnd`/disarm/empty); strict event-name routing (`switch event` + per-activity guards); independence blast radius (additive OR; YouTube-unchanged QA); combined-usage copy states "Open"/"combined" honestly. ✔

**2. Placeholder scan:** No "TBD"/"handle the rest"/"similar to above". Every code step is complete verbatim Swift; every run step gives an exact command + expected result. ✔

**3. Type/name consistency across tasks:**
- `clampManagedAppsLimitMinutes(_:)` / `shouldArmManagedAppsLimit(limitEnabled:hasSelection:)` / `shouldApplyAdultFilter(mode:adultEnabled:)` / `isEnforcementActive(...)` defined in Task 1; called with those exact labels in Task 2 (Steps 5, 8, 9, 10). ✔
- `.tortoiseManagedAppsLimit` / `.tortoiseManagedAppsDaily` / `.managedAppsDailyLimit` / `IOSEnforcementSnapshot.managedAppsLimitMinutes` defined in Task 2 (Part A); consumed by the controller (Part B) and the extension (Task 3). ✔
- `managedAppsLimitEnabled` / `managedAppsLimitDisplayMinutes` / `managedAppsLimitSummary` / `setManagedAppsLimitEnabled(_:)` / `adjustManagedAppsLimit(by:)` defined in Task 2 (Steps 7–8); consumed only in Task 4. ✔
- `applyManagedAppsShield()` becomes `@discardableResult ... -> Bool` (Task 2 Step 10); its one existing call site is rewritten to `let managedAppsShielded = applyManagedAppsShield()` in the same step. `reconcileManagedAppsLimitMonitoring()` / `reconcileAdultWebFilter()` each defined once (Step 10) and called once (Step 9). ✔

**4. Memberwise-init / Codable safety:** `managedAppsLimitMinutes` is added to `IOSEnforcementSnapshot` in the TRAILING defaulted region (`= nil`), so the existing `saveSnapshot` init call (which stops at `lastError`) and `.empty` still compile; the value is set post-construction via `snapshot.managedAppsLimitMinutes = …` (Step 13), mirroring the sibling `snapshot.session = …` assignments. `PersistedIOSEnforcementState.managedAppsLimitMinutes: Int?` is optional → synthesized `decodeIfPresent` maps a missing key (pre-Stage-2 persisted state) to `nil`; both init call sites (Step 14b/14c) pass it explicitly. Backward-compat asserted by `testLegacySnapshotJSONWithoutLimitDecodesToNil` (Step 15). ✔

**5. Build-cost discipline:** 3 iOS builds total (Tasks 2, 3, 4) + one fast macOS test task (Task 1). Spec items 2+3 folded into Task 2 (shared names only exist to serve the controller); the macOS snapshot test runs BEFORE each slow build to catch Codable regressions cheaply. Extension (Task 3) kept separate from the controller for independent reviewability of the name-routing. ✔

**Fixes applied inline:** none required — the scan passed.

**Residual risks (carry into QA):**
- **Advisory-limit leniency.** `adjustManagedAppsLimit` clears `.tortoiseManagedAppsLimit` so a limit change instantly lifts a prior limit shield (honoring §7 "freely editable"). This is intentional for an advisory Open governor, but means lowering the limit after it bit grants brief access until DeviceActivity re-fires at the new threshold. Confirm the re-fire timing on-device (Apple's mid-interval `startMonitoring` re-arm semantics are not contractually precise).
- **Non-enforce Focus Safari policy change.** Switching the non-enforce branch from `writeSafariPolicy(mode: .open)` to `writeSafariPolicy()` also means a Focus session with NO YouTube selection now writes a Focus (not Open) Safari policy. This is more-correct (Focus tuners apply) and additive, but verify it doesn't surprise the Safari extension (QA step 5/6).
- **`.tortoiseManagedAppsLimit` excluded from `tortoiseEnforcementStores`** (deliberate, like `.tortoiseManagedApps`). Any FUTURE hard-reset/sign-out that calls `clearAllStores()` must also clear this store and stop `.tortoiseManagedAppsDaily` — out of scope here; flag for the Stage 3 unification.
- **Re-arm churn.** `reconcileManagedAppsLimitMonitoring()` calls `startMonitoring(.tortoiseManagedAppsDaily …)` on every `applyCurrentMode()` (mirrors the YouTube `startDailyMonitoring()` pattern). Confirm no excessive DeviceActivity re-registration cost during rapid mode/selection toggles on-device.
- **DeviceActivity event caps.** Adds one activity + one event well under Apple's per-app limits, but the managed-apps event fires only while the limit is armed; verify both the YouTube and managed-apps events coexist and fire independently on-device.
