import SwiftUI

struct AdonisWordmark: View {
  var compact = false

  var body: some View {
    HStack(spacing: 8) {
      DoodleFlower(size: compact ? 24 : 30)

      Text("ADONIS")
        .font(.system(size: compact ? 20 : 25, weight: .black, design: .rounded))
        .tracking(1.8)
        .foregroundStyle(AdonisTheme.ink)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Adonis")
  }
}

struct DoodleFlower: View {
  let size: CGFloat

  var body: some View {
    ZStack {
      ForEach(0..<5, id: \.self) { index in
        Capsule()
          .fill(index.isMultiple(of: 2) ? AdonisTheme.pomegranate : AdonisTheme.butter)
          .frame(width: size * 0.34, height: size * 0.55)
          .offset(y: -size * 0.22)
          .rotationEffect(.degrees(Double(index) * 72))
      }

      Circle()
        .fill(AdonisTheme.ink)
        .frame(width: size * 0.23, height: size * 0.23)
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

struct StickerTag: View {
  let title: String
  let color: Color
  var icon: String?

  var body: some View {
    HStack(spacing: 6) {
      if let icon {
        Image(systemName: icon)
      }
      Text(title)
    }
    .font(.system(.caption, design: .rounded, weight: .bold))
    .foregroundStyle(AdonisTheme.ink)
    .padding(.horizontal, 12)
    .frame(minHeight: 32)
    .background(color, in: Capsule())
    .overlay {
      Capsule()
        .stroke(.white.opacity(0.75), lineWidth: 2)
    }
    .rotationEffect(.degrees(-1.5))
  }
}

struct PaperSurfaceModifier: ViewModifier {
  var radius: CGFloat = AdonisTheme.largeRadius

  func body(content: Content) -> some View {
    content
      .background(AdonisTheme.paper, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
      .shadow(color: AdonisTheme.ink.opacity(0.06), radius: 2, y: 1)
      .shadow(color: AdonisTheme.ink.opacity(0.08), radius: 16, y: 8)
  }
}

extension View {
  func paperSurface(radius: CGFloat = AdonisTheme.largeRadius) -> some View {
    modifier(PaperSurfaceModifier(radius: radius))
  }
}

struct StickerButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
      .opacity(configuration.isPressed ? 0.88 : 1)
      .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
  }
}

struct PrimaryActionLabel: View {
  let title: String
  let systemImage: String

  var body: some View {
    HStack(spacing: 10) {
      Text(title)
        .font(.system(.headline, design: .rounded, weight: .bold))
      Image(systemName: systemImage)
        .font(.system(size: 16, weight: .bold))
    }
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity, minHeight: 54)
    .padding(.horizontal, 18)
    .background(AdonisTheme.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .shadow(color: AdonisTheme.ink.opacity(0.14), radius: 10, y: 6)
  }
}
