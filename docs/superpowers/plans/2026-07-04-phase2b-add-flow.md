# Phase 2b — Add Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make "Add devices / profiles" real: an **Add** sheet (Phone / Computer / Browser → QR + link → "sign in, it appears") on both Mac and iPhone, wired to every current Add/Expand entry point — replacing the dead iOS button and the misrouted Mac buttons that fire a browser-connector action. Account-based, no pairing codes; the connected thing shows up in the 2a hub after sign-in.

**Architecture:** Two pure, tested shared files in `Tortoise/` — `AddDestination.swift` (what can be added → its install/connect URL + copy) and `QRCode.swift` (URL → `CGImage` via CoreImage, works on macOS + iOS). Then a per-platform Add sheet view (Mac `AddSheetView`, iOS `MobileAddSheet`) that renders the shared model, and re-point the existing entry-point buttons to present it. No new transport — the browser path opens the account/web page (2c owns transport convergence).

**Tech Stack:** Swift 5, SwiftUI, CoreImage (`CIFilter.qrCodeGenerator`), XCTest, XcodeGen.

## Global Constraints

- Tests are a macOS XCTest bundle `QuietGateTests` (`@testable import QuietGate`). No iOS unit-test target — testable model/QR logic lives in shared `Tortoise/` files (compiled into the macOS `QuietGate` target); SwiftUI views are build-verified only.
- Shared files in `Tortoise/` compile into BOTH targets: the iOS `Tortoise` target auto-includes the folder; the `QuietGate` macOS target must list each new shared file under `sources:` as `type: file`.
- After adding a source file: `xcodegen generate --spec project.yml --project .` (the generated `QuietGate.xcodeproj` is tracked in git — stage it).
- macOS tests: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
- iOS build: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
- Product name **Tortoise**; minimal on-screen text; refined monochrome (match the approved `hub-v3`/`devices-hub-v2` mockups); **no pairing codes**; **no fake data**.
- Web origin: use `AppConfig.apiBaseURL` (`Tortoise/AppConfig.swift`; defaults to `https://www.yourtortoise.com`). Do NOT hardcode a new origin literal.

## Available from earlier phases (committed)

- 2a hub renders the connected list from `DevicesHub` — the Add flow only needs to get the user to the right web page + signed in; the new device then appears via the hub's normal refresh. No hub changes here.
- Sheet convention already in the app: `.sheet(isPresented:)` (Mac `QuietGate/Views/ContentView.swift:87`, iOS `Tortoise/ContentView.swift:57`, both presenting `AuthView`). Match it.
- Entry points to re-wire: Mac `ProtectionView.swift:140` `connectButton` (fires `store.performReadinessAction(primaryConnectAction)`); Mac `ControlView.swift:129-136` "Expand to another device" (fires `connectAction`); Mac `TuningView.swift:133-151` "Add browser account" + "Add iPhone (iOS)" (both fire `connectAction`); iOS `Tortoise/ContentView.swift:901` "Connect another device" (currently a `TODO(2b)` no-op).

---

### Task 1: `AddDestination` shared model

**Files:**
- Create: `Tortoise/AddDestination.swift`
- Modify: `project.yml` (add to `QuietGate` target `sources:` as `type: file`)
- Test: `QuietGateTests/AddDestinationTests.swift`

**Interfaces:**
- Produces: `enum AddDestination: String, CaseIterable, Identifiable { case phone, computer, browser }` with `id`, `title`, `systemImage`, `caption`, and `func url(base: URL = AppConfig.apiBaseURL) -> URL`.

- [ ] **Step 1: Create the file**

```swift
import Foundation

/// What the user can add to their Tortoise account. Each maps to the web page
/// that gets Tortoise onto that thing; after sign-in it appears in the hub.
/// Account-based — there are no pairing codes.
enum AddDestination: String, CaseIterable, Identifiable {
  case phone
  case computer
  case browser

  var id: String { rawValue }

  var title: String {
    switch self {
    case .phone: return "Phone"
    case .computer: return "Computer"
    case .browser: return "Browser"
    }
  }

  var systemImage: String {
    switch self {
    case .phone: return "iphone"
    case .computer: return "desktopcomputer"
    case .browser: return "globe"
    }
  }

  /// One short line shown under the QR — no jargon.
  var caption: String {
    switch self {
    case .phone, .computer: return "Install Tortoise, sign in — it appears here."
    case .browser: return "Add the extension, sign in — it appears here."
    }
  }

  private var path: String {
    switch self {
    case .phone: return "download/ios"
    case .computer: return "download/mac"
    case .browser: return "download/chrome"
    }
  }

  func url(base: URL = AppConfig.apiBaseURL) -> URL {
    base.appendingPathComponent(path)
  }
}
```

