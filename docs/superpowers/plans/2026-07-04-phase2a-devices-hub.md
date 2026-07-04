# Phase 2a — Devices Hub (read/render) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render the Devices hub on Mac and iPhone from ONE shared, tested view model — each connected thing resolved to a single `ConnectionStatus` via the Phase-1 resolver, browser profiles nested under their browser — replacing today's three divergent device-classification copies and three different "connected" freshness windows.

**Architecture:** Add two pure, tested shared files to `Tortoise/` (compiled into both apps): `DevicePresentation.swift` (one `TortoiseDevice` classification/display extension) and `DevicesHubModel.swift` (maps `[TortoiseDevice]` → ordered `[DeviceHubRow]` with `ConnectionStatus` + nested browser profiles). Then rewire the existing `ProtectionView` (Mac) and `MobileDevicesScreen` (iOS) to render from it, keeping the approved refined visual language. The Add button stays a placeholder (real Add flow is sub-plan 2b).

**Tech Stack:** Swift 5, SwiftUI, XCTest, XcodeGen.

## Phase 2 decomposition

Phase 2 (Devices) ships as three sub-plans, each independently testable:

- **2a — Devices hub (read/render)** *(this plan)*: one shared device-classification + hub view model resolving `ConnectionStatus`; rewire both platforms' Devices screens to render it. Add button is a placeholder.
- **2b — Add flow**: `Add` → picker (Phone / Computer / Browser) → QR/link → "sign in & it appears." Replaces the dead iOS "Connect another device" button (`Tortoise/ContentView.swift:888`) and the misrouted Mac "Add iPhone (iOS)" / "Expand to another device" / "Connect another browser or device" buttons (`TuningView.swift`, `ControlView.swift`, `ProtectionView.swift:227-241`), all of which currently fire a browser-connector action.
- **2c — Converge browser connect**: retire the local native-messaging "tuner session" as the connect path in favor of the account/web token exchange (`/api/extension/exchange`); fold the Mac's local `store.browserConnectors` browser list into the account-device hub model so browser profiles come from one source. (Reconciles the transitional note in Task 3 below.)

## Global Constraints

- Tests are a macOS XCTest bundle `QuietGateTests` hosted by `QuietGate.app` (`@testable import QuietGate`). There is **no iOS unit-test target** — all tested logic lives in the shared `Tortoise/` files (which compile into the macOS `QuietGate` target); SwiftUI views are verified by build only.
- Shared files in `Tortoise/` compile into BOTH targets: the `Tortoise` iOS target includes the whole folder automatically; the `QuietGate` macOS target must list each new shared file under `sources:` as `type: file`.
- After adding a source file, regenerate: `xcodegen generate --spec project.yml --project .` (the generated `QuietGate.xcodeproj` is tracked in git — stage it).
- Run macOS tests: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
- Verify iOS compiles: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
- Product name is **Tortoise**; minimal on-screen text (one status dot + at most one word per row); real brand/device marks (`brandAssetName` convention, e.g. `BrandYouTube`).
- **Honesty:** a row is `.on` only when genuinely fresh + enforcing per `ConnectionStatus`. No fake/demo rows.

## Available from Phase 1 (already committed)

- `Tortoise/ConnectionStatus.swift`: `enum ConnectionStatus { case on; case attention(AttentionReason); case off }`, `enum AttentionReason { case setupIncomplete, stale, catchingUp }`, `enum ConnectionFreshness { static let freshWindow: TimeInterval = 15*60 }`, and
  `static func ConnectionStatus.resolve(lastSeenAt: Date?, isEnforcingLatestPolicy: Bool, isPausedByUser: Bool, now: Date) -> ConnectionStatus`.
- `TortoiseDevice` (`Tortoise/TortoiseModels.swift:255`): `id: String`, `platform: String?`, `name: String?`, `appVersion: String?`, `helperVersion: String?`, `lastSeenAt: String?` (ISO8601 string).

## Input assumptions (documented, revisited later)

