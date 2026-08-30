import SwiftData
import SwiftUI

struct StickerTryOnEntry: View {
  @Bindable var item: WardrobeItem

  @Environment(\.modelContext) private var modelContext
  @Query(sort: \OutfitRecord.createdAt, order: .reverse) private var outfits: [OutfitRecord]
  @State private var activeGenerationID: UUID?
  @State private var activeTask: Task<Void, Never>?
  @State private var attemptTimer: CreativeGenerationAttemptTimer?
  @State private var sourceOutfit: OutfitRecord?
  @State private var creativeWork: CreativeWorkPresentation?
  @State private var errorMessage: String?

  private let generator: any StickerTryOnGenerating

  init(
    item: WardrobeItem,
    generator: any StickerTryOnGenerating = StickerTryOnGeneratorFactory.make()
  ) {
    self.item = item
    self.generator = generator
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 15) {
      HStack(alignment: .top, spacing: 12) {
        ZStack {
          RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(AdonisTheme.pomegranate.opacity(0.16))
          Image(systemName: "tshirt.fill")
            .font(.system(size: 20, weight: .black))
            .foregroundStyle(AdonisTheme.pomegranateInk)
        }
        .frame(width: 48, height: 48)
        .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
          Text("贴纸试搭")
            .font(.system(.headline, design: .rounded, weight: .black))
            .foregroundStyle(AdonisTheme.ink)
          Text("商品图 + 最近 OOTD，一次点完")
            .font(.caption)
            .foregroundStyle(AdonisTheme.secondaryInk)
        }

        Spacer(minLength: 6)
        Text("本机")
          .font(.caption2.weight(.black))
          .foregroundStyle(AdonisTheme.leafInk)
          .padding(.horizontal, 9)
          .frame(minHeight: 28)
          .background(AdonisTheme.leaf.opacity(0.25), in: Capsule())
      }

      sourcePreview

      if activeGenerationID != nil {
        processingState
      } else if readiness == .ready, let latestOutfit {
        Button {
          start(using: latestOutfit)
        } label: {
          PrimaryActionLabel(title: "试试穿在我身上", systemImage: "sparkles")
        }
        .buttonStyle(StickerButtonStyle())
        .accessibilityLabel("用最近一次 OOTD 制作贴纸试搭草图")
        .accessibilityIdentifier("sticker-try-on-entry")
      } else {
        unavailableState
      }

      Text("只会裁切、缩放和覆盖衣物图，不预测尺码、合身度、垂坠或真实遮挡。")
        .font(.caption2)
        .foregroundStyle(AdonisTheme.secondaryInk)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(17)
    .background(
      LinearGradient(
        colors: [AdonisTheme.paper, AdonisTheme.lavender.opacity(0.22)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: 24, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(AdonisTheme.pomegranate.opacity(0.18), lineWidth: 1)
    }
    .sheet(item: $creativeWork) { presentation in
      CreativeWorkView(
        presentation: presentation,
        onSave: {
          try save(presentation)
        },
        onShareOpened: {
          EventLogger.log(
            .creativeWorkShareOpened,
            detail: presentation.draft.eventDetail,
            processingVersion: presentation.draft.recipe.version,
            in: modelContext
          )
        }
      )
      .presentationDetents([.large])
    }
    .alert(
      "试搭没有完成",
      isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
      )
    ) {
      Button("知道了", role: .cancel) {}
    } message: {
      Text(errorMessage ?? "原照片和衣橱都没有改变，可以稍后再试。")
    }
    .onDisappear {
      cancelIfNeeded()
    }
  }

  private var latestOutfit: OutfitRecord? {
    outfits.first
  }

  private var readiness: StickerTryOnEligibility {
    StickerTryOnEligibility.evaluate(
      sourceKind: item.sourceKind,
      cleanBackgroundScore: item.cleanBackgroundScore,
      category: item.category
    )
  }

