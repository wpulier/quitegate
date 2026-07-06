# Phase 5a — Remove LegacyProviderConnector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Delete the force-disabled `QuietGate/LegacyProviderConnector/` (8 files, 1,659 lines) and untangle every reference to it in the 5 consuming files, collapsing the code to the browser-first shipping path with zero behavior change.

**Architecture:** The legacy NextDNS-style provider is gated at runtime by a single master switch, `ProtectionStore.legacyProviderConnectorEnabled`, which is `false` in every shipping build (RELEASE hardcodes `false`; the app calls `disableLegacyProviderConnector()` before constructing the store). The only place it is ever `true` is DEBUG unit tests, where the `isolatedDefaults()` helper sets `quietgate.legacyProviderConnectorEnabled = true`. Removal therefore proceeds in two movements: (1) sever the tests from the flag so nothing turns legacy on, then (2) delete the now-permanently-dead legacy branches, members, DI seam, and files. Each task ends compiling + full macOS suite green + committed.

**Tech Stack:** Swift 5 / SwiftUI, XcodeGen (`project.yml`, group-based sources), XCTest (`QuietGateTests`, `@testable import QuietGate`), `xcodebuild` via Bash.

## Global Constraints

- **Tests are the safety net.** macOS XCTest target `QuietGateTests` (`@testable import QuietGate`) — currently **302 passing** (174 of them in `QuietGateTests/ProtectionStoreTests.swift`). Must stay green. Every test this plan removes is removed **only because the production code it exercises is being deleted** (legacy-enabled behavior that never ships); no browser-first / shipping-path coverage is weakened. Each removed test is justified inline.
- **No behavior change.** The legacy path is already runtime-disabled, so removal must be behavior-preserving for the shipping app. The green suite (after the Task 1 test migration) is the proof.
- **Product name is Tortoise.** KEEP the Swift module name (`PRODUCT_MODULE_NAME=QuietGate`, pinned in `project.yml`), the bundle IDs (`com.willpulier.QuietGate*`), and the native-messaging host IDs (`com.willpulier.quietgate.*`). Do NOT rename identifiers here — that is Phase 5d. Only delete.
- **Group-based sources.** The `QuietGate` target's sources are the whole `QuietGate` directory as a group (`project.yml` line 31: `- QuietGate`). After deleting any `.swift` file you MUST run `xcodegen generate --spec project.yml --project .` and stage the regenerated `QuietGate.xcodeproj` (same as the prior ControlView deletion).
- **iOS builds are SLOW (~15–25 min).** Use `xcodebuild` via Bash ONLY (never an Xcode MCP tool), foreground, once per task, and only where the plan says to. There is no iOS unit-test target — iOS is build-verified only.
- **Large mechanical surface — grep-to-zero is the completion criterion.** `ProtectionStore.swift` holds ~409 `legacyProvider` references and `ProtectionStoreTests.swift` ~357. This plan does NOT reproduce 400+ line-level edits verbatim (that would be drift-prone and unmaintainable). Instead each task gives the **exact symbol inventory + collapse rules + line anchors (as read on 2026-07-06)** and a **grep command that must return zero** before the task is done. Line numbers drift as you edit — re-grep, don't trust stale anchors.

### Command reference (used verbatim throughout)

- **Regenerate project after file deletions:**
  `xcodegen generate --spec project.yml --project .`
- **macOS tests (the green gate):**
  `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
- **iOS build-verify (only where the plan says):**
  `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`

### The 8 files being deleted (all under `QuietGate/LegacyProviderConnector/`)

| File | Lines | Contents |
|---|---|---|
| `DisabledLegacyProviderServices.swift` | 95 | No-op seam: `DisabledLegacySecretStore`, `DisabledLegacyProviderService`, `DisabledResolverStatusService`, `DisabledSystemProfileChecker`, `DisabledLegacyProviderProfileGenerator`, `DisabledLocalHostsScriptGenerator`, `DisabledLegacyProviderServiceError`. |
| `LegacyProviderContracts.swift` | 96 | Protocols `LegacyProviderServicing`, `ResolverStatusChecking`, `SystemProfileChecking`, `LegacyProviderProfileGenerating`, `LocalHostsBlockerScriptGenerating`; enums `LegacyProviderError`, `LegacyProviderProfileError`, `LocalHostsBlockerScriptError`; struct `SystemLegacyProviderProfileStatus`. |
| `LegacyProviderModels.swift` | 199 | `ParentalControl`, `LegacyProviderRuleItem`, `LegacyProviderResolverStatus`, `LegacyProviderLogEntry`, `LegacyProviderAnalyticsStatus`, `APIEnvelope`/`APIMeta`/`Pagination`, error-detail structs. |
| `LegacyProviderReadbackError.swift` | 33 | `LegacyProviderReadbackError` enum. |
| `LegacyProviderStatusService.swift` | 87 | `#if DEBUG` `LegacyProviderStatusService`, `ResolverStatusError`. |
| `LegacyProviderClient.swift` | 208 | `#if DEBUG` `LegacyProviderClient`, `HTTPDataLoading`, `JSONDecoder.legacyProviderDecoder()`. |
| `LegacyProviderMacServices.swift` | 527 | `#if DEBUG` `MacConfigurationProfileService`, `LegacyProviderAppleProfileGenerator`, `LocalHostsBlockerScriptGenerator`. |
| `ProtectionStore+LegacyProviderState.swift` | 414 | `extension ProtectionStore` — all legacy readiness checks, `legacy*` computed state, `open*` funcs, `#if DEBUG makeLegacyProviderRuntimeStore()`. |

### Reference inventory (drive each of these to gone)

