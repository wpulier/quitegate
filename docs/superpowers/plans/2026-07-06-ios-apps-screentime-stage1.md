# iOS "Apps" Screen-Time Layer — Stage 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a general `FamilyActivityPicker` "Apps" card in the iOS Tune surface whose picked apps/categories/web-domains are shielded in Focus/Strict, cleared in Open (block-under-mode), frozen during a locked Strict session (grow allowed, shrink/clear refused) — additive and non-breaking versus the existing YouTube shield.

**Architecture:** Give the managed-apps shield its **own** named `ManagedSettingsStore` (`.tortoiseManagedApps`), separate from the YouTube shield's `.tortoiseImmediate` store, so the system **unions** the two shields automatically — no manual merge logic. Pure decision logic (mode→shield, grow-vs-shrink, edit-allowed) lives in a new cross-platform `Tortoise/ManagedAppsShield.swift` (free of `FamilyControls`/`ManagedSettings`) and is TDD'd on macOS, mirroring `IOSSession`. A separate app-group-persisted `FamilyActivitySelection` (`managedAppsSelection`) is loaded/saved iOS-only in `IOSEnforcementShared.swift`, held on the existing `IOSEnforcementController`, applied inside `applyCurrentMode()`, and edited through a guarded `setManagedAppsSelection(_:)`. The "Apps" card in `MobileTuningScreen` presents the picker through a custom binding that routes every write through that guard, and `.disabled`s the trigger during a locked session.

**Tech Stack:** Swift 5, SwiftUI, FamilyControls / ManagedSettings (iOS-only), XCTest (macOS), XcodeGen.

## Global Constraints

- Tests are a macOS XCTest bundle `QuietGateTests` (`@testable import QuietGate`). There is **no iOS unit-test target** — the pure decision logic lives in shared `Tortoise/` code and is TDD'd on macOS; the `FamilyControls`/`ManagedSettings` wiring on `IOSEnforcementController` and the SwiftUI card are **build-verified only** (on-device shield behavior is manual QA).
- **iOS builds are SLOW (~15–25 min).** Run `xcodebuild` via the **Bash tool ONLY** (never an Xcode/xcodebuild MCP tool — that has hung); one build at a time, foreground, let it finish.
- After adding a **new** source file, regenerate: `xcodegen generate --spec project.yml --project .` (add the file to the `QuietGate` macOS target `sources:` as `type: file`; stage `QuietGate.xcodeproj`). Files already under the `Tortoise/` folder auto-compile into the `Tortoise` iOS app target (which includes the whole `- Tortoise` folder). Editing an existing file needs no regenerate.
- `FamilyControls` / `ManagedSettings` are **iOS-only** — keep the new shared file and the shared `IOSEnforcementSnapshot`/cross-platform code free of them (platform-split with `#if os(iOS)`, following the existing pattern in `IOSEnforcementShared.swift`).
- macOS tests: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
- iOS build: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
- Product name **Tortoise**; minimal on-screen text; **no fake/demo data**; **additive/non-breaking** vs the YouTube shield (its `.tortoiseImmediate` store and `applySelection` path stay untouched); **a locked session's precommitment must genuinely hold** (the managed-apps selection cannot be shrunk/cleared while locked, and the OS shield persists through app-kill).

## Available from earlier phases (committed)

- `Tortoise/IOSEnforcementShared.swift`:
  - `enum IOSEnforcementMode { open, focus, strict }` (Codable).
  - `IOSEnforcementSharedStore.loadSelection()`/`saveSelection(_:)` — the existing YouTube `FamilyActivitySelection`, iOS-only behind `#if os(iOS)`, keyed `"TortoiseIOSEnforcementSelection"`; `private static var defaults: UserDefaults { TortoiseAppGroup.defaults }`.
  - `enum IOSEnforcementShieldApplier` (`#if os(iOS)`): `applySelection(_:to:adultWebFilterEnabled:)` writes `store.shield.applications/webDomains/applicationCategories/webDomainCategories` **plus** the adult web/media filter; `clearAllStores()` clears every name in `tortoiseEnforcementStores`; `fileprivate extension Set { var nilIfEmpty }`.
  - `extension ManagedSettingsStore.Name` with `.tortoiseImmediate` / `.tortoiseSchedule` / `.tortoiseLimit` and `static let tortoiseEnforcementStores: [Self] = [.tortoiseImmediate, .tortoiseSchedule, .tortoiseLimit]`.
