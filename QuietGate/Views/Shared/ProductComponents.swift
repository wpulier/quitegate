import SwiftUI

enum QGDesign {
  static let background = Color(red: 0.055, green: 0.055, blue: 0.065)
  static let sidebar = Color(red: 0.075, green: 0.075, blue: 0.086)
  static let panel = Color(red: 0.118, green: 0.118, blue: 0.133)
  static let elevatedPanel = Color(red: 0.145, green: 0.145, blue: 0.160)
  static let field = Color(red: 0.170, green: 0.170, blue: 0.190)
  static let hairline = Color.white.opacity(0.08)
  static let strongHairline = Color.white.opacity(0.13)
  static let primaryText = Color(red: 0.965, green: 0.965, blue: 0.980)
  static let secondaryText = Color(red: 0.635, green: 0.635, blue: 0.675)
  static let tertiaryText = Color(red: 0.460, green: 0.460, blue: 0.505)
  static let accent = Color(red: 0.245, green: 0.388, blue: 0.867)
  static let accentSoft = Color(red: 0.245, green: 0.388, blue: 0.867).opacity(0.18)
  static let green = Color(red: 0.190, green: 0.800, blue: 0.360)
  static let purple = Color(red: 0.435, green: 0.337, blue: 0.812)
  static let red = Color(red: 1.000, green: 0.231, blue: 0.188)
  static let orange = Color(red: 1.000, green: 0.584, blue: 0.000)
}

struct QGPage<Content: View>: View {
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
      .padding(.horizontal, 36)
      .padding(.top, 32)
      .padding(.bottom, 44)
      .frame(maxWidth: maxWidth, alignment: .leading)
    }
    .scrollIndicators(.visible)
    .background(QGDesign.background)
  }
}

struct QGScreenHeader: View {
  let title: String
  let subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.system(size: 28, weight: .bold))
        .foregroundStyle(QGDesign.primaryText)
      Text(subtitle)
        .font(.system(size: 14, weight: .regular))
        .foregroundStyle(QGDesign.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

struct QGSectionLabel: View {
  let text: String

  var body: some View {
    Text(text.uppercased())
      .font(.system(size: 12, weight: .bold))
      .foregroundStyle(QGDesign.tertiaryText)
      .tracking(1.2)
  }
}

struct QGCard<Content: View>: View {
  private let cornerRadius: CGFloat
  private let padding: CGFloat
  private let content: Content

  init(
    cornerRadius: CGFloat = 12,
    padding: CGFloat = 18,
    @ViewBuilder content: () -> Content
  ) {
    self.cornerRadius = cornerRadius
    self.padding = padding
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      content
    }
    .padding(padding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(QGDesign.panel, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .strokeBorder(QGDesign.strongHairline)
    }
  }
}

struct QGAvatar: View {
  let text: String
  var size: CGFloat = 34
  var background: Color = Color.white.opacity(0.11)
  var foreground: Color = QGDesign.primaryText
  var cornerRadius: CGFloat?

  var body: some View {
    Text(text)
      .font(.system(size: max(10, size * 0.34), weight: .bold))
      .foregroundStyle(foreground)
      .frame(width: size, height: size)
      .background(background, in: RoundedRectangle(cornerRadius: cornerRadius ?? size / 2.7, style: .continuous))
  }
}

struct QGPill: View {
  let text: String
  var tint: Color = QGDesign.accent
  var filled: Bool = false

  var body: some View {
    Text(text)
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(filled ? QGDesign.primaryText : tint)
      .lineLimit(1)
      .minimumScaleFactor(0.78)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background((filled ? tint : tint.opacity(0.16)), in: Capsule())
  }
}

struct QGSwitch: View {
  @Binding var isOn: Bool
  var isEnabled = true

  var body: some View {
    Button {
      guard isEnabled else { return }
      isOn.toggle()
    } label: {
      RoundedRectangle(cornerRadius: 13, style: .continuous)
        .fill(isOn ? QGDesign.green : Color.white.opacity(0.20))
        .frame(width: 42, height: 26)
        .overlay(alignment: isOn ? .trailing : .leading) {
          Circle()
            .fill(.white)
            .frame(width: 21, height: 21)
            .padding(.horizontal, 3)
        }
    }
    .buttonStyle(.plain)
    .opacity(isEnabled ? 1 : 0.45)
    .accessibilityLabel(isOn ? "On" : "Off")
  }
}

struct QGIconButtonLabel: View {
  let title: String
  let systemImage: String

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(QGDesign.primaryText)
      .labelStyle(.titleAndIcon)
  }
}

struct QGPrimaryButtonStyle: ButtonStyle {
  var tint: Color = QGDesign.accent

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(QGDesign.primaryText)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(tint.opacity(configuration.isPressed ? 0.27 : 0.20), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
          .strokeBorder(tint.opacity(0.75))
      }
  }
}

struct ProductPage<Content: View>: View {
  private let maxWidth: CGFloat
  private let content: Content

  init(maxWidth: CGFloat = 820, @ViewBuilder content: () -> Content) {
    self.maxWidth = maxWidth
    self.content = content()
  }

  var body: some View {
    QGPage(maxWidth: maxWidth) {
      content
    }
  }
}

struct ProductHeader: View {
  @EnvironmentObject private var store: ProtectionStore
  let title: String
  let subtitle: String
  let systemImage: String

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: systemImage)
        .font(.system(size: 24, weight: .semibold))
        .foregroundStyle(QGDesign.accent)
        .frame(width: 42, height: 42)
        .background(QGDesign.accentSoft, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

      QGScreenHeader(title: title, subtitle: subtitle)

      Spacer(minLength: 16)

      if store.appUpdateAvailable {
        Button {
          store.relaunchToInstalledUpdate()
        } label: {
          QGIconButtonLabel(title: "Update", systemImage: "arrow.triangle.2.circlepath")
        }
        .buttonStyle(QGPrimaryButtonStyle())
        .disabled(store.isWorking)
        .help(store.appUpdateDetail)
      } else {
        QGPill(text: "App up to date", tint: QGDesign.secondaryText)
          .help(store.appUpdateDetail)
          .padding(.top, 5)
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
    QGCard {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(QGDesign.primaryText)
          if let subtitle {
            Text(subtitle)
              .font(.system(size: 13))
              .foregroundStyle(QGDesign.secondaryText)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        content
      }
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
    QGCard {
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: systemImage)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 24)

          VStack(alignment: .leading, spacing: 4) {
            Text(title)
              .font(.system(size: 15, weight: .bold))
              .foregroundStyle(QGDesign.primaryText)
            Text(detail)
              .font(.system(size: 13))
              .foregroundStyle(QGDesign.secondaryText)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        content
      }
    }
  }
}

struct ProductStatusPill: View {
  let text: String
  let tint: Color

  var body: some View {
    QGPill(text: text, tint: tint)
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
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(tint)
        .frame(width: 22)
        .padding(.top, 1)

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(QGDesign.secondaryText)
        Text(detail)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(QGDesign.primaryText)
          .fixedSize(horizontal: false, vertical: true)
        Text(caption)
          .font(.system(size: 12))
          .foregroundStyle(QGDesign.secondaryText)
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
      .fill(QGDesign.hairline)
      .frame(height: 1)
  }
}
