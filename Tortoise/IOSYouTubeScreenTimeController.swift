import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import SafariServices
import UIKit

@MainActor
final class IOSEnforcementController: ObservableObject {
  @Published var selection: FamilyActivitySelection {
    didSet {
      persistState()
      applyCurrentMode()
    }
  }

  /// The general "Apps" selection (separate from the YouTube `selection`). Edited
  /// only via `setManagedAppsSelection(_:)` so the locked-session freeze holds.
  @Published private(set) var managedAppsSelection: FamilyActivitySelection = FamilyActivitySelection()

  @Published var shieldingEnabled: Bool {
    didSet {
      persistState()
      applyCurrentMode()
    }
  }

  @Published var authorizationMode: IOSEnforcementAuthorizationMode {
    didSet {
      persistState()
      saveSnapshot(lastError: lastError)
      updateStatusMessage()
    }
  }

  @Published var enforcementMode: IOSEnforcementMode {
    didSet {
      persistState()
      applyCurrentMode()
    }
  }

  @Published var dailyLimitMinutes: Int {
    didSet {
      // On a @Published property, assigning from inside didSet re-fires
      // didSet (unlike a plain stored property) — an unconditional clamp
      // re-assign here recursed to stack overflow on the FIRST post-init
      // write and killed TestFlight builds 1–7 at launch (policy sync writes
      // this). Re-assign only when out of range; the nested didSet then takes
      // the in-range path exactly once.
      let clamped = min(max(dailyLimitMinutes, 5), 480)
      guard dailyLimitMinutes == clamped else {
        dailyLimitMinutes = clamped
        return
      }
      persistState()
      applyCurrentMode()
    }
  }

  /// Stage 2: combined managed-apps daily limit (minutes). `nil` = off. Clamped
  /// 5–480 when set. Advisory OPEN governor — `applyCurrentMode()` re-arms the
  /// `.tortoiseManagedAppsDaily` monitor. Same recursion hazard as
  /// `dailyLimitMinutes`: @Published re-fires didSet on assignment from within
  /// didSet, so the clamp must re-assign only when the value actually changes.
  @Published var managedAppsLimitMinutes: Int? {
    didSet {
      if let minutes = managedAppsLimitMinutes {
        let clamped = ManagedAppsShield.clampManagedAppsLimitMinutes(minutes)
        guard minutes == clamped else {
          managedAppsLimitMinutes = clamped
          return
        }
      }
      persistState()
      applyCurrentMode()
    }
  }

  @Published var safariExtensionAcknowledged: Bool {
    didSet {
      persistState()
      writeSafariPolicy()
      saveSnapshot(lastError: lastError)
      updateStatusMessage()
    }
  }

  /// Device-local Custom mode state. Set only through the setters below (which
  /// carry the locked-session guards) — no didSet side effects by design.
  @Published private(set) var customSelection: FamilyActivitySelection
  @Published private(set) var customExcludedApps: Set<ApplicationToken>
  @Published private(set) var customAdultEnabled: Bool

  @Published private(set) var authorizationState: IOSScreenTimeAuthorizationState = .notDetermined
  @Published private(set) var statusMessage: String = "Choose setup type, allow Screen Time, then select apps and sites."
  @Published private(set) var scheduleActive = false
  @Published private(set) var syncHealth = "Waiting for setup"
  @Published private(set) var lastError: String?
  @Published private(set) var safariExtensionState: IOSSafariExtensionState = .unknown
  @Published private(set) var lastSafariExtensionSeenAt: Date?
  @Published private(set) var lastSafariPolicyAppliedAt: Date?
  @Published private(set) var lastSetupCheckAt: Date?
  @Published private(set) var safariExtensionStatusError: String?
  @Published private(set) var session: IOSSessionState?

  private let immediateStore = ManagedSettingsStore(named: .tortoiseImmediate)
  private let managedAppsStore = ManagedSettingsStore(named: .tortoiseManagedApps)
  private let managedAppsLimitStore = ManagedSettingsStore(named: .tortoiseManagedAppsLimit)
  private let activityCenter = DeviceActivityCenter()
  private var isApplying = false
  private var policyFeatures: [String: Bool] = [:]
  private var sessionExpiryTimer: Timer?

  init() {
    let persisted = Self.loadState()
    selection = Self.expandedSelection(IOSEnforcementSharedStore.loadSelection())
    managedAppsSelection = Self.expandedSelection(IOSEnforcementSharedStore.loadManagedAppsSelection())
    customSelection = Self.expandedSelection(IOSEnforcementSharedStore.loadCustomSelection())
    customExcludedApps = IOSEnforcementSharedStore.loadCustomExcludedApps()
    customAdultEnabled = IOSEnforcementSharedStore.loadCustomAdultEnabled()
    shieldingEnabled = persisted.shieldingEnabled
    authorizationMode = persisted.authorizationMode
    enforcementMode = persisted.enforcementMode
    dailyLimitMinutes = persisted.dailyLimitMinutes
    managedAppsLimitMinutes = persisted.managedAppsLimitMinutes
    safariExtensionAcknowledged = persisted.safariExtensionAcknowledged
    let recoveredFromLaunchLoop = recoverFromLaunchLoopIfNeeded()
    purgeStaleShieldStoresIfNeeded()
    repairSelfShieldIfNeeded()
    loadSafariSetupSnapshot()
    refreshAuthorizationState()
    refreshSetupStatus()
    applyCurrentMode()
    session = IOSEnforcementSharedStore.loadSnapshot().session
    expireSessionIfNeeded()
    armLaunchSurvivalMarkers()
    // Last: applyCurrentMode()'s deferred updateStatusMessage() overwrites
    // anything set earlier in init, and this message must be what greets the
    // person after a wipe.
    if recoveredFromLaunchLoop {
      statusMessage = "Tortoise kept getting closed by its own protection, so protection was reset. Pick your apps again."
    }
  }

