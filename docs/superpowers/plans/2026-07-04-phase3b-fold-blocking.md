# Phase 3b — Fold Blocking into Tune Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the "Blocking" concerns (overall mode, adult sites, blocked apps, blocked websites, focus/locked sessions) under the single "Tune your digital life" umbrella (spec §3), remove the remaining fake/demo data, and make iOS sessions real. Sub-plan 3b-1 (this plan) first lands the correctness/honesty sweep-in fixes carried over from the 3a review.

**Architecture:** 3b-1 is a small correctness pass on the shared catalog + iOS view minors (no new surface). Later sub-plans do the real work: real iOS sessions (a shared session model + client enforcement) and the IA fold (one Tune surface).

**Tech Stack:** Swift 5, SwiftUI, XCTest, XcodeGen.

## Phase 3b decomposition

- **3b-1 — Sweep-in fixes** *(this plan)*: correct the iOS-Safari enforceability data (the two Instagram features ARE enforceable) + the 3a-review minors (launch `onChange` nil-guard; shared `"youtube"` site-id constant). Small, unblocks a clean honest state before the bigger work.
- **3b-2 — Real iOS sessions**: replace the fake iOS session buttons with genuine timed/locked sessions matching Mac's precommitment model. **KEY DESIGN DECISION pending** (device-local via iOS Screen Time vs cross-device via the cloud policy) — do not write/execute until confirmed.
- **3b-3 — Fold Blocking into the Tune umbrella**: bring mode + adult sites + blocked apps + blocked websites + sessions under one Tune surface on both platforms; remove the fake iOS "concept blocking", the hardcoded distracting-apps list, and the fake blocked-website defaults. (Also removes the now-inert iOS "Browser only" disabled-row path left over from 3a — see note below.)

> After 3b-1 makes every feature enforceable on `.iosSafari`, the 3a `TuneFeature.isEnforceable` machinery (disabled row + "Browser only" caption + bulk-filter + `iosSafariEnforcedFeatures` forced-false) is always-true / never-triggered — harmless dead paths. Leave them inert here; 3b-3 removes them when it reworks the iOS Tune view.

## Global Constraints

- Tests are a macOS XCTest bundle `QuietGateTests` (`@testable import QuietGate`). No iOS unit-test target — testable logic lives in shared `Tortoise/` files; SwiftUI views are build-verified only.
- **iOS builds are SLOW (~15–25 min).** Run `xcodebuild` via the Bash tool ONLY (never an Xcode/xcodebuild MCP tool — that has hung before); one build at a time, foreground, let it finish.
- macOS tests: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
- iOS build: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
- Pure in-file edits need no `xcodegen`; regenerate + stage `QuietGate.xcodeproj` only if a source file is added/removed.
- Product name **Tortoise**; minimal on-screen text; no fake/demo data; cloud policy is the single source of truth; a feature is honest about where it enforces (catalog `enforceableOn`).

## Available from earlier phases (committed)

- `Tortoise/TuningCatalog.swift`: `iosSafariFeatureIDs` currently excludes `instagramProfileSuggestions`/`instagramNotifications`; `features[].enforceableOn` derives `.iosSafari` from it.
- `Tortoise/TuneScreenModel.swift`: `TuneScreen.features(...).isEnforceable`, `iosSafariEnforcedFeatures(policy:)`.
- `QuietGateTests/TuneScreenModelTests.swift`: `testEnforceabilityIsSurfaceAware` (lines 42-51), `testIosSafariEnforcedFeaturesReflectsPolicyAndDropsUnhookable` (lines 60-69) encode the (incorrect) exclusion.
- iOS launch `onChange` for Safari features in `Tortoise/ContentView.swift` (~line 250); `"youtube"` magic string in `MobileTuningScreen` + `TuningView.swift`.

---

### Task 1: Correct the iOS-Safari enforceability (Instagram honesty fix)

**Why:** the 3a whole-branch review verified the Safari content script DOES handle both features it was marked unable to: `TortoiseSafariExtension/content/instagram.js:368-377` (`markProfileSuggestionItems` / notifications selector) + `instagram.css:13-20` (hiding rules). So the "no hook" exclusion — and the iOS "Browser only" label — is false. Enforce all 42 on iOS Safari.

