# Phase 2c — Browser-Connect Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the account/hub the SINGLE browser source in the Mac Devices screen — remove the separate local "Mac browsers" card so a browser can't appear twice, and delete the now-dead local-connect code left behind by 2b. Pure convergence + dead-code removal; no new behavior.

**Architecture:** Deletion-only, guarded by the existing suite. `ProtectionView` currently renders TWO browser sources: the `DevicesHub` rows (account `chrome_extension` devices, already nested by 2a) AND a local "Mac browsers" card built from `store.browserConnectors` (native-messaging). Remove the local card + its self-contained view cluster; browser profiles then render only via the hub. Separately remove the two dead symbols (`ProtectionView.primaryConnectAction`, `ProtectionStore.performReadinessAction(_:)`) that 2b orphaned. `store.browserConnectors` itself STAYS (the Tuning + Control screens still read it; Phase 3 reworks Tune).

**Tech Stack:** Swift 5, SwiftUI, XCTest, XcodeGen.

## KEY-RISK finding (resolved — safe to delete)

A browser connected via the web token-exchange DOES register as an account device: `exchangeExtensionLinkCode` (`my-clerk-app/lib/quietgate-extension.ts:174-193`) upserts a `quietgate_devices` row with `platform: "chrome_extension"`, `last_seen_at`, keyed on `(user_id, installation_id)`. `MacAccountStore.refresh` fetches ALL devices (`fetchDevices`, `MacAccountStore.swift:158`) into `snapshot.devices`, and 2a's `DevicePresentation.deviceKind` maps `chrome_extension` → `.browser(brand:)`, so account browsers ALREADY render as nested hub rows. Removing the local card therefore loses no account-connected browser. (Native-messaging-only connections that were never account-linked will stop showing in Devices — acceptable and intended: 2b already rerouted every connect affordance to the account-based Add flow; the deeper native-messaging subsystem stays for Phase 5.)

## Global Constraints

- Tests are a macOS XCTest bundle `QuietGateTests` (`@testable import QuietGate`). No iOS unit-test target. This phase adds NO new logic — it is deletion guarded by the existing suite (which exercises `browserConnectors`/`primaryBrowserConnector`/`nextAction` and must stay green).
- After editing sources: `xcodegen generate --spec project.yml --project .` only if a file is added/removed; pure in-file edits need no regeneration. Stage `QuietGate.xcodeproj` if it changes.
- macOS tests: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
- iOS build: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
- Product name **Tortoise**; no fake data; a browser row is On only when genuinely fresh+enforcing (via `ConnectionStatus`, unchanged from 2a).
- **Grep-guard every deletion.** Delete a symbol only after confirming zero remaining callers with `grep -rn '<symbol>' --include='*.swift' QuietGate Tortoise QuietGateTests`.
- **Do NOT touch:** `store.browserConnectors` (kept — TuningView/ControlView/tests use it), `primaryBrowserConnector`, `BrowserConnectorSnapshot.nextAction`, the `ReadinessAction` enum, `supportedBrowserConnectorAction`, `BrowserExtensionBridge`, `NativeHost` (Phase 5 cleanup).

## Confirmed caller map (from grep at plan time — re-verify before deleting)

- `performReadinessAction` → **only** its definition (`ProtectionStore.swift:4013`). Zero callers.
- `primaryConnectAction` → **only** its definition (`ProtectionView.swift:194`). Zero callers.
- `macBrowsers`/`macBrowserGroups`/`BrowserProfileGroupRow`/`BrowserProfileGroup`/`safariGroup`/`browserGroup` → all confined to `ProtectionView.swift`, all reachable only through the "Mac browsers" card. No test references them.
- `browserConnectors` → still used at `TuningView.swift:184`, `ControlView.swift:312`, `ProtectionStoreTests.swift:659-664`, and inside `ProtectionStore`. **Keep.**

---

### Task 1: Remove the local "Mac browsers" card from `ProtectionView`

**Files:**
- Modify: `QuietGate/Views/ProtectionView.swift`
- Test: none new (deletion; existing suite is the guard).

**Interfaces:** No public surface changes. After this task the Devices screen renders: account header + count, the hub card (which nests account browser profiles via `hubRows`), and the `connectButton` (Add sheet). One browser source.

- [ ] **Step 1: Read `ProtectionView.swift` fully.** Confirm the current structure. The "Mac browsers" card is the `body` block (around `:28-34`) — a `VStack { QGSectionLabel(text: "Mac browsers"); QGCard { macBrowsers } }` preceded by a `// TODO(2c): fold local browserConnectors into hubRows` comment. Its cluster: `macBrowsers` (view, ~:123), `macBrowserGroups` (~:169), `safariGroup` (~:180), `browserGroup(_:)` (~:208), `BrowserProfileGroupRow` (struct, ~:392), `BrowserProfileGroup` (struct, ~:455), and a second `// TODO(2c)` at ~:121.