- [ ] **Step 2: Add to `project.yml`** — under `targets: QuietGate: sources:` add:

```yaml
      - path: Tortoise/AddDestination.swift
        type: file
```

- [ ] **Step 3: Regenerate** — `xcodegen generate --spec project.yml --project .` (expect `Created project at ...`).

- [ ] **Step 4: Write the tests** — `QuietGateTests/AddDestinationTests.swift`:

```swift
import XCTest
@testable import QuietGate

final class AddDestinationTests: XCTestCase {
  private let base = URL(string: "https://www.yourtortoise.com")!

  func testThreeDestinations() {
    XCTAssertEqual(AddDestination.allCases, [.phone, .computer, .browser])
  }

  func testURLsPointAtRealPages() {
    XCTAssertEqual(AddDestination.phone.url(base: base).absoluteString, "https://www.yourtortoise.com/download/ios")
    XCTAssertEqual(AddDestination.computer.url(base: base).absoluteString, "https://www.yourtortoise.com/download/mac")
    XCTAssertEqual(AddDestination.browser.url(base: base).absoluteString, "https://www.yourtortoise.com/download/chrome")
  }

  func testEveryDestinationHasNonEmptyCopy() {
    for d in AddDestination.allCases {
      XCTAssertFalse(d.title.isEmpty)
      XCTAssertFalse(d.caption.isEmpty)
      XCTAssertFalse(d.systemImage.isEmpty)
    }
  }
}
```

- [ ] **Step 5: Run macOS tests** — expect `AddDestinationTests` 3/3 PASS.
- [ ] **Step 6: iOS build** — expect `BUILD SUCCEEDED`.
- [ ] **Step 7: Commit**

```bash
git add Tortoise/AddDestination.swift project.yml QuietGate.xcodeproj QuietGateTests/AddDestinationTests.swift
git commit -m "Add shared AddDestination model"
```

---

### Task 2: `QRCode` shared helper

**Files:**
- Create: `Tortoise/QRCode.swift`
- Modify: `project.yml` (add to `QuietGate` target `sources:` as `type: file`)
- Test: `QuietGateTests/QRCodeTests.swift`

**Interfaces:**
- Produces: `enum QRCode { static func cgImage(for string: String, scale: CGFloat = 12) -> CGImage? }`

- [ ] **Step 1: Create the file**

```swift
import CoreImage
import CoreImage.CIFilterBuiltins

/// Renders a string (a URL) to a QR `CGImage`. CoreImage is available on both
/// macOS and iOS, so this is shared. Views wrap the result in
/// `Image(decorative: cgImage, scale: 1)` on each platform.
enum QRCode {
  private static let context = CIContext(options: nil)

  static func cgImage(for string: String, scale: CGFloat = 12) -> CGImage? {
    guard !string.isEmpty, let data = string.data(using: .utf8) else { return nil }
    let filter = CIFilter.qrCodeGenerator()
    filter.message = data
    filter.correctionLevel = "M"
    guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) else {
      return nil
    }
    return context.createCGImage(output, from: output.extent)
  }
}
```

- [ ] **Step 2: Add to `project.yml`** — under `targets: QuietGate: sources:` add:

```yaml
      - path: Tortoise/QRCode.swift
        type: file
```

- [ ] **Step 3: Regenerate** — `xcodegen generate --spec project.yml --project .`.

- [ ] **Step 4: Write the tests** — `QuietGateTests/QRCodeTests.swift`:

```swift
import XCTest
@testable import QuietGate

final class QRCodeTests: XCTestCase {
  func testGeneratesImageForValidURL() {
    XCTAssertNotNil(QRCode.cgImage(for: "https://www.yourtortoise.com/download/ios"))
  }

  func testImageHasPositiveDimensions() {
    let image = QRCode.cgImage(for: "https://www.yourtortoise.com/download/mac")
    XCTAssertNotNil(image)
    XCTAssertGreaterThan(image?.width ?? 0, 0)
    XCTAssertGreaterThan(image?.height ?? 0, 0)
  }

  func testNilForEmptyString() {
    XCTAssertNil(QRCode.cgImage(for: ""))
  }
}
```

