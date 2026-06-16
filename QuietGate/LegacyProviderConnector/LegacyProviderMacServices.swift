import Foundation

#if DEBUG
final class MacConfigurationProfileService: SystemProfileChecking {
  func legacyProviderProfileStatus(profileID: String) -> SystemLegacyProviderProfileStatus {
    if let status = systemProfilerLegacyProviderProfileStatus(profileID: profileID) {
      return status
    }

    let legacyInstalled = legacyProfilesOutputContainsProvider()
    return SystemLegacyProviderProfileStatus(
      anyLegacyProviderProfileInstalled: legacyInstalled,
      configuredLegacyProviderProfileInstalled: false
    )
  }

  private func systemProfilerLegacyProviderProfileStatus(profileID: String) -> SystemLegacyProviderProfileStatus? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
    process.arguments = ["SPConfigurationProfileDataType", "-json"]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
      try process.run()
      process.waitUntilExit()
    } catch {
      return nil
    }

    guard process.terminationStatus == 0 else {
      return nil
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return Self.legacyProviderProfileStatus(fromSystemProfilerJSON: data, profileID: profileID)
  }

  static func legacyProviderProfileStatus(
    fromSystemProfilerJSON data: Data,
    profileID: String
  ) -> SystemLegacyProviderProfileStatus? {
    guard let json = try? JSONSerialization.jsonObject(with: data) else {
      return nil
    }

    let strings = flattenedStrings(in: json)
    let anyInstalled = strings.contains { value in
      value.range(
        of: #"nextdns|apple\.dns\.nextdns|dns\.nextdns|io\.nextdns|com\.nextdns"#,
        options: [.regularExpression, .caseInsensitive]
      ) != nil
    }

    let profileID = profileID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let configuredInstalled =
      !profileID.isEmpty
      && strings.contains { value in
        let value = value.lowercased()
        return value.contains("apple.dns.nextdns.io/\(profileID)/")
          || value.contains("nextdns (\(profileID))")
          || value.contains("nextdns.\(profileID)")
          || value.contains("nextdns.\(profileID).")
          || value.contains("nextdns-\(profileID)")
      }

    return SystemLegacyProviderProfileStatus(
      anyLegacyProviderProfileInstalled: anyInstalled,
      configuredLegacyProviderProfileInstalled: configuredInstalled
    )
  }

  private static func flattenedStrings(in value: Any) -> [String] {
    if let string = value as? String {
      return [string]
    }
    if let dictionary = value as? [String: Any] {
      return dictionary.flatMap { key, value in
        [key] + flattenedStrings(in: value)
      }
    }
    if let array = value as? [Any] {
      return array.flatMap(flattenedStrings)
    }
    return []
  }

  private func legacyProfilesOutputContainsProvider() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/profiles")
    process.arguments = ["show", "-type", "configuration"]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
      try process.run()
      process.waitUntilExit()
    } catch {
      return false
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else {
      return false
    }

    return output.range(
      of: #"nextdns|apple\.dns\.nextdns|dns\.nextdns|io\.nextdns|com\.nextdns"#,
      options: [.regularExpression, .caseInsensitive]
    ) != nil
  }
}
#endif

final class LocalHostsBlockerScriptGenerator: LocalHostsBlockerScriptGenerating {
  private static let markerBegin = "# QuietGate blocklist begin"
  private static let markerEnd = "# QuietGate blocklist end"

  private let outputDirectory: URL
  private let fileManager: FileManager
  private let hostsFileURL: URL
  private let privilegedScriptRunner: ((String) throws -> Void)?

  init(
    outputDirectory: URL? = nil,
    fileManager: FileManager = .default,
    hostsFileURL: URL? = nil,
    privilegedScriptRunner: ((String) throws -> Void)? = nil
  ) {
    self.outputDirectory = outputDirectory ?? fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
    self.fileManager = fileManager
    self.hostsFileURL = hostsFileURL ?? Self.defaultHostsFileURL()
    self.privilegedScriptRunner = privilegedScriptRunner
  }

