import ClerkKit
import ClerkKitUI
import SwiftUI

struct ContentView: View {
  @Environment(Clerk.self) private var clerk
  @StateObject private var model = AccountHubModel()
  @State private var authViewIsPresented = false

  var body: some View {
    Group {
      if clerk.session == nil {
        SignedOutLanding(syncMessage: model.syncMessage, onSignIn: presentAuth)
      } else {
        signedInTabs
      }
    }
    .onOpenURL { url in
      Task {
        try? await clerk.handle(url)
      }
    }
    .task(id: clerk.session?.id) {
      await model.refresh(using: clerk)
    }
    .task {
      for await event in clerk.auth.events {
        switch event {
        case .signInNeedsContinuation, .signUpNeedsContinuation:
          authViewIsPresented = true
        default:
          break
        }
      }
    }
    .onChange(of: clerk.session?.tasks, initial: true) { _, newValue in
      if newValue?.isEmpty == false {
        authViewIsPresented = true
      }
    }
    .sheet(isPresented: $authViewIsPresented) {
      AuthView(mode: .signInOrUp)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
  }

  private var signedInTabs: some View {
    TabView {
      SetupTab(accountLabel: accountLabel, model: model, refresh: refresh)
        .tabItem {
          Label("Setup", systemImage: "checkmark.shield")
        }

      HomeTab(model: model, refresh: refresh)
        .tabItem {
          Label("Home", systemImage: "house")
        }

      TuningTab(model: model, refresh: refresh)
        .tabItem {
          Label("Tuning", systemImage: "slider.horizontal.3")
        }

      AppsTab(model: model, refresh: refresh)
        .tabItem {
          Label("Apps", systemImage: "square.grid.2x2")
        }
    }
  }

  private var accountLabel: String {
    clerk.user?.primaryEmailAddress?.emailAddress
      ?? clerk.user?.username
      ?? clerk.user?.id
      ?? "Tortoise account"
  }

  private func presentAuth() {
    authViewIsPresented = true
    Task {
      _ = try? await clerk.refreshEnvironment()
    }
  }

  private func refresh() async {
    await model.refresh(using: clerk)
  }
}

private struct SignedOutLanding: View {
  let syncMessage: String
  let onSignIn: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 28) {
      HStack {
        Text("Tortoise")
          .font(.title)
          .fontWeight(.semibold)
        Spacer()
        Button("Sign in", action: onSignIn)
          .buttonStyle(.bordered)
          .controlSize(.large)
      }

      Spacer(minLength: 52)

      VStack(alignment: .leading, spacing: 14) {
        Text("Account hub")
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundStyle(.secondary)
          .textCase(.uppercase)

        Text("Sign in to sync this device.")
          .font(.largeTitle)
          .fontWeight(.semibold)
          .fixedSize(horizontal: false, vertical: true)

        Text("Use the same Tortoise account for Mac, iPhone, browser helpers, and shared protection policy.")
          .font(.body)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      VStack(alignment: .leading, spacing: 12) {
        Button(action: onSignIn) {
          Text("Sign in")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)

        Text(syncMessage)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color(.systemBackground))
  }
}

private struct SetupTab: View {
  let accountLabel: String
  @ObservedObject var model: AccountHubModel
  let refresh: () async -> Void

