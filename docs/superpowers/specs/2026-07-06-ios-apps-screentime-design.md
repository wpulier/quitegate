# iOS "Apps" — Native-App Control via Screen Time — Design

**Date:** 2026-07-06
**Status:** Approved design pending user review, then implementation planning
**Scope:** The iOS app (`Tortoise/`) only. Mac and the browser extensions are unaffected.

## 1. Goal

Let an iPhone user hand Tortoise **any apps and categories they choose** and have Tortoise enforce them — "give the app everything, go as specific as you wish." The first cut ships the **Family Controls picker** and **blocks the picked apps under the current mode**. Per-app limits and schedules follow in later stages.

## 2. The honest technical envelope (drives everything)

Verified against the installed **iOS 26.5 SDK** (`ManagedSettings`, `FamilyControls`, `DeviceActivity`):

- **iOS native apps can be controlled only at app/category/web-domain level** — block, time-limit, schedule. There is **no API to tune features *inside* another app** (no "hide Shorts in the YouTube app"). In-page feature tuning exists **only** for the *web versions* via the Safari Web Extension.
- The Safari Web Extension is **Safari-only** on iOS; Chrome/Firefox on iOS cannot run it.
- Therefore Tortoise's iOS model is two honest layers: **Sites** (deep web tuning, Safari) and **Apps** (native block/limit/schedule, Screen Time). This spec builds the **Apps** layer, block-first.

`ManagedSettingsStore` exposes 12 control domains; this spec uses **`shield`** (applications, applicationCategories, webDomains). `FamilyActivitySelection` (Codable) is the picked set. `DeviceActivity` (limits/schedules) is deferred to Stages 2–3.

## 3. Information architecture

Tortoise iOS nav is **Devices / Tune / Usage** (unchanged). Inside **Tune**, add an **"Apps"** area alongside the existing web **"Sites."** The single **mode** selector (Open / Focus / Strict) governs both. No new tab; no new top-level concept.

## 4. The flow (minimal text)

