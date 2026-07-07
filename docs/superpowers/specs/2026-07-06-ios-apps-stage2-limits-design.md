# iOS Apps Stage 2 — Daily Limits + YouTube-Independence Fix — Design

**Date:** 2026-07-06
**Status:** Approved design pending spec review, then implementation planning
**Scope:** The iOS app (`Tortoise/`) + the `TortoiseDeviceActivityMonitor` extension. Mac and browser extensions unaffected.
**Builds on:** Stage 1 (`docs/superpowers/specs/2026-07-06-ios-apps-screentime-design.md`) — the managed-apps `FamilyActivitySelection`, its `.tortoiseManagedApps` shield store, and the `ManagedAppsShield` pure logic.

## 1. Goal

Add a **combined daily limit** to the managed apps: in **Open** mode the picked apps are *allowed but capped* — after N minutes/day of combined use they shield until midnight; in **Focus/Strict** they stay blocked outright (Stage 1). And fix the Stage-1-flagged coupling so the Strict adult web filter and the enforcement status no longer require a *YouTube* selection.

## 2. The limit model (the core idea)

One managed-apps selection, two layers:
- **Focus / Strict:** apps blocked outright (Stage 1 `.tortoiseManagedApps` shield). A limit here is moot.
- **Open:** apps allowed but subject to the **daily limit** — combined usage across the picked apps; on reaching N minutes the apps shield for the rest of the day.

So the limit is the *everyday guardrail*, the mode-block is the *focus hard-stop*. The limit shield is applied by the DeviceActivity monitor into a separate store, which the OS unions with the Stage 1 shield: in Open only the limit bites; in Focus/Strict the Stage 1 shield already covers the apps and the limit shield is a harmless redundant union.

**Combined, not per-app** (decided): one `DeviceActivityEvent` measures combined usage of the whole selection. Per-app limits, time-of-day schedules, and *locked* limits are later increments.

## 3. Wiring (reuses the proven YouTube-limit pattern)

Ground truth (existing): `IOSYouTubeScreenTimeController.startDailyMonitoring()` builds a full-day `DeviceActivitySchedule` + a `DeviceActivityEvent(threshold: DateComponents(minute: dailyLimitMinutes))` over the YouTube `selection` and calls `activityCenter.startMonitoring(...)`; `TortoiseDeviceActivityMonitor.eventDidReachThreshold` shields into `.tortoiseLimit`; `intervalDidEnd` clears the schedule/limit stores at day boundary.

Stage 2 adds a parallel path:
- **`@Published managedAppsLimitMinutes: Int?`** on the controller (nil = off; else clamped 5–480), persisted in the shared snapshot (its own key). Off by default.
- **A distinct `DeviceActivityEvent.Name`** (e.g. `.managedAppsDailyLimit`) registered in the monitored events dict over the **managed-apps selection** with `threshold: DateComponents(minute: managedAppsLimitMinutes)`, only when the limit is enabled and the selection is non-empty. Registered/re-registered on the same seam as the YouTube monitor (selection change, limit change, `applyCurrentMode`).
- **A new store `ManagedSettingsStore.Name.tortoiseManagedAppsLimit`.** On the managed-apps event firing, the extension loads the managed-apps selection (`IOSEnforcementSharedStore.loadManagedAppsSelection()`) and shields it into `.tortoiseManagedAppsLimit`. Cleared on `intervalDidEnd` (daily reset) and whenever the limit is disabled/selection emptied.
- The extension distinguishes events **by name**: the existing YouTube event → `.tortoiseLimit`; the new managed-apps event → `.tortoiseManagedAppsLimit`. Neither store is in `tortoiseEnforcementStores` (owned by their own reconcile paths).

DeviceActivity supports multiple events; adding one more is well under Apple's caps.

## 4. UI

Extend the Stage 1 **Apps card** with a **daily-limit control**, styled like the existing YouTube daily-limit control:
- An off/on affordance + a minutes stepper ("Daily limit: 30m", **off by default**).
- Honest copy: when on, "Allowed <N>m/day in Open · blocked in Focus & Strict"; when off, no limit line.
- Disabled while `sessionLockedActive` (consistent with Stage 1), though limits are otherwise freely editable (see §7).
- Only meaningful when a selection exists; hidden/disabled when the selection is empty.