- [ ] **Step 2: Grep-guard the cluster.** Run:
```
grep -rn 'BrowserProfileGroup\|BrowserProfileGroupRow\|macBrowsers\|macBrowserGroups\|safariGroup\|browserGroup\|PlatformSubsectionHeader' --include='*.swift' QuietGate Tortoise QuietGateTests
```
Expect `BrowserProfileGroup*`, `macBrowsers*`, `safariGroup`, `browserGroup` to appear ONLY inside `ProtectionView.swift`. For `PlatformSubsectionHeader`: if it is used ONLY by the `macBrowsers` view, delete it too; if it is used elsewhere in `ProtectionView` or another file, KEEP it. Record the result in your report.

- [ ] **Step 3: Remove the card + its cluster.** Delete from `ProtectionView.swift`:
  - the "Mac browsers" section block in `body` (the `VStack`/`QGCard { macBrowsers }` and its preceding `// TODO(2c)` comment),
  - `macBrowsers`, `macBrowserGroups`, `safariGroup`, `browserGroup(_:)` (and the `// TODO(2c)` at ~:121),
  - `BrowserProfileGroupRow` and the `BrowserProfileGroup` struct,
  - `PlatformSubsectionHeader` ONLY if Step 2 proved it unused elsewhere.

  **Keep:** `connectButton` (it presents the Add sheet — the account-based Add entry point), `hubRows`, `connectionCount`, and everything account/hub-related. Do NOT touch `store.browserConnectors`.

- [ ] **Step 4: Build + full macOS suite.**
Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
Expected: `BUILD SUCCEEDED`; whole suite green (no test referenced the removed view cluster — confirm via the Step 2 grep showing zero test hits).

- [ ] **Step 5: iOS build.**
Run: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
Expected: `BUILD SUCCEEDED` (iOS never had the local card; unaffected).

- [ ] **Step 6: Commit.**
```bash
git add QuietGate/Views/ProtectionView.swift
git commit -m "Converge Mac Devices on the account hub; remove local browser card"
```

---

### Task 2: Remove the dead local-connect symbols

**Files:**
- Modify: `QuietGate/Stores/ProtectionStore.swift` (delete `performReadinessAction(_:)`)
- Test: none new (dead-code removal; existing suite is the guard).

> Note: `primaryConnectAction` was already removed in Task 1 (it was orphaned by the card removal and grep-verified dead). Task 2 is now solely `ProtectionStore.performReadinessAction(_:)`.

**Interfaces:** No public surface changes. `performReadinessAction(_:)` carries a `// TODO(2c)` marker and has zero callers.

- [ ] **Step 1: Grep-guard the symbol.** Run:
```
grep -rn 'primaryConnectAction\|performReadinessAction' --include='*.swift' QuietGate Tortoise QuietGateTests
```
Expect `performReadinessAction` ONLY on its own definition line in `ProtectionStore.swift`, and `primaryConnectAction` to return ZERO hits (already removed in Task 1). If `performReadinessAction` has any other hit, STOP and report — do not delete a referenced symbol. Record the result.

- [ ] **Step 2: Delete `ProtectionStore.performReadinessAction(_:)`** (the `func performReadinessAction(_ action: ReadinessAction) { ... }` and its `// TODO(2c)` comment). Leave `ReadinessAction`, `supportedBrowserConnectorAction`, and `BrowserConnectorSnapshot.nextAction` intact.

- [ ] **Step 4: Build + full macOS suite.**
Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
Expected: `BUILD SUCCEEDED`; whole suite green.

- [ ] **Step 5: iOS build.**
Run: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit.**
```bash
git add QuietGate/Stores/ProtectionStore.swift
git commit -m "Remove dead performReadinessAction (superseded by the Add flow)"
```

---

## Self-Review

**Spec coverage (spec §5 Devices; 2a/2b follow-ups):**
- One browser source in the Devices screen (no double-show) → Task 1 removes the local card; account browsers already render via the hub (KEY-RISK finding). ✓
- Remove the dead connect code 2b orphaned (`primaryConnectAction`, `performReadinessAction`) → Task 2, grep-guarded. ✓
- Don't break Tuning → `store.browserConnectors` retained; `TuningView`/`ControlView` untouched. ✓
- Don't remove the native-messaging subsystem → `BrowserExtensionBridge`/`NativeHost` untouched (Phase 5). ✓

**Placeholder scan:** No TBD/TODO. This phase deletes the two `// TODO(2c)` markers as it does the work they described.

**Type consistency:** No new types. Deletions only; every removal is grep-guarded to zero callers before it happens.

**Out of scope (deferred):** the native-messaging subsystem removal + `browserConnectors` retirement (Phase 5, once Tune no longer reads it); the neutral browser landing page + `/download/*` release check (2b follow-ups); the entry-point verb harmonization (2b Minor); real per-device enforcement signal (Phase 3).

## Risk to confirm before execution

None blocking. One judgment call for the parent to confirm: **Task 1 makes native-messaging-only browser connections (never account-linked) stop appearing in the Devices screen.** This is intended (the going-forward path is the account-based Add flow), but if you want those legacy connections to remain visible during a transition, Task 1 should instead keep the card but de-duplicate against account profiles. The evidence says clean removal is correct; confirm you're happy losing the legacy-only display.
