import SwiftUI

struct CuratedStyleGardenEntry: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 16) {
        ZStack {
          ForEach(Array(CreativeRecipe.curatedSystemRecipes.enumerated()), id: \.offset) {
            index, recipe in
            CuratedStyleArtwork(recipe: recipe)
              .frame(width: 55, height: 76)
              .rotationEffect(.degrees(Double(index - 1) * 9))
              .offset(x: CGFloat(index - 1) * 18, y: CGFloat(abs(index - 1)) * 4)
          }
        }
        .frame(width: 94, height: 104)
        .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 5) {
          Text("3 个精选世界")
            .font(.caption.weight(.bold))
            .foregroundStyle(AdonisTheme.pomegranateInk)
          Text("风格花园")
            .font(.system(.title3, design: .rounded, weight: .black))
            .foregroundStyle(AdonisTheme.ink)
          Text("选一个感觉，一点就开始")
            .font(.footnote)
            .foregroundStyle(AdonisTheme.secondaryInk)
          Text("都会重新绘制人物、衣服和背景")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AdonisTheme.pomegranateInk)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 4)
        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .black))
          .foregroundStyle(AdonisTheme.ink)
          .accessibilityHidden(true)
      }
      .padding(14)
      .background(
        LinearGradient(
          colors: [
            AdonisTheme.pomegranate.opacity(0.13),
            AdonisTheme.lavender.opacity(0.28),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        in: RoundedRectangle(cornerRadius: 22, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .stroke(AdonisTheme.pomegranate.opacity(0.26), lineWidth: 1)
      }
    }
    .buttonStyle(StickerButtonStyle())
    .accessibilityLabel(
      "打开风格花园，选择三个精选风格之一；都会重新绘制人物、衣服和背景"
    )
    .accessibilityIdentifier("curated-style-garden-entry")
  }
}

struct CuratedStylePickerView: View {
  let onSelect: (CreativeRecipe) -> Void

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ZStack {
        AdonisTheme.canvas
          .ignoresSafeArea()

        ScrollView {
          VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
              Text("今天想走进哪个世界？")
                .font(.system(.title2, design: .rounded, weight: .black))
                .foregroundStyle(AdonisTheme.ink)
                .accessibilityAddTraits(.isHeader)
              Text("只选一个感觉就好，不需要设置其他东西。")
                .font(.subheadline)
                .foregroundStyle(AdonisTheme.secondaryInk)
            }

            HStack(alignment: .top, spacing: 10) {
              Image(systemName: "wand.and.stars")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AdonisTheme.pomegranateInk)
                .frame(width: 36, height: 36)
                .background(AdonisTheme.pomegranate.opacity(0.16), in: Circle())
                .accessibilityHidden(true)
              VStack(alignment: .leading, spacing: 3) {
                Text("都会重新绘制整张画面")
                  .font(.subheadline.weight(.black))
                  .foregroundStyle(AdonisTheme.ink)
                Text("人物、衣服和背景可能变化；完成后可以与原图对照，再决定是否收藏。")
                  .font(.footnote)
                  .foregroundStyle(AdonisTheme.secondaryInk)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
            .padding(14)
            .background(
              AdonisTheme.butter.opacity(0.3),
              in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("curated-style-boundary")

            ForEach(CreativeRecipe.curatedSystemRecipes) { recipe in
              CuratedStyleOption(recipe: recipe) {
                dismiss()
                onSelect(recipe)
              }
            }
          }
          .padding(.horizontal, 20)
          .padding(.top, 8)
          .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
      }
      .navigationTitle("风格花园")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("稍后") {
            dismiss()
          }
          .fontWeight(.bold)
          .foregroundStyle(AdonisTheme.ink)
          .accessibilityIdentifier("close-curated-style-picker")
        }
      }
    }
    .accessibilityIdentifier("curated-style-picker")
  }
}

