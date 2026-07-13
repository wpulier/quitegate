import SwiftUI

/// The "Add" sheet. Remote devices use a QR handoff; Chrome connects directly
/// through the extension flow owned by the Mac app.
struct AddSheetView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: ProtectionStore
  @State private var selected: AddDestination?

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        if selected != nil {
          Button { selected = nil } label: { Image(systemName: "chevron.left") }
            .buttonStyle(.plain).foregroundStyle(QGDesign.secondaryText)
        }
        Text(sheetTitle)
          .font(.system(size: 20, weight: .bold))
          .foregroundStyle(QGDesign.primaryText)
        Spacer()
        Button { dismiss() } label: { Image(systemName: "xmark") }
          .buttonStyle(.plain).foregroundStyle(QGDesign.secondaryText)
      }

      if let selected {
        detail(selected)
      } else {
        VStack(spacing: 10) {
          ForEach(AddDestination.allCases) { destination in
            Button { self.selected = destination } label: { tile(destination) }
              .buttonStyle(.plain)
          }
        }
      }
    }
    .padding(22)
    .frame(width: 400)
    .background(QGDesign.panel)
  }

  private var sheetTitle: String {
    guard let selected else { return "Connect" }
    return selected == .browser ? "Connect Chrome extension" : "Add \(selected.title.lowercased())"
  }

  private func tile(_ d: AddDestination) -> some View {
    HStack(spacing: 14) {
      Image(systemName: d.systemImage)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(QGDesign.secondaryText)
        .frame(width: 34, height: 34)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
      Text(d.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(QGDesign.primaryText)
      Spacer()
      Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(QGDesign.secondaryText)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(QGDesign.elevatedPanel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(QGDesign.hairline) }
  }

  @ViewBuilder private func detail(_ d: AddDestination) -> some View {
    if d == .browser {
      chromeExtensionDetail
    } else {
      VStack(spacing: 16) {
        if let cg = QRCode.cgImage(for: d.url().absoluteString) {
          Image(decorative: cg, scale: 1)
            .interpolation(.none)
            .resizable()
            .frame(width: 168, height: 168)
            .padding(10)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        Link(destination: d.url()) {
          Text(d.url().absoluteString).font(.system(size: 12, weight: .semibold)).foregroundStyle(QGDesign.accent)
        }
        Text(d.caption)
          .font(.system(size: 13)).foregroundStyle(QGDesign.secondaryText)
          .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity)
    }
  }

  private var chromeExtensionDetail: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(spacing: 14) {
        Image(systemName: store.chromeExtensionLoaded ? "checkmark.circle.fill" : "puzzlepiece.extension.fill")
          .font(.system(size: 26, weight: .semibold))
          .foregroundStyle(store.chromeExtensionLoaded ? QGDesign.green : QGDesign.accent)
          .frame(width: 48, height: 48)
          .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

        VStack(alignment: .leading, spacing: 3) {
          Text(store.chromeExtensionLoaded ? "Extension found" : "Connect QuietGate to Chrome")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(QGDesign.primaryText)
          Text(chromeConnectionDetail)
            .font(.system(size: 12))
            .foregroundStyle(QGDesign.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      VStack(alignment: .leading, spacing: 11) {
        connectionStep(number: 1, text: "QuietGate opens Chrome and installs the extension if needed.")
        connectionStep(number: 2, text: "Sign in or create your account in the Chrome tab that opens.")
        connectionStep(number: 3, text: "Return here; this browser profile will appear under your Mac.")
      }

      Button {
        store.launchBrowserTunerSession(.chrome)
      } label: {
        HStack(spacing: 8) {
          if store.isWorking {
            ProgressView().controlSize(.small)
          } else {
            Image(systemName: "arrow.up.forward.app")
          }
          Text(store.chromeExtensionLoaded ? "Finish connection in Chrome" : "Connect Chrome extension")
        }
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(QGPrimaryButtonStyle())
      .disabled(store.isWorking)

      if let message = store.extensionBridgeMessage {
        Label(message, systemImage: "info.circle")
          .font(.system(size: 12))
          .foregroundStyle(QGDesign.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .onAppear {
      store.refreshChromeExtensionStatus()
    }
  }

  private var chromeConnectionDetail: String {
    if let profile = store.chromeExtensionStatus.selectedProfileLabel {
      return "Found in \(profile). Continue once to connect your QuietGate account."
    }
    if store.chromeExtensionLoaded {
      return "Found in Chrome. Continue once to connect your QuietGate account."
    }
    return "One button handles installation and account setup."
  }

  private func connectionStep(number: Int, text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Text("\(number)")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(QGDesign.primaryText)
        .frame(width: 22, height: 22)
        .background(QGDesign.accent.opacity(0.20), in: Circle())
      Text(text)
        .font(.system(size: 12))
        .foregroundStyle(QGDesign.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}