1. **"Apps" card** in the Tune screen → **"Choose apps"** button.
2. Tap → present the system **`FamilyActivityPicker`** (`.familyActivityPicker(isPresented:selection:)`). Requires Family Controls authorization — **reuse** the authorization the app already requests for YouTube Screen Time (if not yet approved, route through the existing authorization request first).
3. User selects any apps, whole categories, and/or web domains.
4. On dismiss, the selection persists (see §6). The card shows the honest state:
   - Heading: **"N apps · M categories blocked in Focus & Strict"** (omit a count that's zero).
   - Rows: each picked application/category as `Label(ApplicationToken)` / `Label(ActivityCategoryToken)` (system icon + name), plus picked web domains as text rows.
   - When nothing is picked: a one-line empty state ("Choose apps to block in Focus & Strict").

## 5. Enforcement — block under the mode

A single enforcement controller computes the shield from the current mode + the managed-apps selection and writes it to `ManagedSettingsStore`:

- **Focus / Strict:** `shield.applications = selection.applicationTokens`; `shield.applicationCategories = .specific(selection.categoryTokens)` (or the appropriate `ActivityCategoryPolicy`); `shield.webDomains = selection.webDomainTokens`.
- **Open:** clear those shield fields.
- The controller **merges** this Apps shield with any existing shield source (the current YouTube Screen-Time shield) into the store's single `shield` — additive union, non-breaking (per the "coexist now, unify later" decision). Folding the YouTube app-shield into the general Apps model is a later stage.
- Applied on the **same seam** the existing shield uses: mode change, session start/expiry, and `applyCurrentMode()` on launch (so the shield survives app-kill — the OS keeps enforcing).

## 6. Data model & persistence

- Add a persisted **managed-apps `FamilyActivitySelection`** to the iOS enforcement state, **separate** from the existing YouTube selection.
- `FamilyControls`/`ManagedSettings` types are **iOS-only**; the shared `IOSEnforcementSnapshot` compiles on macOS too. Follow the **existing platform-split pattern** in `Tortoise/IOSEnforcementShared.swift` (the YouTube `FamilyActivitySelection` is already loaded/saved behind `#if os(iOS)` via `loadSelection`/`saveSelection`): persist the managed-apps selection the same iOS-only way (its own app-group key), and keep the shared/cross-platform snapshot free of iOS-only types.
- The **pure, cross-platform logic** — "given mode + selection presence + locked-session state, should the shield be applied and is editing allowed?" — lives in shared `Tortoise/` code as plain functions and is TDD'd on macOS.

## 7. Precommitment (locked sessions)

A locked Strict session must not be weakenable by un-picking apps:

- When `screenTime.sessionLockedActive`, the **"Choose apps" button and any remove/clear affordance are `.disabled`**, and the controller **refuses** to shrink the managed-apps selection or clear its shield — mirroring the existing locked-session gates on tuning writes (`3b-2a` precommitment). Growing the selection (adding more apps) is allowed; shrinking/clearing is refused until the session ends.
- The shield itself is the system `ManagedSettingsStore` shield, which persists through app-kill — so the commitment genuinely holds.

## 8. Architecture / components

- **`Tortoise/ContentView.swift`** — the new "Apps" card in `MobileTuningScreen` (picker trigger, selection display, precommitment disabling). Reuse `TortoiseDesign` tokens + the existing card style.
- **Enforcement controller** (`IOSYouTubeScreenTimeController` extended, or a focused sibling) — holds the managed-apps selection, applies/merges the shield in `applyCurrentMode()`, exposes `setManagedAppsSelection(_:)` with the locked-session guard.
- **`Tortoise/IOSEnforcementShared.swift`** — iOS-only load/save of the managed-apps selection (mirrors the YouTube selection).
- **Shared pure logic file** (new, `Tortoise/`) — the mode→shield decision + edit-allowed decision, TDD'd in `QuietGateTests`.
- No new target; no `DeviceActivity` extension change in Stage 1 (limits/schedules are Stage 2–3).

## 9. Testing

- **macOS XCTest** (`QuietGateTests`): the pure decision logic (mode→shield-applies, locked-session edit-allowed, selection non-empty), and any Codable round-trip of the shared state.
- **iOS**: build-verified; the `FamilyControls`/`ManagedSettings` wiring + the actual shield are **on-device QA** (there is no iOS unit-test target). Manual QA: pick apps → enter Focus → confirm the picked apps show the Tortoise shield; start a locked Strict session → confirm "Choose apps"/remove are disabled and the shield can't be weakened; return to Open → shield clears.

## 10. Staged roadmap

- **Stage 1 (this spec):** Family Controls picker + persist + block-under-mode + precommitment freeze + honest empty/selected states.
- **Stage 2:** per-app / per-category **daily limits** (`DeviceActivityEvent` thresholds → shield on reach) in the `TortoiseDeviceActivityMonitor` extension.
- **Stage 3:** **schedules** (time-of-day `DeviceActivitySchedule` windows) + additional `ManagedSettings` (media explicit, App Store, passcode) exposed as optional advanced toggles; and **unify** the YouTube app-shield into the general Apps model.

## 11. Success criteria (Stage 1)

- A user can open **Tune → Apps → Choose apps**, pick any apps/categories/domains, and see them listed.
- In **Focus/Strict**, the picked apps/sites show the Tortoise shield; in **Open**, they don't.
- The existing YouTube Screen-Time behavior is **unchanged** (additive, non-breaking).
- During a **locked Strict session**, the selection cannot be shrunk/cleared and the shield holds.
- macOS suite stays green; iOS builds.

## 12. Out of scope (Stage 1)

- In-app feature tuning of native apps (impossible on iOS — Safari-only, already covered by Sites).
- Per-app daily limits and time-of-day schedules (Stages 2–3).
- Media/App Store/passcode `ManagedSettings` toggles (Stage 3).
- Unifying the YouTube app-shield into the Apps model (Stage 3).
- Any Mac / browser-extension change.

## 13. Risks / open questions

- **Authorization state:** if Family Controls isn't yet authorized, the picker can't populate; the flow must route through the existing authorization request first (surface the same "grant Screen Time" step the YouTube setup uses).
- **Shield merge correctness:** two shield sources (YouTube + managed-apps) write one store; the controller must union them on every apply so neither clobbers the other — covered by a pure-logic test where feasible, else on-device QA.
- **`FamilyActivitySelection` opacity:** tokens are opaque + device-scoped; the persisted selection is only meaningful on the same device (acceptable — this is a per-device iOS control, consistent with the per-device session decision).
