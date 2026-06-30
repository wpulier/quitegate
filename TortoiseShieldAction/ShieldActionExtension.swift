import ManagedSettings

final class TortoiseShieldActionExtension: ShieldActionDelegate {
  override func handle(
    action: ShieldAction,
    for application: ApplicationToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    completionHandler(response(for: action))
  }

  override func handle(
    action: ShieldAction,
    for category: ActivityCategoryToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    completionHandler(response(for: action))
  }

  override func handle(
    action: ShieldAction,
    for webDomain: WebDomainToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    completionHandler(response(for: action))
  }

  private func response(for action: ShieldAction) -> ShieldActionResponse {
    switch action {
    case .primaryButtonPressed:
      return .close
    case .secondaryButtonPressed:
      return .defer
    @unknown default:
      return .close
    }
  }
}