- [ ] **Step 5: Run macOS tests** — expect `QRCodeTests` 3/3 PASS. If `createCGImage` returns nil in the headless test host, switch to `CIContext(options: [.useSoftwareRenderer: true])` and note it in your report.
- [ ] **Step 6: iOS build** — expect `BUILD SUCCEEDED`.
- [ ] **Step 7: Commit**

```bash
git add Tortoise/QRCode.swift project.yml QuietGate.xcodeproj QuietGateTests/QRCodeTests.swift
git commit -m "Add shared QRCode helper (CoreImage)"
```

---

### Task 3: Mac Add sheet + wire the Mac entry points

**Files:**
- Create: `QuietGate/Views/AddSheetView.swift`
- Modify: `QuietGate/Views/ProtectionView.swift` (present the sheet from `connectButton`)
- Modify: `QuietGate/Views/ControlView.swift` ("Expand to another device" → present the sheet)
- Modify: `QuietGate/Views/TuningView.swift` (the two scope-card Add buttons → one "Add" that presents the sheet)
- Test: none new (view layer; model/QR covered by Tasks 1-2). Suite must stay green.

**Interfaces:**
- Consumes: `AddDestination`, `QRCode` (Tasks 1-2).
- Produces: `struct AddSheetView: View` (self-contained; no required init args).

- [ ] **Step 1: Read the three view files first.** The design tokens (`QGDesign.*`) and card helpers (`QGCard`, `QGPrimaryButtonStyle`, `QGPage`) are established — match them. Confirm the exact current button code at `ProtectionView.swift:140-154`, `ControlView.swift:128-137`, `TuningView.swift:133-151`.

- [ ] **Step 2: Create `AddSheetView`** — a two-step sheet (tiles → destination detail). Use the app's existing `QGDesign` tokens; if a token below doesn't exist in `QGDesign`, substitute the nearest one the file already uses (build will tell you):

```swift
import SwiftUI

/// The "Add" sheet: pick Phone / Computer / Browser, then scan the QR (or open
/// the link) on that thing and sign in — it shows up in the hub. No codes.
struct AddSheetView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var selected: AddDestination?

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        if selected != nil {
          Button { selected = nil } label: { Image(systemName: "chevron.left") }
            .buttonStyle(.plain).foregroundStyle(QGDesign.secondaryText)
        }
        Text(selected.map { "Add \($0.title.lowercased())" } ?? "Add")
          .font(.system(size: 20, weight: .bold))
          .foregroundStyle(QGDesign.primaryText)
        Spacer()
        Button { dismiss() } label: { Image(systemName: "xmark") }
          .buttonStyle(.plain).foregroundStyle(QGDesign.secondaryText)
      }

      if let selected {
        detail(selected)
      } else {
        VStack(spacing: 10) {
          ForEach(AddDestination.allCases) { destination in
            Button { self.selected = destination } label: { tile(destination) }
              .buttonStyle(.plain)
          }
        }
      }
    }
    .padding(22)
    .frame(width: 360)
    .background(QGDesign.panel)
  }

  private func tile(_ d: AddDestination) -> some View {
    HStack(spacing: 14) {
      Image(systemName: d.systemImage)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(QGDesign.secondaryText)
        .frame(width: 34, height: 34)
        .background(QGDesign.elevatedPanel, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
      Text(d.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(QGDesign.primaryText)
      Spacer()
      Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(QGDesign.secondaryText)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(QGDesign.elevatedPanel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(QGDesign.hairline) }
  }

  @ViewBuilder private func detail(_ d: AddDestination) -> some View {
    VStack(spacing: 16) {
      if let cg = QRCode.cgImage(for: d.url().absoluteString) {
        Image(decorative: cg, scale: 1)
          .interpolation(.none)
          .resizable()
          .frame(width: 168, height: 168)
          .padding(10)
          .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      Link(destination: d.url()) {
        Text(d.url().absoluteString).font(.system(size: 12, weight: .semibold)).foregroundStyle(QGDesign.accent)
      }
      Text(d.caption)
        .font(.system(size: 13)).foregroundStyle(QGDesign.secondaryText)
        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity)
  }
}
```