  var body: some View {
    TabScreen(title: "Setup", subtitle: "Account, device registration, and sync.", model: model, refresh: refresh) {
      StatusCard(title: "Account", status: "Signed in") {
        InfoRow("Email", value: accountLabel)
        InfoRow("Plan", value: "Beta access")
      }

      StatusCard(title: "This iPhone", status: deviceStatus) {
        InfoRow("Device", value: model.snapshot.device?.name ?? UIDevice.current.name)
        InfoRow("Registered", value: model.snapshot.device == nil ? "No" : "Yes")
        InfoRow("Last sync", value: model.snapshot.lastSyncedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Never")
        SyncButton(isSyncing: model.isSyncing, refresh: refresh)
      }

      StatusCard(title: "Checklist", status: "iOS v1") {
        ChecklistRow(title: "Sign in", isComplete: true)
        ChecklistRow(title: "Register iPhone", isComplete: model.snapshot.device != nil)
        ChecklistRow(title: "Pull shared policy", isComplete: model.snapshot.policy != nil)
        ChecklistRow(title: "Upload device health", isComplete: model.snapshot.lastSyncedAt != nil)
      }
    }
  }

  private var deviceStatus: String {
    if model.snapshot.device == nil {
      return "Setup incomplete"
    }
    if model.snapshot.policy == nil {
      return "Signed in"
    }
    return "Synced"
  }
}

private struct HomeTab: View {
  @ObservedObject var model: AccountHubModel
  let refresh: () async -> Void

  var body: some View {
    TabScreen(title: "Home", subtitle: "Desired policy and what this device proves.", model: model, refresh: refresh) {
      StatusCard(title: "Policy", status: model.snapshot.policy == nil ? "Unavailable" : "Current") {
        InfoRow("Mode", value: policy?.normalizedMode ?? "Unknown")
        InfoRow("Adult blocking", value: policy?.adultBlockingEnabled == true ? "On" : "Off")
        InfoRow("Version", value: model.snapshot.policy.map { "\($0.settingsVersion)" } ?? "Unavailable")
      }

      StatusCard(title: "Coverage", status: "Account hub only") {
        CapabilityRow(title: "Account sync", policy: "On", device: model.snapshot.device == nil ? "Setup incomplete" : "Live")
        CapabilityRow(title: "Shared policy", policy: "On", device: model.snapshot.policy == nil ? "Unavailable" : "Current")
        CapabilityRow(title: "iOS content blocking", policy: "Planned", device: "Not available yet")
        CapabilityRow(title: "Mac/browser enforcement", policy: "Tracked", device: "Shown by Mac health")
      }

      StatusCard(title: "Sync", status: model.isSyncing ? "Working" : "Ready") {
        Text(model.syncMessage)
          .foregroundStyle(.secondary)
        SyncButton(isSyncing: model.isSyncing, refresh: refresh)
      }
    }
  }

  private var policy: TortoisePolicy? {
    model.snapshot.policy?.policy
  }
}

private struct TuningTab: View {
  @ObservedObject var model: AccountHubModel
  let refresh: () async -> Void

  var body: some View {
    TabScreen(title: "Tuning", subtitle: "Policy is shared. Enforcement depends on each platform.", model: model, refresh: refresh) {
      StatusCard(title: "Browser tuning", status: "\(policy?.enabledBrowserFeatureCount ?? 0) on") {
        TuningRow(title: "X", isOn: policy?.featureEnabled(withPrefix: "x") == true, deviceStatus: "Mac/Chrome")
        TuningRow(title: "Reddit", isOn: policy?.featureEnabled(withPrefix: "reddit") == true, deviceStatus: "Mac/Chrome")
        TuningRow(title: "YouTube", isOn: policy?.featureEnabled(withPrefix: "youtube") == true, deviceStatus: "Mac/Chrome")
        TuningRow(title: "Instagram", isOn: policy?.featureEnabled(withPrefix: "instagram") == true, deviceStatus: "Mac/Chrome")
      }

      StatusCard(title: "Adult web", status: policy?.adultBlockingEnabled == true ? "Policy on" : "Policy off") {
        InfoRow("Blocked domains", value: "\(policy?.browser?.blockedDomains.count ?? 0)")
        InfoRow("Blocked categories", value: "\(policy?.browser?.blockedCategories.count ?? 0)")
        InfoRow("iOS enforcement", value: "Not available in v1")
      }

      StatusCard(title: "Schedules", status: policy?.schedules?.enabled == true ? "On" : "Off") {
        InfoRow("Active windows", value: "\(policy?.activeFocusWindowCount ?? 0)")
        InfoRow("iOS behavior", value: "Displays policy only")
      }
    }
  }

