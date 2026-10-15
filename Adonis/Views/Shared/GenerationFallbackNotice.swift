import SwiftUI

struct GenerationFallbackNotice: View {
  let identifier: String
  let isHistory: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      ZStack {
        Circle()
          .fill(AdonisTheme.butter.opacity(0.8))
          .frame(width: 44, height: 44)
        Image(systemName: "clock.badge.checkmark")
          .font(.system(size: 17, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
      }
      .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(isHistory ? "这是一张基础贴纸结果" : "先为你保住了基础贴纸")
          .font(.system(.subheadline, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
        Text(
          isHistory
            ? "当时等待到 90 秒后结束了后续整理；贴纸与收藏卡可以正常使用，但没有生成衣物线索。"
            : "等待到 90 秒后，ReBloom 结束了后续整理。贴纸与收藏卡可以正常保存；这次没有生成衣物线索。"
        )
        .font(.footnote)
        .foregroundStyle(AdonisTheme.secondaryInk)
        .lineSpacing(2)
      }
      Spacer(minLength: 0)
    }
    .padding(15)
    .background(
      AdonisTheme.butter.opacity(0.24),
      in: RoundedRectangle(cornerRadius: 18, style: .continuous)
    )
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(identifier)
  }
}