**Consuming production files (5):**
- `QuietGate/App/QuietGateApp.swift` — `disableLegacyProviderConnector(...)` (2 calls), `DisabledLegacySecretStore()` (2 uses).
- `QuietGate/Models/BlockingProvider.swift` — `BlockingProviderID.legacyProvider` case, `BlockingProviderCatalog.legacy(dns:browser:localMac:)` factory. (KEEP `isLegacy` field — see decomposition note.)
- `QuietGate/Models/ReadinessCheck.swift` — IDs `legacyProviderAccount`, `legacyMacPermission`, `legacyMacConnection`; actions `allowSavedProviderCredentialAccess`, `openLegacyProviderAccount`, `openLegacyMacPermissionSetup`, `createLegacyMacPermissionProfile`, `checkLegacyMacConnection`.
- `QuietGate/Views/BlockRulesSection.swift` — `store.legacyBlockingProviderEnabled` (2 uses, lines 17 & 71), `store.legacyManagedRestrictionsText` (line 18), `legacySyncPending` local var → `store.legacyProviderSyncPending` (lines 26, 39, 171–172).
- `QuietGate/Stores/ProtectionStore.swift` — the master switch + init ternaries + legacy `@Published` props + legacy methods + DI params + defaults keys (full inventory in Tasks 3a/3b).