- `Tortoise/IOSYouTubeScreenTimeController.swift` — `typealias IOSYouTubeScreenTimeController = IOSEnforcementController` (`@MainActor final class`, iOS-only, `import FamilyControls` at top):
  - `@Published var selection: FamilyActivitySelection` (YouTube), loaded in `init()`; `private let immediateStore = ManagedSettingsStore(named: .tortoiseImmediate)`.
  - `var sessionLockedActive: Bool` (from `IOSSession.isLockedActive`); `authorizationState.isApproved`.
  - `func clearSelection()` guards `!sessionLockedActive`; `func requestAuthorization() async` (Family Controls authorization — reused for the picker).
  - `private func applyCurrentMode()` — the single seam that writes the shield (mode change, session start/expiry, launch); computes `shouldEnforce`, clears via `clearAllStores()` in Open, applies the YouTube `selection` to `immediateStore` in Focus/Strict.
- `Tortoise/IOSSession.swift` — `IOSSession.isLockedActive(_:now:)` etc.; the precommitment source of truth.
- `Tortoise/ContentView.swift` — `MobileTuningScreen` (the Tune screen); `MobileCard`, `MobileSectionLabel`, `TortoiseDesign` tokens (`primaryText`, `secondaryText`, `accent`, `green`); the existing YouTube setup card uses `.familyActivityPicker(isPresented:selection:)` and gates writes with `guard !screenTime.sessionLockedActive`.
- `QuietGateTests/IOSSessionTests.swift` — the pattern to mirror for the new pure-logic tests.
- `project.yml` — `QuietGate` (macOS) target `sources:` lists shared `Tortoise/*.swift` files individually as `type: file` (incl. `IOSEnforcementShared.swift`, `IOSSession.swift`); the `Tortoise` iOS target includes the whole `- Tortoise` folder.

---

### Task 1: Pure decision logic — `ManagedAppsShield` (macOS TDD)

Cross-platform decision functions with **no** `FamilyControls`/`ManagedSettings` dependency, TDD'd on macOS. `isShrink` is generic over `Set<Token: Hashable>` so the same function serves the macOS test (with `Set<Int>`) and the iOS controller (with `Set<ApplicationToken>` etc.).

**Files:**
- Create: `Tortoise/ManagedAppsShield.swift`
- Create test: `QuietGateTests/ManagedAppsShieldTests.swift`
- Modify: `project.yml` (add `Tortoise/ManagedAppsShield.swift` to the `QuietGate` target `sources:` as `type: file`)

**Interfaces:**
- Produces (consumed by Tasks 2–3):
  - `enum ManagedAppsShield`
  - `static func shouldShield(mode: IOSEnforcementMode) -> Bool` — `true` for `.focus`/`.strict`, `false` for `.open`.
  - `static func isShrink<Token: Hashable>(old: Set<Token>, new: Set<Token>) -> Bool` — `true` when any committed token is dropped (`old` is not a subset of `new`).
  - `static func canApplyEdit(lockedActive: Bool, isShrink: Bool) -> Bool` — unlocked → always `true`; locked → `!isShrink`.

- [ ] **Step 1: Write the failing test**

Create `QuietGateTests/ManagedAppsShieldTests.swift`:

```swift
import XCTest
@testable import QuietGate

final class ManagedAppsShieldTests: XCTestCase {
  // MARK: shouldShield(mode:)

  func testShouldShieldIsTrueForFocusAndStrict() {
    XCTAssertTrue(ManagedAppsShield.shouldShield(mode: .focus))
    XCTAssertTrue(ManagedAppsShield.shouldShield(mode: .strict))
  }

  func testShouldShieldIsFalseForOpen() {
    XCTAssertFalse(ManagedAppsShield.shouldShield(mode: .open))
  }

  // MARK: isShrink(old:new:)

  func testAddingIsNotShrink() {
    XCTAssertFalse(ManagedAppsShield.isShrink(old: Set([1, 2]), new: Set([1, 2, 3])))
  }

  func testUnchangedIsNotShrink() {
    XCTAssertFalse(ManagedAppsShield.isShrink(old: Set([1, 2]), new: Set([1, 2])))
  }

  func testEmptyToNonEmptyIsNotShrink() {
    XCTAssertFalse(ManagedAppsShield.isShrink(old: Set<Int>(), new: Set([1])))
  }

  func testRemovingIsShrink() {
    XCTAssertTrue(ManagedAppsShield.isShrink(old: Set([1, 2, 3]), new: Set([1, 2])))
  }

  func testClearingIsShrink() {
    XCTAssertTrue(ManagedAppsShield.isShrink(old: Set([1]), new: Set<Int>()))
  }

  func testSwapKeepingCountIsShrink() {
    // Same count, but a committed token was dropped → still a shrink.
    XCTAssertTrue(ManagedAppsShield.isShrink(old: Set([1, 2]), new: Set([1, 3])))
  }

  // MARK: canApplyEdit(lockedActive:isShrink:)

  func testUnlockedAllowsShrink() {
    XCTAssertTrue(ManagedAppsShield.canApplyEdit(lockedActive: false, isShrink: true))
  }

  func testUnlockedAllowsGrow() {
    XCTAssertTrue(ManagedAppsShield.canApplyEdit(lockedActive: false, isShrink: false))
  }

  func testLockedRefusesShrink() {
    XCTAssertFalse(ManagedAppsShield.canApplyEdit(lockedActive: true, isShrink: true))
  }

  func testLockedAllowsGrow() {
    XCTAssertTrue(ManagedAppsShield.canApplyEdit(lockedActive: true, isShrink: false))
  }
}
```