`ConnectionStatus.resolve` needs `isEnforcingLatestPolicy` and `isPausedByUser`. `TortoiseDevice` carries neither a policy-version nor a pause flag today. For 2a:
- `isPausedByUser` = `false` (no per-device pause exists yet; introduced with a later phase).
- `isEnforcingLatestPolicy` = `true` (so a freshly-checked-in device resolves to `.on`; a stale one still resolves to `.stale`). A `TODO(2c/Phase 3)` marks wiring the real signal (device-reported policy version vs current `settingsVersion`). This is already strictly more honest than today (never-seen → `setupIncomplete`, >15min → `stale`).

---

### Task 1: Shared device classification (`DevicePresentation.swift`)

**Files:**
- Create: `Tortoise/DevicePresentation.swift`
- Modify: `project.yml` (add the file to the `QuietGate` target's `sources:`)
- Test: `QuietGateTests/DevicePresentationTests.swift`

**Interfaces:**
- Produces: `enum DeviceKind: Equatable { case mac, iphone, browser(brand: String), other }`
- Produces on `TortoiseDevice`: `var deviceKind: DeviceKind`, `var isBrowserProfile: Bool`, `var displayName: String`, `var initials: String`, `var brandAssetName: String?`, `var lastSeenDate: Date?`

- [ ] **Step 1: Create the file**

Create `Tortoise/DevicePresentation.swift`:

```swift
import Foundation

/// The single classification of a connected thing. Replaces the per-screen
/// copies previously inlined in ProtectionView (macOS) and ContentView (iOS).
enum DeviceKind: Equatable {
  case mac
  case iphone
  case browser(brand: String)  // brand is a lowercase key: "chrome","firefox","safari","edge","brave","arc"
  case other
}

extension TortoiseDevice {
  private var normalizedPlatform: String { (platform ?? "").lowercased() }

  var deviceKind: DeviceKind {
    let p = normalizedPlatform
    switch p {
    case "ios": return .iphone
    case "macos", "mac": return .mac
    default:
      for brand in ["chrome", "firefox", "safari", "edge", "brave", "arc"] where p.contains(brand) {
        return .browser(brand: brand)
      }
      return .other
    }
  }

  var isBrowserProfile: Bool {
    if case .browser = deviceKind { return true }
    return false
  }

  /// The user-facing name: the device's own name, else a label for its kind.
  var displayName: String {
    let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty { return trimmed }
    switch deviceKind {
    case .mac: return "Mac"
    case .iphone: return "iPhone"
    case .browser(let brand): return brand.capitalized
    case .other: return "Device"
    }
  }

  var initials: String {
    let letters = displayName.split(separator: " ").prefix(2).compactMap(\.first)
    if letters.isEmpty { return "T" }
    return String(letters).uppercased()
  }

  /// Real brand asset name for browser kinds (nil for mac/iphone/other, which use SF Symbols).
  var brandAssetName: String? {
    if case .browser(let brand) = deviceKind { return "Brand\(brand.capitalized)" }
    return nil
  }

  /// Parses the ISO8601 `lastSeenAt` string (with or without fractional seconds).
  var lastSeenDate: Date? {
    guard let lastSeenAt else { return nil }
    return DevicePresentationFormatters.withFractional.date(from: lastSeenAt)
      ?? DevicePresentationFormatters.plain.date(from: lastSeenAt)
  }
}

enum DevicePresentationFormatters {
  static let withFractional: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()
  static let plain: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()
}
```

- [ ] **Step 2: Add the file to the macOS target in `project.yml`**

Under `targets: QuietGate: sources:`, add next to the other shared `type: file` entries:

```yaml
      - path: Tortoise/DevicePresentation.swift
        type: file
```

- [ ] **Step 3: Regenerate the project**

Run: `xcodegen generate --spec project.yml --project .`
Expected: `Created project at .../QuietGate.xcodeproj`

- [ ] **Step 4: Write the tests**

Create `QuietGateTests/DevicePresentationTests.swift`:

```swift
import XCTest
@testable import QuietGate

final class DevicePresentationTests: XCTestCase {
  private func device(platform: String?, name: String? = nil, lastSeenAt: String? = nil) -> TortoiseDevice {
    // TortoiseDevice is Decodable-only; build one from JSON to respect its coding keys.
    // Insert keys ONLY when non-nil — a nil boxed as `Any` is Optional.none, which is
    // not valid JSON and makes JSONSerialization throw. (A missing key decodes to nil.)
    var payload: [String: Any] = ["id": "d1"]
    if let platform { payload["platform"] = platform }
    if let name { payload["name"] = name }
    if let lastSeenAt { payload["last_seen_at"] = lastSeenAt }
    let data = try! JSONSerialization.data(withJSONObject: payload)
    return try! JSONDecoder().decode(TortoiseDevice.self, from: data)
  }

  func testKindClassification() {
    XCTAssertEqual(device(platform: "ios").deviceKind, .iphone)
    XCTAssertEqual(device(platform: "macos").deviceKind, .mac)
    XCTAssertEqual(device(platform: "mac").deviceKind, .mac)
    XCTAssertEqual(device(platform: "chrome_extension").deviceKind, .browser(brand: "chrome"))
    XCTAssertEqual(device(platform: "firefox_extension").deviceKind, .browser(brand: "firefox"))
    XCTAssertEqual(device(platform: "safari").deviceKind, .browser(brand: "safari"))
    XCTAssertEqual(device(platform: "watch").deviceKind, .other)
    XCTAssertEqual(device(platform: nil).deviceKind, .other)
  }

  func testIsBrowserProfile() {
    XCTAssertTrue(device(platform: "chrome_extension").isBrowserProfile)
    XCTAssertFalse(device(platform: "ios").isBrowserProfile)
  }

  func testDisplayNameFallsBackToKind() {
    XCTAssertEqual(device(platform: "ios", name: "Will's iPhone").displayName, "Will's iPhone")
    XCTAssertEqual(device(platform: "ios", name: "  ").displayName, "iPhone")
    XCTAssertEqual(device(platform: "chrome", name: nil).displayName, "Chrome")
  }

  func testInitials() {
    XCTAssertEqual(device(platform: "ios", name: "Will Pulier").initials, "WP")
    XCTAssertEqual(device(platform: "mac", name: nil).initials, "M")
  }

  func testBrandAssetNameOnlyForBrowsers() {
    XCTAssertEqual(device(platform: "chrome").brandAssetName, "BrandChrome")
    XCTAssertNil(device(platform: "ios").brandAssetName)
  }

  func testLastSeenDateParsesBothISOFormats() {
    XCTAssertNotNil(device(platform: "ios", lastSeenAt: "2026-07-04T00:00:00.123Z").lastSeenDate)
    XCTAssertNotNil(device(platform: "ios", lastSeenAt: "2026-07-04T00:00:00Z").lastSeenDate)
    XCTAssertNil(device(platform: "ios", lastSeenAt: nil).lastSeenDate)
    XCTAssertNil(device(platform: "ios", lastSeenAt: "not-a-date").lastSeenDate)
  }
}
```

- [ ] **Step 5: Run the tests**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
Expected: `DevicePresentationTests` — 6 tests PASS. If the JSON helper fails to decode, check `TortoiseDevice`'s `CodingKeys` (`Tortoise/TortoiseModels.swift:263-270`) — it maps `last_seen_at`→`lastSeenAt` etc.; align the test payload keys.

- [ ] **Step 6: Verify iOS compiles**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 7: Commit**

```bash
git add Tortoise/DevicePresentation.swift project.yml QuietGate.xcodeproj QuietGateTests/DevicePresentationTests.swift
git commit -m "Add shared TortoiseDevice classification (DevicePresentation)"
```

---

### Task 2: Devices hub view model (`DevicesHubModel.swift`)

**Files:**
- Create: `Tortoise/DevicesHubModel.swift`
- Modify: `project.yml` (add the file to the `QuietGate` target's `sources:`)
- Test: `QuietGateTests/DevicesHubModelTests.swift`

**Interfaces:**
- Consumes: `DeviceKind`, `TortoiseDevice.{deviceKind,isBrowserProfile,displayName,initials,brandAssetName,lastSeenDate}` (Task 1), `ConnectionStatus.resolve` (Phase 1).
- Produces: `struct DeviceHubRow: Identifiable, Equatable { let id: String; let kind: DeviceKind; let title: String; let isCurrentDevice: Bool; let status: ConnectionStatus; let profiles: [DeviceHubRow] }`
- Produces: `enum DevicesHub { static func rows(devices: [TortoiseDevice], currentDeviceID: String?, now: Date) -> [DeviceHubRow]; static func connectedCount(_ rows: [DeviceHubRow]) -> Int }`

- [ ] **Step 1: Write the failing tests**

Create `QuietGateTests/DevicesHubModelTests.swift`:

```swift
import XCTest
@testable import QuietGate

final class DevicesHubModelTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 2_000_000_000)

  private func device(id: String, platform: String, name: String? = nil, minutesAgo: Double?) -> TortoiseDevice {
    var payload: [String: Any] = ["id": id, "platform": platform]
    if let name { payload["name"] = name }
    if let minutesAgo {
      payload["last_seen_at"] = DevicePresentationFormatters.withFractional
        .string(from: now.addingTimeInterval(-minutesAgo * 60))
    }
    let data = try! JSONSerialization.data(withJSONObject: payload)
    return try! JSONDecoder().decode(TortoiseDevice.self, from: data)
  }

  func testFreshDeviceIsOn() {
    let rows = DevicesHub.rows(devices: [device(id: "m", platform: "macos", minutesAgo: 1)], currentDeviceID: nil, now: now)
    XCTAssertEqual(rows.count, 1)
    XCTAssertEqual(rows[0].status, .on)
    XCTAssertEqual(rows[0].kind, .mac)
  }

  func testStaleDeviceIsAttentionStale() {
    let rows = DevicesHub.rows(devices: [device(id: "m", platform: "macos", minutesAgo: 30)], currentDeviceID: nil, now: now)
    XCTAssertEqual(rows[0].status, .attention(.stale))
  }

  func testNeverSeenDeviceIsSetupIncomplete() {
    let rows = DevicesHub.rows(devices: [device(id: "p", platform: "ios", minutesAgo: nil)], currentDeviceID: nil, now: now)
    XCTAssertEqual(rows[0].status, .attention(.setupIncomplete))
  }

  func testBrowserProfilesNestUnderOneBrowserRow() {
    let rows = DevicesHub.rows(devices: [
      device(id: "c1", platform: "chrome_extension", name: "willpulier1999@gmail.com", minutesAgo: 1),
      device(id: "c2", platform: "chrome_extension", name: "work", minutesAgo: 1),
    ], currentDeviceID: nil, now: now)
    let browserRows = rows.filter { if case .browser = $0.kind { return true } else { return false } }
    XCTAssertEqual(browserRows.count, 1, "both Chrome profiles nest under one Chrome row")
    XCTAssertEqual(browserRows[0].profiles.count, 2)
  }

  func testCurrentDeviceSortsFirst() {
    let rows = DevicesHub.rows(devices: [
      device(id: "old", platform: "ios", minutesAgo: 2),
      device(id: "me", platform: "macos", minutesAgo: 5),
    ], currentDeviceID: "me", now: now)
    XCTAssertEqual(rows.first?.id, "me")
    XCTAssertTrue(rows.first?.isCurrentDevice == true)
  }

  func testConnectedCountCountsOnLeaves() {
    let rows = DevicesHub.rows(devices: [
      device(id: "m", platform: "macos", minutesAgo: 1),          // on
      device(id: "p", platform: "ios", minutesAgo: 30),           // stale
      device(id: "c1", platform: "chrome_extension", minutesAgo: 1), // on (nested)
    ], currentDeviceID: nil, now: now)
    XCTAssertEqual(DevicesHub.connectedCount(rows), 2)
  }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test -only-testing:QuietGateTests/DevicesHubModelTests`
Expected: FAIL to compile (`DevicesHub` / `DeviceHubRow` undefined).

- [ ] **Step 3: Create the model file**

Create `Tortoise/DevicesHubModel.swift`:

```swift
import Foundation

/// One row in the Devices hub. A device (mac/iphone/other) has no profiles;
/// a browser row nests its connected profiles.
struct DeviceHubRow: Identifiable, Equatable {
  let id: String
  let kind: DeviceKind
  let title: String
  let isCurrentDevice: Bool
  let status: ConnectionStatus
  let profiles: [DeviceHubRow]
}

/// Builds the Devices hub from the account device list. One definition, used by
/// both the macOS and iOS Devices screens.
enum DevicesHub {
  static func rows(devices: [TortoiseDevice], currentDeviceID: String?, now: Date) -> [DeviceHubRow] {
    // Dedup by id, newest first.
    let unique = Dictionary(devices.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new }).values
    let sorted = unique.sorted { ($0.lastSeenDate ?? .distantPast) > ($1.lastSeenDate ?? .distantPast) }

    let leafRows = sorted.map { leaf($0, currentDeviceID: currentDeviceID, now: now) }

    // Non-browser devices as top-level rows.
    let deviceRows = leafRows.filter { !$0.kind.isBrowser }

    // Browser profiles grouped under one row per brand.
    let browserLeaves = leafRows.filter { $0.kind.isBrowser }
    let browserRows = Dictionary(grouping: browserLeaves, by: { $0.kind.brandKey ?? "browser" })
      .sorted { $0.key < $1.key }
      .map { brand, profiles -> DeviceHubRow in
        DeviceHubRow(
          id: "browser-\(brand)",
          kind: .browser(brand: brand),
          title: brand.capitalized,
          isCurrentDevice: false,
          status: aggregate(profiles.map(\.status)),
          profiles: profiles
        )
      }

    // Current device first, then remaining devices (already newest-first), then browsers.
    let current = deviceRows.filter(\.isCurrentDevice)
    let otherDevices = deviceRows.filter { !$0.isCurrentDevice }
    return current + otherDevices + browserRows
  }

  static func connectedCount(_ rows: [DeviceHubRow]) -> Int {
    rows.reduce(0) { acc, row in
      if row.profiles.isEmpty {
        return acc + (row.status == .on ? 1 : 0)
      }
      return acc + row.profiles.filter { $0.status == .on }.count
    }
  }

  private static func leaf(_ device: TortoiseDevice, currentDeviceID: String?, now: Date) -> DeviceHubRow {
    let status = ConnectionStatus.resolve(
      lastSeenAt: device.lastSeenDate,
      isEnforcingLatestPolicy: true,  // TODO(2c/Phase 3): device-reported policyVersion vs current settingsVersion
      isPausedByUser: false,          // TODO: per-device pause not modeled yet
      now: now
    )
    return DeviceHubRow(
      id: device.id,
      kind: device.deviceKind,
      title: device.displayName,
      isCurrentDevice: device.id == currentDeviceID,
      status: status,
      profiles: []
    )
  }

  /// A browser row is On if any profile is On, else needs attention if any does, else off.
  private static func aggregate(_ statuses: [ConnectionStatus]) -> ConnectionStatus {
    if statuses.contains(.on) { return .on }
    if let attention = statuses.first(where: { if case .attention = $0 { return true } else { return false } }) {
      return attention
    }
    return .off
  }
}

private extension DeviceKind {
  var isBrowser: Bool { if case .browser = self { return true } else { return false } }
  var brandKey: String? { if case .browser(let brand) = self { return brand } else { return nil } }
}
```

- [ ] **Step 4: Add the file to the macOS target in `project.yml`**

```yaml
      - path: Tortoise/DevicesHubModel.swift
        type: file
```

- [ ] **Step 5: Regenerate + run the tests**

Run: `xcodegen generate --spec project.yml --project .`
Then: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
Expected: `DevicesHubModelTests` — 6 tests PASS; whole suite green.

- [ ] **Step 6: Verify iOS compiles**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 7: Commit**

```bash
git add Tortoise/DevicesHubModel.swift project.yml QuietGate.xcodeproj QuietGateTests/DevicesHubModelTests.swift
git commit -m "Add shared DevicesHub view model (ConnectionStatus + nested profiles)"
```

---

### Task 3: Render the Mac Devices screen from `DevicesHub`

**Files:**
- Modify: `QuietGate/Views/ProtectionView.swift` (device rows + count; keep the local browser-connector section for now)
- Test: none new (view layer; logic covered by Tasks 1-2). Existing suite must stay green.

**Interfaces:**
- Consumes: `DevicesHub.rows(...)`, `DevicesHub.connectedCount(...)`, `DeviceHubRow`, `ConnectionStatus` (Tasks 1-2).

- [ ] **Step 1: Build hub rows from the account snapshot**

In `ProtectionView`, add a computed property that feeds the model from the existing `accountStore.snapshot` (which already exposes `devices` and `device`):

```swift
  private var hubRows: [DeviceHubRow] {
    var devices = accountStore.snapshot.devices
    if let current = accountStore.snapshot.device, !devices.contains(where: { $0.id == current.id }) {
      devices.append(current)
    }
    return DevicesHub.rows(devices: devices, currentDeviceID: accountStore.snapshot.device?.id, now: Date())
  }
```

- [ ] **Step 2: Replace the device sections + count with hub-driven rows**

Replace the `macConnections` / `iphoneConnections` / `otherConnectionList` device rendering and the inline `deviceStatus`/`deviceTint`/`macDevices`/`iphoneDevices`/`otherConnections`/`normalizedPlatform`/`isMacDevice`/`isIPhoneDevice`/`platformLabel`/`deviceSystemImage`/`deviceTitle`/`deviceSubtitle` helpers with a single hub list rendered by a status-dot row. Add this row view and a status→(color,label) mapping to `ProtectionView.swift`:

```swift
private struct HubDeviceRow: View {
  let row: DeviceHubRow

  var body: some View {
    HStack(spacing: 13) {
      Image(systemName: HubStatusStyle.systemImage(for: row.kind))
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(QGDesign.secondaryText)
        .frame(width: 38, height: 38)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 7) {
          Text(row.title)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(QGDesign.primaryText)
          if row.isCurrentDevice {
            Text("THIS ONE").font(.system(size: 9, weight: .bold)).foregroundStyle(QGDesign.secondaryText)
          }
        }
        if !row.profiles.isEmpty {
          Text("\(row.profiles.count) profile\(row.profiles.count == 1 ? "" : "s")")
            .font(.system(size: 12)).foregroundStyle(QGDesign.secondaryText)
        }
      }
      Spacer()
      HStack(spacing: 7) {
        Text(HubStatusStyle.label(for: row.status))
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(HubStatusStyle.color(for: row.status))
        Circle().fill(HubStatusStyle.color(for: row.status)).frame(width: 8, height: 8)
      }
    }
  }
}

enum HubStatusStyle {
  static func label(for status: ConnectionStatus) -> String {
    switch status {
    case .on: return "On"
    case .attention: return "Tap"
    case .off: return "Off"
    }
  }
  static func color(for status: ConnectionStatus) -> Color {
    switch status {
    case .on: return QGDesign.green
    case .attention: return QGDesign.orange
    case .off: return QGDesign.secondaryText
    }
  }
  static func systemImage(for kind: DeviceKind) -> String {
    switch kind {
    case .mac: return "desktopcomputer"
    case .iphone: return "iphone"
    case .browser: return "globe"       // TODO: real brand mark via brandAssetName
    case .other: return "laptopcomputer"
    }
  }
}
```

Then render one card of `hubRows` (nesting `row.profiles` indented) in `body` in place of the separate Mac/iPhone/Other cards, and change `connectionCount` to `DevicesHub.connectedCount(hubRows)`. Leave the `macBrowserGroups` local-native browser section and the `connectButton` (placeholder) in place — a `// TODO(2c)` comment notes the local browser list folds into `hubRows` in sub-plan 2c.

- [ ] **Step 3: Build for macOS + run tests**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
Expected: `BUILD SUCCEEDED`; whole suite green (no test asserted the removed private helpers — verify by search before deleting: `grep -rn "deviceStatus\|isMacDevice" QuietGateTests` returns nothing).

- [ ] **Step 4: Commit**

```bash
git add QuietGate/Views/ProtectionView.swift
git commit -m "Render Mac Devices screen from shared DevicesHub"
```

---

### Task 4: Render the iOS Devices screen from `DevicesHub` (remove the duplicate)

**Files:**
- Modify: `Tortoise/ContentView.swift` — `MobileDevicesScreen` (~810-928), the `MobileDeviceRow`/`MobileBrowserProfileRow` usage, and DELETE the `private extension TortoiseDevice` (2420-2492) whose helpers are now in shared code.
- Test: none new (view layer; iOS build-verified).

**Interfaces:**
- Consumes: `DevicesHub.rows(...)`, `DevicesHub.connectedCount(...)`, `DeviceHubRow`, `TortoiseDevice.{displayName,initials,...}` (Tasks 1-2).

- [ ] **Step 1: Feed the model from `AccountHubModel`**

In `MobileDevicesScreen`, replace `otherDevices` / `browserRows` / `connectionCount` (which used the private extension) with:

```swift
  private var hubRows: [DeviceHubRow] {
    DevicesHub.rows(
      devices: model.snapshot.devices,
      currentDeviceID: model.snapshot.device?.id,
      now: Date()
    )
  }
```

Render `hubRows` (nesting `row.profiles`) using a mobile status-dot row that mirrors the mac `HubStatusStyle` (define a local `MobileHubStatusStyle` with the same On/Tap/Off + green/orange/secondary mapping, since `HubStatusStyle` is macOS-view-file-scoped). Set the header connection count to `DevicesHub.connectedCount(hubRows)`. Keep the existing "This iPhone" Screen-Time status row (`MobileIOSDeviceStatusRow`) — it carries iOS-specific enforcement detail that the generic row doesn't.

- [ ] **Step 2: Delete the duplicated classification extension**

Remove the `private extension TortoiseDevice { ... }` block (`Tortoise/ContentView.swift:2420-2492`) and update the `MobileDevice`/`MobileBrowserProfile` initializers that referenced `device.platformLabel`/`device.statusSubtitle`/`device.initials` to use the shared `TortoiseDevice` members from `DevicePresentation.swift` (same names: `displayName`, `initials`) or the hub rows directly. Keep the `ISO8601DateFormatter.tortoise`/`.tortoiseNoFractions` helpers only if still referenced elsewhere; if not, remove them too (the shared `DevicePresentationFormatters` supersedes them). Search first: `grep -n "tortoiseNoFractions\|\.platformLabel\|\.statusSubtitle" Tortoise/ContentView.swift`.

- [ ] **Step 3: Leave the Add button as a labeled placeholder**

The dead "Connect another device" button (`~888`) stays for now but must not misrepresent state. Change its action to a no-op with a `// TODO(2b): wire the Add flow` comment and keep the label — sub-plan 2b replaces it. Do not point it at a browser-connector action.

- [ ] **Step 4: Verify iOS compiles**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme Tortoise -configuration Debug -destination 'generic/platform=iOS Simulator' build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Verify macOS suite still green**

Run: `xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
Expected: whole suite PASS (the shared files are unchanged; only iOS view code moved).

- [ ] **Step 6: Commit**

```bash
git add Tortoise/ContentView.swift
git commit -m "Render iOS Devices screen from shared DevicesHub; drop duplicate classification"
```

---

## Self-Review

**Spec coverage (spec §5 Devices — hub read/render slice):**
- §5.1 one row per connected thing, one `ConnectionStatus` dot + one word, account + count header → Tasks 2-4. ✓
- §5.1 browser profiles nest under their browser (no top-level double-count) → Task 2 `rows` grouping + `connectedCount`. ✓
- §4.1 single freshness rule / single status model applied everywhere → Tasks 1-2 (replaces ProtectionView's 24h + MacAccountStore's 7-day + iOS copy with Phase-1 15-min `resolve`). ✓
- §4 unify duplicated device classification → Task 1 shared extension; Tasks 3-4 delete the Mac inline + iOS private copies. ✓
- Deferred (named in decomposition): the Add flow (2b), browser-connect convergence + folding local `browserConnectors` into the hub (2c). ✓

**Placeholder scan:** No TBD/TODO left as work-in-a-step. The `TODO(2c/Phase 3)` on `isEnforcingLatestPolicy` and `TODO(2b)` on the Add button are deliberate, documented deferrals to named sub-plans, not missing implementation in this plan's steps.

**Type consistency:** `DeviceKind`, `DeviceHubRow`, `DevicesHub.rows(devices:currentDeviceID:now:)`, `DevicesHub.connectedCount(_:)`, `TortoiseDevice.{deviceKind,isBrowserProfile,displayName,initials,brandAssetName,lastSeenDate}`, and `ConnectionStatus.resolve(lastSeenAt:isEnforcingLatestPolicy:isPausedByUser:now:)` are used with identical signatures across tasks. `HubStatusStyle` is macOS-view-scoped; iOS defines its own `MobileHubStatusStyle` twin (Task 4 Step 1) — noted so the duplication is intentional, not an accident (both map the same 3 cases; a later shared-UI phase could unify).

**Out of scope (correctly deferred):** Add flow, browser-connect transport convergence, per-device pause, real per-device enforcement signal, TikTok, Tune screen, legacy-enum removal.
