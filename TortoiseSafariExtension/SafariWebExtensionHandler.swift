import Foundation
import SafariServices
import os.log

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
  func beginRequest(with context: NSExtensionContext) {
    let request = context.inputItems.first as? NSExtensionItem
    let message = Self.message(from: request)
    let payload = handle(message: message)
    let response = NSExtensionItem()

    if #available(iOS 15.0, macOS 11.0, *) {
      response.userInfo = [SFExtensionMessageKey: payload]
    } else {
      response.userInfo = ["message": payload]
    }

    context.completeRequest(returningItems: [response], completionHandler: nil)
  }

  private func handle(message: Any?) -> [String: Any] {
    guard let message = message as? [String: Any],
          let type = message["type"] as? String else {
      return policyResponse()
    }

    switch type {
    case "quietgate.policy":
      return policyResponse()
    case "quietgate.recordSiteUsage":
      if let usage = message["siteUsageBySite"] as? [String: Any] {
        IOSEnforcementSharedStore.saveSiteUsageBySite(usage)
      }
      IOSEnforcementSharedStore.recordSafariExtensionHeartbeat(
        policyMode: IOSEnforcementSharedStore.loadSafariPolicy().mode
      )
      return [
        "ok": true,
        "storedAt": ISO8601DateFormatter().string(from: Date())
      ]
    default:
      os_log(.debug, "Unhandled QuietGate Safari message: %@", type)
      return policyResponse()
    }
  }

  private func policyResponse() -> [String: Any] {
    let policy = IOSEnforcementSharedStore.loadSafariPolicy()
    IOSEnforcementSharedStore.recordSafariExtensionHeartbeat(policyMode: policy.mode)
    let snapshot = IOSEnforcementSharedStore.loadSnapshot()
    var setup: [String: Any] = [
      "mode": snapshot.mode.rawValue,
      "shieldingEnabled": snapshot.shieldingEnabled,
      "safariExtensionEnabled": snapshot.safariExtensionEnabled,
      "selectedApplicationCount": snapshot.selectedApplicationCount,
      "selectedCategoryCount": snapshot.selectedCategoryCount,
      "selectedWebDomainCount": snapshot.selectedWebDomainCount,
      "scheduleActive": snapshot.scheduleActive
    ]
    setup["safariExtensionState"] = snapshot.safariExtensionState?.rawValue
    if let lastSafariExtensionSeenAt = snapshot.lastSafariExtensionSeenAt {
      setup["lastSafariExtensionSeenAt"] = ISO8601DateFormatter().string(from: lastSafariExtensionSeenAt)
    }
    if let lastSafariPolicyAppliedAt = snapshot.lastSafariPolicyAppliedAt {
      setup["lastSafariPolicyAppliedAt"] = ISO8601DateFormatter().string(from: lastSafariPolicyAppliedAt)
    }
    if let lastAppliedAt = snapshot.lastAppliedAt {
      setup["lastAppliedAt"] = ISO8601DateFormatter().string(from: lastAppliedAt)
    }
    return [
      "ok": true,
      "storageUpdates": policy.storageObject,
      "setup": setup
    ]
  }

  private static func message(from request: NSExtensionItem?) -> Any? {
    if #available(iOS 15.0, macOS 11.0, *) {
      return request?.userInfo?[SFExtensionMessageKey]
    }
    return request?.userInfo?["message"]
  }
}