- [ ] **Step 2: Create the file with deliberately-wrong stub bodies (compiles, so the assertions can fail red)**

Create `Tortoise/ManagedAppsShield.swift`:

```swift
import Foundation

enum ManagedAppsShield {
  static func shouldShield(mode: IOSEnforcementMode) -> Bool {
    false
  }

  static func isShrink<Token: Hashable>(old: Set<Token>, new: Set<Token>) -> Bool {
    false
  }

  static func canApplyEdit(lockedActive: Bool, isShrink: Bool) -> Bool {
    true
  }
}
```

- [ ] **Step 3: Register the new file in the macOS target**

In `project.yml`, under `targets: → QuietGate: → sources:`, add after the `Tortoise/IOSSession.swift` entry:

```yaml
      - path: Tortoise/ManagedAppsShield.swift
        type: file
```

- [ ] **Step 4: Regenerate the project**

Run: `xcodegen generate --spec project.yml --project .`
Expected: `Created project at ./QuietGate.xcodeproj`.

- [ ] **Step 5: Run the test to verify it fails**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData -only-testing:QuietGateTests/ManagedAppsShieldTests test`
Expected: builds, then FAILS — e.g. `testShouldShieldIsTrueForFocusAndStrict`, `testRemovingIsShrink`, `testLockedRefusesShrink` fail their assertions.

- [ ] **Step 6: Write the real implementation**

Replace the body of `Tortoise/ManagedAppsShield.swift` with:

```swift
import Foundation

/// Pure, cross-platform decision logic for the general "Apps" Screen-Time
/// layer (Stage 1). Kept free of `FamilyControls`/`ManagedSettings` (iOS-only)
/// so it compiles and is unit-tested on macOS, mirroring `IOSSession`.
///
/// The managed-apps selection is shielded under Focus/Strict and cleared under
/// Open ("block under mode"). During a *locked* Strict session the commitment is
/// frozen: the selection may grow but must not shrink or clear (precommitment).
enum ManagedAppsShield {
  /// Whether the managed-apps shield is applied for `mode`.
  /// Focus and Strict shield; Open clears.
  static func shouldShield(mode: IOSEnforcementMode) -> Bool {
    switch mode {
    case .focus, .strict:
      return true
    case .open:
      return false
    }
  }

  /// A change from `old` to `new` *shrinks* the commitment when any previously
  /// committed token is dropped — i.e. `old` is not a subset of `new`. Pure
  /// additions (`old ⊆ new`) grow and are never a shrink; swapping one token for
  /// another (equal count, different membership) drops a committed token and is
  /// therefore a shrink.
  static func isShrink<Token: Hashable>(old: Set<Token>, new: Set<Token>) -> Bool {
    !old.isSubset(of: new)
  }

  /// Whether an edit may be applied given the locked state. Unlocked: any edit is
  /// allowed. Locked-active: growing/unchanged is allowed, shrinking/clearing is
  /// refused.
  static func canApplyEdit(lockedActive: Bool, isShrink: Bool) -> Bool {
    if lockedActive {
      return !isShrink
    }
    return true
  }
}
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData -only-testing:QuietGateTests/ManagedAppsShieldTests test`
Expected: `ManagedAppsShieldTests` 12/12 PASS.

- [ ] **Step 8: Run the full macOS suite to confirm no regressions**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
Expected: whole suite green (incl. `IOSSessionTests`).

- [ ] **Step 9: Commit**

```bash
git add project.yml QuietGate.xcodeproj Tortoise/ManagedAppsShield.swift QuietGateTests/ManagedAppsShieldTests.swift
git commit -m "feat(ios-apps): add ManagedAppsShield pure decision logic (TDD)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Persist the managed-apps selection + its own shield store + controller wiring (iOS build-verified)

Add the iOS-only persistence pair and the `.tortoiseManagedApps` store name to `IOSEnforcementShared.swift`, a shield-only applier (no adult filter — that stays a YouTube/Strict concern on the `.tortoiseImmediate` path), then wire the controller: hold `managedAppsSelection`, load it on init, apply it to the new store inside `applyCurrentMode()`, and edit it through the locked-session-guarded `setManagedAppsSelection(_:)`.