## 5. Independence fix (folded in — the Stage 1 review finding)

Decouple two things from requiring a non-empty *YouTube* `selection`:
- **Strict adult web filter:** the `writeSafariPolicy` / `blockedByFilter` + blocked-domains path applies the adult filter whenever `mode == .strict` and adult blocking is on — regardless of whether a YouTube target is picked. (Today it rides the YouTube-selection-gated `shouldEnforce` branch.)
- **Enforcement status:** `syncHealth` / `connectionState` / `statusMessage` reflect active enforcement when **either** the YouTube selection **or** the managed-apps selection is active (or the adult filter is on), so the app stops reporting "Open"/"setup required" while apps are actually shielded.

This is a targeted change to the controller's status + Safari-policy computation; it must not alter the YouTube shield behavior or the Stage 1 managed-apps shield.

## 6. Persistence & pure logic

- `managedAppsLimitMinutes` persists in the shared snapshot (`IOSEnforcementSharedStore`), iOS-visible; the shared snapshot stays free of `FamilyControls`/`ManagedSettings` types (Int only — safe cross-platform).
- **Pure, cross-platform decisions** (extend `ManagedAppsShield` or a sibling, TDD'd on macOS): clamp `managedAppsLimitMinutes` to 5–480; `shouldArmManagedAppsLimit(limitEnabled:hasSelection:) -> Bool`; the decoupled decisions — `shouldApplyAdultFilter(mode:adultEnabled:) -> Bool` and `isEnforcementActive(youtubeSelected:managedAppsSelected:adultFilterOn:) -> Bool` for the status.

## 7. Precommitment

- The daily limit governs Open (unrestricted by design), so it is **freely editable** — raising/lowering/toggling is allowed anytime. This is a standard (advisory) Screen Time limit.
- The Stage 1 **selection freeze** during a locked Strict session is unchanged (shrink/clear refused). Locked *limits* (a cap you cannot raise mid-commitment) are explicitly a later increment.
- During a locked Strict session the apps are blocked outright, so the limit is moot regardless.

## 8. Testing

- **macOS XCTest:** the pure decisions in §6 (clamp bounds, arm-limit, adult-filter, enforcement-active), and any Codable round-trip of the extended snapshot.
- **iOS:** DeviceActivity registration + extension routing + the new store shield are build-verified; on-device QA: set a limit in Open → use the apps past the threshold → they shield → next day they're usable again; confirm Focus/Strict still block; confirm the YouTube limit still works unchanged; confirm Strict adult filter now applies with no YouTube target; confirm status no longer says "Open" while apps are shielded.

## 9. Success criteria

- In **Open** with a limit set, the managed apps shield after N minutes of combined use and reset the next day.
- In **Focus/Strict** the managed apps stay blocked; the YouTube daily limit is **unchanged**.
- The Strict adult web filter applies even when no YouTube target is selected.
- The status stops reporting "Open"/"setup required" while managed apps are shielded.
- Pure logic TDD'd green; macOS suite green; iOS builds.

## 10. Out of scope

- Per-app / per-category limits (each app its own minutes) — later increment.
- Time-of-day schedules (`DeviceActivitySchedule` windows) — Stage 3.
- Locked limits (a cap you can't raise during a commitment) — later.
- YouTube app-shield unification, media/App Store/passcode toggles — Stage 3.
- Any Mac / browser-extension change.

## 11. Risks

- **Extension store hygiene:** `.tortoiseManagedAppsLimit` must be cleared on `intervalDidEnd` and when the limit is disabled or the selection emptied, else a stale limit shield could persist. Covered by the reconcile paths + on-device QA.
- **DeviceActivity event identity:** the extension must route strictly by `EventName`; a mismatch would shield the wrong set. Pure event-name routing decision is unit-tested where feasible; the wiring is on-device QA.
- **Independence-fix blast radius:** the status/Safari-policy computation is shared with the YouTube path; the change must be additive (an OR of enforcement sources), verified by a focused review + the YouTube-unchanged QA check.
- **Combined-usage semantics:** users may expect per-app limits; the UI copy states "combined" clearly, and per-app is the named next increment.
