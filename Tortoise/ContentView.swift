import ClerkKit
import ClerkKitUI
import SwiftUI

struct ContentView: View {
  @Environment(Clerk.self) private var clerk
  @StateObject private var model = AccountHubModel()
  @State private var authViewIsPresented = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          header

          if clerk.session == nil {
            signedOutCard
          } else {
            accountCard
            policyCard
            deviceCard
            coverageCard
            setupCard
          }
        }
        .padding(20)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Tortoise")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          UserButton(signedOutContent: {
            Button("Sign in") {
              authViewIsPresented = true
            }
          })
        }
      }
      .refreshable {
        await model.refresh(using: clerk)
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
      AuthView()
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Account hub")
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
      Text("Keep your Mac, iPhone, and browser protection on the same account.")
        .font(.largeTitle)
        .fontWeight(.semibold)
        .fixedSize(horizontal: false, vertical: true)
      Text("iOS v1 is an account hub: it signs in, registers this device, syncs policy, and shows what is not enforceable here yet.")
        .font(.body)
        .foregroundStyle(.secondary)
      Text(model.syncMessage)
        .font(.body)
        .foregroundStyle(.secondary)
    }
  }

  private var signedOutCard: some View {
    StatusCard(title: "Sign in", status: "Required") {
      Text("Use the same Tortoise account you use on the web dashboard. After sign-in, this iPhone registers itself and pulls your shared policy.")
        .foregroundStyle(.secondary)
      Button("Sign in") {
        authViewIsPresented = true
      }
      .buttonStyle(.borderedProminent)
    }
  }

  private var accountCard: some View {
    StatusCard(title: "Account", status: "Signed in") {
      Text(clerk.user?.primaryEmailAddress?.emailAddress ?? clerk.user?.username ?? clerk.user?.id ?? "Tortoise account")
        .foregroundStyle(.secondary)
      Text("Plan: Beta access")
        .fontWeight(.medium)
    }
  }

  private var policyCard: some View {
    StatusCard(
      title: "Shared policy",
      status: model.snapshot.policy == nil ? "Unavailable" : "Current"
    ) {
      LabeledContent("Mode", value: model.snapshot.policy?.policy.mode.capitalized ?? "Unknown")
      LabeledContent(
        "Adult blocking",
        value: model.snapshot.policy?.policy.adultBlockingEnabled == true ? "On" : "Off"
      )
      LabeledContent(
        "Policy version",
        value: model.snapshot.policy.map { "\($0.settingsVersion)" } ?? "Unavailable"
      )
    }
  }

  private var deviceCard: some View {
    StatusCard(
      title: "This iPhone",
      status: model.snapshot.device == nil
        ? "Setup incomplete"
        : model.snapshot.policy == nil ? "Signed in" : "Synced"
    ) {
      LabeledContent("Device", value: model.snapshot.device?.name ?? UIDevice.current.name)
      LabeledContent("Registered", value: model.snapshot.device == nil ? "No" : "Yes")
      LabeledContent("Last sync", value: model.snapshot.lastSyncedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Never")
      Text("This confirms account and policy sync only. It does not mean iOS is blocking browser content yet.")
        .foregroundStyle(.secondary)
      Button {
        Task {
          await model.refresh(using: clerk)
        }
      } label: {
        if model.isSyncing {
          ProgressView()
        } else {
          Text("Sync now")
        }
      }
      .buttonStyle(.bordered)
      .disabled(model.isSyncing)
    }
  }

  private var coverageCard: some View {
    StatusCard(title: "Protection coverage", status: "Account hub only") {
      CapabilityRow(title: "Account sync", status: model.snapshot.device == nil ? "Setup incomplete" : "Live")
      CapabilityRow(title: "Shared policy", status: model.snapshot.policy == nil ? "Unavailable" : "Current")
      CapabilityRow(title: "Adult web blocking on iOS", status: "Planned")
      CapabilityRow(title: "X, Reddit, YouTube, Instagram tuning on iOS", status: "Not available in v1")
      CapabilityRow(title: "Mac and Chrome enforcement", status: "Shown from device health")
    }
  }

  private var setupCard: some View {
    StatusCard(title: "Setup checklist", status: "Account hub v1") {
      ChecklistRow(title: "Sign in", isComplete: clerk.session != nil)
      ChecklistRow(title: "Register iOS device", isComplete: model.snapshot.device != nil)
      ChecklistRow(title: "Pull shared policy", isComplete: model.snapshot.policy != nil)
      ChecklistRow(title: "iOS enforcement", isComplete: false, note: "Not available in v1")
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
        Text(status)
          .font(.caption)
          .fontWeight(.semibold)
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(Color(.secondarySystemGroupedBackground), in: Capsule())
      }
      content
        .font(.subheadline)
    }
    .padding(16)
    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct ChecklistRow: View {
  let title: String
  let isComplete: Bool
  var note: String? = nil

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
        .foregroundStyle(isComplete ? .green : .secondary)
      Text(title)
      Spacer()
      if let note {
        Text(note)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .foregroundStyle(isComplete ? .primary : .secondary)
  }
}

private struct CapabilityRow: View {
  let title: String
  let status: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(title)
      Spacer()
      Text(status)
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
    }
  }
}