**Why persistence + store + controller are one task:** the persistence API, the new store name, and the shield applier are all iOS-only and are only exercised by the controller; the controller is the smallest unit whose behavior an on-device reviewer can meaningfully accept/reject, and each iOS build costs ~15–25 min, so they share one build.

**Files:**
- Modify: `Tortoise/IOSEnforcementShared.swift` (persistence pair ~:219–241; store name ~:360–370; shield applier ~:329–352)
- Modify: `Tortoise/IOSYouTubeScreenTimeController.swift` (store property ~:68; init load ~:75–76; `applyCurrentMode` ~:534–544; new methods + computed props)

**Interfaces:**
- Consumes (from Task 1): `ManagedAppsShield.shouldShield(mode:)`, `ManagedAppsShield.isShrink(old:new:)`, `ManagedAppsShield.canApplyEdit(lockedActive:isShrink:)`.
- Produces (consumed by Task 3, all on `IOSEnforcementController`):
  - `@Published private(set) var managedAppsSelection: FamilyActivitySelection`
  - `func setManagedAppsSelection(_ newValue: FamilyActivitySelection)` — the guarded write.
  - `var hasManagedAppsSelection: Bool`
  - `var managedAppsSummary: String`
  - `IOSEnforcementSharedStore.loadManagedAppsSelection() -> FamilyActivitySelection` / `saveManagedAppsSelection(_:)` (iOS-only)
  - `IOSEnforcementShieldApplier.applyShield(_:to:)` (iOS-only, shield fields only)
  - `ManagedSettingsStore.Name.tortoiseManagedApps`

- [ ] **Step 1: Add the app-group key for the managed-apps selection**

In `Tortoise/IOSEnforcementShared.swift`, in `enum IOSEnforcementSharedStore`, find:

```swift
  private static let selectionKey = "TortoiseIOSEnforcementSelection"
```

Add directly below it:

```swift
  private static let managedAppsSelectionKey = "TortoiseIOSManagedAppsSelection"
```

- [ ] **Step 2: Add the iOS-only load/save pair**

In the same file, find the existing YouTube persistence block:

```swift
  static func saveSelection(_ selection: FamilyActivitySelection) {
    guard let data = try? JSONEncoder().encode(selection) else {
      return
    }
    defaults.set(data, forKey: selectionKey)
  }
  #endif
```

Replace it with (adds the managed-apps pair inside the same `#if os(iOS)` block, before `#endif`):

```swift
  static func saveSelection(_ selection: FamilyActivitySelection) {
    guard let data = try? JSONEncoder().encode(selection) else {
      return
    }
    defaults.set(data, forKey: selectionKey)
  }

  static func loadManagedAppsSelection() -> FamilyActivitySelection {
    guard let data = defaults.data(forKey: managedAppsSelectionKey),
          let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
      return FamilyActivitySelection()
    }
    return selection
  }

  static func saveManagedAppsSelection(_ selection: FamilyActivitySelection) {
    guard let data = try? JSONEncoder().encode(selection) else {
      return
    }
    defaults.set(data, forKey: managedAppsSelectionKey)
  }
  #endif
```

- [ ] **Step 3: Add the `.tortoiseManagedApps` store name (its own store, NOT in the clear-sweep)**

In the same file, find:

```swift
extension ManagedSettingsStore.Name {
  static let tortoiseImmediate = Self("tortoise.immediate")
  static let tortoiseSchedule = Self("tortoise.schedule")
  static let tortoiseLimit = Self("tortoise.limit")

  static let tortoiseEnforcementStores: [Self] = [
    .tortoiseImmediate,
    .tortoiseSchedule,
    .tortoiseLimit
  ]
}
```

Replace with:

```swift
extension ManagedSettingsStore.Name {
  static let tortoiseImmediate = Self("tortoise.immediate")
  static let tortoiseSchedule = Self("tortoise.schedule")
  static let tortoiseLimit = Self("tortoise.limit")

  /// The general "Apps" (Screen-Time) shield lives in its OWN store so the system
  /// UNIONS it with the YouTube shield in `.tortoiseImmediate` automatically —
  /// no manual merge. Deliberately NOT part of `tortoiseEnforcementStores`: this
  /// store is owned solely by `applyManagedAppsShield()`, which reconciles it on
  /// every `applyCurrentMode()`, so the YouTube `clearAllStores()` sweep never
  /// touches it.
  static let tortoiseManagedApps = Self("tortoise.managedApps")

  static let tortoiseEnforcementStores: [Self] = [
    .tortoiseImmediate,
    .tortoiseSchedule,
    .tortoiseLimit
  ]
}
```