  static func defaultHostsFileURL() -> URL {
    if let path = ProcessInfo.processInfo.environment["QG_HOSTS_PATH"],
       !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return URL(fileURLWithPath: path)
    }
    return URL(fileURLWithPath: "/etc/hosts")
  }

  func writeScript(domains: [String]) throws -> URL {
    let domains = try Self.normalizedDomains(domains)
    guard !domains.isEmpty else {
      throw LocalHostsBlockerScriptError.emptyBlocklist
    }

    try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    let url = outputDirectory.appendingPathComponent("QuietGate Local Hosts Blocker.command")
    let data = Data(Self.scriptText(for: domains).utf8)
    try data.write(to: url, options: .atomic)
    try fileManager.setAttributes(
      [.posixPermissions: NSNumber(value: Int16(0o755))],
      ofItemAtPath: url.path
    )
    return url
  }

  func installBlocklist(domains: [String]) throws {
    let domains = try Self.normalizedDomains(domains)
    try runPrivilegedScript(Self.nonInteractiveScriptText(for: domains, action: "install"))
  }

  func removeBlocklist() throws {
    try runPrivilegedScript(Self.nonInteractiveScriptText(for: [], action: "remove"))
  }

  func localHostsBlocklistInstalled() -> Bool {
    guard let hosts = try? String(contentsOf: hostsFileURL, encoding: .utf8) else {
      return false
    }

    return hosts.contains(Self.markerBegin) && hosts.contains(Self.markerEnd)
  }

  func localHostsBlocklistMatches(domains: [String]) -> Bool {
    guard let hosts = try? String(contentsOf: hostsFileURL, encoding: .utf8),
          let installedHosts = Self.markedBlocklistHosts(in: hosts),
          let expectedHosts = try? Self.expectedHosts(for: domains)
    else {
      return false
    }

    return installedHosts == expectedHosts
  }

  static func normalizedDomains(_ domains: [String]) throws -> [String] {
    try Array(Set(domains.map { try DomainNormalizer.normalize($0) })).sorted()
  }

  private static func scriptText(for domains: [String]) -> String {
    let hosts = hostnames(for: domains)
    let entries = hosts.flatMap { host in
      [
        "0.0.0.0 \(host)",
        "::1 \(host)"
      ]
    }.joined(separator: "\n")

    return """
    #!/bin/bash
    set -euo pipefail

    MARKER_BEGIN="# QuietGate blocklist begin"
    MARKER_END="# QuietGate blocklist end"
    HOSTS="/etc/hosts"
    TMP="$(mktemp)"
    BACKUP="/etc/hosts.quietgate.$(date +%Y%m%d%H%M%S).bak"

    cleanup() {
      rm -f "$TMP"
    }
    trap cleanup EXIT

    cat <<'QUIETGATE_INTRO'
    QuietGate Local Hosts Blocker

    1) Install/update local blocks
    2) Remove QuietGate local blocks

    This edits only the marked QuietGate section in /etc/hosts.
    macOS will ask for your password because /etc/hosts is system-owned.
    QUIETGATE_INTRO

    read -r -p "Choose 1 or 2: " choice
    case "$choice" in
      2|r|R|remove|Remove)
        ACTION="remove"
        ;;
      *)
        ACTION="install"
        ;;
    esac

    sudo cp "$HOSTS" "$BACKUP"
    awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" '
      $0 == begin { skip=1; next }
      $0 == end { skip=0; next }
      !skip { print }
    ' "$HOSTS" > "$TMP"

    if [[ "$ACTION" == "install" ]]; then
      printf '\\n' >> "$TMP"
      cat >> "$TMP" <<'QUIETGATE_BLOCKLIST'
    # QuietGate blocklist begin
    \(entries)
    # QuietGate blocklist end
    QUIETGATE_BLOCKLIST
    fi

    sudo install -m 644 "$TMP" "$HOSTS"
    sudo dscacheutil -flushcache || true
    sudo killall -HUP mDNSResponder || true

    echo
    echo "QuietGate local hosts blocklist: $ACTION complete."
    echo "Backup: $BACKUP"
    read -r -p "Press Return to close."
    """
  }

  private static func nonInteractiveScriptText(for domains: [String], action: String) -> String {
    let entries = hostnames(for: domains).flatMap { host in
      [
        "0.0.0.0 \(host)",
        "::1 \(host)"
      ]
    }.joined(separator: "\n")

    return """
    #!/bin/bash
    set -euo pipefail

    MARKER_BEGIN="# QuietGate blocklist begin"
    MARKER_END="# QuietGate blocklist end"
    HOSTS="/etc/hosts"
    TMP="$(mktemp)"
    BACKUP="/etc/hosts.quietgate.$(date +%Y%m%d%H%M%S).bak"
    ACTION="\(action)"

    cleanup() {
      rm -f "$TMP"
    }
    trap cleanup EXIT

    cp "$HOSTS" "$BACKUP"
    awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" '
      $0 == begin { skip=1; next }
      $0 == end { skip=0; next }
      !skip { print }
    ' "$HOSTS" > "$TMP"

    if [[ "$ACTION" == "install" ]]; then
      printf '\\n' >> "$TMP"
      cat >> "$TMP" <<'QUIETGATE_BLOCKLIST'
    # QuietGate blocklist begin
    \(entries)
    # QuietGate blocklist end
    QUIETGATE_BLOCKLIST
    fi

    install -m 644 "$TMP" "$HOSTS"
    dscacheutil -flushcache || true
    killall -HUP mDNSResponder || true
    """
  }

  private func runPrivilegedScript(_ script: String) throws {
    if let privilegedScriptRunner {
      try privilegedScriptRunner(script)
      return
    }

    let scriptURL = fileManager.temporaryDirectory
      .appendingPathComponent("quietgate-hosts-\(UUID().uuidString).sh")
    try script.write(to: scriptURL, atomically: true, encoding: .utf8)
    try fileManager.setAttributes(
      [.posixPermissions: NSNumber(value: Int16(0o700))],
      ofItemAtPath: scriptURL.path
    )
    defer { try? fileManager.removeItem(at: scriptURL) }

    let command = "/bin/bash \(Self.shellQuoted(scriptURL.path))"
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = [
      "-e",
      "do shell script \(Self.appleScriptString(command)) with administrator privileges"
    ]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    guard process.terminationStatus == 0 else {
      throw LocalHostsBlockerScriptError.privilegedCommandFailed(output)
    }
  }

  private static func shellQuoted(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
  }

  private static func appleScriptString(_ value: String) -> String {
    let escaped = value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(escaped)\""
  }

  private static func expectedHosts(for domains: [String]) throws -> Set<String> {
    Set(hostnames(for: try normalizedDomains(domains)))
  }

  private static func markedBlocklistHosts(in hostsFile: String) -> Set<String>? {
    let lines = hostsFile.components(separatedBy: .newlines)
    guard let beginIndex = lines.firstIndex(of: markerBegin),
          beginIndex + 1 < lines.endIndex,
          let endIndex = lines[(beginIndex + 1)...].firstIndex(of: markerEnd),
          beginIndex < endIndex
    else {
      return nil
    }

    return lines[(beginIndex + 1)..<endIndex].reduce(into: Set<String>()) { result, line in
      let parts = line.split { $0 == " " || $0 == "\t" }
      guard parts.count >= 2,
            parts[0] == "0.0.0.0" || parts[0] == "::1"
      else {
        return
      }
      result.insert(String(parts[1]))
    }
  }

  private static func hostnames(for domains: [String]) -> [String] {
    let hosts = domains.flatMap { domain in
      [
        domain,
        domain.hasPrefix("www.") ? domain : "www.\(domain)",
        domain.hasPrefix("m.") ? domain : "m.\(domain)"
      ]
    }
    return Array(Set(hosts)).sorted()
  }
}