- [ ] **Step 3: Present it from `ProtectionView.connectButton`.** Add `@State private var addSheetPresented = false` to `ProtectionView`; change the button action (currently `store.performReadinessAction(primaryConnectAction)`) to `addSheetPresented = true`; attach `.sheet(isPresented: $addSheetPresented) { AddSheetView() }` to the page body. Keep `primaryConnectAction` and the local browser-connector card unchanged (the card's own connect buttons still use it).

- [ ] **Step 4: Present it from `ControlView` "Expand to another device".** Add `@State private var addSheetPresented = false`; change the button action from `store.performReadinessAction(connectAction)` to `addSheetPresented = true`; attach `.sheet(isPresented: $addSheetPresented) { AddSheetView() }`. Then `grep -n "connectAction" QuietGate/Views/ControlView.swift` — if the `connectAction` computed property is now unreferenced, delete it; if anything else uses it, leave it.

- [ ] **Step 5: Present it from `TuningView`.** Replace the two scope-card buttons ("Add browser account" + "Add iPhone (iOS)", `:133-151`) with a SINGLE button labeled `Add` (systemImage `plus`) whose action sets `addSheetPresented = true`; add the `@State` + `.sheet(isPresented:) { AddSheetView() }`. Then `grep -n "connectAction" QuietGate/Views/TuningView.swift` — delete the now-unreferenced `connectAction` property if nothing else uses it.

- [ ] **Step 6: Build + full suite** — `xcodebuild ... -scheme QuietGate ... test` → `BUILD SUCCEEDED`, whole suite green (no test referenced the removed buttons/props — confirm with grep in your report).

- [ ] **Step 7: iOS build** — `BUILD SUCCEEDED`.

- [ ] **Step 8: Commit**

```bash
git add QuietGate/Views/AddSheetView.swift QuietGate/Views/ProtectionView.swift QuietGate/Views/ControlView.swift QuietGate/Views/TuningView.swift project.yml QuietGate.xcodeproj
git commit -m "Add Mac Add sheet; route Mac Add/Expand buttons to it"
```

(Note: `AddSheetView.swift` is a macOS-target view file — add it to `project.yml` under `QuietGate` sources like other `QuietGate/Views/*` if the target lists views individually; if the `QuietGate` target globs the `QuietGate/Views` folder, no `project.yml` change is needed. Check how sibling view files are listed and match.)

---

### Task 4: iOS Add sheet + wire the iOS entry point

**Files:**
- Modify: `Tortoise/ContentView.swift` — add `MobileAddSheet` view; present it from the "Connect another device" button (`~886-901`).
- Test: none new (iOS build-verified).

**Interfaces:**
- Consumes: `AddDestination`, `QRCode` (Tasks 1-2).

- [ ] **Step 1: Read `MobileDevicesScreen` and the current button** (`Tortoise/ContentView.swift` around `886-901`) and the `TortoiseDesign` tokens used nearby. Match them.

- [ ] **Step 2: Add `MobileAddSheet`** to `Tortoise/ContentView.swift` (mirrors `AddSheetView` with `TortoiseDesign` tokens and touch sizing):

```swift
private struct MobileAddSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var selected: AddDestination?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 14) {
          if let selected {
            detail(selected)
          } else {
            ForEach(AddDestination.allCases) { d in
              Button { selected = d } label: { tile(d) }.buttonStyle(.plain)
            }
          }
        }
        .padding(20)
      }
      .background(TortoiseDesign.background)
      .navigationTitle(selected.map { "Add \($0.title.lowercased())" } ?? "Add")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          if selected != nil {
            Button("Back") { selected = nil }
          } else {
            Button("Close") { dismiss() }
          }
        }
      }
    }
    .preferredColorScheme(.dark)
  }

  private func tile(_ d: AddDestination) -> some View {
    HStack(spacing: 14) {
      Image(systemName: d.systemImage)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(TortoiseDesign.secondaryText)
        .frame(width: 40, height: 40)
        .background(TortoiseDesign.elevatedPanel, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
      Text(d.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(TortoiseDesign.primaryText)
      Spacer()
      Image(systemName: "chevron.right").foregroundStyle(TortoiseDesign.tertiaryText)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(TortoiseDesign.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(TortoiseDesign.strongHairline) }
  }

  @ViewBuilder private func detail(_ d: AddDestination) -> some View {
    VStack(spacing: 18) {
      if let cg = QRCode.cgImage(for: d.url().absoluteString) {
        Image(decorative: cg, scale: 1)
          .interpolation(.none).resizable()
          .frame(width: 200, height: 200)
          .padding(12)
          .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
      Link(destination: d.url()) {
        Text(d.url().absoluteString).font(.system(size: 13, weight: .semibold)).foregroundStyle(TortoiseDesign.accent)
      }
      Text(d.caption)
        .font(.system(size: 14)).foregroundStyle(TortoiseDesign.secondaryText)
        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
    }
    .padding(.top, 12)
  }
}
```

- [ ] **Step 3: Present it from the button.** In `MobileDevicesScreen`, add `@State private var addSheetPresented = false`. Change the "Connect another device" button's action (currently a `TODO(2b)` no-op) to `addSheetPresented = true`, and attach `.sheet(isPresented: $addSheetPresented) { MobileAddSheet() }` to the screen's root. Remove the `// TODO(2b)` comment.

- [ ] **Step 4: iOS build** — `BUILD SUCCEEDED`.

- [ ] **Step 5: macOS suite** — still green (shared files unchanged; only iOS view code added).

- [ ] **Step 6: Commit**

```bash
git add Tortoise/ContentView.swift
git commit -m "Add iOS Add sheet; wire Connect-another-device button to it"
```

---

## Self-Review

**Spec coverage (spec §5.2 — Add flow):**
- Picker Phone/Computer/Browser → get-it-there → sign-in-appears, no codes → Tasks 1 (model) + 3/4 (sheets). ✓
- QR + tappable link per destination → Task 2 (QR) + 3/4 (rendered). ✓
- Replace the dead iOS "Connect another device" button → Task 4. ✓
- Replace the misrouted Mac "Add iPhone"/"Expand to another device"/"Add browser account" (fire a browser-connector action) → Task 3 (all now present the Add sheet; the browser-connector CARD stays). ✓
- Account-based; browser opens the web page (transport convergence is 2c). ✓

**Placeholder scan:** No TBD/TODO left as work-in-a-step. The design-token substitution note (Task 3 Step 2) is a build-verify instruction, not missing implementation.

**Type consistency:** `AddDestination.{title,systemImage,caption,url(base:)}`, `QRCode.cgImage(for:scale:)`, `AddSheetView`, `MobileAddSheet` used consistently. Both sheets render `QRCode.cgImage(...)` via `Image(decorative:scale:)` (available on macOS + iOS).

**Out of scope (deferred):** browser-connect transport convergence + folding local `browserConnectors` (2c); real per-device enforcement signal (Phase 3); Tune screen (Phase 3).

## Whole-branch review outcome (Phase 2b)

Verdict: **merge-ready with small fixes** (applied). No Critical. Core Add flow coherent + honest — one shared model (`AddDestination`/`QRCode`) behind two platform sheets, all four entry points rerouted (zero `performReadinessAction` callers remain), no fake state, no pairing codes.

Applied in the fix pass (commit `b84707b`): Mac Add-sheet icon-chip contrast (`Color.white.opacity(0.06)`); `TODO(2c)` markers on the now-dead `ProtectionView.primaryConnectAction` + `ProtectionStore.performReadinessAction(_:)`.

Carry forward:

**Important (tracked, not code for this slice):**
1. **Browser tile → `/download/chrome` is Chromium-only.** Firefox users (Tortoise ships a first-class `FirefoxExtension`) land on a Chrome page; spec §5.2 envisioned a browser-neutral `tortoise.com/add`. **Follow-up (web):** a neutral `/download/browser` (or `/add`) with server-side user-agent detection, or a per-UA redirect on `/download/chrome`. Don't let the Browser tile point at a Chrome-only page permanently.
2. **Release gate:** the whole payoff depends on `/download/{ios,mac,chrome}` (under `AppConfig.apiBaseURL`) existing and funneling to install + same-account sign-in. Verify all three resolve before this is user-facing. Not a code change.

**Cleanup for 2c:** remove the now-dead `primaryConnectAction` (`ProtectionView`) + `performReadinessAction(_:)` (`ProtectionStore`) together with the local native-messaging browser-connect path.

**Minor (defer):** harmonize the entry-point button verbs toward "Add" ("Connect another browser or device" / "Expand to another device" / "Add" / "Connect another device" all open the same **Add** sheet).
