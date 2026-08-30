import SwiftUI

struct CreativeWorkPresentation: Identifiable {
  let draft: CreativeWorkDraft
  let sourceImage: UIImage
  let isSaved: Bool

  var id: UUID { draft.id }
}

private enum CreativeWorkPreviewAsset: String, CaseIterable, Identifiable {
  case work
  case originalPhoto

  var id: String { rawValue }

  func title(for recipe: CreativeRecipe) -> String {
    switch self {
    case .work: recipe.title
    case .originalPhoto: "原始照片"
    }
  }
}

struct CreativeWorkView: View {
  let presentation: CreativeWorkPresentation
  let onSave: (() throws -> Void)?
  let onShareOpened: () -> Void

  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var previewAsset = CreativeWorkPreviewAsset.work
  @State private var isSaved: Bool
  @State private var showShare = false
  @State private var saveError: String?

  init(
    presentation: CreativeWorkPresentation,
    onSave: (() throws -> Void)? = nil,
    onShareOpened: @escaping () -> Void = {}
  ) {
    self.presentation = presentation
    self.onSave = onSave
    self.onShareOpened = onShareOpened
    _isSaved = State(initialValue: presentation.isSaved)
  }

  var body: some View {
    ZStack {
      AdonisTheme.canvas
        .ignoresSafeArea()

      ScrollView {
        VStack(spacing: 20) {
          header
          previewPicker
          preview

          AccessibilityAdaptiveStack(spacing: 8) {
            StickerTag(
              title: outputDimensionsTitle,
              color: AdonisTheme.butter,
              icon: "rectangle.portrait"
            )
            StickerTag(
              title: executionTagTitle,
              color: AdonisTheme.leaf.opacity(0.48),
              icon: executionTagIcon
            )
          }

          ContentProvenanceNotice(
            provenance: presentation.draft.provenance,
            detail: provenanceDetail,
            identifier: "creative-work-provenance",
            summary: provenanceSummary
          )

          HStack(alignment: .top, spacing: 12) {
            Image(systemName: "eye.fill")
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(AdonisTheme.ink)
              .frame(width: 40, height: 40)
              .background(AdonisTheme.pomegranate.opacity(0.22), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
              Text(boundaryTitle)
                .font(.system(.subheadline, design: .rounded, weight: .black))
                .foregroundStyle(AdonisTheme.ink)
              Text(boundaryDetail)
                .font(.footnote)
                .foregroundStyle(AdonisTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
          }
          .padding(14)
          .background(
            AdonisTheme.pomegranate.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
          )
          .accessibilityElement(children: .combine)
          .accessibilityIdentifier("creative-work-boundary")

          actions
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 34)
      }
      .scrollIndicators(.hidden)
    }
    .sheet(isPresented: $showShare) {
      ActivityView(items: [presentation.draft.image])
        .presentationDetents([.medium, .large])
    }
    .alert(
      "作品没有收藏成功",
      isPresented: Binding(
        get: { saveError != nil },
        set: { if !$0 { saveError = nil } }
      )
    ) {
      Button("知道了", role: .cancel) {}
    } message: {
      Text(saveError ?? "请稍后再试。")
    }
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 4) {
        Text(presentation.draft.recipe.title)
          .font(.system(.title2, design: .rounded, weight: .black))
          .foregroundStyle(AdonisTheme.ink)
          .accessibilityAddTraits(.isHeader)
        Text(presentation.draft.recipe.subtitle)
          .font(.subheadline)
          .foregroundStyle(AdonisTheme.secondaryInk)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 12)

      Button {
        dismiss()
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
          .frame(width: 44, height: 44)
          .background(.white.opacity(0.8), in: Circle())
      }
      .buttonStyle(StickerButtonStyle())
      .accessibilityLabel("关闭\(presentation.draft.recipe.title)")
      .accessibilityIdentifier("close-creative-work")
    }
  }