- [ ] **Step 4: Add a shield-only applier (no adult filter)**

In the same file, in `enum IOSEnforcementShieldApplier`, find:

```swift
  static func clearAllStores() {
    for name in ManagedSettingsStore.Name.tortoiseEnforcementStores {
      ManagedSettingsStore(named: name).clearAllSettings()
    }
  }
```

Insert this method directly above `clearAllStores()`:

```swift
  /// Writes ONLY the shield fields from `selection` into `store` — no adult web/
  /// media filter (that stays on the YouTube/Strict `applySelection` path). Used
  /// for the general "Apps" store so the two shields union cleanly.
  static func applyShield(
    _ selection: FamilyActivitySelection,
    to store: ManagedSettingsStore
  ) {
    store.shield.applications = selection.applicationTokens.nilIfEmpty
    store.shield.webDomains = selection.webDomainTokens.nilIfEmpty
    store.shield.applicationCategories = selection.categoryTokens.isEmpty
      ? nil
      : .specific(selection.categoryTokens)
    store.shield.webDomainCategories = selection.categoryTokens.isEmpty
      ? nil
      : .specific(selection.categoryTokens)
  }

```

- [ ] **Step 5: Add the managed-apps store property on the controller**

In `Tortoise/IOSYouTubeScreenTimeController.swift`, find:

```swift
  private let immediateStore = ManagedSettingsStore(named: .tortoiseImmediate)
```

Replace with:

```swift
  private let immediateStore = ManagedSettingsStore(named: .tortoiseImmediate)
  private let managedAppsStore = ManagedSettingsStore(named: .tortoiseManagedApps)
```

- [ ] **Step 6: Add the published property**

In the same file, find:

```swift
  @Published var selection: FamilyActivitySelection {
    didSet {
      persistState()
      applyCurrentMode()
    }
  }
```

Insert directly below it:

```swift
  /// The general "Apps" selection (separate from the YouTube `selection`). Edited
  /// only via `setManagedAppsSelection(_:)` so the locked-session freeze holds.
  @Published private(set) var managedAppsSelection: FamilyActivitySelection = FamilyActivitySelection()
```

- [ ] **Step 7: Load it on init**

In `init()`, find:

```swift
    let persisted = Self.loadState()
    selection = IOSEnforcementSharedStore.loadSelection()
```

Replace with:

```swift
    let persisted = Self.loadState()
    selection = IOSEnforcementSharedStore.loadSelection()
    managedAppsSelection = IOSEnforcementSharedStore.loadManagedAppsSelection()
```

(This runs before the `applyCurrentMode()` call later in `init()`, so `applyManagedAppsShield()` sees the persisted selection.)

- [ ] **Step 8: Add the computed helpers for the card**

In the same file, find:

```swift
  var hasSelection: Bool {
    !selection.applicationTokens.isEmpty ||
      !selection.categoryTokens.isEmpty ||
      !selection.webDomainTokens.isEmpty
  }
```

Insert directly below it:

```swift
  var hasManagedAppsSelection: Bool {
    !managedAppsSelection.applicationTokens.isEmpty ||
      !managedAppsSelection.categoryTokens.isEmpty ||
      !managedAppsSelection.webDomainTokens.isEmpty
  }

  /// Honest one-line state for the "Apps" card. Omits any zero count.
  var managedAppsSummary: String {
    guard hasManagedAppsSelection else {
      return "Choose apps to block in Focus & Strict."
    }
    let apps = managedAppsSelection.applicationTokens.count
    let categories = managedAppsSelection.categoryTokens.count
    let domains = managedAppsSelection.webDomainTokens.count
    var parts: [String] = []
    if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
    if categories > 0 { parts.append("\(categories) categor\(categories == 1 ? "y" : "ies")") }
    if domains > 0 { parts.append("\(domains) web domain\(domains == 1 ? "" : "s")") }
    return parts.joined(separator: " · ") + " blocked in Focus & Strict"
  }
```

- [ ] **Step 9: Add the guarded setter (grow-allowed, shrink/clear-refused while locked)**

In the same file, find:

```swift
  func clearSelection() {
    guard !sessionLockedActive else { return }
    selection = FamilyActivitySelection()
    shieldingEnabled = false
  }
```

Insert directly below it:

