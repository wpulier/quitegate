import AppKit
import Combine
import Darwin
import Foundation

enum ChromeTunerLaunchError: LocalizedError, Equatable {
  case chromeMissing
  case chromeStillRunning

  var errorDescription: String? {
    switch self {
    case .chromeMissing:
      return "That browser was not found on this Mac."
    case .chromeStillRunning:
      return "The browser did not quit. Close it, then connect again."
    }
  }
}

@MainActor
protocol BrowserStatusMonitoring: AnyObject {
  func start(
    watchURLsProvider: @escaping () -> [URL],
    onChange: @escaping () -> Void
  )
  func stop()
}

@MainActor
final class NoopBrowserStatusMonitor: BrowserStatusMonitoring {
  func start(
    watchURLsProvider: @escaping () -> [URL],
    onChange: @escaping () -> Void
  ) {}

  func stop() {}
}

@MainActor
final class FileBrowserStatusMonitor: BrowserStatusMonitoring {
  private let debounceInterval: TimeInterval
  private let fileManager: FileManager
  private var watchURLsProvider: (() -> [URL])?
  private var onChange: (() -> Void)?
  private var sources: [String: DispatchSourceFileSystemObject] = [:]
  private var sourceDescriptors: [String: Int32] = [:]
  private var refreshWorkItem: DispatchWorkItem?
  private var activationObserver: NSObjectProtocol?

  init(
    debounceInterval: TimeInterval = 0.25,
    fileManager: FileManager = .default
  ) {
    self.debounceInterval = debounceInterval
    self.fileManager = fileManager
  }

  deinit {
    MainActor.assumeIsolated {
      stop()
    }
  }

  func start(
    watchURLsProvider: @escaping () -> [URL],
    onChange: @escaping () -> Void
  ) {
    stop()
    self.watchURLsProvider = watchURLsProvider
    self.onChange = onChange
    activationObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.refreshNow()
      }
    }
    armWatchers(force: true)
  }

  func stop() {
    refreshWorkItem?.cancel()
    refreshWorkItem = nil
    if let activationObserver {
      NotificationCenter.default.removeObserver(activationObserver)
      self.activationObserver = nil
    }
    for source in sources.values {
      source.cancel()
    }
    sources = [:]
    for descriptor in sourceDescriptors.values {
      close(descriptor)
    }
    sourceDescriptors = [:]
  }

  private func scheduleRefresh() {
    refreshWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      Task { @MainActor in
        self?.refreshNow()
      }
    }
    refreshWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
  }

  private func refreshNow() {
    refreshWorkItem?.cancel()
    refreshWorkItem = nil
    onChange?()
    armWatchers(force: false)
  }

  private func armWatchers(force: Bool) {
    guard let watchURLsProvider else {
      return
    }

    let watchURLs = effectiveWatchURLs(for: watchURLsProvider())
    let paths = Set(watchURLs.map { $0.standardizedFileURL.path })
    if !force, paths == Set(sources.keys) {
      return
    }

    for source in sources.values {
      source.cancel()
    }
    sources = [:]
    for descriptor in sourceDescriptors.values {
      close(descriptor)
    }
    sourceDescriptors = [:]

    for url in watchURLs {
      let path = url.standardizedFileURL.path
      let descriptor = open(path, O_EVTONLY)
      guard descriptor >= 0 else {
        continue
      }
      let source = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: descriptor,
        eventMask: [.write, .extend, .attrib, .link, .rename, .delete],
        queue: DispatchQueue.global(qos: .utility)
      )
      source.setEventHandler { [weak self] in
        Task { @MainActor in
          self?.scheduleRefresh()
        }
      }
      source.setCancelHandler {}
      sources[path] = source
      sourceDescriptors[path] = descriptor
      source.resume()
    }
  }

  private func effectiveWatchURLs(for urls: [URL]) -> [URL] {
    var seen = Set<String>()
    return urls.compactMap { url in
      let effectiveURL = effectiveWatchURL(for: url)
      guard let effectiveURL else {
        return nil
      }
      let path = effectiveURL.standardizedFileURL.path
      guard !seen.contains(path) else {
        return nil
      }
      seen.insert(path)
      return effectiveURL
    }
  }

  private func effectiveWatchURL(for url: URL) -> URL? {
    var isDirectory = ObjCBool(false)
    if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
      return url
    }
    return nil
  }
}

@MainActor
final class ProtectionStore: ObservableObject {
  @Published var profileID: String {
    didSet {
      if profileID.trimmingCharacters(in: .whitespacesAndNewlines)
        != oldValue.trimmingCharacters(in: .whitespacesAndNewlines)
      {
        resolverStatus = nil
        resolverStatusCheckedAt = nil
        parentalControlCheckedAt = nil
        generatedAppleProfileURL = nil
        defaults.removeObject(forKey: DefaultsKey.generatedAppleProfilePath)
        clearLegacyProviderControlVerification()
        clearLegacyProviderRulesReadback()
        clearPendingLegacyProviderRuleRemovals()
      }
    }
  }
  @Published var apiKeyDraft = ""
  @Published var hasAPIKey: Bool
  @Published var accessMode: AccessMode
  @Published var mode: ProtectionMode = .off
  @Published var connectionState: ConnectionState = .notConfigured
  @Published var parentalControl: ParentalControl? {
    didSet {
      parentalControlCheckedAt = parentalControl == nil ? nil : (parentalControlCheckedAt ?? nowProvider())
    }
  }
  @Published var parentalControlCheckedAt: Date?
  @Published private(set) var legacyProviderRules: [LegacyProviderRuleItem] = [] {
    didSet {
      activeLegacyProviderRuleDomainsCache = nil
    }
  }
  @Published var legacyProviderRulesCheckedAt: Date?
  @Published private(set) var domainResolutionStatuses: [String: DomainResolutionStatus] = [:]
  @Published var blockedLogs: [LegacyProviderLogEntry] = []
  @Published var analyticsStatus: [LegacyProviderAnalyticsStatus] = []
  @Published var blockedSites: [BlockedSiteRule]
  @Published var blockCategories: [BlockCategoryRule]
  @Published var customDomainDraft = ""
  @Published var tuningOverrides: [String: Bool]
  @Published var tuningOptions: BrowserTuningOptions
  @Published var resolverStatus: LegacyProviderResolverStatus? {
    didSet {
      resolverStatusCheckedAt = resolverStatus == nil ? nil : (resolverStatusCheckedAt ?? nowProvider())
    }
  }
  @Published var resolverStatusCheckedAt: Date?
  @Published var isWorking = false
  @Published var errorMessage: String?
  @Published var extensionBridgeMessage: String?
  @Published var chromeBridgeInstalled = false
  @Published var chromeBridgeResponding = false
  @Published var chromeHelperState: ChromeHelperState = .notInstalled
  @Published var chromeHelperSnapshot: ChromeHelperSnapshot?
  @Published var chromeExtensionLoaded = false
  @Published var chromeExtensionStatus = ChromeExtensionStatus.empty
  @Published var browserBridgeInstalled: [BrowserConnectorID: Bool] = [:]
  @Published var browserHelperStates: [BrowserConnectorID: ChromeHelperState] = [:]
  @Published var browserHelperSnapshots: [BrowserConnectorID: ChromeHelperSnapshot] = [:]
  @Published var browserExtensionStatuses: [BrowserConnectorID: ChromeExtensionStatus] = [:]
  @Published var browserProfileWatchMessage: String?
  @Published var browserProfileWatchBrowser: BrowserConnectorID?
  @Published var builtInProtectionsSnapshot: BuiltInProtectionsSnapshot = .empty
  @Published private(set) var appUpdateInfo: AppUpdateInfo?
  @Published var macOSLegacyProviderProfileInstalled = false
  @Published var macOSConfiguredLegacyProviderProfileInstalled = false
  @Published var legacyProviderRulesSyncPending: Bool
  @Published var legacyProviderVerifiedProfileID: String?
  @Published var legacyProviderKeyNeedsPermission = false
  @Published var setupMessage: String?
  @Published var generatedAppleProfileURL: URL?
  @Published var generatedHostsScriptURL: URL?
  @Published var localHostsFallbackInstalled = false
  @Published var timedSessionEndDate: Date?
  @Published var timedSessionMode: AccessMode?
  @Published var timedSessionLocked: Bool
  @Published var focusWindows: [FocusWindow]
  @Published var focusWindowScheduleEnabled: Bool
  @Published var lastBlockingTransaction: BlockingControlTransactionState = .idle
  @Published private(set) var blockingControlTransactions: [String: BlockingControlTransactionState] =
    [:]

  private let defaults: UserDefaults
  private let keychain: SecretStoring
  private let makeClient: (String) -> LegacyProviderServicing
  private let resolverService: ResolverStatusChecking
  private let extensionBridge: BrowserExtensionBridging
  private let appUpdateService: AppUpdateServicing
  private let systemProfileChecker: SystemProfileChecking
  private let appleProfileGenerator: LegacyProviderProfileGenerating
  private let localHostsScriptGenerator: LocalHostsBlockerScriptGenerating
  private let domainResolver: DomainResolutionChecking
  private let platformControlsChecker: PlatformControlsChecking
  private let browserInstallationChecker: (BrowserConnectorID) -> Bool
  private let browserRunningChecker: (BrowserConnectorID) -> Bool
  private let browserStatusMonitor: BrowserStatusMonitoring
  private let nowProvider: () -> Date
  let legacyProviderConnectorEnabled: Bool
  private var timedSessionTimer: Timer?
  private var focusWindowTimer: Timer?
  private var browserProfilePollTask: Task<Void, Never>?
  private var browserSettingsAutoApplyTask: Task<Void, Never>?
  private var builtInProtectionsRefreshTask: Task<BuiltInProtectionsSnapshot, Never>?
  private var browserProfileWatchSession: BrowserProfileWatchSession?
  private var launchedBrowserSessionProfiles: [BrowserConnectorID: String] = [:]
  private var activeFocusWindowID: UUID?
  private var suppressedFocusWindowID: UUID?
  private var cachedAPIKey: String?
  private var categoryPreferencesHaveBeenSaved: Bool
  private var pendingLegacyProviderRuleRemovals: Set<String>
  private var activeLegacyProviderRuleDomainsCache: Set<String>?
  private static let blockingReadbackFreshnessInterval: TimeInterval = 60
  private static let browserProfileWatchTimeout: TimeInterval = 90
  private static let browserProfilePollInterval: UInt64 = 750_000_000

  private struct BrowserProfileDetectionSnapshot: Equatable {
    let selectedProfileLabel: String?
    let connectedProfileLabels: [String]
    let helperState: ChromeHelperState

    init(
      selectedProfileLabel: String?,
      connectedProfileLabels: [String],
      helperState: ChromeHelperState
    ) {
      self.selectedProfileLabel = selectedProfileLabel
      self.connectedProfileLabels = connectedProfileLabels
      self.helperState = helperState
    }
  }

  private struct BrowserProfileWatchSession {
    let browser: BrowserConnectorID
    let baseline: BrowserProfileDetectionSnapshot
    let deadline: Date
  }

  private enum DefaultsKey {
    static let profileID = "quietgate.profileID"
    static let accessMode = "quietgate.accessMode"
    static let baseline = "quietgate.parentalControlBaseline"
    static let customDomains = "quietgate.customDomains"
    static let blockedSites = "quietgate.blockedSites"
    static let blockCategories = "quietgate.blockCategories"
    static let pendingLegacyProviderRuleRemovals = "quietgate.pendingLegacyProviderRuleRemovals"
    static let legacyProviderRulesSyncPending = "quietgate.legacyProviderRulesSyncPending"
    static let legacyProviderVerifiedProfileID = "quietgate.legacyProviderVerifiedProfileID"
    static let legacyProviderConnectorEnabled = "quietgate.legacyProviderConnectorEnabled"
    static let legacyProviderConnectorEnabledDeprecated = "quietgate.legacyProviderConnectorEnabledDeprecated"
    static let legacyProviderRuntimeEnabled = "quietgate.enableLegacyProviderRuntime"
    static let localHostsFallbackFingerprint = "quietgate.localHostsFallbackFingerprint"
    static let tuningOverrides = "quietgate.tuningOverrides"
    static let tuningOptions = "quietgate.tuningOptions"
    static let generatedAppleProfilePath = "quietgate.generatedAppleProfilePath"
    static let generatedHostsScriptPath = "quietgate.generatedHostsScriptPath"
    static let browserSettingsVersion = "quietgate.browserSettingsVersion"
    static let timedSessionEndDate = "quietgate.timedSessionEndDate"
    static let timedSessionMode = "quietgate.timedSessionMode"
    static let timedSessionLocked = "quietgate.timedSessionLocked"
    static let focusWindows = "quietgate.focusWindows"
    static let focusWindowScheduleEnabled = "quietgate.focusWindowScheduleEnabled"
    static let activeFocusWindowID = "quietgate.activeFocusWindowID"
    static let suppressedFocusWindowID = "quietgate.suppressedFocusWindowID"
  }

  static func disableLegacyProviderConnector(in defaults: UserDefaults = .standard) {
    defaults.set(false, forKey: DefaultsKey.legacyProviderConnectorEnabled)
    defaults.set(false, forKey: DefaultsKey.legacyProviderConnectorEnabledDeprecated)
    defaults.set(false, forKey: DefaultsKey.legacyProviderRulesSyncPending)
    defaults.removeObject(forKey: DefaultsKey.pendingLegacyProviderRuleRemovals)
    defaults.removeObject(forKey: DefaultsKey.profileID)
    defaults.removeObject(forKey: DefaultsKey.legacyProviderVerifiedProfileID)
    defaults.removeObject(forKey: DefaultsKey.generatedAppleProfilePath)
    defaults.removeObject(forKey: DefaultsKey.legacyProviderRuntimeEnabled)
  }

