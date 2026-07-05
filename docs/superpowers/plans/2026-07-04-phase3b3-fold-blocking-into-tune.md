# Phase 3b-3 — Fold Blocking into Tune (+ remove the last fake data) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reach the spec §3 end state — everything you do to shape your experience lives under one "Tune" surface, and **nothing fake ships**. This is done in two sub-plans: **3b-3a (this plan)** removes/realizes every remaining fake control *in place* (so both current screens become 100% real), and **3b-3b** performs the navigation fold (Mac: merge Blocking into Tune; iOS: drop the Blocking tab) once the content is real.

**Architecture:** 3b-3a is a fake-data removal + real-source wiring pass across the two "Blocking" screens (`ControlView` on Mac, `MobileBlockingScreen`/`MobileTuningScreen` on iOS). It adds no new surface. Real sources already exist: `AppBlockingStore` (installed Mac apps), `ProtectionStore.blockedSites`/`addCustomDomain`/`deleteBlockedSite` (websites) and `blockCategories`/`setBlockCategory` (adult). The nav restructure is deferred to 3b-3b so this pass stays low-risk.

**Tech Stack:** Swift 5, SwiftUI, XCTest, XcodeGen.

## Phase 3b-3 decomposition

- **3b-3a — Remove the last fake data (this plan):** delete/realize the iOS fake "concept blocking", the Mac hardcoded distracting-apps list, the Mac fake blocked-website defaults, the Mac non-functional Gambling/News rows, and the now-inert iOS "Browser only" path. Both screens become fully real. Nav unchanged.
- **3b-3b — Fold Blocking into the one Tune umbrella:** Mac sidebar `Devices / Tune / Usage` (merge the Blocking screen's real controls — mode + adult + apps + websites + sessions — into the Tune screen as areas, per the `tune-v1` mockup); iOS tabs `Usage / Tune / Devices` (fold `MobileBlockingScreen`'s real content, incl. the 3b-2a sessions, into the Tune tab). Pure IA/nav move over already-real controls.

## Global Constraints

- Tests are a macOS XCTest bundle `QuietGateTests` (`@testable import QuietGate`). No iOS unit-test target — any testable logic lives in shared `Tortoise/` files; SwiftUI views are build-verified only.
- **iOS builds are SLOW (~15–25 min).** Run `xcodebuild` via the Bash tool ONLY (never an Xcode/xcodebuild MCP tool — that has hung); one build at a time, foreground, let it finish.
- macOS tests: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
- iOS build: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
- Pure in-file edits need no `xcodegen`. Product name **Tortoise**; minimal on-screen text; **no fake/demo data** (this is the phase that removes the last of it); cloud policy / real stores are the source of truth; a control only shows where it is real.

## Available from earlier phases (committed)

- Mac `QuietGate/Stores/AppBlockingStore.swift`: `availableApplications: [RunningApplicationSnapshot]`, `blockedApplications: [BlockedApplicationRule]`, `addBlockedApplication(_:)`, `setBlockedApplication(_ bundleIdentifier:enabled:)`, `removeBlockedApplication(_:)`, `enforcementEnabled`, `refreshAvailableApplications()`.
- Mac `QuietGate/Stores/ProtectionStore.swift`: `blockedSites: [BlockedSiteRule]`, `customDomainDraft`, `addCustomDomain()`, `deleteBlockedSite(_:)`, `blockCategories`, `setBlockCategory(_:enabled:)`, `blockRuleEditingReady`.
- iOS: after 3b-1 every feature is enforceable on `.iosSafari`, so `TuneFeature.isEnforceable` is always true on iOS — the "Browser only" disabled-row path in `MobileTuningScreen` is inert dead code.

---

### Task 1: iOS — remove the fake "concept blocking" + inert "Browser only" path

**Files:**
- Modify: `Tortoise/ContentView.swift`
- Test: none new (iOS build-verified).

**Why:** `MobileBlockingScreen`'s "concept blocking" (`conceptStates` `@State = ["porn": true, "gambling": false, "news": false]`, `MobileConcept`, `MobileConceptRow`) is fake — the toggles sync nowhere. iOS adult protection is real but mode-driven (Focus/Strict + Screen Time), not these toggles. And the `TuneFeature.isEnforceable == false` handling in `MobileTuningScreen` (disabled row + "Browser only" caption) is inert after 3b-1 (all iOS features now enforceable).

- [ ] **Step 1: Read `MobileBlockingScreen` and `MobileTuningScreen`** in `Tortoise/ContentView.swift`. Locate: the `conceptStates` `@State` (~:197), the `conceptStates` binding passed into `MobileBlockingScreen` (~:291), the concept section rendering `MobileConcept.allCases`/`MobileConceptRow` (~:638-643), the `MobileConcept` enum + `MobileConceptRow` struct, and the `isEnforceable == false` "Browser only" row handling in `MobileTuningFeatureRow` (the disabled/caption path).