```swift
  /// Applies a new managed-apps selection. While a locked session is active the
  /// selection may only GROW — any shrink/clear (a committed token dropped) is
  /// refused (precommitment). Unlocked, any edit is accepted. On acceptance the
  /// selection is persisted and the shield re-applied through `applyCurrentMode()`.
  func setManagedAppsSelection(_ newValue: FamilyActivitySelection) {
    let shrinks =
      ManagedAppsShield.isShrink(
        old: managedAppsSelection.applicationTokens, new: newValue.applicationTokens) ||
      ManagedAppsShield.isShrink(
        old: managedAppsSelection.categoryTokens, new: newValue.categoryTokens) ||
      ManagedAppsShield.isShrink(
        old: managedAppsSelection.webDomainTokens, new: newValue.webDomainTokens)

    guard ManagedAppsShield.canApplyEdit(lockedActive: sessionLockedActive, isShrink: shrinks) else {
      return
    }

    managedAppsSelection = newValue
    IOSEnforcementSharedStore.saveManagedAppsSelection(newValue)
    applyCurrentMode()
  }
```

- [ ] **Step 10: Reconcile the managed-apps shield inside `applyCurrentMode()`**

In the same file, find the start of `applyCurrentMode()`:

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

    let shouldEnforce = shieldingEnabled && enforcementMode != .open && canApplyShielding
```

Replace with (inserts the managed-apps reconcile before the YouTube `shouldEnforce` branch — it runs on BOTH the Open/clear and the Focus/Strict paths because it precedes the early return, and it owns a store the YouTube `clearAllStores()` sweep never touches):

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
```

- [ ] **Step 11: Add the `applyManagedAppsShield()` helper**

In the same file, find the end of `applyCurrentMode()` and the start of the next method:

```swift
    startDailyMonitoring()
    writeSafariPolicy()
    saveSnapshot(lastError: lastError)
    syncHealth = "Screen Time and Safari policy current"
  }

  private func startDailyMonitoring() {
```

Insert the helper between `applyCurrentMode()`'s closing brace and `startDailyMonitoring()`:

```swift
    startDailyMonitoring()
    writeSafariPolicy()
    saveSnapshot(lastError: lastError)
    syncHealth = "Screen Time and Safari policy current"
  }

  /// Reconciles the general "Apps" shield in its own `.tortoiseManagedApps` store.
  /// Governed by MODE (Focus/Strict) + authorization + a non-empty managed-apps
  /// selection — independent of the YouTube `selection`, so managed apps are
  /// shielded even when no YouTube target is picked. The system unions this store
  /// with the YouTube shield automatically.
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

  private func startDailyMonitoring() {
```