**Files:**
- Modify: `Tortoise/TuningCatalog.swift:49-52` (`iosSafariFeatureIDs`)
- Modify: `QuietGateTests/TuneScreenModelTests.swift` (the two tests that encode the exclusion)

**Interfaces:** No signature changes. `TuningCatalog.features[*].enforceableOn` now contains `.iosSafari` for ALL 42; `TuneScreen.iosSafariEnforcedFeatures` reflects real policy for every feature (no forced-false).

- [ ] **Step 1: Update the two failing-expectation tests FIRST (they encode the wrong assumption).**

In `QuietGateTests/TuneScreenModelTests.swift`, replace `testEnforceabilityIsSurfaceAware` (lines 42-51) with:

```swift
  func testEnforceabilityIsSurfaceAware() {
    // Browser (chrome) enforces every feature.
    let browser = TuneScreen.features(forSiteID: "instagram", policy: nil, surface: .chromeExtension)
    XCTAssertTrue(browser.allSatisfy(\.isEnforceable))
    // iOS Safari content scripts handle every Instagram feature too (verified in
    // TortoiseSafariExtension/content/instagram.js + instagram.css), so all are enforceable there.
    let safari = TuneScreen.features(forSiteID: "instagram", policy: nil, surface: .iosSafari)
    XCTAssertTrue(safari.allSatisfy(\.isEnforceable))
  }
```

And replace `testIosSafariEnforcedFeaturesReflectsPolicyAndDropsUnhookable` (lines 60-69) with:

```swift
  func testIosSafariEnforcedFeaturesReflectRealPolicy() {
    let safari = TuneScreen.iosSafariEnforcedFeatures(
      policy: policy(featuresOn: ["youtubeShorts", "instagramReels", "instagramNotifications"])
    )
    XCTAssertEqual(Set(safari.keys), Set(TuningCatalog.allFeatureIDs))
    XCTAssertTrue(safari["youtubeShorts"]!)          // enforceable + on
    XCTAssertTrue(safari["instagramReels"]!)         // enforceable + on
    XCTAssertTrue(safari["instagramNotifications"]!) // now enforceable on iOS Safari + on
    XCTAssertFalse(safari["youtubeHome"]!)           // enforceable but off
  }
```

- [ ] **Step 2: Run the tests to confirm they now FAIL against the current catalog**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test -only-testing:QuietGateTests/TuneScreenModelTests`
Expected: FAIL — `testEnforceabilityIsSurfaceAware` (safari still non-enforceable for the two IG features) and `testIosSafariEnforcedFeaturesReflectRealPolicy` (`instagramNotifications` still forced false). This proves the tests exercise the change.

- [ ] **Step 3: Fix the catalog** — in `Tortoise/TuningCatalog.swift`, replace the `iosSafariFeatureIDs` definition (lines 49-52):

```swift
  /// Features the iOS Safari web extension applies via its content scripts. The
  /// scripts handle every catalog feature (incl. the two Instagram surfaces — see
  /// TortoiseSafariExtension/content/instagram.js + instagram.css), so Safari
  /// enforces all of them.
  private static let iosSafariFeatureIDs: Set<String> = Set(allFeatureIDs)
```

- [ ] **Step 4: Run the full macOS suite** — `xcodebuild ... -scheme QuietGate ... test`. Expected: `TuneScreenModelTests` all PASS; whole suite green. If any OTHER pre-existing test (e.g. in `TuningCatalogTests`) asserted the iOS-Safari 2-feature exclusion, update it to the corrected expectation and note it in your report.

- [ ] **Step 5: iOS build** — `xcodebuild ... -scheme Tortoise ... build` → `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit**
```bash
git add Tortoise/TuningCatalog.swift QuietGateTests/TuneScreenModelTests.swift
git commit -m "iOS Safari enforces all tuning features (drop false 'no hook' exclusion)"
```

---

### Task 2: iOS minors — launch `onChange` nil-guard + shared youtube constant

