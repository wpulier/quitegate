# Phase 3b-3b — The Navigation Fold (merge "Blocking" into the one "Tune" umbrella) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reach the spec §3 IA — each app has three destinations **Devices / Tune / Usage**, and "Blocking" is no longer a separate place: its real controls (mode + sessions + adult + apps + websites) live under the one **Tune** surface. This is a pure IA/navigation move over controls that are already 100% real (3b-3a removed the last fake data) — **no new fake data, no new enforcement logic.**

**Architecture:** Two independent sub-plans, one per app, because they touch disjoint files (`QuietGate/Views/*` vs `Tortoise/ContentView.swift`), have different verification (macOS XCTest+build vs slow iOS build-only), and each produces a coherent, shippable app on its own. Within each app the fold is: (1) copy the Blocking screen's real controls into the Tune screen so both are momentarily coherent, then (2) flip the navigation to drop the Blocking destination and delete the now-dead screen. The Tune screen already owns the same four environment objects the Blocking screen used, so the controls move without new plumbing. All 3b-2a locked-session precommitment gates (`timedSessionLockedActive` on Mac / `screenTime.sessionLockedActive` on iOS `.disabled` guards) move verbatim with the controls.

**Tech Stack:** Swift 5, SwiftUI, XCTest, XcodeGen.

## Phase 3b-3b decomposition

- **3b-3b-mac — Fold Blocking into `TuningView` + Mac nav (THIS SUB-PLAN, written in full below).** Mac sidebar `AppSection` → **Devices / Tune / Usage** (remove `.blocking`, retitle `.tuning` label to "Tune"). Move `ControlView`'s real sections — mode selector, session card, adult sites, distracting apps, blocked websites — into `TuningView` as areas, per the `tune-v1` mockup intent (mode at top, Start-a-session at bottom). Delete `ControlView.swift`. macOS-testable (the `AppSection` nav model has a unit test) + build-verified; fast.
- **3b-3b-ios — Fold `MobileBlockingScreen` into `MobileTuningScreen` + drop the Blocking tab (outline below; authored in full at its execution time).** `MobileSection` → **usage / tuning / devices** (drop `.blocking`, label `.tuning` "Tune"). Move the mode selector + the real 3b-2a session UI into `MobileTuningScreen`; update every `.blocking` reference (`initialSection`/deep-link/`fixSetup`). iOS build-verified only (no iOS unit-test target); slow.

