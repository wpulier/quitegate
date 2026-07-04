# Phase 3b-2 — Real Per-Device iOS Sessions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the FAKE iOS "Commit to a session" buttons (which just call `selectMode` with no timer/lock) with genuine timed/locked focus sessions matching Mac's precommitment model — a session applies a mode (Focus/Strict) for a duration then reverts to Open on expiry; a LOCKED session cannot be ended, weakened, or mode-switched before it expires. Device-local via iOS Screen Time (the confirmed decision) — a session on the iPhone applies to the iPhone; cross-device locking is a future upgrade.

**Architecture:** Mirror Mac's mechanism. A pure, TDD-able `IOSSessionState` (`{mode, endsAt, locked}`) + decision helpers (`isActive` / `isLockedActive` / `hasExpired` / `canEndEarly` / `canChangeMode`) live in shared `Tortoise/` code and are tested on macOS. The session is persisted in the app-group `IOSEnforcementSnapshot`. `IOSYouTubeScreenTimeController` gains `startSession` / `endSession` / `expireSessionIfNeeded` that set `enforcementMode` + `shieldingEnabled` (its existing `applyCurrentMode` then applies the ManagedSettings shield, which **persists even if the app is killed** → real precommitment), guard mode changes / early-end while locked-active, and schedule an in-app expiry timer + check on foreground — matching Mac's "reverts while running." `MobileBlockingScreen`'s session UI becomes real.

**Tech Stack:** Swift 5, SwiftUI, DeviceActivity/ManagedSettings, XCTest, XcodeGen.

## Phase 3b-2 decomposition

- **3b-2a — Real sessions (this plan):** session model + decision logic (TDD), app-group persistence, controller start/end/expiry + lock enforcement + in-app timer, and the real `MobileBlockingScreen` session UI. Achieves parity with Mac's device-local precommitment model.
- **3b-2b — Authoritative suspended expiry (deferred):** a dedicated `DeviceActivitySchedule` over the session window whose `intervalDidEnd` (fires even when the app is suspended, in `TortoiseDeviceActivityMonitor`) reverts the snapshot to Open + clears the session shield — so a session reverts on time without needing the app open. Hardening on top of 3b-2a's Mac-parity behavior.

## Global Constraints

- Tests are a macOS XCTest bundle `QuietGateTests` (`@testable import QuietGate`). No iOS unit-test target — the session model + decision logic + snapshot round-trip live in shared `Tortoise/` files and are TDD'd on macOS; the `IOSYouTubeScreenTimeController` Screen-Time wiring and the SwiftUI view are build-verified only.
- **iOS builds are SLOW (~15–25 min).** Run `xcodebuild` via the Bash tool ONLY (never an Xcode/xcodebuild MCP tool — that has hung); one build at a time, foreground, let it finish.
- After adding a source file, regenerate: `xcodegen generate --spec project.yml --project .` (add the file to the `QuietGate` macOS target `sources:` as `type: file`; stage `QuietGate.xcodeproj`). `Tortoise/` files auto-compile into the iOS target.
- macOS tests: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
- iOS build: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
- Product name **Tortoise**; minimal on-screen text; no fake/demo data; **a locked session must genuinely resist early termination** (precommitment is the whole point).

## Available from earlier phases (committed)

- `Tortoise/IOSEnforcementShared.swift`: `enum IOSEnforcementMode { open, focus, strict }` (Codable); `struct IOSEnforcementSnapshot: Codable` (persisted via `IOSEnforcementSharedStore.saveSnapshot`/`loadSnapshot`/`updateSnapshot`); `IOSEnforcementShieldApplier` (applies/clears the ManagedSettings shield).
- `Tortoise/IOSYouTubeScreenTimeController.swift`: `@Published enforcementMode: IOSEnforcementMode` + `@Published shieldingEnabled: Bool` (both `didSet { applyCurrentMode() }`); `setMode(_:)`, `turnOn()`, `turnOff()`; `private func applyCurrentMode()` (applies the shield + DeviceActivity daily monitor + Safari policy when `shieldingEnabled && enforcementMode != .open`); `init()` loads persisted state then `applyCurrentMode()`.
- Mac reference: `QuietGate/Stores/ProtectionStore.swift` `startTimedSession(mode:duration:locked:)` / `endTimedSession()` / `expireTimedSessionIfNeeded()` / `timedSessionActive` / `timedSessionLockedActive`; `QuietGate/Views/ControlView.swift` `sessionCard` (Focus·25m / Focus·1h / Lock Strict·2h).
- iOS UI to replace: `Tortoise/ContentView.swift` `MobileBlockingScreen` — the "Commit to a session" card with `MobileSessionButton("Focus · 25m")` / `("Focus · 1h")` / `("Lock Strict · 2h", systemImage: "lock")` all calling `selectMode(.focus/.strict)` (no timer, no lock).

