import SwiftUI

struct SystemCreativeProcessingOverlay: View {
  let recipe: CreativeRecipe
  let onCancel: () -> Void

  var body: some View {
    ZStack {
      Color.black.opacity(0.48)
        .ignoresSafeArea()

      VStack(spacing: 18) {
        ProgressView()
          .controlSize(.large)
          .tint(AdonisTheme.pomegranate)
          .accessibilityHidden(true)

        VStack(spacing: 7) {
          Text("正在打开\(recipe.title)")
            .font(.system(.title3, design: .rounded, weight: .black))
            .foregroundStyle(AdonisTheme.ink)
          Text("系统会重新绘制整张画面，最多等待 90 秒。原照片和贴纸不会改变。")
            .font(.footnote)
            .foregroundStyle(AdonisTheme.secondaryInk)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
          "正在生成\(recipe.title)。系统会重新绘制整张画面，最多等待 90 秒。"
        )
        .accessibilityIdentifier("system-creative-status")

        Button("停止这次创作", role: .cancel, action: onCancel)
          .font(.system(.headline, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
          .frame(maxWidth: .infinity, minHeight: 48)
          .background(
            AdonisTheme.butter.opacity(0.72),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
          )
          .buttonStyle(StickerButtonStyle())
          .accessibilityIdentifier("system-creative-cancel")
      }
      .padding(24)
      .frame(maxWidth: 330)
      .background(
        AdonisTheme.paper,
        in: RoundedRectangle(cornerRadius: 28, style: .continuous)
      )
      .shadow(color: .black.opacity(0.22), radius: 24, y: 12)
      .padding(24)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("system-creative-processing")
  }
}