- [ ] **Step 12: Run the full macOS suite (confirm shared code still compiles + Task 1 stays green)**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
Expected: whole suite green. (The macOS target compiles `IOSEnforcementShared.swift`; the new persistence/store/applier are inside `#if os(iOS)` so they compile out here — this step verifies the macOS-visible edits didn't regress. The controller is iOS-only and is verified in the next step.)

- [ ] **Step 13: iOS build**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
Expected: `BUILD SUCCEEDED`. (This also compiles the embedded extensions, which include `IOSEnforcementShared.swift`; the new iOS-only additions are unreferenced there and must not break their build.)

- [ ] **Step 14: Commit**

```bash
git add Tortoise/IOSEnforcementShared.swift Tortoise/IOSYouTubeScreenTimeController.swift
git commit -m "feat(ios-apps): persist managed-apps selection + union shield store + guarded edits

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: "Apps" card in `MobileTuningScreen` (iOS build-verified)

Add the "Apps" card to the Tune screen: a "Choose apps"/"Edit" trigger (disabled unless authorized and not locked), the honest empty/selected summary, and rows for picked apps/categories (`Label(token)`) plus a web-domain count row. The picker binds through a custom `Binding` that routes every write through `setManagedAppsSelection(_:)`, so the freeze holds even mid-edit.

**Files:**
- Modify: `Tortoise/ContentView.swift` (`MobileTuningScreen` — state ~:563; card insert between the iPhone-info card and the sites `LazyVGrid` ~:654–656; helper members before the struct closes ~:816)

**Interfaces:**
- Consumes (from Task 2): `screenTime.managedAppsSelection`, `screenTime.setManagedAppsSelection(_:)`, `screenTime.hasManagedAppsSelection`, `screenTime.managedAppsSummary`, `screenTime.authorizationState`, `screenTime.sessionLockedActive`.

- [ ] **Step 1: Add picker-presentation state to `MobileTuningScreen`**

In `Tortoise/ContentView.swift`, find (inside `private struct MobileTuningScreen`):

```swift
  let setYoutubeProtection: (Bool) -> Void
  let setDailyLimit: (Int) -> Void

  private var tunePolicy: TortoisePolicy? { model.snapshot.policy?.policy }
```

Replace with:

```swift
  let setYoutubeProtection: (Bool) -> Void
  let setDailyLimit: (Int) -> Void

  @State private var appsPickerPresented = false

  private var tunePolicy: TortoisePolicy? { model.snapshot.policy?.policy }
```

- [ ] **Step 2: Insert the "Apps" card before the sites grid**

In the same struct's `body`, find the iPhone-info card immediately followed by the sites grid:

```swift
      MobileCard {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: "iphone.gen3")
            .foregroundStyle(TortoiseDesign.accent)
          Text("On iPhone, blocks run through the Tortoise app and Screen Time. Keep Tortoise allowed in Settings > Screen Time for full enforcement.")
            .font(.system(size: 13))
            .foregroundStyle(TortoiseDesign.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 150), spacing: 10)],
        spacing: 10
      ) {
```

Replace with (inserts the Apps card + its `.familyActivityPicker` between the two):

```swift
      MobileCard {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: "iphone.gen3")
            .foregroundStyle(TortoiseDesign.accent)
          Text("On iPhone, blocks run through the Tortoise app and Screen Time. Keep Tortoise allowed in Settings > Screen Time for full enforcement.")
            .font(.system(size: 13))
            .foregroundStyle(TortoiseDesign.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      MobileCard {
        VStack(alignment: .leading, spacing: 14) {
          HStack(spacing: 8) {
            MobileSectionLabel("Apps")
            Spacer(minLength: 8)
            Button(screenTime.hasManagedAppsSelection ? "Edit" : "Choose apps") {
              presentAppsPicker()
            }
            .font(.system(size: 12, weight: .bold))
            .buttonStyle(.bordered)
            .disabled(screenTime.authorizationState != .approved || screenTime.sessionLockedActive)
          }

          Text(screenTime.managedAppsSummary)
            .font(.system(size: 13))
            .foregroundStyle(TortoiseDesign.secondaryText)
            .fixedSize(horizontal: false, vertical: true)

          if screenTime.hasManagedAppsSelection {
            VStack(alignment: .leading, spacing: 10) {
              ForEach(Array(screenTime.managedAppsSelection.applicationTokens), id: \.self) { token in
                Label(token)
                  .labelStyle(.titleAndIcon)
                  .font(.system(size: 14))
                  .foregroundStyle(TortoiseDesign.primaryText)
              }
              ForEach(Array(screenTime.managedAppsSelection.categoryTokens), id: \.self) { token in
                Label(token)
                  .labelStyle(.titleAndIcon)
                  .font(.system(size: 14))
                  .foregroundStyle(TortoiseDesign.primaryText)
              }
              if !screenTime.managedAppsSelection.webDomainTokens.isEmpty {
                let domainCount = screenTime.managedAppsSelection.webDomainTokens.count
                Text("\(domainCount) web domain\(domainCount == 1 ? "" : "s")")
                  .font(.system(size: 13, weight: .semibold))
                  .foregroundStyle(TortoiseDesign.secondaryText)
              }
            }
            .padding(.top, 2)
          }
        }
      }
      .familyActivityPicker(isPresented: $appsPickerPresented, selection: managedAppsBinding)

      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 150), spacing: 10)],
        spacing: 10
      ) {
```

- [ ] **Step 3: Add the guarded binding + present helper**

In the same struct, find the end of `toggleAll()` and the struct's closing brace:

```swift
  private func toggleAll() {
    let countableFeatures = enforceableSiteFeatures.count
    guard countableFeatures > 0 else {
      return
    }
    let next = enabledEnforceableFeatureCount != countableFeatures
    setFeatures(enforceableSiteFeatures.map(\.id), next)
  }
}
```

Replace with (adds the two members before the closing brace):

```swift
  private func toggleAll() {
    let countableFeatures = enforceableSiteFeatures.count
    guard countableFeatures > 0 else {
      return
    }
    let next = enabledEnforceableFeatureCount != countableFeatures
    setFeatures(enforceableSiteFeatures.map(\.id), next)
  }

  /// Routes every picker write through the controller's guard so the locked
  /// session freeze holds even while the picker is open. The getter reflects the
  /// controller's (possibly refused) authoritative selection back into the picker.
  private var managedAppsBinding: Binding<FamilyActivitySelection> {
    Binding(
      get: { screenTime.managedAppsSelection },
      set: { screenTime.setManagedAppsSelection($0) }
    )
  }

  private func presentAppsPicker() {
    guard !screenTime.sessionLockedActive else { return }
    appsPickerPresented = true
  }
}
```

- [ ] **Step 4: iOS build**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
Expected: `BUILD SUCCEEDED`. (If `Label(_ webDomain:)` were the chosen row and failed, we already avoided it — web domains render as a count row, which always compiles. `Label(_ application:)` / `Label(_ category:)` are the documented FamilyControls initializers.)

- [ ] **Step 5: Commit**

```bash
git add Tortoise/ContentView.swift
git commit -m "feat(ios-apps): add Apps card to Tune with guarded FamilyActivityPicker

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 6: Manual on-device QA checklist (record results; not a blocker for the commit above)**

  1. Tune → Apps → "Choose apps": if Screen Time is not yet authorized, the trigger is disabled — approve via the existing YouTube setup, then it enables. Pick apps/categories/domains → the card shows "N apps · M categories … blocked in Focus & Strict" and the rows.
  2. Enter **Focus** → picked apps show the Tortoise shield; the existing YouTube shield is **unchanged** (verify a YouTube-only selection still shields). Return to **Open** → the managed-apps shield clears, YouTube behavior intact.
  3. Start a **Lock Strict · 2h** session → "Choose apps"/"Edit" is disabled; re-selecting via any path cannot drop a committed app (grow still works). Kill the app → the shield persists. Session ends → editing re-enables.