  private var policy: TortoisePolicy? {
    model.snapshot.policy?.policy
  }
}

private struct AppsTab: View {
  @ObservedObject var model: AccountHubModel
  let refresh: () async -> Void

  var body: some View {
    TabScreen(title: "Apps", subtitle: "Mac app rules are synced here, but enforced on Mac.", model: model, refresh: refresh) {
      StatusCard(title: "Mac app blocking", status: policy?.applications?.enforcementEnabled == true ? "Policy on" : "Policy off") {
        InfoRow("Blocked apps", value: "\(policy?.activeBlockedAppCount ?? 0)")
        InfoRow("Allowed apps", value: "\(policy?.activeAllowedAppCount ?? 0)")
        InfoRow("iPhone", value: "Status hub only")
      }

      StatusCard(title: "What iOS can show", status: "Read-only") {
        CapabilityRow(title: "Desired Mac rules", policy: "Synced", device: "Visible")
        CapabilityRow(title: "Mac enforcement", policy: "Tracked", device: "Requires Mac health")
        CapabilityRow(title: "iOS app blocking", policy: "Planned", device: "Not available yet")
      }
    }
  }

  private var policy: TortoisePolicy? {
    model.snapshot.policy?.policy
  }
}

private struct TabScreen<Content: View>: View {
  let title: String
  let subtitle: String
  @ObservedObject var model: AccountHubModel
  let refresh: () async -> Void
  @ViewBuilder let content: Content

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          VStack(alignment: .leading, spacing: 6) {
            Text(title)
              .font(.largeTitle)
              .fontWeight(.semibold)
            Text(subtitle)
              .font(.body)
              .foregroundStyle(.secondary)
          }
          .padding(.bottom, 4)

          content
        }
        .padding(20)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .refreshable {
        await refresh()
      }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          UserButton()
        }
      }
    }
  }
}

private struct StatusCard<Content: View>: View {
  let title: String
  let status: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline) {
        Text(title)
          .font(.headline)
        Spacer()
        StatusPill(status)
      }

      content
        .font(.subheadline)
    }
    .padding(16)
    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct StatusPill: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    Text(text)
      .font(.caption)
      .fontWeight(.semibold)
      .lineLimit(1)
      .minimumScaleFactor(0.75)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(Color(.secondarySystemGroupedBackground), in: Capsule())
  }
}

private struct InfoRow: View {
  let title: String
  let value: String

  init(_ title: String, value: String) {
    self.title = title
    self.value = value
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(title)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .fontWeight(.medium)
        .multilineTextAlignment(.trailing)
    }
  }
}

private struct ChecklistRow: View {
  let title: String
  let isComplete: Bool

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
        .foregroundStyle(isComplete ? .green : .secondary)
      Text(title)
      Spacer()
    }
    .foregroundStyle(isComplete ? .primary : .secondary)
  }
}

private struct CapabilityRow: View {
  let title: String
  let policy: String
  let device: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .fontWeight(.medium)
      HStack(spacing: 8) {
        StatusPill("Policy: \(policy)")
        StatusPill(device)
        Spacer(minLength: 0)
      }
    }
  }
}

private struct TuningRow: View {
  let title: String
  let isOn: Bool
  let deviceStatus: String

  var body: some View {
    CapabilityRow(
      title: title,
      policy: isOn ? "On" : "Off",
      device: isOn ? "\(deviceStatus) only" : "No action"
    )
  }
}

private struct SyncButton: View {
  let isSyncing: Bool
  let refresh: () async -> Void

  var body: some View {
    Button {
      Task {
        await refresh()
      }
    } label: {
      if isSyncing {
        ProgressView()
          .frame(maxWidth: .infinity)
      } else {
        Text("Sync now")
          .frame(maxWidth: .infinity)
      }
    }
    .buttonStyle(.bordered)
    .disabled(isSyncing)
  }
}
