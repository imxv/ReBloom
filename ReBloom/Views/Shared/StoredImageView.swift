import SwiftUI

struct StoredImageView: View {
  let filename: String
  var contentMode: ContentMode = .fill

  var body: some View {
    Group {
      if let image = MediaStore.shared.image(filename: filename) {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: contentMode)
      } else {
        ZStack {
          AdonisTheme.canvas
          Image(systemName: "photo.badge.exclamationmark")
            .font(.title2)
            .foregroundStyle(AdonisTheme.secondaryInk)
        }
      }
    }
    .accessibilityLabel("本地图片")
  }
}

struct EmptyGardenView: View {
  let title: String
  let message: String
  let systemImage: String

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    VStack(spacing: 14) {
      ZStack {
        Circle()
          .fill(AdonisTheme.butter.opacity(0.6))
          .frame(width: 84, height: 84)
        Image(systemName: systemImage)
          .font(.system(size: 34, weight: .medium))
          .foregroundStyle(AdonisTheme.ink)
      }
      .accessibilityHidden(true)

      Text(title)
        .font(.system(.title3, design: .rounded, weight: .bold))
        .foregroundStyle(AdonisTheme.ink)
        .fixedSize(horizontal: false, vertical: true)

      Text(message)
        .font(.subheadline)
        .foregroundStyle(AdonisTheme.secondaryInk)
        .multilineTextAlignment(.center)
        .lineSpacing(3)
        .frame(maxWidth: 280)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 24 : 44)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title)。\(message)")
  }
}