**Consuming test files:**
- `QuietGateTests/LegacyProviderClientTests.swift` (222 lines, 6 tests) — DELETE whole file (tests deleted source).
- `QuietGateTests/LegacyProviderStatusServiceTests.swift` (36 lines, 3 tests) — DELETE whole file (tests deleted source).
- `QuietGateTests/ProtectionStoreTests.swift` — remove legacy-enabled tests + neutralize `isolatedDefaults()` (Task 1).
- `QuietGateTests/TestSupport/ProtectionStoreTestDoubles.swift` — remove `FakeLegacyProviderService`, `FakeResolverStatusService`, `FakeSystemProfileChecker`, `FakeLocalHostsScriptGenerator` (Task 4, after their last use is gone). KEEP `MemorySecretStore`/`LockedSecretStore` (they conform to `SecretStoring`, which is 5b's concern), `FakeDomainResolver`, `FakePlatformControlsChecker`, `FakeBrowserExtensionBridge`, `ManualBrowserStatusMonitor`, `FakeAppUpdateService`.

**Files whose "legacy" mentions are INCIDENTAL — DO NOT touch in 5a:**
- `QuietGate/Models/BrowserBlockingProvider.swift:85` / `LocalMacBlockingProvider.swift:67` — `isLegacy: false` (the field we keep).
- `QuietGate/Models/BrowserTuningFeature.swift:253` — the word "legacy" in a YouTube feature description string.
- `QuietGateTests/AppBlockingStoreTests.swift:157`, `BrowserBlockingProviderTests.swift:47`, `LocalMacBlockingProviderTests.swift:37` — `.isLegacy` assertions (stay valid, field kept).
- `QuietGateTests/BrowserExtensionBridgeTests.swift:83,89` — a `settingsVersion: "legacy"` decode test, unrelated.

---

## Phase 5 decomposition (context — only 5a is authored here)

Phase 5 = cleanup + rename, per spec §8. Decomposed into four sub-plans, sequenced so each rests on the prior:

- **5a — Remove `LegacyProviderConnector`** (THIS PLAN). Delete the 8 files + untangle ~417 refs across 5 consumers. Unblocks 5b/5c by removing the last legacy readers of `KeychainStore` and the legacy writers of `connectionState`.
- **5b — Remove `KeychainStore`.** After 5a, `ProtectionStore` no longer calls `keychain.readSecret`/`hasSecret` (all such calls were inside `if legacyProviderConnectorEnabled`). Verify the `keychain` init param/stored property is unused, then delete `QuietGate/Services/KeychainStore.swift` (`SecretStoring`, `KeychainError`, `KeychainStore`) and the `MemorySecretStore`/`LockedSecretStore` test doubles.
- **5c — Remove vestigial `ConnectionState`.** ⚠️ **Refinement (verified while grounding 5a):** the brief's "one use at `ProtectionStore.swift:370`" is inaccurate. `connectionState` has ~30 writers in the LIVE browser-connect / refresh flow (lines 646, 2289–4371) plus 3 string readers (`settingsStatusSummary`-type text at 805, 828, 1047). No View consumes it (confirmed: zero matches in `QuietGate/Views` / `QuietGate/App`). 5c must confirm those writers are write-only dead state and the 3 readers can be re-sourced or dropped, then delete `QuietGate/Models/ConnectionState.swift`. 5a explicitly does NOT touch `ConnectionState` — it stays a `.connected`/`.notConfigured`/`.error` published value driven by the browser flow.
- **5d — Finish the Tortoise rename.** ~18 user-facing "QuietGate" strings post-deletion. Per spec §8 KEEP bundle IDs, `PRODUCT_MODULE_NAME=QuietGate`, and native-host IDs. Small.

**`isLegacy` field decision (locked for 5a):** `BlockingProviderSnapshot.isLegacy` is referenced by `BrowserBlockingProvider`, `LocalMacBlockingProvider`, and 3 test files, all as `false`. Removing it would pull 5 extra files into scope for zero behavior gain. **5a keeps `isLegacy` (always `false`) and removes only the `.legacyProvider` enum case + the `.legacy(...)` catalog factory.** Optional follow-up cleanup, if desired, belongs in 5d or a dedicated micro-task, not here.

---

## Task 1: Sever the tests from the legacy master switch

Do this first: while production still has the legacy branches, migrate the tests so nothing sets `quietgate.legacyProviderConnectorEnabled = true`. After this task, every ProtectionStore test exercises the browser-first (shipping) path, which is exactly the behavior we are preserving. The suite stays green through all later deletions.

**Files:**
- Delete: `QuietGateTests/LegacyProviderClientTests.swift`
- Delete: `QuietGateTests/LegacyProviderStatusServiceTests.swift`
- Modify: `QuietGateTests/ProtectionStoreTests.swift` (helper at `:4672`; legacy-enabled test methods throughout)

**Interfaces:**
- Consumes: nothing (test-only task).
- Produces: a suite in which `grep -rn 'legacyProviderConnectorEnabled.*true\|set(true, forKey: "quietgate.legacyProviderConnectorEnabled")' QuietGateTests/` returns zero, and `store.legacyProviderConnectorEnabled` is never asserted `true`.

- [ ] **Step 1: Establish the baseline — full suite green before any change**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
Expected: **TEST SUCCEEDED**, 302 tests. Record the count. This is the number every later task compares against (minus the tests this task intentionally removes).

- [ ] **Step 2: Delete the two dedicated legacy unit-test files**

These test deleted-in-5a source directly (`LegacyProviderClient`, `LegacyProviderStatusService` / `ResolverStatusError`). They cannot survive their subjects.

```bash
git rm QuietGateTests/LegacyProviderClientTests.swift
git rm QuietGateTests/LegacyProviderStatusServiceTests.swift
```

Justification (record in commit): 9 tests removed because their sole subjects (`LegacyProviderClient`, `LegacyProviderStatusService`) are being deleted. No shipping behavior is covered by them.

- [ ] **Step 3: Neutralize `isolatedDefaults()` so no test enables legacy**

In `QuietGateTests/ProtectionStoreTests.swift`, edit the helper at `:4672` to stop enabling the flag, and fold `browserFirstDefaults()` into an alias (its 37 call sites keep compiling):

```swift
  private func isolatedDefaults() -> UserDefaults {
    let suiteName = "QuietGateTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }

  private func browserFirstDefaults() -> UserDefaults {
    isolatedDefaults()
  }
```

- [ ] **Step 4: Identify the legacy-enabled test methods to remove**

Run this to list every candidate — tests that only make sense with the flag on:

```bash
grep -n 'func test\|store.legacyProviderConnectorEnabled\|FakeLegacyProviderService\|FakeResolverStatusService\|FakeSystemProfileChecker\|verifiedLegacyProviderDefaults\|markBlockConnectorReady\|makeClient:\|resolverService:\|systemProfileChecker:\|appleProfileGenerator:\|connectionState ==\|\.legacyProvider\b' QuietGateTests/ProtectionStoreTests.swift
```

Removal rule: **delete a `func test…` method iff its body depends on the legacy path** — it injects a legacy service (`makeClient:` / `resolverService:` / `systemProfileChecker:` / `appleProfileGenerator:`), calls a legacy helper (`markBlockConnectorReady`, `verifiedLegacyProviderDefaults`, `blockedLogEntry`), or asserts a legacy outcome (`legacyProviderConnectorEnabled == true`, `blockingProviders`/`defaultBlockingProvider.id == .legacyProvider`, `defaultBlockingProvider.isLegacy == true`, `connectionState == .checking/.error/.misconfigured(...)` from a resolver, `readinessChecks(scope: .blocker)` non-empty, denylist/parentalControl/apple-profile/mac-permission behavior). Known anchors from grounding: `testLegacyNextDNSProviderStaysCompartmentalizedBehindLegacyFlag` (:798), `testLegacyProviderConnectorRuntimeRequiresExplicitServiceInjection` (:815), and the denylist/parentalControl/resolver/appleProfile/macPermission tests.

**Convert, do not delete, the migration tests** whose whole point is that stale legacy state is ignored when the flag is off — they already assert the browser-first outcome and must keep passing. These include `testBrowserFirstStartupMigrationClearsLegacyProviderConnectorDefaults` (:835), `testBrowserFirstStartupMigrationIgnoresLegacyProviderEnvironmentFlag` (:869), `testBrowserFirstIgnoresStaleLegacyProviderConnectorStateWhenFlagIsOff` (:896). For each: keep the "browser-first result" assertions (`store.legacyProviderConnectorEnabled == false`, `profileID == ""`, `defaultBlockingProvider.id == .browserHelpers`, `readinessChecks(scope: .blocker).isEmpty`) and the defaults-clearing assertions; drop any injected legacy service arg (`makeClient:` / `resolverService:`) since the store no longer accepts them after Task 3b — but at THIS task they still compile, so leave the args for now and revisit in 3b (they will be removed there when the init signature changes). At this task, only ensure these tests still pass with `isolatedDefaults()` now meaning flag-off.

- [ ] **Step 5: Remove the identified legacy-enabled test methods**

Delete each method identified in Step 4's removal rule (whole `func … { }` block). Track them so the final count is defensible: expected removals are the ~15–25 legacy-behavior tests in `ProtectionStoreTests.swift` plus the 9 from the two deleted files. Do not touch tests that assert browser-first behavior.

- [ ] **Step 6: Build + run the full macOS suite**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
Expected: **TEST SUCCEEDED**. Count = 302 minus (9 + the ProtectionStoreTests methods you removed). No failures. If any surviving test fails, it was relying on legacy-on behavior — re-apply the Step 4 rule (delete if legacy-only, convert if it asserts a browser-first outcome).

- [ ] **Step 7: Verify no test enables the flag**

Run: `grep -rn 'set(true, forKey: "quietgate.legacyProviderConnectorEnabled")\|legacyProviderConnectorEnabled), *true\|legacyProviderConnectorEnabled == true\|XCTAssertTrue(store.legacyProviderConnectorEnabled)' QuietGateTests/`
Expected: **no output.**

- [ ] **Step 8: Commit**

```bash
git add QuietGateTests/
git commit -m "test: migrate ProtectionStore tests off the legacy provider flag

Remove the legacy-enabled test surface and the two dedicated
LegacyProvider* unit-test files ahead of deleting the legacy connector.
isolatedDefaults() no longer enables the runtime-disabled legacy path;
all remaining tests exercise the browser-first shipping behavior.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Remove the legacy readiness + view surface

With the flag never on, the legacy readiness checks and the view branches that show legacy-only notices are permanently dead. Delete the `ProtectionStore+LegacyProviderState.swift` extension (all legacy readiness/state/`open*`), collapse the readiness aggregation, collapse `BlockRulesSection`, and prune the legacy cases from `ReadinessCheck`.

**Files:**
- Delete: `QuietGate/LegacyProviderConnector/ProtectionStore+LegacyProviderState.swift`
- Modify: `QuietGate/Stores/ProtectionStore.swift` (`readinessChecks(scope:)` :1737, `nextStepReadinessChecks` :1789)
- Modify: `QuietGate/Views/BlockRulesSection.swift` (:15–73, :171–172)
- Modify: `QuietGate/Models/ReadinessCheck.swift` (enum `ReadinessCheckID` :3, `ReadinessAction` :33 + its `title` :53 and `systemImage` :76 switches)

**Interfaces:**
- Consumes: the Task 1 flag-off suite.
- Produces: `ProtectionStore` no longer exposes `legacyProviderAccountCheck`, `websiteBlockingCheck`, `legacyMacPermissionCheck`, `legacyMacConnectionCheck`, `legacyBlockingProviderEnabled`, `legacyManagedRestrictionsText`, `legacyProviderSyncPending`, or any `openLegacyProvider*`/`openLegacyMacPermissionSetup` func. `ReadinessCheckID`/`ReadinessAction` carry no `legacy*` cases. `readinessChecks(scope: .blocker)` returns `[]`.

- [ ] **Step 1: Collapse the readiness aggregation in `ProtectionStore.swift`**

At `readinessChecks(scope:)` (:1737) the `.blocker` case is already `guard legacyProviderConnectorEnabled else { return [] }` — with the flag gone it is unconditionally empty. Replace the `.blocker` case body with `return []` and simplify the `.selectedMode` case (:1753) to its `else` (flag-off) branch only:

```swift
  func readinessChecks(scope: ReadinessScope) -> [ReadinessCheck] {
    switch scope {
    case .all:
      return readinessChecks(scope: .blocker) + readinessChecks(scope: .tuner)
    case .blocker:
      return []
    case .tuner:
      return [browserConnectionCheck, browserSettingsCheck]
    case .selectedMode:
      return (accessMode.protectionEnabled || tunerEnabled || hasActiveBlockRules)
        ? readinessChecks(scope: .tuner)
        : []
    }
  }
```

Then simplify `nextStepReadinessChecks` (:1789) to its flag-off branch:

```swift
  private var nextStepReadinessChecks: [ReadinessCheck] {
    tunerEnabled || hasActiveBlockRules ? readinessChecks(scope: .tuner) : []
  }
```

(`.all` and `ReadinessScope.blocker` stay; `.blocker` now yields `[]`. Full removal of the `.blocker` scope is optional polish, not required — leaving it empty is behavior-preserving and keeps `.all` callers stable.)

- [ ] **Step 2: Delete the legacy extension file**

```bash
git rm QuietGate/LegacyProviderConnector/ProtectionStore+LegacyProviderState.swift
```

This removes `legacyProviderAccountCheck`, `websiteBlockingCheck`, `legacyMacPermissionCheck`, `legacyMacConnectionCheck`, `legacyMacConnectionAction`, all `legacy*`/`hiddenLegacyProvider*` computed state, `legacyProviderSyncPending`, `legacyBlockingProviderEnabled`, `legacyManagedRestrictionsText`, `appleProfileSetupAction`, and every `openLegacy*`/`openLegacyProvider*` func in one shot.

- [ ] **Step 3: Collapse `BlockRulesSection.swift`**

Remove the legacy-only notice blocks and the `legacySyncPending` helper (which read the just-deleted `store.legacyBlockingProviderEnabled` / `store.legacyManagedRestrictionsText` / `store.legacyProviderSyncPending`). Replace the top of `body` (:16–47) so it drops the `HiddenRestrictionsNotice` and the `legacySyncPending`-gated blocks:

Delete this block (:17–28):
```swift
      if store.legacyBlockingProviderEnabled,
         let hiddenRestrictions = store.legacyManagedRestrictionsText {
        HiddenRestrictionsNotice(
          restrictions: hiddenRestrictions,
          isWorking: resolvingHiddenRestrictions || store.isWorking,
          action: turnOffHiddenRestrictions
        )
      }

      if legacySyncPending {
        CheckingBlocksNotice()
      }
```

Change the `!legacySyncPending` guard (:39) — since `legacySyncPending` is always `false`, `!legacySyncPending` is always `true`, so drop that clause:
```swift
      if let attentionTitle = store.blockApplicationAttentionTitle,
         let attentionDetail = store.blockApplicationAttentionDetail {
```

Simplify the `ProductPanel` subtitle (:71–73) to the flag-off string:
```swift
      ProductPanel(
        title: "What gets blocked",
        subtitle: "These switches change what Tortoise blocks in connected browsers."
      ) {
```

Delete the `legacySyncPending` computed var (:171–172):
```swift
  private var legacySyncPending: Bool {
    store.legacyProviderSyncPending
  }
```

Then remove any now-orphaned symbols this exposes: the `resolvingHiddenRestrictions` `@State` (:8) and its `turnOffHiddenRestrictions` action, and the `HiddenRestrictionsNotice` / `CheckingBlocksNotice` subviews **iff** they have no other referencer. Verify before deleting each:
`grep -rn 'HiddenRestrictionsNotice\|CheckingBlocksNotice\|turnOffHiddenRestrictions\|resolvingHiddenRestrictions' QuietGate/`
Delete only those whose sole reference was the code you just removed. Leave anything still used elsewhere.

- [ ] **Step 4: Prune legacy cases from `ReadinessCheck.swift`**

Remove the three legacy IDs from `ReadinessCheckID` (:3):
```swift
enum ReadinessCheckID: String, Codable, CaseIterable {
  case websiteBlocking
  case browserConnection
  case browserSettings
}
```
(`websiteBlocking` is retained only if still referenced — grep `grep -rn '\.websiteBlocking\b' QuietGate/`; the legacy `websiteBlockingCheck` producer was deleted in Step 2, so if there is no other producer/consumer, remove `websiteBlocking` too.)

Remove the five legacy `ReadinessAction` cases (:37–51) and their matching arms in the `title` switch (:53) and `systemImage` switch (:76): `allowSavedProviderCredentialAccess`, `openLegacyProviderAccount`, `openLegacyMacPermissionSetup`, `createLegacyMacPermissionProfile`, `checkLegacyMacConnection`. Also drop `checkLegacyMacConnection`'s sibling only if unused. After editing, the enum, `title`, and `systemImage` must remain exhaustive and consistent (each surviving case appears in both switches). Verify no dangling references:
`grep -rn 'allowSavedProviderCredentialAccess\|openLegacyProviderAccount\|openLegacyMacPermissionSetup\|createLegacyMacPermissionProfile\|checkLegacyMacConnection' QuietGate/`
Expected after edit: **no output.**

- [ ] **Step 5: Build + run the full macOS suite**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
Expected: **TEST SUCCEEDED.** Compiler errors here point to a missed reader of a removed symbol — fix by collapsing that reader to its flag-off behavior. Note: this task does not run xcodegen yet (the `LegacyProviderConnector` group still has 7 files, and the file you removed is tracked by git; xcodegen runs in Task 4 when the directory empties). If the build cannot resolve the deleted file, run `xcodegen generate --spec project.yml --project .` and stage `QuietGate.xcodeproj`, then rebuild.

- [ ] **Step 6: Commit**

```bash
git add QuietGate/ QuietGate.xcodeproj 2>/dev/null; git add QuietGate/
git commit -m "refactor: remove legacy provider readiness and view surface

Delete ProtectionStore+LegacyProviderState.swift, collapse the blocker
readiness scope to empty, drop the legacy notices from BlockRulesSection,
and prune the legacy ReadinessCheck IDs/actions. Behavior-preserving:
the legacy path was already disabled in every shipping build.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3a: Collapse the master switch and init in `ProtectionStore.swift`

Replace every read of `legacyProviderConnectorEnabled` with its permanent value (`false`), simplify the resulting conditionals and init ternaries, and remove the flag itself plus the app wiring that set it. After this task the legacy `@Published` properties and legacy private methods are unreferenced-but-present (Swift does not error on unused private members; the project has no warnings-as-errors) — they are deleted in Task 3b.

**Files:**
- Modify: `QuietGate/Stores/ProtectionStore.swift` (flag decl :447, defaults keys :497–499, `disableLegacyProviderConnector` :515, init :526–656, and ~90 `legacyProviderConnectorEnabled` read sites)
- Modify: `QuietGate/App/QuietGateApp.swift` (:80–98)

**Interfaces:**
- Consumes: Task 2's suite.
- Produces: `ProtectionStore` has no `legacyProviderConnectorEnabled` member and no `disableLegacyProviderConnector(...)` static; `init` no longer branches on it; `QuietGateApp.makeStore()` constructs the store without `disableLegacyProviderConnector` / `DisabledLegacySecretStore`.

- [ ] **Step 1: Collapse every conditional on the flag**

Apply these rules to all read sites (find them with `grep -n 'legacyProviderConnectorEnabled' QuietGate/Stores/ProtectionStore.swift`):
- `if legacyProviderConnectorEnabled { A } [else { B }]` → keep `B` (or delete the whole `if` if no `else`). `A` is dead.
- `if !legacyProviderConnectorEnabled { B } [else { A }]` → keep `B`; delete `A`.
- `guard legacyProviderConnectorEnabled else { X }` → the guard always falls through to `X`; replace the whole guarded region with `X` (i.e., the method/getter returns/does `X` unconditionally).
- `legacyProviderConnectorEnabled ? A : B` → `B`.
- `flag && Z` → `false` (drop the branch); `flag || Z` → `Z`.

Concrete init collapses (:566–649), for example:
```swift
    categoryPreferencesHaveBeenSaved = defaults.array(forKey: DefaultsKey.blockCategories) != nil
    profileID = ""
    accessMode =
      AccessMode(rawValue: defaults.string(forKey: DefaultsKey.accessMode) ?? "") ?? .open
    blockedSites = Self.loadBlockedSites(from: defaults)
    blockCategories = []
    pendingLegacyProviderRuleRemovals = []
    tuningOverrides = Self.loadTuningOverrides(from: defaults)
    tuningOptions = Self.loadTuningOptions(from: defaults)
    generatedAppleProfileURL = nil
    generatedHostsScriptURL = Self.loadExistingFileURL(
      from: defaults, key: DefaultsKey.generatedHostsScriptPath)
    ...
    cachedAPIKey = nil
    legacyProviderKeyNeedsPermission = false
    hasAPIKey = false
    legacyProviderRulesSyncPending = false
    legacyProviderVerifiedProfileID = nil
    ...
    blockCategories = Self.loadBlockCategories(from: defaults, accessMode: accessMode)
    clearPendingLegacyProviderRuleRemovals()
    connectionState = .connected
    localHostsFallbackInstalled = localHostsScriptGenerator.localHostsBlocklistInstalled()
```
(Remove the `#if DEBUG legacyProviderConnectorEnabled = defaults.bool(...) #else … #endif` block at :565–569 entirely — the property is being removed.)

Note: `pendingLegacyProviderRuleRemovals`, `legacyProviderKeyNeedsPermission`, `hasAPIKey`, `legacyProviderRulesSyncPending`, `legacyProviderVerifiedProfileID`, `generatedAppleProfileURL`, `cachedAPIKey`, `keychain` are still declared — keep initializing them to their inert values here so the store compiles; Task 3b removes the properties themselves once their remaining readers are gone.

- [ ] **Step 2: Remove the flag, its defaults keys, and the static disabler**

- Delete the stored `let legacyProviderConnectorEnabled: Bool` (:447).
- In the `DefaultsKey` enum (:487) delete `legacyProviderConnectorEnabled` (:497), `legacyProviderConnectorEnabledDeprecated` (:498), and `legacyProviderRuntimeEnabled` (:499) **only if** they have no remaining reader (grep each; `disableLegacyProviderConnector` referenced them and is being deleted next).
- Delete the whole `static func disableLegacyProviderConnector(in:)` (:515–524).

Verify: `grep -n 'legacyProviderConnectorEnabled\|disableLegacyProviderConnector' QuietGate/Stores/ProtectionStore.swift` → **no output.**

- [ ] **Step 3: Update `QuietGateApp.makeStore()`**

The app used `disableLegacyProviderConnector(...)` (now gone) and `DisabledLegacySecretStore()` (defined in a Task-4-deleted file). Drop both. Let `keychain` fall back to its `init` default (`KeychainStore()`) — after 5a it is never read (5b removes it). Rewrite `makeStore()` (:80–98):

```swift
  private static func makeStore() -> ProtectionStore {
    guard ProcessInfo.processInfo.isRunningUnitTests else {
      return ProtectionStore()
    }

    let defaults =
      UserDefaults(suiteName: "QuietGate.AppHostTests.\(UUID().uuidString)") ?? .standard
    return ProtectionStore(
      defaults: defaults,
      extensionBridge: AppHostNoopBrowserExtensionBridge(),
      appUpdateService: AppHostNoopAppUpdateService(),
      localHostsScriptGenerator: AppHostNoopLocalHostsScriptGenerator()
    )
  }
```

(`AppHostNoopLocalHostsScriptGenerator` conforms to `LocalHostsBlockerScriptGenerating`, a protocol in `LegacyProviderContracts.swift` deleted in Task 4 — see Task 4 Step 2 for its relocation/removal. At this task it still compiles.)

Verify: `grep -n 'disableLegacyProviderConnector\|DisabledLegacySecretStore' QuietGate/App/QuietGateApp.swift` → **no output.**

- [ ] **Step 4: Build + run the full macOS suite**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
Expected: **TEST SUCCEEDED.** If a migration test (`testBrowserFirstStartupMigration…`) fails because it passed `makeClient:`/`resolverService:` args, leave those args for now (init still accepts them until 3b) — a failure here instead means an assertion depended on the flag; re-check Task 1 Step 4 conversion.

- [ ] **Step 5: Commit**

```bash
git add QuietGate/Stores/ProtectionStore.swift QuietGate/App/QuietGateApp.swift
git commit -m "refactor: remove the legacy provider master switch

Collapse every legacyProviderConnectorEnabled branch to the browser-first
shipping path, delete the flag, its defaults keys, and the
disableLegacyProviderConnector migration hook. App constructs the store
without the disabled-legacy wiring. Behavior-preserving.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3b: Delete the orphaned legacy members in `ProtectionStore.swift`

Remove the now-unreferenced legacy `@Published` properties, legacy private methods, the legacy DI seam (params + stored props + `Disabled*` defaults), the remaining legacy `DefaultsKey`s, and the `.legacyProvider` catalog entry. Drive `grep -in 'legacyprovider' QuietGate/Stores/ProtectionStore.swift` to zero.

**Files:**
- Modify: `QuietGate/Stores/ProtectionStore.swift`
- Modify: `QuietGate/Models/BlockingProvider.swift` (`BlockingProviderID` :3, `BlockingProviderCatalog.legacy` :67)

**Interfaces:**
- Consumes: Task 3a's collapsed store.
- Produces: `ProtectionStore.init` no longer has `makeClient` / `resolverService` / `systemProfileChecker` / `appleProfileGenerator` params; `BlockingProviderID` has cases `browserHelpers`, `localMac` only; `BlockingProviderCatalog` has no `legacy(...)` factory.

- [ ] **Step 1: Delete the legacy `@Published` properties (:377–418 region)**

Remove those with no remaining reader (grep each name first): `legacyProviderRules`, `legacyProviderRulesCheckedAt`, `blockedLogs`, `analyticsStatus`, `parentalControl`, `parentalControlCheckedAt`, `resolverStatus`, `resolverStatusCheckedAt`, `macOSLegacyProviderProfileInstalled`, `macOSConfiguredLegacyProviderProfileInstalled`, `legacyProviderRulesSyncPending`, `legacyProviderVerifiedProfileID`, `legacyProviderKeyNeedsPermission`, `generatedAppleProfileURL`, `hasAPIKey`, `apiKeyDraft`. For each, remove its declaration, its `didSet`, and its init assignment. If a grep shows a surviving reader (e.g. a string summary), collapse that reader first.

⚠️ Keep: `connectionState` (5c), `domainResolutionStatuses`, `blockedSites`, `blockCategories`, and everything browser/tuning/session-related. Do not remove `keychain` yet (5b).

- [ ] **Step 2: Delete the legacy private methods**

Remove these definitions (anchors as of 2026-07-06; re-grep to confirm): `legacyProviderRulesContains` (:2084, :2088), `pendingLegacyProviderRuleRemovalContains` (:2095), `legacyProviderCategoryConfirmed` (:2129), the `legacyBlockingProvider` computed var (:1986–2005), `legacyProviderBlockConnectorReady` (:2007), `freshLegacyProviderControlReadback` (:2011), `freshLegacyProviderRulesReadback` (:2015), `freshMacConnectionReadback` (:2019), `checkResolverStatus` (:3407), `updateResolverStatus` (:3432), `refreshActivity(using:)` (:4012), `configuredClient()` (:4030), `legacyProviderClientForImmediateSync` (:4061), `refreshLegacyProviderRules(using:)` (:4080), `clearLegacyProviderRulesReadback` (:4116), `legacyProviderRulesNeedsSync` (:4122, :4126), `removableManagedDenylistDomains` (:4137), `legacyProviderReadbackConfirmsSavedRules` (:4147, :4151), `addLegacyProviderRule` (:4165), `removeLegacyProviderRule` (:4180), `applyLegacyProviderRules` (:4195), `restoreLegacyProviderRuleIfNeeded` (:4229), `isDuplicateDenylistError` (:4245), `isMissingDenylistError` (:4250), `markLegacyProviderControlVerified` (:4255), `clearLegacyProviderControlVerification` (:4265), `clearLegacyProviderControlVerificationIfCredentialFailure` (:4270), `invalidatesLegacyProviderControlVerification` (:4277), `setLegacyProviderRulesSyncPending` (:4290), `addPendingLegacyProviderRuleRemoval` (:4300), `removePendingLegacyProviderRuleRemoval` (:4306), `clearConfirmedPendingLegacyProviderRuleRemovals` (:4314), `clearPendingLegacyProviderRuleRemovals` (:4327), `syncPendingLegacyProviderRules` (:4333), `ensureBaseline(_:)` (:4378), `savedBaseline()` (:4387), `restoreUnconfirmedDenylistRemovals` (:4497), `persistPendingLegacyProviderRuleRemovals` (:4575), `loadPendingLegacyProviderRuleRemovals` (:4987), plus the legacy branches inside `refresh()` (:2351) and `refreshProtectionStatus()` (:2335) — collapse `refresh()`/`refreshProtectionStatus()` to their browser-first bodies (they already call `refreshBrowserFirstStatus()` at :3995; keep that path). Remove the stored `pendingLegacyProviderRuleRemovals`, `activeLegacyProviderRuleDomainsCache`, `cachedAPIKey`, `categoryPreferencesHaveBeenSaved` **iff** now unreferenced.

Work outside-in: delete leaf methods first, rebuild-grep for the next orphan, repeat. The green gate is the backstop.

- [ ] **Step 3: Remove the legacy DI seam**

In `init` (:526) delete the params `makeClient`, `resolverService`, `systemProfileChecker`, `appleProfileGenerator` and their `self.… =` assignments (:546–551), and the stored `private let` declarations (:434, :435, :438, :439). Keep `localHostsScriptGenerator` **only if** still referenced by a non-legacy path (grep `localHostsScriptGenerator` / `localHostsFallback`); the local-hosts backup is legacy-adjacent — if its sole readers were legacy, remove it and the `generatedHostsScriptURL` / `localHostsFallbackInstalled` props too, and drop `LocalHostsBlockerScriptGenerating` from `init`. Decide by grep, not assumption.

Remove the now-orphaned `DefaultsKey`s (grep each): `profileID`, `baseline`, `pendingLegacyProviderRuleRemovals`, `legacyProviderRulesSyncPending`, `legacyProviderVerifiedProfileID`, `generatedAppleProfilePath`, and `localHostsFallbackFingerprint` / `generatedHostsScriptPath` if local-hosts was removed.

- [ ] **Step 4: Remove the `.legacyProvider` catalog entry in `BlockingProvider.swift`**

```swift
enum BlockingProviderID: String, CaseIterable, Hashable, Identifiable {
  case browserHelpers
  case localMac

  var id: String { rawValue }
}
```
Delete the `BlockingProviderCatalog.legacy(dns:browser:localMac:)` factory (:67–77). KEEP `BlockingProviderKind.dns` and the `isLegacy` field (both may still be referenced; the field stays `false` everywhere per the decomposition note). Verify: `grep -rn '\.legacyProvider\b\|BlockingProviderCatalog.legacy\b' QuietGate/` → **no output.**

- [ ] **Step 5: Drive the file to zero legacy references**

Run: `grep -in 'legacyprovider\|parentalControl\|resolverStatus\|denylist\|appleProfile' QuietGate/Stores/ProtectionStore.swift`
Expected: **no output** (or only genuinely non-legacy incidental hits you can justify). Anything left is a missed orphan — remove it.

- [ ] **Step 6: Build + run the full macOS suite**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
Expected: **TEST SUCCEEDED.** If a migration test still passes a removed init arg (`makeClient:` etc.), update that test now to drop the arg (it only ever injected a legacy fake).

- [ ] **Step 7: Commit**

```bash
git add QuietGate/Stores/ProtectionStore.swift QuietGate/Models/BlockingProvider.swift QuietGateTests/ProtectionStoreTests.swift
git commit -m "refactor: delete orphaned legacy provider members from ProtectionStore

Remove the legacy @Published state, denylist/parentalControl/resolver/
apple-profile machinery, the legacy DI seam, the legacy defaults keys, and
the .legacyProvider catalog entry. ProtectionStore now only models the
browser-first path. Behavior-preserving.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Delete the remaining legacy files, regenerate the project, verify both platforms

Nothing references the legacy types anymore. Delete the remaining 7 files (the directory empties), remove the orphaned test doubles, relocate the one still-needed protocol if required, regenerate the Xcode project, and build-verify macOS + iOS.

**Files:**
- Delete: `QuietGate/LegacyProviderConnector/DisabledLegacyProviderServices.swift`, `LegacyProviderContracts.swift`, `LegacyProviderModels.swift`, `LegacyProviderReadbackError.swift`, `LegacyProviderStatusService.swift`, `LegacyProviderClient.swift`, `LegacyProviderMacServices.swift`
- Modify: `QuietGateTests/TestSupport/ProtectionStoreTestDoubles.swift`
- Modify (regenerate): `QuietGate.xcodeproj`
- Possibly modify: `QuietGate/App/QuietGateApp.swift` (if `AppHostNoopLocalHostsScriptGenerator` / `LocalHostsBlockerScriptGenerating` survived)

**Interfaces:**
- Consumes: Task 3b's zeroed store.
- Produces: no `QuietGate/LegacyProviderConnector/` directory; regenerated project; green macOS suite; successful iOS build.

- [ ] **Step 1: Resolve the last protocol dependency**

Only two legacy protocols may still be referenced by surviving code: `LocalHostsBlockerScriptGenerating` (if Task 3b kept local-hosts) and `SecretStoring` (from `KeychainStore.swift`, NOT a legacy file — unaffected). Check:
`grep -rn 'LocalHostsBlockerScriptGenerating\|LocalHostsBlockerScriptError' QuietGate/ QuietGateTests/`
- If **no output**: nothing to relocate; proceed.
- If it survives (local-hosts kept): move the `protocol LocalHostsBlockerScriptGenerating` + `enum LocalHostsBlockerScriptError` out of the doomed `LegacyProviderContracts.swift` into `QuietGate/Services/` (e.g. append to an existing services file or a new `LocalHostsBlocker.swift`), and move the concrete `LocalHostsBlockerScriptGenerator` out of `LegacyProviderMacServices.swift` likewise, before deleting those files. Reassess: if 3b removed all local-hosts readers, skip this and delete freely.

- [ ] **Step 2: Delete the seven remaining legacy source files**

```bash
git rm QuietGate/LegacyProviderConnector/DisabledLegacyProviderServices.swift \
       QuietGate/LegacyProviderConnector/LegacyProviderContracts.swift \
       QuietGate/LegacyProviderConnector/LegacyProviderModels.swift \
       QuietGate/LegacyProviderConnector/LegacyProviderReadbackError.swift \
       QuietGate/LegacyProviderConnector/LegacyProviderStatusService.swift \
       QuietGate/LegacyProviderConnector/LegacyProviderClient.swift \
       QuietGate/LegacyProviderConnector/LegacyProviderMacServices.swift
rmdir QuietGate/LegacyProviderConnector 2>/dev/null || true
```

- [ ] **Step 3: Remove the orphaned legacy test doubles**

In `QuietGateTests/TestSupport/ProtectionStoreTestDoubles.swift` delete `FakeLegacyProviderService` (:54–142), `FakeResolverStatusService` (:144–164), `FakeSystemProfileChecker` (:206–224), and `FakeLocalHostsScriptGenerator` (:226–257 — unless local-hosts was kept in 3b, in which case keep it). KEEP `MemorySecretStore`/`LockedSecretStore` (5b owns `SecretStoring`), `FakeDomainResolver`, `FakePlatformControlsChecker`, `FakeBrowserExtensionBridge`, `ManualBrowserStatusMonitor`, `FakeAppUpdateService`. Also delete the `blockedLogEntry()` / `JSONDecoder.legacyProviderDecoder()` test helper in `ProtectionStoreTests.swift` (:4770) and `verifiedLegacyProviderDefaults` (:4731) / `markBlockConnectorReady` (:4738) / `pendingRemovalDefaults` (:4668) if now unreferenced (grep each).

- [ ] **Step 4: Regenerate the Xcode project and stage it**

Run: `xcodegen generate --spec project.yml --project .`
Then stage: `git add QuietGate.xcodeproj`
(Group-based sources: the deleted files must drop out of the generated `.pbxproj`.)

- [ ] **Step 5: Build + run the full macOS suite**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
Expected: **TEST SUCCEEDED.**

- [ ] **Step 6: Verify zero legacy references repo-wide**

Run: `grep -rn 'LegacyProvider\|legacyProvider\|ParentalControl\|DisabledLegacy' QuietGate/ QuietGateTests/`
Expected: **no output.** (The incidental `isLegacy` field, the `BrowserTuningFeature` description string, and the `settingsVersion: "legacy"` decode test are lowercase-`isLegacy` / free-text and won't match `LegacyProvider`/`legacyProvider` — confirm any residual hit is one of those documented keeps.)

- [ ] **Step 7: iOS build-verify (slow — ~15–25 min, once)**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
Expected: **BUILD SUCCEEDED.** (The Tortoise/iOS target never compiled the legacy files, but it shares `BlockingProvider.swift` / `ReadinessCheck.swift` / `BrowserTuningFeature.swift`; this confirms the shared-model edits didn't break iOS.)

- [ ] **Step 8: Commit**

```bash
git add QuietGate/ QuietGateTests/ QuietGate.xcodeproj project.yml
git commit -m "chore: delete LegacyProviderConnector and regenerate project

Remove the final seven legacy source files, the orphaned legacy test
doubles, and regenerate QuietGate.xcodeproj. QuietGate no longer contains
any legacy provider code. macOS tests green; iOS builds. Behavior-preserving.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage (spec §8 / §5.3 legacy portion):**
- "Delete `QuietGate/LegacyProviderConnector/` (~1,660 lines)" → Tasks 2 (extension) + 4 (remaining 7). ✅
- "plus the ~40 `ProtectionStore` branches guarding it" → Tasks 3a (collapse) + 3b (delete members). ✅
- "and the now-unused `KeychainStore`" → explicitly deferred to **5b** with the seam prepared (5a leaves `keychain` unread). Noted in decomposition. ✅ (not in 5a scope by brief)
- "Vestigial `ConnectionState` — delete" → deferred to **5c**; 5a leaves it intact and documents the corrected scope (~30 live-flow writers, not one). ✅
- "Finish the rename" → deferred to **5d**; 5a keeps module name / bundle IDs / native-host IDs per §8. ✅
- Tests stay green / no coverage weakened → Global Constraints + Task 1 justification + per-task green gate. ✅

**2. Placeholder scan:** No "TBD"/"handle edge cases"/"write tests for the above". Where the surface is too large to reproduce verbatim (ProtectionStore's 400+ refs), the plan gives exact symbol inventories, collapse rules, and grep-to-zero gates rather than vague instructions — this is a deliberate, stated methodology, not a placeholder. ✅

**3. Type consistency:** `legacyProviderConnectorEnabled` (flag), `disableLegacyProviderConnector` (static), `DisabledLegacySecretStore` (app-injected no-op), `BlockingProviderID.legacyProvider` / `.legacy(...)` factory, `ReadinessCheckID`/`ReadinessAction` legacy cases, `isolatedDefaults()`/`browserFirstDefaults()` helpers, and the `keychain`/`isLegacy` deliberate-keeps are named identically wherever referenced across tasks. Init-param names (`makeClient`, `resolverService`, `systemProfileChecker`, `appleProfileGenerator`, `localHostsScriptGenerator`) match the source signature at `:526`. ✅

**Known risk the executor must respect:** line anchors are from 2026-07-06 and WILL drift as earlier tasks edit `ProtectionStore.swift` — always re-grep by symbol name, and treat the per-task grep-to-zero + full-suite green as the real completion signal, not the anchors.