  @ViewBuilder
  private var previewPicker: some View {
    if dynamicTypeSize.isAccessibilitySize {
      VStack(spacing: 8) {
        ForEach(CreativeWorkPreviewAsset.allCases) { asset in
          Button {
            previewAsset = asset
          } label: {
            HStack(spacing: 10) {
              Text(asset.title(for: presentation.draft.recipe))
                .font(.body.weight(.bold))
                .multilineTextAlignment(.leading)
              Spacer(minLength: 8)
              Image(
                systemName: previewAsset == asset
                  ? "checkmark.circle.fill"
                  : "circle"
              )
              .font(.title3.weight(.bold))
            }
            .foregroundStyle(AdonisTheme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(
              previewAsset == asset
                ? AdonisTheme.butter.opacity(0.58)
                : AdonisTheme.paper,
              in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
          }
          .buttonStyle(.plain)
          .accessibilityLabel(asset.title(for: presentation.draft.recipe))
          .accessibilityValue(previewAsset == asset ? "已选择" : "未选择")
          .accessibilityIdentifier("creative-work-mode-\(asset.rawValue)")
        }
      }
    } else {
      Picker("对照查看", selection: $previewAsset) {
        ForEach(CreativeWorkPreviewAsset.allCases) { asset in
          Text(asset.title(for: presentation.draft.recipe)).tag(asset)
        }
      }
      .pickerStyle(.segmented)
      .accessibilityIdentifier("creative-work-mode-picker")
    }
  }

  private var preview: some View {
    Group {
      switch previewAsset {
      case .work:
        Image(uiImage: presentation.draft.image)
          .resizable()
          .scaledToFit()
      case .originalPhoto:
        Image(uiImage: presentation.sourceImage)
          .resizable()
          .scaledToFit()
          .frame(maxWidth: .infinity)
          .background(AdonisTheme.paper)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 26, style: .continuous)
        .stroke(AdonisTheme.ink.opacity(0.09), lineWidth: 1)
    }
    .shadow(color: AdonisTheme.ink.opacity(0.14), radius: 18, y: 10)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      previewAsset == .work
        ? "\(presentation.draft.recipe.title)预览" : "原始照片对照预览"
    )
    .accessibilityIdentifier("creative-work-preview")
  }

  private var actions: some View {
    VStack(spacing: 12) {
      if let onSave {
        Button {
          do {
            try onSave()
            isSaved = true
          } catch {
            saveError = error.localizedDescription
          }
        } label: {
          PrimaryActionLabel(
            title: isSaved ? "作品已经收藏" : "收藏这张作品",
            systemImage: isSaved ? "checkmark.circle.fill" : "heart.fill"
          )
        }
        .buttonStyle(StickerButtonStyle())
        .disabled(isSaved)
        .accessibilityIdentifier("save-creative-work")
      }

      Button {
        onShareOpened()
        showShare = true
      } label: {
        Label("分享\(presentation.draft.recipe.title)", systemImage: "square.and.arrow.up")
          .font(.system(.headline, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
          .frame(maxWidth: .infinity, minHeight: 52)
          .background(
            .white.opacity(0.78),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
          )
      }
      .buttonStyle(StickerButtonStyle())
      .accessibilityIdentifier("share-creative-work")
    }
  }

  private var executionTagTitle: String {
    switch presentation.draft.recipe {
    case .botanicalPoster: "本机创作"
    case .aiStickerSource, .floralSketch, .mythicGarden, .moonlitTheater: "系统创作"
    case .stickerTryOn: "本机试搭"
    }
  }

  private var outputDimensionsTitle: String {
    let size = presentation.draft.image.size
    return "\(Int(size.width.rounded())) × \(Int(size.height.rounded()))"
  }

  private var executionTagIcon: String {
    switch presentation.draft.recipe {
    case .botanicalPoster: "iphone"
    case .aiStickerSource, .floralSketch, .mythicGarden, .moonlitTheater: "sparkles"
    case .stickerTryOn: "tshirt"
    }
  }

  private var provenanceDetail: String {
    switch presentation.draft.recipe {
    case .botanicalPoster:
      presentation.draft.provenance.containsAIGeneratedPixels
        ? "人物、衣物、姿势和纯白边沿用 AI 贴纸像素；背景、花影与文字由 Adonis 本机排版，没有再次重绘人物或衣物。"
        : "人物、衣物、姿势和纯白边直接复用原图贴纸；背景、花影与文字由 Adonis 本机排版，不含 AI 重绘。"
    case .aiStickerSource, .floralSketch, .mythicGarden, .moonlitTheater:
      "原始照片只作为创作参考；画面包含系统生成或重绘的人物、衣物和背景，请与原图对照后再收藏。"
    case .stickerTryOn:
      "人物与背景来自 OOTD 原始照片；衣物来自商品图，由本机裁切、缩放并覆盖到上身位置，不含 AI 重绘。"
    }
  }

  private var provenanceSummary: String? {
    guard presentation.draft.recipe == .stickerTryOn else { return nil }
    return "人物与背景来自 OOTD · 衣物来自商品图"
  }

  private var boundaryTitle: String {
    switch presentation.draft.recipe {
    case .botanicalPoster: "只是一张风格海报"
    case .aiStickerSource, .floralSketch, .mythicGarden, .moonlitTheater:
      "人物和衣服都可能改变"
    case .stickerTryOn: "只是一张贴纸试搭草图"
    }
  }

  private var boundaryDetail: String {
    switch presentation.draft.recipe {
    case .botanicalPoster:
      "它不是试穿效果，也不代表一张真实拍摄的新照片。"
    case .aiStickerSource, .floralSketch, .mythicGarden, .moonlitTheater:
      "请把它当作风格插画，不是试穿效果，也不是真实拍摄的新照片。"
    case .stickerTryOn:
      "它不预测尺码、合身度、垂坠、褶皱或真实遮挡，请只用来快速看看配色和轮廓。"
    }
  }
}

struct BotanicalPosterEntry: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 16) {
        ZStack {
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(hex: 0x291F24))
          Circle()
            .fill(AdonisTheme.pomegranate)
            .frame(width: 50, height: 50)
            .offset(x: 22, y: -24)
          Capsule()
            .fill(AdonisTheme.leaf)
            .frame(width: 58, height: 22)
            .rotationEffect(.degrees(-24))
            .offset(x: 12, y: 18)
          Text("花影")
            .font(.system(.caption, design: .rounded, weight: .black))
            .foregroundStyle(.white)
            .offset(x: -13, y: 7)
        }
        .frame(width: 88, height: 104)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 5) {
          Text("再变一个版本")
            .font(.caption.weight(.bold))
            .foregroundStyle(AdonisTheme.pomegranateInk)
          Text("花影海报")
            .font(.system(.title3, design: .rounded, weight: .black))
            .foregroundStyle(AdonisTheme.ink)
          Text("一键排版，贴纸内容保持不变")
            .font(.footnote)
            .foregroundStyle(AdonisTheme.secondaryInk)
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
        AdonisTheme.lavender.opacity(0.25),
        in: RoundedRectangle(cornerRadius: 22, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .stroke(AdonisTheme.ink.opacity(0.08), lineWidth: 1)
      }
    }
    .buttonStyle(StickerButtonStyle())
    .accessibilityLabel("制作花影海报，一键排版，贴纸内容保持不变")
    .accessibilityIdentifier("botanical-poster-entry")
  }
}
