import SwiftUI

struct ProductPage<Content: View>: View {
  private let maxWidth: CGFloat
  private let content: Content

  init(maxWidth: CGFloat = 820, @ViewBuilder content: () -> Content) {
    self.maxWidth = maxWidth
    self.content = content()
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        content
      }
      .padding(28)
      .frame(maxWidth: maxWidth, alignment: .leading)
    }
    .scrollIndicators(.visible)
  }
}

struct ProductHeader: View {
  @EnvironmentObject private var store: ProtectionStore
  let title: String
  let subtitle: String
  let systemImage: String

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      Image(systemName: systemImage)
        .font(.system(size: 34, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 44, height: 44)

      VStack(alignment: .leading, spacing: 5) {
        Text(title)
          .font(.system(size: 34, weight: .bold))
          .foregroundStyle(.primary)
        Text(subtitle)
          .font(.title3)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 16)

      if store.appUpdateAvailable {
        Button {
          store.relaunchToInstalledUpdate()
        } label: {
          Label("Update", systemImage: "arrow.triangle.2.circlepath")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(store.isWorking)
        .help(store.appUpdateDetail)
        .padding(.top, 5)
      } else {
        ProductStatusPill(text: "Newest version", tint: .secondary)
          .help(store.appUpdateDetail)
          .padding(.top, 8)
      }
    }
  }
}

struct ProductPanel<Content: View>: View {
  let title: String
  let subtitle: String?
  private let content: Content

  init(
    title: String,
    subtitle: String? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.subtitle = subtitle
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.title3.weight(.semibold))
        if let subtitle {
          Text(subtitle)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      content
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    .overlay {
      RoundedRectangle(cornerRadius: 8)
        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.45))
    }
  }
}

struct ProductCallout<Content: View>: View {
  let title: String
  let detail: String
  let systemImage: String
  let tint: Color
  private let content: Content

  init(
    title: String,
    detail: String,
    systemImage: String,
    tint: Color,
    @ViewBuilder content: () -> Content = { EmptyView() }
  ) {
    self.title = title
    self.detail = detail
    self.systemImage = systemImage
    self.tint = tint
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: systemImage)
          .font(.title3)
          .foregroundStyle(tint)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.headline)
          Text(detail)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      content
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct ProductStatusPill: View {
  let text: String
  let tint: Color

  var body: some View {
    Text(text)
      .font(.caption.weight(.semibold))
      .foregroundStyle(tint)
      .padding(.horizontal, 9)
      .padding(.vertical, 4)
      .background(tint.opacity(0.12), in: Capsule())
  }
}

struct ProductScopeLine: View {
  let title: String
  let detail: String
  let caption: String
  let systemImage: String
  let tint: Color

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: systemImage)
        .font(.callout.weight(.semibold))
        .foregroundStyle(tint)
        .frame(width: 22)
        .padding(.top, 1)

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(detail)
          .font(.callout.weight(.semibold))
          .foregroundStyle(.primary)
          .fixedSize(horizontal: false, vertical: true)
        Text(caption)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

struct ProductActionRow<Content: View>: View {
  private let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 10) {
        content
      }
      .fixedSize(horizontal: true, vertical: false)

      VStack(alignment: .leading, spacing: 8) {
        content
      }
    }
  }
}

struct ProductDivider: View {
  var body: some View {
    Rectangle()
      .fill(Color(nsColor: .separatorColor).opacity(0.7))
      .frame(height: 1)
  }
}
