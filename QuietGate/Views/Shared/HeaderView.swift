import SwiftUI

struct HeaderView: View {
  let title: String
  let subtitle: String
  let systemImage: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 26, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 32)

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.title.weight(.semibold))
        Text(subtitle)
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    }
  }
}