  /// Crash-loop backstop: a shield that catches Tortoise itself makes iOS
  /// kill the app moments after every foreground — no crash log, and no
  /// guarantee any code later in launch runs. So the check is first, the
  /// trigger is the loop itself (two straight launches that died while
  /// foregrounded with enforcement active), and the response wipes
  /// EVERYTHING: every store, every monitor, both selections, and the
  /// on-switch. init's applyCurrentMode() then re-applies the now-empty state.
  private func recoverFromLaunchLoopIfNeeded() -> Bool {
    let wasEnforcing = shieldingEnabled || hasSelection || hasManagedAppsSelection
    guard IOSEnforcementSharedStore.beginLaunchWatch(wasEnforcing: wasEnforcing) else {
      return false
    }
    IOSEnforcementShieldApplier.purgeAllStoresEverWritten()
    activityCenter.stopMonitoring()
    selection = FamilyActivitySelection(includeEntireCategory: true)
    managedAppsSelection = FamilyActivitySelection(includeEntireCategory: true)
    IOSEnforcementSharedStore.saveManagedAppsSelection(managedAppsSelection)
    shieldingEnabled = false
    return true
  }

  /// A Screen Time self-shield kill strikes while the app is foregrounded, so
  /// surviving to background OR outliving the grace period both prove this
  /// launch was healthy. Quick in-and-out visits background normally and never
  /// count toward the loop.
  private func armLaunchSurvivalMarkers() {
    NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification,
      object: nil,
      queue: .main
    ) { _ in
      IOSEnforcementSharedStore.markLaunchSurvived()
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
      IOSEnforcementSharedStore.markLaunchSurvived()
    }
  }

  /// Rebuilds `base` with `includeEntireCategory: true` so future picker edits
  /// expand category picks into their member-app tokens — those concrete tokens
  /// are what gets shielded now that raw category shields are gone ("Tortoise
  /// can't block Tortoise").
  private static func expandedSelection(_ base: FamilyActivitySelection) -> FamilyActivitySelection {
    var expanded = FamilyActivitySelection(includeEntireCategory: true)
    expanded.applicationTokens = base.applicationTokens
    expanded.categoryTokens = base.categoryTokens
    expanded.webDomainTokens = base.webDomainTokens
    return expanded
  }

  /// ManagedSettings persist system-side until explicitly cleared, and builds
  /// ≤3 could leave category shields (which may include Tortoise itself) in the
  /// event-owned stores that enforcement passes never rewrite in Focus/Strict.
  /// One-time purge of every store + all monitors; init's applyCurrentMode()
  /// then re-arms everything fresh with category-free shields.
  private func purgeStaleShieldStoresIfNeeded() {
    // v2: v1 marked itself done BEFORE purging — on a phone where the app dies
    // seconds after launch, that one shot may have burned without the clears
    // landing. Run once more for everyone, and mark done only AFTER the work
    // so an interrupted purge retries next launch (it's idempotent).
    let migrationKey = "TortoiseShieldStorePurge.v2"
    guard !TortoiseAppGroup.defaults.bool(forKey: migrationKey) else {
      return
    }
    IOSEnforcementShieldApplier.purgeAllStoresEverWritten()
    activityCenter.stopMonitoring()
    TortoiseAppGroup.defaults.set(true, forKey: migrationKey)
  }

  /// The ShieldConfiguration extension flags the App Group when iOS asked it to
  /// shield Tortoise itself. Purge every store and clear every selection that
  /// could have caused it — deliberately bypassing the locked-session shrink
  /// guard: staying usable outranks precommitment when the app is blocking
  /// itself.
  private func repairSelfShieldIfNeeded() {
    guard IOSEnforcementSharedStore.consumeSelfShieldFlag() else {
      return
    }
    IOSEnforcementShieldApplier.purgeAllStoresEverWritten()
    activityCenter.stopMonitoring()
    selection = FamilyActivitySelection(includeEntireCategory: true)
    managedAppsSelection = FamilyActivitySelection(includeEntireCategory: true)
    IOSEnforcementSharedStore.saveSelection(selection)
    IOSEnforcementSharedStore.saveManagedAppsSelection(managedAppsSelection)
    statusMessage = "A selection blocked Tortoise itself, so Tortoise cleared it. Pick your apps again."
  }

  var hasSelection: Bool {
    !selection.applicationTokens.isEmpty ||
      !selection.categoryTokens.isEmpty ||
      !selection.webDomainTokens.isEmpty
  }

  var hasManagedAppsSelection: Bool {
    !managedAppsSelection.applicationTokens.isEmpty ||
      !managedAppsSelection.categoryTokens.isEmpty ||
      !managedAppsSelection.webDomainTokens.isEmpty
  }

  /// Honest one-line state for the "Apps" card. Omits any zero count.
  var managedAppsSummary: String {
    guard hasManagedAppsSelection else {
      return "Choose apps to block in Focus & Strict."
    }
    let apps = managedAppsSelection.applicationTokens.count
    let categories = managedAppsSelection.categoryTokens.count
    let domains = managedAppsSelection.webDomainTokens.count
    if ManagedAppsShield.selectionNeedsRepick(
      categoryCount: categories, applicationCount: apps, webDomainCount: domains
    ) {
      return "Category picks changed - tap Edit and re-select so each app is blocked directly."
    }
    var parts: [String] = []
    if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
    if categories > 0 { parts.append("\(categories) categor\(categories == 1 ? "y" : "ies")") }
    if domains > 0 { parts.append("\(domains) web domain\(domains == 1 ? "" : "s")") }
    return parts.joined(separator: " · ") + " blocked in Focus & Strict"
  }

  var managedAppsLimitEnabled: Bool { managedAppsLimitMinutes != nil }

  /// Value shown in the stepper — defaults to 30 when the limit is off.
  var managedAppsLimitDisplayMinutes: Int { managedAppsLimitMinutes ?? 30 }

  /// Honest one-line copy for the Apps-card limit control.
  var managedAppsLimitSummary: String {
    guard let minutes = managedAppsLimitMinutes else {
      return "No daily limit"
    }
    return "Allowed \(minutes)m/day in Open · blocked in Focus & Strict"
  }

  var coverageSummary: String {
    if !hasSelection {
      return "Nothing chosen yet"
    }

    // Only the non-zero pieces — "2 apps · 1 site", never "0 categories".
    var parts: [String] = []
    let apps = selection.applicationTokens.count
    let categories = selection.categoryTokens.count
    let domains = selection.webDomainTokens.count
    if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
    if categories > 0 { parts.append("\(categories) categor\(categories == 1 ? "y" : "ies")") }
    if domains > 0 { parts.append("\(domains) site\(domains == 1 ? "" : "s")") }
    return parts.joined(separator: " · ")
  }

  var canApplyShielding: Bool {
    authorizationState.isApproved && hasSelection
  }

  var canTurnOn: Bool {
    canApplyShielding
  }

  var sessionActive: Bool {
    IOSSession.isActive(session, now: Date())
  }

  var sessionLockedActive: Bool {
    IOSSession.isLockedActive(session, now: Date())
  }

  var sessionStatusLine: String {
    guard let session, sessionActive else { return "No active session" }
    let mins = Int(IOSSession.remaining(session, now: Date()) / 60) + 1
    return "\(session.locked ? "Locked " : "")\(session.mode.rawValue.capitalized) session · \(mins)m left"
  }

  /// True when any enforcement surface is active: a YouTube selection, a
  /// managed-apps selection, or the Strict adult web filter.
  private var enforcementActive: Bool {
    ManagedAppsShield.isEnforcementActive(
      youtubeSelected: hasSelection,
      managedAppsSelected: enforcementMode == .custom ? customEffectiveSelection != nil : hasManagedAppsSelection,
      adultFilterOn: ManagedAppsShield.shouldApplyAdultFilter(mode: enforcementMode, adultEnabled: adultFilterInputEnabled)
    )
  }

  var connectionState: IOSEnforcementConnectionState {
    if authorizationState == .denied || lastError != nil || safariExtensionState == .failed {
      return .repairRequired
    }

    if authorizationState != .approved || !enforcementActive {
      return .setupRequired
    }

    if shieldingEnabled && enforcementMode != .open && scheduleActive && safariExtensionConnected {
      return .connected
    }

    if shieldingEnabled || safariExtensionConnected || scheduleActive {
      return .partial
    }

    return .setupRequired
  }

  /// The steps a person actually performs; account/mode/sync resolve on their
  /// own and would only pad the checklist.
  static let userSetupSteps: [IOSEnforcementSetupStep] = [
    .screenTimePermission, .targets, .safariExtension, .mode,
  ]

  var setupProgressText: String {
    let completeCount = Self.userSetupSteps.filter { setupStatus(for: $0) == .complete }.count
    return "\(completeCount) of \(Self.userSetupSteps.count)"
  }

  var setupRemainingText: String {
    let remaining = Self.userSetupSteps.filter { setupStatus(for: $0) != .complete }.count
    if remaining == 0 {
      return "Almost done"
    }
    return remaining == 1 ? "1 step left" : "\(remaining) steps left"
  }

  var connectionTitle: String {
    switch connectionState {
    case .connected:
      return "iPhone connected"
    case .partial, .setupRequired:
      return "Finish setup"
    case .repairRequired:
      return "Needs attention"
    }
  }

  var deviceStatusSubtitle: String {
    switch connectionState {
    case .connected:
      return "\(enforcementMode.rawValue.capitalized) active · \(coverageSummary)"
    case .partial:
      return "\(enforcementMode.rawValue.capitalized) partly active · \(coverageSummary)"
    case .setupRequired:
      return "Not protecting yet"
    case .repairRequired:
      return repairDetail
    }
  }

  var repairDetail: String {
    if authorizationState == .denied {
      return authorizationMode == .child
        ? "Child setup needs Family Sharing and Screen Time approval on the child device."
        : "Screen Time permission is blocked. Re-enable App & Website Activity for Tortoise, then retry."
    }
    if safariExtensionState == .failed {
      return safariExtensionStatusError ?? "Safari extension status could not be checked."
    }
    return lastError ?? "Tortoise could not apply the latest iOS protection state."
  }

  var safariExtensionConnected: Bool {
    switch safariExtensionState {
    case .connected:
      return true
    case .unavailable:
      return safariExtensionAcknowledged && safariHeartbeatIsFresh
    default:
      return false
    }
  }

  var safariHeartbeatIsFresh: Bool {
    IOSEnforcementSharedStore.safariHeartbeatIsFresh(lastSafariExtensionSeenAt)
  }

  var safariStateTitle: String {
    switch safariExtensionState {
    case .connected:
      return "Safari connected"
    case .enabledWaitingForHeartbeat:
      return "Enabled, waiting for Safari"
    case .disabled:
      return "Safari extension off"
    case .unavailable:
      return safariExtensionAcknowledged ? "Manual Safari check pending" : "Manual Safari setup"
    case .failed:
      return "Safari check failed"
    case .unknown:
      return "Checking Safari"
    }
  }

  var screenTimeStatusTitle: String {
    authorizationState.title
  }

  var targetStatusTitle: String {
    hasSelection ? coverageSummary : "Select apps, sites, or categories"
  }

  var safariStatusTitle: String {
    switch safariExtensionState {
    case .connected:
      return "Heartbeat verified"
    case .enabledWaitingForHeartbeat:
      return "Open Safari to verify"
    case .disabled:
      return "Enable in Safari settings"
    case .unavailable:
      return safariExtensionAcknowledged ? "Manual confirmation saved" : "Enable in Safari settings"
    case .failed:
      return "Tap Recheck or use manual setup"
    case .unknown:
      return "Checking extension state"
    }
  }

  var schedulesStatusTitle: String {
    scheduleActive ? "Daily monitor active" : "No active monitor"
  }

  var limitStatusTitle: String {
    "\(dailyLimitMinutes)m selected-target limit"
  }

  var safariManualSetupText: String {
    "Settings -> Apps -> Safari -> Extensions -> Tortoise Safari -> Allow Extension"
  }

  func setupStatus(for step: IOSEnforcementSetupStep) -> IOSEnforcementSetupStatus {
    switch step {
    case .account:
      return .complete
    case .authorizationMode:
      return .complete
    case .screenTimePermission:
      switch authorizationState {
      case .approved:
        return .complete
      case .denied:
        return .failed
      case .notDetermined:
        return .needsAction
      case .unknown:
        return .checking
      }
    case .targets:
      return hasSelection ? .complete : .needsAction
    case .safariExtension:
      switch safariExtensionState {
      case .connected:
        return .complete
      case .enabledWaitingForHeartbeat:
        return .checking
      case .disabled, .unavailable:
        return .needsAction
      case .failed:
        return .failed
      case .unknown:
        return .checking
      }
    case .mode:
      return shieldingEnabled && enforcementMode != .open ? .complete : .needsAction
    case .sync:
      if let lastError, !lastError.isEmpty {
        return .failed
      }
      return syncHealth.contains("current") || connectionState == .connected ? .complete : .checking
    }
  }

  func refreshAuthorizationState() {
    let status = AuthorizationCenter.shared.authorizationStatus
    switch status {
    case .notDetermined:
      authorizationState = .notDetermined
    case .denied:
      authorizationState = .denied
    case .approved:
      authorizationState = .approved
    case .approvedWithDataAccess:
      authorizationState = .approved
    @unknown default:
      authorizationState = .unknown
    }
    updateStatusMessage()
  }

  func refreshSetupStatus() {
    repairSelfShieldIfNeeded()
    refreshAuthorizationState()
    loadSafariSetupSnapshot()
    lastSetupCheckAt = Date()
    refreshSafariExtensionState()
    saveSnapshot(lastError: lastError)
  }

  func requestAuthorization() async {
    do {
      try await AuthorizationCenter.shared.requestAuthorization(for: authorizationMode.familyMember)
      refreshAuthorizationState()
      lastError = nil
    } catch {
      authorizationState = .denied
      lastError = error.localizedDescription
      statusMessage = authorizationMode == .child
        ? "Child setup needs Family Sharing and a child Apple Account before Screen Time authorization can finish."
        : "Screen Time permission failed. Check the Family Controls entitlement and Settings."
    }
    applyCurrentMode()
  }

  func setMode(_ mode: IOSEnforcementMode) {
    guard IOSSession.canChangeMode(session, now: Date()) else { return }
    applyMode(mode)
  }

  /// Applies a mode without the locked-session guard. Used by `setMode` (after
  /// its guard passes) and by the session lifecycle methods below, which must
  /// always be able to apply their own start/end/expiry transition even while
  /// `session` reflects the very session being started or ended.
  private func applyMode(_ mode: IOSEnforcementMode) {
    enforcementMode = mode
    shieldingEnabled = mode != .open
  }

  func turnOn() {
    if enforcementMode == .open {
      enforcementMode = .focus
    }
    shieldingEnabled = true
    applyCurrentMode()
  }

  func turnOff() {
    guard IOSSession.canEndEarly(session, now: Date()) else { return }
    shieldingEnabled = false
    enforcementMode = .open
    session = nil
    sessionExpiryTimer?.invalidate()
    applyCurrentMode()
  }

  func clearSelection() {
    guard !sessionLockedActive else { return }
    selection = FamilyActivitySelection(includeEntireCategory: true)
    shieldingEnabled = false
  }

  /// Applies a new managed-apps selection. While a locked session is active the
  /// selection may only GROW — any shrink/clear (a committed token dropped) is
  /// refused (precommitment). Unlocked, any edit is accepted. On acceptance the
  /// selection is persisted and the shield re-applied through `applyCurrentMode()`.
  func setManagedAppsSelection(_ newValue: FamilyActivitySelection) {
    let shrinks =
      ManagedAppsShield.isShrink(
        old: managedAppsSelection.applicationTokens, new: newValue.applicationTokens) ||
      ManagedAppsShield.isShrink(
        old: managedAppsSelection.categoryTokens, new: newValue.categoryTokens) ||
      ManagedAppsShield.isShrink(
        old: managedAppsSelection.webDomainTokens, new: newValue.webDomainTokens)

    guard ManagedAppsShield.canApplyEdit(lockedActive: sessionLockedActive, isShrink: shrinks) else {
      return
    }

    managedAppsSelection = newValue
    IOSEnforcementSharedStore.saveManagedAppsSelection(newValue)
    applyCurrentMode()
  }

  // MARK: Custom group (device-local Block mode)

  /// Applies a new Custom-group selection through the same precommitment guard
  /// as the managed selection: while a locked session is active it may only
  /// grow. Excluded switches are pruned to stay ⊆ the picked apps.
  func setCustomSelection(_ newValue: FamilyActivitySelection) {
    let expanded = Self.expandedSelection(newValue)
    let shrinks =
      ManagedAppsShield.isShrink(
        old: customSelection.applicationTokens, new: expanded.applicationTokens) ||
      ManagedAppsShield.isShrink(
        old: customSelection.categoryTokens, new: expanded.categoryTokens) ||
      ManagedAppsShield.isShrink(
        old: customSelection.webDomainTokens, new: expanded.webDomainTokens)

    guard ManagedAppsShield.canApplyEdit(lockedActive: sessionLockedActive, isShrink: shrinks) else {
      return
    }

    customSelection = expanded
    customExcludedApps = customExcludedApps.intersection(expanded.applicationTokens)
    IOSEnforcementSharedStore.saveCustomSelection(expanded)
    IOSEnforcementSharedStore.saveCustomExcludedApps(customExcludedApps)
    applyCurrentMode()
  }

  /// Per-app on/off inside the Custom group. Locked sessions allow tightening
  /// (ON) but never loosening (OFF) — `ManagedAppsShield.canToggleCustomApp`.
  func setCustomApp(_ token: ApplicationToken, isOn: Bool) {
    guard ManagedAppsShield.canToggleCustomApp(lockedActive: sessionLockedActive, turningOn: isOn) else {
      return
    }
    if isOn {
      customExcludedApps.remove(token)
    } else {
      customExcludedApps.insert(token)
    }
    IOSEnforcementSharedStore.saveCustomExcludedApps(customExcludedApps)
    applyCurrentMode()
  }

  /// The Custom group's adult-websites toggle. Tighten-only while locked.
  func setCustomAdultEnabled(_ enabled: Bool) {
    guard enabled || !sessionLockedActive else { return }
    customAdultEnabled = enabled
    IOSEnforcementSharedStore.saveCustomAdultEnabled(enabled)
    applyCurrentMode()
  }

  var hasCustomSelection: Bool {
    !customSelection.applicationTokens.isEmpty || !customSelection.webDomainTokens.isEmpty
  }

  /// What Custom actually shields right now: picked apps minus off-switches,
  /// plus picked web domains. Nil when nothing effective remains.
  var customEffectiveSelection: FamilyActivitySelection? {
    var effective = FamilyActivitySelection(includeEntireCategory: true)
    effective.applicationTokens = ManagedAppsShield.customShieldTokens(
      selected: customSelection.applicationTokens,
      excluded: customExcludedApps
    )
    effective.webDomainTokens = customSelection.webDomainTokens
    if effective.applicationTokens.isEmpty && effective.webDomainTokens.isEmpty {
      return nil
    }
    return effective
  }

  /// Turns the combined managed-apps daily limit on (default 30m) or off. Advisory
  /// OPEN governor; disabled while a locked session is active (the apps are blocked
  /// outright then, so the limit is moot — spec §4/§7).
  func setManagedAppsLimitEnabled(_ enabled: Bool) {
    guard !sessionLockedActive else { return }
    if enabled {
      if managedAppsLimitMinutes == nil {
        managedAppsLimitMinutes = 30
      }
    } else {
      managedAppsLimitMinutes = nil
    }
  }

  /// Raises/lowers the limit by `delta` minutes (clamped 5–480). Clears any
  /// already-applied limit shield first so the change takes effect immediately
  /// (raising regains access; `applyCurrentMode()` re-arms at the new threshold).
  /// No-op when the limit is off or a locked session is active.
  func adjustManagedAppsLimit(by delta: Int) {
    guard !sessionLockedActive, let current = managedAppsLimitMinutes else { return }
    managedAppsLimitStore.clearAllSettings()
    managedAppsLimitMinutes = ManagedAppsShield.clampManagedAppsLimitMinutes(current + delta)
  }

  func startSession(mode: IOSEnforcementMode, duration: TimeInterval, locked: Bool) {
    guard !sessionLockedActive else { return }          // can't override a locked session
    let mode = mode == .open ? .focus : mode
    session = IOSSessionState(mode: mode, endsAt: Date().addingTimeInterval(duration), locked: locked)
    applyMode(mode)                                      // applies shield via applyCurrentMode + persists
    scheduleSessionExpiry()
    saveSnapshot(lastError: lastError)                   // persist the session field
  }

  func endSession() {
    guard IOSSession.canEndEarly(session, now: Date()) else { return }  // locked → refuse
    session = nil
    applyMode(.open)
    sessionExpiryTimer?.invalidate()
    saveSnapshot(lastError: lastError)
  }

  func expireSessionIfNeeded() {
    guard IOSSession.hasExpired(session, now: Date()) else {
      scheduleSessionExpiry()
      return
    }
    session = nil
    applyMode(.open)
    saveSnapshot(lastError: lastError)
  }

  private func scheduleSessionExpiry() {
    sessionExpiryTimer?.invalidate()
    guard let session, sessionActive else { return }
    let interval = max(1, session.endsAt.timeIntervalSinceNow)
    sessionExpiryTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
      Task { @MainActor in self?.expireSessionIfNeeded() }
    }
  }

  func retrySetupStep(_ step: IOSEnforcementSetupStep) {
    switch step {
    case .screenTimePermission:
      Task {
        await requestAuthorization()
      }
    case .safariExtension:
      openSafariExtensionSettings()
    case .mode:
      turnOn()
    case .sync, .account, .authorizationMode, .targets:
      refreshSetupStatus()
    }
  }

  func openSettings() {
    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
      return
    }
    UIApplication.shared.open(settingsURL)
  }

  func openSafariExtensionSettings() {
    if #available(iOS 26.2, *) {
      SFSafariSettings.openExtensionsSettings(forIdentifiers: [Self.safariExtensionBundleIdentifier]) { [weak self] error in
        guard let self else {
          return
        }
        if let error {
          Task { @MainActor in
            self.safariExtensionStatusError = error.localizedDescription
            self.openSettings()
          }
        }
      }
      return
    }

    openSettings()
  }

  func openSafariVerificationPage() {
    // Must be a domain no installed app claims via Universal Links — a
    // youtube.com/x.com/instagram.com URL opens that APP, not Safari, and the
    // extension can never heartbeat. Our own site always lands in Safari,
    // where web-classifier.js performs the verification handshake.
    guard let url = URL(string: "https://www.yourtortoise.com/?safari-check=1") else {
      return
    }
    UIApplication.shared.open(url)
  }

  private func loadSafariSetupSnapshot() {
    let snapshot = IOSEnforcementSharedStore.loadSnapshot()
    lastSafariExtensionSeenAt = snapshot.lastSafariExtensionSeenAt
    lastSafariPolicyAppliedAt = snapshot.lastSafariPolicyAppliedAt
    if let storedState = snapshot.safariExtensionState {
      safariExtensionState = resolvedSafariState(from: storedState)
    } else if safariExtensionAcknowledged {
      safariExtensionState = safariHeartbeatIsFresh ? .connected : .enabledWaitingForHeartbeat
    }
  }

  private func refreshSafariExtensionState() {
    loadSafariSetupSnapshot()

    if #available(iOS 26.2, *) {
      safariExtensionState = .unknown
      SFSafariExtensionManager.getStateOfExtension(withIdentifier: Self.safariExtensionBundleIdentifier) { [weak self] state, error in
        Task { @MainActor in
          guard let self else {
            return
          }

          self.lastSetupCheckAt = Date()
          if let error {
            self.safariExtensionStatusError = error.localizedDescription
            self.safariExtensionState = .failed
          } else if state?.isEnabled == true {
            self.safariExtensionStatusError = nil
            self.safariExtensionState = self.safariHeartbeatIsFresh ? .connected : .enabledWaitingForHeartbeat
          } else {
            self.safariExtensionStatusError = nil
            self.safariExtensionState = .disabled
          }
          self.saveSnapshot(lastError: self.lastError)
          self.updateStatusMessage()
        }
      }
      return
    }

    safariExtensionStatusError = nil
    safariExtensionState = safariExtensionAcknowledged
      ? (safariHeartbeatIsFresh ? .connected : .enabledWaitingForHeartbeat)
      : .unavailable
  }

  private func resolvedSafariState(from storedState: IOSSafariExtensionState) -> IOSSafariExtensionState {
    switch storedState {
    case .connected:
      return safariHeartbeatIsFresh ? .connected : .enabledWaitingForHeartbeat
    case .enabledWaitingForHeartbeat, .unavailable:
      return safariExtensionAcknowledged && safariHeartbeatIsFresh ? .connected : storedState
    case .unknown, .disabled, .failed:
      return storedState
    }
  }

  private func applyCurrentMode() {
    guard !isApplying else {
      return
    }
    isApplying = true
    defer {
      isApplying = false
      updateStatusMessage()
    }

    // Single top-of-pass reset so a resolved error clears on the next pass. Gated on
    // approval: while unauthorized the monitor-arm reconciles below early-return without
    // touching `lastError`, so an unconditional reset here would wipe a sticky auth-request
    // failure set by `requestAuthorization()`. Within an approved pass each arm now sets
    // `lastError` only on FAILURE (never clears on success), so no monitor's success can
    // erase another monitor's failure.
    if authorizationState.isApproved {
      lastError = nil
    }

    let managedAppsShielded = applyManagedAppsShield()
    reconcileManagedAppsLimitMonitoring()

    // Custom deliberately takes the light branch: it shields its OWN group via
    // applyManagedAppsShield() above and never applies the YouTube selection
    // or arms the YouTube daily monitor.
    let shouldEnforce = shieldingEnabled
      && (enforcementMode == .focus || enforcementMode == .strict)
      && canApplyShielding
    if !shouldEnforce {
      IOSEnforcementShieldApplier.clearAllStores()
      activityCenter.stopMonitoring([.tortoiseDaily])
      scheduleActive = false
      // Independence fix: the Strict/Custom adult filter rides MODE, not the
      // YouTube selection — re-apply it after clearAllStores() wiped
      // immediateStore, and write the REAL-mode Safari policy (not a forced
      // `.open`), so the adult web/media filter holds with no YouTube target.
      reconcileAdultWebFilter()
      writeSafariPolicy()
      let adultActive = ManagedAppsShield.shouldApplyAdultFilter(
        mode: enforcementMode, adultEnabled: adultFilterInputEnabled)
      syncHealth = (managedAppsShielded || adultActive)
        ? "Screen Time and Safari policy current"
        : (enforcementMode == .custom ? "Custom group is empty" : "Open mode")
      saveSnapshot(lastError: lastError)
      return
    }

    let adultWebFilterEnabled = enforcementMode == .strict
    IOSEnforcementShieldApplier.applySelection(
      selection,
      to: immediateStore,
      adultWebFilterEnabled: adultWebFilterEnabled
    )
    startDailyMonitoring()
    writeSafariPolicy()
    saveSnapshot(lastError: lastError)
    syncHealth = "Screen Time and Safari policy current"
  }

  /// Reconciles the general "Apps" shield in its own `.tortoiseManagedApps` store.
  /// Governed by MODE (Focus/Strict) + authorization + a non-empty managed-apps
  /// selection — independent of the YouTube `selection`, so managed apps are
  /// shielded even when no YouTube target is picked. The system unions this store
  /// with the YouTube shield automatically.
  @discardableResult
  private func applyManagedAppsShield() -> Bool {
    guard ManagedAppsShield.shouldShield(mode: enforcementMode),
          authorizationState.isApproved,
          let source = managedAppsShieldSource else {
      managedAppsStore.clearAllSettings()
      return false
    }
    IOSEnforcementShieldApplier.applyShield(source, to: managedAppsStore)
    return true
  }

  /// What the `.tortoiseManagedApps` store shields under the current mode:
  /// Focus/Strict → the managed selection; Custom → its own picked group
  /// (minus per-app off-switches); Open → nothing.
  private var managedAppsShieldSource: FamilyActivitySelection? {
    switch enforcementMode {
    case .focus, .strict:
      return hasManagedAppsSelection ? managedAppsSelection : nil
    case .custom:
      return customEffectiveSelection
    case .open:
      return nil
    }
  }

  /// The `adultEnabled` input to `ManagedAppsShield.shouldApplyAdultFilter`:
  /// Strict rides the on-switch; Custom rides its own adult toggle.
  private var adultFilterInputEnabled: Bool {
    enforcementMode == .custom ? (shieldingEnabled && customAdultEnabled) : shieldingEnabled
  }

  /// Stage 2: arms/re-arms the combined managed-apps daily-limit monitor in its OWN
  /// DeviceActivity (`.tortoiseManagedAppsDaily`) so it runs regardless of mode —
  /// the limit is an OPEN governor (in Focus/Strict the Stage 1 shield already
  /// blocks the apps, making the limit shield a harmless redundant union). Armed
  /// only when the limit is enabled, the selection is non-empty, and Screen Time is
  /// authorized; otherwise the monitor is stopped and `.tortoiseManagedAppsLimit`
  /// cleared so no stale limit shield survives (spec §11).
  private func reconcileManagedAppsLimitMonitoring() {
    let shouldArm = ManagedAppsShield.shouldArmManagedAppsLimit(
      limitEnabled: managedAppsLimitMinutes != nil,
      hasSelection: hasManagedAppsSelection
    ) && authorizationState.isApproved

    guard shouldArm, let minutes = managedAppsLimitMinutes else {
      activityCenter.stopMonitoring([.tortoiseManagedAppsDaily])
      managedAppsLimitStore.clearAllSettings()
      return
    }

    let schedule = DeviceActivitySchedule(
      intervalStart: DateComponents(hour: 0, minute: 0),
      intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
      repeats: true
    )
    let event = DeviceActivityEvent(
      applications: managedAppsSelection.applicationTokens,
      categories: managedAppsSelection.categoryTokens,
      webDomains: managedAppsSelection.webDomainTokens,
      threshold: DateComponents(minute: minutes)
    )
    do {
      try activityCenter.startMonitoring(
        .tortoiseManagedAppsDaily,
        during: schedule,
        events: [.managedAppsDailyLimit: event]
      )
    } catch {
      lastError = error.localizedDescription
    }
  }

  /// Stage 2 independence fix: applies the OS-level adult web/media content filter
  /// to `immediateStore` driven PURELY by mode (Strict + adult on) — independent of
  /// the YouTube `selection`. Called on the non-enforce branch (where
  /// `clearAllStores()` wiped the filter) so Strict's adult filter holds with no
  /// YouTube target. On the enforce branch `applySelection(...)` already sets it.
  private func reconcileAdultWebFilter() {
    let apply = ManagedAppsShield.shouldApplyAdultFilter(
      mode: enforcementMode, adultEnabled: adultFilterInputEnabled)
    immediateStore.webContent.blockedByFilter = apply ? .auto() : nil
    immediateStore.media.denyExplicitContent = apply ? true : nil
  }

  private func startDailyMonitoring() {
    let schedule = DeviceActivitySchedule(
      intervalStart: DateComponents(hour: 0, minute: 0),
      intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
      repeats: true,
      warningTime: DateComponents(minute: 5)
    )

    let event = DeviceActivityEvent(
      applications: selection.applicationTokens,
      categories: selection.categoryTokens,
      webDomains: selection.webDomainTokens,
      threshold: DateComponents(minute: dailyLimitMinutes)
    )

    do {
      try activityCenter.startMonitoring(
        .tortoiseDaily,
        during: schedule,
        events: [.tortoiseDailyLimit: event]
      )
      scheduleActive = true
    } catch {
      scheduleActive = false
      lastError = error.localizedDescription
    }
  }

  func applyPolicyFeatures(_ features: [String: Bool]) {
    policyFeatures = features
    writeSafariPolicy()
  }

  private func writeSafariPolicy(mode overrideMode: IOSEnforcementMode? = nil) {
    let mode = overrideMode ?? (shieldingEnabled ? enforcementMode : .open)
    var policy = SafariExtensionPolicy.policy(
      for: mode,
      dailyLimitMinutes: dailyLimitMinutes,
      adultWebFilterEnabled: mode == .strict || (mode == .custom && customAdultEnabled)
    )
    if !policyFeatures.isEmpty {
      policy.features = policyFeatures  // real per-feature state (Safari-enforceable only) overrides the mode preset
    }
    IOSEnforcementSharedStore.saveSafariPolicy(policy)
  }

  private func saveSnapshot(lastError: String?) {
    IOSEnforcementSharedStore.saveSelection(selection)
    var snapshot = IOSEnforcementSnapshot(
      mode: enforcementMode,
      authorizationMode: authorizationMode,
      shieldingEnabled: shieldingEnabled,
      dailyLimitMinutes: dailyLimitMinutes,
      adultWebFilterEnabled: ManagedAppsShield.shouldApplyAdultFilter(
        mode: enforcementMode, adultEnabled: adultFilterInputEnabled),
      safariExtensionEnabled: safariExtensionConnected || safariExtensionAcknowledged,
      selectedApplicationCount: selection.applicationTokens.count,
      selectedCategoryCount: selection.categoryTokens.count,
      selectedWebDomainCount: selection.webDomainTokens.count,
      scheduleActive: scheduleActive,
      lastAppliedAt: Date(),
      lastError: lastError
    )
    snapshot.safariExtensionState = safariExtensionState
    snapshot.lastSafariExtensionSeenAt = lastSafariExtensionSeenAt
    snapshot.lastSafariPolicyAppliedAt = lastSafariPolicyAppliedAt
    snapshot.lastSetupCheckAt = lastSetupCheckAt
    snapshot.session = session
    snapshot.managedAppsLimitMinutes = managedAppsLimitMinutes
    if let previousMode = IOSEnforcementSharedStore.loadSnapshot().lastSafariPolicyMode {
      snapshot.lastSafariPolicyMode = previousMode
    }
    IOSEnforcementSharedStore.saveSnapshot(snapshot)
  }

  private func updateStatusMessage() {
    switch authorizationState {
    case .approved where shieldingEnabled && enforcementMode == .strict && enforcementActive:
      statusMessage = "Strict is active. Selected apps/sites are shielded, Safari tuners are on, and the daily limit monitor is running."
    case .approved where shieldingEnabled && enforcementMode == .custom && enforcementActive:
      statusMessage = "Custom is active. Your picked group is blocked on this iPhone."
    case .approved where shieldingEnabled && enforcementActive:
      statusMessage = "Focus is active. Selected apps/sites are shielded and Safari tuners are synced."
    case .approved where enforcementActive:
      statusMessage = "Ready. Turn on iOS enforcement to shield selected apps/sites and sync Safari tuners."
    case .approved:
      statusMessage = "Screen Time is approved. Select apps, categories, youtube.com, and other Safari domains next."
    case .denied:
      statusMessage = authorizationMode == .child
        ? "Child setup is not authorized. Confirm Family Sharing and Screen Time permissions for this child device."
        : "Screen Time permission is not approved for Tortoise."
    case .notDetermined:
      statusMessage = "Choose My iPhone or Child device, then allow Screen Time."
    case .unknown:
      statusMessage = "Screen Time permission status is unavailable."
    }
  }

  private func persistState() {
    IOSEnforcementSharedStore.saveSelection(selection)
    let state = PersistedIOSEnforcementState(
      authorizationMode: authorizationMode,
      enforcementMode: enforcementMode,
      shieldingEnabled: shieldingEnabled,
      dailyLimitMinutes: dailyLimitMinutes,
      managedAppsLimitMinutes: managedAppsLimitMinutes,
      safariExtensionAcknowledged: safariExtensionAcknowledged
    )
    guard let data = try? JSONEncoder().encode(state) else {
      return
    }
    UserDefaults.standard.set(data, forKey: Self.stateKey)
    TortoiseAppGroup.defaults.set(data, forKey: Self.stateKey)
  }

  private static func loadState() -> PersistedIOSEnforcementState {
    let stores = [TortoiseAppGroup.defaults, UserDefaults.standard]
    for store in stores {
      guard let data = store.data(forKey: stateKey),
            let state = try? JSONDecoder().decode(PersistedIOSEnforcementState.self, from: data) else {
        continue
      }
      return state
    }
    return PersistedIOSEnforcementState(
      authorizationMode: .individual,
      enforcementMode: .open,
      shieldingEnabled: false,
      dailyLimitMinutes: 30,
      managedAppsLimitMinutes: nil,
      safariExtensionAcknowledged: false
    )
  }

  private static let stateKey = "TortoiseIOSEnforcementState"
  private static let safariExtensionBundleIdentifier = "com.yourtortoise.Tortoise.SafariExtension"
}

typealias IOSYouTubeScreenTimeController = IOSEnforcementController

enum IOSScreenTimeAuthorizationState: Equatable {
  case notDetermined
  case denied
  case approved
  case unknown

  var isApproved: Bool {
    self == .approved
  }

  var title: String {
    switch self {
    case .notDetermined:
      return "Permission needed"
    case .denied:
      return "Permission blocked"
    case .approved:
      return "Permission approved"
    case .unknown:
      return "Permission unknown"
    }
  }
}

private struct PersistedIOSEnforcementState: Codable {
  let authorizationMode: IOSEnforcementAuthorizationMode
  let enforcementMode: IOSEnforcementMode
  let shieldingEnabled: Bool
  let dailyLimitMinutes: Int
  let managedAppsLimitMinutes: Int?
  let safariExtensionAcknowledged: Bool
}