**Files:**
- Modify: `Tortoise/ContentView.swift` (the Safari-features `onChange`; the `"youtube"` literals)
- Modify: `QuietGate/Views/TuningView.swift` (the `"youtube"` default)
- Modify: `Tortoise/TuningCatalog.swift` (add the constant)

**Interfaces:** Adds `TuningCatalog.youtubeSiteID: String`. No other signature change.

- [ ] **Step 1: Read the two Tune views** to find the exact `"youtube"` literals and the Safari-features `onChange`. Grep first: `grep -n '"youtube"' Tortoise/ContentView.swift QuietGate/Views/TuningView.swift` and `grep -n 'onChange(of: model.snapshot.policy?.policy.browser?.features' Tortoise/ContentView.swift`.

- [ ] **Step 2: Add the constant** — in `Tortoise/TuningCatalog.swift`, add inside `enum TuningCatalog`:
```swift
  /// The YouTube site id, referenced by both Tune screens for their Screen-Time card.
  static let youtubeSiteID = "youtube"
```

- [ ] **Step 3: Nil-guard the launch onChange.** Replace the Safari-features `onChange` body (currently `screenTime.applyPolicyFeatures(TuneScreen.iosSafariEnforcedFeatures(policy: model.snapshot.policy?.policy))`) with a guarded version so no all-false map is written before the first real policy loads (matching the sibling daily-limit onChange's `if let`):
```swift
      .onChange(of: model.snapshot.policy?.policy.browser?.features, initial: true) { _, _ in
        if let policy = model.snapshot.policy?.policy {
          screenTime.applyPolicyFeatures(TuneScreen.iosSafariEnforcedFeatures(policy: policy))
        }
      }
```

- [ ] **Step 4: Replace the `"youtube"` literals** in `MobileTuningScreen` (`Tortoise/ContentView.swift`) and `TuningView.swift` with `TuningCatalog.youtubeSiteID` — the `selectedSite == "youtube"` comparisons and the `@State selectedSite = "youtube"` defaults. Leave any user-facing "YouTube" display strings (those come from the catalog `title`, not this id) alone.

- [ ] **Step 5: iOS build** — `xcodebuild ... -scheme Tortoise ... build` → `BUILD SUCCEEDED`.
- [ ] **Step 6: macOS suite** — `xcodebuild ... -scheme QuietGate ... test` → green.

- [ ] **Step 7: Commit**
```bash
git add Tortoise/ContentView.swift QuietGate/Views/TuningView.swift Tortoise/TuningCatalog.swift
git commit -m "iOS Tune: nil-guard the Safari onChange; share a youtube site-id constant"
```

---

## Self-Review

**Spec coverage (3b-1 slice — correctness/honesty sweep):**
- Instagram honesty (§6.3): iOS Safari now enforces all 42 features; the false "Browser only" label no longer applies → Task 1. ✓
- 3a-review minors: launch `onChange` nil-guard (no premature all-false Safari write); shared youtube constant → Task 2. ✓
- Surface-aware counts minor: resolved transitively — after Task 1, every feature is enforceable on both Tune surfaces (`.chromeExtension`, `.iosSafari`), so the site/header counts (= total) are already correct; no separate change needed. (The unused `surface` param on `TuneScreen.sites` is left as-is; harmless.)

**Placeholder scan:** No TBD/TODO. The inert 3a "Browser only" disabled-row path is a documented, harmless leftover removed in 3b-3, not missing work here.

**Type consistency:** `TuningCatalog.iosSafariFeatureIDs`, `TuningCatalog.youtubeSiteID`, `TuneScreen.features(...).isEnforceable`, `TuneScreen.iosSafariEnforcedFeatures(policy:)` used consistently; the two updated tests match the corrected catalog data.

**Out of scope (deferred to later 3b sub-plans / phases):** real iOS sessions (3b-2, pending the design decision); folding Blocking (mode/adult/apps/websites/sessions) into one Tune surface + removing the fake concept-blocking / hardcoded apps / fake website defaults (3b-3); removing the now-inert iOS "Browser only" path (3b-3); Mac augment knobs (3c); real TikTok tuner (Phase 4).