  private var sourcePreview: some View {
    HStack(spacing: 10) {
      StoredImageView(filename: item.imageFilename, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .frame(height: 96)
        .background(.white.opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .rotationEffect(.degrees(-1.5))
        .accessibilityHidden(true)

      Image(systemName: "plus")
        .font(.system(size: 14, weight: .black))
        .foregroundStyle(AdonisTheme.pomegranateInk)
        .accessibilityHidden(true)

      Group {
        if let latestOutfit {
          StoredImageView(filename: latestOutfit.sourceImageFilename, contentMode: .fill)
        } else {
          ZStack {
            AdonisTheme.canvas
            Image(systemName: "person.crop.rectangle.badge.plus")
              .font(.system(size: 25, weight: .bold))
              .foregroundStyle(AdonisTheme.secondaryInk)
          }
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: 96)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .rotationEffect(.degrees(1.5))
      .accessibilityHidden(true)
    }
  }

  private var processingState: some View {
    HStack(spacing: 13) {
      ProgressView()
        .tint(AdonisTheme.pomegranate)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text("正在摆好这件衣服")
          .font(.system(.subheadline, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
        Text("原照片和衣橱不会改变")
          .font(.caption2)
          .foregroundStyle(AdonisTheme.secondaryInk)
      }
      Spacer(minLength: 4)
      Button("停止", role: .cancel) {
        cancelIfNeeded()
      }
      .font(.subheadline.weight(.bold))
      .frame(minWidth: 52, minHeight: 44)
      .accessibilityIdentifier("sticker-try-on-cancel")
    }
    .padding(13)
    .background(.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 17))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("sticker-try-on-processing")
  }

  private var unavailableState: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: unavailableIcon)
        .foregroundStyle(AdonisTheme.pomegranateInk)
        .frame(width: 24)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 3) {
        Text(unavailableTitle)
          .font(.system(.subheadline, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
        Text(unavailableDetail)
          .font(.caption)
          .foregroundStyle(AdonisTheme.secondaryInk)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(13)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(AdonisTheme.butter.opacity(0.28), in: RoundedRectangle(cornerRadius: 17))
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("sticker-try-on-unavailable")
  }

  private var unavailableTitle: String {
    if latestOutfit == nil { return "先收藏一张 OOTD" }
    return switch readiness {
    case .ready: "已经可以试搭"
    case .needsCleanCatalogImage: "补一张干净商品图"
    case .unsupportedCategory: "先选上装或外套"
    }
  }

  private var unavailableDetail: String {
    if latestOutfit == nil { return "有了人物更完整的穿搭照，再回来点一次就好。" }
    return switch readiness {
    case .ready: "点一下就会使用最近一次 OOTD。"
    case .needsCleanCatalogImage: "白底或干净平铺图更容易保留衣服本来的颜色和轮廓。"
    case .unsupportedCategory: "第一版先处理上装和外套，避免给出不可靠的鞋包位置。"
    }
  }

  private var unavailableIcon: String {
    if latestOutfit == nil { return "person.crop.rectangle.badge.plus" }
    return switch readiness {
    case .ready: "checkmark.circle.fill"
    case .needsCleanCatalogImage: "photo.badge.plus"
    case .unsupportedCategory: "tshirt"
    }
  }

  @MainActor
  private func start(using outfit: OutfitRecord) {
    guard activeGenerationID == nil else { return }
    guard
      let person = MediaStore.shared.image(filename: outfit.sourceImageFilename),
      let garment = MediaStore.shared.image(filename: item.imageFilename)
    else {
      errorMessage = StickerTryOnError.renderFailed.localizedDescription
      return
    }

    let generationID = UUID()
    let timer = CreativeGenerationAttemptTimer(startedAt: ContinuousClock.now)
    activeGenerationID = generationID
    attemptTimer = timer
    errorMessage = nil
    EventLogger.log(
      .creativeWorkGenerationStarted,
      detail: generator.executionMetadata.eventDetail(for: .stickerTryOn),
      processingVersion: AdonisProcessingVersion.stickerTryOn,
      in: modelContext
    )

    activeTask = Task { @MainActor in
      do {
        let result = try await generator.generate(
          person: person,
          garment: garment,
          category: item.category
        )
        try Task.checkCancellation()
        finish(
          result,
          outfit: outfit,
          sourceImage: person,
          generationID: generationID,
          timer: timer
        )
      } catch {
        fail(error, generationID: generationID, timer: timer)
      }
    }
  }

  @MainActor
  private func finish(
    _ result: StickerTryOnResult,
    outfit: OutfitRecord,
    sourceImage: UIImage,
    generationID: UUID,
    timer: CreativeGenerationAttemptTimer
  ) {
    guard activeGenerationID == generationID else { return }
    activeGenerationID = nil
    activeTask = nil
    attemptTimer = nil

    let milliseconds = timer.elapsedMilliseconds()
    let draft = CreativeWorkDraft(
      createdAt: .now,
      recipe: .stickerTryOn,
      image: result.image,
      processingMilliseconds: milliseconds,
      executionMetadata: generator.executionMetadata
    )
    EventLogger.log(
      .creativeWorkCreated,
      durationMilliseconds: milliseconds,
      detail: draft.eventDetail,
      processingVersion: draft.recipe.version,
      in: modelContext
    )
    sourceOutfit = outfit
    creativeWork = CreativeWorkPresentation(
      draft: draft,
      sourceImage: sourceImage,
      isSaved: false
    )
  }

  @MainActor
  private func fail(
    _ error: Error,
    generationID: UUID,
    timer: CreativeGenerationAttemptTimer
  ) {
    guard activeGenerationID == generationID else { return }
    activeGenerationID = nil
    activeTask = nil
    attemptTimer = nil
    let isCancelled = error is CancellationError
    let code = (error as? StickerTryOnError)?.eventCode ?? (isCancelled ? "cancelled" : "failed")
    EventLogger.log(
      isCancelled ? .creativeWorkGenerationCancelled : .creativeWorkGenerationFailed,
      durationMilliseconds: timer.elapsedMilliseconds(),
      detail: generator.executionMetadata.eventDetail(for: .stickerTryOn) + ";error=\(code)",
      processingVersion: AdonisProcessingVersion.stickerTryOn,
      in: modelContext
    )
    if !isCancelled {
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func cancelIfNeeded() {
    guard activeGenerationID != nil else { return }
    activeGenerationID = nil
    let task = activeTask
    activeTask = nil
    task?.cancel()
    let timer = attemptTimer
    attemptTimer = nil
    EventLogger.log(
      .creativeWorkGenerationCancelled,
      durationMilliseconds: timer?.elapsedMilliseconds(),
      detail: generator.executionMetadata.eventDetail(for: .stickerTryOn) + ";error=cancelled",
      processingVersion: AdonisProcessingVersion.stickerTryOn,
      in: modelContext
    )
  }

  @MainActor
  private func save(_ presentation: CreativeWorkPresentation) throws {
    guard let sourceOutfit else {
      throw CreativeWorkStoreError.missingSourceOutfit
    }
    _ = try CreativeWorkStore().save(
      presentation.draft,
      for: sourceOutfit,
      in: modelContext
    )
    EventLogger.log(
      .creativeWorkSaved,
      durationMilliseconds: presentation.draft.processingMilliseconds,
      detail: presentation.draft.eventDetail,
      processingVersion: presentation.draft.recipe.version,
      in: modelContext
    )
  }
}