#if DEBUG
final class LegacyProviderAppleProfileGenerator: LegacyProviderProfileGenerating {
  private let outputDirectory: URL
  private let fileManager: FileManager
  private let deviceNameProvider: () -> String
  private let uuidProvider: () -> UUID

  init(
    outputDirectory: URL? = nil,
    fileManager: FileManager = .default,
    deviceNameProvider: @escaping () -> String = { Host.current().localizedName ?? "Mac" },
    uuidProvider: @escaping () -> UUID = UUID.init
  ) {
    self.outputDirectory = outputDirectory ?? fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
    self.fileManager = fileManager
    self.deviceNameProvider = deviceNameProvider
    self.uuidProvider = uuidProvider
  }

  func writeProfile(profileID: String) throws -> URL {
    let profileID = profileID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !profileID.isEmpty else {
      throw LegacyProviderProfileError.missingProfileID
    }

    let data = try Self.profileData(
      profileID: profileID,
      deviceName: deviceNameProvider(),
      profileUUID: uuidProvider(),
      payloadUUID: uuidProvider()
    )
    try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    let url = outputDirectory.appendingPathComponent("QuietGate Blocking.mobileconfig")
    try data.write(to: url, options: .atomic)
    return url
  }

  static func profileData(
    profileID: String,
    deviceName: String,
    profileUUID: UUID = UUID(),
    payloadUUID: UUID = UUID()
  ) throws -> Data {
    let profileID = profileID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !profileID.isEmpty else {
      throw LegacyProviderProfileError.missingProfileID
    }

    guard let serverURL = legacyProviderServerURL(profileID: profileID, deviceName: deviceName) else {
      throw LegacyProviderProfileError.invalidProfile
    }

    let identifierSuffix = payloadIdentifierSuffix(profileID)
    let payload: [String: Any] = [
      "DNSSettings": [
        "DNSProtocol": "HTTPS",
        "ServerURL": serverURL.absoluteString
      ],
      "OnDemandRules": onDemandRules,
      "PayloadDescription": "Allows this Mac to use QuietGate blocking.",
      "PayloadDisplayName": "QuietGate Blocking",
      "PayloadIdentifier": "com.willpulier.quietgate.nextdns.dns.\(identifierSuffix)",
      "PayloadType": "com.apple.dnsSettings.managed",
      "PayloadUUID": payloadUUID.uuidString,
      "PayloadVersion": 1
    ]

    let profile: [String: Any] = [
      "PayloadContent": [payload],
      "PayloadDescription": "Installs the Mac approval used by QuietGate blocking.",
      "PayloadDisplayName": "QuietGate Blocking",
      "PayloadIdentifier": "com.willpulier.quietgate.nextdns.\(identifierSuffix)",
      "PayloadOrganization": "QuietGate",
      "PayloadRemovalDisallowed": false,
      "PayloadScope": "System",
      "PayloadType": "Configuration",
      "PayloadUUID": profileUUID.uuidString,
      "PayloadVersion": 1
    ]

    return try PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
  }