- [ ] **Step 2: Delete the fake concept blocking.** Remove the `conceptStates` `@State`, its binding param on `MobileBlockingScreen`, the "Concept blocking" section/card in `MobileBlockingScreen`, and the `MobileConcept` enum + `MobileConceptRow` struct. Grep-guard: `grep -n 'conceptStates\|MobileConcept' Tortoise/ContentView.swift` must show zero remaining references after removal.

- [ ] **Step 3: Remove the inert "Browser only" path.** In `MobileTuningFeatureRow` (and the `MobileTuningScreen` row builder), since `isEnforceable` is always true on iOS now, remove the `isEnforceable == false` branch (the "Browser only" caption + forced-disable). Keep the switch bound to `feature.isOn` with the existing `!model.isSyncing && !screenTime.sessionLockedActive` gate. (Do NOT remove `TuneFeature.isEnforceable` from the model — it's still meaningful on Mac surfaces and a correct abstraction; only remove the now-dead iOS *view* handling of the false case.)

- [ ] **Step 4: iOS build** — `xcodebuild ... -scheme Tortoise ... build` → `BUILD SUCCEEDED`.
- [ ] **Step 5: macOS suite** — `xcodebuild ... -scheme QuietGate ... test` → green (shared files unchanged).
- [ ] **Step 6: Commit**
```bash
git add Tortoise/ContentView.swift
git commit -m "iOS: remove fake concept-blocking and the inert 'Browser only' path"
```

---

### Task 2: Mac — real installed-apps blocking (drop the hardcoded list)

**Files:**
- Modify: `QuietGate/Views/ControlView.swift`
- Test: none new (view + existing `AppBlockingStore` logic; build-verified).

**Why:** `ControlView.distractingApps` is a hardcoded Slack/Discord/Steam/Messages/Mail/Spotify list, and `localAppStates` is a fake fallback. The real mechanism is `AppBlockingStore` (scans installed apps, closes selected ones). Show REAL apps.

- [ ] **Step 1: Read `ControlView.swift`** — `distractingAppsCard`, `distractingApps` (the hardcoded `DistractingAppModel` list ~:367-376), `localAppStates` (~:9-16), `appBinding(for:)`/`actualBlockedApp(named:)`/`availableApp(named:)` (the name-matching bridge to `appBlockingStore`), and the `.task` that already calls `appBlockingStore.refreshAvailableApplications()`.

- [ ] **Step 2: Render real apps.** Replace the hardcoded `distractingApps` + `localAppStates` with rows built from `appBlockingStore` — the union of currently `blockedApplications` and a bounded set of `availableApplications` (installed apps the user can pick), de-duplicated by `bundleIdentifier`. Each row: app display name + a `QGSwitch` bound to whether it's in `blockedApplications` and enabled, writing via `appBlockingStore.setBlockedApplication(bundleIdentifier, enabled:)` / `addBlockedApplication(_:)` / `removeBlockedApplication(_:)`. Keep the existing `enforcementEnabled` toggle and the `pushLocalPolicy` sync. Delete `localAppStates`, the hardcoded `distractingApps`, `DistractingAppModel` (if now unused), and the name-string bridge helpers (`actualBlockedApp(named:)`/`availableApp(named:)`) — grep-guard each removal.

- [ ] **Step 3: Honest empty state.** If `appBlockingStore.availableApplications` is empty (not yet scanned), show a small "Scanning installed apps…" / "No apps found yet" note rather than any placeholder rows.

- [ ] **Step 4: Build + full macOS suite** — `xcodebuild ... -scheme QuietGate ... test` → `BUILD SUCCEEDED`, suite green. (Confirm no test referenced the removed `distractingApps`/`localAppStates`/`DistractingAppModel` via `grep -rn` in `QuietGateTests`.)
- [ ] **Step 5: iOS build** — `BUILD SUCCEEDED`.
- [ ] **Step 6: Commit**
```bash
git add QuietGate/Views/ControlView.swift
git commit -m "Mac: block real installed apps (drop the hardcoded distracting-apps list)"
```

---

### Task 3: Mac — real blocked-websites empty state (drop the fake defaults)

**Files:**
- Modify: `QuietGate/Views/ControlView.swift`
- Test: none new (build-verified).

**Why:** `ControlView.displayedSites` shows fake `espn.com`/`cnn.com`/`amazon.com`/`news.ycombinator.com` when `store.blockedSites` is empty — fabricated data. The add/remove flow (`store.addCustomDomain`/`deleteBlockedSite`) is real; only the empty-state defaults are fake.

- [ ] **Step 1: Read** `blockedWebsitesCard` + `displayedSites` (~:378-388) in `ControlView.swift`.

- [ ] **Step 2: Replace the fake defaults with a real empty state.** `displayedSites` returns `store.blockedSites` (only). When it's empty, render an honest empty state ("No blocked sites yet — add a domain above") instead of the four fake rows. Keep the real add field (`store.customDomainDraft` + `addCustomDomain()`) and per-row delete (`deleteBlockedSite`).

- [ ] **Step 3: Build + full macOS suite** — green.
- [ ] **Step 4: iOS build** — `BUILD SUCCEEDED`.
- [ ] **Step 5: Commit**
```bash
git add QuietGate/Views/ControlView.swift
git commit -m "Mac: honest empty state for blocked websites (drop fake defaults)"
```

---

### Task 4: Mac — remove the non-functional Gambling/News concept rows

**Files:**
- Modify: `QuietGate/Views/ControlView.swift`
- Test: none new (build-verified).

**Why:** `ControlView.conceptRows` renders three rows but only "Pornography & adult content" is real (`isActionable: true`, wired to `toggleCategory(.adultContent, ...)`); "Gambling & betting" and "News & doomscroll" are `isActionable: false` with no-op bindings (`Binding(get: { false }, set: { _ in })`) — decorative fakes. There is no gambling/news block category mechanism today (`BlockCategoryID` only has `.adultContent`).

- [ ] **Step 1: Read** `conceptSection` + `conceptRows` (~:329-364) in `ControlView.swift`, and confirm via `grep -n 'case ' QuietGate/Models/AppBlocking.swift` (or wherever `BlockCategoryID` is defined) that only `adultContent` is a real category.

- [ ] **Step 2: Remove the two non-functional rows.** `conceptRows` returns only the real adult-content row. Delete the Gambling and News `ConceptRowModel` entries (the `isActionable: false` ones). If removing them leaves `conceptSection` as a single row, keep it as a clean "Adult content" card (retitle the section if "Concept blocking" now reads oddly for one item — a simple "Adult sites" label is fine).

- [ ] **Step 3: Build + full macOS suite** — green.
- [ ] **Step 4: iOS build** — `BUILD SUCCEEDED`.
- [ ] **Step 5: Commit**
```bash
git add QuietGate/Views/ControlView.swift
git commit -m "Mac: drop the non-functional Gambling/News concept rows"
```

---

## Self-Review

**Spec coverage (3b-3a — remove all fake data):**
- iOS fake concept-blocking removed → Task 1. ✓
- iOS inert "Browser only" path removed → Task 1. ✓
- Mac hardcoded distracting-apps list → real installed apps via `AppBlockingStore` → Task 2. ✓
- Mac fake blocked-website defaults → real empty state → Task 3. ✓
- Mac non-functional Gambling/News rows removed → Task 4. ✓
- Result: both "Blocking" screens are 100% real; nothing fake ships. The nav fold into the one Tune umbrella is 3b-3b (deferred — pure IA move over now-real controls).

**Placeholder scan:** No TBD/TODO. Every task removes fake data and either deletes it or wires the real store; no placeholder introduced.

**Type consistency:** Uses existing `AppBlockingStore`/`ProtectionStore` APIs (`availableApplications`, `blockedApplications`, `setBlockedApplication`, `blockedSites`, `addCustomDomain`, `deleteBlockedSite`, `blockCategories`) as already used elsewhere in `ControlView`; no new types.

**Out of scope (deferred):** the navigation fold (Mac sidebar → Devices/Tune/Usage; iOS tabs → Usage/Tune/Devices; move sessions into Tune) is **3b-3b**; the Mac Usage view's `QGUsageDisplay.mock` fallback (a separate empty-state placeholder in the Usage surface, not a Blocking/Tune control) is a Usage-phase follow-up, not this pass; Mac augment knobs (3c); real TikTok tuner (Phase 4).

## Key decisions to confirm before execution

1. **Final IA (drives 3b-3b, but confirm now so 3b-3a doesn't fight it).** Recommended end state: **three destinations — Devices, Tune, Usage** — where CONTROLS live in Devices + Tune (the spec §3 "two places") and Usage stays a separate *insight* surface (it's analytics, not a control). Confirm Usage stays its own section/tab rather than folding into Tune.
2. **iOS apps blocking.** Mac app-blocking is a real local mechanism (`AppBlockingStore` closes apps). iOS has no equivalent app-closing; iOS "apps" would be Screen Time target selection (the `FamilyActivityPicker`, which already exists for YouTube). Recommend: **Mac gets the real Apps section (Task 2); iOS does NOT get a general Apps section in 3b-3** — iOS app/site targeting stays the existing Screen Time selection. Confirm (vs. building a general iOS Screen-Time apps picker now).
3. **iOS adult sites.** Mac has a real adult-content toggle (`setBlockCategory(.adultContent)`). iOS adult web filtering is mode-driven (Strict → Screen Time managed web filter), not a separate toggle. Recommend: iOS keeps adult protection mode-driven (no separate iOS adult toggle in 3b-3a); the removed fake "porn" concept toggle is not replaced by a new iOS control. Confirm.