---

## Self-Review

**1. Spec coverage** (against `2026-07-06-ios-apps-screentime-design.md`):
- §4 flow (Apps card, Choose apps → `FamilyActivityPicker`, authorization reuse, honest empty/selected states, `Label(token)` rows, count heading) → Task 3 (`.familyActivityPicker`, `managedAppsSummary`, rows) + the authorization-gated trigger. ✔
- §5 enforcement (Focus/Strict shield, Open clear, applied on the `applyCurrentMode()` seam, union with YouTube via a separate store) → Task 2 Steps 3/10/11 (`.tortoiseManagedApps` own store + `applyManagedAppsShield()` inside `applyCurrentMode`). ✔ The "merge" is achieved by the OS unioning two named stores — no manual merge, matching the Architecture note.
- §6 persistence (separate app-group key, iOS-only, shared snapshot free of iOS types) → Task 2 Steps 1/2 (`managedAppsSelectionKey`, `#if os(iOS)` load/save). Pure logic cross-platform → Task 1. ✔
- §7 precommitment (disabled trigger + controller refuses shrink/clear while locked; grow allowed; OS shield survives app-kill) → Task 2 Step 9 (`setManagedAppsSelection` guard via `canApplyEdit`/`isShrink`) + Task 3 `.disabled(... || sessionLockedActive)` and `presentAppsPicker` guard. ✔
- §9 testing (macOS XCTest for pure logic; iOS build-verified wiring) → Task 1 (12 tests) + Tasks 2/3 iOS builds + Task 3 Step 6 QA. ✔
- §11 success criteria + §12 out-of-scope (no DeviceActivity limits/schedules, no YouTube unification, no Mac/extension change) → nothing in the plan adds limits/schedules or touches Mac/extension source; YouTube `.tortoiseImmediate`/`applySelection`/`selection` untouched. ✔
- §13 risks: authorization-not-approved → trigger disabled until approved (Task 3) and `applyManagedAppsShield` requires `authorizationState.isApproved`; shield-merge correctness → separate stores unioned by the OS (Task 2); token opacity → per-device, web domains shown as a count row. ✔

**2. Placeholder scan:** No "TBD"/"handle edge cases"/"similar to Task N". Every code step shows complete, verbatim code; every run step gives an exact command + expected result. ✔

**3. Type consistency:** `ManagedAppsShield.shouldShield(mode:)` / `isShrink(old:new:)` / `canApplyEdit(lockedActive:isShrink:)` are defined in Task 1 and called with those exact labels in Task 2 (Steps 9, 11). `managedAppsSelection`, `setManagedAppsSelection(_:)`, `hasManagedAppsSelection`, `managedAppsSummary` are defined in Task 2 and consumed with those exact names in Task 3. `IOSEnforcementSharedStore.loadManagedAppsSelection()`/`saveManagedAppsSelection(_:)`, `IOSEnforcementShieldApplier.applyShield(_:to:)`, `.tortoiseManagedApps` are defined and used consistently. `applyManagedAppsShield()` is defined once (Task 2 Step 11) and called once (Step 10). ✔

**Fixes applied inline:** none required — the scan passed.

**Residual risks (carry into QA):**
- `applyManagedAppsShield` gates on `hasManagedAppsSelection`, so clearing the last app while unlocked calls `managedAppsStore.clearAllSettings()` — verify no orphaned shield remains (QA step 2).
- `.tortoiseManagedApps` is intentionally excluded from `tortoiseEnforcementStores`; any *future* hard-reset/sign-out path that calls `clearAllStores()` must also clear this store (out of scope for Stage 1, but note it for Stage 3 unification).
- The custom `Binding` re-applies the shield on every intermediate picker toggle (matches the existing YouTube `selection` didSet behavior) — acceptable, but confirm no visible thrash during multi-select on-device.
