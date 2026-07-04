import SwiftUI

/// The "Add" sheet: pick Phone / Computer / Browser, then scan the QR (or open
/// the link) on that thing and sign in — it shows up in the hub. No codes.
struct AddSheetView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var selected: AddDestination?

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        if selected != nil {
          Button { selected = nil } label: { Image(systemName: "chevron.left") }
            .buttonStyle(.plain).foregroundStyle(QGDesign.secondaryText)
        }
        Text(selected.map { "Add \($0.title.lowercased())" } ?? "Add")
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
    .frame(width: 360)
    .background(QGDesign.panel)
  }

  private func tile(_ d: AddDestination) -> some View {
    HStack(spacing: 14) {
      Image(systemName: d.systemImage)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(QGDesign.secondaryText)
        .frame(width: 34, height: 34)
        .background(QGDesign.elevatedPanel, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
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
