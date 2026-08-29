import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct CreateView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \OutfitRecord.createdAt, order: .reverse) private var records: [OutfitRecord]

  @State private var selectedPhotoItem: PhotosPickerItem?
  @State private var draft: GenerationDraft?
  @State private var isProcessing = false
  @State private var processingStage: ProcessingStage = .reading
  @State private var errorMessage: String?
  @State private var showCamera = false
  @State private var showCameraUnavailable = false
  @State private var showSettings = false
  @State private var activeGenerationID: UUID?
  @State private var activeInputSource: EventInputSource?

  private let processor = StickerProcessor()
  private let qualityAssessor = StickerQualityAssessor()
  private let cardRenderer = ShareCardRenderer()
  private let garmentObserver = OutfitGarmentObserver()

  var body: some View {
    ZStack {
      AdonisTheme.canvas
        .ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 26) {
          header
          hero
          inputActions
          sampleSection
          privacyNote
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 36)
      }
      .scrollIndicators(.hidden)
      .disabled(isProcessing)

      if isProcessing {
        ProcessingOverlay(
          stage: processingStage,
          onCancel: cancelGeneration
        )
        .transition(
          reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98))
        )
        .zIndex(2)
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .onChange(of: selectedPhotoItem) { _, newItem in
      guard let newItem else { return }
      Task { await loadPhoto(from: newItem) }
    }
    .fullScreenCover(item: $draft) { draft in
      GenerationResultView(
        draft: draft,
        initiallySaved: records.contains(where: { $0.id == draft.id }),
        onSave: { try save(draft) },
        onReset: { self.draft = nil }
      )
    }
    .sheet(isPresented: $showCamera) {
      CameraPicker { image in
        Task { await generate(from: image, inputSource: .camera) }
      }
      .ignoresSafeArea()
    }
    .sheet(isPresented: $showSettings) {
      NavigationStack {
        LocalSettingsView()
      }
    }
    .alert(
      "这次没有生成成功",
      isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
      )
    ) {
      Button("换一张试试", role: .cancel) {}
    } message: {
      Text(errorMessage ?? "请换一张照片再试。")
    }
    .alert("模拟器没有相机", isPresented: $showCameraUnavailable) {
      Button("知道了", role: .cancel) {}
    } message: {
      Text("可以选择相册照片，或先用下面的四张样片体验完整流程。")
    }
  }

  private var header: some View {
    HStack {
      AdonisWordmark()
      Spacer()
      Button {
        showSettings = true
      } label: {
        Image(systemName: "gearshape.fill")
          .font(.system(size: 17, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
          .frame(width: 44, height: 44)
          .background(.white.opacity(0.72), in: Circle())
          .shadow(color: AdonisTheme.ink.opacity(0.08), radius: 8, y: 4)
      }
      .buttonStyle(StickerButtonStyle())
      .accessibilityLabel("本地设置")
    }
  }

  private var hero: some View {
    ZStack(alignment: .bottomLeading) {
      RoundedRectangle(cornerRadius: AdonisTheme.largeRadius, style: .continuous)
        .fill(AdonisTheme.paper)

      Circle()
        .fill(AdonisTheme.lavender.opacity(0.62))
        .frame(width: 190, height: 190)
        .offset(x: 210, y: -118)

      Circle()
        .fill(AdonisTheme.leaf.opacity(0.28))
        .frame(width: 120, height: 120)
        .offset(x: -42, y: 55)

      VStack(alignment: .leading, spacing: 14) {
        StickerTag(title: "今天也值得收藏", color: AdonisTheme.butter, icon: "heart.fill")

        Text("一张照片，\n变成今天的贴纸")
          .font(.system(.largeTitle, design: .rounded, weight: .black))
          .foregroundStyle(AdonisTheme.ink)
          .fixedSize(horizontal: false, vertical: true)

        Text("保留原来的你，只把背景轻轻拿走。")
          .font(.system(.subheadline, design: .rounded, weight: .medium))
          .foregroundStyle(AdonisTheme.secondaryInk)
      }
      .padding(26)
    }
    .frame(maxWidth: .infinity, minHeight: 290, alignment: .bottomLeading)
    .clipShape(RoundedRectangle(cornerRadius: AdonisTheme.largeRadius, style: .continuous))
    .shadow(color: AdonisTheme.ink.opacity(0.08), radius: 18, y: 10)
    .overlay(alignment: .topTrailing) {
      DoodleFlower(size: 48)
        .rotationEffect(.degrees(9))
        .padding(24)
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("create-hero")
  }

  private var inputActions: some View {
    VStack(spacing: 12) {
      PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
        PrimaryActionLabel(title: "选择一张照片", systemImage: "photo.on.rectangle.angled")
      }
      .buttonStyle(StickerButtonStyle())
      .accessibilityIdentifier("choose-photo")

      Button {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
          showCamera = true
        } else {
          showCameraUnavailable = true
        }
      } label: {
        Label("现在拍一张", systemImage: "camera.fill")
          .font(.system(.headline, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
          .frame(maxWidth: .infinity, minHeight: 52)
          .background(
            .white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      }
      .buttonStyle(StickerButtonStyle())
      .accessibilityIdentifier("take-photo")
    }
  }

  private var sampleSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      sampleSectionHeader

      ScrollView(.horizontal) {
        HStack(spacing: 14) {
          ForEach(SampleCatalog.photos) { sample in
            SamplePhotoButton(sample: sample) {
              guard let image = sample.image(),
                let sticker = sample.preparedStickerImage()
              else {
                errorMessage = "样片没有正确打包进 App。"
                return
              }
              Task {
                await generate(
                  from: image,
                  preparedSticker: sticker,
                  inputSource: .preparedSample
                )
              }
            }
          }
        }
        .padding(.vertical, 4)
      }
      .scrollIndicators(.hidden)
    }
  }

  @ViewBuilder
  private var sampleSectionHeader: some View {
    if dynamicTypeSize.isAccessibilitySize {
      VStack(alignment: .leading, spacing: 4) {
        Text("先用样片玩一下")
          .font(.system(.title3, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
        Text("全部本机处理")
          .font(.caption)
          .foregroundStyle(AdonisTheme.secondaryInk)
      }
    } else {
      HStack(alignment: .firstTextBaseline) {
        Text("先用样片玩一下")
          .font(.system(.title3, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
        Spacer()
        Text("全部本机处理")
          .font(.caption)
          .foregroundStyle(AdonisTheme.secondaryInk)
      }
    }
  }

  private var privacyNote: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "lock.fill")
        .foregroundStyle(AdonisTheme.leafInk)
        .frame(width: 24)
        .accessibilityHidden(true)
      Text("这个 Demo 没有账号和网络请求。照片、贴纸与穿搭记录只保存在当前设备。")
        .font(.footnote)
        .foregroundStyle(AdonisTheme.secondaryInk)
        .lineSpacing(3)
    }
    .padding(16)
    .background(
      AdonisTheme.leaf.opacity(0.11), in: RoundedRectangle(cornerRadius: 18, style: .continuous)
    )
    .accessibilityElement(children: .combine)
  }

  @MainActor
  private func loadPhoto(from item: PhotosPickerItem) async {
    let loadID = UUID()
    activeGenerationID = loadID
    activeInputSource = .photoLibrary
    do {
      processingStage = .reading
      isProcessing = true
      guard let data = try await item.loadTransferable(type: Data.self),
        let image = UIImage(data: data)
      else {
        throw StickerProcessingError.unreadableImage
      }
      guard activeGenerationID == loadID else { return }
      await generate(
        from: image,
        inputSource: .photoLibrary,
        alreadyShowingProgress: true
      )
    } catch {
      guard activeGenerationID == loadID else { return }
      EventLogger.log(
        .generationFailed,
        detail: error.localizedDescription,
        inputSource: .photoLibrary,
        processingVersion: AdonisProcessingVersion.generationPipeline,
        in: modelContext
      )
      activeGenerationID = nil
      activeInputSource = nil
      isProcessing = false
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func generate(
    from image: UIImage,
    inputSource: EventInputSource,
    alreadyShowingProgress: Bool = false
  ) async {
    await generate(
      from: image,
      preparedSticker: nil,
      inputSource: inputSource,
      alreadyShowingProgress: alreadyShowingProgress
    )
  }

  @MainActor
  private func generate(
    from image: UIImage,
    preparedSticker: UIImage?,
    inputSource: EventInputSource,
    alreadyShowingProgress: Bool = false
  ) async {
    let generationID = UUID()
    activeGenerationID = generationID
    activeInputSource = inputSource
    if !alreadyShowingProgress {
      isProcessing = true
    }
    processingStage = .separating
    EventLogger.log(
      .generationStarted,
      inputSource: inputSource,
      processingVersion: AdonisProcessingVersion.generationPipeline,
      in: modelContext
    )

    if ProcessInfo.processInfo.arguments.contains("-ui-testing-hold-generation") {
      try? await Task.sleep(for: .seconds(15))
      guard activeGenerationID == generationID else { return }
    }

    do {
      let processed: StickerProcessingResult
      if let preparedSticker {
        processed = StickerProcessingResult(
          image: preparedSticker,
          elapsedMilliseconds: 0,
          foregroundCoverage: 0
        )
      } else {
        processed = try await processor.process(image)
      }
      guard activeGenerationID == generationID else { return }

      processingStage = .outlining
      await Task.yield()
      guard activeGenerationID == generationID else { return }
      processingStage = .checking
      let qualityAssessment = await qualityAssessor.assess(
        sticker: processed.image,
        foregroundCoverage: processed.foregroundCoverage
      )
      guard activeGenerationID == generationID else { return }
      if qualityAssessment.isRejected {
        EventLogger.log(
          .generationQualityRejected,
          detail: qualityAssessment.eventDetail,
          inputSource: inputSource,
          processingVersion: StickerQualityAssessor.version,
          in: modelContext
        )
        throw StickerProcessingError.outputQualityTooLow
      }
      if qualityAssessment.requiresReview {
        EventLogger.log(
          .generationQualityWarning,
          detail: qualityAssessment.eventDetail,
          inputSource: inputSource,
          processingVersion: StickerQualityAssessor.version,
          in: modelContext
        )
      }

      processingStage = .composing
      let bloomNumber = (records.map(\.bloomNumber).max() ?? 0) + 1
      let date = Date.now
      let card = cardRenderer.render(
        sticker: processed.image,
        bloomNumber: bloomNumber,
        date: date
      )
      processingStage = .observing
      let garmentObservations = await garmentObserver.observe(sticker: processed.image)
      guard activeGenerationID == generationID else { return }

      EventLogger.log(
        .generationSucceeded,
        durationMilliseconds: preparedSticker == nil
          ? processed.elapsedMilliseconds
          : nil,
        detail: preparedSticker == nil ? nil : "prepared_sample",
        inputSource: inputSource,
        processingVersion: AdonisProcessingVersion.generationPipeline,
        in: modelContext
      )
      activeGenerationID = nil
      activeInputSource = nil
      isProcessing = false
      draft = GenerationDraft(
        createdAt: date,
        sourceImage: image,
        stickerImage: processed.image,
        cardImage: card,
        bloomNumber: bloomNumber,
        processingMilliseconds: processed.elapsedMilliseconds,
        foregroundCoverage: processed.foregroundCoverage,
        usesPreparedSample: preparedSticker != nil,
        inputSource: inputSource,
        qualityAssessment: qualityAssessment,
        garmentObservations: garmentObservations
      )
    } catch {
      guard activeGenerationID == generationID else { return }
      EventLogger.log(
        .generationFailed,
        detail: error.localizedDescription,
        inputSource: inputSource,
        processingVersion: AdonisProcessingVersion.generationPipeline,
        in: modelContext
      )
      activeGenerationID = nil
      activeInputSource = nil
      isProcessing = false
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func cancelGeneration() {
    guard activeGenerationID != nil else { return }
    activeGenerationID = nil
    selectedPhotoItem = nil
    isProcessing = false
    EventLogger.log(
      .generationCancelled,
      inputSource: activeInputSource,
      processingVersion: AdonisProcessingVersion.generationPipeline,
      in: modelContext
    )
    activeInputSource = nil
  }

  @MainActor
  private func save(_ draft: GenerationDraft) throws {
    guard !records.contains(where: { $0.id == draft.id }) else { return }

    let prefix = draft.id.uuidString.lowercased()
    var savedFilenames: [String] = []

    do {
      let sourceFilename = try MediaStore.shared.savePNG(
        draft.sourceImage,
        filename: "\(prefix)-source.png"
      )
      savedFilenames.append(sourceFilename)
      let stickerFilename = try MediaStore.shared.savePNG(
        draft.stickerImage,
        filename: "\(prefix)-sticker.png"
      )
      savedFilenames.append(stickerFilename)
      let cardFilename = try MediaStore.shared.savePNG(
        draft.cardImage,
        filename: "\(prefix)-card.png"
      )
      savedFilenames.append(cardFilename)

      let record = OutfitRecord(
        id: draft.id,
        createdAt: draft.createdAt,
        sourceImageFilename: sourceFilename,
        stickerImageFilename: stickerFilename,
        cardImageFilename: cardFilename,
        bloomNumber: draft.bloomNumber,
        stickerQualityAssessment: draft.qualityAssessment,
        stickerQualityVersion: StickerQualityAssessor.version
      )
      modelContext.insert(record)

      for draftObservation in draft.garmentObservations {
        let previewFilename = try MediaStore.shared.savePNG(
          draftObservation.previewImage,
          filename: "\(draftObservation.id.uuidString.lowercased())-observation.png"
        )
        savedFilenames.append(previewFilename)
        let observation = GarmentObservation(
          id: draftObservation.id,
          createdAt: draft.createdAt,
          slot: draftObservation.slot,
          suggestedCategory: draftObservation.suggestedCategory,
          dominantColorName: draftObservation.dominantColorName,
          dominantColorHex: draftObservation.dominantColorHex,
          confidence: draftObservation.confidence,
          previewImageFilename: previewFilename,
          observerVersion: draftObservation.observerVersion,
          outfit: record
        )
        modelContext.insert(observation)
        record.garmentObservations.append(observation)
      }
      try modelContext.save()
    } catch {
      modelContext.rollback()
      MediaStore.shared.delete(filenames: savedFilenames)
      throw error
    }
    EventLogger.log(
      .outfitSaved,
      inputSource: draft.inputSource,
      processingVersion: AdonisProcessingVersion.generationPipeline,
      in: modelContext
    )
    if !draft.garmentObservations.isEmpty {
      EventLogger.log(
        .garmentObservationsCreated,
        detail: "count=\(draft.garmentObservations.count)",
        inputSource: draft.inputSource,
        processingVersion: OutfitGarmentObserver.version,
        in: modelContext
      )
    }
  }
}

private struct SamplePhotoButton: View {
  let sample: SamplePhoto
  let action: () -> Void

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 9) {
        Group {
          if let image = sample.image() {
            Image(uiImage: image)
              .resizable()
              .scaledToFill()
          } else {
            AdonisTheme.lavender.opacity(0.4)
          }
        }
        .frame(width: imageWidth, height: 176)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(AdonisTheme.ink.opacity(0.08), lineWidth: 1)
        }

        Text(sample.title)
          .font(.system(.subheadline, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)

        Text(sample.subtitle)
          .font(.caption2)
          .foregroundStyle(AdonisTheme.secondaryInk)
          .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(9)
      .frame(width: cardWidth, alignment: .leading)
      .background(AdonisTheme.paper, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
      .shadow(color: AdonisTheme.ink.opacity(0.08), radius: 10, y: 5)
    }
    .buttonStyle(StickerButtonStyle())
    .accessibilityLabel("使用样片：\(sample.title)")
    .accessibilityIdentifier(sample.id)
  }

  private var cardWidth: CGFloat {
    dynamicTypeSize.isAccessibilitySize ? 220 : 162
  }

  private var imageWidth: CGFloat {
    cardWidth - 18
  }
}

private struct ProcessingOverlay: View {
  let stage: ProcessingStage
  let onCancel: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var rotation: Double = 0

  var body: some View {
    ZStack {
      Color.black.opacity(0.22)
        .ignoresSafeArea()
        .accessibilityHidden(true)

      VStack(spacing: 20) {
        ZStack {
          Circle()
            .fill(AdonisTheme.butter)
            .frame(width: 84, height: 84)
          DoodleFlower(size: 44)
            .rotationEffect(.degrees(rotation))
        }

        VStack(spacing: 7) {
          Text(stage.rawValue)
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(AdonisTheme.ink)
            .id(stage)
            .transition(.opacity)
          Text("人物与衣服不会被重新绘制")
            .font(.footnote)
            .foregroundStyle(AdonisTheme.secondaryInk)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(stage.rawValue)
        .accessibilityAddTraits(.updatesFrequently)

        Button("取消", action: onCancel)
          .font(.system(.subheadline, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.secondaryInk)
          .frame(minWidth: 88, minHeight: 44)
          .buttonStyle(StickerButtonStyle())
          .accessibilityIdentifier("processing-cancel")
      }
      .padding(30)
      .frame(maxWidth: 320)
      .paperSurface()
      .padding(24)
      .accessibilityElement(children: .contain)
      .accessibilityAddTraits(.isModal)
    }
    .onAppear {
      guard !reduceMotion else { return }
      withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
        rotation = 360
      }
    }
    .accessibilityIdentifier("processing-overlay")
  }
}