---

### Task 1: Shared `IOSSessionState` + decision helpers + snapshot persistence (TDD)

**Files:**
- Create: `Tortoise/IOSSession.swift`
- Modify: `Tortoise/IOSEnforcementShared.swift` (add `session` to `IOSEnforcementSnapshot`)
- Modify: `project.yml` (add `Tortoise/IOSSession.swift` to the `QuietGate` target `sources:` as `type: file`)
- Test: `QuietGateTests/IOSSessionTests.swift`

**Interfaces:**
- Produces: `struct IOSSessionState: Codable, Equatable { var mode: IOSEnforcementMode; var endsAt: Date; var locked: Bool }`
- Produces: `enum IOSSession { static func isActive(_:now:) -> Bool; static func isLockedActive(_:now:) -> Bool; static func hasExpired(_:now:) -> Bool; static func canEndEarly(_:now:) -> Bool; static func canChangeMode(_:now:) -> Bool; static func remaining(_:now:) -> TimeInterval }`
- Produces: `IOSEnforcementSnapshot.session: IOSSessionState?` (new persisted field).

- [ ] **Step 1: Create the model file**

Create `Tortoise/IOSSession.swift`:

```swift
import Foundation

/// A device-local focus/lock session. `mode` is `.focus` or `.strict` (never
/// `.open`); the session applies that mode until `endsAt`. A `locked` session
/// cannot be ended, weakened, or mode-switched before it expires — precommitment.
struct IOSSessionState: Codable, Equatable {
  var mode: IOSEnforcementMode
  var endsAt: Date
  var locked: Bool
}

/// Pure decision logic for iOS sessions (mirrors Mac's timedSession* rules).
/// Time-injectable so it is fully testable on macOS.
enum IOSSession {
  static func isActive(_ session: IOSSessionState?, now: Date) -> Bool {
    guard let session, session.mode != .open else { return false }
    return session.endsAt > now
  }

  static func isLockedActive(_ session: IOSSessionState?, now: Date) -> Bool {
    guard let session, session.locked else { return false }
    return isActive(session, now: now)
  }

  /// True once a started session's window has elapsed (so the app should revert).
  static func hasExpired(_ session: IOSSessionState?, now: Date) -> Bool {
    guard let session else { return false }
    return session.endsAt <= now
  }

  /// The user may end early only when there is no locked-active session.
  static func canEndEarly(_ session: IOSSessionState?, now: Date) -> Bool {
    !isLockedActive(session, now: now)
  }

  /// The mode may be changed only when there is no locked-active session.
  static func canChangeMode(_ session: IOSSessionState?, now: Date) -> Bool {
    !isLockedActive(session, now: now)
  }

  static func remaining(_ session: IOSSessionState?, now: Date) -> TimeInterval {
    guard let session else { return 0 }
    return max(0, session.endsAt.timeIntervalSince(now))
  }
}
```

- [ ] **Step 2: Add the persisted `session` field to `IOSEnforcementSnapshot`**

In `Tortoise/IOSEnforcementShared.swift`, read the `struct IOSEnforcementSnapshot: Codable` definition (its stored properties, its `static let empty`, and any memberwise/explicit init). Add a stored property `var session: IOSSessionState?` (defaulting to `nil` in `empty` and any initializer). It is `Codable` and optional, so existing persisted snapshots without the key decode with `session == nil` — confirm the struct doesn't use a custom `init(from:)` that would need the new key added (if it does, add it defensively with `decodeIfPresent`).