private struct CuratedStyleOption: View {
  let recipe: CreativeRecipe
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 15) {
        CuratedStyleArtwork(recipe: recipe)
          .frame(width: 82, height: 108)
          .shadow(color: AdonisTheme.ink.opacity(0.16), radius: 8, y: 5)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 5) {
          Text(styleLabel)
            .font(.caption.weight(.black))
            .foregroundStyle(accent)
          Text(recipe.title)
            .font(.system(.title3, design: .rounded, weight: .black))
            .foregroundStyle(AdonisTheme.ink)
          Text(recipe.subtitle)
            .font(.footnote)
            .foregroundStyle(AdonisTheme.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 4)
        Image(systemName: "arrow.up.right")
          .font(.system(size: 14, weight: .black))
          .foregroundStyle(AdonisTheme.ink)
          .accessibilityHidden(true)
      }
      .padding(14)
      .frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
      .background(
        Color.white.opacity(0.76),
        in: RoundedRectangle(cornerRadius: 23, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 23, style: .continuous)
          .stroke(accent.opacity(0.26), lineWidth: 1)
      }
    }
    .buttonStyle(StickerButtonStyle())
    .accessibilityLabel(
      "选择\(recipe.title)，\(recipe.subtitle)；会重新绘制人物、衣服和背景"
    )
    .accessibilityIdentifier("curated-style-option-\(recipe.rawValue)")
  }

  private var styleLabel: String {
    switch recipe {
    case .mythicGarden: "植物神话插画"
    case .floralSketch: "纸上时装速写"
    case .moonlitTheater: "蓝夜动画剧照"
    case .aiStickerSource, .botanicalPoster, .stickerTryOn: "精选风格"
    }
  }

  private var accent: Color {
    switch recipe {
    case .mythicGarden: AdonisTheme.pomegranate
    case .floralSketch: Color(hex: 0xB5443B)
    case .moonlitTheater: Color(hex: 0x294FA3)
    case .aiStickerSource, .botanicalPoster, .stickerTryOn: AdonisTheme.leaf
    }
  }
}

private struct CuratedStyleArtwork: View {
  let recipe: CreativeRecipe

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(background)

      Circle()
        .fill(highlight)
        .frame(width: 46, height: 46)
        .offset(x: 19, y: -28)

      Capsule()
        .fill(figure)
        .frame(width: 35, height: 70)
        .offset(x: -7, y: 11)

      ForEach(0..<3, id: \.self) { index in
        Capsule()
          .fill(index == 1 ? highlight.opacity(0.92) : detail)
          .frame(width: 42, height: 10)
          .rotationEffect(.degrees(Double(index * 49 - 42)))
          .offset(x: CGFloat(index * 9 - 12), y: CGFloat(index * 15 + 18))
      }

      Image(systemName: symbol)
        .font(.system(size: 14, weight: .black))
        .foregroundStyle(.white)
        .offset(x: -22, y: -34)
    }
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private var background: Color {
    switch recipe {
    case .mythicGarden: Color(hex: 0x24141F)
    case .floralSketch: Color(hex: 0xE9DCC2)
    case .moonlitTheater: Color(hex: 0x10255E)
    case .aiStickerSource, .botanicalPoster, .stickerTryOn: AdonisTheme.ink
    }
  }

  private var highlight: Color {
    switch recipe {
    case .mythicGarden: AdonisTheme.pomegranate
    case .floralSketch: Color(hex: 0xB5443B)
    case .moonlitTheater: Color(hex: 0xFF646B)
    case .aiStickerSource, .botanicalPoster, .stickerTryOn: AdonisTheme.butter
    }
  }

  private var figure: Color {
    switch recipe {
    case .mythicGarden: AdonisTheme.leaf
    case .floralSketch: Color(hex: 0x40342D)
    case .moonlitTheater: Color(hex: 0x4DA9C8)
    case .aiStickerSource, .botanicalPoster, .stickerTryOn: AdonisTheme.paper
    }
  }

  private var detail: Color {
    switch recipe {
    case .mythicGarden: AdonisTheme.butter
    case .floralSketch: Color(hex: 0x5F7A4C)
    case .moonlitTheater: Color(hex: 0xFFD46D)
    case .aiStickerSource, .botanicalPoster, .stickerTryOn: AdonisTheme.pomegranate
    }
  }

  private var symbol: String {
    switch recipe {
    case .mythicGarden: "sparkles"
    case .floralSketch: "pencil.tip"
    case .moonlitTheater: "moon.stars.fill"
    case .aiStickerSource, .botanicalPoster, .stickerTryOn: "wand.and.stars"
    }
  }
}
