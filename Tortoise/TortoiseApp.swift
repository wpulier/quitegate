import ClerkKit
import ClerkKitUI
import SwiftUI

@main
struct TortoiseApp: App {
  init() {
    Clerk.configure(publishableKey: AppConfig.clerkPublishableKey)
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .prefetchClerkImages()
        .environment(Clerk.shared)
    }
  }
}
