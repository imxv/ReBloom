import SwiftData
import SwiftUI

struct GenerationResultView: View {
  let draft: GenerationDraft
  let initiallySaved: Bool
  let creativeImageGenerator: any CreativeImageGenerating
  let photoLibrarySaver: PhotoLibrarySaver
  let onSave: () throws -> Void
  let onSaveCreative: (CreativeWorkDraft) throws -> Void
  let onReset: () -> Void

  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.modelContext) private var modelContext
  @State private var mode: OutfitVisualAsset
  @State private var isSaved: Bool
  @State private var showShare = false
  @State private var showCuratedStylePicker = false
  @State private var digitalFigurineCard: DigitalFigurineCardPresentation?
  @State private var creativeWork: CreativeWorkPresentation?
  @State private var photoSaveState: StickerPhotoSaveState = .idle
  @State private var saveError: String?
  @State private var figurineError: String?
  @State private var creativeWorkError: String?
  @State private var activeSystemCreativeID: UUID?
  @State private var activeSystemCreativeRecipe: CreativeRecipe?
  @State private var systemCreativeTimer: CreativeGenerationAttemptTimer?
  @State private var systemCreativeTask: Task<Void, Never>?
  @State private var systemCreativeDeadline = GenerationDeadlineController()

  init(
    draft: GenerationDraft,
    initiallySaved: Bool,
    creativeImageGenerator: any CreativeImageGenerating,
    photoLibrarySaver: PhotoLibrarySaver = .configuredForCurrentProcess,
    onSave: @escaping () throws -> Void,
    onSaveCreative: @escaping (CreativeWorkDraft) throws -> Void,
    onReset: @escaping () -> Void
  ) {
    self.draft = draft
    self.initiallySaved = initiallySaved
    self.creativeImageGenerator = creativeImageGenerator
    self.photoLibrarySaver = photoLibrarySaver
    self.onSave = onSave
    self.onSaveCreative = onSaveCreative
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

          ContentProvenanceNotice(provenance: draft.provenance(for: mode))

          BotanicalPosterEntry {
            makeBotanicalPoster()
          }

          if creativeImageGenerator.availability == .available {
            CuratedStyleGardenEntry {
              showCuratedStylePicker = true
            }
          }

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
      .disabled(activeSystemCreativeID != nil)

      if let activeSystemCreativeRecipe {
        SystemCreativeProcessingOverlay(
          recipe: activeSystemCreativeRecipe,
          onCancel: cancelSystemCreative
        )
        .transition(.opacity)
        .zIndex(3)
      }
    }
    .sheet(isPresented: $showShare) {
      ActivityView(items: [selectedImage])
        .presentationDetents([.medium, .large])
    }
    .sheet(isPresented: $showCuratedStylePicker) {
      CuratedStylePickerView { recipe in
        showCuratedStylePicker = false
        makeSystemCreative(recipe)
      }
      .presentationDetents([.large])
    }
    .sheet(item: $creativeWork) { presentation in
      CreativeWorkView(
        presentation: presentation,
        onSave: {
          try onSaveCreative(presentation.draft)
          isSaved = true
        },
        onShareOpened: {
          EventLogger.log(
            .creativeWorkShareOpened,
            detail: presentation.draft.eventDetail,
            inputSource: draft.inputSource,
            processingVersion: presentation.draft.recipe.version,
            in: modelContext
          )
        }
      )
      .presentationDetents([.large])
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
    .alert(
      "作品还没做好",
      isPresented: Binding(
        get: { creativeWorkError != nil },
        set: { if !$0 { creativeWorkError = nil } }
      )
    ) {
      Button("知道了", role: .cancel) {}
    } message: {
      Text(creativeWorkError ?? "请稍后再试。")
    }
    .onDisappear {
      cancelSystemCreative()
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
        .accessibilityLabel(previewAccessibilityLabel)

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
        .accessibilityLabel(previewAccessibilityLabel)

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

  private var previewAccessibilityLabel: String {
    switch mode {
    case .shareCard:
      "收藏卡预览，\(draft.provenance(for: .shareCard).summary)"
    case .sticker:
      "透明贴纸预览，\(draft.provenance(for: .sticker).summary)"
    case .originalPhoto:
      "你选择的原始照片预览"
    }
  }

  private func makeDigitalFigurineCard() {
    guard
      let image = DigitalFigurineCardRenderer().render(
        sticker: draft.stickerImage,
        bloomNumber: draft.bloomNumber,
        date: draft.createdAt,
        stickerProvenance: draft.stickerProvenance
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
      date: draft.createdAt,
      stickerProvenance: draft.stickerProvenance
    )
  }

  private func makeBotanicalPoster() {
    let startedAt = ContinuousClock.now
    guard
      let image = BotanicalPosterRenderer().render(
        sticker: draft.stickerImage,
        bloomNumber: draft.bloomNumber,
        date: draft.createdAt,
        stickerProvenance: draft.stickerProvenance
      )
    else {
      creativeWorkError = "这张透明贴纸暂时无法排进花影海报，可以稍后再试。"
      return
    }

    let elapsed = startedAt.duration(to: ContinuousClock.now)
    let milliseconds = max(
      0,
      Int(elapsed.components.seconds * 1_000)
        + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
    )
    let creativeDraft = CreativeWorkDraft(
      createdAt: .now,
      recipe: .botanicalPoster,
      image: image,
      processingMilliseconds: milliseconds,
      executionMetadata: .botanicalPoster,
      provenance: BotanicalPosterRenderer.provenance(for: draft.stickerProvenance)
    )
    EventLogger.log(
      .creativeWorkCreated,
      durationMilliseconds: milliseconds,
      detail: creativeDraft.eventDetail,
      inputSource: draft.inputSource,
      processingVersion: creativeDraft.recipe.version,
      in: modelContext
    )
    creativeWork = CreativeWorkPresentation(
      draft: creativeDraft,
      sourceImage: draft.sourceImage,
      isSaved: false
    )
  }

  private func makeSystemCreative(_ recipe: CreativeRecipe) {
    guard activeSystemCreativeID == nil else { return }
    guard recipe.requiresSystemImageGeneration else { return }

    creativeWorkError = nil
    let generationID = UUID()
    let timer = CreativeGenerationAttemptTimer(startedAt: ContinuousClock.now)
    let attemptMetadata = creativeImageGenerator.executionMetadata
    activeSystemCreativeID = generationID
    activeSystemCreativeRecipe = recipe
    systemCreativeTimer = timer

    EventLogger.log(
      .creativeWorkGenerationStarted,
      detail: attemptMetadata.eventDetail(for: recipe),
      inputSource: draft.inputSource,
      processingVersion: recipe.version,
      in: modelContext
    )

    systemCreativeDeadline.arm(
      generationID: generationID,
      timeout: systemCreativeTimeout
    ) { timedOutID in
      timeOutSystemCreative(
        generationID: timedOutID,
        metadata: attemptMetadata,
        timer: timer
      )
    }

    systemCreativeTask = Task { @MainActor in
      do {
        let output = try await creativeImageGenerator.generate(
          sourceImage: draft.sourceImage,
          recipe: recipe
        )
        try Task.checkCancellation()
        finishSystemCreative(
          output: output,
          recipe: recipe,
          generationID: generationID,
          timer: timer
        )
      } catch {
        failSystemCreative(
          error,
          recipe: recipe,
          generationID: generationID,
          metadata: attemptMetadata,
          timer: timer
        )
      }
    }
  }

  private func finishSystemCreative(
    output: CreativeProviderOutput,
    recipe: CreativeRecipe,
    generationID: UUID,
    timer: CreativeGenerationAttemptTimer
  ) {
    guard activeSystemCreativeID == generationID else { return }
    guard
      let image = SystemCreativeCardRenderer().render(
        generatedImage: output.image,
        recipe: recipe,
        bloomNumber: draft.bloomNumber,
        date: draft.createdAt
      )
    else {
      failSystemCreative(
        CreativeGenerationError.noImage,
        recipe: recipe,
        generationID: generationID,
        metadata: output.executionMetadata,
        timer: timer
      )
      return
    }

    let milliseconds = timer.elapsedMilliseconds()
    systemCreativeDeadline.cancel(generationID: generationID)
    activeSystemCreativeID = nil
    activeSystemCreativeRecipe = nil
    systemCreativeTimer = nil
    systemCreativeTask = nil

    let creativeDraft = CreativeWorkDraft(
      createdAt: .now,
      recipe: recipe,
      image: image,
      processingMilliseconds: milliseconds,
      executionMetadata: output.executionMetadata
    )
    EventLogger.log(
      .creativeWorkCreated,
      durationMilliseconds: milliseconds,
      detail: creativeDraft.eventDetail,
      inputSource: draft.inputSource,
      processingVersion: creativeDraft.recipe.version,
      in: modelContext
    )
    creativeWork = CreativeWorkPresentation(
      draft: creativeDraft,
      sourceImage: draft.sourceImage,
      isSaved: false
    )
  }

  private func failSystemCreative(
    _ error: Error,
    recipe: CreativeRecipe,
    generationID: UUID,
    metadata: CreativeExecutionMetadata,
    timer: CreativeGenerationAttemptTimer
  ) {
    guard activeSystemCreativeID == generationID else { return }

    let generationError: CreativeGenerationError
    if let error = error as? CreativeGenerationError {
      generationError = error
    } else if error is CancellationError {
      generationError = .cancelled
    } else {
      generationError = .failed
    }

    systemCreativeDeadline.cancel(generationID: generationID)
    activeSystemCreativeID = nil
    activeSystemCreativeRecipe = nil
    systemCreativeTimer = nil
    systemCreativeTask = nil
    let milliseconds = timer.elapsedMilliseconds()
    let detail =
      metadata.eventDetail(for: recipe)
      + ";error=\(generationError.eventCode)"

    switch generationError {
    case .cancelled:
      EventLogger.log(
        .creativeWorkGenerationCancelled,
        durationMilliseconds: milliseconds,
        detail: detail,
        inputSource: draft.inputSource,
        processingVersion: recipe.version,
        in: modelContext
      )
    case .timedOut:
      EventLogger.log(
        .creativeWorkGenerationTimedOut,
        durationMilliseconds: milliseconds,
        detail: detail,
        inputSource: draft.inputSource,
        processingVersion: recipe.version,
        in: modelContext
      )
      creativeWorkError = generationError.localizedDescription
    default:
      EventLogger.log(
        .creativeWorkGenerationFailed,
        durationMilliseconds: milliseconds,
        detail: detail,
        inputSource: draft.inputSource,
        processingVersion: recipe.version,
        in: modelContext
      )
      creativeWorkError = generationError.localizedDescription
    }
  }

  private func cancelSystemCreative() {
    guard
      let generationID = activeSystemCreativeID,
      let recipe = activeSystemCreativeRecipe,
      let timer = systemCreativeTimer
    else { return }
    let metadata = creativeImageGenerator.executionMetadata
    activeSystemCreativeID = nil
    activeSystemCreativeRecipe = nil
    systemCreativeTimer = nil
    systemCreativeDeadline.cancel(generationID: generationID)
    let task = systemCreativeTask
    systemCreativeTask = nil
    task?.cancel()
    EventLogger.log(
      .creativeWorkGenerationCancelled,
      durationMilliseconds: timer.elapsedMilliseconds(),
      detail: metadata.eventDetail(for: recipe) + ";error=cancelled",
      inputSource: draft.inputSource,
      processingVersion: recipe.version,
      in: modelContext
    )
  }

  private func timeOutSystemCreative(
    generationID: UUID,
    metadata: CreativeExecutionMetadata,
    timer: CreativeGenerationAttemptTimer
  ) {
    guard activeSystemCreativeID == generationID else { return }
    guard let recipe = activeSystemCreativeRecipe else { return }
    activeSystemCreativeID = nil
    activeSystemCreativeRecipe = nil
    systemCreativeTimer = nil
    let task = systemCreativeTask
    systemCreativeTask = nil
    task?.cancel()
    EventLogger.log(
      .creativeWorkGenerationTimedOut,
      durationMilliseconds: timer.elapsedMilliseconds(),
      detail: metadata.eventDetail(for: recipe) + ";error=timed_out",
      inputSource: draft.inputSource,
      processingVersion: recipe.version,
      in: modelContext
    )
    creativeWorkError = CreativeGenerationError.timedOut.localizedDescription
  }

  private var systemCreativeTimeout: Duration {
    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("-ui-testing-system-creative-timeout") {
        return .seconds(2)
      }
    #endif
    return GenerationDeadlineController.productionTimeout
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
          saveStickerToPhotos()
        } label: {
          HStack(spacing: 8) {
            if photoSaveState == .saving {
              ProgressView()
                .tint(AdonisTheme.ink)
            } else {
              Image(
                systemName: photoSaveState == .saved
                  ? "checkmark.circle.fill" : "square.and.arrow.down"
              )
            }
            Text(photoSaveState.buttonTitle)
          }
          .font(.system(.headline, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
          .frame(maxWidth: .infinity, minHeight: 52)
          .background(
            AdonisTheme.leaf.opacity(0.22),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
          )
        }
        .buttonStyle(StickerButtonStyle())
        .disabled(photoSaveState == .saving || photoSaveState == .saved)
        .accessibilityIdentifier("save-sticker-to-photos")

        Button {
          if photoSaveState.isFailure {
            mode = .sticker
          }
          showShare = true
        } label: {
          Label(
            photoSaveState.isFailure ? "分享贴纸" : "分享",
            systemImage: "square.and.arrow.up"
          )
          .font(.system(.headline, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
          .frame(maxWidth: .infinity, minHeight: 52)
          .background(
            .white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(StickerButtonStyle())
        .accessibilityIdentifier(
          photoSaveState.isFailure ? "photo-save-share-fallback" : "share-result"
        )
      }

      if case .failed(let error) = photoSaveState {
        photoSaveFailureNotice(error)
      }

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

  private func saveStickerToPhotos() {
    guard photoSaveState != .saving, photoSaveState != .saved else { return }
    photoSaveState = .saving
    Task { @MainActor in
      do {
        try await photoLibrarySaver.save(draft.stickerImage)
        photoSaveState = .saved
        EventLogger.log(
          .stickerPhotoSaved,
          detail: "asset=sticker",
          inputSource: draft.inputSource,
          in: modelContext
        )
      } catch {
        let saveError = error as? PhotoLibrarySaveError ?? .writeFailed
        photoSaveState = .failed(saveError)
        EventLogger.log(
          .stickerPhotoSaveFailed,
          detail: "asset=sticker;reason=\(saveError.eventCode)",
          inputSource: draft.inputSource,
          in: modelContext
        )
      }
    }
  }

  private func photoSaveFailureNotice(_ error: PhotoLibrarySaveError) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "photo.badge.exclamationmark")
        .font(.system(size: 18, weight: .bold))
        .foregroundStyle(AdonisTheme.ink)
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 5) {
        Text("没有存进相册")
          .font(.system(.headline, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
        Text(error.localizedDescription)
          .font(.subheadline)
          .foregroundStyle(AdonisTheme.secondaryInk)
        Text("原贴纸还在，可以点“分享贴纸”继续，收藏也不受影响。")
          .font(.footnote)
          .foregroundStyle(AdonisTheme.secondaryInk)
      }
      .fixedSize(horizontal: false, vertical: true)
    }
    .padding(15)
    .background(
      AdonisTheme.butter.opacity(0.46),
      in: RoundedRectangle(cornerRadius: 18, style: .continuous)
    )
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("photo-save-failure")
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

private enum StickerPhotoSaveState: Equatable {
  case idle
  case saving
  case saved
  case failed(PhotoLibrarySaveError)

  var buttonTitle: String {
    switch self {
    case .idle: "存透明贴纸"
    case .saving: "正在保存贴纸"
    case .saved: "贴纸已存到相册"
    case .failed: "再试一次"
    }
  }

  var isFailure: Bool {
    if case .failed = self { return true }
    return false
  }
}