  init(
    defaults: UserDefaults = .standard,
    keychain: SecretStoring = KeychainStore(),
    makeClient: @escaping (String) -> LegacyProviderServicing = { _ in DisabledLegacyProviderService() },
    resolverService: ResolverStatusChecking = DisabledResolverStatusService(),
    extensionBridge: BrowserExtensionBridging = BrowserExtensionBridge(),
    appUpdateService: AppUpdateServicing = AppUpdateService(),
    systemProfileChecker: SystemProfileChecking = DisabledSystemProfileChecker(),
    appleProfileGenerator: LegacyProviderProfileGenerating = DisabledLegacyProviderProfileGenerator(),
    localHostsScriptGenerator: LocalHostsBlockerScriptGenerating =
      DisabledLocalHostsScriptGenerator(),
    domainResolver: DomainResolutionChecking = SystemDomainResolver(),
    platformControlsChecker: PlatformControlsChecking = PlatformControlsChecker(),
    browserInstallationChecker: @escaping (BrowserConnectorID) -> Bool = { $0.isInstalled() },
    browserRunningChecker: ((BrowserConnectorID) -> Bool)? = nil,
    browserStatusMonitor: BrowserStatusMonitoring? = nil,
    nowProvider: @escaping () -> Date = Date.init
  ) {
    self.defaults = defaults
    self.keychain = keychain
    self.makeClient = makeClient
    self.resolverService = resolverService
    self.extensionBridge = extensionBridge
    self.appUpdateService = appUpdateService
    self.systemProfileChecker = systemProfileChecker
    self.appleProfileGenerator = appleProfileGenerator
    self.localHostsScriptGenerator = localHostsScriptGenerator
    self.domainResolver = domainResolver
    self.platformControlsChecker = platformControlsChecker
    self.browserInstallationChecker = browserInstallationChecker
    self.browserRunningChecker = browserRunningChecker ?? Self.browserIsRunning
    if let browserStatusMonitor {
      self.browserStatusMonitor = browserStatusMonitor
    } else if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
      self.browserStatusMonitor = NoopBrowserStatusMonitor()
    } else {
      self.browserStatusMonitor = FileBrowserStatusMonitor()
    }
    self.nowProvider = nowProvider
    #if DEBUG
    legacyProviderConnectorEnabled = defaults.bool(forKey: DefaultsKey.legacyProviderConnectorEnabled)
    #else
    legacyProviderConnectorEnabled = false
    #endif
    categoryPreferencesHaveBeenSaved = defaults.array(forKey: DefaultsKey.blockCategories) != nil
    profileID = legacyProviderConnectorEnabled ? (defaults.string(forKey: DefaultsKey.profileID) ?? "") : ""
    accessMode =
      AccessMode(rawValue: defaults.string(forKey: DefaultsKey.accessMode) ?? "") ?? .open
    blockedSites = Self.loadBlockedSites(from: defaults)
    blockCategories = []
    pendingLegacyProviderRuleRemovals = legacyProviderConnectorEnabled
      ? Self.loadPendingLegacyProviderRuleRemovals(from: defaults)
      : []
    tuningOverrides = Self.loadTuningOverrides(from: defaults)
    tuningOptions = Self.loadTuningOptions(from: defaults)
    generatedAppleProfileURL = legacyProviderConnectorEnabled
      ? Self.loadExistingFileURL(from: defaults, key: DefaultsKey.generatedAppleProfilePath)
      : nil
    generatedHostsScriptURL = Self.loadExistingFileURL(
      from: defaults, key: DefaultsKey.generatedHostsScriptPath)
    focusWindows = Self.loadFocusWindows(from: defaults)
    focusWindowScheduleEnabled =
      defaults.object(forKey: DefaultsKey.focusWindowScheduleEnabled) as? Bool ?? true
    activeFocusWindowID = Self.loadUUID(from: defaults, key: DefaultsKey.activeFocusWindowID)
    suppressedFocusWindowID = Self.loadUUID(
      from: defaults, key: DefaultsKey.suppressedFocusWindowID)
    if legacyProviderConnectorEnabled {
      do {
        cachedAPIKey = try keychain.readSecret(allowUserInteraction: false)
        legacyProviderKeyNeedsPermission = false
      } catch KeychainError.unavailableWithoutUserInteraction {
        cachedAPIKey = nil
        legacyProviderKeyNeedsPermission = true
      } catch {
        cachedAPIKey = nil
        legacyProviderKeyNeedsPermission = false
      }
    } else {
      cachedAPIKey = nil
      legacyProviderKeyNeedsPermission = false
    }
    hasAPIKey = legacyProviderConnectorEnabled && (cachedAPIKey != nil || keychain.hasSecret())
    legacyProviderRulesSyncPending =
      legacyProviderConnectorEnabled
      && (defaults.bool(forKey: DefaultsKey.legacyProviderRulesSyncPending)
        || !pendingLegacyProviderRuleRemovals.isEmpty)
    legacyProviderVerifiedProfileID = legacyProviderConnectorEnabled
      ? defaults.string(forKey: DefaultsKey.legacyProviderVerifiedProfileID)
      : nil
    timedSessionEndDate = defaults.object(forKey: DefaultsKey.timedSessionEndDate) as? Date
    timedSessionMode = AccessMode(
      rawValue: defaults.string(forKey: DefaultsKey.timedSessionMode) ?? "")
    timedSessionLocked = defaults.object(forKey: DefaultsKey.timedSessionLocked) as? Bool ?? false
    if let timedSessionEndDate, let timedSessionMode, timedSessionMode != .open {
      if timedSessionEndDate > nowProvider() {
        accessMode = timedSessionMode
      } else {
        self.timedSessionEndDate = nil
        self.timedSessionMode = nil
        timedSessionLocked = false
        accessMode = .open
        defaults.removeObject(forKey: DefaultsKey.timedSessionEndDate)
        defaults.removeObject(forKey: DefaultsKey.timedSessionMode)
        defaults.removeObject(forKey: DefaultsKey.timedSessionLocked)
        defaults.set(AccessMode.open.rawValue, forKey: DefaultsKey.accessMode)
        defaults.removeObject(forKey: DefaultsKey.browserSettingsVersion)
      }
    } else if timedSessionLocked {
      timedSessionLocked = false
      defaults.removeObject(forKey: DefaultsKey.timedSessionLocked)
    }
    blockCategories = Self.loadBlockCategories(from: defaults, accessMode: accessMode)
    if legacyProviderConnectorEnabled {
      restoreUnconfirmedDenylistRemovals()
    } else {
      clearPendingLegacyProviderRuleRemovals()
    }
    if legacyProviderConnectorEnabled && hasActiveBlockRules {
      setLegacyProviderRulesSyncPending(true)
    }
    connectionState =
      legacyProviderConnectorEnabled
      ? (profileID.isEmpty || !hasAPIKey ? .notConfigured : .checking)
      : .connected
    localHostsFallbackInstalled = localHostsScriptGenerator.localHostsBlocklistInstalled()
    syncBrowserExtensionSettingsIfNeeded(refreshStatus: false, announce: false)
    refreshChromeExtensionStatus()
    startBrowserStatusMonitoring()
    scheduleTimedSessionTimer()
    startFocusWindowMonitoring()
  }

  deinit {
    browserProfilePollTask?.cancel()
    browserSettingsAutoApplyTask?.cancel()
    Task { @MainActor [browserStatusMonitor] in
      browserStatusMonitor.stop()
    }
  }

  var configured: Bool {
    !profileID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasAPIKey
  }

  var trimmedProfileID: String {
    profileID.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var customDomains: [String] {
    get {
      blockedSites.map(\.domain)
    }
    set {
      blockedSites = Self.blockedSiteRules(from: newValue)
      blockedSites.forEach { removePendingLegacyProviderRuleRemoval($0.domain) }
      persistBlockedSites()
      setLegacyProviderRulesSyncPending(legacyProviderRulesNeedsSync())
      syncBrowserExtensionSettings()
    }
  }

  var blockedQueryCount: Int {
    analyticsStatus.first { $0.status == "blocked" }?.queries ?? 0
  }

  var accessModeStatusSummary: String {
    if timedSessionActive {
      return timedSessionStatusLine
    }
    if accessMode.protectionEnabled && !adultContentBlockingEnabled {
      return "\(accessMode.title) tuning is active. Adult Content is off in Blocked Sites."
    }
    if !legacyProviderConnectorEnabled {
      if accessMode == .open && tunerEnabled {
        return "Browser cleanup is customized. Website blocking is off."
      }
      if hasActiveBlockRules {
        return browserBlockingConnected
          ? "Blocks are active in connected browsers."
          : "Blocks are saved. Connect a browser to apply them."
      }
      return accessMode.summary
    }
    if !configured && hasActiveBlockRules {
      return "Blocks are saved. Connect QuietGate to make them active on this Mac."
    }
    if accessMode == .open && tunerEnabled {
      return "Blocker is off. Browser tuning is customized."
    }
    if !configured && accessMode.protectionEnabled {
      return "Focus mode is selected. Connect QuietGate to make blocking active on this Mac."
    }
    if (hasActiveBlockRules || accessMode.protectionEnabled) && !systemBlockingCapabilityFresh {
      return "Blocking settings are saved. QuietGate needs a fresh connection check before it can promise they work."
    }
    if blockerProfileEnabled && !legacyMacConnectionReady {
      if resolverStatus == nil {
        return "Blocking is on. Check the connection to verify it applies on this Mac."
      }
      if legacyMacConnectionProfileMismatch {
        return "This Mac is using a different blocking setup than the one QuietGate updates."
      }
      if legacyMacConnectionUsesProvider {
        return "A blocking setup is active, but QuietGate cannot confirm it belongs to QuietGate."
      }
      return "Blocking is on, but this Mac has not approved QuietGate yet."
    }
    if !tuningOverrides.isEmpty {
      return "\(accessMode.summary) Browser tuning is customized."
    }
    return accessMode.summary
  }

  var settingsStatusSummary: String {
    if !legacyProviderConnectorEnabled {
      return browserBlockingConnected
        ? "QuietGate is ready. \(connectedBrowserProfileScopeText ?? connectedBrowserNames.joined(separator: ", ")) connected for browser blocking and tuning."
        : "Connect a browser to finish setup for browser blocking and site tuning."
    }
    if legacyProviderHardBlockReady {
      return "QuietGate is connected and verified on this Mac."
    }
    if configured && !legacyProviderControlConnected {
      return "Account details are saved. Check access before relying on blocking."
    }
    if configured {
      return "Account details are saved. Allow this Mac before relying on blocking."
    }
    if hasAPIKey || !profileID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return "Finish the account details to enable blocking."
    }
    return "Connect QuietGate before relying on blocking."
  }

  var currentModeTitle: String {
    if accessMode == .open && tunerEnabled {
      return "Tuned"
    }
    if !tuningOverrides.isEmpty {
      return "\(accessMode.title) Tuned"
    }
    return accessMode.title
  }

  var currentModeSystemImage: String {
    if accessMode == .open && tunerEnabled {
      return "slider.horizontal.3"
    }
    return accessMode.systemImage
  }

  var compactStatusLine: String {
    if isWorking {
      return "Working"
    }
    if timedSessionActive {
      return timedSessionStatusLine
    }
    if !legacyProviderConnectorEnabled {
      if hasActiveBlockRules {
        return browserBlockingConnected
          ? "Browser blocks active"
          : "Connect a browser for blocks"
      }
      if accessMode == .open && tunerEnabled {
        return "Browser cleanup customized"
      }
      return "Ready"
    }
    if !configured && hasActiveBlockRules {
      return "Blocks saved; connection needed"
    }
    if accessMode == .open && tunerEnabled {
      return "Browser tuning on; blocker off"
    }
    if !configured && accessMode.protectionEnabled {
      return "Blocker needs connection"
    }
    if configured && !legacyProviderControlConnected && (hasActiveBlockRules || accessMode.protectionEnabled) {
      return connectionState == .checking ? "Checking account access" : "Account access needed"
    }
    if blockerProfileEnabled {
      if systemBlockingCapabilityFresh {
        return "Blocker verified on this Mac"
      }
      if legacyMacConnectionReady {
        return "Blocker needs fresh check"
      }
      if legacyMacConnectionProfileMismatch {
        return "Different Mac permission"
      }
      if legacyMacConnectionUsesProvider {
        return "Mac permission not confirmed"
      }
      if let resolverStatus {
        return "Mac connection status: \(resolverStatus.status)"
      }
      return "Blocking on; check connection"
    }
    if let resolverStatus {
      return "Connection status: \(resolverStatus.status)"
    }
    return connectionState.title
  }

  var blockerStatusLabel: String {
    if !legacyProviderConnectorEnabled {
      if hasActiveBlockRules {
        return browserBlockingConnected ? "On" : "Connect"
      }
      return "Off"
    }
    if !configured {
      return "Connect"
    }
    guard blockerProfileEnabled else {
      if hasActiveBlockRules || accessMode.protectionEnabled {
        return legacyProviderControlConnected ? "Verify" : "Connect"
      }
      return "Off"
    }
    if systemBlockingCapabilityFresh {
      return "On"
    }
    if legacyMacConnectionReady {
      return "Check"
    }
    return resolverStatus == nil ? "Verify" : "Connect"
  }

  var blockerStatusDetail: String {
    if !legacyProviderConnectorEnabled {
      if hasActiveBlockRules {
        return browserBlockingConnected
          ? "QuietGate browser rules are current in connected browsers."
          : "QuietGate saved these rules. Connect a browser to apply them."
      }
      return "QuietGate website blocking is off."
    }
    if !configured {
      return "Connect the account and allow this Mac before categories and sites can block."
    }
    guard blockerProfileEnabled else {
      if !legacyProviderControlConnected && (hasActiveBlockRules || accessMode.protectionEnabled) {
        return
          "Account details are saved, but QuietGate has not verified access yet."
      }
      return "QuietGate blocking is off."
    }
    if systemBlockingCapabilityFresh {
      if mode == .on {
        return accessMode.blockerSummary
      }
      return "Enabled individual site rules are active on this Mac."
    }
    if legacyMacConnectionReady {
      return "QuietGate needs a fresh readback before it can promise blocking is active."
    }
    if legacyMacConnectionProfileMismatch {
      return
        "This Mac is using a different blocking setup than the one QuietGate updates. Finish Mac approval in Setup."
    }
    if legacyMacConnectionUsesProvider {
      return
        "This Mac is using another blocking setup, so QuietGate's rules may not apply. Finish Mac approval in Setup."
    }
    if let resolverStatus {
      return
        "This Mac reports \(resolverStatus.status). Finish Mac approval in Setup before relying on blocking."
    }
    if mode == .on {
      return "Rules are on. QuietGate is updating setup status before it promises blocking applies on this Mac."
    }
    return
      "Enabled individual site rules are saved. QuietGate is updating setup status before it promises blocking applies on this Mac."
  }

  var blockerProfileEnabled: Bool {
    legacyProviderControlConnected && (mode == .on || !enabledBlockedSites.isEmpty)
  }

  var systemBlockingCapabilityFresh: Bool {
    if !legacyProviderConnectorEnabled {
      return browserBlockingConnected
    }
    return legacyProviderHardBlockReady
      && freshLegacyProviderControlReadback
      && freshLegacyProviderRulesReadback
      && freshMacConnectionReadback
  }

  var blockingControlsReady: Bool {
    systemBlockingCapabilityFresh
  }

  var blockingCapabilityUnavailableReason: String? {
    guard !blockingControlsReady else {
      return nil
    }
    if isWorking {
      return "QuietGate is updating setup status."
    }
    if !legacyProviderConnectorEnabled {
      if firstInstalledSupportedBrowserConnector == nil {
        return "Install Chrome, Edge, Brave, Arc, or Firefox before using Home controls."
      }
      let browser = primaryBrowserConnector
      if let selectedProfile = browser.selectedProfileLabel {
        return "Finish the \(browser.displayName) connection for \(selectedProfile) before using Home controls."
      }
      if !browser.connectedProfileLabels.isEmpty {
        return "Finish the \(browser.displayName) connection for \(Self.formattedList(browser.connectedProfileLabels)) before using Home controls."
      }
      return "Connect \(browser.displayName) before using Home controls."
    }
    if !configured {
      return "Finish setup before using blocking controls."
    }
    if legacyProviderKeyNeedsPermission {
      return "Allow QuietGate to read the saved setup key before using blocking controls."
    }
    if !legacyProviderControlConnected {
      return "Finish setup before using blocking controls."
    }
    if !legacyMacConnectionReady {
      return "Finish Mac approval in Setup before using blocking controls."
    }
    if legacyProviderRulesSyncPending {
      return "QuietGate is applying saved changes. Controls unlock when it finishes."
    }
    if !freshLegacyProviderControlReadback || !freshLegacyProviderRulesReadback || !freshMacConnectionReadback {
      return "QuietGate is updating setup status. Controls unlock when it confirms setup is still working."
    }
    return "Finish setup before using blocking controls."
  }

  var blockingCapabilitySnapshot: BlockingCapabilitySnapshot {
    let state: BlockingCapabilityState
    if isWorking {
      state = .checking
    } else if blockingControlsReady {
      state = .ready
    } else {
      state = .disabled(blockingCapabilityUnavailableReason ?? "Finish setup before using blocking controls.")
    }
    let provider = defaultBlockingProvider
    return BlockingCapabilitySnapshot(
      state: state,
      providerID: provider.id,
      providerTitle: provider.title,
      providerDetail: provider.state.detail,
      checkedAt: blockingCapabilityCheckedAt,
      browserHelperState: chromeHelperState,
      lastTransaction: lastBlockingTransaction
    )
  }

  private var blockingCapabilityCheckedAt: Date? {
    if legacyProviderConnectorEnabled {
      let legacyReadbacks = [
        parentalControlCheckedAt,
        legacyProviderRulesCheckedAt,
        resolverStatusCheckedAt,
      ].compactMap { $0 }
      return legacyReadbacks.count == 3 ? legacyReadbacks.min() : nil
    }
    return connectedBrowserConnectors.compactMap(\.lastSeenAt).max()
  }

  var websiteBlockingReady: Bool {
    systemBlockingCapabilityFresh
  }

  var blockerVisualEnabled: Bool {
    hasActiveBlockRules
      && (!legacyProviderConnectorEnabled
        ? browserBlockingConnected
        : (blockerProfileEnabled && systemBlockingCapabilityFresh))
  }

  var blockerVisualNeedsAttention: Bool {
    hasActiveBlockRules && !websiteBlockingReady
  }

  var blockerVisualSystemImage: String {
    if blockerVisualEnabled {
      return ProtectionMode.on.systemImage
    }
    if blockerVisualNeedsAttention {
      return "exclamationmark.shield"
    }
    return ProtectionMode.off.systemImage
  }

  var tunerStatusLabel: String {
    guard tunerEnabled else {
      return "Off"
    }
    return browserBlockingConnected ? "Connected" : "Not connected"
  }

  var diagnosticStatusText: String {
    let readinessLines = readinessChecks.map { check in
      "- \(check.title): \(check.state.title) - \(check.detail)"
    }
    let tuning = effectiveTuningFeatures.map(\.title).joined(separator: ", ")

    var lines = [
      "QuietGate Status",
      "Mode: \(currentModeTitle)",
      "Timed session: \(timedSessionActive ? timedSessionStatusLine : "off")",
      "Timed session locked: \(timedSessionLockedActive ? "yes" : "no")",
      "Focus windows: \(focusWindowScheduleEnabled ? "enabled" : "paused") - \(focusWindowScheduleStatusLine)",
      "Focus window count: \(focusWindows.count)",
      "Blocker: \(blockerStatusLabel)",
      "Blocker detail: \(blockerStatusDetail)",
      "Browser connection: \(tunerStatusLabel)",
      "Default blocking provider: \(defaultBlockingProvider.title)",
      "Website controls ready: \(websiteBlockingReady ? "yes" : "no")",
      "Blocking controls ready: \(blockingControlsReady ? "yes" : "no")",
      "Blocking controls reason: \(blockingCapabilityUnavailableReason ?? "ready")",
      "Connection: \(connectionState.title) - \(connectionState.detail)",
      "Readiness: \(readinessSummary)",
      readinessLines.joined(separator: "\n"),
      "Browser tuning: \(tuning.isEmpty ? "off" : tuning)",
      "Enabled categories: \(enabledBlockCategoryTitles)",
      "Disabled categories: \(disabledBlockCategoryTitles)",
      "Enabled sites: \(enabledIndividualBlockedDomains.isEmpty ? "none" : enabledIndividualBlockedDomains.joined(separator: ", "))",
      "Disabled sites: \(disabledIndividualBlockedDomains.isEmpty ? "none" : disabledIndividualBlockedDomains.joined(separator: ", "))",
      "Active blocked domains: \(activeBlockedDomainCount)",
      "Last blocking transaction: \(lastBlockingTransaction.message ?? "none")",
      "Saved blocked site rows: \(blockedSites.count)",
      "Browser rule count: \(chromeFallbackBlockedDomains.count)",
      "Primary browser status: \(chromeCoverageStatus)",
      adultProtectionDiagnosticText,
      "Primary browser extension loaded: \(chromeExtensionLoaded ? "yes" : "no")",
      "Primary browser current profile: \(chromeExtensionStatus.selectedProfileLabel ?? chromeExtensionStatus.selectedProfile ?? "unknown")",
      "Primary browser profiles found: \(chromeExtensionStatus.profileCount)",
      "Primary browser profiles with QuietGate: \(chromeExtensionStatus.loadedProfileLabels.isEmpty ? "none" : chromeExtensionStatus.loadedProfileLabels.joined(separator: ", "))",
      "Primary browser automatic updates installed: \(chromeBridgeInstalled ? "yes" : "no")",
      "Primary browser automatic updates connected: \(chromeBridgeResponding ? "yes" : "no")",
      "Extension settings: \(extensionSettingsURL.path)",
      "Browser extension folder: \(chromeExtensionDirectoryURL.path)",
      "Native host manifest: \(nativeMessagingManifestURL.path)",
    ]

    if legacyProviderConnectorEnabled {
      lines.append(contentsOf: [
        "Advanced blocking connector: on",
        "Advanced blocking configured: \(configured ? "yes" : "no")",
        "Advanced blocking controls connected: \(legacyProviderControlConnected ? "yes" : "no")",
        "macOS advanced blocking profile installed: \(macOSLegacyProviderProfileInstalled ? "yes" : "no")",
        "macOS configured advanced blocking profile installed: \(macOSConfiguredLegacyProviderProfileInstalled ? "yes" : "no")",
        "Advanced blocking profile detected: \(legacyMacConnectionProfileDetected ? "yes" : "no")",
        "Advanced blocking profile matches QuietGate: \(legacyMacConnectionProfileMatchesConfiguredProfile ? "yes" : "no")",
        "Advanced blocking rules checked: \(legacyProviderRulesCheckedAt?.description ?? "never")",
        "Advanced parental controls checked: \(parentalControlCheckedAt?.description ?? "never")",
        "Mac connection checked: \(resolverStatusCheckedAt?.description ?? "never")",
        "Advanced Mac setup URL: \(legacyProviderMacSetupURL.absoluteString)",
        "Generated Mac connection profile: \(generatedAppleProfileURL?.path ?? "none")",
        "Verified active blocked domains: \(verifiedActiveBlockedDomainCount)",
      ])

      lines.append(contentsOf: [
        "Legacy backup blocks: \(localHostsFallbackDomains.count)",
        "Legacy backup installed: \(localHostsFallbackConnected ? "yes" : "no")",
        "Legacy backup current: \(localHostsFallbackSynced ? "yes" : "no")",
        "Legacy backup maintenance needed: \(localHostsFallbackMaintenanceNeeded ? "yes" : "no")",
        "Local hosts script: \(generatedHostsScriptURL?.path ?? "none")",
      ])
    }

    return (lines + optionalDiagnosticLines).joined(separator: "\n")
  }

  private var optionalDiagnosticLines: [String] {
    var lines: [String] = []
    if let resolverStatus {
      lines.append("Resolver status: \(resolverStatus.status)")
    }
    if let errorMessage {
      lines.append("Last error: \(errorMessage)")
    }
    return lines
  }

  private var adultProtectionDiagnosticText: String {
    let snapshot = browserHelperSnapshots[primaryBrowserConnector.id] ?? chromeHelperSnapshot
    guard let health = snapshot?.adultProtection else {
      return "Adult protection health: unknown"
    }

    let rulesets = health.staticRulesetsEnabled.isEmpty
      ? "none"
      : health.staticRulesetsEnabled.joined(separator: ", ")
    let scripts = health.scriptVersions?
      .sorted { $0.key < $1.key }
      .map { "\($0.key)=\($0.value)" }
      .joined(separator: ", ") ?? "unknown"
    let canaries = health.canaryDomains.isEmpty ? "none" : health.canaryDomains.joined(separator: ", ")
    return
      "Adult protection health: \(health.enabled ? "on" : "off"); domains: \(health.domainListCount); seeds: \(health.seedDomainCount); dynamic rules: \(health.dynamicRuleCount); static rulesets: \(rulesets); scripts: \(scripts); canaries: \(canaries)"
  }

  private var enabledBlockCategoryTitles: String {
    let titles = enabledBlockCategories.map { $0.id.title }
    return titles.isEmpty ? "none" : titles.joined(separator: ", ")
  }

  private var disabledBlockCategoryTitles: String {
    let titles = disabledBlockCategories.map { $0.id.title }
    return titles.isEmpty ? "none" : titles.joined(separator: ", ")
  }

  var effectiveTuningFeatures: [BrowserTuningFeature] {
    browserBlockingProviderModel.effectiveTuningFeatures
  }

  var tunerEnabled: Bool {
    browserBlockingProviderModel.tunerEnabled
  }

  var effectiveTuningFeatureMap: [String: Bool] {
    browserBlockingProviderModel.effectiveTuningFeatureMap
  }

  var currentBrowserTuningSettings: BrowserTuningSettings {
    if legacyProviderConnectorEnabled {
      return browserBlockingProviderModel.settings.withBlockedDomains(browserHelperBlockedDomains)
    }
    return browserBlockingProviderModel.settings
  }

  var currentBrowserSettingsVersion: String {
    currentBrowserTuningSettings.settingsVersion
  }

  private var supportedBrowserIDs: [BrowserConnectorID] {
    BrowserConnectorID.allCases.filter(\.isSupportedToday)
  }

  var supportedBrowserConnectors: [BrowserConnectorSnapshot] {
    browserConnectors.filter { $0.support == .supportedToday }
  }

  var connectedBrowserConnectors: [BrowserConnectorSnapshot] {
    let connected = supportedBrowserConnectors.filter(\.isConnected)
    return legacyProviderConnectorEnabled
      ? connected.filter(\.isCurrent)
      : connected
  }

  var browserBlockingConnected: Bool {
    !connectedBrowserConnectors.isEmpty
  }

  private var connectedBrowserNames: [String] {
    connectedBrowserConnectors.map(\.displayName)
  }

  private var connectedBrowserProfileScopes: [String] {
    connectedBrowserConnectors.map { connector in
      connector.profileScopeText ?? connector.displayName
    }
  }

  var connectedBrowserProfileScopeText: String? {
    guard !connectedBrowserProfileScopes.isEmpty else {
      return nil
    }
    return Self.formattedList(connectedBrowserProfileScopes)
  }

  var browserRuleProfileScopeDetail: String? {
    guard !legacyProviderConnectorEnabled,
          browserBlockingConnected,
          let scopeText = connectedBrowserProfileScopeText else {
      return nil
    }
    return "Website blocks and site tuning apply in \(scopeText). Other browser profiles need their own QuietGate connection."
  }

  private var firstInstalledSupportedBrowserConnector: BrowserConnectorSnapshot? {
    supportedBrowserConnectors.first { $0.isInstalled }
  }

  var browserConnectors: [BrowserConnectorSnapshot] {
    BrowserConnectorID.allCases.map { browserConnector(for: $0) }
  }

  var primaryBrowserConnector: BrowserConnectorSnapshot {
    connectedBrowserConnectors.first
      ?? firstInstalledSupportedBrowserConnector
      ?? browserConnector(for: .chrome)
  }

  var browserSettingsApplyNeeded: Bool {
    guard !legacyProviderConnectorEnabled else {
      return false
    }
    let browser = primaryBrowserConnector
    return browser.isConnected && !browser.isCurrent
  }

  var browserSettingsApplyTitle: String {
    browserRunningChecker(primaryBrowserConnector.id) ? "Refresh Browser" : "Apply Now"
  }

  var browserSettingsApplyDetail: String {
    let browser = primaryBrowserConnector
    if browserRunningChecker(browser.id) {
      return "QuietGate is trying to update \(browser.displayName). Use this if the browser has not refreshed yet."
    }
    return "QuietGate saved new settings. They will apply next time \(browser.displayName) opens."
  }

  var appUpdateAvailable: Bool {
    appUpdateInfo != nil
  }

  var appUpdateDetail: String {
    appUpdateInfo?.detailText ?? "QuietGate is up to date."
  }

  var blockingProviders: [BlockingProviderSnapshot] {
    if legacyProviderConnectorEnabled {
      return BlockingProviderCatalog.legacy(
        dns: legacyBlockingProvider,
        browser: browserBlockingProvider
      )
      .providers
    }
    return [browserBlockingProvider]
  }

  func blockingProviders(
    includingLocalMac localMacProvider: BlockingProviderSnapshot
  ) -> [BlockingProviderSnapshot] {
    if legacyProviderConnectorEnabled {
      return BlockingProviderCatalog.legacy(
        dns: legacyBlockingProvider,
        browser: browserBlockingProvider,
        localMac: localMacProvider
      )
      .providers
    }
    return BlockingProviderCatalog.browserFirst(
      browser: browserBlockingProvider,
      localMac: localMacProvider
    )
    .providers
  }

  var defaultBlockingProvider: BlockingProviderSnapshot {
    BlockingProviderCatalog(providers: blockingProviders).defaultProvider ?? browserBlockingProvider
  }

  var systemBlockState: SystemBlockState {
    if !legacyProviderConnectorEnabled {
      if browserBlockingConnected {
        return hasActiveBlockRules ? .active : .notReady
      }
      return hasActiveBlockRules ? .savedNeedsSync : .notReady
    }
    if systemBlockingCapabilityFresh {
      return .active
    }
    if hasActiveBlockRules || legacyProviderRulesSyncPending {
      return .savedNeedsSync
    }
    return .notReady
  }

  var adultContentCategoryRule: BlockCategoryRule {
    blockCategoryRule(.adultContent)
  }

  var adultContentBlockingEnabled: Bool {
    adultContentCategoryRule.isEnabled
  }

  var enabledBlockCategories: [BlockCategoryRule] {
    blockCategories.filter(\.isEnabled)
  }

  var disabledBlockCategories: [BlockCategoryRule] {
    blockCategories.filter { !$0.isEnabled }
  }

  var enabledBlockedSites: [BlockedSiteRule] {
    blockedSites.filter(\.isEnabled)
  }

  var disabledBlockedSites: [BlockedSiteRule] {
    blockedSites.filter { !$0.isEnabled }
  }

  var enabledIndividualBlockedDomains: [String] {
    enabledBlockedSites.map(\.domain).sorted()
  }

  var disabledIndividualBlockedDomains: [String] {
    disabledBlockedSites.map(\.domain).sorted()
  }

  var activeCategoryBlockedDomains: [String] {
    browserBlockingProviderModel.activeCategoryBlockedDomains
  }

  var activeBlockedDomains: [String] {
    browserBlockingProviderModel.activeBlockedDomains
  }

  var activeBlockedDomainCount: Int {
    activeBlockedDomains.count
  }

  var verifiedActiveBlockedDomains: [String] {
    let activeDomains = activeLegacyProviderRuleDomains
    let domains =
      verifiedIndividualBlockedDomains(activeDomains: activeDomains)
      + verifiedCategoryBlockedDomains(activeDomains: activeDomains)
    return Array(Set(domains)).sorted()
  }

  var verifiedActiveBlockedDomainCount: Int {
    verifiedActiveBlockedDomains.count
  }

  var hasActiveBlockRules: Bool {
    adultContentBlockingEnabled || !enabledBlockedSites.isEmpty
  }

  var chromeFallbackBlockedDomains: [String] {
    browserHelperBlockedDomains
  }

  var chromeFallbackReady: Bool {
    chromeHelperState == .current
  }

  var localHostsFallbackDomains: [String] {
    activeBlockedDomains
  }

  var localHostsFallbackConnected: Bool {
    localHostsFallbackInstalled
  }

  var localHostsFallbackSynced: Bool {
    guard localHostsFallbackInstalled else {
      return false
    }
    return localHostsScriptGenerator.localHostsBlocklistMatches(domains: localHostsFallbackDomains)
  }

  var localHostsFallbackCurrent: Bool {
    localHostsFallbackSynced
  }

  var localHostsFallbackMaintenanceNeeded: Bool {
    localHostsFallbackConnected && !localHostsFallbackSynced
  }

  var localHostsFallbackNeedsUpdate: Bool {
    localHostsFallbackMaintenanceNeeded
  }

  var localHostsFallbackMaintenanceStatus: String? {
    guard localHostsFallbackMaintenanceNeeded else {
      return nil
    }
    return localHostsFallbackDomains.isEmpty ? "Backup update clears old blocks" : "Backup update available"
  }

  var blockCoverageSummary: String {
    if !legacyProviderConnectorEnabled {
      if activeBlockedDomainCount == 0 {
        return "0 active blocks."
      }
      let blockText = "\(activeBlockedDomainCount) \(activeBlockedDomainCount == 1 ? "block" : "blocks")"
      return browserBlockingConnected
        ? "\(blockText) active in connected browsers."
        : "\(blockText) saved. Connect a browser to apply them."
    }

    let unconfirmedCount = max(activeBlockedDomainCount - verifiedActiveBlockedDomainCount, 0)

    let domainText: String
    if activeBlockedDomainCount == 0 {
      domainText = "0 active blocks."
    } else if verifiedActiveBlockedDomainCount == activeBlockedDomainCount {
      let blockText =
        "\(verifiedActiveBlockedDomainCount) \(verifiedActiveBlockedDomainCount == 1 ? "block" : "blocks")"
      domainText = "\(blockText) active."
    } else if verifiedActiveBlockedDomainCount > 0 {
      let activeText =
        "\(verifiedActiveBlockedDomainCount) \(verifiedActiveBlockedDomainCount == 1 ? "block" : "blocks")"
      let savedText = "\(unconfirmedCount) \(unconfirmedCount == 1 ? "saved block" : "saved blocks")"
      domainText = "\(activeText) active. \(savedText) not confirmed yet."
    } else {
      let blockText =
        "\(activeBlockedDomainCount) \(activeBlockedDomainCount == 1 ? "block" : "blocks")"
      domainText = blockApplicationAvailable
        ? "\(blockText) saved. Not confirmed yet."
        : "\(blockText) saved. Not blocking yet."
    }

    if let hiddenRestrictions = hiddenLegacyProviderManagedRestrictionsText {
      return "\(domainText) Still locked by account settings: \(hiddenRestrictions)."
    }
    return domainText
  }

  var blockApplicationAttentionTitle: String? {
    if !legacyProviderConnectorEnabled {
      return nil
    }
    if legacyProviderRulesSyncPending && legacyProviderControlConnected {
      return "QuietGate is checking these blocks"
    }
    guard hasActiveBlockRules, !blockApplicationAvailable else {
      return nil
    }
    return "Blocks are saved, but not active yet"
  }

  var blockApplicationAttentionDetail: String? {
    if !legacyProviderConnectorEnabled {
      return nil
    }
    if legacyProviderRulesSyncPending {
      if legacyProviderControlConnected {
        return "QuietGate is applying the change. This can take about a minute, especially in a browser tab that was already open."
      }
      return "Finish setup before QuietGate can apply these saved blocks."
    }
    guard hasActiveBlockRules, !blockApplicationAvailable else {
      return nil
    }
    if legacyProviderControlConnected && !legacyMacConnectionReady {
      return "Finish Mac approval in Setup so this computer uses QuietGate."
    }
    return "Finish setup so QuietGate has a place to apply these blocks."
  }

  var blockBrowserAttentionTitle: String? {
    guard hasActiveBlockRules,
          !browserBlockingConnected
    else {
      return nil
    }
    return legacyProviderConnectorEnabled
      ? "\(primaryBrowserConnector.displayName) is optional"
      : "Connect a browser"
  }

  var blockBrowserAttentionDetail: String? {
    guard blockBrowserAttentionTitle != nil else {
      return nil
    }
    switch chromeHelperState {
    case .notInstalled:
      if !legacyProviderConnectorEnabled {
        return "QuietGate saved your rules. Connect Chrome, Edge, Brave, Arc, or Firefox so website blocks and site tuning apply."
      }
      return "System blocking is active. New blocks can take about a minute to reach Chrome. Connect Chrome only if you want instant tab updates and site tuning."
    case .nativeHostMissing:
      if !legacyProviderConnectorEnabled {
        return "QuietGate saved your rules. Update the browser connection so your browser can receive them."
      }
      return "System blocking is active. New blocks can take about a minute to reach Chrome. Connect Chrome so it can receive QuietGate changes instantly."
    case .needsChromeOpen, .needsSync, .stale:
      if !legacyProviderConnectorEnabled {
        return "Open your connected browser once so QuietGate can confirm the latest rules."
      }
      return "System blocking is active. New blocks can take about a minute to reach Chrome. Open Chrome to update the optional browser connection."
    case .extensionNeedsReload:
      return "Chrome has an older QuietGate extension loaded. Reload the QuietGate extension in Chrome, or restart Chrome, so site tuning uses the latest code."
    case .error(let message):
      if !legacyProviderConnectorEnabled {
        return "The browser connection needs attention before it can apply QuietGate rules: \(message)"
      }
      return "System blocking is active. New blocks can take about a minute to reach Chrome. Chrome needs attention: \(message)"
    case .current:
      return nil
    }
  }

  var blockRuleEditingReady: Bool {
    blockingControlsReady
  }

  var blockRuleEditingUnavailableReason: String? {
    blockingCapabilityUnavailableReason
  }

  var activeBlockDestinationsText: String {
    let destinations = activeBlockDestinations
    return destinations.isEmpty ? "saved settings only" : destinations.joined(separator: ", ")
  }

  var localFallbackCoverageStatus: String {
    localHostsFallbackConnected ? "Installed" : "Not installed"
  }

  var disabledSiteStillBlockedDomains: [String] {
    guard legacyProviderConnectorEnabled else {
      return []
    }
    return disabledBlockedSites
      .filter { disabledSiteStillBlockedOnThisMac($0.domain) }
      .map(\.domain)
      .sorted()
  }

  var disabledSiteStillBlockedWarningTitle: String? {
    let domains = disabledSiteStillBlockedDomains
    guard !domains.isEmpty else {
      return nil
    }
    return domains.count == 1
      ? "A website is off in QuietGate"
      : "Some websites are off in QuietGate"
  }

  var disabledSiteStillBlockedWarningDetail: String? {
    let domains = disabledSiteStillBlockedDomains
    guard !domains.isEmpty else {
      return nil
    }

    let domainText = Self.formattedList(domains)
    return
      "\(domainText) is not being blocked by QuietGate. If it still will not open, another setting on this Mac may be blocking it."
  }

  var chromeCoverageStatus: String {
    if browserBlockingConnected {
      return "Connected"
    }
    switch chromeHelperState {
    case .notInstalled:
      return "Not installed"
    case .nativeHostMissing:
      return "Needs Chrome"
    case .needsChromeOpen:
      return "Open Chrome"
    case .needsSync:
      return "Needs sync"
    case .stale:
      return "Stale"
    case .extensionNeedsReload:
      return "Reload extension"
    case .error:
      return "Error"
    case .current:
      return "Connected"
    }
  }

  func blockCategoryApplicationStatus(_ rule: BlockCategoryRule) -> BlockApplicationStatus {
    guard rule.isEnabled else {
      return disabledCategoryBlockApplicationStatus
    }
    guard legacyProviderConnectorEnabled else {
      guard blockApplicationAvailable else {
        return enabledUnconfirmedBlockApplicationStatus
      }
      return confirmedBlockApplicationStatus
    }
    guard blockApplicationAvailable else {
      return enabledUnconfirmedBlockApplicationStatus
    }
    guard legacyProviderCategoryConfirmed(rule.id),
          blockCategoryDenylistConfirmed(rule)
    else {
      return BlockApplicationStatus(
        text: "On here - finishing setup",
        tone: .warning
      )
    }
    return confirmedBlockApplicationStatus
  }

  func blockedSiteApplicationStatus(_ rule: BlockedSiteRule) -> BlockApplicationStatus {
    if rule.isEnabled {
      guard legacyProviderConnectorEnabled else {
        guard blockApplicationAvailable else {
          return enabledUnconfirmedBlockApplicationStatus
        }
        return confirmedBlockApplicationStatus
      }
      guard blockApplicationAvailable else {
        return enabledUnconfirmedBlockApplicationStatus
      }
      guard legacyProviderRulesContains(rule.domain) else {
        return BlockApplicationStatus(
          text: "On here - not confirmed yet",
          tone: .warning
        )
      }
      return confirmedBlockApplicationStatus
    }

    guard legacyProviderConnectorEnabled else {
      return BlockApplicationStatus(text: "Off in QuietGate", tone: .secondary)
    }

    if pendingLegacyProviderRuleRemovalContains(rule.domain) {
      if legacyProviderRulesContains(rule.domain) {
        return BlockApplicationStatus(
          text: "Off here - still blocked by account",
          tone: .warning
        )
      }
      return BlockApplicationStatus(
        text: "Off here - checking",
        tone: .warning
      )
    }

    if legacyProviderRulesContains(rule.domain) {
      return BlockApplicationStatus(
        text: "Off here - still blocked by account",
        tone: .warning
      )
    }
    if disabledSiteStillBlockedOnThisMac(rule.domain) {
      return BlockApplicationStatus(
        text: "Off here - this Mac still blocks it",
        tone: .warning
      )
    }
    if disabledSiteProofInconclusive(rule.domain) {
      return BlockApplicationStatus(
        text: "Cannot prove off",
        tone: .warning
      )
    }
    if legacyProviderRulesSyncPending {
      return BlockApplicationStatus(
        text: "Off here - waiting for check",
        tone: .warning
      )
    }
    return BlockApplicationStatus(text: "Off - verified", tone: .secondary)
  }

  var timedSessionActive: Bool {
    guard let timedSessionEndDate,
      let timedSessionMode,
      timedSessionMode != .open
    else {
      return false
    }
    return timedSessionEndDate > nowProvider()
  }

  var timedSessionLockedActive: Bool {
    timedSessionActive && timedSessionLocked
  }

  var timedSessionStatusLine: String {
    guard timedSessionActive,
      let timedSessionMode,
      let timedSessionEndDate
    else {
      return "No timed session"
    }
    let prefix = timedSessionLocked ? "Locked " : ""
    return
      "\(prefix)\(timedSessionMode.title) session ends in \(Self.durationText(timedSessionEndDate.timeIntervalSince(nowProvider())))"
  }

  var activeFocusWindow: FocusWindow? {
    currentFocusWindow()
  }

  var focusWindowScheduleStatusLine: String {
    guard focusWindowScheduleEnabled else {
      return "Focus windows paused"
    }
    guard !focusWindows.isEmpty else {
      return "No focus windows"
    }
    if let activeFocusWindow {
      return
        "\(activeFocusWindow.title) active until \(FocusWindow.timeText(activeFocusWindow.endMinute))"
    }
    return nextFocusWindowStatusLine ?? "No window active"
  }

  var nextFocusWindowStatusLine: String? {
    guard focusWindowScheduleEnabled else {
      return nil
    }
    guard let next = nextFocusWindow() else {
      return nil
    }
    return "Next: \(next.title) at \(FocusWindow.timeText(next.startMinute))"
  }

  var readinessChecks: [ReadinessCheck] {
    readinessChecks(scope: .all)
  }

  var readinessSummary: String {
    readinessSummary(scope: .all)
  }

  func readinessChecks(scope: ReadinessScope) -> [ReadinessCheck] {
    switch scope {
    case .all:
      return readinessChecks(scope: .blocker) + readinessChecks(scope: .tuner)
    case .blocker:
      guard legacyProviderConnectorEnabled else {
        return []
      }
      if legacyProviderSetupStarted {
        return [
          websiteBlockingCheck, legacyProviderAccountCheck, legacyMacPermissionCheck, legacyMacConnectionCheck,
        ]
      }
      return [websiteBlockingCheck]
    case .tuner:
      return [browserConnectionCheck, browserSettingsCheck]
    case .selectedMode:
      guard legacyProviderConnectorEnabled else {
        return (accessMode.protectionEnabled || tunerEnabled || hasActiveBlockRules)
          ? readinessChecks(scope: .tuner)
          : []
      }
      var checks: [ReadinessCheck] = []
      if accessMode.protectionEnabled {
        checks += readinessChecks(scope: .blocker)
      }
      if accessMode.tunerEnabled || tunerEnabled {
        checks += readinessChecks(scope: .tuner)
      }
      return checks.isEmpty ? readinessChecks(scope: .tuner) : checks
    }
  }

  func readinessSummary(scope: ReadinessScope) -> String {
    let checks = readinessChecks(scope: scope)
    let readyCount = checks.filter { $0.state == .ready }.count
    return "\(readyCount) of \(checks.count) ready"
  }

  var nextReadinessCheck: ReadinessCheck? {
    nextStepReadinessChecks.first { check in
      check.state != .ready && check.action != nil
    }
  }

  var nextReadinessMenuTitle: String? {
    guard let check = nextReadinessCheck else {
      return nil
    }
    return "Next: \(check.title)"
  }

  private var nextStepReadinessChecks: [ReadinessCheck] {
    if !legacyProviderConnectorEnabled {
      return tunerEnabled || hasActiveBlockRules ? readinessChecks(scope: .tuner) : []
    }
    let blockerChecks = readinessChecks(scope: .blocker)
    let tunerChecks = readinessChecks(scope: .tuner)
    let needsBlocker = hasActiveBlockRules || accessMode.protectionEnabled || blockerProfileEnabled
    let needsTuner = tunerEnabled

    if websiteBlockingReady {
      return []
    }
    if needsBlocker && needsTuner {
      return blockerChecks + tunerChecks
    }
    if needsBlocker {
      return blockerChecks
    }
    if needsTuner {
      return tunerChecks
    }
    return blockerChecks + tunerChecks
  }

  private var activeBlockDestinations: [String] {
    var destinations: [String] = []
    if !legacyProviderConnectorEnabled {
      return browserConnectors
        .filter(\.isConnected)
        .map(\.displayName)
    }
    if systemBlockingCapabilityFresh {
      destinations.append("Mac blocking verified")
    }
    return destinations
  }

  private func browserConnector(for id: BrowserConnectorID) -> BrowserConnectorSnapshot {
    let support: BrowserConnectorSupport = id.isSupportedToday ? .supportedToday : .planned
    let status = browserExtensionStatus(for: id)
    let snapshot = browserHelperSnapshots[id]
    return BrowserConnectorSnapshot(
      id: id,
      support: support,
      isInstalled: browserInstallationChecker(id),
      state: id.isSupportedToday
        ? supportedBrowserConnectorState(for: id)
        : plannedBrowserConnectorState(for: id),
      activeRuleCount: 0,
      settingsVersion: snapshot?.lastAppliedSettingsVersion ?? "",
      selectedProfile: status.selectedProfile,
      selectedProfileLabel: status.selectedProfileLabel,
      connectedProfiles: status.readyProfiles,
      connectedProfileLabels: status.readyProfileLabels,
      lastSeenAt: snapshot?.lastSeenAt,
      nextAction: id.isSupportedToday ? supportedBrowserConnectorAction(for: id) : nil,
      isPrimary: id == primaryBrowserID
    )
  }

  private var browserBlockingProviderModel: BrowserBlockingProvider {
    BrowserBlockingProvider(
      accessMode: accessMode,
      blockCategories: blockCategories,
      blockedSites: blockedSites,
      tuningOverrides: tuningOverrides,
      tuningOptions: tuningOptions
    )
  }

  private var primaryBrowserID: BrowserConnectorID {
    if let connected = supportedBrowserIDs.first(where: { browserHelperState(for: $0) == .current }) {
      return connected
    }
    if let installed = supportedBrowserIDs.first(where: { browserInstallationChecker($0) }) {
      return installed
    }
    return .chrome
  }

  private func plannedBrowserConnectorState(for id: BrowserConnectorID) -> BrowserConnectorState {
    if browserInstallationChecker(id) {
      return .comingSoon("\(id.displayName) is installed. QuietGate support is planned.")
    }
    return .comingSoon("\(id.displayName) support is planned.")
  }

  private func supportedBrowserConnectorState(for id: BrowserConnectorID) -> BrowserConnectorState {
    let helperState = browserHelperState(for: id)
    if !browserInstallationChecker(id), helperState != .current {
      return .actionNeeded(
        "\(id.displayName) is not installed. Install \(id.displayName), or connect another supported browser."
      )
    }

    let status = browserExtensionStatus(for: id)
    switch helperState {
    case .current:
      if status.sessionReady, !status.persistentReady {
        let profile = status.selectedProfileLabel ?? status.sessionProfileLabels.first ?? "this profile"
        return .connected(
          "Connected for this \(id.displayName) session in \(profile). Add QuietGate to \(id.displayName) later if you want it to stay connected after restart."
        )
      }
      if let selectedProfile = status.selectedProfileLabel {
        return .connected("Connected in the current \(id.displayName) profile (\(selectedProfile)).")
      }
      return .connected("\(id.displayName) is connected to QuietGate.")
    case .notInstalled:
      return .actionNeeded(
        "Connect \(id.displayName) so website blocks and site tuning apply there."
      )
    case .nativeHostMissing:
      return .actionNeeded(
        "Finish the small \(id.displayName) connection file so \(id.displayName) can receive QuietGate settings."
      )
    case .needsChromeOpen:
      if let selectedProfile = status.selectedProfileLabel {
        return .connectedPending(
          "\(id.displayName) is connected in \(selectedProfile). QuietGate changes apply next time it opens."
        )
      }
      return .connectedPending(
        "\(id.displayName) is connected. QuietGate changes apply next time it opens."
      )
    case .needsSync:
      if let selectedProfile = status.selectedProfileLabel {
        return .connectedPending(
          "\(id.displayName) is connected in \(selectedProfile). QuietGate is updating it with the latest settings."
        )
      }
      return .connectedPending(
        "\(id.displayName) is connected. QuietGate is updating it with the latest settings."
      )
    case .stale:
      if let selectedProfile = status.selectedProfileLabel {
        return .connectedPending(
          "\(id.displayName) is connected in \(selectedProfile). Refresh the browser connection if pages have not updated."
        )
      }
      return .connectedPending(
        "\(id.displayName) is connected. Refresh the browser connection if pages have not updated."
      )
    case .extensionNeedsReload:
      return .connectedPending(
        "\(id.displayName) has an older QuietGate extension loaded. Open Extensions, reload QuietGate, then refresh the affected site."
      )
    case .error(let message):
      return .error("\(id.displayName) reported: \(message)")
    }
  }

  private func supportedBrowserConnectorAction(for id: BrowserConnectorID) -> ReadinessAction? {
    let helperState = browserHelperState(for: id)
    if !browserInstallationChecker(id), helperState != .current {
      return id == .chrome ? .openChromeDownload : .openBrowserDownload(id)
    }

    switch helperState {
    case .current:
      return nil
    case .nativeHostMissing:
      return id == .chrome ? .installChromeSync : .installBrowserSync(id)
    case .needsChromeOpen, .needsSync, .stale:
      return .applyBrowserChanges(id)
    case .extensionNeedsReload:
      return .openBrowserExtensionsPage(id)
    case .notInstalled, .error:
      return id == .chrome ? .launchChromeTunerSession : .launchBrowserTunerSession(id)
    }
  }

  private func browserExtensionStatus(for id: BrowserConnectorID) -> ChromeExtensionStatus {
    browserExtensionStatuses[id] ?? (id == .chrome ? chromeExtensionStatus : .empty)
  }

  private func browserHelperState(for id: BrowserConnectorID) -> ChromeHelperState {
    browserHelperStates[id] ?? (id == .chrome ? chromeHelperState : .notInstalled)
  }

  private var chromeApplicationURL: URL? {
    browserApplicationURL(for: .chrome)
  }

  private func browserApplicationURL(for id: BrowserConnectorID) -> URL? {
    id.likelyApplicationURLs.first {
      FileManager.default.fileExists(atPath: $0.path)
    }
  }

  private var browserBlockingProvider: BlockingProviderSnapshot {
    browserBlockingProviderModel.providerSnapshot(
      destinationNames: connectedBrowserNames,
      isDefault: !legacyProviderConnectorEnabled
    )
  }

  private var legacyBlockingProvider: BlockingProviderSnapshot {
    let state: BlockingProviderState =
      systemBlockingCapabilityFresh
      ? .ready("Advanced blocking is verified on this Mac.")
      : .actionNeeded(
        blockingCapabilityUnavailableReason
          ?? "Advanced setup needs attention before it can be trusted."
      )

    return BlockingProviderSnapshot(
      id: .legacyProvider,
      title: "Advanced blocking",
      kind: .dns,
      state: state,
      activeRuleCount: verifiedActiveBlockedDomainCount,
      destinationNames: systemBlockingCapabilityFresh ? ["Mac connection"] : [],
      isDefault: legacyProviderConnectorEnabled,
      isLegacy: true
    )
  }

  private var legacyProviderBlockConnectorReady: Bool {
    configured && !legacyProviderKeyNeedsPermission && legacyMacConnectionReady
  }

  private var freshLegacyProviderControlReadback: Bool {
    legacyProviderControlConnected && readbackIsFresh(parentalControlCheckedAt)
  }

  private var freshLegacyProviderRulesReadback: Bool {
    readbackIsFresh(legacyProviderRulesCheckedAt)
  }

  private var freshMacConnectionReadback: Bool {
    legacyMacConnectionReady && readbackIsFresh(resolverStatusCheckedAt)
  }

  private func readbackIsFresh(_ date: Date?) -> Bool {
    guard let date else {
      return false
    }
    return nowProvider().timeIntervalSince(date) <= Self.blockingReadbackFreshnessInterval
  }

  private var blockApplicationAvailable: Bool {
    legacyProviderConnectorEnabled ? systemBlockingCapabilityFresh : browserBlockingConnected
  }

  private var verifiedIndividualBlockedDomains: [String] {
    verifiedIndividualBlockedDomains(activeDomains: activeLegacyProviderRuleDomains)
  }

  private func verifiedIndividualBlockedDomains(activeDomains: Set<String>) -> [String] {
    if !legacyProviderConnectorEnabled {
      return browserBlockingConnected ? enabledBlockedSites.map(\.domain).sorted() : []
    }
    return enabledBlockedSites
      .map(\.domain)
      .filter { legacyProviderRulesContains($0, in: activeDomains) }
      .sorted()
  }

  private var verifiedCategoryBlockedDomains: [String] {
    verifiedCategoryBlockedDomains(activeDomains: activeLegacyProviderRuleDomains)
  }

  private func verifiedCategoryBlockedDomains(activeDomains: Set<String>) -> [String] {
    if !legacyProviderConnectorEnabled {
      return adultContentBlockingEnabled && browserBlockingConnected
        ? activeCategoryBlockedDomains
        : []
    }
    guard adultContentBlockingEnabled,
          legacyProviderCategoryConfirmed(.adultContent)
    else {
      return []
    }
    return activeCategoryBlockedDomains
      .filter { legacyProviderRulesContains($0, in: activeDomains) }
  }

  private var activeLegacyProviderRuleDomains: Set<String> {
    if let activeLegacyProviderRuleDomainsCache {
      return activeLegacyProviderRuleDomainsCache
    }

    let domains: Set<String> = Set(
      legacyProviderRules.compactMap { item in
        guard item.active else {
          return nil
        }
        return Self.normalizedReadbackDomain(item.id)
      }
    )
    activeLegacyProviderRuleDomainsCache = domains
    return domains
  }

  private func legacyProviderRulesContains(_ domain: String) -> Bool {
    legacyProviderRulesContains(domain, in: activeLegacyProviderRuleDomains)
  }

  private func legacyProviderRulesContains(_ domain: String, in activeDomains: Set<String>) -> Bool {
    guard let normalized = Self.normalizedReadbackDomain(domain) else {
      return false
    }
    return activeDomains.contains(normalized)
  }

  private func pendingLegacyProviderRuleRemovalContains(_ domain: String) -> Bool {
    guard let normalized = Self.normalizedReadbackDomain(domain) else {
      return false
    }
    return pendingLegacyProviderRuleRemovals.contains(normalized)
  }

  private func disabledSiteStillBlockedOnThisMac(_ domain: String) -> Bool {
    guard legacyProviderConnectorEnabled else {
      return false
    }
    guard let normalized = try? DomainNormalizer.normalize(domain),
          disabledBlockedSites.contains(where: { $0.domain == normalized })
    else {
      return false
    }
    return domainResolutionStatuses[normalized]?.isSinkholed == true
  }

  private func disabledSiteProofInconclusive(_ domain: String) -> Bool {
    guard legacyProviderConnectorEnabled else {
      return false
    }
    guard let normalized = try? DomainNormalizer.normalize(domain),
          disabledBlockedSites.contains(where: { $0.domain == normalized })
    else {
      return false
    }
    guard let status = domainResolutionStatuses[normalized] else {
      return true
    }
    return status.isInconclusive
  }

  private func legacyProviderCategoryConfirmed(_ id: BlockCategoryID) -> Bool {
    if !legacyProviderConnectorEnabled {
      return true
    }
    guard systemBlockingCapabilityFresh,
          let parentalControl
    else {
      return false
    }

    switch id {
    case .adultContent:
      return parentalControl.isQuietGateEnabled
    }
  }

  private func blockCategoryDenylistConfirmed(_ rule: BlockCategoryRule) -> Bool {
    if !legacyProviderConnectorEnabled {
      return true
    }
    guard rule.isEnabled else {
      return true
    }
    let activeDomains = activeLegacyProviderRuleDomains
    return rule.id.domains.allSatisfy { legacyProviderRulesContains($0, in: activeDomains) }
  }

  private var browserHelperBlockedDomains: [String] {
    legacyProviderConnectorEnabled
      ? (systemBlockingCapabilityFresh ? verifiedActiveBlockedDomains : [])
      : activeBlockedDomains
  }

  private var confirmedBlockApplicationStatus: BlockApplicationStatus {
    BlockApplicationStatus(
      text: appliedStatusText,
      tone: .positive
    )
  }

  private var enabledUnconfirmedBlockApplicationStatus: BlockApplicationStatus {
    BlockApplicationStatus(
      text: unappliedBlockStatusText,
      tone: .warning
    )
  }

  private var disabledCategoryBlockApplicationStatus: BlockApplicationStatus {
    if !legacyProviderConnectorEnabled {
      return BlockApplicationStatus(text: "Off in QuietGate", tone: .secondary)
    }
    if let hiddenRestrictions = hiddenLegacyProviderManagedRestrictionsText {
      return BlockApplicationStatus(
        text: "Off here - still on in account settings: \(hiddenRestrictions)",
        tone: .warning
      )
    }
    guard systemBlockingCapabilityFresh else {
      return BlockApplicationStatus(text: "Cannot prove off", tone: .warning)
    }
    if legacyProviderRulesSyncPending {
      return BlockApplicationStatus(text: "Off here - waiting for check", tone: .warning)
    }
    return BlockApplicationStatus(text: "Off - verified", tone: .secondary)
  }

  private var appliedStatusText: String {
    guard hasActiveBlockRules else {
      return "No active blocks"
    }
    if !legacyProviderConnectorEnabled {
      return browserBlockingConnected ? "On in browser" : "On in QuietGate"
    }
    return "On - verified"
  }

  private var unappliedBlockStatusText: String {
    if !legacyProviderConnectorEnabled {
      return "On in QuietGate - connect a browser"
    }
    if legacyProviderRulesSyncPending {
      return legacyProviderControlConnected ? "On here - checking" : "On here - account access needed"
    }
    if legacyProviderControlConnected && !legacyMacConnectionReady {
      return "On here - Mac permission needed"
    }
    if blockApplicationAvailable {
      return "On here - not confirmed yet"
    }
    return "On here - connect QuietGate to apply"
  }

  var extensionSettingsURL: URL {
    extensionBridge.settingsURL
  }

  var chromeExtensionDirectoryURL: URL {
    extensionBridge.chromeExtensionDirectoryURL
  }

  func browserExtensionDirectoryURL(for browser: BrowserConnectorID) -> URL {
    extensionBridge.extensionDirectoryURL(for: browser)
  }

  var chromeExtensionAvailable: Bool {
    extensionBridge.chromeExtensionAvailable()
  }

  var installedNativeHostURL: URL {
    extensionBridge.installedNativeHostURL
  }

  var nativeMessagingManifestURL: URL {
    extensionBridge.nativeMessagingManifestURL
  }

  func saveConfiguration() async {
    isWorking = true
    defer { isWorking = false }

    do {
      let hadSavedAPIKey = hasAPIKey
      profileID = profileID.trimmingCharacters(in: .whitespacesAndNewlines)
      defaults.set(profileID, forKey: DefaultsKey.profileID)

      let apiKey = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
      if !apiKey.isEmpty {
        clearLegacyProviderControlVerification()
        try keychain.saveSecret(apiKey)
        cachedAPIKey = apiKey
        legacyProviderKeyNeedsPermission = false
        apiKeyDraft = ""
        if hadSavedAPIKey {
          resolverStatus = nil
        }
      }
      hasAPIKey = cachedAPIKey != nil || keychain.hasSecret()
      await refresh()
      if legacyProviderRulesSyncPending {
        await syncPendingLegacyProviderRules()
      }
    } catch {
      present(error)
    }
  }

  func clearAPIKey() {
    do {
      try keychain.deleteSecret()
      cachedAPIKey = nil
      hasAPIKey = false
      legacyProviderKeyNeedsPermission = false
      clearLegacyProviderControlVerification()
      apiKeyDraft = ""
      mode = .off
      parentalControl = nil
      parentalControlCheckedAt = nil
      clearLegacyProviderRulesReadback()
      blockedLogs = []
      analyticsStatus = []
      connectionState = .notConfigured
      resolverStatusCheckedAt = nil
      clearPendingLegacyProviderRuleRemovals()
      setLegacyProviderRulesSyncPending(false)
    } catch {
      present(error)
    }
  }

  func resetBaseline() {
    defaults.removeObject(forKey: DefaultsKey.baseline)
    errorMessage = nil
  }

  func allowSavedProviderCredentialAccess() async {
    isWorking = true
    let apiKey: String?
    do {
      apiKey = try keychain.readSecret(allowUserInteraction: true)
    } catch {
      isWorking = false
      present(error)
      return
    }
    isWorking = false

    guard let apiKey,
          !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      legacyProviderKeyNeedsPermission = false
      cachedAPIKey = nil
      hasAPIKey = false
      clearLegacyProviderControlVerification()
      connectionState = .notConfigured
      errorMessage = "Connect again, then save again."
      return
    }

    cachedAPIKey = apiKey
    hasAPIKey = true
    legacyProviderKeyNeedsPermission = false
    setupMessage = "Great, QuietGate can read the saved setup key now."
    errorMessage = nil
    await refresh()
  }

  func refreshProtectionStatus() async {
    guard legacyProviderConnectorEnabled else {
      refreshBrowserFirstStatus()
      await refreshBuiltInProtections()
      return
    }

    if configured {
      await refresh()
    } else {
      await checkThisMac()
      await refreshDisabledSiteBlockStatus()
    }
    await refreshBuiltInProtections()
  }

  func refresh() async {
    guard legacyProviderConnectorEnabled else {
      refreshBrowserFirstStatus()
      await refreshBuiltInProtections()
      return
    }

    refreshLocalSetupStatus()

    guard configured else {
      mode = .off
      parentalControl = nil
      clearLegacyProviderRulesReadback()
      connectionState = .notConfigured
      clearLegacyProviderControlVerification()
      await refreshDisabledSiteBlockStatus()
      return
    }

    isWorking = true
    connectionState = .checking
    defer { isWorking = false }

    do {
      let client = try configuredClient()
      let parentalControl = try await client.getParentalControl(profileID: profileID)
      parentalControlCheckedAt = nowProvider()
      try await refreshLegacyProviderRules(using: client)
      markLegacyProviderControlVerified()
      ensureBaseline(parentalControl)
      self.parentalControl = parentalControl
      let protectionEnabled = parentalControl.isQuietGateEnabled
      let managedRestrictionsActive = parentalControl.quietGateManagedRestrictionActive
      mode = managedRestrictionsActive ? .on : .off

      await updateResolverStatus()
      if legacyProviderBlockConnectorReady && legacyProviderRulesNeedsSync() {
        setLegacyProviderRulesSyncPending(true)
      }

      if protectionEnabled && !adultContentBlockingEnabled {
        if !categoryPreferencesHaveBeenSaved && !accessMode.protectionEnabled {
          blockCategories = blockCategories.setting(.adultContent, enabled: true)
          persistBlockCategories()
          persistAccessMode(.focus)
        } else {
          _ = await applyProtection(
            adultContentBlockingEnabled,
            accessMode: accessMode,
            requireCapabilityReady: false
          )
          return
        }
      } else if adultContentBlockingEnabled {
        if !protectionEnabled {
          _ = await applyProtection(true, accessMode: accessMode, requireCapabilityReady: false)
          return
        }
      } else if managedRestrictionsActive {
        _ = await applyProtection(false, accessMode: accessMode, requireCapabilityReady: false)
        return
      }

      connectionState = .connected
      errorMessage = nil
      if legacyProviderRulesSyncPending && legacyProviderBlockConnectorReady {
        await syncPendingLegacyProviderRules()
      } else {
        await refreshActivity(using: client)
      }
      await refreshDisabledSiteBlockStatus()
    } catch {
      clearLegacyProviderControlVerificationIfCredentialFailure(error)
      connectionState = .error(error.localizedDescription)
      await refreshDisabledSiteBlockStatus()
      present(error)
    }
  }

  func toggleProtection() async {
    await setAccessMode(mode == .off ? .focus : .open)
  }

  func setAccessMode(_ newMode: AccessMode) async {
    guard !timedSessionLockedActive else {
      refuseLockedTimedSessionChange()
      return
    }
    guard accessMode != newMode else {
      return
    }
    if shouldRefreshBlockingCapabilityBeforeMutation {
      setBlockingTransaction(.checkingCapability, for: Self.accessModeControlKey)
      await refresh()
    }
    guard requireBlockingControlsReady(controlKey: Self.accessModeControlKey) else {
      return
    }

    let previousEndDate = timedSessionEndDate
    let previousTimedMode = timedSessionMode
    let previousLocked = timedSessionLocked
    let previousActiveFocusWindowID = activeFocusWindowID
    let previousSuppressedFocusWindowID = suppressedFocusWindowID
    clearTimedSession()
    suppressCurrentFocusWindowIfNeeded(forManualMode: newMode)
    setActiveFocusWindowID(nil)
    let applied = await applyAccessModeSelection(newMode)
    guard applied else {
      timedSessionEndDate = previousEndDate
      timedSessionMode = previousTimedMode
      timedSessionLocked = previousLocked
      setActiveFocusWindowID(previousActiveFocusWindowID)
      setSuppressedFocusWindowID(previousSuppressedFocusWindowID)
      persistTimedSession()
      scheduleTimedSessionTimer()
      return
    }
  }

  @discardableResult
  private func applyAccessModeSelection(_ newMode: AccessMode) async -> Bool {
    await applyProtection(
      newMode.protectionEnabled, accessMode: newMode, resetTuningOverrides: true)
  }

  func startTimedSession(mode sessionMode: AccessMode, duration: TimeInterval, locked: Bool = false)
    async
  {
    guard !timedSessionLockedActive else {
      refuseLockedTimedSessionChange()
      return
    }
    if shouldRefreshBlockingCapabilityBeforeMutation {
      setBlockingTransaction(.checkingCapability, for: Self.timedSessionControlKey)
      await refresh()
    }
    guard requireBlockingControlsReady(controlKey: Self.timedSessionControlKey) else {
      return
    }

    let sessionMode = sessionMode == .open ? AccessMode.focus : sessionMode
    let previousEndDate = timedSessionEndDate
    let previousMode = timedSessionMode
    let previousLocked = timedSessionLocked
    let previousActiveFocusWindowID = activeFocusWindowID
    setBlockingTransaction(
      .applying("Starting \(sessionMode.title) session. Blocks can take about a minute."),
      for: Self.timedSessionControlKey
    )
    setActiveFocusWindowID(nil)
    let applied = await applyAccessModeSelection(sessionMode)
    guard applied else {
      timedSessionEndDate = previousEndDate
      timedSessionMode = previousMode
      timedSessionLocked = previousLocked
      setActiveFocusWindowID(previousActiveFocusWindowID)
      persistTimedSession()
      scheduleTimedSessionTimer()
      setBlockingTransaction(
        .reverted(
          reason: "QuietGate could not prove the timed session started, so it put it back.",
          nextAction: nil
        ),
        for: Self.timedSessionControlKey
      )
      return
    }
    timedSessionMode = sessionMode
    timedSessionEndDate = nowProvider().addingTimeInterval(duration)
    timedSessionLocked = locked
    persistTimedSession()
    scheduleTimedSessionTimer()
    setBlockingTransaction(
      .verified("\(sessionMode.title) session started. Blocks can take about a minute to reach your browser."),
      for: Self.timedSessionControlKey
    )
  }

  func endTimedSession() async {
    guard !timedSessionLockedActive else {
      refuseLockedTimedSessionChange()
      return
    }
    if shouldRefreshBlockingCapabilityBeforeMutation {
      setBlockingTransaction(.checkingCapability, for: Self.timedSessionControlKey)
      await refresh()
    }
    guard requireBlockingControlsReady(controlKey: Self.timedSessionControlKey) else {
      return
    }

    let previousEndDate = timedSessionEndDate
    let previousMode = timedSessionMode
    let previousLocked = timedSessionLocked
    clearTimedSession()
    if await applyFocusWindowScheduleIfNeeded() {
      return
    }
    let applied = await applyAccessModeSelection(.open)
    guard applied else {
      timedSessionEndDate = previousEndDate
      timedSessionMode = previousMode
      timedSessionLocked = previousLocked
      persistTimedSession()
      scheduleTimedSessionTimer()
      setBlockingTransaction(
        .reverted(
          reason: "QuietGate could not prove the timed session ended, so it put it back.",
          nextAction: nil
        ),
        for: Self.timedSessionControlKey
      )
      return
    }
  }

  func expireTimedSessionIfNeeded() async {
    guard let timedSessionEndDate,
      timedSessionEndDate <= nowProvider()
    else {
      scheduleTimedSessionTimer()
      return
    }

    clearTimedSession()
    if await applyFocusWindowScheduleIfNeeded() {
      return
    }
    await applyAccessModeSelection(.open)
  }

  func addFocusWindow(
    title: String,
    startMinute: Int,
    endMinute: Int,
    mode: AccessMode
  ) {
    guard requireBlockingControlsReady(controlKey: Self.focusWindowsControlKey) else {
      return
    }
    let window = FocusWindow(
      title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? mode.title : title,
      startMinute: startMinute,
      endMinute: endMinute,
      mode: mode
    )
    focusWindows.append(window)
    focusWindows.sort { lhs, rhs in
      if lhs.startMinute == rhs.startMinute {
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
      }
      return lhs.startMinute < rhs.startMinute
    }
    persistFocusWindows()
    scheduleFocusWindowTimer()
  }

  func removeFocusWindow(_ id: UUID) {
    guard requireBlockingControlsReady(controlKey: Self.focusWindowsControlKey) else {
      return
    }
    focusWindows.removeAll { $0.id == id }
    if suppressedFocusWindowID == id {
      setSuppressedFocusWindowID(nil)
    }
    persistFocusWindows()
    scheduleFocusWindowTimer()
  }

  func setFocusWindow(_ id: UUID, isEnabled: Bool) {
    guard requireBlockingControlsReady(controlKey: Self.focusWindowsControlKey) else {
      return
    }
    guard let index = focusWindows.firstIndex(where: { $0.id == id }) else {
      return
    }
    focusWindows[index].isEnabled = isEnabled
    if !isEnabled && suppressedFocusWindowID == id {
      setSuppressedFocusWindowID(nil)
    }
    persistFocusWindows()
    scheduleFocusWindowTimer()
  }

  func setFocusWindowScheduleEnabled(_ enabled: Bool) {
    guard requireBlockingControlsReady(controlKey: Self.focusWindowsControlKey) else {
      return
    }
    focusWindowScheduleEnabled = enabled
    defaults.set(enabled, forKey: DefaultsKey.focusWindowScheduleEnabled)
    if !enabled {
      setActiveFocusWindowID(nil)
      setSuppressedFocusWindowID(nil)
    }
    scheduleFocusWindowTimer()
  }

  @discardableResult
  func evaluateFocusWindowSchedule() async -> Bool {
    await applyFocusWindowScheduleIfNeeded()
  }

  @discardableResult
  func setProtection(_ enabled: Bool) async -> Bool {
    let nextMode: AccessMode = enabled ? (accessMode == .open ? .focus : accessMode) : .open
    return await applyProtection(enabled, accessMode: nextMode, resetTuningOverrides: true)
  }

  @discardableResult
  private func applyProtection(
    _ enabled: Bool,
    accessMode nextAccessMode: AccessMode,
    resetTuningOverrides: Bool = false,
    requireRuleEditingReady: Bool = false,
    requireCapabilityReady: Bool = true
  ) async -> Bool {
    let controlKey =
      requireRuleEditingReady
      ? Self.blockCategoryControlKey(.adultContent)
      : Self.accessModeControlKey
    let candidateCategories = blockCategories.setting(.adultContent, enabled: enabled)
    if requireCapabilityReady {
      if shouldRefreshBlockingCapabilityBeforeMutation {
        setBlockingTransaction(.checkingCapability, for: controlKey)
        await refresh()
      }
      guard requireBlockingControlsReady(controlKey: controlKey) else {
        return false
      }
      setBlockingTransaction(
        .applying(
          enabled
            ? "Turning blocking on. This can take about a minute."
            : "Turning blocking off. This can take about a minute."
        ),
        for: controlKey
      )
    }

    guard legacyProviderConnectorEnabled else {
      blockCategories = candidateCategories
      persistBlockCategories()
      mode = enabled ? .on : .off
      persistAccessMode(
        nextAccessMode,
        resetTuningOverrides: resetTuningOverrides,
        syncBrowserSettings: false
      )
      clearPendingLegacyProviderRuleRemovals()
      connectionState = .connected
      syncBrowserExtensionSettings()
      errorMessage = nil
      setBlockingTransaction(
        .verified(
          enabled
            ? "Blocking is on in connected browsers."
            : "Blocking is off in QuietGate."
        ),
        for: controlKey
      )
      return true
    }

    guard configured else {
      connectionState = .notConfigured
      mode = .off
      setBlockingTransaction(
        .reverted(
          reason: "QuietGate could not prove this changed, so it put the switch back.",
          nextAction: "Open Setup"
        ),
        for: controlKey
      )
      errorMessage = blockingCapabilityUnavailableReason
      return false
    }

    guard let client = legacyProviderClientForImmediateSync() else {
      mode = .off
      setBlockingTransaction(
        .reverted(
          reason: "QuietGate could not prove this changed, so it put the switch back.",
          nextAction: "Open Setup"
        ),
        for: controlKey
      )
      errorMessage = blockingCapabilityUnavailableReason
      return false
    }

    isWorking = true
    defer { isWorking = false }

    do {
      let current = try await client.getParentalControl(profileID: profileID)
      parentalControlCheckedAt = nowProvider()
      let baseline = savedBaseline()

      let target: ParentalControl
      if enabled {
        ensureBaseline(current)
        target = current.applyingQuietGateEnabled()
      } else {
        target = (baseline ?? current).applyingQuietGateDisabled()
      }

      let updated = try await client.patchParentalControl(profileID: profileID, value: target)
      let confirmed = enabled ? updated.isQuietGateEnabled : !updated.quietGateManagedRestrictionActive
      guard confirmed else {
        throw LegacyProviderReadbackError.categoryNotConfirmed(BlockCategoryID.adultContent.title)
      }
      markLegacyProviderControlVerified()
      parentalControl = updated
      parentalControlCheckedAt = nowProvider()
      mode = enabled ? .on : .off
      do {
        try await refreshLegacyProviderRules(using: client)
        try await applyLegacyProviderRules(
          client,
          sites: blockedSites,
          categories: candidateCategories
        )
        try await refreshLegacyProviderRules(using: client)
      } catch {
        setLegacyProviderRulesSyncPending(true)
        syncBrowserExtensionSettings()
        setBlockingTransaction(
          .reverted(
            reason: "QuietGate could not prove this changed, so it put the switch back.",
            nextAction: nil
          ),
          for: controlKey
        )
        present(LegacyProviderReadbackError.pendingRulesNotConfirmed)
        return false
      }
      await updateResolverStatus()
      guard systemBlockingCapabilityFresh else {
        throw LegacyProviderReadbackError.categoryNotConfirmed(BlockCategoryID.adultContent.title)
      }
      guard legacyProviderReadbackConfirmsSavedRules(sites: blockedSites, categories: candidateCategories)
      else {
        throw LegacyProviderReadbackError.pendingRulesNotConfirmed
      }
      blockCategories = candidateCategories
      persistBlockCategories()
      persistAccessMode(
        nextAccessMode,
        resetTuningOverrides: resetTuningOverrides,
        syncBrowserSettings: false
      )
      connectionState = .connected
      setLegacyProviderRulesSyncPending(legacyProviderRulesNeedsSync())
      syncBrowserExtensionSettings()
      errorMessage = nil
      await refreshActivity(using: client)
      setBlockingTransaction(
        .verified(
          enabled
            ? "Blocking is on. It can take about a minute to reach your browser."
            : "Blocking is off. It can take about a minute for browser tabs to catch up."
        ),
        for: controlKey
      )
      return true
    } catch {
      clearLegacyProviderControlVerificationIfCredentialFailure(error)
      connectionState = .error(error.localizedDescription)
      setBlockingTransaction(
        .reverted(
          reason: "QuietGate could not prove this changed, so it put the switch back.",
          nextAction: nil
        ),
        for: controlKey
      )
      present(error)
      return false
    }
  }

  private var shouldRefreshBlockingCapabilityBeforeMutation: Bool {
    legacyProviderConnectorEnabled && configured && !legacyProviderKeyNeedsPermission
      && !blockingControlsReady && !isWorking
  }

  func addCustomDomain() async {
    do {
      let domain = try DomainNormalizer.normalize(customDomainDraft)
      try await addCustomDomain(domain)
      customDomainDraft = ""
    } catch {
      present(error)
    }
  }

  func addCustomDomain(_ domain: String) async throws {
    let normalized = try DomainNormalizer.normalize(domain)
    let controlKey = Self.blockedSiteControlKey(normalized)
    if shouldRefreshBlockingCapabilityBeforeMutation {
      setBlockingTransaction(.checkingCapability, for: controlKey)
      await refresh()
    }
    guard requireBlockingControlsReady(controlKey: controlKey) else {
      return
    }
    setBlockingTransaction(
      .applying("Adding \(normalized). This can take about a minute."),
      for: controlKey
    )

    var candidateSites = blockedSites
    if let index = candidateSites.firstIndex(where: { $0.domain == normalized }) {
      candidateSites[index].isEnabled = true
    } else {
      candidateSites.append(BlockedSiteRule(domain: normalized, isEnabled: true))
      candidateSites.sort { $0.domain < $1.domain }
    }

    guard legacyProviderConnectorEnabled else {
      blockedSites = candidateSites
      removePendingLegacyProviderRuleRemoval(normalized)
      persistBlockedSites()
      connectionState = .connected
      syncBrowserExtensionSettings()
      await refreshDisabledSiteBlockStatus()
      setBlockingTransaction(
        .verified("\(normalized) is on in connected browsers."),
        for: controlKey
      )
      errorMessage = nil
      return
    }

    guard let client = legacyProviderClientForImmediateSync() else {
      errorMessage = nil
      return
    }

    isWorking = true
    defer { isWorking = false }

    do {
      try await addLegacyProviderRule(client, domain: normalized)
      do {
        try await refreshLegacyProviderRules(using: client)
      } catch {
        markLegacyProviderControlVerified()
        connectionState = .connected
        addPendingLegacyProviderRuleRemoval(normalized)
        setLegacyProviderRulesSyncPending(true)
        syncBrowserExtensionSettings()
        await refreshDisabledSiteBlockStatus()
        setBlockingTransaction(
          .reverted(
            reason: "QuietGate could not prove \(normalized) was added, so it put the switch back.",
            nextAction: nil
          ),
          for: controlKey
        )
        present(LegacyProviderReadbackError.ruleStatusUnknown(normalized))
        return
      }
      guard legacyProviderRulesContains(normalized) else {
        throw LegacyProviderReadbackError.addedDomainNotConfirmed(normalized)
      }
      markLegacyProviderControlVerified()
      blockedSites = candidateSites
      removePendingLegacyProviderRuleRemoval(normalized)
      persistBlockedSites()
      connectionState = .connected
      setLegacyProviderRulesSyncPending(false)
      syncBrowserExtensionSettings()
      await refreshDisabledSiteBlockStatus()
      await refreshActivity(using: client)
      setBlockingTransaction(
        .verified("\(normalized) is on. It can take about a minute to reach your browser."),
        for: controlKey
      )
    } catch {
      clearLegacyProviderControlVerificationIfCredentialFailure(error)
      connectionState = .error(error.localizedDescription)
      setBlockingTransaction(
        .reverted(
          reason: "QuietGate could not prove \(normalized) was added, so it put the switch back.",
          nextAction: nil
        ),
        for: controlKey
      )
      present(error)
      return
    }
    errorMessage = nil
  }

  func removeCustomDomain(_ domain: String) async {
    guard !timedSessionLockedActive || !blockedSiteEnabled(domain) else {
      refuseLockedTimedSessionChange()
      return
    }

    do {
      let normalized = try DomainNormalizer.normalize(domain)
      let controlKey = Self.blockedSiteControlKey(normalized)
      let wasEnabled = blockedSites.first { $0.domain == normalized }?.isEnabled == true
      let candidateSites = blockedSites.filter { $0.domain != normalized }
      if shouldRefreshBlockingCapabilityBeforeMutation {
        setBlockingTransaction(.checkingCapability, for: controlKey)
        await refresh()
      }

      guard legacyProviderConnectorEnabled else {
        blockedSites = candidateSites
        removePendingLegacyProviderRuleRemoval(normalized)
        persistBlockedSites()
        connectionState = .connected
        syncBrowserExtensionSettings()
        await refreshDisabledSiteBlockStatus()
        setBlockingTransaction(.verified("\(normalized) was removed from QuietGate."), for: controlKey)
        errorMessage = nil
        return
      }

      guard wasEnabled else {
        guard requireBlockingControlsReady(controlKey: controlKey) else {
          return
        }
        if legacyProviderRulesContains(normalized) || disabledSiteStillBlockedOnThisMac(normalized)
          || disabledSiteProofInconclusive(normalized) {
          setBlockingTransaction(
            .reverted(
              reason: "QuietGate cannot delete \(normalized) until it proves the site is unblocked.",
              nextAction: nil
            ),
            for: controlKey
          )
          errorMessage = "QuietGate cannot delete \(normalized) until it proves the site is unblocked."
          return
        }
        blockedSites = candidateSites
        persistBlockedSites()
        syncBrowserExtensionSettings()
        await refreshDisabledSiteBlockStatus()
        clearBlockingTransaction(for: controlKey)
        errorMessage = nil
        return
      }

      guard requireBlockingControlsReady(controlKey: controlKey) else {
        return
      }

      guard let client = legacyProviderClientForImmediateSync() else {
        errorMessage = nil
        return
      }

      isWorking = true
      defer { isWorking = false }
      setBlockingTransaction(.applying("Removing \(normalized)."), for: controlKey)

      do {
        try await removeLegacyProviderRule(client, domain: normalized)
      } catch {
        clearLegacyProviderControlVerificationIfCredentialFailure(error)
        let restored = await restoreLegacyProviderRuleIfNeeded(client, domain: normalized)
        setLegacyProviderRulesSyncPending(!restored)
        syncBrowserExtensionSettings()
        await refreshDisabledSiteBlockStatus()
        setBlockingTransaction(
          .reverted(
            reason: "QuietGate could not prove \(normalized) was removed, so it kept the row.",
            nextAction: nil
          ),
          for: controlKey
        )
        present(LegacyProviderReadbackError.ruleTurnedOffButNotConfirmed(normalized))
        return
      }
      do {
        try await refreshLegacyProviderRules(using: client)
      } catch {
        clearLegacyProviderControlVerificationIfCredentialFailure(error)
        let restored = await restoreLegacyProviderRuleIfNeeded(client, domain: normalized)
        setLegacyProviderRulesSyncPending(!restored)
        markLegacyProviderControlVerified()
        connectionState = .connected
        syncBrowserExtensionSettings()
        await refreshDisabledSiteBlockStatus()
        setBlockingTransaction(
          .reverted(
            reason: "QuietGate could not prove \(normalized) was removed, so it kept the row.",
            nextAction: nil
          ),
          for: controlKey
        )
        present(LegacyProviderReadbackError.ruleTurnedOffButNotConfirmed(normalized))
        return
      }
      guard !legacyProviderRulesContains(normalized) else {
        throw LegacyProviderReadbackError.removedDomainStillPresent(normalized)
      }
      try await verifyDomainUnblockedOnThisMac(normalized)
      removePendingLegacyProviderRuleRemoval(normalized)
      markLegacyProviderControlVerified()
      blockedSites = candidateSites
      persistBlockedSites()
      connectionState = .connected
      setLegacyProviderRulesSyncPending(false)
      syncBrowserExtensionSettings()
      await refreshDisabledSiteBlockStatus()
      await refreshActivity(using: client)
      setBlockingTransaction(.verified("\(normalized) was removed."), for: controlKey)
      errorMessage = nil
    } catch {
      clearLegacyProviderControlVerificationIfCredentialFailure(error)
      let normalized = (try? DomainNormalizer.normalize(domain)) ?? domain
      let restored: Bool
      if let client = legacyProviderClientForImmediateSync() {
        restored = await restoreLegacyProviderRuleIfNeeded(client, domain: normalized)
      } else {
        restored = false
      }
      setBlockingTransaction(
        .reverted(
          reason: "QuietGate could not prove \(normalized) was removed, so it kept the row.",
          nextAction: nil
        ),
        for: Self.blockedSiteControlKey(normalized)
      )
      setLegacyProviderRulesSyncPending(!restored)
      present(error)
    }
  }

  func setBlockedSite(_ domain: String, enabled: Bool) async {
    do {
      let normalized = try DomainNormalizer.normalize(domain)
      let controlKey = Self.blockedSiteControlKey(normalized)
      guard let index = blockedSites.firstIndex(where: { $0.domain == normalized }) else {
        if enabled {
          try await addCustomDomain(normalized)
        }
        return
      }

      let wasEnabled = blockedSites[index].isEnabled
      guard !timedSessionLockedActive || enabled || !wasEnabled else {
        refuseLockedTimedSessionChange()
        return
      }
      guard wasEnabled != enabled else {
        return
      }

      if shouldRefreshBlockingCapabilityBeforeMutation {
        setBlockingTransaction(.checkingCapability, for: controlKey)
        await refresh()
      }
      guard requireBlockingControlsReady(controlKey: controlKey) else {
        return
      }

      guard legacyProviderConnectorEnabled else {
        var candidateSites = blockedSites
        candidateSites[index].isEnabled = enabled
        blockedSites = candidateSites
        removePendingLegacyProviderRuleRemoval(normalized)
        persistBlockedSites()
        connectionState = .connected
        syncBrowserExtensionSettings()
        await refreshDisabledSiteBlockStatus()
        setBlockingTransaction(
          .verified(
            enabled
              ? "\(normalized) is on in connected browsers."
              : "\(normalized) is off in QuietGate."
          ),
          for: controlKey
        )
        errorMessage = nil
        return
      }

      guard let client = legacyProviderClientForImmediateSync() else {
        errorMessage = nil
        return
      }

      isWorking = true
      defer { isWorking = false }
      setBlockingTransaction(
        .applying(
          enabled
            ? "Turning \(normalized) on. This can take about a minute."
            : "Turning \(normalized) off. This can take about a minute."
        ),
        for: controlKey
      )

      do {
        if enabled {
          try await addLegacyProviderRule(client, domain: normalized)
        } else {
          try await removeLegacyProviderRule(client, domain: normalized)
        }
      } catch {
        if enabled {
          throw error
        }
        clearLegacyProviderControlVerificationIfCredentialFailure(error)
        let restored = await restoreLegacyProviderRuleIfNeeded(client, domain: normalized)
        setLegacyProviderRulesSyncPending(!restored)
        setBlockingTransaction(
          .reverted(
            reason:
              "QuietGate could not prove \(normalized) turned off, so it put the switch back.",
            nextAction: nil
          ),
          for: controlKey
        )
        present(LegacyProviderReadbackError.ruleTurnedOffButNotConfirmed(normalized))
        return
      }

      do {
        try await refreshLegacyProviderRules(using: client)
      } catch {
        clearLegacyProviderControlVerificationIfCredentialFailure(error)
        if enabled {
          addPendingLegacyProviderRuleRemoval(normalized)
        } else {
          setLegacyProviderRulesSyncPending(true)
        }
        markLegacyProviderControlVerified()
        connectionState = .connected
        syncBrowserExtensionSettings()
        await refreshDisabledSiteBlockStatus()
        setBlockingTransaction(
          .reverted(
            reason:
              "QuietGate could not prove this changed, so it put the switch back.",
            nextAction: nil
          ),
          for: controlKey
        )
        if enabled {
          present(LegacyProviderReadbackError.ruleStatusUnknown(normalized))
        } else {
          present(LegacyProviderReadbackError.ruleTurnedOffButNotConfirmed(normalized))
        }
        return
      }
      if enabled {
        guard legacyProviderRulesContains(normalized) else {
          throw LegacyProviderReadbackError.addedDomainNotConfirmed(normalized)
        }
      } else {
        guard !legacyProviderRulesContains(normalized) else {
          throw LegacyProviderReadbackError.removedDomainStillPresent(normalized)
        }
        try await verifyDomainUnblockedOnThisMac(normalized)
        removePendingLegacyProviderRuleRemoval(normalized)
      }
      markLegacyProviderControlVerified()
      var candidateSites = blockedSites
      candidateSites[index].isEnabled = enabled
      blockedSites = candidateSites
      if enabled {
        removePendingLegacyProviderRuleRemoval(normalized)
      }
      persistBlockedSites()
      connectionState = .connected
      setLegacyProviderRulesSyncPending(false)
      syncBrowserExtensionSettings()
      await refreshDisabledSiteBlockStatus()
      await refreshActivity(using: client)
      setBlockingTransaction(
        .verified(
          enabled
            ? "\(normalized) is on. It can take about a minute to reach your browser."
            : "\(normalized) is off and verified."
        ),
        for: controlKey
      )
      errorMessage = nil
    } catch {
      clearLegacyProviderControlVerificationIfCredentialFailure(error)
      let normalized = (try? DomainNormalizer.normalize(domain)) ?? domain
      let key = Self.blockedSiteControlKey(normalized)
      setBlockingTransaction(
        .reverted(
          reason: "QuietGate could not prove this changed, so it put the switch back.",
          nextAction: nil
        ),
        for: key
      )
      if !enabled {
        let restored: Bool
        if let client = legacyProviderClientForImmediateSync() {
          restored = await restoreLegacyProviderRuleIfNeeded(client, domain: normalized)
        } else {
          restored = false
        }
        setLegacyProviderRulesSyncPending(!restored)
      }
      present(error)
    }
  }

  func deleteBlockedSite(_ domain: String) async {
    await removeCustomDomain(domain)
  }

  func setBlockCategory(_ id: BlockCategoryID, enabled: Bool) async {
    guard id == .adultContent else {
      return
    }

    let current = blockCategoryRule(id).isEnabled
    guard !timedSessionLockedActive || enabled || !current else {
      refuseLockedTimedSessionChange()
      return
    }
    guard current != enabled else {
      return
    }

    _ = await applyProtection(enabled, accessMode: accessMode, requireRuleEditingReady: true)
  }

  func tuningFeatureEnabled(_ feature: BrowserTuningFeature) -> Bool {
    tuningOverrides[feature.rawValue] ?? accessMode.tuningFeatures.contains(feature)
  }

  func setTuningFeature(_ feature: BrowserTuningFeature, enabled: Bool) {
    guard !timedSessionLockedActive else {
      refuseLockedTimedSessionChange()
      return
    }

    let presetEnabled = accessMode.tuningFeatures.contains(feature)
    if enabled == presetEnabled {
      tuningOverrides.removeValue(forKey: feature.rawValue)
    } else {
      tuningOverrides[feature.rawValue] = enabled
    }
    persistTuningOverrides()
    syncBrowserExtensionSettings()
  }

  func setTuningFeatures(_ features: [BrowserTuningFeature], enabled: Bool) {
    guard !timedSessionLockedActive else {
      refuseLockedTimedSessionChange()
      return
    }

    var changed = false
    for feature in features {
      let presetEnabled = accessMode.tuningFeatures.contains(feature)
      if enabled == presetEnabled {
        if tuningOverrides.removeValue(forKey: feature.rawValue) != nil {
          changed = true
        }
      } else if tuningOverrides[feature.rawValue] != enabled {
        tuningOverrides[feature.rawValue] = enabled
        changed = true
      }
    }

    guard changed else {
      return
    }

    persistTuningOverrides()
    syncBrowserExtensionSettings()
  }

  func setExplicitHideStyle(_ style: ExplicitHideStyle) {
    guard !timedSessionLockedActive else {
      refuseLockedTimedSessionChange()
      return
    }

    guard tuningOptions.explicitHideStyle != style else {
      return
    }

    tuningOptions.explicitHideStyle = style
    persistTuningOptions()
    syncBrowserExtensionSettings()
  }

  func setYouTubeDailyLimitMinutes(_ minutes: Int) {
    guard !timedSessionLockedActive else {
      refuseLockedTimedSessionChange()
      return
    }

    let clamped = BrowserTuningOptions.clampedYouTubeDailyLimitMinutes(minutes)
    guard tuningOptions.youtubeDailyLimitMinutes != clamped else {
      return
    }

    tuningOptions.youtubeDailyLimitMinutes = clamped
    persistTuningOptions()
    syncBrowserExtensionSettings()
  }

  func resetTuningOverrides() {
    guard !timedSessionLockedActive else {
      refuseLockedTimedSessionChange()
      return
    }

    tuningOverrides.removeAll()
    persistTuningOverrides()
    syncBrowserExtensionSettings()
  }

  func resetTuningOverrides(for site: BrowserTuningSite) {
    guard !timedSessionLockedActive else {
      refuseLockedTimedSessionChange()
      return
    }

    let siteFeatureIDs = Set(BrowserTuningFeature.features(for: site).map(\.rawValue))
    tuningOverrides = tuningOverrides.filter { !siteFeatureIDs.contains($0.key) }
    persistTuningOverrides()
    syncBrowserExtensionSettings()
  }

  func copyDiagnosticStatus() {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(diagnosticStatusText, forType: .string)
    extensionBridgeMessage = "Status copied."
  }

  func copyChromeExtensionFolderPath() {
    copyBrowserExtensionFolderPath(.chrome)
  }

  func copyBrowserExtensionFolderPath(_ browser: BrowserConnectorID) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(browserExtensionDirectoryURL(for: browser).path, forType: .string)
    if browser == .firefox {
      extensionBridgeMessage =
        "Firefox connection folder copied. In Firefox, click Load Temporary Add-on and choose manifest.json in that folder."
    } else {
      extensionBridgeMessage =
        "Browser extension path copied. In your browser, click Load unpacked and paste it."
    }
  }

  func checkResolverStatus() async {
    guard legacyProviderConnectorEnabled else {
      refreshBrowserFirstStatus()
      return
    }

    isWorking = true
    defer { isWorking = false }

    await updateResolverStatus()
  }

  func checkThisMac() async {
    guard legacyProviderConnectorEnabled else {
      refreshBrowserFirstStatus()
      return
    }

    isWorking = true
    defer { isWorking = false }

    refreshLocalSetupStatus()
    await updateResolverStatus()
  }

  private func updateResolverStatus() async {
    do {
      resolverStatus = try await resolverService.check()
      resolverStatusCheckedAt = nowProvider()
      if resolverStatus?.status.lowercased() == "ok" {
        if case .notConfigured = connectionState {
          connectionState = .misconfigured(
            "This Mac looks partly connected, but QuietGate still needs the connection codes.")
        }
      } else if let status = resolverStatus?.status {
        connectionState = .misconfigured("This Mac connection status is \(status).")
      }
    } catch {
      present(error)
    }
  }

  func createLegacyMacPermissionProfile() {
    do {
      let profileURL = try appleProfileGenerator.writeProfile(profileID: trimmedProfileID)
      generatedAppleProfileURL = profileURL
      defaults.set(profileURL.path, forKey: DefaultsKey.generatedAppleProfilePath)
      setupMessage =
        "Mac approval is ready. Approve QuietGate in System Settings; QuietGate will finish automatically when you return."
      errorMessage = nil
      open(profileURL)
    } catch {
      present(error)
    }
  }

  func createLocalHostsBlockerScript() {
    do {
      let scriptURL = try localHostsScriptGenerator.writeScript(domains: localHostsFallbackDomains)
      generatedHostsScriptURL = scriptURL
      defaults.set(scriptURL.path, forKey: DefaultsKey.generatedHostsScriptPath)
      setupMessage =
        "Backup blocking script created. Open it, choose update, and enter your Mac password."
      errorMessage = nil
    } catch {
      present(error)
    }
  }

  func installLocalBlockerBackup() {
    do {
      isWorking = true
      defer { isWorking = false }
      try localHostsScriptGenerator.installBlocklist(domains: localHostsFallbackDomains)
      persistLocalHostsFallbackFingerprint()
      localHostsFallbackInstalled = localHostsScriptGenerator.localHostsBlocklistInstalled()
      setupMessage = "Backup blocking updated."
      errorMessage = nil
    } catch {
      present(error)
    }
  }

  func removeLocalHostsFallback() {
    guard !timedSessionLockedActive else {
      refuseLockedTimedSessionChange()
      return
    }

    do {
      isWorking = true
      defer { isWorking = false }
      try localHostsScriptGenerator.removeBlocklist()
      clearLocalHostsFallbackFingerprint()
      localHostsFallbackInstalled = localHostsScriptGenerator.localHostsBlocklistInstalled()
      setupMessage = "Backup blocking turned off."
      errorMessage = nil
    } catch {
      present(error)
    }
  }

  func openLocalHostsBlockerScript() {
    guard let scriptURL = generatedHostsScriptURL,
      FileManager.default.fileExists(atPath: scriptURL.path)
    else {
      createLocalHostsBlockerScript()
      return
    }

    open(scriptURL)
  }

  func openSystemProfiles() {
    let candidates = [
      "x-apple.systempreferences:com.apple.Profiles-Settings.extension",
      "x-apple.systempreferences:com.apple.preferences.configurationprofiles",
    ]
    let message = systemProfilesSetupMessage

    for value in candidates {
      guard let url = URL(string: value) else { continue }
      if NSWorkspace.shared.open(url) {
        setupMessage = message
        return
      }
    }

    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    setupMessage = message
  }

  private var systemProfilesSetupMessage: String {
    if legacyMacConnectionProfileMismatch {
      return
        "Device Management is open. Approve QuietGate Blocking if needed, keep the QuietGate approval, then return here."
    }
    return
      "Waiting for approval. Approve QuietGate Blocking in System Settings; QuietGate will finish automatically when you return."
  }

  func openChromeExtensionsPage() {
    openBrowserExtensionsPage(.chrome)
  }

  func openBrowserExtensionsPage(_ browser: BrowserConnectorID) {
    if browser == .firefox {
      openFirefoxDebuggingPage()
      return
    }

    guard let scheme = browser.internalPageScheme,
          let url = URL(string: "\(scheme)://extensions") else { return }
    guard let applicationURL = browserApplicationURL(for: browser) else {
      NSWorkspace.shared.open(url)
      return
    }

    let configuration = NSWorkspace.OpenConfiguration()
    NSWorkspace.shared.open([url], withApplicationAt: applicationURL, configuration: configuration) {
      _, error in
      if error != nil {
        NSWorkspace.shared.open(url)
      }
    }
  }

  func openBuiltInProtectionAction(_ actionURLString: String?) {
    guard let actionURLString,
          let url = URL(string: actionURLString) else {
      return
    }
    open(url)
  }

  private func openFirefoxDebuggingPage() {
    guard let url = URL(string: "about:debugging#/runtime/this-firefox") else {
      return
    }
    guard let applicationURL = browserApplicationURL(for: .firefox) else {
      NSWorkspace.shared.open(url)
      return
    }

    let configuration = NSWorkspace.OpenConfiguration()
    NSWorkspace.shared.open([url], withApplicationAt: applicationURL, configuration: configuration) {
      _, error in
      if error != nil {
        NSWorkspace.shared.open(url)
      }
    }
  }

  func openChromeDownload() {
    openBrowserDownload(.chrome)
  }

  func openBrowserDownload(_ browser: BrowserConnectorID) {
    if let url = browser.downloadURL {
      open(url)
    }
  }

  func revealChromeExtensionFolder() {
    refreshChromeExtensionStatus()
    if chromeExtensionAvailable {
      NSWorkspace.shared.activateFileViewerSelecting([chromeExtensionDirectoryURL])
    } else {
      openBrowserExtensionsPage(.chrome)
    }
  }

  func prepareChromeExtensionInstall() {
    prepareBrowserExtensionInstall(.chrome)
  }

  func prepareBrowserExtensionInstall(_ browser: BrowserConnectorID) {
    refreshChromeExtensionStatus()
    copyBrowserExtensionFolderPath(browser)
    startBrowserProfileRegistrationWatch(for: browser)

    if extensionBridge.extensionAvailable(for: browser) {
      NSWorkspace.shared.activateFileViewerSelecting([browserExtensionDirectoryURL(for: browser)])
    }

    openBrowserExtensionsPage(browser)
  }

  func launchChromeTunerSession() {
    launchBrowserTunerSession(.chrome)
  }

  func launchBrowserTunerSession(_ browser: BrowserConnectorID) {
    Task {
      await launchBrowserTunerSessionAsync(browser)
    }
  }

  func applyPrimaryBrowserChanges() {
    applyBrowserChanges(primaryBrowserConnector.id)
  }

  func applyBrowserChanges(_ browser: BrowserConnectorID) {
    Task {
      await applyBrowserChangesAsync(browser, automatic: false)
    }
  }

  private func applyBrowserChangesAsync(_ browser: BrowserConnectorID, automatic: Bool) async {
    isWorking = true
    defer { isWorking = false }

    do {
      syncBrowserExtensionSettings(refreshStatus: true, announce: false, autoApply: false)
      guard extensionBridge.nativeMessagingHostInstalled(for: browser) else {
        extensionBridgeMessage =
          "Update the \(browser.displayName) connection file before applying browser changes."
        return
      }

      try await openBrowserHelperPage(browser)
      startBrowserProfileRegistrationWatch(for: browser)
      extensionBridgeMessage = "Applying latest settings to \(browser.displayName)..."
      errorMessage = nil

      try? await Task.sleep(nanoseconds: 1_000_000_000)
      refreshChromeExtensionStatus()
      if browserHelperState(for: browser) == .current {
        extensionBridgeMessage = "Applied to \(browser.displayName)."
      } else {
        extensionBridgeMessage =
          automatic
            ? "Saved. Refresh \(browser.displayName) if the page has not updated yet."
            : "Saved. Changes will apply next time \(browser.displayName) opens or reloads QuietGate."
      }
    } catch {
      refreshChromeExtensionStatus()
      extensionBridgeMessage = nil
      present(error)
    }
  }

  private func launchBrowserTunerSessionAsync(_ browser: BrowserConnectorID) async {
    guard extensionBridge.extensionAvailable(for: browser) else {
      extensionBridgeMessage = nil
      errorMessage = "QuietGate browser extension files were not found."
      return
    }

    isWorking = true
    defer { isWorking = false }

    do {
      try extensionBridge.installNativeMessagingHost(for: browser)
      syncBrowserExtensionSettings()
      refreshChromeExtensionStatus()
      startBrowserProfileRegistrationWatch(for: browser)

      let status = browserExtensionStatus(for: browser)
      if status.ready {
        try await openBrowserHelperPage(browser)
        extensionBridgeMessage =
          "\(browser.displayName) opened. If it does not connect automatically, click QuietGate in \(browser.displayName), then return here."
      } else if let storeURL = browser.extensionStoreURL {
        open(storeURL)
        extensionBridgeMessage =
          "Install QuietGate in \(browser.displayName), then return here. QuietGate checks the connection automatically."
      } else if browser == .firefox {
        prepareBrowserExtensionInstall(browser)
        extensionBridgeMessage =
          "Firefox is open. Click This Firefox, Load Temporary Add-on, then choose manifest.json in the copied QuietGate folder."
      } else if browserRunningChecker(browser) {
        copyBrowserExtensionFolderPath(browser)
        NSWorkspace.shared.activateFileViewerSelecting([browserExtensionDirectoryURL(for: browser)])
        openBrowserExtensionsPage(browser)
        extensionBridgeMessage =
          "\(browser.displayName) is open. Turn on Developer mode, click Load unpacked, and choose the copied QuietGate folder."
      } else {
        let selectedProfile = status.selectedProfile ?? "Default"
        try await openBrowserWithTuner(browser, profile: selectedProfile)
        extensionBridgeMessage =
          "\(browser.displayName) opened with QuietGate for this session. Add QuietGate from the Extensions page later if you want it to stay connected after restart."
      }

      errorMessage = nil
      try? await Task.sleep(nanoseconds: 1_000_000_000)
      refreshChromeExtensionStatus()
    } catch {
      refreshChromeExtensionStatus()
      extensionBridgeMessage = nil
      present(error)
    }
  }

  func installChromeBridge() {
    installBrowserBridge(.chrome)
  }

  func installBrowserBridge(_ browser: BrowserConnectorID) {
    do {
      try extensionBridge.installNativeMessagingHost(for: browser)
      syncBrowserExtensionSettings()
      refreshChromeExtensionStatus()
      startBrowserProfileRegistrationWatch(for: browser)
      extensionBridgeMessage = "\(browser.displayName) is ready. Open \(browser.displayName) so it can confirm the latest settings."
      errorMessage = nil
    } catch {
      refreshChromeExtensionStatus()
      extensionBridgeMessage = nil
      present(error)
    }
  }

  func refreshChromeExtensionStatus() {
    let settingsVersion =
      defaults.string(forKey: DefaultsKey.browserSettingsVersion) ?? currentBrowserSettingsVersion
    let now = nowProvider()
    for browser in supportedBrowserIDs {
      let installed = extensionBridge.nativeMessagingHostInstalled(for: browser)
      let status = effectiveBrowserExtensionStatus(
        extensionBridge.extensionStatus(for: browser),
        for: browser
      )
      let snapshot = extensionBridge.helperSnapshot(for: browser)
      let helperState = extensionBridge.helperState(
        for: browser,
        currentSettingsVersion: settingsVersion,
        now: now,
        extensionStatus: status
      )
      browserBridgeInstalled[browser] = installed
      browserExtensionStatuses[browser] = status
      browserHelperSnapshots[browser] = snapshot
      browserHelperStates[browser] = helperState
    }

    chromeBridgeInstalled = browserBridgeInstalled[.chrome] ?? false
    chromeExtensionStatus = browserExtensionStatuses[.chrome] ?? .empty
    chromeExtensionLoaded = chromeExtensionStatus.ready
    chromeHelperSnapshot = browserHelperSnapshots[.chrome]
    chromeHelperState = browserHelperStates[.chrome] ?? .notInstalled
    chromeBridgeResponding = chromeHelperState == .current
  }

  private func effectiveBrowserExtensionStatus(
    _ status: ChromeExtensionStatus,
    for browser: BrowserConnectorID
  ) -> ChromeExtensionStatus {
    guard let launchedProfile = launchedBrowserSessionProfiles[browser] else {
      return status
    }

    guard browserRunningChecker(browser) else {
      launchedBrowserSessionProfiles.removeValue(forKey: browser)
      return status
    }

    return status.addingSessionProfile(launchedProfile)
  }

  func noteLaunchedBrowserSession(_ browser: BrowserConnectorID, profile: String) {
    let profile = profile.trimmingCharacters(in: .whitespacesAndNewlines)
    guard browser != .firefox, !profile.isEmpty else {
      return
    }

    launchedBrowserSessionProfiles[browser] = profile
  }

  private func startBrowserStatusMonitoring() {
    browserStatusMonitor.start(
      watchURLsProvider: { [weak self] in
        guard let self else {
          return []
        }
        return self.supportedBrowserIDs.flatMap { browser in
          self.extensionBridge.statusWatchURLs(for: browser)
        }
      },
      onChange: { [weak self] in
        self?.handleBrowserStatusMonitorChange()
      }
    )
  }

  private func handleBrowserStatusMonitorChange() {
    refreshChromeExtensionStatus()
    evaluateBrowserProfileWatch()
  }

  func startBrowserProfileRegistrationWatch(for browser: BrowserConnectorID) {
    refreshChromeExtensionStatus()
    browserProfilePollTask?.cancel()
    browserProfileWatchSession = BrowserProfileWatchSession(
      browser: browser,
      baseline: browserProfileDetectionSnapshot(for: browser),
      deadline: nowProvider().addingTimeInterval(Self.browserProfileWatchTimeout)
    )
    browserProfileWatchBrowser = browser
    browserProfileWatchMessage = "Watching for a new \(browser.displayName) profile..."
    browserProfilePollTask = Task { [weak self] in
      while !Task.isCancelled {
        do {
          try await Task.sleep(nanoseconds: Self.browserProfilePollInterval)
        } catch {
          return
        }
        await MainActor.run {
          self?.pollBrowserProfileWatch()
        }
      }
    }
  }

  private func pollBrowserProfileWatch() {
    refreshChromeExtensionStatus()
    evaluateBrowserProfileWatch()
  }

  private func evaluateBrowserProfileWatch() {
    guard let session = browserProfileWatchSession else {
      return
    }

    let current = browserProfileDetectionSnapshot(for: session.browser)
    if browserProfileWatchDetected(baseline: session.baseline, current: current) {
      finishBrowserProfileWatch(
        message: browserProfileDetectedMessage(for: session.browser)
      )
      return
    }

    if nowProvider() >= session.deadline {
      finishBrowserProfileWatch(
        message: "Still waiting for \(session.browser.displayName) to report the profile. Open the QuietGate extension in that profile or press Update Status."
      )
    }
  }

  private func finishBrowserProfileWatch(message: String) {
    browserProfilePollTask?.cancel()
    browserProfilePollTask = nil
    browserProfileWatchSession = nil
    browserProfileWatchBrowser = nil
    browserProfileWatchMessage = message
  }

  private func browserProfileWatchDetected(
    baseline: BrowserProfileDetectionSnapshot,
    current: BrowserProfileDetectionSnapshot
  ) -> Bool {
    current.selectedProfileLabel != baseline.selectedProfileLabel
      || current.connectedProfileLabels != baseline.connectedProfileLabels
      || (!baseline.helperState.isCurrent && current.helperState.isCurrent)
  }

  private func browserProfileDetectedMessage(for browser: BrowserConnectorID) -> String {
    let connector = browserConnector(for: browser)
    if let scopeText = connector.profileScopeText {
      return "\(scopeText) registered."
    }
    return "\(browser.displayName) profile registered."
  }

  private func browserProfileDetectionSnapshot(
    for browser: BrowserConnectorID
  ) -> BrowserProfileDetectionSnapshot {
    let status = browserExtensionStatuses[browser] ?? .empty
    let helperState = browserHelperStates[browser] ?? .notInstalled
    return BrowserProfileDetectionSnapshot(
      selectedProfileLabel: status.selectedProfileLabel,
      connectedProfileLabels: status.readyProfileLabels,
      helperState: helperState
    )
  }

  func refreshBuiltInProtections() async {
    if let task = builtInProtectionsRefreshTask {
      builtInProtectionsSnapshot = await task.value
      return
    }

    let primary = primaryBrowserConnector.id
    let browserSnapshot = browserHelperSnapshots[primary] ?? chromeHelperSnapshot
    let quietGateTunersReady = browserBlockingConnected
    let now = nowProvider()
    let checker = platformControlsChecker
    let task = Task {
      await checker.snapshot(
        browserSnapshot: browserSnapshot,
        quietGateTunersReady: quietGateTunersReady,
        now: now
      )
    }
    builtInProtectionsRefreshTask = task
    let snapshot = await task.value
    builtInProtectionsSnapshot = snapshot
    builtInProtectionsRefreshTask = nil
  }

  func refreshAppUpdateStatus() {
    appUpdateInfo = appUpdateService.availableUpdate()
  }

  func relaunchToInstalledUpdate() {
    Task {
      await performInstalledAppUpdate()
    }
  }

  func performInstalledAppUpdate() async {
    guard let update = appUpdateInfo else {
      return
    }

    isWorking = true
    defer { isWorking = false }

    do {
      try await appUpdateService.relaunch(using: update)
      setupMessage = "Opened QuietGate \(update.installedVersion.displayText)."
      errorMessage = nil
      refreshAppUpdateStatus()
    } catch {
      refreshAppUpdateStatus()
      present(error)
    }
  }

  func refreshLocalSetupStatus() {
    if legacyProviderConnectorEnabled {
      let legacyProviderProfileStatus = systemProfileChecker.legacyProviderProfileStatus(profileID: trimmedProfileID)
      macOSLegacyProviderProfileInstalled = legacyProviderProfileStatus.anyLegacyProviderProfileInstalled
      macOSConfiguredLegacyProviderProfileInstalled =
        legacyProviderProfileStatus.configuredLegacyProviderProfileInstalled
    } else {
      macOSLegacyProviderProfileInstalled = false
      macOSConfiguredLegacyProviderProfileInstalled = false
      resolverStatus = nil
      resolverStatusCheckedAt = nil
    }
    localHostsFallbackInstalled = localHostsScriptGenerator.localHostsBlocklistInstalled()
    if !localHostsFallbackInstalled {
      clearLocalHostsFallbackFingerprint()
    }
    refreshChromeExtensionStatus()
  }

  private func refreshBrowserFirstStatus() {
    macOSLegacyProviderProfileInstalled = false
    macOSConfiguredLegacyProviderProfileInstalled = false
    resolverStatus = nil
    resolverStatusCheckedAt = nil
    parentalControl = nil
    clearLegacyProviderRulesReadback()
    clearPendingLegacyProviderRuleRemovals()
    blockedLogs = []
    analyticsStatus = []
    domainResolutionStatuses = [:]
    syncBrowserExtensionSettingsIfNeeded(refreshStatus: false, announce: false)
    refreshLocalSetupStatus()
    connectionState = .connected
    errorMessage = nil
  }

  func performReadinessAction(_ action: ReadinessAction) {
    switch action {
    case .allowSavedProviderCredentialAccess:
      Task { await allowSavedProviderCredentialAccess() }
    case .refreshProtectionStatus:
      Task { await refreshProtectionStatus() }
    case .openLegacyProviderAccount:
      openLegacyProviderAccount()
    case .openLegacyMacPermissionSetup:
      openLegacyMacPermissionSetup()
    case .createLegacyMacPermissionProfile:
      createLegacyMacPermissionProfile()
    case .openSystemProfiles:
      openSystemProfiles()
    case .checkThisMac:
      Task { await checkThisMac() }
    case .checkLegacyMacConnection:
      Task { await checkResolverStatus() }
    case .installLocalBlockerBackup:
      installLocalBlockerBackup()
    case .launchChromeTunerSession:
      launchChromeTunerSession()
    case .openChromeDownload:
      openChromeDownload()
    case .showChromeExtensionFolder:
      prepareChromeExtensionInstall()
    case .installChromeSync:
      installChromeBridge()
    case .applyBrowserChanges(let browser):
      applyBrowserChanges(browser)
    case .openBrowserExtensionsPage(let browser):
      openBrowserExtensionsPage(browser)
    case .launchBrowserTunerSession(let browser):
      launchBrowserTunerSession(browser)
    case .openBrowserDownload(let browser):
      openBrowserDownload(browser)
    case .installBrowserSync(let browser):
      installBrowserBridge(browser)
    }
  }

  private func refreshActivity(using client: LegacyProviderServicing) async {
    do {
      blockedLogs = try await client.blockedLogs(profileID: profileID, limit: 50)
    } catch {
      if !Self.isCancellation(error) {
        errorMessage = error.localizedDescription
      }
    }

    do {
      analyticsStatus = try await client.analyticsStatus(profileID: profileID)
    } catch {
      if !Self.isCancellation(error) {
        errorMessage = error.localizedDescription
      }
    }
  }

  private func configuredClient() throws -> LegacyProviderServicing {
    let trimmedProfileID = profileID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedProfileID.isEmpty else {
      throw LegacyProviderError.notConfigured
    }

    let apiKey: String?
    if let cachedAPIKey, !cachedAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      apiKey = cachedAPIKey
    } else {
      do {
        apiKey = try keychain.readSecret(allowUserInteraction: false)
        cachedAPIKey = apiKey
        legacyProviderKeyNeedsPermission = false
      } catch KeychainError.unavailableWithoutUserInteraction {
        legacyProviderKeyNeedsPermission = true
        clearLegacyProviderControlVerification()
        throw KeychainError.unavailableWithoutUserInteraction
      }
    }

    guard let apiKey,
      !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      throw LegacyProviderError.notConfigured
    }

    profileID = trimmedProfileID
    return makeClient(apiKey)
  }

  private func legacyProviderClientForImmediateSync() -> LegacyProviderServicing? {
    do {
      return try configuredClient()
    } catch KeychainError.unavailableWithoutUserInteraction {
      legacyProviderKeyNeedsPermission = true
      clearLegacyProviderControlVerification()
      return nil
    } catch LegacyProviderError.notConfigured {
      clearLegacyProviderControlVerification()
      connectionState = .notConfigured
      return nil
    } catch {
      clearLegacyProviderControlVerificationIfCredentialFailure(error)
      connectionState = .error(error.localizedDescription)
      present(error)
      return nil
    }
  }

  private func refreshLegacyProviderRules(using client: LegacyProviderServicing) async throws {
    legacyProviderRules = try await client.getDenylist(profileID: profileID)
    legacyProviderRulesCheckedAt = nowProvider()
    clearConfirmedPendingLegacyProviderRuleRemovals()
  }

  private func refreshDisabledSiteBlockStatus() async {
    guard legacyProviderConnectorEnabled else {
      domainResolutionStatuses = [:]
      return
    }
    let domains = disabledBlockedSites.map(\.domain).sorted()
    guard !domains.isEmpty else {
      domainResolutionStatuses = [:]
      return
    }

    var statuses: [String: DomainResolutionStatus] = [:]
    for domain in domains {
      let addresses = await domainResolver.addresses(for: domain)
      statuses[domain] = DomainResolutionStatus(domain: domain, addresses: addresses)
    }
    domainResolutionStatuses = statuses
  }

  private func verifyDomainUnblockedOnThisMac(_ domain: String) async throws {
    let addresses = await domainResolver.addresses(for: domain)
    let status = DomainResolutionStatus(domain: domain, addresses: addresses)
    if status.isSinkholed {
      throw LegacyProviderReadbackError.ruleTurnedOffButMacStillBlocks(domain)
    }
    if status.isInconclusive {
      throw LegacyProviderReadbackError.ruleTurnedOffButProofInconclusive(domain)
    }
  }

  private func clearLegacyProviderRulesReadback() {
    legacyProviderRules = []
    legacyProviderRulesCheckedAt = nil
    parentalControlCheckedAt = nil
  }

  private func legacyProviderRulesNeedsSync() -> Bool {
    legacyProviderRulesNeedsSync(sites: blockedSites, categories: blockCategories)
  }

  private func legacyProviderRulesNeedsSync(
    sites: [BlockedSiteRule],
    categories: [BlockCategoryRule]
  ) -> Bool {
    let desired = Self.activeBlockedDomainSet(sites: sites, categories: categories)
    let removable = removableManagedDenylistDomains(sites: sites, categories: categories)
    let activeDomains = activeLegacyProviderRuleDomains
    return desired.contains { !legacyProviderRulesContains($0, in: activeDomains) }
      || removable.contains { legacyProviderRulesContains($0, in: activeDomains) }
  }

  private func removableManagedDenylistDomains(
    sites: [BlockedSiteRule],
    categories: [BlockCategoryRule]
  ) -> Set<String> {
    let desired = Self.activeBlockedDomainSet(sites: sites, categories: categories)
    return Self.managedDenylistDomainSet(sites: sites)
      .union(pendingLegacyProviderRuleRemovals)
      .subtracting(desired)
  }

  private func legacyProviderReadbackConfirmsSavedRules() -> Bool {
    legacyProviderReadbackConfirmsSavedRules(sites: blockedSites, categories: blockCategories)
  }

  private func legacyProviderReadbackConfirmsSavedRules(
    sites: [BlockedSiteRule],
    categories: [BlockCategoryRule]
  ) -> Bool {
    let categoryConfirmed: Bool
    let adultEnabled = categories.first { $0.id == .adultContent }?.isEnabled == true
    if adultEnabled {
      categoryConfirmed = parentalControl?.isQuietGateEnabled == true
    } else {
      categoryConfirmed = parentalControl?.quietGateManagedRestrictionActive != true
    }
    return categoryConfirmed && !legacyProviderRulesNeedsSync(sites: sites, categories: categories)
  }

  private func addLegacyProviderRule(
    _ client: LegacyProviderServicing,
    domain: String
  ) async throws {
    do {
      _ = try await client.addDenylist(profileID: profileID, domain: domain)
    } catch LegacyProviderError.httpStatus(let status) where status == 409 {
      return
    } catch LegacyProviderError.api(let details)
      where details.contains(where: { Self.isDuplicateDenylistError($0) })
    {
      return
    }
  }

  private func removeLegacyProviderRule(
    _ client: LegacyProviderServicing,
    domain: String
  ) async throws {
    do {
      try await client.removeDenylist(profileID: profileID, domain: domain)
    } catch LegacyProviderError.httpStatus(let status) where status == 404 {
      return
    } catch LegacyProviderError.api(let details)
      where details.contains(where: { Self.isMissingDenylistError($0) })
    {
      return
    }
  }

  private func applyLegacyProviderRules(
    _ client: LegacyProviderServicing,
    sites: [BlockedSiteRule],
    categories: [BlockCategoryRule]
  ) async throws {
    let desired = Self.activeBlockedDomainSet(sites: sites, categories: categories)
    let removable = removableManagedDenylistDomains(sites: sites, categories: categories)
    var activeDomains = activeLegacyProviderRuleDomains

    for domain in desired.sorted() {
      if !legacyProviderRulesContains(domain, in: activeDomains) {
        try await addLegacyProviderRule(client, domain: domain)
        if let normalized = Self.normalizedReadbackDomain(domain) {
          activeDomains.insert(normalized)
        }
      }
      if pendingLegacyProviderRuleRemovalContains(domain) {
        removePendingLegacyProviderRuleRemoval(domain)
      }
    }

    for domain in removable.sorted() {
      if legacyProviderRulesContains(domain, in: activeDomains) {
        try await removeLegacyProviderRule(client, domain: domain)
        if let normalized = Self.normalizedReadbackDomain(domain) {
          activeDomains.remove(normalized)
        }
      }
      if pendingLegacyProviderRuleRemovalContains(domain) {
        removePendingLegacyProviderRuleRemoval(domain)
      }
    }
  }

  private func restoreLegacyProviderRuleIfNeeded(
    _ client: LegacyProviderServicing,
    domain: String
  ) async -> Bool {
    if legacyProviderRulesContains(domain) {
      return true
    }
    do {
      try await addLegacyProviderRule(client, domain: domain)
      try await refreshLegacyProviderRules(using: client)
      return legacyProviderRulesContains(domain)
    } catch {
      return false
    }
  }

  private static func isDuplicateDenylistError(_ detail: LegacyProviderAPIErrorDetail) -> Bool {
    let text = "\(detail.code) \(detail.detail)".lowercased()
    return text.contains("already") || text.contains("duplicate") || text.contains("exists")
  }

  private static func isMissingDenylistError(_ detail: LegacyProviderAPIErrorDetail) -> Bool {
    let text = "\(detail.code) \(detail.detail)".lowercased()
    return text.contains("not found") || text.contains("missing") || text.contains("does not exist")
  }

  private func markLegacyProviderControlVerified() {
    let profileID = trimmedProfileID
    guard configured, !profileID.isEmpty else {
      clearLegacyProviderControlVerification()
      return
    }
    legacyProviderVerifiedProfileID = profileID
    defaults.set(profileID, forKey: DefaultsKey.legacyProviderVerifiedProfileID)
  }

  private func clearLegacyProviderControlVerification() {
    legacyProviderVerifiedProfileID = nil
    defaults.removeObject(forKey: DefaultsKey.legacyProviderVerifiedProfileID)
  }

  private func clearLegacyProviderControlVerificationIfCredentialFailure(_ error: Error) {
    guard Self.invalidatesLegacyProviderControlVerification(error) else {
      return
    }
    clearLegacyProviderControlVerification()
  }

  private static func invalidatesLegacyProviderControlVerification(_ error: Error) -> Bool {
    switch error {
    case KeychainError.unavailableWithoutUserInteraction:
      return true
    case LegacyProviderError.notConfigured:
      return true
    case LegacyProviderError.httpStatus(let status):
      return status == 401 || status == 403 || status == 404
    default:
      return false
    }
  }

  private func setLegacyProviderRulesSyncPending(_ pending: Bool) {
    let effectivePending = pending || !pendingLegacyProviderRuleRemovals.isEmpty
    legacyProviderRulesSyncPending = effectivePending
    if effectivePending {
      defaults.set(true, forKey: DefaultsKey.legacyProviderRulesSyncPending)
    } else {
      defaults.removeObject(forKey: DefaultsKey.legacyProviderRulesSyncPending)
    }
  }

  private func addPendingLegacyProviderRuleRemoval(_ domain: String) {
    pendingLegacyProviderRuleRemovals.insert(domain)
    persistPendingLegacyProviderRuleRemovals()
    setLegacyProviderRulesSyncPending(true)
  }

  private func removePendingLegacyProviderRuleRemoval(_ domain: String) {
    guard pendingLegacyProviderRuleRemovals.remove(domain) != nil else {
      return
    }
    persistPendingLegacyProviderRuleRemovals()
    setLegacyProviderRulesSyncPending(false)
  }

  private func clearConfirmedPendingLegacyProviderRuleRemovals() {
    let activeDomains = activeLegacyProviderRuleDomains
    let confirmedRemoved = pendingLegacyProviderRuleRemovals.filter {
      !legacyProviderRulesContains($0, in: activeDomains)
    }
    guard !confirmedRemoved.isEmpty else {
      return
    }
    pendingLegacyProviderRuleRemovals.subtract(confirmedRemoved)
    persistPendingLegacyProviderRuleRemovals()
    setLegacyProviderRulesSyncPending(legacyProviderRulesNeedsSync())
  }

  private func clearPendingLegacyProviderRuleRemovals() {
    pendingLegacyProviderRuleRemovals.removeAll()
    defaults.removeObject(forKey: DefaultsKey.pendingLegacyProviderRuleRemovals)
    setLegacyProviderRulesSyncPending(false)
  }

  private func syncPendingLegacyProviderRules() async {
    guard legacyProviderRulesSyncPending, configured,
          legacyProviderBlockConnectorReady,
          let client = legacyProviderClientForImmediateSync()
    else {
      return
    }

    do {
      let current = try await client.getParentalControl(profileID: profileID)
      parentalControlCheckedAt = nowProvider()
      let baseline = savedBaseline()
      let target = adultContentBlockingEnabled
        ? current.applyingQuietGateEnabled()
        : (baseline ?? current).applyingQuietGateDisabled()
      parentalControl = try await client.patchParentalControl(profileID: profileID, value: target)
      parentalControlCheckedAt = nowProvider()

      try await applyLegacyProviderRules(
        client,
        sites: blockedSites,
        categories: blockCategories
      )
      try await refreshLegacyProviderRules(using: client)
      await updateResolverStatus()
      guard legacyProviderReadbackConfirmsSavedRules() else {
        throw LegacyProviderReadbackError.pendingRulesNotConfirmed
      }
      mode = adultContentBlockingEnabled ? .on : .off
      markLegacyProviderControlVerified()
      connectionState = .connected
      setLegacyProviderRulesSyncPending(false)
      errorMessage = nil
      syncBrowserExtensionSettings()
      await refreshDisabledSiteBlockStatus()
      await refreshActivity(using: client)
    } catch {
      clearLegacyProviderControlVerificationIfCredentialFailure(error)
      connectionState = .error(error.localizedDescription)
      setLegacyProviderRulesSyncPending(true)
      await refreshDisabledSiteBlockStatus()
      present(error)
    }
  }

  private func ensureBaseline(_ value: ParentalControl) {
    guard savedBaseline() == nil,
      let encoded = try? JSONEncoder().encode(value.applyingQuietGateDisabled())
    else {
      return
    }
    defaults.set(encoded, forKey: DefaultsKey.baseline)
  }

  private func savedBaseline() -> ParentalControl? {
    guard let data = defaults.data(forKey: DefaultsKey.baseline) else { return nil }
    return try? JSONDecoder().decode(ParentalControl.self, from: data)
  }

  private func persistAccessMode(
    _ value: AccessMode,
    resetTuningOverrides: Bool = false,
    syncBrowserSettings: Bool = true
  ) {
    accessMode = value
    defaults.set(value.rawValue, forKey: DefaultsKey.accessMode)
    if resetTuningOverrides {
      tuningOverrides.removeAll()
      defaults.removeObject(forKey: DefaultsKey.tuningOverrides)
    }
    if syncBrowserSettings {
      syncBrowserExtensionSettings()
    }
  }

  private func persistTimedSession() {
    if let timedSessionEndDate, let timedSessionMode {
      defaults.set(timedSessionEndDate, forKey: DefaultsKey.timedSessionEndDate)
      defaults.set(timedSessionMode.rawValue, forKey: DefaultsKey.timedSessionMode)
      defaults.set(timedSessionLocked, forKey: DefaultsKey.timedSessionLocked)
    } else {
      defaults.removeObject(forKey: DefaultsKey.timedSessionEndDate)
      defaults.removeObject(forKey: DefaultsKey.timedSessionMode)
      defaults.removeObject(forKey: DefaultsKey.timedSessionLocked)
    }
  }

  private func clearTimedSession() {
    timedSessionTimer?.invalidate()
    timedSessionTimer = nil
    timedSessionEndDate = nil
    timedSessionMode = nil
    timedSessionLocked = false
    persistTimedSession()
  }

  private func refuseLockedTimedSessionChange() {
    errorMessage =
      "\(timedSessionStatusLine). Locked sessions cannot be changed until the timer ends."
  }

  private func scheduleTimedSessionTimer() {
    timedSessionTimer?.invalidate()
    timedSessionTimer = nil
    guard let timedSessionEndDate,
      let timedSessionMode,
      timedSessionMode != .open
    else {
      return
    }

    let interval = max(1, timedSessionEndDate.timeIntervalSince(nowProvider()))
    timedSessionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) {
      [weak self] _ in
      Task { @MainActor in
        await self?.expireTimedSessionIfNeeded()
      }
    }
  }

  private func persistFocusWindows() {
    if focusWindows.isEmpty {
      defaults.removeObject(forKey: DefaultsKey.focusWindows)
      return
    }

    if let data = try? JSONEncoder().encode(focusWindows) {
      defaults.set(data, forKey: DefaultsKey.focusWindows)
    }
  }

  private func setActiveFocusWindowID(_ id: UUID?) {
    activeFocusWindowID = id
    persistFocusWindowID(id, key: DefaultsKey.activeFocusWindowID)
  }

  private func setSuppressedFocusWindowID(_ id: UUID?) {
    suppressedFocusWindowID = id
    persistFocusWindowID(id, key: DefaultsKey.suppressedFocusWindowID)
  }

  private func persistFocusWindowID(_ id: UUID?, key: String) {
    if let id {
      defaults.set(id.uuidString, forKey: key)
    } else {
      defaults.removeObject(forKey: key)
    }
  }

  private func persistBlockedSites() {
    if blockedSites.isEmpty {
      defaults.removeObject(forKey: DefaultsKey.blockedSites)
      return
    }

    let values = blockedSites.map { rule in
      [
        "domain": rule.domain,
        "isEnabled": rule.isEnabled,
      ] as [String: Any]
    }
    defaults.set(values, forKey: DefaultsKey.blockedSites)
  }

  private func restoreUnconfirmedDenylistRemovals() {
    guard !pendingLegacyProviderRuleRemovals.isEmpty else {
      return
    }

    var rulesByDomain = Dictionary(uniqueKeysWithValues: blockedSites.map { ($0.domain, $0) })
    for domain in pendingLegacyProviderRuleRemovals {
      rulesByDomain[domain] = BlockedSiteRule(domain: domain, isEnabled: false)
    }

    blockedSites = rulesByDomain.values.sorted { $0.domain < $1.domain }
    persistBlockedSites()
    setLegacyProviderRulesSyncPending(true)
  }

  @discardableResult
  private func requireBlockRuleEditingReady() -> Bool {
    guard blockRuleEditingReady else {
      errorMessage = blockRuleEditingUnavailableReason
      return false
    }
    return true
  }

  @discardableResult
  private func requireBlockingControlsReady(controlKey: String) -> Bool {
    guard blockingControlsReady else {
      let reason =
        blockingCapabilityUnavailableReason
        ?? "QuietGate needs a fresh connection check before using blocking controls."
      let transaction = BlockingControlTransactionState.reverted(
        reason: reason,
        nextAction: "Open Setup"
      )
      lastBlockingTransaction = transaction
      blockingControlTransactions[controlKey] = transaction
      errorMessage = reason
      return false
    }
    return true
  }

  private func setBlockingTransaction(
    _ state: BlockingControlTransactionState,
    for controlKey: String
  ) {
    lastBlockingTransaction = state
    blockingControlTransactions[controlKey] = state
  }

  private func clearBlockingTransaction(for controlKey: String) {
    blockingControlTransactions[controlKey] = .idle
  }

  func blockingTransaction(for controlKey: String) -> BlockingControlTransactionState {
    blockingControlTransactions[controlKey] ?? .idle
  }

  func blockedSiteTransaction(_ domain: String) -> BlockingControlTransactionState {
    blockingTransaction(for: Self.blockedSiteControlKey(domain))
  }

  func blockCategoryTransaction(_ id: BlockCategoryID) -> BlockingControlTransactionState {
    blockingTransaction(for: Self.blockCategoryControlKey(id))
  }

  private static func blockedSiteControlKey(_ domain: String) -> String {
    "site:\(domain)"
  }

  private static func blockCategoryControlKey(_ id: BlockCategoryID) -> String {
    "category:\(id.rawValue)"
  }

  private static let accessModeControlKey = "mode"
  private static let timedSessionControlKey = "timedSession"
  private static let focusWindowsControlKey = "focusWindows"

  private func persistPendingLegacyProviderRuleRemovals() {
    if pendingLegacyProviderRuleRemovals.isEmpty {
      defaults.removeObject(forKey: DefaultsKey.pendingLegacyProviderRuleRemovals)
    } else {
      defaults.set(
        pendingLegacyProviderRuleRemovals.sorted(),
        forKey: DefaultsKey.pendingLegacyProviderRuleRemovals
      )
    }
  }

  private func persistBlockCategories() {
    categoryPreferencesHaveBeenSaved = true
    let values = blockCategories.map { rule in
      [
        "id": rule.id.rawValue,
        "isEnabled": rule.isEnabled,
      ] as [String: Any]
    }
    defaults.set(values, forKey: DefaultsKey.blockCategories)
  }

  private var activeBlocklistFingerprint: String {
    localHostsFallbackDomains.joined(separator: "\n")
  }

  private func persistLocalHostsFallbackFingerprint() {
    defaults.set(activeBlocklistFingerprint, forKey: DefaultsKey.localHostsFallbackFingerprint)
  }

  private func clearLocalHostsFallbackFingerprint() {
    defaults.removeObject(forKey: DefaultsKey.localHostsFallbackFingerprint)
  }

  private func blockCategoryRule(_ id: BlockCategoryID) -> BlockCategoryRule {
    blockCategories.first { $0.id == id } ?? BlockCategoryRule(id: id, isEnabled: false)
  }

  private func blockedSiteEnabled(_ domain: String) -> Bool {
    guard let normalized = try? DomainNormalizer.normalize(domain) else {
      return false
    }
    return blockedSites.first { $0.domain == normalized }?.isEnabled == true
  }

  private func startFocusWindowMonitoring() {
    scheduleFocusWindowTimer()
  }

  private func scheduleFocusWindowTimer() {
    focusWindowTimer?.invalidate()
    focusWindowTimer = nil
    guard focusWindowScheduleEnabled, !focusWindows.isEmpty else {
      return
    }

    let boundarySeconds = focusWindows
      .filter { $0.isEnabled && $0.startMinute != $0.endMinute }
      .flatMap { [$0.startMinute, $0.endMinute] }
      .map { Self.secondsUntil(minuteOfDay: $0, from: nowProvider()) }
      .min()

    guard let boundarySeconds else {
      return
    }

    focusWindowTimer = Timer.scheduledTimer(withTimeInterval: max(1, boundarySeconds), repeats: false) { [weak self] _ in
      Task { @MainActor in
        await self?.expireTimedSessionIfNeeded()
        await self?.evaluateFocusWindowSchedule()
        self?.scheduleFocusWindowTimer()
      }
    }
  }

  @discardableResult
  private func applyFocusWindowScheduleIfNeeded() async -> Bool {
    guard focusWindowScheduleEnabled else {
      if activeFocusWindowID != nil {
        let previous = activeFocusWindowID
        setActiveFocusWindowID(nil)
        if await applyAccessModeSelection(.open) == false {
          setActiveFocusWindowID(previous)
        }
      }
      return false
    }

    guard !timedSessionActive else {
      return false
    }

    let activeWindow = currentFocusWindow()
    if suppressedFocusWindowID != nil && suppressedFocusWindowID != activeWindow?.id {
      setSuppressedFocusWindowID(nil)
    }

    guard let activeWindow else {
      if activeFocusWindowID != nil {
        let previous = activeFocusWindowID
        setActiveFocusWindowID(nil)
        if await applyAccessModeSelection(.open) == false {
          setActiveFocusWindowID(previous)
        }
      }
      return false
    }

    guard suppressedFocusWindowID != activeWindow.id else {
      return false
    }

    if activeFocusWindowID != activeWindow.id || accessMode != activeWindow.mode {
      let previous = activeFocusWindowID
      setActiveFocusWindowID(activeWindow.id)
      if await applyAccessModeSelection(activeWindow.mode) == false {
        setActiveFocusWindowID(previous)
        return false
      }
    }
    return true
  }

  private func suppressCurrentFocusWindowIfNeeded(forManualMode newMode: AccessMode) {
    guard let activeWindow = currentFocusWindow(),
      focusWindowScheduleEnabled,
      newMode != activeWindow.mode
    else {
      return
    }
    setSuppressedFocusWindowID(activeWindow.id)
  }

  private func currentFocusWindow() -> FocusWindow? {
    let minute = Self.minuteOfDay(from: nowProvider())
    return
      focusWindows
      .filter { $0.contains(minute: minute) }
      .sorted { lhs, rhs in
        if lhs.mode == rhs.mode {
          return lhs.startMinute > rhs.startMinute
        }
        return lhs.mode == .strict
      }
      .first
  }

  private func nextFocusWindow() -> FocusWindow? {
    let minute = Self.minuteOfDay(from: nowProvider())
    return
      focusWindows
      .filter(\.isEnabled)
      .sorted { lhs, rhs in
        Self.minutesUntil(startMinute: lhs.startMinute, from: minute)
          < Self.minutesUntil(startMinute: rhs.startMinute, from: minute)
      }
      .first
  }

  private func persistTuningOverrides() {
    if tuningOverrides.isEmpty {
      defaults.removeObject(forKey: DefaultsKey.tuningOverrides)
    } else {
      defaults.set(tuningOverrides, forKey: DefaultsKey.tuningOverrides)
    }
  }

  private func persistTuningOptions() {
    if tuningOptions == .defaultValue {
      defaults.removeObject(forKey: DefaultsKey.tuningOptions)
      return
    }

    if let data = try? JSONEncoder().encode(tuningOptions) {
      defaults.set(data, forKey: DefaultsKey.tuningOptions)
    }
  }

  private func syncBrowserExtensionSettings(
    refreshStatus: Bool = true,
    announce: Bool = true,
    autoApply: Bool = true
  ) {
    let settings = currentBrowserTuningSettings
    syncBrowserExtensionSettings(
      settings,
      refreshStatus: refreshStatus,
      announce: announce,
      autoApply: autoApply
    )
  }

  private func syncBrowserExtensionSettingsIfNeeded(
    refreshStatus: Bool = true,
    announce: Bool = true
  ) {
    guard defaults.string(forKey: DefaultsKey.browserSettingsVersion) == nil else {
      if refreshStatus {
        refreshChromeExtensionStatus()
      }
      return
    }
    syncBrowserExtensionSettings(refreshStatus: refreshStatus, announce: announce)
  }

  private func syncBrowserExtensionSettings(
    _ settings: BrowserTuningSettings,
    refreshStatus: Bool,
    announce: Bool,
    autoApply: Bool
  ) {
    do {
      try extensionBridge.writeSettings(settings)
      defaults.set(settings.settingsVersion, forKey: DefaultsKey.browserSettingsVersion)
      if refreshStatus {
        refreshChromeExtensionStatus()
      }
      if announce {
        if browserSettingsApplyNeeded {
          let browser = primaryBrowserConnector
          if canAutoApplyBrowserChanges(browser.id) {
            extensionBridgeMessage = "Applying latest settings to \(browser.displayName)..."
          } else if browserRunningChecker(browser.id) {
            extensionBridgeMessage =
              "Settings saved. Refresh \(browser.displayName) if the page has not updated."
          } else {
            extensionBridgeMessage =
              "Settings saved. Changes will apply next time \(browser.displayName) opens."
          }
        } else {
          extensionBridgeMessage = "Extension settings saved."
        }
      }
      if autoApply {
        scheduleBrowserSettingsAutoApplyIfNeeded()
      }
    } catch {
      extensionBridgeMessage = nil
      present(error)
    }
  }

  private func scheduleBrowserSettingsAutoApplyIfNeeded() {
    guard !legacyProviderConnectorEnabled,
          browserSettingsAutoApplyTask == nil,
          browserSettingsApplyNeeded else {
      return
    }

    let browser = primaryBrowserConnector.id
    guard canAutoApplyBrowserChanges(browser) else {
      return
    }

    browserSettingsAutoApplyTask = Task { @MainActor [weak self] in
      guard let self else {
        return
      }
      await self.applyBrowserChangesAsync(browser, automatic: true)
      self.browserSettingsAutoApplyTask = nil
    }
  }

  private func canAutoApplyBrowserChanges(_ browser: BrowserConnectorID) -> Bool {
    guard browser != .firefox,
          browserRunningChecker(browser),
          extensionBridge.nativeMessagingHostInstalled(for: browser) else {
      return false
    }

    switch browserHelperState(for: browser) {
    case .needsChromeOpen, .needsSync, .stale:
      return true
    case .notInstalled, .nativeHostMissing, .current, .extensionNeedsReload, .error:
      return false
    }
  }

  private func present(_ error: Error) {
    guard !Self.isCancellation(error) else {
      return
    }
    errorMessage = error.localizedDescription
  }

  private static func isCancellation(_ error: Error) -> Bool {
    if error is CancellationError {
      return true
    }

    let nsError = error as NSError
    return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
  }

  private func openChromeWithTuner(profile: String) async throws {
    try await openBrowserWithTuner(.chrome, profile: profile)
  }

  private func openBrowserWithTuner(_ browser: BrowserConnectorID, profile: String) async throws {
    guard let applicationURL = browserApplicationURL(for: browser) else {
      throw ChromeTunerLaunchError.chromeMissing
    }

    if browser == .firefox {
      let configuration = NSWorkspace.OpenConfiguration()
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { _, error in
          if let error {
            continuation.resume(throwing: error)
          } else {
            continuation.resume()
          }
        }
      }
      return
    }

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.arguments = [
      "--profile-directory=\(profile)",
      "--load-extension=\(browserExtensionDirectoryURL(for: browser).path)",
      "chrome-extension://\(BrowserExtensionBridge.extensionID)/connect/connect.html?sync=1",
    ]

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { _, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
    noteLaunchedBrowserSession(browser, profile: profile)
  }

  private func openChromeHelperPage() async throws {
    try await openBrowserHelperPage(.chrome)
  }

  private func openBrowserHelperPage(_ browser: BrowserConnectorID) async throws {
    guard let applicationURL = browserApplicationURL(for: browser) else {
      throw ChromeTunerLaunchError.chromeMissing
    }
    if browser == .firefox {
      let configuration = NSWorkspace.OpenConfiguration()
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { _, error in
          if let error {
            continuation.resume(throwing: error)
          } else {
            continuation.resume()
          }
        }
      }
      return
    }
    guard let helperURL = URL(
      string: "chrome-extension://\(BrowserExtensionBridge.extensionID)/connect/connect.html?sync=1"
    ) else {
      return
    }

    let configuration = NSWorkspace.OpenConfiguration()
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      NSWorkspace.shared.open([helperURL], withApplicationAt: applicationURL, configuration: configuration) {
        _, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }

  private static func chromeIsRunning() -> Bool {
    browserIsRunning(.chrome)
  }

  private static func browserIsRunning(_ browser: BrowserConnectorID) -> Bool {
    guard let bundleIdentifier = browser.applicationBundleIdentifier else {
      return false
    }
    return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
  }

  private func open(_ value: String) {
    guard let url = URL(string: value) else { return }
    open(url)
  }

  private func open(_ url: URL) {
    NSWorkspace.shared.open(url)
  }

  private static func loadBlockedSites(from defaults: UserDefaults) -> [BlockedSiteRule] {
    if let values = defaults.array(forKey: DefaultsKey.blockedSites) as? [[String: Any]] {
      return blockedSiteRules(from: values)
    }

    let legacyDomains = defaults.stringArray(forKey: DefaultsKey.customDomains) ?? []
    let migratedRules = blockedSiteRules(from: legacyDomains)
    if !migratedRules.isEmpty {
      defaults.set(
        migratedRules.map { ["domain": $0.domain, "isEnabled": $0.isEnabled] as [String: Any] },
        forKey: DefaultsKey.blockedSites
      )
    }
    return migratedRules
  }

  private static func loadPendingLegacyProviderRuleRemovals(from defaults: UserDefaults) -> Set<String> {
    let domains = defaults.stringArray(forKey: DefaultsKey.pendingLegacyProviderRuleRemovals) ?? []
    return Set(domains.compactMap { try? DomainNormalizer.normalize($0) })
  }

  private static func loadBlockCategories(
    from defaults: UserDefaults,
    accessMode: AccessMode
  ) -> [BlockCategoryRule] {
    if let values = defaults.array(forKey: DefaultsKey.blockCategories) as? [[String: Any]] {
      return blockCategoryRules(from: values, defaultAdultEnabled: accessMode.protectionEnabled)
    }

    let defaultRules = BlockCategoryID.allCases.map { id in
      BlockCategoryRule(id: id, isEnabled: id == .adultContent && accessMode.protectionEnabled)
    }
    defaults.set(
      defaultRules.map { ["id": $0.id.rawValue, "isEnabled": $0.isEnabled] as [String: Any] },
      forKey: DefaultsKey.blockCategories
    )
    return defaultRules
  }

  private static func blockedSiteRules(from domains: [String]) -> [BlockedSiteRule] {
    var rulesByDomain: [String: BlockedSiteRule] = [:]
    for rawDomain in domains {
      guard let domain = try? DomainNormalizer.normalize(rawDomain) else {
        continue
      }
      rulesByDomain[domain] = BlockedSiteRule(domain: domain, isEnabled: true)
    }
    return rulesByDomain.values.sorted { $0.domain < $1.domain }
  }

  private static func blockedSiteRules(from values: [[String: Any]]) -> [BlockedSiteRule] {
    var rulesByDomain: [String: BlockedSiteRule] = [:]
    for value in values {
      guard let rawDomain = value["domain"] as? String,
        let domain = try? DomainNormalizer.normalize(rawDomain)
      else {
        continue
      }

      let isEnabled: Bool
      if let bool = value["isEnabled"] as? Bool {
        isEnabled = bool
      } else if let number = value["isEnabled"] as? NSNumber {
        isEnabled = number.boolValue
      } else {
        isEnabled = true
      }
      rulesByDomain[domain] = BlockedSiteRule(domain: domain, isEnabled: isEnabled)
    }
    return rulesByDomain.values.sorted { $0.domain < $1.domain }
  }

  private static func blockCategoryRules(
    from values: [[String: Any]],
    defaultAdultEnabled: Bool
  ) -> [BlockCategoryRule] {
    var rulesByID = Dictionary(
      uniqueKeysWithValues: BlockCategoryID.allCases.map { id in
        (id, BlockCategoryRule(id: id, isEnabled: id == .adultContent && defaultAdultEnabled))
      }
    )

    for value in values {
      guard let rawID = value["id"] as? String,
        let id = BlockCategoryID(rawValue: rawID)
      else {
        continue
      }

      if let bool = value["isEnabled"] as? Bool {
        rulesByID[id] = BlockCategoryRule(id: id, isEnabled: bool)
      } else if let number = value["isEnabled"] as? NSNumber {
        rulesByID[id] = BlockCategoryRule(id: id, isEnabled: number.boolValue)
      }
    }

    return BlockCategoryID.allCases.compactMap { rulesByID[$0] }
  }

  private static func activeCategoryBlockedDomains(for categories: [BlockCategoryRule]) -> [String]
  {
    BrowserBlockingProvider.activeCategoryBlockedDomains(for: categories)
  }

  private static func activeBlockedDomains(
    sites: [BlockedSiteRule],
    categories: [BlockCategoryRule]
  ) -> [String] {
    BrowserBlockingProvider.activeBlockedDomains(sites: sites, categories: categories)
  }

  private static func activeBlockedDomainSet(
    sites: [BlockedSiteRule],
    categories: [BlockCategoryRule]
  ) -> Set<String> {
    BrowserBlockingProvider.activeBlockedDomainSet(sites: sites, categories: categories)
  }

  private static func managedDenylistDomainSet(sites: [BlockedSiteRule]) -> Set<String> {
    let siteDomains = sites.map(\.domain)
    let categoryDomains = BlockCategoryID.allCases.flatMap(\.domains)
    return Set(siteDomains + categoryDomains)
  }

  private static func normalizedReadbackDomain(_ value: String) -> String? {
    try? DomainNormalizer.normalize(value)
  }

  private static func loadTuningOverrides(from defaults: UserDefaults) -> [String: Bool] {
    guard let dictionary = defaults.dictionary(forKey: DefaultsKey.tuningOverrides) else {
      return [:]
    }

    return dictionary.reduce(into: [String: Bool]()) { result, item in
      guard BrowserTuningFeature(rawValue: item.key) != nil else {
        return
      }

      if let value = item.value as? Bool {
        result[item.key] = value
      } else if let value = item.value as? NSNumber {
        result[item.key] = value.boolValue
      }
    }
  }

  private static func loadTuningOptions(from defaults: UserDefaults) -> BrowserTuningOptions {
    if let data = defaults.data(forKey: DefaultsKey.tuningOptions),
      let options = try? JSONDecoder().decode(BrowserTuningOptions.self, from: data)
    {
      return options
    }

    if let dictionary = defaults.dictionary(forKey: DefaultsKey.tuningOptions) {
      let rawValue = dictionary["explicitHideStyle"] as? String
      let style = rawValue.flatMap(ExplicitHideStyle.init(rawValue:)) ?? .post
      let limitMinutes = dictionary["youtubeDailyLimitMinutes"] as? Int
        ?? (dictionary["youtubeDailyLimitMinutes"] as? NSNumber)?.intValue
        ?? BrowserTuningOptions.defaultYouTubeDailyLimitMinutes
      return BrowserTuningOptions(
        explicitHideStyle: style,
        youtubeDailyLimitMinutes: limitMinutes
      )
    }

    return .defaultValue
  }

  private static func loadFocusWindows(from defaults: UserDefaults) -> [FocusWindow] {
    guard let data = defaults.data(forKey: DefaultsKey.focusWindows),
      let windows = try? JSONDecoder().decode([FocusWindow].self, from: data)
    else {
      return []
    }
    return windows.sorted { lhs, rhs in
      if lhs.startMinute == rhs.startMinute {
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
      }
      return lhs.startMinute < rhs.startMinute
    }
  }

  private static func loadUUID(from defaults: UserDefaults, key: String) -> UUID? {
    guard let value = defaults.string(forKey: key) else {
      return nil
    }
    return UUID(uuidString: value)
  }

  private static func loadExistingFileURL(from defaults: UserDefaults, key: String) -> URL? {
    guard let path = defaults.string(forKey: key),
      !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      return nil
    }

    let url = URL(fileURLWithPath: path)
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }

  private static func minuteOfDay(from date: Date) -> Int {
    let components = Calendar.current.dateComponents([.hour, .minute], from: date)
    return ((components.hour ?? 0) * 60) + (components.minute ?? 0)
  }

  private static func minutesUntil(startMinute: Int, from currentMinute: Int) -> Int {
    let startMinute = FocusWindow.normalizedMinute(startMinute)
    let currentMinute = FocusWindow.normalizedMinute(currentMinute)
    if startMinute >= currentMinute {
      return startMinute - currentMinute
    }
    return (1_440 - currentMinute) + startMinute
  }

  private static func secondsUntil(minuteOfDay targetMinute: Int, from date: Date) -> TimeInterval {
    let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
    let currentMinute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
    let currentSecond = components.second ?? 0
    var seconds = (minutesUntil(startMinute: targetMinute, from: currentMinute) * 60) - currentSecond
    if seconds <= 0 {
      seconds += 24 * 60 * 60
    }
    return TimeInterval(seconds)
  }

  private static func formattedList(_ values: [String]) -> String {
    switch values.count {
    case 0:
      return ""
    case 1:
      return values[0]
    case 2:
      return "\(values[0]) and \(values[1])"
    default:
      return values.dropLast().joined(separator: ", ") + ", and " + values.last!
    }
  }

  private static func durationText(_ interval: TimeInterval) -> String {
    let minutes = max(1, Int(ceil(interval / 60)))
    if minutes < 60 {
      return "\(minutes)m"
    }

    let hours = minutes / 60
    let remainder = minutes % 60
    return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
  }

  private var browserConnectionCheck: ReadinessCheck {
    let browser = primaryBrowserConnector
    let status = browserExtensionStatus(for: browser.id)
    let detail: String
    if status.ready {
      if status.sessionReady {
        let selectedProfile =
          status.selectedProfileLabel ?? status.sessionProfileLabels.first
          ?? browser.displayName
        detail =
          "Connected for this \(browser.displayName) session in \(selectedProfile). Add QuietGate to \(browser.displayName) later if you want it to stay connected after restart."
      } else if let selectedProfile = status.selectedProfileLabel {
        detail = "Connected in the current \(browser.displayName) profile (\(selectedProfile))."
      } else {
        detail = "\(browser.displayName) is connected to QuietGate."
      }
    } else if status.loadedElsewhere {
      let selectedProfile = status.selectedProfileLabel ?? "the current profile"
      detail =
        "\(browser.displayName) is connected in \(status.readyProfileLabels.joined(separator: ", ")), but not in \(selectedProfile). Add it there too if you use that profile."
    } else {
      detail =
        "Connect \(browser.displayName) so QuietGate can apply website blocks and site tuning."
    }

    return ReadinessCheck(
      id: .browserConnection,
      title: browser.displayName,
      detail: detail,
      state: status.ready ? .ready : .actionNeeded,
      action: status.ready ? nil : supportedBrowserConnectorAction(for: browser.id)
    )
  }

  private var browserSettingsCheck: ReadinessCheck {
    let browser = primaryBrowserConnector
    let helperState = browserHelperState(for: browser.id)
    let detail: String
    let action: ReadinessAction?
    let ready = helperState == .current

    switch helperState {
    case .current:
      detail = "\(browser.displayName) confirmed the latest QuietGate settings."
      action = nil
    case .notInstalled:
      detail = "Connect \(browser.displayName) first. It will confirm settings after it opens."
      action = supportedBrowserConnectorAction(for: browser.id)
    case .nativeHostMissing:
      detail = "Install the small connection file \(browser.displayName) uses to ask QuietGate for settings."
      action = supportedBrowserConnectorAction(for: browser.id)
    case .needsChromeOpen:
      detail = "Saved settings will apply next time \(browser.displayName) opens."
      action = supportedBrowserConnectorAction(for: browser.id)
    case .needsSync:
      detail = "QuietGate is updating \(browser.displayName) with the latest settings."
      action = supportedBrowserConnectorAction(for: browser.id)
    case .stale:
      detail = "\(browser.displayName) has not checked in recently. Refresh the connection if pages have not updated."
      action = supportedBrowserConnectorAction(for: browser.id)
    case .extensionNeedsReload:
      detail = "\(browser.displayName) has an older QuietGate extension loaded. Open Extensions, reload QuietGate, then refresh the affected site."
      action = supportedBrowserConnectorAction(for: browser.id)
    case .error(let message):
      detail = "\(browser.displayName) reported: \(message)"
      action = supportedBrowserConnectorAction(for: browser.id)
    }

    return ReadinessCheck(
      id: .browserSettings,
      title: "\(browser.displayName) settings",
      detail: detail,
      state: ready ? .ready : .actionNeeded,
      action: action
    )
  }
}