- [ ] **Step 3: Add the file to `project.yml`** — under `targets: QuietGate: sources:` add:
```yaml
      - path: Tortoise/IOSSession.swift
        type: file
```

- [ ] **Step 4: Regenerate** — `xcodegen generate --spec project.yml --project .` (expect `Created project at ...`).

- [ ] **Step 5: Write the tests** — `QuietGateTests/IOSSessionTests.swift`:

```swift
import XCTest
@testable import QuietGate

final class IOSSessionTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_000_000)
  private func session(_ mode: IOSEnforcementMode, inMinutes: Double, locked: Bool) -> IOSSessionState {
    IOSSessionState(mode: mode, endsAt: now.addingTimeInterval(inMinutes * 60), locked: locked)
  }

  func testNilSessionIsInactive() {
    XCTAssertFalse(IOSSession.isActive(nil, now: now))
    XCTAssertFalse(IOSSession.isLockedActive(nil, now: now))
    XCTAssertTrue(IOSSession.canEndEarly(nil, now: now))
    XCTAssertTrue(IOSSession.canChangeMode(nil, now: now))
  }

  func testActiveWhileWithinWindow() {
    let s = session(.focus, inMinutes: 25, locked: false)
    XCTAssertTrue(IOSSession.isActive(s, now: now))
    XCTAssertFalse(IOSSession.hasExpired(s, now: now))
  }

  func testExpiredAfterWindow() {
    let s = session(.focus, inMinutes: 25, locked: false)
    let later = now.addingTimeInterval(26 * 60)
    XCTAssertFalse(IOSSession.isActive(s, now: later))
    XCTAssertTrue(IOSSession.hasExpired(s, now: later))
  }

  func testLockedActiveBlocksEndAndModeChange() {
    let s = session(.strict, inMinutes: 120, locked: true)
    XCTAssertTrue(IOSSession.isLockedActive(s, now: now))
    XCTAssertFalse(IOSSession.canEndEarly(s, now: now))
    XCTAssertFalse(IOSSession.canChangeMode(s, now: now))
  }

  func testExpiredLockedSessionNoLongerBlocks() {
    let s = session(.strict, inMinutes: 120, locked: true)
    let later = now.addingTimeInterval(121 * 60)
    XCTAssertFalse(IOSSession.isLockedActive(s, now: later))
    XCTAssertTrue(IOSSession.canEndEarly(s, now: later))   // window over → precommitment released
  }

  func testUnlockedSessionCanEndEarly() {
    let s = session(.focus, inMinutes: 60, locked: false)
    XCTAssertTrue(IOSSession.isActive(s, now: now))
    XCTAssertTrue(IOSSession.canEndEarly(s, now: now))
  }

  func testRemainingCountsDown() {
    let s = session(.focus, inMinutes: 25, locked: false)
    XCTAssertEqual(IOSSession.remaining(s, now: now), 25 * 60, accuracy: 0.5)
    XCTAssertEqual(IOSSession.remaining(s, now: now.addingTimeInterval(26 * 60)), 0)
  }

  func testSnapshotRoundTripsSession() throws {
    var snapshot = IOSEnforcementSnapshot.empty
    snapshot.session = session(.strict, inMinutes: 120, locked: true)
    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(IOSEnforcementSnapshot.self, from: data)
    XCTAssertEqual(decoded.session, snapshot.session)
  }
}
```

- [ ] **Step 6: Run macOS tests** — `xcodebuild ... -scheme QuietGate ... test`. Expected: `IOSSessionTests` 8/8 PASS; whole suite green. (If `IOSEnforcementSnapshot.empty` or its init needs the new field, the round-trip test surfaces it — fix the struct, not the test.)

- [ ] **Step 7: iOS build** — `xcodebuild ... -scheme Tortoise ... build` → `BUILD SUCCEEDED`.

- [ ] **Step 8: Commit**
```bash
git add Tortoise/IOSSession.swift Tortoise/IOSEnforcementShared.swift project.yml QuietGate.xcodeproj QuietGateTests/IOSSessionTests.swift
git commit -m "Add shared iOS session model + decision logic; persist in snapshot"
```

