import SwiftData
import SwiftUI

struct GenerationResultView: View {
  let draft: GenerationDraft
  let initiallySaved: Bool
  let onSave: () throws -> Void
  let onReset: () -> Void

  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.modelContext) private var modelContext
  @State private var mode: OutfitVisualAsset
  @State private var isSaved: Bool
  @State private var showShare = false
  @State private var digitalFigurineCard: DigitalFigurineCardPresentation?
  @State private var saveError: String?
  @State private var figurineError: String?

  init(
    draft: GenerationDraft,
    initiallySaved: Bool,
    onSave: @escaping () throws -> Void,
    onReset: @escaping () -> Void
  ) {
    self.draft = draft
    self.initiallySaved = initiallySaved
    self.onSave = onSave
    self.onReset = onReset
    _mode = State(
      initialValue: draft.completionMode == .basicStickerFallback
        || draft.qualityAssessment.requiresReview ? .sticker : .shareCard
    )
    _isSaved = State(initialValue: initiallySaved)
  }

  var body: some View {
    ZStack {
      AdonisTheme.canvas
        .ignoresSafeArea()

      ScrollView {
        VStack(spacing: 20) {
          resultHeader

          resultModePicker

          preview

          if draft.completionMode == .basicStickerFallback {
            GenerationFallbackNotice(
              identifier: "generation-fallback-notice",
              isHistory: false
            )
          }

          if draft.qualityAssessment.requiresReview {
            StickerQualityNotice(assessment: draft.qualityAssessment)
          }

          AccessibilityAdaptiveStack(spacing: 8) {
            StickerTag(
              title: outputTagTitle,
              color: mode == .sticker ? AdonisTheme.leaf.opacity(0.5) : AdonisTheme.butter,
              icon: outputTagIcon
            )
            StickerTag(
              title: "来自\(draft.inputSource.title)",
              color: AdonisTheme.lavender.opacity(0.55),
              icon: "photo.on.rectangle"
            )
          }

          ContentProvenanceNotice(provenance: mode.provenance)

          DigitalFigurineCardEntry {
            makeDigitalFigurineCard()
          }

          if !draft.garmentObservations.isEmpty {
            wardrobeObservationHint
          }

          actionButtons
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 34)
      }
    }
    .sheet(isPresented: $showShare) {
      ActivityView(items: [selectedImage])
        .presentationDetents([.medium, .large])
    }
    .sheet(item: $digitalFigurineCard) { presentation in
      DigitalFigurineCardView(presentation: presentation) {
        EventLogger.log(
          .digitalFigurineCardShareOpened,
          inputSource: draft.inputSource,
          processingVersion: AdonisProcessingVersion.digitalFigurineCard,
          in: modelContext
        )
      }
    }
    .alert(
      "保存失败",
      isPresented: Binding(
        get: { saveError != nil },
        set: { if !$0 { saveError = nil } }
      )
    ) {
      Button("知道了", role: .cancel) {}
    } message: {
      Text(saveError ?? "请稍后再试。")
    }
    .alert(
      "手办卡还没做好",
      isPresented: Binding(
        get: { figurineError != nil },
        set: { if !$0 { figurineError = nil } }
      )
    ) {
      Button("知道了", role: .cancel) {}
    } message: {
      Text(figurineError ?? "请稍后再试。")
    }
  }

  private var wardrobeObservationHint: some View {
    HStack(alignment: .top, spacing: 12) {
      ZStack {
        Circle()
          .fill(AdonisTheme.leaf.opacity(0.24))
          .frame(width: 44, height: 44)
        Image(systemName: "hanger")
          .font(.system(size: 17, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
      }
      .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(isSaved ? "衣橱线索已经留好" : "还看到了穿搭里的衣服")
          .font(.system(.subheadline, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
        Text(
          isSaved
            ? "有 \(draft.garmentObservations.count) 个待确认线索，确认前不会变成衣橱单品。"
            : "收藏今天后留下 \(draft.garmentObservations.count) 个线索，不需要现在整理。"
        )
        .font(.footnote)
        .foregroundStyle(AdonisTheme.secondaryInk)
        .lineSpacing(2)
      }
      Spacer(minLength: 0)
    }
    .padding(15)
    .background(
      AdonisTheme.leaf.opacity(0.1),
      in: RoundedRectangle(cornerRadius: 18, style: .continuous)
    )
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("garment-observation-hint")
  }

  private var resultHeader: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(resultTitle)
          .font(.system(.title2, design: .rounded, weight: .black))
          .foregroundStyle(AdonisTheme.ink)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityAddTraits(.isHeader)
          .accessibilityIdentifier("result-title")
        Text("Bloom No. \(String(format: "%03d", draft.bloomNumber))")
          .font(.system(.subheadline, design: .monospaced, weight: .semibold))
          .foregroundStyle(AdonisTheme.secondaryInk)
      }

      Spacer()

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
      .accessibilityLabel("关闭结果")
    }
  }

  @ViewBuilder
  private var preview: some View {
    switch mode {
    case .shareCard:
      Image(uiImage: draft.cardImage)
        .resizable()
        .scaledToFit()
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: AdonisTheme.ink.opacity(0.15), radius: 18, y: 10)
        .overlay {
          RoundedRectangle(cornerRadius: 26, style: .continuous)
            .stroke(AdonisTheme.ink.opacity(0.08), lineWidth: 1)
        }
        .transition(.opacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("收藏卡预览，人物与衣物来自原始照片")

    case .sticker:
      TransparencyGridBackground()
        .overlay {
          Image(uiImage: draft.stickerImage)
            .resizable()
            .scaledToFit()
            .padding(24)
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 26, style: .continuous)
            .stroke(AdonisTheme.ink.opacity(0.08), lineWidth: 1)
        }
        .transition(.opacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("透明贴纸预览，人物与衣物来自原始照片")

    case .originalPhoto:
      Image(uiImage: draft.sourceImage)
        .resizable()
        .scaledToFit()
        .frame(maxWidth: .infinity)
        .background(AdonisTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 26, style: .continuous)
            .stroke(AdonisTheme.ink.opacity(0.08), lineWidth: 1)
        }
        .transition(.opacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("你选择的原始照片预览")
    }
  }

  @ViewBuilder
  private var resultModePicker: some View {
    if dynamicTypeSize.isAccessibilitySize {
      Picker("预览内容", selection: $mode) {
        ForEach(OutfitVisualAsset.allCases) { mode in
          Text(mode.title)
            .tag(mode)
        }
      }
      .pickerStyle(.menu)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 14)
      .frame(minHeight: 52)
      .background(
        AdonisTheme.paper,
        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
      )
      .accessibilityIdentifier("result-mode-menu")
    } else {
      Picker("预览方式", selection: $mode) {
        ForEach(OutfitVisualAsset.allCases) { mode in
          Text(mode.title)
            .tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .accessibilityIdentifier("result-mode-picker")
    }
  }

  private var selectedImage: UIImage {
    switch mode {
    case .shareCard: draft.cardImage
    case .sticker: draft.stickerImage
    case .originalPhoto: draft.sourceImage
    }
  }

  private func makeDigitalFigurineCard() {
    guard
      let image = DigitalFigurineCardRenderer().render(
        sticker: draft.stickerImage,
        bloomNumber: draft.bloomNumber,
        date: draft.createdAt
      )
    else {
      figurineError = "这张透明贴纸暂时无法放进展台，可以稍后再试。"
      return
    }

    EventLogger.log(
      .digitalFigurineCardCreated,
      inputSource: draft.inputSource,
      processingVersion: AdonisProcessingVersion.digitalFigurineCard,
      in: modelContext
    )
    digitalFigurineCard = DigitalFigurineCardPresentation(
      image: image,
      bloomNumber: draft.bloomNumber,
      date: draft.createdAt
    )
  }

  private var outputTagTitle: String {
    switch mode {
    case .shareCard: "1080 × 1440"
    case .sticker: "真实透明 PNG"
    case .originalPhoto: "原始尺寸"
    }
  }

  private var outputTagIcon: String {
    switch mode {
    case .shareCard: "rectangle.portrait"
    case .sticker: "checkerboard.rectangle"
    case .originalPhoto: "camera.fill"
    }
  }

  private var actionButtons: some View {
    VStack(spacing: 12) {
      Button {
        do {
          try onSave()
          isSaved = true
        } catch {
          saveError = error.localizedDescription
        }
      } label: {
        PrimaryActionLabel(
          title: saveButtonTitle,
          systemImage: isSaved ? "checkmark.circle.fill" : "heart.fill"
        )
      }
      .buttonStyle(StickerButtonStyle())
      .disabled(isSaved)
      .accessibilityIdentifier("save-today")

      AccessibilityAdaptiveStack(spacing: 12) {
        Button {
          showShare = true
        } label: {
          Label("分享", systemImage: "square.and.arrow.up")
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(AdonisTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
              .white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(StickerButtonStyle())
        .accessibilityIdentifier("share-result")

        Button {
          onReset()
          dismiss()
        } label: {
          Label("再做一张", systemImage: "arrow.clockwise")
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(AdonisTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
              AdonisTheme.butter.opacity(0.72),
              in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(StickerButtonStyle())
        .accessibilityIdentifier("make-another")
      }
    }
  }

  private var saveButtonTitle: String {
    if isSaved { return "今天已经收藏" }
    if draft.completionMode == .basicStickerFallback { return "收藏这张贴纸" }
    return draft.qualityAssessment.requiresReview ? "这样也收藏" : "收藏今天"
  }

  private var resultTitle: String {
    if draft.completionMode == .basicStickerFallback {
      return draft.completionMode.resultTitle
    }
    return draft.qualityAssessment.requiresReview ? "先看看这张贴纸" : "今天开了一朵花"
  }
}
