import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
  case protection
  case control
  case tuning
  case apps

  var id: String { rawValue }

  var title: String {
    switch self {
    case .protection: return "Setup"
    case .control: return "Home"
    case .tuning: return "Tuning"
    case .apps: return "Apps"
    }
  }

  var systemImage: String {
    switch self {
    case .protection: return "checkmark.shield"
    case .control: return "house"
    case .tuning: return "slider.horizontal.3"
    case .apps: return "app.badge"
    }
  }
}

struct ContentView: View {
  @Environment(\.scenePhase) private var scenePhase
  @EnvironmentObject private var store: ProtectionStore
  @EnvironmentObject private var appBlockingStore: AppBlockingStore
  @SceneStorage("quietgate.selectedSection") private var selectedSectionID =
    AppSection.protection.rawValue

  private var selectedSection: Binding<AppSection> {
    Binding {
      AppSection(rawValue: selectedSectionID) ?? .protection
    } set: { newValue in
      selectedSectionID = newValue.rawValue
    }
  }

  var body: some View {
    NavigationSplitView {
      List(selection: selectedSection) {
        ForEach(AppSection.allCases) { section in
          Label(section.title, systemImage: section.systemImage)
            .tag(section)
        }
      }
      .listStyle(.sidebar)
      .navigationSplitViewColumnWidth(min: 170, ideal: 190)
    } detail: {
      detailView
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background)
    }
    .task {
      store.refreshAppUpdateStatus()
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        store.refreshAppUpdateStatus()
      }
    }
  }

  @ViewBuilder
  private var detailView: some View {
    switch selectedSection.wrappedValue {
    case .protection:
      ProtectionView {
        selectedSectionID = AppSection.control.rawValue
      } openApps: {
        selectedSectionID = AppSection.apps.rawValue
      }
    case .control:
      ControlView {
        selectedSectionID = AppSection.protection.rawValue
      }
    case .tuning:
      TuningView()
    case .apps:
      AppsView(store: appBlockingStore)
    }
  }
}