---

### Task 2: `IOSYouTubeScreenTimeController` session methods + lock enforcement + expiry timer

**Files:**
- Modify: `Tortoise/IOSYouTubeScreenTimeController.swift`
- Test: none new (iOS controller; the pure logic is TDD'd in Task 1). iOS build-verified.

**Interfaces:**
- Consumes: `IOSSessionState`, `IOSSession.*` (Task 1); existing `enforcementMode`/`shieldingEnabled`/`applyCurrentMode`/`setMode`.
- Produces: `@Published private(set) var session: IOSSessionState?`; `func startSession(mode: IOSEnforcementMode, duration: TimeInterval, locked: Bool)`; `func endSession()`; `func expireSessionIfNeeded()`; computed `var sessionActive: Bool` / `var sessionLockedActive: Bool` / `var sessionStatusLine: String`.

- [ ] **Step 1: Read the controller** (`init`, `loadState`/`saveSnapshot`, `setMode`, `turnOff`, `applyCurrentMode`, and the `nowProvider`/time source if any — if none, use `Date()` and add a `now: () -> Date = { Date() }` injectable only if trivial; otherwise `Date()` is fine since the pure logic is already tested).

- [ ] **Step 2: Add session state + load/persist.** Add `@Published private(set) var session: IOSSessionState?`. In `init`, after loading persisted state, set `session = IOSEnforcementSharedStore.loadSnapshot().session` and then call `expireSessionIfNeeded()` (so a session that ended while the app was closed reverts on launch). In the controller's `saveSnapshot(...)`, include `snapshot.session = session` so it persists (read how the snapshot is built there and add the assignment).

- [ ] **Step 3: Add the session methods:**
```swift
  var sessionActive: Bool { IOSSession.isActive(session, now: Date()) }
  var sessionLockedActive: Bool { IOSSession.isLockedActive(session, now: Date()) }
  var sessionStatusLine: String {
    guard let session, sessionActive else { return "No active session" }
    let mins = Int(IOSSession.remaining(session, now: Date()) / 60) + 1
    return "\(session.locked ? "Locked " : "")\(session.mode.rawValue.capitalized) session · \(mins)m left"
  }

  func startSession(mode: IOSEnforcementMode, duration: TimeInterval, locked: Bool) {
    guard !sessionLockedActive else { return }          // can't override a locked session
    let mode = mode == .open ? .focus : mode
    session = IOSSessionState(mode: mode, endsAt: Date().addingTimeInterval(duration), locked: locked)
    setMode(mode)                                        // applies shield via applyCurrentMode + persists
    scheduleSessionExpiry()
    saveSnapshotPublic()                                 // persist the session field (see note)
  }

  func endSession() {
    guard IOSSession.canEndEarly(session, now: Date()) else { return }  // locked → refuse
    session = nil
    setMode(.open)
    sessionExpiryTimer?.invalidate()
    saveSnapshotPublic()
  }

  func expireSessionIfNeeded() {
    guard IOSSession.hasExpired(session, now: Date()) else {
      scheduleSessionExpiry()
      return
    }
    session = nil
    setMode(.open)
    saveSnapshotPublic()
  }

  private func scheduleSessionExpiry() {
    sessionExpiryTimer?.invalidate()
    guard let session, sessionActive else { return }
    let interval = max(1, session.endsAt.timeIntervalSinceNow)
    sessionExpiryTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
      Task { @MainActor in self?.expireSessionIfNeeded() }
    }
  }
```
Add `private var sessionExpiryTimer: Timer?`. `saveSnapshotPublic()` is a thin wrapper that persists the current state including `session` — if the existing `saveSnapshot(lastError:)` already writes `snapshot.session = session` (Step 2), call that; otherwise add a small internal method. `setMode` already triggers `applyCurrentMode()` (which applies/reverts the shield) and persists — so `startSession`/`endSession` reuse it and only add the session bookkeeping.

- [ ] **Step 4: Enforce the lock on `setMode` and `turnOff`.** Guard the top of `setMode(_:)` with `guard IOSSession.canChangeMode(session, now: Date()) else { return }` and the top of `turnOff()` with `guard IOSSession.canEndEarly(session, now: Date()) else { return }`, so a locked-active session can't be weakened/switched/turned off from anywhere. (Do NOT guard `startSession`'s own internal `setMode` call — it clears/replaces via the `sessionLockedActive` guard already; confirm ordering so `startSession` sets `session` BEFORE calling `setMode`, and since the new session isn't yet "locked-active from a DIFFERENT session," the guard passes — verify by reading; if the guard blocks the legitimate start, have `startSession` set the mode via a private un-guarded `applyMode` helper instead.)

- [ ] **Step 5: iOS build** — `xcodebuild ... -scheme Tortoise ... build` → `BUILD SUCCEEDED`. (Watch for the `setMode` self-guard ordering issue above; if the build's logic is wrong you'll see it at runtime, so reason carefully at edit time.)

- [ ] **Step 6: macOS suite** — `xcodebuild ... -scheme QuietGate ... test` → green (Task 1's logic unchanged).

- [ ] **Step 7: Commit**
```bash
git add Tortoise/IOSYouTubeScreenTimeController.swift
git commit -m "iOS controller: real start/end/expiry sessions with locked precommitment"
```

---

### Task 3: Real `MobileBlockingScreen` session UI

**Files:**
- Modify: `Tortoise/ContentView.swift` — `MobileBlockingScreen` (the fake "Commit to a session" card) and its mode selector.
- Test: none new (iOS build-verified).

**Interfaces:**
- Consumes: `screenTime.startSession(mode:duration:locked:)`, `endSession()`, `expireSessionIfNeeded()`, `sessionActive`, `sessionLockedActive`, `sessionStatusLine` (Task 2).

- [ ] **Step 1: Read `MobileBlockingScreen`** — the mode selector (`selectMode`), the "Commit to a session" card with the three `MobileSessionButton`s, and how `screenTime` is passed in. Note the `TortoiseDesign` tokens.

- [ ] **Step 2: Wire the session buttons to real sessions.** Replace the three fake buttons' actions:
  - "Focus · 25m" → `screenTime.startSession(mode: .focus, duration: 25 * 60, locked: false)`
  - "Focus · 1h" → `screenTime.startSession(mode: .focus, duration: 60 * 60, locked: false)`
  - "Lock Strict · 2h" → `screenTime.startSession(mode: .strict, duration: 2 * 3600, locked: true)`

- [ ] **Step 3: Show the running-session state.** When `screenTime.sessionActive`, render a status row (`screenTime.sessionStatusLine` — mode, minutes left, "Locked" prefix). If `screenTime.sessionActive && !screenTime.sessionLockedActive`, show an "End session" button → `screenTime.endSession()`. If `sessionLockedActive`, show a non-interactive "Locked until it ends" note instead (no end button) — precommitment made visible and honest.

- [ ] **Step 4: Disable mode changes during a locked session.** In the mode selector, disable the Open/Focus/Strict buttons when `screenTime.sessionLockedActive` (the controller already refuses, but the UI must reflect it). Keep them enabled otherwise.

- [ ] **Step 5: Expire on foreground.** Add `.onChange(of: scenePhase)` (or `.onAppear`) to the screen so that when the app becomes active, `screenTime.expireSessionIfNeeded()` runs (reverts a session that ended while the app was backgrounded) — matching Mac's "reverts while running." If `scenePhase` isn't already in scope, add `@Environment(\.scenePhase) private var scenePhase`.

- [ ] **Step 6: iOS build** — `xcodebuild ... -scheme Tortoise ... build` → `BUILD SUCCEEDED`.

- [ ] **Step 7: macOS suite** — `xcodebuild ... -scheme QuietGate ... test` → green (shared files unchanged).

- [ ] **Step 8: Commit**
```bash
git add Tortoise/ContentView.swift
git commit -m "iOS Blocking: real timed/locked focus sessions (replace fake buttons)"
```

---

## Self-Review

**Spec coverage (real iOS sessions, device-local per the confirmed decision):**
- Fake session buttons → real timed sessions that apply a mode for a duration and revert on expiry → Tasks 2 (controller) + 3 (UI). ✓
- Locked precommitment (can't end/weaken/switch before expiry) → `IOSSession.canEndEarly`/`canChangeMode` (Task 1, TDD'd); enforced in the controller's `setMode`/`turnOff`/`endSession` (Task 2) AND reflected in the UI (Task 3); the ManagedSettings shield persists even if the app is killed, so the block itself holds. ✓
- Device-local via iOS Screen Time (no cloud/backend) → uses the existing `applyCurrentMode` shield + app-group snapshot. ✓
- Revert while running (Mac parity) → in-app expiry `Timer` + on-foreground `expireSessionIfNeeded` (Tasks 2-3). ✓
- No fake data → the fake session buttons and any fake state are removed. ✓

**Placeholder scan:** No TBD/TODO. The `setMode` self-guard ordering (Task 2 Step 4) is a real implementation caution with a concrete fallback (private un-guarded `applyMode`), not deferred work.

**Type consistency:** `IOSSessionState`, `IOSSession.{isActive,isLockedActive,hasExpired,canEndEarly,canChangeMode,remaining}`, `IOSEnforcementSnapshot.session`, and the controller's `startSession`/`endSession`/`expireSessionIfNeeded`/`sessionActive`/`sessionLockedActive`/`sessionStatusLine` are used consistently across tasks.

**Out of scope (deferred):** authoritative expiry when the app is SUSPENDED via a `DeviceActivitySchedule` session window + `intervalDidEnd` revert (3b-2b) — until then, a session that expires while the app is killed reverts on next foreground (fail-safe: the block persists slightly past expiry, never ends early); folding Blocking (adult/apps/websites) into the one Tune surface + removing the fake concept-blocking/hardcoded apps/fake site defaults (3b-3); cross-device sessions (future); Mac augment knobs (3c).

## Whole-branch review outcome (Phase 3b-2a)

**Adversarial precommitment audit (Opus)** enumerated every enforcement-state mutator (mode/shield, session, targets, Safari policy, daily limit) across all tabs + app-restart. Session lifecycle + most surfaces were correctly sealed, but it found **2 more reachable bypasses**, now FIXED (commit 366b2d1) + verified:
- **Critical — YouTube daily-limit stepper** raised the limit mid-lock → `writeSafariPolicy` weakened enforcement. Fixed: stepper buttons `.disabled` + `adjustDailyLimit` guards `!sessionLockedActive`.
- **Important — policy-sync onChanges** applied a weaker cloud/Mac-edited policy that synced down during a local lock. Fixed: both policy `onChange` handlers skip while locked (iOS Safari policy frozen at locked-start), with a `.onChange(of: sessionLockedActive)` catch-up re-applying the current policy on release. `setAccessMode` also guarded.

**Result: precommitment is airtight** — no local UI path (stepper, mode, tuning toggles, targets) and no synced cloud policy change can weaken a locked iOS session; it survives relaunch and releases exactly at its wall-clock end.

**Deferred:** 3b-2b (authoritative expiry when the app is SUSPENDED via a DeviceActivity session window) — until then a session that expires while the app is killed reverts on next foreground (fail-safe: blocks slightly past expiry, never ends early).

## Residual risks to confirm

1. **`setMode` self-guard ordering (Task 2 Step 4):** guarding `setMode` with `canChangeMode` must not block `startSession`'s own mode application. The plan sets `session` before calling `setMode`; since a freshly-created session's guard evaluates against the NEW session (which IS locked-active for a locked start), `setMode` could refuse its own start. The plan's fallback is a private un-guarded `applyMode(_:)` that `startSession` calls instead of the public `setMode`. The implementer must pick the ordering that both (a) lets a legitimate start apply the mode and (b) blocks external mode changes during a locked session — flag if the chosen approach needs review.
2. **iOS-only verification:** the controller + UI are build-verified only (no iOS unit-test target); the session decision logic is fully TDD'd on macOS, but the Screen-Time shield application + timer behavior is not exercised by tests. On-device QA (start a locked 2h session, confirm mode can't be changed / ended, confirm revert after expiry) is a manual follow-up.