**Sequence:** do **3b-3b-mac first** (fast feedback, and its `AppSection` change is genuinely TDD'd), then **3b-3b-ios**. They are independent and could be parallelized, but Mac-first surfaces any IA/ordering surprise cheaply before paying the 15-25 min iOS build.

## Global Constraints

- Tests are a macOS XCTest bundle `QuietGateTests` (`@testable import QuietGate`). No iOS unit-test target — any testable logic in shared `Tortoise/` code is TDD'd on macOS; SwiftUI views are build-verified only. The `AppSection` nav enum is macOS-target code and **is** unit-tested (`ProtectionStoreTests`), so the Mac nav change is TDD'd.
- **iOS builds are SLOW (~15-25 min).** Run `xcodebuild` via the Bash tool ONLY (never an Xcode/xcodebuild MCP tool — that has hung); one build at a time, foreground, let it finish.
- macOS tests: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
- iOS build: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
- Pure in-file view edits need no `xcodegen`. **Deleting a Mac View file DOES need it:** the macOS `QuietGate` target sources include the `QuietGate` directory as a group (`project.yml:31`), so a deleted file must be dropped from the project via `xcodegen generate --spec project.yml --project .` + staging `QuietGate.xcodeproj`.
- Product name **Tortoise**; minimal on-screen text; **NO fake/demo data reintroduced**; a control only appears where it is real (per confirmed decisions — no iOS apps section, no separate iOS adult toggle); **all 3b-2a locked-session precommitment gates must remain intact** after the move.

## Confirmed decisions (baked in — do not re-litigate)

1. **Three destinations: Devices / Tune / Usage.** Controls live in Devices + Tune; **Usage stays a separate insight surface** (analytics, NOT folded into Tune).
2. **Apps:** Mac keeps its real installed-apps blocking (moves into Tune); **iOS gets NO general apps section** (no iOS app-closing mechanism; iOS targeting stays the Screen Time picker).
3. **Adult sites:** Mac has a real adult toggle (moves into Tune); **iOS adult stays mode-driven** (Strict → Screen Time web filter), no separate iOS adult toggle.
4. **`coverageCard` is NOT moved.** `ControlView.coverageCard` ("Blocks are enforced across these accounts & devices" + "Expand to another device") is device-coverage display that the **Devices** hub (`ProtectionView`) already owns, and its Add action is already reachable from `TuningView.scopeCard`'s "Add" button. It is dropped with `ControlView`, not carried into Tune. (Residual decision — see end.)

## Ground truth (verified in the current tree)

- Mac nav: `QuietGate/Views/ContentView.swift` — `enum AppSection` (`:5-30`, cases `devices/blocking/tuning/usage`), `detailView` switch (`:126-137`), `QGSidebar` iterates `AppSection.allCases` (`:304`), `@SceneStorage("quietgate.selectedSection")` defaults to `.devices` and falls back to `.devices` on an unknown rawValue (`:38-48`).
- Mac Blocking screen: `QuietGate/Views/ControlView.swift` (663 lines). Real sections that move: `accessModeSection` (`:46-78`), `sessionCard` (`:80-114`) + `sessionButton` (`:330-350`) + `sessionDetail` (`:321-328`), `conceptSection` (`:145-171`) + `conceptRows` (`:370-384`, single real `.adultContent` row) + `categoryBinding`/`toggleCategory` (`:395-419`), `lowerGrid` (`:173-182`) → `distractingAppsCard` (`:184-236`) + `addAppMenu` (`:238-269`) + `addableApplications` (`:386-389`) + `blockedAppBinding` (`:457-470`), `blockedWebsitesCard` (`:271-319`) + `displayedSites` (`:391-393`) + `addCustomDomain` (`:421-437`) + `deleteSite` (`:439-455`). The `.task` at `:36-40` (refresh + scan installed apps + start monitoring) must move too. Private subviews to relocate: `ModeChoiceCard` (`:482-528`), `ConceptBlockingRow` (`:553-590`), `AppBlockingToggleRow` (`:592-614`), `BlockedWebsiteRow` (`:616-642`), `ConceptRowModel` (`:651-662`). NOT moved: `coverageCard`, `CoverageChip`, `CoverageChipModel`, `avatar(for:)` (TuningView already has an identical `avatar(for:)` at `TuningView.swift:220-227`).
- Mac Tune screen: `QuietGate/Views/TuningView.swift` (370 lines). Already has `@Environment(Clerk.self) clerk`, `@EnvironmentObject store/appBlockingStore/accountStore`, `@State selectedSite/addSheetPresented`, `avatar(for:)`, and `.sheet(AddSheetView())`. Body (`:26-54`) is header → `siteGrid` → `selectedSiteHeader` → `scopeCard` → `featuresCard`. It has **no** `.task` today.
- `ControlView` is referenced in exactly one place: `ContentView.swift:131`. Deleting it touches nothing else.
- Nav unit test: `QuietGateTests/ProtectionStoreTests.swift:29-34` asserts `AppSection.allCases == [.devices, .blocking, .tuning, .usage]` and titles `["Devices","Blocking","Tuning","Usage"]`. This is the TDD anchor for the nav flip.

---

# SUB-PLAN 3b-3b-mac — Fold Blocking into `TuningView` + Mac nav

**Strategy (coherent app throughout):** Tasks 1-2 copy the real controls into `TuningView` while `ControlView`/Blocking is still live (so no real control is ever unreachable — momentarily duplicated is fine and reversible). Task 3 flips the nav (TDD) and deletes `ControlView`. Note: the relocated private subviews (`ModeChoiceCard`, etc.) are top-level `private` — i.e. **file-scoped** — so `TuningView.swift` and `ControlView.swift` may each hold a same-named copy during Tasks 1-2 with no symbol collision; Task 3 deletes `ControlView.swift`'s copies.

---

### Task 1: Tune — add the mode selector (top) and the session card (bottom)

**Files:**
- Modify: `QuietGate/Views/TuningView.swift`
- Test: none new (view; build-verified; the nav model is TDD'd in Task 3).

**Interfaces:**
- Consumes (already on `TuningView`): `store`, `accountStore`, `clerk`, `appBlockingStore`; `store.accessMode`, `store.blockingControlsReady`, `store.isWorking`, `store.timedSessionLockedActive`, `store.timedSessionActive`, `store.timedSessionStatusLine`, `store.blockingCapabilityUnavailableReason`, `accountStore.setAccessMode(_:using:protectionStore:appBlockingStore:)`, `store.startTimedSession(mode:duration:locked:)`, `store.endTimedSession()`.
- Produces: `accessModeSection`, `sessionCard`, `sessionButton(...)`, `sessionDetail` on `TuningView`; a file-scoped `private struct ModeChoiceCard`.

- [ ] **Step 1: Insert `accessModeSection` at the top of the body and `sessionCard` at the bottom.** In `TuningView.body`, change the content block (currently header → `siteGrid` → `selectedSiteHeader` → `scopeCard` → `featuresCard`) to place `accessModeSection` first and `sessionCard` last:

```swift
    QGPage(maxWidth: 820) {
      QGScreenHeader(
        title: "Tuning",
        subtitle: "Strip the noisy parts of a site without blocking it. Applies in every connected browser profile."
      )

      accessModeSection

      siteGrid
      selectedSiteHeader
      scopeCard
      featuresCard

      sessionCard

      if let extensionBridgeMessage = store.extensionBridgeMessage {
        Label(extensionBridgeMessage, systemImage: "info.circle")
          .font(.system(size: 13))
          .foregroundStyle(QGDesign.secondaryText)
          .textSelection(.enabled)
      }

      if let errorMessage = store.errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle")
          .font(.system(size: 13))
          .foregroundStyle(QGDesign.orange)
      }
    }
```
(Leave the header title/subtitle as-is for now — Task 2 retitles to "Tune" once all areas are present.)

- [ ] **Step 2: Add `accessModeSection`, `sessionCard`, `sessionButton`, `sessionDetail` as members of `TuningView`** (paste inside the `struct TuningView`, e.g. just after `avatar(for:)`):

```swift
  private var accessModeSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      QGSectionLabel(text: "Access mode")
      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 230), spacing: 12)],
        alignment: .leading,
        spacing: 12
      ) {
        ForEach(AccessMode.allCases) { mode in
          Button {
            guard !store.timedSessionLockedActive else { return }
            Task {
              await accountStore.setAccessMode(
                mode,
                using: clerk,
                protectionStore: store,
                appBlockingStore: appBlockingStore
              )
            }
          } label: {
            ModeChoiceCard(mode: mode, isSelected: store.accessMode == mode)
          }
          .buttonStyle(.plain)
          .disabled(!store.blockingControlsReady || store.isWorking || store.timedSessionLockedActive)
        }
      }
      if let reason = store.blockingCapabilityUnavailableReason {
        Label(reason, systemImage: "lock")
          .font(.system(size: 12))
          .foregroundStyle(QGDesign.secondaryText)
      }
    }
  }

  private var sessionCard: some View {
    QGCard {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 5) {
            Text("Commit to a session")
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(QGDesign.primaryText)
            Text(sessionDetail)
              .font(.system(size: 13))
              .foregroundStyle(QGDesign.secondaryText)
          }
          Spacer()
          Text(store.timedSessionActive ? store.timedSessionStatusLine : "Returns to Open when the timer ends")
            .font(.system(size: 12))
            .foregroundStyle(QGDesign.secondaryText)
        }

        HStack(spacing: 10) {
          sessionButton(title: "Focus · 25m", mode: .focus, duration: 25 * 60)
          sessionButton(title: "Focus · 1h", mode: .focus, duration: 60 * 60)
          sessionButton(title: "Lock Strict · 2h", mode: .strict, duration: 2 * 3600, locked: true, systemImage: "lock")

          if store.timedSessionActive && !store.timedSessionLockedActive {
            Button(role: .destructive) {
              Task { await store.endTimedSession() }
            } label: {
              Text("End")
            }
            .buttonStyle(QGPrimaryButtonStyle(tint: QGDesign.red))
          }
        }
      }
    }
  }

  private var sessionDetail: String {
    if store.timedSessionActive {
      return store.timedSessionLockedActive
        ? "A locked Strict session can't be ended, weakened, or quit early - that's the point."
        : "Your focus session is running. End it early or let it return to Open."
    }
    return "Lock in a block of time. A locked Strict session can't be ended, weakened, or quit early - that's the point."
  }

  private func sessionButton(
    title: String,
    mode: AccessMode,
    duration: TimeInterval,
    locked: Bool = false,
    systemImage: String? = nil
  ) -> some View {
    Button {
      Task {
        await store.startTimedSession(mode: mode, duration: duration, locked: locked)
      }
    } label: {
      if let systemImage {
        Label(title, systemImage: systemImage)
      } else {
        Text(title)
      }
    }
    .buttonStyle(QGPrimaryButtonStyle(tint: locked ? QGDesign.purple : QGDesign.accent))
    .disabled(!store.blockingControlsReady || store.isWorking || store.timedSessionLockedActive)
  }
```

- [ ] **Step 3: Add the `ModeChoiceCard` private subview** at file scope in `TuningView.swift` (e.g. after the `TuningView` struct, before `TuningSiteTile`):

```swift
private struct ModeChoiceCard: View {
  let mode: AccessMode
  let isSelected: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Image(systemName: mode.systemImage)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(isSelected ? QGDesign.accent : QGDesign.secondaryText)
        Spacer()
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(QGDesign.accent)
        }
      }

      VStack(alignment: .leading, spacing: 5) {
        Text(mode.title)
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(QGDesign.primaryText)
        Text(detail)
          .font(.system(size: 12))
          .foregroundStyle(QGDesign.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
    .background(QGDesign.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(isSelected ? QGDesign.accent : QGDesign.strongHairline)
    }
  }

  private var detail: String {
    switch mode {
    case .open:
      return "No Tortoise rules applied. Everything is available."
    case .focus:
      return "Adult blocking on. Feeds, Shorts, Reels & recommendations hidden."
    case .strict:
      return "Everything tuned to intentional use. Daily limits enforced."
    }
  }
}
```

- [ ] **Step 4: Build + full macOS suite** — `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`. Expected: `BUILD SUCCEEDED`, suite green (no test change yet; `ProtectionStoreTests` still passes because `AppSection` is untouched). `ControlView.swift` still compiles with its own `ModeChoiceCard` copy — the file-scoped `private` duplication is legal.

- [ ] **Step 5: Commit**
```bash
git add QuietGate/Views/TuningView.swift
git commit -m "Mac Tune: add mode selector + session card (fold from Blocking, step 1/3)"
```

---

### Task 2: Tune — add adult sites, distracting apps, blocked websites (+ the data `.task`, + retitle "Tune")

**Files:**
- Modify: `QuietGate/Views/TuningView.swift`
- Test: none new (view; build-verified).

**Interfaces:**
- Consumes (already available): `store.blockCategories`, `store.setBlockCategory(_:enabled:)`, `store.blockRuleEditingReady`, `accountStore.pushLocalPolicy(...)`, `appBlockingStore.enforcementEnabled`, `appBlockingStore.blockedApplications`, `appBlockingStore.availableApplications`, `appBlockingStore.addBlockedApplication(_:)`, `appBlockingStore.setBlockedApplication(_:enabled:)`, `appBlockingStore.removeBlockedApplication(_:)`, `appBlockingStore.refreshAvailableApplications()`, `appBlockingStore.startMonitoring()`, `store.customDomainDraft`, `store.blockedSites`, `store.addCustomDomain()`, `store.deleteBlockedSite(_:)`, `store.refreshProtectionStatus()`; types `BlockCategoryID`, `RunningApplicationSnapshot`, `BlockedApplicationRule`, `BlockedSiteRule`.
- Produces on `TuningView`: `@State pendingCategoryIDs/pendingSiteDomains/addingCustomDomain`; `conceptSection`, `lowerGrid`, `distractingAppsCard`, `addAppMenu`, `blockedWebsitesCard`, `conceptRows`, `addableApplications`, `displayedSites`, `categoryBinding`, `toggleCategory`, `addCustomDomain`, `deleteSite`, `blockedAppBinding`; file-scoped `private struct`s `ConceptBlockingRow`, `AppBlockingToggleRow`, `BlockedWebsiteRow`, `ConceptRowModel`.

- [ ] **Step 1: Add the three `@State` properties** at the top of `struct TuningView` (next to `selectedSite`/`addSheetPresented`):
```swift
  @State private var pendingCategoryIDs: Set<BlockCategoryID> = []
  @State private var pendingSiteDomains: Set<String> = []
  @State private var addingCustomDomain = false
```

- [ ] **Step 2: Wire the three areas into the body and retitle the header.** Update the body content order to place adult + apps + websites between the site tuning and the session card, and change the header to "Tune":

```swift
    QGPage(maxWidth: 820) {
      QGScreenHeader(
        title: "Tune",
        subtitle: "Set your mode, shape each site, and choose what's blocked. Enforced wherever you're connected."
      )

      accessModeSection

      siteGrid
      selectedSiteHeader
      scopeCard
      featuresCard

      conceptSection
      lowerGrid

      sessionCard

      if let extensionBridgeMessage = store.extensionBridgeMessage {
        Label(extensionBridgeMessage, systemImage: "info.circle")
          .font(.system(size: 13))
          .foregroundStyle(QGDesign.secondaryText)
          .textSelection(.enabled)
      }

      if let errorMessage = store.errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle")
          .font(.system(size: 13))
          .foregroundStyle(QGDesign.orange)
      }
    }
```

- [ ] **Step 3: Add the data-loading `.task` to the body** (TuningView has none today; the apps/blocking data won't populate without it). Attach it alongside the existing `.sheet` modifier on `QGPage`:
```swift
    .task {
      await store.refreshProtectionStatus()
      appBlockingStore.refreshAvailableApplications()
      appBlockingStore.startMonitoring()
    }
    .sheet(isPresented: $addSheetPresented) {
      AddSheetView()
    }
```

- [ ] **Step 4: Add the area view members + helpers** to `struct TuningView`:

```swift
  private var conceptSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      QGSectionLabel(text: "Adult sites")
      QGCard {
        VStack(spacing: 0) {
          ForEach(Array(conceptRows.enumerated()), id: \.element.id) { index, row in
            if index > 0 {
              ProductDivider()
                .padding(.vertical, 12)
            }
            ConceptBlockingRow(
              row: row,
              isOn: row.binding,
              isEnabled: row.isActionable
                && store.blockRuleEditingReady
                && !store.timedSessionLockedActive
                && !pendingCategoryIDs.contains(row.categoryID)
            ) { enabled in
              if row.isActionable {
                toggleCategory(row.categoryID, enabled: enabled)
              }
            }
          }
        }
      }
    }
  }

  private var lowerGrid: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 330), spacing: 14, alignment: .top)],
      alignment: .leading,
      spacing: 14
    ) {
      distractingAppsCard
      blockedWebsitesCard
    }
  }

  private var distractingAppsCard: some View {
    QGCard {
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top, spacing: 12) {
          VStack(alignment: .leading, spacing: 3) {
            Text("Distracting apps")
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(QGDesign.primaryText)
            Text(appBlockingStore.enforcementEnabled ? "Closed on launch while a session runs." : "Saved, but app closing is paused.")
              .font(.system(size: 12))
              .foregroundStyle(QGDesign.secondaryText)
          }
          Spacer()
          QGSwitch(isOn: Binding(
            get: { appBlockingStore.enforcementEnabled },
            set: { enabled in
              appBlockingStore.enforcementEnabled = enabled
              Task {
                await accountStore.pushLocalPolicy(
                  using: clerk,
                  protectionStore: store,
                  appBlockingStore: appBlockingStore
                )
              }
            }
          ))
        }

        if appBlockingStore.blockedApplications.isEmpty {
          Text("No apps blocked yet — add one below.")
            .font(.system(size: 12))
            .foregroundStyle(QGDesign.secondaryText)
        } else {
          VStack(spacing: 0) {
            ForEach(appBlockingStore.blockedApplications) { rule in
              AppBlockingToggleRow(
                displayName: rule.displayName,
                avatar: avatar(for: rule.displayName),
                isOn: blockedAppBinding(for: rule),
                removeAction: { appBlockingStore.removeBlockedApplication(rule.bundleIdentifier) }
              )
              if rule.id != appBlockingStore.blockedApplications.last?.id {
                ProductDivider()
                  .padding(.vertical, 10)
              }
            }
          }
        }

        addAppMenu
      }
    }
  }

  private var addAppMenu: some View {
    Group {
      if appBlockingStore.availableApplications.isEmpty {
        Text("Scanning installed apps…")
          .font(.system(size: 12))
          .foregroundStyle(QGDesign.secondaryText)
      } else if addableApplications.isEmpty {
        Text("Every scanned app is already blocked.")
          .font(.system(size: 12))
          .foregroundStyle(QGDesign.secondaryText)
      } else {
        Menu {
          ForEach(addableApplications) { app in
            Button(app.displayName) {
              appBlockingStore.addBlockedApplication(app)
              Task {
                await accountStore.pushLocalPolicy(
                  using: clerk,
                  protectionStore: store,
                  appBlockingStore: appBlockingStore
                )
              }
            }
          }
        } label: {
          Label("Add app", systemImage: "plus")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
      }
    }
  }

  private var blockedWebsitesCard: some View {
    QGCard {
      VStack(alignment: .leading, spacing: 14) {
        Text("Blocked websites")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(QGDesign.primaryText)

        HStack(spacing: 8) {
          TextField("Add a domain...", text: $store.customDomainDraft)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(QGDesign.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(QGDesign.field, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .disabled(addingCustomDomain || !store.blockRuleEditingReady)
            .onSubmit(addCustomDomain)

          Button("Add", action: addCustomDomain)
            .buttonStyle(QGPrimaryButtonStyle())
            .disabled(
              store.customDomainDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || addingCustomDomain
                || !store.blockRuleEditingReady
            )
        }

        if displayedSites.isEmpty {
          Text("No blocked sites yet — add a domain above.")
            .font(.system(size: 12))
            .foregroundStyle(QGDesign.secondaryText)
        } else {
          VStack(spacing: 0) {
            ForEach(displayedSites) { site in
              BlockedWebsiteRow(
                site: site,
                isPending: pendingSiteDomains.contains(site.domain),
                deleteAction: { deleteSite(site.domain) }
              )
              if site.id != displayedSites.last?.id {
                ProductDivider()
                  .padding(.vertical, 10)
              }
            }
          }
        }
      }
    }
  }

  private var conceptRows: [ConceptRowModel] {
    [
      ConceptRowModel(
        categoryID: .adultContent,
        icon: "figure.mixed.cardio",
        iconTint: QGDesign.red,
        iconBackground: QGDesign.red.opacity(0.16),
        title: "Pornography & adult content",
        badge: "LOCKED IN STRICT",
        detail: "Blocks adult domains, adult-host media, and high-confidence explicit pages across every connected browser.",
        isActionable: true,
        binding: categoryBinding(.adultContent)
      )
    ]
  }

  private var addableApplications: [RunningApplicationSnapshot] {
    let blockedIDs = Set(appBlockingStore.blockedApplications.map(\.bundleIdentifier))
    return appBlockingStore.availableApplications.filter { !blockedIDs.contains($0.bundleIdentifier) }
  }

  private var displayedSites: [BlockedSiteRule] {
    store.blockedSites
  }

  private func categoryBinding(_ id: BlockCategoryID) -> Binding<Bool> {
    Binding {
      store.blockCategories.first { $0.id == id }?.isEnabled ?? (store.accessMode != .open)
    } set: { enabled in
      toggleCategory(id, enabled: enabled)
    }
  }

  private func toggleCategory(_ id: BlockCategoryID, enabled: Bool) {
    guard !pendingCategoryIDs.contains(id) else {
      return
    }
    pendingCategoryIDs.insert(id)
    Task {
      await store.setBlockCategory(id, enabled: enabled)
      await accountStore.pushLocalPolicy(
        using: clerk,
        protectionStore: store,
        appBlockingStore: appBlockingStore
      )
      await MainActor.run {
        _ = pendingCategoryIDs.remove(id)
      }
    }
  }

  private func addCustomDomain() {
    guard !addingCustomDomain else {
      return
    }
    addingCustomDomain = true
    Task {
      await store.addCustomDomain()
      await accountStore.pushLocalPolicy(
        using: clerk,
        protectionStore: store,
        appBlockingStore: appBlockingStore
      )
      await MainActor.run {
        addingCustomDomain = false
      }
    }
  }

  private func deleteSite(_ domain: String) {
    guard !pendingSiteDomains.contains(domain), store.blockedSites.contains(where: { $0.domain == domain }) else {
      return
    }
    pendingSiteDomains.insert(domain)
    Task {
      await store.deleteBlockedSite(domain)
      await accountStore.pushLocalPolicy(
        using: clerk,
        protectionStore: store,
        appBlockingStore: appBlockingStore
      )
      await MainActor.run {
        _ = pendingSiteDomains.remove(domain)
      }
    }
  }

  private func blockedAppBinding(for rule: BlockedApplicationRule) -> Binding<Bool> {
    Binding {
      rule.isEnabled
    } set: { enabled in
      appBlockingStore.setBlockedApplication(rule.bundleIdentifier, enabled: enabled)
      Task {
        await accountStore.pushLocalPolicy(
          using: clerk,
          protectionStore: store,
          appBlockingStore: appBlockingStore
        )
      }
    }
  }
```

- [ ] **Step 5: Add the four private subviews at file scope** in `TuningView.swift` (after `ModeChoiceCard` from Task 1):

```swift
private struct ConceptBlockingRow: View {
  let row: ConceptRowModel
  @Binding var isOn: Bool
  let isEnabled: Bool
  let action: (Bool) -> Void

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: row.icon)
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(row.iconTint)
        .frame(width: 38, height: 38)
        .background(row.iconBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 8) {
          Text(row.title)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(QGDesign.primaryText)
          if let badge = row.badge {
            QGPill(text: badge, tint: QGDesign.purple)
          }
        }
        Text(row.detail)
          .font(.system(size: 12))
          .foregroundStyle(QGDesign.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 14)

      QGSwitch(isOn: Binding(get: { isOn }, set: { value in
        isOn = value
        action(value)
      }), isEnabled: isEnabled)
    }
  }
}

private struct AppBlockingToggleRow: View {
  let displayName: String
  let avatar: String
  @Binding var isOn: Bool
  let removeAction: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      QGAvatar(text: avatar, size: 34, cornerRadius: 8)
      Text(displayName)
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(QGDesign.primaryText)
      Spacer()
      QGSwitch(isOn: $isOn)
      Button(action: removeAction) {
        Image(systemName: "xmark")
          .font(.system(size: 11, weight: .bold))
      }
      .buttonStyle(.plain)
      .foregroundStyle(QGDesign.secondaryText)
    }
  }
}

private struct BlockedWebsiteRow: View {
  let site: BlockedSiteRule
  let isPending: Bool
  let deleteAction: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "lock")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(QGDesign.orange)
        .frame(width: 28, height: 28)
        .background(QGDesign.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      Text(site.domain)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(QGDesign.primaryText)
      Spacer()
      Button(action: deleteAction) {
        Image(systemName: "xmark")
          .font(.system(size: 11, weight: .bold))
      }
      .buttonStyle(.plain)
      .foregroundStyle(QGDesign.secondaryText)
      .disabled(isPending)
    }
    .opacity(site.isEnabled ? 1 : 0.55)
  }
}

private struct ConceptRowModel: Identifiable {
  let id = UUID()
  let categoryID: BlockCategoryID
  let icon: String
  let iconTint: Color
  let iconBackground: Color
  let title: String
  let badge: String?
  let detail: String
  let isActionable: Bool
  let binding: Binding<Bool>
}
```

- [ ] **Step 6: Build + full macOS suite** — same command as Task 1 Step 4. Expected: `BUILD SUCCEEDED`, suite green. `ControlView.swift` still compiles (still holds its own copies of these private structs — file-scoped, no collision). Grep-guard the new file has exactly one of each moved type: `grep -c 'struct ConceptBlockingRow' QuietGate/Views/TuningView.swift` → `1`.

- [ ] **Step 7: Commit**
```bash
git add QuietGate/Views/TuningView.swift
git commit -m "Mac Tune: add adult / apps / websites areas + retitle 'Tune' (fold step 2/3)"
```

---

### Task 3: Flip the Mac nav to Devices / Tune / Usage and delete `ControlView`

**Files:**
- Test: `QuietGateTests/ProtectionStoreTests.swift:29-34` (update the nav assertion — TDD).
- Modify: `QuietGate/Views/ContentView.swift` (`AppSection` enum `:5-30`; `detailView` `:126-137`).
- Delete: `QuietGate/Views/ControlView.swift`.
- Modify: `project.yml` is unchanged (the file is picked up by the `QuietGate` group, not an explicit entry) — but `QuietGate.xcodeproj` must be regenerated so the reference is dropped.

**Interfaces:**
- Produces: `AppSection` with cases `[.devices, .tuning, .usage]`, titles `["Devices","Tune","Usage"]`.

- [ ] **Step 1: Update the failing test first (TDD).** In `QuietGateTests/ProtectionStoreTests.swift`, replace the body of `testPublicNavigationDoesNotExposeLegacyHistoryOrDNSSetup`:
```swift
  func testPublicNavigationDoesNotExposeLegacyHistoryOrDNSSetup() {
    XCTAssertEqual(AppSection.allCases, [.devices, .tuning, .usage])
    XCTAssertEqual(AppSection.allCases.map(\.title), ["Devices", "Tune", "Usage"])
    XCTAssertFalse(AppSection.allCases.map(\.title).contains("Blocking"))
    XCTAssertFalse(AppSection.allCases.map(\.title).contains("History"))
    XCTAssertFalse(AppSection.allCases.map(\.title).contains("Activity"))
  }
```

- [ ] **Step 2: Run the test to verify it fails** — `xcodebuild ... -scheme QuietGate ... test` (or the single test). Expected: **FAIL** — the current `AppSection` still contains `.blocking`, so `allCases` and `titles` don't match. (This is the red step; a compile failure here would only occur if `.blocking` were already gone — it is not.)

- [ ] **Step 3: Update the `AppSection` enum** in `QuietGate/Views/ContentView.swift` — remove the `.blocking` case and retitle `.tuning`:
```swift
enum AppSection: String, CaseIterable, Identifiable {
  case devices
  case tuning
  case usage

  var id: String { rawValue }

  var title: String {
    switch self {
    case .devices: return "Devices"
    case .tuning: return "Tune"
    case .usage: return "Usage"
    }
  }

  var systemImage: String {
    switch self {
    case .devices: return "macbook.and.iphone"
    case .tuning: return "slider.horizontal.3"
    case .usage: return "chart.bar"
    }
  }
}
```
(Keep the raw value `tuning` for `.tuning` — do not rename the case — so the `@SceneStorage("quietgate.selectedSection")` value survives. A previously-stored `"blocking"` decodes to `nil` and the existing `?? .devices` fallback at `ContentView.swift:44` sends the user to Devices — no crash.)

- [ ] **Step 4: Remove the `.blocking` arm of `detailView`** in `QuietGate/Views/ContentView.swift`:
```swift
  @ViewBuilder
  private var detailView: some View {
    switch selectedSection.wrappedValue {
    case .devices:
      ProtectionView()
    case .tuning:
      TuningView()
    case .usage:
      QuietGateUsageView()
    }
  }
```

- [ ] **Step 5: Delete the dead Blocking screen** — `rm QuietGate/Views/ControlView.swift`. (Confirmed sole reference was `detailView`, removed in Step 4. `ControlView.swift`'s copies of `ModeChoiceCard`/`ConceptBlockingRow`/`AppBlockingToggleRow`/`BlockedWebsiteRow`/`ConceptRowModel` go with it; `TuningView.swift` keeps the copies added in Tasks 1-2.)

- [ ] **Step 6: Regenerate the project** so the deleted file is dropped from `QuietGate.xcodeproj` — `xcodegen generate --spec project.yml --project .` (expect `Created project at .../QuietGate.xcodeproj`).

- [ ] **Step 7: Run the test to verify it passes + full suite** — `xcodebuild ... -scheme QuietGate ... test`. Expected: `BUILD SUCCEEDED`; `testPublicNavigationDoesNotExposeLegacyHistoryOrDNSSetup` PASS; whole suite green. Guard: `grep -rn 'ControlView\|\.blocking' QuietGate/Views/ContentView.swift` → no matches; `test ! -f QuietGate/Views/ControlView.swift` → true.

- [ ] **Step 8: iOS build guard** — the Mac changes touched no `Tortoise/` file, but the shared `QuietGate.xcodeproj` was regenerated; confirm iOS still builds: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build` → `BUILD SUCCEEDED`. (SLOW; run once, foreground.)

- [ ] **Step 9: Commit**
```bash
git add QuietGate/Views/ContentView.swift QuietGate/Views/ControlView.swift QuietGate.xcodeproj QuietGateTests/ProtectionStoreTests.swift
git commit -m "Mac nav: fold Blocking into Tune (Devices / Tune / Usage); delete ControlView"
```

---

## Self-Review (3b-3b-mac)

**Spec coverage (§3 IA + §6 Tune contents, Mac):**
- Sidebar → Devices / Tune / Usage (remove Blocking) → Task 3 (TDD'd via `AppSection` test). ✓
- Mode selector (Open/Focus/Strict) in Tune → Task 1. ✓
- Real session card (timed/locked precommitment) in Tune → Task 1 (moved verbatim, incl. `!store.timedSessionLockedActive` disables + locked `sessionDetail`). ✓
- Adult sites (single real `.adultContent` row) in Tune → Task 2. ✓
- Apps (real installed apps via `AppBlockingStore`) in Tune → Task 2. ✓
- Blocked websites (real list + add/delete) in Tune → Task 2. ✓
- Usage stays a separate destination (confirmed decision 1) — `QuietGateUsageView` untouched. ✓
- `coverageCard` intentionally dropped (confirmed decision 4) — Devices owns coverage. ✓

**Precommitment integrity:** every moved control kept its `store.timedSessionLockedActive` guard: mode buttons (`.disabled(... || store.timedSessionLockedActive)` + early `guard`), `sessionButton` (`.disabled(... || store.timedSessionLockedActive)`), adult row (`isEnabled: ... && !store.timedSessionLockedActive`). The existing site `featuresCard`/`selectedSiteHeader` already gate on `store.timedSessionLockedActive`. No gate was loosened by the move. ✓

**Placeholder scan:** no TBD/TODO; every step is exact code or an exact command with expected output. No fake data added — all moved code reads real stores.

**Type consistency:** moved members reference APIs verified present on `TuningView`'s existing env objects (`store`/`accountStore`/`clerk`/`appBlockingStore`); `avatar(for:)` reused (not duplicated); moved types (`ModeChoiceCard`, `ConceptBlockingRow`, `AppBlockingToggleRow`, `BlockedWebsiteRow`, `ConceptRowModel`) match their `ControlView` originals verbatim and are added exactly once to `TuningView.swift`. The `.task` loader (refresh + scan installed apps + start monitoring) is carried over so Tune populates apps/blocking data that `TuningView` never loaded before.

**Coherence between tasks:** after Task 1 and Task 2, Blocking is still a live destination showing the same controls (temporary, harmless duplication via file-scoped `private`); Task 3 removes it. No real control is ever unreachable mid-plan.

---

# SUB-PLAN 3b-3b-ios — Fold `MobileBlockingScreen` into `MobileTuningScreen` + drop the Blocking tab

> Authored as a task **outline** here; write it in full (verbatim SwiftUI code, per writing-plans) when it is scheduled. Do 3b-3b-mac first. All edits are in one file: `Tortoise/ContentView.swift` (iOS build-verified only — no iOS unit-test target).

**Ground truth:** `MobileSection` enum (`:2194-2219`, cases `usage/blocking/tuning/devices`); shell `section` state + `screenContent` switch (`:279-309`); `bottomTabBar` iterates `MobileSection.allCases` (`:394`); `initialSection` default `.usage` (`:204`), screenshot `initialSection` (`:106-113`); `MobileBlockingScreen` (`:557-644`) = mode selector + `MobileIOSYouTubeStatusCard` + real 3b-2a session card (`startSession`/`endSession`/`sessionStatusLine`/`sessionLockedActive`) + iPhone note; `MobileTuningScreen` (`:646-839`) = sites + per-site detail; helper structs `MobileModeRow` (`:1895`) / `MobileSessionButton` (`:1926`) are file-scoped `private` and used only by Blocking today. Four `.blocking` references to update: `ContentView.swift:20` (`showsGuidedSetup`), `:227` (`fixSetup`), `:328` and `:363` (redirects when `!screenTime.canTurnOn`).

**Confirmed for iOS (decisions 2-3):** iOS gets **no** general Apps section and **no** separate adult toggle. So only the **mode selector** and the **session card** move from Blocking into Tune. The `MobileIOSYouTubeStatusCard` already renders inside `MobileTuningScreen` for the YouTube site, so it is NOT added again at Tune top level (avoid a duplicate). The iPhone Screen-Time note can move into Tune as a single footer card or be dropped (it duplicates the guided-setup card) — decide at authoring; recommend keeping one concise note.

### Task i1: `MobileTuningScreen` accepts mode + session inputs and renders them at the top
- Add parameters to `MobileTuningScreen`: `accessMode: MobileAccessMode`, `isSyncing: Bool`, `selectMode: (MobileAccessMode) -> Void` (it already has `screenTime`, which owns the session API).
- At the top of its body (above the site grid), render the mode selector loop (moved verbatim from `MobileBlockingScreen:572-582`, keeping `.disabled(isSyncing || screenTime.sessionLockedActive)`) and the "Commit to a session" `MobileCard` (moved verbatim from `:586-630`, keeping every `.disabled(screenTime.sessionLockedActive)` and the `sessionActive`/`sessionLockedActive` status/End-session/Locked logic intact — this is the 3b-2a precommitment UI; do not alter it).
- `MobileModeRow` and `MobileSessionButton` stay where they are (file-scoped, still in the same file) — no move needed.
- Update the shell's `screenContent` `.tuning` arm to pass `accessMode: currentAccessMode`, `isSyncing: model.isSyncing`, `selectMode: setAccessMode`.
- iOS build → `BUILD SUCCEEDED`. Commit. (Blocking tab still live and unchanged — coherent, momentarily duplicated.)

### Task i2: Drop `.blocking` from `MobileSection`, delete `MobileBlockingScreen`, retarget the redirects, retitle "Tune"
- `MobileSection`: remove `case blocking`; change `.tuning` title to `"Tune"` (keep rawValue `tuning`). Result order in the tab bar: `usage / tuning / devices` (Usage, Tune, Devices).
- `screenContent`: remove the `case .blocking:` arm and the `MobileBlockingScreen(...)` call; delete the `struct MobileBlockingScreen` (`:557-644`) and, if now unused, its no-longer-referenced helpers (verify `MobileModeRow`/`MobileSessionButton` are still referenced by the moved-into-Tune code — they are — so keep them).
- Retarget the four `.blocking` references to `.tuning`: `:20` `showsGuidedSetup: TortoiseScreenshot.initialSection == .tuning`; `:227` `fixSetup: { section = .tuning }`; `:328` and `:363` `section = .tuning`. (These now land on the Tune screen where the mode/setup lives — same intent, new home.)
- `MobileTuningScreen`'s header title → `"Tune"` (from `"Tuning"`), and set its subtitle to reflect mode + tuning (e.g. "Set your mode, then shape each site. Enforced wherever you're connected.").
- Retitle Blocking-only copy that referenced the old IA (e.g. the mode section is no longer under a "Blocking" header — the Tune header covers it).
- Grep-guard: `grep -n '\.blocking\|MobileBlockingScreen' Tortoise/ContentView.swift` → zero matches.
- iOS build → `BUILD SUCCEEDED`; macOS suite → green (shared files untouched). Commit.

### Self-review focus for 3b-3b-ios (at authoring time)
- Confirm every `screenTime.sessionLockedActive` / `isSyncing` disable that guarded the mode selector and session buttons in `MobileBlockingScreen` is present verbatim in `MobileTuningScreen` after the move (precommitment must not regress). The existing per-feature tuning rows already gate on `!model.isSyncing && !screenTime.sessionLockedActive` (`:785`).
- Confirm no duplicate `MobileIOSYouTubeStatusCard` at Tune top level (it already renders for the YouTube site).
- Confirm the `.onChange(of: scenePhase)` → `expireSessionIfNeeded()` and the policy-sync `onChange` guards in the shell (`:245-271`) are untouched (they live on the shell, not the moved screen).
- Confirm `initialSection` default `.usage` still valid and no code path sets `section = .blocking`.

## Residual decisions / risks

1. **`coverageCard` dropped, not moved (decision 4).** If product wants the "these accounts & devices enforce your blocks" chips visible from Tune (not only Devices), that is a follow-up add to Tune — this plan removes it with `ControlView` since Devices already shows coverage and Tune's `scopeCard` already exposes "Add". Low risk; flag if reviewers want the reassurance chips in Tune.
2. **Tune screen length (Mac).** Folding five areas onto one `QGPage` makes a long scroll (mode → site grid → selected-site detail → adult → apps+websites grid → session). It matches the `tune-v1` "one surface, detail-on-demand" intent but is denser than the phone mockup; if it reads long in practice, a later pass can collapse the site detail behind a drill-in. Not blocking.
3. **iOS `MobileIOSYouTubeStatusCard` placement.** The card appears under the YouTube site in Tune already; the Blocking copy at top level is intentionally NOT carried over to avoid duplication. Verify on-device the YouTube setup path is still reachable from Tune (the `setYoutubeProtection` "Finish setup" flow lives in `MobileTuningScreen` already).
4. **iOS verification is build-only.** No iOS unit-test target; the nav fold + precommitment gates are build-verified + manual QA (start a locked 2h session in Tune, confirm mode/session buttons disabled and can't be ended; confirm the tab bar shows Usage/Tune/Devices with no Blocking). The `AppSection` (Mac) nav change IS unit-tested.
5. **SceneStorage / stale `.blocking` (Mac).** A user whose stored `quietgate.selectedSection == "blocking"` decodes to `nil` → `?? .devices` fallback (verified at `ContentView.swift:44`). No migration needed; noted so it isn't mistaken for a bug.

## Execution Handoff

Two execution options:
1. **Subagent-Driven (recommended)** — one fresh subagent per task, review between tasks. Do 3b-3b-mac Tasks 1-3, then author + run 3b-3b-ios.
2. **Inline Execution** — batch with checkpoints via superpowers:executing-plans.