  private static func legacyProviderServerURL(profileID: String, deviceName: String) -> URL? {
    var allowedPathCharacters = CharacterSet.urlPathAllowed
    allowedPathCharacters.remove(charactersIn: "/?#")

    let encodedProfileID = profileID.addingPercentEncoding(withAllowedCharacters: allowedPathCharacters) ?? profileID
    let trimmedDeviceName = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
    let deviceName = trimmedDeviceName.isEmpty ? "QuietGate-Mac" : trimmedDeviceName
    let encodedDeviceName = deviceName.addingPercentEncoding(withAllowedCharacters: allowedPathCharacters) ?? "QuietGate-Mac"

    return URL(string: "https://apple.dns.nextdns.io/\(encodedProfileID)/\(encodedDeviceName)")
  }

  private static func payloadIdentifierSuffix(_ profileID: String) -> String {
    let suffix = profileID
      .lowercased()
      .filter { $0.isLetter || $0.isNumber || $0 == "-" }
      .prefix(64)
    return suffix.isEmpty ? "profile" : String(suffix)
  }

  private static var onDemandRules: [[String: Any]] {
    [
      [
        "Action": "EvaluateConnection",
        "ActionParameters": [
          [
            "DomainAction": "NeverConnect",
            "Domains": [
              "captive.apple.com",
              "3gppnetwork.org",
              "dav.orange.fr",
              "vvm.mobistar.be",
              "vvm.mstore.msg.t-mobile.com",
              "tma.vvm.mone.pan-net.eu",
              "vvm.ee.co.uk"
            ]
          ]
        ]
      ],
      [
        "Action": "Connect"
      ]
    ]
  }
}
#endif
