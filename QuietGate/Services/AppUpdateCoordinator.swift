import Foundation
import Sparkle

@MainActor
final class AppUpdateCoordinator: NSObject, ObservableObject, SPUUpdaterDelegate {
  enum State: Equatable {
    case idle
    case checking
    case downloading(version: String?)
    case ready(version: String?)
    case installing
    case failed(message: String)
  }

  @Published private(set) var state: State = .idle

  private var updaterController: SPUStandardUpdaterController!
  private var immediateInstallHandler: (() -> Void)?
  private var installRequested = false

  init(startUpdater: Bool = true) {
    super.init()
    updaterController = SPUStandardUpdaterController(
      startingUpdater: startUpdater,
      updaterDelegate: self,
      userDriverDelegate: nil
    )
  }

  var actionTitle: String {
    switch state {
    case .checking:
      return "Checking for update…"
    case .downloading:
      return "Downloading update…"
    case .ready:
      return "Restart to update"
    case .installing:
      return "Installing update…"
    case .idle, .failed:
      return "New update available"
    }
  }

  var actionSystemImage: String {
    switch state {
    case .ready, .installing:
      return "arrow.triangle.2.circlepath"
    default:
      return "arrow.down.circle"
    }
  }

  var actionDisabled: Bool {
    switch state {
    case .checking, .installing:
      return true
    default:
      return false
    }
  }

  var detailText: String {
    switch state {
    case .idle:
      return "A signed Tortoise update is available. Install it without downloading a separate app."
    case .checking:
      return "Checking the signed Tortoise update feed."
    case let .downloading(version):
      return version.map { "Downloading Tortoise \($0) securely in the background." }
        ?? "Downloading the Tortoise update securely in the background."
    case let .ready(version):
      return version.map { "Tortoise \($0) is ready. Restart to install it now." }
        ?? "The update is ready. Restart to install it now."
    case .installing:
      return "Tortoise will close, install the update, and reopen automatically."
    case let .failed(message):
      return message
    }
  }

  func checkForUpdates() {
    updaterController.checkForUpdates(nil)
  }

  func checkForUpdatesInBackground() {
    guard !updaterController.updater.sessionInProgress else {
      return
    }
    updaterController.updater.checkForUpdatesInBackground()
  }

  func installLatestUpdate() {
    installRequested = true

    if let immediateInstallHandler {
      state = .installing
      immediateInstallHandler()
      return
    }

    guard !updaterController.updater.sessionInProgress else {
      if case .idle = state {
        state = .checking
      }
      return
    }

    state = .checking
    updaterController.updater.checkForUpdatesInBackground()
  }

  func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
    state = .downloading(version: item.displayVersionString)
  }

  func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
    installRequested = false
    if case .checking = state {
      state = .idle
    }
  }

  func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
    state = .downloading(version: item.displayVersionString)
  }

  func updater(
    _ updater: SPUUpdater,
    willInstallUpdateOnQuit item: SUAppcastItem,
    immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
  ) -> Bool {
    self.immediateInstallHandler = immediateInstallHandler
    state = .ready(version: item.displayVersionString)

    if installRequested {
      state = .installing
      immediateInstallHandler()
    }

    return true
  }

  func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
    installRequested = false
    immediateInstallHandler = nil
    state = .failed(message: error.localizedDescription)
  }
}
