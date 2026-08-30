import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct CreateView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.modelContext) private var modelContext
  @Environment(\.openURL) private var openURL
  @Query(sort: \OutfitRecord.createdAt, order: .reverse) private var records: [OutfitRecord]

  @State private var selectedPhotoItem: PhotosPickerItem?
  @State private var draft: GenerationDraft?
  @State private var isProcessing = false
  @State private var processingStage: ProcessingStage = .reading
  @State private var errorMessage: String?
  @State private var errorTitle = "这次没有生成成功"
  @State private var offersRetry = false
  @State private var retryInput: GenerationRetryInput?
  @State private var retryPhotoItem: PhotosPickerItem?
  @State private var activeFallbackCandidate: GenerationFallbackCandidate?
  @State private var cameraSheet: CameraSheet?
  @State private var cameraAlert: CameraAccessAlert?
  @State private var isResolvingCameraAccess = false
  @State private var showSettings = false
  @State private var activeGenerationID: UUID?
  @State private var activeInputSource: EventInputSource?
  @State private var activePerformanceRecorder: GenerationPerformanceRecorder?
  @State private var deadlineController = GenerationDeadlineController()

  private let processor = StickerProcessor()
  private let qualityAssessor = StickerQualityAssessor()
  private let cardRenderer = ShareCardRenderer()
  private let garmentObserver = OutfitGarmentObserver()
  private let creativeWorkStore = CreativeWorkStore()
  private let cameraAccessService: CameraAccessService

  @MainActor
  init(cameraAccessService: CameraAccessService? = nil) {
    self.cameraAccessService = cameraAccessService ?? .live
  }

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
        onSaveCreative: { creativeWork in
          try save(draft)
          try save(creativeWork, for: draft)
        },
        onReset: { self.draft = nil }
      )
    }
    .sheet(item: $cameraSheet) { _ in
      CameraPicker { image in
        Task { await generate(from: image, inputSource: .camera) }
      }
      .ignoresSafeArea()
      .accessibilityIdentifier("camera-picker")
    }
    .sheet(isPresented: $showSettings) {
      NavigationStack {
        LocalSettingsView()
      }
    }
    .alert(
      errorTitle,
      isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
      )
    ) {
      if offersRetry {
        Button("再试一次", action: retryLastGeneration)
      }
      Button(offersRetry ? "换一张照片" : "换一张试试", role: .cancel) {
        retryInput = nil
        retryPhotoItem = nil
        offersRetry = false
      }
    } message: {
      Text(errorMessage ?? "请换一张照片再试。")
    }
    .alert(item: $cameraAlert, content: cameraAccessAlert)
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
        requestCamera()
      } label: {
        Label("现在拍一张", systemImage: "camera.fill")
          .font(.system(.headline, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
          .frame(maxWidth: .infinity, minHeight: 52)
          .background(
            .white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      }
      .buttonStyle(StickerButtonStyle())
      .disabled(isResolvingCameraAccess)
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
                presentGenerationError("样片没有正确打包进 App。")
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
  private func requestCamera() {
    guard !isResolvingCameraAccess else { return }
    isResolvingCameraAccess = true
    Task { @MainActor in
      let outcome = await cameraAccessService.resolveLaunchOutcome()
      isResolvingCameraAccess = false
      switch outcome {
      case .openCamera:
        cameraAlert = nil
        cameraSheet = .picker
      case .unavailable:
        cameraAlert = .unavailable
      case .permissionDenied:
        cameraAlert = .permissionDenied
      case .restricted:
        cameraAlert = .restricted
      }
    }
  }

  private func cameraAccessAlert(for issue: CameraAccessAlert) -> Alert {
    switch issue {
    case .permissionDenied:
      return Alert(
        title: Text(issue.title),
        message: Text(issue.message),
        primaryButton: .default(Text("打开系统设置"), action: openCameraSettings),
        secondaryButton: .cancel(Text("先不用"))
      )
    case .unavailable, .restricted:
      return Alert(
        title: Text(issue.title),
        message: Text(issue.message),
        dismissButton: .cancel(Text("知道了"))
      )
    }
  }

  private func openCameraSettings() {
    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
    openURL(settingsURL)
  }

  @MainActor
  private func loadPhoto(from item: PhotosPickerItem) async {
    let loadID = UUID()
    let recorder = GenerationPerformanceRecorder(usesPreparedSample: false)
    activeGenerationID = loadID
    activeInputSource = .photoLibrary
    activePerformanceRecorder = recorder
    retryInput = nil
    retryPhotoItem = item
    activeFallbackCandidate = nil
    recorder.begin(.inputLoading)
    armGenerationDeadline(for: loadID)
    EventLogger.log(
      .generationStarted,
      inputSource: .photoLibrary,
      processingVersion: AdonisProcessingVersion.generationPipeline,
      in: modelContext
    )
    do {
      processingStage = .reading
      isProcessing = true
      guard let data = try await item.loadTransferable(type: Data.self),
        let image = UIImage(data: data)
      else {
        throw StickerProcessingError.unreadableImage
      }
      recorder.finish(.inputLoading)
      guard activeGenerationID == loadID else { return }
      await generate(
        from: image,
        inputSource: .photoLibrary,
        alreadyShowingProgress: true,
        performanceRecorder: recorder,
        startEventLogged: true,
        generationID: loadID,
        deadlineAlreadyArmed: true
      )
    } catch {
      guard activeGenerationID == loadID else { return }
      deadlineController.cancel(generationID: loadID)
      let trace = recorder.makeTrace(interrupted: true)
      EventLogger.log(
        .generationFailed,
        detail: error.localizedDescription,
        inputSource: .photoLibrary,
        processingVersion: AdonisProcessingVersion.generationPipeline,
        generationPerformanceTrace: trace,
        in: modelContext
      )
      activeGenerationID = nil
      activeInputSource = nil
      activePerformanceRecorder = nil
      retryPhotoItem = nil
      isProcessing = false
      presentGenerationError(error.localizedDescription)
    }
  }

  @MainActor
  private func generate(
    from image: UIImage,
    inputSource: EventInputSource,
    alreadyShowingProgress: Bool = false,
    performanceRecorder: GenerationPerformanceRecorder? = nil,
    startEventLogged: Bool = false,
    generationID: UUID? = nil,
    deadlineAlreadyArmed: Bool = false
  ) async {
    await generate(
      from: image,
      preparedSticker: nil,
      inputSource: inputSource,
      alreadyShowingProgress: alreadyShowingProgress,
      performanceRecorder: performanceRecorder,
      startEventLogged: startEventLogged,
      generationID: generationID,
      deadlineAlreadyArmed: deadlineAlreadyArmed
    )
  }

  @MainActor
  private func generate(
    from image: UIImage,
    preparedSticker: UIImage?,
    inputSource: EventInputSource,
    alreadyShowingProgress: Bool = false,
    performanceRecorder: GenerationPerformanceRecorder? = nil,
    startEventLogged: Bool = false,
    generationID suppliedGenerationID: UUID? = nil,
    deadlineAlreadyArmed: Bool = false
  ) async {
    let generationID = suppliedGenerationID ?? UUID()
    let recorder =
      performanceRecorder
      ?? GenerationPerformanceRecorder(usesPreparedSample: preparedSticker != nil)
    activeGenerationID = generationID
    activeInputSource = inputSource
    activePerformanceRecorder = recorder
    activeFallbackCandidate = nil
    retryPhotoItem = nil
    retryInput = GenerationRetryInput(
      image: image,
      preparedSticker: preparedSticker,
      inputSource: inputSource
    )
    if !deadlineAlreadyArmed {
      armGenerationDeadline(for: generationID)
    }
    if !alreadyShowingProgress {
      isProcessing = true
    }
    processingStage = .separating
    if !startEventLogged {
      EventLogger.log(
        .generationStarted,
        inputSource: inputSource,
        processingVersion: AdonisProcessingVersion.generationPipeline,
        in: modelContext
      )
    }

    recorder.begin(.subjectExtraction)

    if ProcessInfo.processInfo.arguments.contains("-ui-testing-hold-generation") {
      let holdDuration: Duration =
        ProcessInfo.processInfo.arguments.contains(
          "-ui-testing-force-generation-timeout"
        ) ? .seconds(3) : .seconds(15)
      try? await Task.sleep(for: holdDuration)
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
      recorder.finish(.subjectExtraction)
      guard activeGenerationID == generationID else { return }

      processingStage = .outlining
      await Task.yield()
      guard activeGenerationID == generationID else { return }
      processingStage = .checking
      recorder.begin(.qualityAssessment)
      let qualityAssessment = await qualityAssessor.assess(
        sticker: processed.image,
        foregroundCoverage: processed.foregroundCoverage
      )
      recorder.finish(.qualityAssessment)
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
      recorder.begin(.shareCardComposition)
      let card = cardRenderer.render(
        sticker: processed.image,
        bloomNumber: bloomNumber,
        date: date
      )
      recorder.finish(.shareCardComposition)
      activeFallbackCandidate = GenerationFallbackCandidate(
        id: generationID,
        createdAt: date,
        sourceImage: image,
        stickerImage: processed.image,
        cardImage: card,
        bloomNumber: bloomNumber,
        foregroundCoverage: processed.foregroundCoverage,
        usesPreparedSample: preparedSticker != nil,
        inputSource: inputSource,
        qualityAssessment: qualityAssessment
      )
      processingStage = .observing
      recorder.begin(.garmentObservation)
      if ProcessInfo.processInfo.arguments.contains(
        "-ui-testing-force-generation-fallback-timeout"
      ) {
        armGenerationDeadline(for: generationID, timeout: .seconds(1))
        try? await Task.sleep(for: .seconds(2))
        guard activeGenerationID == generationID else { return }
      }
      let garmentObservations = await garmentObserver.observe(sticker: processed.image)
      recorder.finish(.garmentObservation)
      guard activeGenerationID == generationID else { return }

      let trace = recorder.makeTrace(interrupted: false)
      deadlineController.cancel(generationID: generationID)
      EventLogger.log(
        .generationSucceeded,
        detail: preparedSticker == nil ? nil : "prepared_sample",
        inputSource: inputSource,
        processingVersion: AdonisProcessingVersion.generationPipeline,
        generationPerformanceTrace: trace,
        in: modelContext
      )
      activeGenerationID = nil
      activeInputSource = nil
      activePerformanceRecorder = nil
      retryInput = nil
      retryPhotoItem = nil
      activeFallbackCandidate = nil
      isProcessing = false
      draft = GenerationDraft(
        createdAt: date,
        sourceImage: image,
        stickerImage: processed.image,
        cardImage: card,
        bloomNumber: bloomNumber,
        processingMilliseconds: trace.totalMilliseconds,
        foregroundCoverage: processed.foregroundCoverage,
        usesPreparedSample: preparedSticker != nil,
        inputSource: inputSource,
        qualityAssessment: qualityAssessment,
        garmentObservations: garmentObservations
      )
    } catch {
      guard activeGenerationID == generationID else { return }
      deadlineController.cancel(generationID: generationID)
      let trace = recorder.makeTrace(interrupted: true)
      EventLogger.log(
        .generationFailed,
        detail: error.localizedDescription,
        inputSource: inputSource,
        processingVersion: AdonisProcessingVersion.generationPipeline,
        generationPerformanceTrace: trace,
        in: modelContext
      )
      activeGenerationID = nil
      activeInputSource = nil
      activePerformanceRecorder = nil
      retryInput = nil
      retryPhotoItem = nil
      activeFallbackCandidate = nil
      isProcessing = false
      presentGenerationError(error.localizedDescription)
    }
  }

  @MainActor
  private func cancelGeneration() {
    guard let generationID = activeGenerationID else { return }
    deadlineController.cancel(generationID: generationID)
    let trace = activePerformanceRecorder?.makeTrace(interrupted: true)
    activeGenerationID = nil
    selectedPhotoItem = nil
    isProcessing = false
    EventLogger.log(
      .generationCancelled,
      inputSource: activeInputSource,
      processingVersion: AdonisProcessingVersion.generationPipeline,
      generationPerformanceTrace: trace,
      in: modelContext
    )
    activeInputSource = nil
    activePerformanceRecorder = nil
    retryInput = nil
    retryPhotoItem = nil
    activeFallbackCandidate = nil
  }

  @MainActor
  private func armGenerationDeadline(
    for generationID: UUID,
    timeout timeoutOverride: Duration? = nil
  ) {
    let timeout: Duration =
      timeoutOverride
      ?? (ProcessInfo.processInfo.arguments.contains("-ui-testing-force-generation-timeout")
        ? .milliseconds(1_500) : GenerationDeadlineController.productionTimeout)
    deadlineController.arm(generationID: generationID, timeout: timeout) { expiredID in
      handleGenerationTimeout(generationID: expiredID)
    }
  }

  @MainActor
  private func handleGenerationTimeout(generationID: UUID) {
    guard activeGenerationID == generationID else { return }
    let trace = activePerformanceRecorder?.makeTrace(interrupted: true)
    let inputSource = activeInputSource
    let fallbackCandidate = activeFallbackCandidate
    activeGenerationID = nil
    activeInputSource = nil
    activePerformanceRecorder = nil
    activeFallbackCandidate = nil
    selectedPhotoItem = nil
    isProcessing = false
    EventLogger.log(
      .generationTimedOut,
      detail: fallbackCandidate == nil
        ? "deadline_ms=90000;fallback=unavailable"
        : "deadline_ms=90000;fallback=basic_sticker",
      inputSource: inputSource,
      processingVersion: AdonisProcessingVersion.generationPipeline,
      generationPerformanceTrace: trace,
      in: modelContext
    )
    if let fallbackCandidate {
      retryInput = nil
      retryPhotoItem = nil
      offersRetry = false
      errorMessage = nil
      draft = fallbackCandidate.makeDraft(
        processingMilliseconds: trace?.totalMilliseconds ?? 90_000
      )
      return
    }
    errorTitle = "这次等得有点久"
    offersRetry = retryInput != nil || retryPhotoItem != nil
    errorMessage = "处理超过 90 秒，已经停止等待。可以再试一次，或换一张照片。"
  }

  @MainActor
  private func retryLastGeneration() {
    errorMessage = nil
    offersRetry = false
    if let retryInput {
      Task {
        await generate(
          from: retryInput.image,
          preparedSticker: retryInput.preparedSticker,
          inputSource: retryInput.inputSource
        )
      }
      return
    }
    guard let retryPhotoItem else { return }
    Task {
      await loadPhoto(from: retryPhotoItem)
    }
  }

  @MainActor
  private func presentGenerationError(_ message: String) {
    errorTitle = "这次没有生成成功"
    offersRetry = false
    retryInput = nil
    retryPhotoItem = nil
    errorMessage = message
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
        generationCompletionMode: draft.completionMode,
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
          visualSignatureRawValue: draftObservation.visualSignatureRawValue,
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

  @MainActor
  private func save(_ creativeWork: CreativeWorkDraft, for draft: GenerationDraft) throws {
    let outfitID = draft.id
    let descriptor = FetchDescriptor<OutfitRecord>(
      predicate: #Predicate { $0.id == outfitID }
    )
    guard let outfit = try modelContext.fetch(descriptor).first else {
      throw CreativeWorkStoreError.missingSourceOutfit
    }

    _ = try creativeWorkStore.save(creativeWork, for: outfit, in: modelContext)
    EventLogger.log(
      .creativeWorkSaved,
      durationMilliseconds: creativeWork.processingMilliseconds,
      detail: creativeWork.recipe.traceDetail,
      inputSource: draft.inputSource,
      processingVersion: creativeWork.recipe.version,
      in: modelContext
    )
  }
}

private struct GenerationRetryInput {
  let image: UIImage
  let preparedSticker: UIImage?
  let inputSource: EventInputSource
}

private enum CameraSheet: String, Identifiable {
  case picker

  var id: String { rawValue }
}

private enum CameraAccessAlert: String, Identifiable {
  case unavailable
  case permissionDenied
  case restricted

  var id: String { rawValue }

  var title: String {
    switch self {
    case .unavailable: "这里暂时不能拍照"
    case .permissionDenied: "需要相机权限"
    case .restricted: "这台 iPhone 限制了相机"
    }
  }

  var message: String {
    switch self {
    case .unavailable:
      "可以选择相册照片，或先用下面的四张样片体验完整流程。"
    case .permissionDenied:
      "要拍一张新照片，请先在系统设置里允许 Adonis 使用相机。你也可以继续从相册选择。"
    case .restricted:
      "当前系统限制不允许 Adonis 使用相机。你仍然可以从相册选择照片。"
    }
  }
}

private struct GenerationFallbackCandidate {
  let id: UUID
  let createdAt: Date
  let sourceImage: UIImage
  let stickerImage: UIImage
  let cardImage: UIImage
  let bloomNumber: Int
  let foregroundCoverage: Double
  let usesPreparedSample: Bool
  let inputSource: EventInputSource
  let qualityAssessment: StickerQualityAssessment

  func makeDraft(processingMilliseconds: Int) -> GenerationDraft {
    GenerationDraft(
      id: id,
      createdAt: createdAt,
      sourceImage: sourceImage,
      stickerImage: stickerImage,
      cardImage: cardImage,
      bloomNumber: bloomNumber,
      processingMilliseconds: processingMilliseconds,
      foregroundCoverage: foregroundCoverage,
      usesPreparedSample: usesPreparedSample,
      inputSource: inputSource,
      completionMode: .basicStickerFallback,
      qualityAssessment: qualityAssessment
    )
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
