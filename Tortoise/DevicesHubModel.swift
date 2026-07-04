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
