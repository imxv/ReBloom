import SwiftUI

struct WardrobeColorDot: View {
  let hex: String?
  var size: CGFloat = 12

  var body: some View {
    Circle()
      .fill(Color(adonisHexString: hex) ?? AdonisTheme.canvas)
      .frame(width: size, height: size)
      .overlay {
        Circle()
          .stroke(AdonisTheme.ink.opacity(0.14), lineWidth: 1)
      }
      .accessibilityHidden(true)
  }
}

struct WardrobeMetadataChip: View {
  let title: String
  let systemImage: String
  var color = AdonisTheme.leaf.opacity(0.22)
  var colorHex: String?

  var body: some View {
    HStack(spacing: 7) {
      if colorHex != nil {
        WardrobeColorDot(hex: colorHex, size: 14)
      } else {
        Image(systemName: systemImage)
          .font(.system(size: 12, weight: .bold))
      }
      Text(title)
        .lineLimit(1)
    }
    .font(.system(.caption, design: .rounded, weight: .bold))
    .foregroundStyle(AdonisTheme.ink)
    .padding(.horizontal, 11)
    .frame(minHeight: 34)
    .background(color, in: Capsule())
  }
}

extension Color {
  fileprivate init?(adonisHexString value: String?) {
    guard let value else { return nil }
    let normalized = value.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard normalized.count == 6, let number = UInt(normalized, radix: 16) else {
      return nil
    }
    self.init(hex: number)
  }
}
