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
  @State private var systemImagePlaygroundRequest: SystemImagePlaygroundRequest?
  @State private var isProcessing = false
  @State private var processingStage: ProcessingStage = .reading
  @State private var errorMessage: String?
  @State private var errorTitle = "这次没有生成成功"
  @State private var offersRetry = false
  @State private var retryInput: GenerationRetryInput?
  @State private var retryPhotoItem: PhotosPickerItem?
  @State private var preparedSampleRecovery: SamplePhoto?
  @State private var activeFallbackCandidate: GenerationFallbackCandidate?
  @State private var cameraSheet: CameraSheet?
  @State private var presentedCreateAlert: CreatePresentedAlert?
  @State private var isResolvingCameraAccess = false
  @State private var showSettings = false
  @State private var activeGenerationID: UUID?
  @State private var activeInputSource: EventInputSource?
  @State private var activePerformanceRecorder: GenerationPerformanceRecorder?
  @State private var activeOperationKind: CreateOperationKind?
  @State private var activeWardrobeCandidate: CreationWardrobeCandidate?
  @State private var wardrobeImportNotice: CreationWardrobeImportNotice?
  @State private var deadlineController = GenerationDeadlineController()
  @State private var activeDeadlineMilliseconds = 90_000

  private let qualityAssessor = StickerQualityAssessor()
  private let cardRenderer = ShareCardRenderer()
  private let garmentObserver = OutfitGarmentObserver()
  private let creativeWorkStore = CreativeWorkStore()
  private let wardrobeAnalyzer = WardrobeImageAnalyzer()
  private let imageIntentRouter = CreationImageIntentRouter()
  private let wardrobeImporter = WardrobeItemImportService()
  private let cameraAccessService: CameraAccessService
  private let creativeImageGenerator: any CreativeImageGenerating
  private let aiStickerPipeline: AIStickerCreationPipeline
  private let onOpenWardrobe: () -> Void

  @MainActor
  init(
    cameraAccessService: CameraAccessService? = nil,
    creativeImageGenerator: (any CreativeImageGenerating)? = nil,
    onOpenWardrobe: @escaping () -> Void = {}
  ) {
    let resolvedGenerator = creativeImageGenerator ?? CreativeImageGeneratorFactory.make()
    let extractSticker: AIStickerCreationPipeline.StickerExtractor
    let extractionExecutionMetadata: CreativeExecutionMetadata
    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("-ui-testing-ai-sticker-main-flow")
        || ProcessInfo.processInfo.arguments.contains(
          "-ui-testing-system-image-playground-main-flow"
        )
      {
        extractSticker = { generatedSource in
          guard generatedSource.cgImage != nil,
            let sticker = SampleCatalog.showcasePhotos.first?.preparedStickerImage()
          else {
            throw StickerProcessingError.renderFailed
          }
          return StickerProcessingResult(
            image: sticker,
            elapsedMilliseconds: 0,
            foregroundCoverage: 0.36,
            rawMatteAssessment: .acceptable,
            sourceFidelityAssessment: .acceptable
          )
        }
        extractionExecutionMetadata = .uiTestFixture
      } else {
        let client = AIStickerCloudExtractionClient()
        extractSticker = { generatedSource in
          let transparentSubject = try await client.extractTransparentSubject(
            from: generatedSource
          )
          return try await AITransparentStickerProcessor().process(transparentSubject)
        }
        extractionExecutionMetadata = .openAIGPTImageExtraction
      }
    #else
      let client = AIStickerCloudExtractionClient()
      extractSticker = { generatedSource in
        let transparentSubject = try await client.extractTransparentSubject(
          from: generatedSource
        )
        return try await AITransparentStickerProcessor().process(transparentSubject)
      }
      extractionExecutionMetadata = .openAIGPTImageExtraction
    #endif
    self.cameraAccessService = cameraAccessService ?? .live
    self.creativeImageGenerator = resolvedGenerator
    self.aiStickerPipeline = AIStickerCreationPipeline(
      sourceGenerator: CreativeAIStickerSourceGenerator(generator: resolvedGenerator),
      extractSticker: extractSticker,
      extractionExecutionMetadata: extractionExecutionMetadata
    )
    self.onOpenWardrobe = onOpenWardrobe
  }

  var body: some View {
    ZStack {
      AdonisTheme.canvas
        .ignoresSafeArea()

      ScrollViewReader { proxy in
        ScrollView {
          VStack(alignment: .leading, spacing: 26) {
            header
            hero
            inputActions
            if let wardrobeImportNotice {
              wardrobeImportNoticeCard(wardrobeImportNotice)
                .id("creation-wardrobe-import-anchor")
            }
            sampleSection
            privacyNote
          }
          .padding(.horizontal, 20)
          .padding(.top, 12)
          .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
        .disabled(isProcessing)
        .onChange(of: wardrobeImportNotice?.id) { _, noticeID in
          guard noticeID != nil else { return }
          if reduceMotion {
            proxy.scrollTo("creation-wardrobe-import-anchor", anchor: .center)
          } else {
            withAnimation(.easeOut(duration: 0.28)) {
              proxy.scrollTo("creation-wardrobe-import-anchor", anchor: .center)
            }
          }
        }
      }

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
    .fullScreenCover(item: $systemImagePlaygroundRequest) { request in
      SystemImagePlaygroundStickerSourceSheet(
        sourceImage: request.sourceImage,
        usesFixture: request.usesFixture,
        onCompletion: { output in
          resumeAfterSystemImagePlayground(request, output: output)
        },
        onFailure: { error in
          handleSystemImagePlaygroundFailure(request, error: error)
        },
        onCancellation: {
          handleSystemImagePlaygroundCancellation(request)
        }
      )
    }
    .fullScreenCover(item: $draft) { draft in
      GenerationResultView(
        draft: draft,
        initiallySaved: records.contains(where: { $0.id == draft.id }),
        creativeImageGenerator: creativeImageGenerator,
        initialFidelityReview: records.first(where: { $0.id == draft.id })?
          .stickerFidelityReview,
        onSave: { fidelityReview in
          try save(draft, stickerFidelityReview: fidelityReview)
        },
        onSaveCreative: { creativeWork, fidelityReview in
          try save(draft, stickerFidelityReview: fidelityReview)
          try save(creativeWork, for: draft)
        },
        onFidelityReview: { review in
          try save(review, for: draft)
        },
        onReset: { self.draft = nil }
      )
    }
    .sheet(item: $cameraSheet) { _ in
      CameraPicker { image in
        Task { await loadCapturedPhoto(image) }
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
      if let preparedSampleRecovery {
        Button("体验内置样片") {
          startPreparedSampleRecovery(preparedSampleRecovery)
        }
      }
      Button(
        preparedSampleRecovery == nil
          ? (offersRetry ? "换一张照片" : "换一张试试") : "先不用",
        role: .cancel
      ) {
        retryInput = nil
        retryPhotoItem = nil
        preparedSampleRecovery = nil
        offersRetry = false
      }
    } message: {
      Text(errorMessage ?? "请换一张照片再试。")
    }
    .alert(item: $presentedCreateAlert, content: createAlert)
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

        Text("先生成贴纸形象，再把背景轻轻拿走。")
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

      #if DEBUG
        if isUITestingCreateInputRouting {
          Button {
            Task { await loadUITestingCatalogPhoto(category: .top, confidence: 0.95) }
          } label: {
            Label("试一下商品图", systemImage: "tshirt.fill")
              .font(.system(.headline, design: .rounded, weight: .bold))
              .foregroundStyle(AdonisTheme.ink)
              .frame(maxWidth: .infinity, minHeight: 52)
              .background(
                AdonisTheme.butter.opacity(0.58),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
              )
          }
          .buttonStyle(StickerButtonStyle())
          .accessibilityIdentifier("create-catalog-test-image")

          Button {
            Task { await loadUITestingCatalogPhoto(category: nil, confidence: nil) }
          } label: {
            Label("试一下待确认商品图", systemImage: "questionmark.app.dashed")
              .font(.system(.headline, design: .rounded, weight: .bold))
              .foregroundStyle(AdonisTheme.ink)
              .frame(maxWidth: .infinity, minHeight: 52)
              .background(
                AdonisTheme.lavender.opacity(0.4),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
              )
          }
          .buttonStyle(StickerButtonStyle())
          .accessibilityIdentifier("create-ambiguous-catalog-test-image")
        }
      #endif
    }
  }

  private func wardrobeImportNoticeCard(_ notice: CreationWardrobeImportNotice) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: notice.systemImage)
          .font(.system(size: 20, weight: .bold))
          .foregroundStyle(AdonisTheme.leafInk)
          .frame(width: 42, height: 42)
          .background(AdonisTheme.leaf.opacity(0.2), in: Circle())
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
          Text(notice.title)
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(AdonisTheme.ink)
          Text(notice.detail)
            .font(.subheadline)
            .foregroundStyle(AdonisTheme.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      HStack(spacing: 12) {
        Button("继续创作") {
          wardrobeImportNotice = nil
        }
        .buttonStyle(.bordered)

        Button("去衣橱") {
          wardrobeImportNotice = nil
          onOpenWardrobe()
        }
        .buttonStyle(.borderedProminent)
        .tint(AdonisTheme.pomegranate)
        .accessibilityIdentifier("creation-open-wardrobe")
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(AdonisTheme.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(AdonisTheme.leaf.opacity(0.36), lineWidth: 1)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("creation-wardrobe-import-notice")
  }

  private var sampleSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      sampleSectionHeader

      ScrollView(.horizontal) {
        HStack(spacing: 14) {
          ForEach(samplesForDisplay) { sample in
            SamplePhotoButton(sample: sample) {
              guard let image = sample.image() else {
                presentGenerationError("样片没有正确打包进 App。")
                return
              }
              Task {
                #if DEBUG
                  if ProcessInfo.processInfo.arguments.contains(
                    "-ui-testing-ai-sticker-main-flow"
                  ) {
                    await generate(from: image, inputSource: .testFixture)
                    return
                  }
                #endif
                guard let sticker = sample.preparedStickerImage() else {
                  presentGenerationError("样片没有正确打包进 App。")
                  return
                }
                await generate(
                  from: image,
                  preparedSticker: sticker,
                  preparedMatteAssessment: sample.preparedMatteAssessment,
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

  private var samplesForDisplay: [SamplePhoto] {
    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("-ui-testing-show-rejected-sample") {
        return SampleCatalog.photos
      }
    #endif
    return SampleCatalog.showcasePhotos
  }

  @MainActor
  private var shouldUseSystemImagePlaygroundSource: Bool {
    #if DEBUG
      if usesSystemImagePlaygroundFixture {
        return true
      }
      if ProcessInfo.processInfo.arguments.contains("-ui-testing-ai-sticker-main-flow") {
        return false
      }
    #endif
    return SystemImagePlaygroundStickerSourceCapability.isAvailable
  }

  private var usesSystemImagePlaygroundFixture: Bool {
    #if DEBUG
      ProcessInfo.processInfo.arguments.contains(
        "-ui-testing-system-image-playground-main-flow"
      )
    #else
      false
    #endif
  }

  #if DEBUG
    private var isUITestingCreateInputRouting: Bool {
      ProcessInfo.processInfo.arguments.contains("-ui-testing-create-input-routing")
    }
  #endif

  @ViewBuilder
  private var sampleSectionHeader: some View {
    if dynamicTypeSize.isAccessibilitySize {
      VStack(alignment: .leading, spacing: 4) {
        Text("看看照片怎么变成贴纸")
          .font(.system(.title3, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
        Text("内置样片 · 本机处理")
          .font(.caption)
          .foregroundStyle(AdonisTheme.secondaryInk)
      }
    } else {
      HStack(alignment: .firstTextBaseline) {
        Text("看看照片怎么变成贴纸")
          .font(.system(.title3, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
        Spacer()
        Text("内置样片 · 本机处理")
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
      Text("没有账号或云同步。原照片只交给 Apple 系统生成贴纸底图；你确认后，仅这张 AI 底图会发送到 Adonis 图像服务做透明处理，收藏仍保存在当前设备。")
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
        presentedCreateAlert = nil
        cameraSheet = .picker
      case .unavailable:
        presentedCreateAlert = .camera(.unavailable)
      case .permissionDenied:
        presentedCreateAlert = .camera(.permissionDenied)
      case .restricted:
        presentedCreateAlert = .camera(.restricted)
      }
    }
  }

  private func createAlert(for alert: CreatePresentedAlert) -> Alert {
    switch alert {
    case .camera(let issue):
      cameraAccessAlert(for: issue)
    case .wardrobeFallback(let candidate):
      wardrobeFallbackAlert(for: candidate)
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

  private func wardrobeFallbackAlert(for candidate: CreationWardrobeCandidate) -> Alert {
    Alert(
      title: Text("这张更像衣服图片"),
      message: Text("这次没有做成人物贴纸。要把它收进衣橱吗？颜色和画面类型会在本机记住。"),
      primaryButton: .default(Text("收进衣橱")) {
        importPendingWardrobeCandidate(candidate)
      },
      secondaryButton: .cancel(Text("换一张"))
    )
  }

  private func openCameraSettings() {
    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
    openURL(settingsURL)
  }

  @MainActor
  private func loadPhoto(from item: PhotosPickerItem) async {
    let (loadID, recorder) = beginImageInput(source: .photoLibrary, retryPhotoItem: item)
    do {
      guard let data = try await item.loadTransferable(type: Data.self),
        let image = UIImage(data: data)
      else {
        throw StickerProcessingError.unreadableImage
      }
      guard activeGenerationID == loadID else { return }
      await routeLoadedImage(
        data: data,
        image: image,
        inputSource: .photoLibrary,
        operationID: loadID,
        performanceRecorder: recorder
      )
    } catch {
      handleImageInputFailure(
        error,
        inputSource: .photoLibrary,
        operationID: loadID,
        performanceRecorder: recorder
      )
    }
  }

  @MainActor
  private func loadCapturedPhoto(_ image: UIImage) async {
    let (loadID, recorder) = beginImageInput(source: .camera)
    do {
      guard let data = image.jpegData(compressionQuality: 0.94) else {
        throw StickerProcessingError.unreadableImage
      }
      await routeLoadedImage(
        data: data,
        image: image,
        inputSource: .camera,
        operationID: loadID,
        performanceRecorder: recorder
      )
    } catch {
      handleImageInputFailure(
        error,
        inputSource: .camera,
        operationID: loadID,
        performanceRecorder: recorder
      )
    }
  }

  #if DEBUG
    @MainActor
    private func loadUITestingCatalogPhoto(
      category: WardrobeCategory?,
      confidence: Double?
    ) async {
      let image = WardrobeTestImageFactory.brownCatalogShirt()
      let (loadID, recorder) = beginImageInput(source: .testFixture)
      do {
        guard let data = image.pngData() else {
          throw StickerProcessingError.unreadableImage
        }
        processingStage = .understanding
        let detected = try await wardrobeAnalyzer.analyze(data: data)
        let fixtureAnalysis = WardrobeImageAnalysis(
          sourceKind: detected.sourceKind,
          dominantColorName: detected.dominantColorName,
          dominantColorHex: detected.dominantColorHex,
          suggestedCategory: category,
          categoryConfidence: confidence,
          cleanBackgroundScore: detected.cleanBackgroundScore,
          imageWidth: detected.imageWidth,
          imageHeight: detected.imageHeight,
          imageFingerprint: detected.imageFingerprint,
          visualSignatureRawValue: detected.visualSignatureRawValue,
          processingMilliseconds: detected.processingMilliseconds,
          analysisVersion: detected.analysisVersion
        )
        await routeLoadedImage(
          data: data,
          image: image,
          inputSource: .testFixture,
          operationID: loadID,
          performanceRecorder: recorder,
          analysisOverride: fixtureAnalysis
        )
      } catch {
        handleImageInputFailure(
          error,
          inputSource: .testFixture,
          operationID: loadID,
          performanceRecorder: recorder
        )
      }
    }
  #endif

  @MainActor
  private func beginImageInput(
    source: EventInputSource,
    retryPhotoItem: PhotosPickerItem? = nil
  ) -> (id: UUID, recorder: GenerationPerformanceRecorder) {
    let operationID = UUID()
    let recorder = GenerationPerformanceRecorder(usesPreparedSample: false)
    activeGenerationID = operationID
    activeInputSource = source
    activePerformanceRecorder = recorder
    activeOperationKind = .routing
    activeFallbackCandidate = nil
    activeWardrobeCandidate = nil
    wardrobeImportNotice = nil
    retryInput = nil
    self.retryPhotoItem = retryPhotoItem
    processingStage = .reading
    isProcessing = true
    recorder.begin(.inputLoading)
    armGenerationDeadline(for: operationID)
    return (operationID, recorder)
  }

  @MainActor
  private func routeLoadedImage(
    data: Data,
    image: UIImage,
    inputSource: EventInputSource,
    operationID: UUID,
    performanceRecorder: GenerationPerformanceRecorder,
    analysisOverride: WardrobeImageAnalysis? = nil
  ) async {
    processingStage = .understanding
    let analysis: WardrobeImageAnalysis?
    if let analysisOverride {
      analysis = analysisOverride
    } else {
      analysis = try? await wardrobeAnalyzer.analyze(data: data)
    }
    guard activeGenerationID == operationID else { return }
    performanceRecorder.finish(.inputLoading)

    if let analysis {
      switch imageIntentRouter.route(analysis) {
      case .wardrobe:
        persistWardrobeCandidate(
          CreationWardrobeCandidate(
            data: data,
            analysis: analysis,
            inputSource: inputSource,
            route: .automatic
          ),
          operationID: operationID,
          deadlineAlreadyArmed: true
        )
        return
      case .creation(let offersWardrobeFallback):
        let wardrobeCandidate =
          offersWardrobeFallback
          ? CreationWardrobeCandidate(
            data: data,
            analysis: analysis,
            inputSource: inputSource,
            route: .afterCreationFailure
          ) : nil
        await generate(
          from: image,
          inputSource: inputSource,
          alreadyShowingProgress: true,
          performanceRecorder: performanceRecorder,
          generationID: operationID,
          deadlineAlreadyArmed: true,
          wardrobeCandidate: wardrobeCandidate
        )
        return
      }
    }

    await generate(
      from: image,
      inputSource: inputSource,
      alreadyShowingProgress: true,
      performanceRecorder: performanceRecorder,
      generationID: operationID,
      deadlineAlreadyArmed: true
    )
  }

  @MainActor
  private func handleImageInputFailure(
    _ error: Error,
    inputSource: EventInputSource,
    operationID: UUID,
    performanceRecorder: GenerationPerformanceRecorder
  ) {
    guard activeGenerationID == operationID else { return }
    deadlineController.cancel(generationID: operationID)
    let trace = performanceRecorder.makeTrace(interrupted: true)
    EventLogger.log(
      .generationFailed,
      detail: "input_read_failed;reason=\(error.localizedDescription)",
      inputSource: inputSource,
      processingVersion: CreationImageIntentRouter.version,
      generationPerformanceTrace: trace,
      in: modelContext
    )
    finishCreateOperation(operationID: operationID)
    presentGenerationError(error.localizedDescription)
  }

  @MainActor
  private func importPendingWardrobeCandidate(_ candidate: CreationWardrobeCandidate) {
    let operationID = UUID()
    activeGenerationID = operationID
    activeInputSource = candidate.inputSource
    activePerformanceRecorder = nil
    activeOperationKind = .wardrobeImport
    activeFallbackCandidate = nil
    activeWardrobeCandidate = nil
    retryInput = nil
    retryPhotoItem = nil
    processingStage = .remembering
    isProcessing = true
    persistWardrobeCandidate(
      candidate,
      operationID: operationID,
      deadlineAlreadyArmed: false
    )
  }

  @MainActor
  private func persistWardrobeCandidate(
    _ candidate: CreationWardrobeCandidate,
    operationID: UUID,
    deadlineAlreadyArmed: Bool
  ) {
    guard activeGenerationID == operationID else { return }
    activeOperationKind = .wardrobeImport
    processingStage = .remembering
    EventLogger.log(
      .wardrobeImportStarted,
      detail: candidate.route.eventDetail,
      inputSource: candidate.inputSource,
      processingVersion: CreationImageIntentRouter.version,
      in: modelContext
    )

    do {
      let outcome = try wardrobeImporter.persist(
        data: candidate.data,
        analysis: candidate.analysis,
        in: modelContext
      )
      guard activeGenerationID == operationID else { return }
      if deadlineAlreadyArmed {
        deadlineController.cancel(generationID: operationID)
      }
      let eventKind: AppEventKind =
        outcome.disposition == .added ? .wardrobeItemAdded : .wardrobeItemReused
      EventLogger.log(
        eventKind,
        durationMilliseconds: candidate.analysis.processingMilliseconds,
        detail: "\(outcome.eventDetail);\(candidate.route.eventDetail)",
        inputSource: candidate.inputSource,
        processingVersion: candidate.analysis.analysisVersion,
        in: modelContext
      )
      finishCreateOperation(operationID: operationID)
      wardrobeImportNotice = CreationWardrobeImportNotice(outcome: outcome)
    } catch {
      modelContext.rollback()
      if deadlineAlreadyArmed {
        deadlineController.cancel(generationID: operationID)
      }
      EventLogger.log(
        .wardrobeImportFailed,
        detail: "\(candidate.route.eventDetail);reason=\(error.localizedDescription)",
        inputSource: candidate.inputSource,
        processingVersion: candidate.analysis.analysisVersion,
        in: modelContext
      )
      finishCreateOperation(operationID: operationID)
      presentGenerationError(error.localizedDescription, title: "这次没有收进衣橱")
    }
  }

  @MainActor
  private func finishCreateOperation(operationID: UUID) {
    guard activeGenerationID == operationID else { return }
    systemImagePlaygroundRequest = nil
    activeGenerationID = nil
    activeInputSource = nil
    activePerformanceRecorder = nil
    activeOperationKind = nil
    activeFallbackCandidate = nil
    activeWardrobeCandidate = nil
    selectedPhotoItem = nil
    retryInput = nil
    retryPhotoItem = nil
    offersRetry = false
    isProcessing = false
  }

  @MainActor
  private func generate(
    from image: UIImage,
    inputSource: EventInputSource,
    alreadyShowingProgress: Bool = false,
    performanceRecorder: GenerationPerformanceRecorder? = nil,
    startEventLogged: Bool = false,
    generationID: UUID? = nil,
    deadlineAlreadyArmed: Bool = false,
    wardrobeCandidate: CreationWardrobeCandidate? = nil
  ) async {
    await generate(
      from: image,
      preparedSticker: nil,
      inputSource: inputSource,
      alreadyShowingProgress: alreadyShowingProgress,
      performanceRecorder: performanceRecorder,
      startEventLogged: startEventLogged,
      generationID: generationID,
      deadlineAlreadyArmed: deadlineAlreadyArmed,
      wardrobeCandidate: wardrobeCandidate
    )
  }

  @MainActor
  private func generate(
    from image: UIImage,
    preparedSticker: UIImage?,
    preparedMatteAssessment: StickerQualityAssessment = .acceptable,
    acceptedProviderOutput: CreativeProviderOutput? = nil,
    inputSource: EventInputSource,
    alreadyShowingProgress: Bool = false,
    performanceRecorder: GenerationPerformanceRecorder? = nil,
    startEventLogged: Bool = false,
    generationID suppliedGenerationID: UUID? = nil,
    deadlineAlreadyArmed: Bool = false,
    wardrobeCandidate: CreationWardrobeCandidate? = nil
  ) async {
    let generationID = suppliedGenerationID ?? UUID()
    let needsSystemImagePlayground =
      preparedSticker == nil
      && acceptedProviderOutput == nil
      && shouldUseSystemImagePlaygroundSource
    let recorder =
      performanceRecorder
      ?? GenerationPerformanceRecorder(usesPreparedSample: preparedSticker != nil)
    activeGenerationID = generationID
    activeInputSource = inputSource
    activePerformanceRecorder = recorder
    activeOperationKind = .generation
    activeFallbackCandidate = nil
    activeWardrobeCandidate = wardrobeCandidate
    retryPhotoItem = nil
    retryInput = GenerationRetryInput(
      image: image,
      preparedSticker: preparedSticker,
      preparedMatteAssessment: preparedMatteAssessment,
      acceptedProviderOutput: acceptedProviderOutput,
      inputSource: inputSource,
      wardrobeCandidate: wardrobeCandidate
    )
    if needsSystemImagePlayground {
      deadlineController.cancel(generationID: generationID)
    } else if !deadlineAlreadyArmed {
      if acceptedProviderOutput != nil {
        armGenerationDeadline(
          for: generationID,
          timeout: GenerationDeadlineController.aiTransparentProcessingTimeout,
          contractMilliseconds: 150_000
        )
      } else {
        armGenerationDeadline(for: generationID)
      }
    }
    if !alreadyShowingProgress {
      isProcessing = true
    }
    processingStage =
      preparedSticker == nil && acceptedProviderOutput == nil ? .generatingSticker : .separating
    if !startEventLogged {
      EventLogger.log(
        .generationStarted,
        inputSource: inputSource,
        processingVersion: AdonisProcessingVersion.generationPipeline,
        in: modelContext
      )
    }

    if let acceptedProviderOutput {
      recorder.recordExecutionMetadata(acceptedProviderOutput.executionMetadata)
      recorder.begin(.subjectExtraction)
    } else {
      recorder.begin(preparedSticker == nil ? .aiStickerGeneration : .subjectExtraction)
    }

    if needsSystemImagePlayground {
      isProcessing = false
      systemImagePlaygroundRequest = SystemImagePlaygroundRequest(
        id: generationID,
        sourceImage: image,
        inputSource: inputSource,
        performanceRecorder: recorder,
        wardrobeCandidate: wardrobeCandidate,
        usesFixture: usesSystemImagePlaygroundFixture
      )
      return
    }

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
      let aiStickerSourceImage: UIImage?
      let stickerProvenance: VisualContentProvenance
      let stickerExecutionMetadata: CreativeExecutionMetadata?
      if let preparedSticker {
        aiStickerSourceImage = nil
        stickerProvenance = .derivedFromOriginal
        stickerExecutionMetadata = nil
        processed = StickerProcessingResult(
          image: preparedSticker,
          elapsedMilliseconds: 0,
          foregroundCoverage: 0,
          rawMatteAssessment: preparedMatteAssessment,
          sourceFidelityAssessment: .acceptable
        )
      } else {
        let result: AIStickerCreationResult
        if let acceptedProviderOutput {
          result = try await aiStickerPipeline.createSticker(from: acceptedProviderOutput)
        } else {
          result = try await aiStickerPipeline.createSticker(from: image) {
            _, metadata in
            guard activeGenerationID == generationID else { return }
            recorder.finish(.aiStickerGeneration)
            recorder.recordExecutionMetadata(metadata)
            processingStage = .separating
            recorder.begin(.subjectExtraction)
          }
        }
        aiStickerSourceImage = result.generatedSourceImage
        stickerProvenance = .aiGenerated
        stickerExecutionMetadata = result.executionMetadata
        recorder.recordExecutionMetadata(result.executionMetadata)
        if result.executionMetadata.extractionProvider == .openAIGPTImage {
          recorder.recordExternalRequest()
        }
        processed = result.stickerProcessingResult
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
        foregroundCoverage: processed.foregroundCoverage,
        rawMatteAssessment: processed.rawMatteAssessment,
        sourceFidelityAssessment: processed.sourceFidelityAssessment
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
        throw StickerProcessingError.outputQualityTooLow(qualityAssessment)
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
        date: date,
        stickerProvenance: stickerProvenance
      )
      recorder.finish(.shareCardComposition)
      activeFallbackCandidate = GenerationFallbackCandidate(
        id: generationID,
        createdAt: date,
        sourceImage: image,
        aiStickerSourceImage: aiStickerSourceImage,
        stickerImage: processed.image,
        cardImage: card,
        bloomNumber: bloomNumber,
        foregroundCoverage: processed.foregroundCoverage,
        usesPreparedSample: preparedSticker != nil,
        inputSource: inputSource,
        stickerProvenance: stickerProvenance,
        stickerExecutionMetadata: stickerExecutionMetadata,
        qualityAssessment: qualityAssessment
      )
      let garmentObservations: [GarmentObservationDraft]
      if stickerProvenance.containsAIGeneratedPixels {
        garmentObservations = []
      } else {
        processingStage = .observing
        recorder.begin(.garmentObservation)
        if ProcessInfo.processInfo.arguments.contains(
          "-ui-testing-force-generation-fallback-timeout"
        ) {
          armGenerationDeadline(for: generationID, timeout: .seconds(1))
          try? await Task.sleep(for: .seconds(2))
          guard activeGenerationID == generationID else { return }
        }
        garmentObservations = await garmentObserver.observe(sticker: processed.image)
        recorder.finish(.garmentObservation)
        guard activeGenerationID == generationID else { return }
      }

      let trace = recorder.makeTrace(interrupted: false)
      deadlineController.cancel(generationID: generationID)
      EventLogger.log(
        .generationSucceeded,
        detail: stickerExecutionMetadata?.eventDetail(for: .aiStickerSource) ?? "prepared_sample",
        inputSource: inputSource,
        processingVersion: AdonisProcessingVersion.generationPipeline,
        generationPerformanceTrace: trace,
        in: modelContext
      )
      finishCreateOperation(operationID: generationID)
      draft = GenerationDraft(
        createdAt: date,
        sourceImage: image,
        aiStickerSourceImage: aiStickerSourceImage,
        stickerImage: processed.image,
        cardImage: card,
        bloomNumber: bloomNumber,
        processingMilliseconds: trace.totalMilliseconds,
        foregroundCoverage: processed.foregroundCoverage,
        usesPreparedSample: preparedSticker != nil,
        inputSource: inputSource,
        stickerProvenance: stickerProvenance,
        stickerExecutionMetadata: stickerExecutionMetadata,
        qualityAssessment: qualityAssessment,
        garmentObservations: garmentObservations
      )
    } catch {
      guard activeGenerationID == generationID else { return }
      let wardrobeCandidate = activeWardrobeCandidate
      let pendingRetryInput = retryInput
      deadlineController.cancel(generationID: generationID)
      let trace = recorder.makeTrace(interrupted: true)
      let failureDetail: String
      if let creativeError = error as? CreativeGenerationError {
        failureDetail =
          "stage=ai_sticker_source;reason=\(creativeError.eventCode);fallback=none"
      } else {
        failureDetail =
          "stage=ai_sticker_transparent_edit;reason=\(error.localizedDescription);fallback=none"
      }
      EventLogger.log(
        .generationFailed,
        detail: failureDetail,
        inputSource: inputSource,
        processingVersion: AdonisProcessingVersion.generationPipeline,
        generationPerformanceTrace: trace,
        in: modelContext
      )
      finishCreateOperation(operationID: generationID)
      if let creativeError = error as? CreativeGenerationError {
        presentAIStickerGenerationError(creativeError, retry: pendingRetryInput)
        return
      }
      if let wardrobeCandidate {
        errorMessage = nil
        offersRetry = false
        presentedCreateAlert = .wardrobeFallback(wardrobeCandidate)
        return
      }
      if error is AIStickerCloudExtractionError {
        presentGenerationError(
          error.localizedDescription,
          title: "AI 透明处理没有完成",
          retry: pendingRetryInput
        )
        return
      }
      if let processingError = error as? StickerProcessingError,
        case .outputQualityTooLow(let assessment) = processingError
      {
        presentGenerationError(
          assessment.userDetail,
          title: assessment.userTitle
        )
      } else if error is StickerProcessingError, preparedSticker == nil {
        presentGenerationError(
          "AI 贴纸形象已经生成，但透明版本不够完整。这次没有改用 Vision 或原照片直接处理，请再试一次或换一张照片。",
          title: "透明贴纸不够完整"
        )
      } else {
        presentGenerationError(error.localizedDescription)
      }
    }
  }

  @MainActor
  private func resumeAfterSystemImagePlayground(
    _ request: SystemImagePlaygroundRequest,
    output: CreativeProviderOutput
  ) {
    guard activeGenerationID == request.id else { return }
    systemImagePlaygroundRequest = nil
    Task { @MainActor in
      await Task.yield()
      await generate(
        from: request.sourceImage,
        preparedSticker: nil,
        acceptedProviderOutput: output,
        inputSource: request.inputSource,
        performanceRecorder: request.performanceRecorder,
        startEventLogged: true,
        generationID: request.id,
        deadlineAlreadyArmed: false,
        wardrobeCandidate: request.wardrobeCandidate
      )
    }
  }

  @MainActor
  private func handleSystemImagePlaygroundFailure(
    _ request: SystemImagePlaygroundRequest,
    error: CreativeGenerationError
  ) {
    guard activeGenerationID == request.id else { return }
    systemImagePlaygroundRequest = nil
    let pendingRetryInput = retryInput
    deadlineController.cancel(generationID: request.id)
    let trace = request.performanceRecorder.makeTrace(interrupted: true)
    EventLogger.log(
      .generationFailed,
      detail: "stage=ai_sticker_source;reason=\(error.eventCode);fallback=none",
      inputSource: request.inputSource,
      processingVersion: AdonisProcessingVersion.generationPipeline,
      generationPerformanceTrace: trace,
      in: modelContext
    )
    finishCreateOperation(operationID: request.id)
    presentAIStickerGenerationError(error, retry: pendingRetryInput)
  }

  @MainActor
  private func handleSystemImagePlaygroundCancellation(
    _ request: SystemImagePlaygroundRequest
  ) {
    guard activeGenerationID == request.id else { return }
    systemImagePlaygroundRequest = nil
    deadlineController.cancel(generationID: request.id)
    let trace = request.performanceRecorder.makeTrace(interrupted: true)
    EventLogger.log(
      .generationCancelled,
      detail: "stage=ai_sticker_source;provider=system_image_playground_sheet",
      inputSource: request.inputSource,
      processingVersion: AdonisProcessingVersion.generationPipeline,
      generationPerformanceTrace: trace,
      in: modelContext
    )
    finishCreateOperation(operationID: request.id)
  }

  @MainActor
  private func cancelGeneration() {
    guard let generationID = activeGenerationID else { return }
    let operationKind = activeOperationKind
    let inputSource = activeInputSource
    deadlineController.cancel(generationID: generationID)
    let trace = activePerformanceRecorder?.makeTrace(interrupted: true)
    switch operationKind {
    case .generation:
      EventLogger.log(
        .generationCancelled,
        inputSource: inputSource,
        processingVersion: AdonisProcessingVersion.generationPipeline,
        generationPerformanceTrace: trace,
        in: modelContext
      )
    case .wardrobeImport:
      EventLogger.log(
        .wardrobeImportCancelled,
        inputSource: inputSource,
        processingVersion: CreationImageIntentRouter.version,
        in: modelContext
      )
    case .routing, .none:
      break
    }
    finishCreateOperation(operationID: generationID)
  }

  @MainActor
  private func armGenerationDeadline(
    for generationID: UUID,
    timeout timeoutOverride: Duration? = nil,
    contractMilliseconds: Int = 90_000
  ) {
    activeDeadlineMilliseconds = contractMilliseconds
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
    let deadlineMilliseconds = activeDeadlineMilliseconds
    let inputSource = activeInputSource
    let operationKind = activeOperationKind
    let fallbackCandidate = activeFallbackCandidate
    let wardrobeCandidate = activeWardrobeCandidate
    activeGenerationID = nil
    activeInputSource = nil
    activePerformanceRecorder = nil
    activeOperationKind = nil
    activeFallbackCandidate = nil
    activeWardrobeCandidate = nil
    selectedPhotoItem = nil
    isProcessing = false

    guard operationKind == .generation else {
      errorTitle = "读取照片花了太久"
      offersRetry = retryPhotoItem != nil
      errorMessage = "这张照片还没有读完，已经停止等待。可以再试一次，或换一张照片。"
      return
    }

    EventLogger.log(
      .generationTimedOut,
      detail: fallbackCandidate == nil
        ? "deadline_ms=\(deadlineMilliseconds);fallback=unavailable"
        : "deadline_ms=\(deadlineMilliseconds);fallback=basic_sticker",
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
        processingMilliseconds: trace?.totalMilliseconds ?? deadlineMilliseconds
      )
      return
    }
    if let wardrobeCandidate {
      retryInput = nil
      retryPhotoItem = nil
      offersRetry = false
      errorMessage = nil
      presentedCreateAlert = .wardrobeFallback(wardrobeCandidate)
      return
    }
    errorTitle = "这次等得有点久"
    offersRetry = retryInput != nil || retryPhotoItem != nil
    errorMessage = "处理超过 \(deadlineMilliseconds / 1_000) 秒，已经停止等待。可以再试一次，或换一张照片。"
  }

  @MainActor
  private func retryLastGeneration() {
    errorMessage = nil
    offersRetry = false
    preparedSampleRecovery = nil
    if let retryInput {
      Task {
        await generate(
          from: retryInput.image,
          preparedSticker: retryInput.preparedSticker,
          preparedMatteAssessment: retryInput.preparedMatteAssessment,
          acceptedProviderOutput: retryInput.acceptedProviderOutput,
          inputSource: retryInput.inputSource,
          wardrobeCandidate: retryInput.wardrobeCandidate
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
  private func presentGenerationError(
    _ message: String,
    title: String = "这次没有生成成功",
    retry: GenerationRetryInput? = nil,
    preparedSampleRecovery: SamplePhoto? = nil
  ) {
    errorTitle = title
    offersRetry = retry != nil
    retryInput = retry
    retryPhotoItem = nil
    self.preparedSampleRecovery = preparedSampleRecovery
    errorMessage = message
  }

  @MainActor
  private func presentAIStickerGenerationError(
    _ error: CreativeGenerationError,
    retry: GenerationRetryInput?
  ) {
    switch error {
    case .unavailable, .unsupportedLanguage:
      presentGenerationError(
        "这次需要先生成 AI 贴纸形象，再做 AI 透明处理。当前设备或系统设置不支持第一步生成。你可以先体验明确标注的内置样片；Adonis 不会用样片替换你的照片，也不会改用原图直接处理。",
        title: "当前设备不能生成 AI 贴纸",
        preparedSampleRecovery: SampleCatalog.showcasePhotos.first
      )
    case .unsupportedSource, .personTooSmall:
      presentGenerationError(
        "系统没能根据这张照片生成完整的贴纸形象。请换一张人物更清楚、全身更完整的照片；Adonis 没有改用原照片直接处理。",
        title: "换一张更清楚的照片"
      )
    case .cancelled:
      presentGenerationError("已经停止这次 AI 贴纸生成。", title: "已停止生成")
    case .timedOut, .noImage, .failed:
      presentGenerationError(
        "AI 贴纸形象还没有成功生成，因此没有进入透明处理，也没有改用原照片直接处理。可以再试一次。",
        title: "AI 贴纸形象没有生成好",
        retry: retry
      )
    }
  }

  @MainActor
  private func startPreparedSampleRecovery(_ sample: SamplePhoto) {
    guard let image = sample.image(), let sticker = sample.preparedStickerImage() else {
      presentGenerationError("样片没有正确打包进 App。")
      return
    }
    errorMessage = nil
    offersRetry = false
    retryInput = nil
    retryPhotoItem = nil
    preparedSampleRecovery = nil
    Task {
      await generate(
        from: image,
        preparedSticker: sticker,
        preparedMatteAssessment: sample.preparedMatteAssessment,
        inputSource: .preparedSample
      )
    }
  }

  @MainActor
  private func save(
    _ draft: GenerationDraft,
    stickerFidelityReview: StickerFidelityReview? = nil
  ) throws {
    guard !records.contains(where: { $0.id == draft.id }) else { return }

    let prefix = draft.id.uuidString.lowercased()
    var savedFilenames: [String] = []

    do {
      let sourceFilename = try MediaStore.shared.savePNG(
        draft.sourceImage,
        filename: "\(prefix)-source.png"
      )
      savedFilenames.append(sourceFilename)
      let aiStickerSourceFilename: String?
      if let aiStickerSourceImage = draft.aiStickerSourceImage {
        let savedAIStickerSourceFilename = try MediaStore.shared.savePNG(
          aiStickerSourceImage,
          filename: "\(prefix)-ai-sticker-source.png"
        )
        aiStickerSourceFilename = savedAIStickerSourceFilename
        savedFilenames.append(savedAIStickerSourceFilename)
      } else {
        aiStickerSourceFilename = nil
      }
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
        aiStickerSourceImageFilename: aiStickerSourceFilename,
        stickerImageFilename: stickerFilename,
        cardImageFilename: cardFilename,
        bloomNumber: draft.bloomNumber,
        stickerProvenance: draft.stickerProvenance,
        stickerExecutionMetadata: draft.stickerExecutionMetadata,
        generationCompletionMode: draft.completionMode,
        stickerQualityAssessment: draft.qualityAssessment,
        stickerQualityVersion: StickerQualityAssessor.version,
        stickerFidelityReview: stickerFidelityReview
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
    if let stickerFidelityReview {
      EventLogger.log(
        .stickerFidelityReviewed,
        detail: stickerFidelityReview.eventDetail,
        inputSource: draft.inputSource,
        processingVersion: StickerFidelityReview.version,
        in: modelContext
      )
    }
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
  private func save(
    _ review: StickerFidelityReview,
    for draft: GenerationDraft
  ) throws {
    let draftID = draft.id
    let descriptor = FetchDescriptor<OutfitRecord>(
      predicate: #Predicate { $0.id == draftID }
    )
    guard let record = try modelContext.fetch(descriptor).first else {
      throw StickerFidelityReviewSaveError.outfitMissing
    }

    do {
      record.setStickerFidelityReview(review)
      try modelContext.save()
    } catch {
      modelContext.rollback()
      throw error
    }
    EventLogger.log(
      .stickerFidelityReviewed,
      detail: review.eventDetail,
      inputSource: draft.inputSource,
      processingVersion: StickerFidelityReview.version,
      in: modelContext
    )
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
      detail: creativeWork.eventDetail,
      inputSource: draft.inputSource,
      processingVersion: creativeWork.recipe.version,
      in: modelContext
    )
  }
}

private struct GenerationRetryInput {
  let image: UIImage
  let preparedSticker: UIImage?
  let preparedMatteAssessment: StickerQualityAssessment
  let acceptedProviderOutput: CreativeProviderOutput?
  let inputSource: EventInputSource
  let wardrobeCandidate: CreationWardrobeCandidate?
}

@MainActor
private struct SystemImagePlaygroundRequest: Identifiable {
  let id: UUID
  let sourceImage: UIImage
  let inputSource: EventInputSource
  let performanceRecorder: GenerationPerformanceRecorder
  let wardrobeCandidate: CreationWardrobeCandidate?
  let usesFixture: Bool
}

private enum CreateOperationKind: Equatable {
  case routing
  case generation
  case wardrobeImport
}

private enum CreationWardrobeImportRoute {
  case automatic
  case afterCreationFailure

  var eventDetail: String {
    switch self {
    case .automatic: "route=create_input_auto"
    case .afterCreationFailure: "route=create_input_fallback"
    }
  }
}

private struct CreationWardrobeCandidate: Identifiable {
  let id = UUID()
  let data: Data
  let analysis: WardrobeImageAnalysis
  let inputSource: EventInputSource
  let route: CreationWardrobeImportRoute
}

private struct CreationWardrobeImportNotice: Identifiable {
  let id = UUID()
  let title: String
  let detail: String
  let systemImage: String

  init(outcome: WardrobeItemImportOutcome) {
    switch outcome.disposition {
    case .added:
      title = "已收进衣橱"
      detail = "\(outcome.item.name)已经记好了。颜色和画面类型只保存在本机，不需要再填资料。"
      systemImage = "checkmark.circle.fill"
    case .reused:
      title = "衣橱里已经有它"
      detail = "找到了已有的\(outcome.item.name)，没有重复添加。"
      systemImage = "arrow.triangle.2.circlepath.circle.fill"
    }
  }
}

private enum CreatePresentedAlert: Identifiable {
  case camera(CameraAccessAlert)
  case wardrobeFallback(CreationWardrobeCandidate)

  var id: String {
    switch self {
    case .camera(let issue): "camera-\(issue.id)"
    case .wardrobeFallback(let candidate): "wardrobe-\(candidate.id.uuidString)"
    }
  }
}

private enum CameraSheet: String, Identifiable {
  case picker

  var id: String { rawValue }
}

private enum StickerFidelityReviewSaveError: LocalizedError {
  case outfitMissing

  var errorDescription: String? {
    "这条收藏还没有保存好，请先点“收藏今天”再试。"
  }
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
      "可以选择相册照片，或先用下面的内置样片体验完整流程。"
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
  let aiStickerSourceImage: UIImage?
  let stickerImage: UIImage
  let cardImage: UIImage
  let bloomNumber: Int
  let foregroundCoverage: Double
  let usesPreparedSample: Bool
  let inputSource: EventInputSource
  let stickerProvenance: VisualContentProvenance
  let stickerExecutionMetadata: CreativeExecutionMetadata?
  let qualityAssessment: StickerQualityAssessment

  func makeDraft(processingMilliseconds: Int) -> GenerationDraft {
    GenerationDraft(
      id: id,
      createdAt: createdAt,
      sourceImage: sourceImage,
      aiStickerSourceImage: aiStickerSourceImage,
      stickerImage: stickerImage,
      cardImage: cardImage,
      bloomNumber: bloomNumber,
      processingMilliseconds: processingMilliseconds,
      foregroundCoverage: foregroundCoverage,
      usesPreparedSample: usesPreparedSample,
      inputSource: inputSource,
      stickerProvenance: stickerProvenance,
      stickerExecutionMetadata: stickerExecutionMetadata,
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
        SampleTransformationPreview(sample: sample, width: imageWidth)

        Text(sample.title)
          .font(.system(.subheadline, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)

        VStack(alignment: .leading, spacing: 3) {
          Text("原图 → 透明贴纸")
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .foregroundStyle(AdonisTheme.leafInk)

          Text(sample.subtitle)
            .font(.caption2)
            .foregroundStyle(AdonisTheme.secondaryInk)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(9)
      .frame(width: cardWidth, alignment: .leading)
      .background(AdonisTheme.paper, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
      .shadow(color: AdonisTheme.ink.opacity(0.08), radius: 10, y: 5)
    }
    .buttonStyle(StickerButtonStyle())
    .accessibilityLabel(
      "使用样片：\(sample.title)。原始照片变成透明贴纸，来自内置样片，属于原图处理。"
    )
    .accessibilityHint("点一下体验完整的贴纸和收藏卡流程")
    .accessibilityIdentifier(sample.id)
  }

  private var cardWidth: CGFloat {
    dynamicTypeSize.isAccessibilitySize ? 256 : 214
  }

  private var imageWidth: CGFloat {
    cardWidth - 18
  }
}

private struct SampleTransformationPreview: View {
  let sample: SamplePhoto
  let width: CGFloat

  var body: some View {
    HStack(spacing: 0) {
      originalPreview
        .frame(width: panelWidth, height: 176)
        .clipped()

      stickerPreview
        .frame(width: panelWidth, height: 176)
        .clipped()
    }
    .frame(width: width, height: 176)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(AdonisTheme.ink.opacity(0.1), lineWidth: 1)
    }
    .overlay {
      Image(systemName: "arrow.right")
        .font(.system(size: 11, weight: .black))
        .foregroundStyle(Color.white)
        .frame(width: 28, height: 28)
        .background(AdonisTheme.ink, in: Circle())
        .overlay {
          Circle().stroke(Color.white.opacity(0.9), lineWidth: 2)
        }
        .shadow(color: AdonisTheme.ink.opacity(0.18), radius: 5, y: 2)
        .accessibilityHidden(true)
    }
    .accessibilityHidden(true)
  }

  private var panelWidth: CGFloat {
    width / 2
  }

  private var originalPreview: some View {
    ZStack(alignment: .topLeading) {
      AdonisTheme.lavender.opacity(0.38)

      if let image = sample.image() {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .frame(width: panelWidth, height: 176)
          .clipped()
      }

      previewTag("原图", foreground: AdonisTheme.ink, background: Color.white.opacity(0.88))
        .padding(8)
    }
  }

  private var stickerPreview: some View {
    ZStack(alignment: .topTrailing) {
      AdonisTheme.butter.opacity(0.62)

      Circle()
        .fill(AdonisTheme.pomegranate.opacity(0.12))
        .frame(width: 86, height: 86)
        .offset(x: 28, y: 118)

      Circle()
        .fill(AdonisTheme.leaf.opacity(0.2))
        .frame(width: 62, height: 62)
        .offset(x: -52, y: -20)

      if let sticker = sample.preparedStickerImage() {
        Image(uiImage: sticker)
          .resizable()
          .scaledToFit()
          .padding(.horizontal, 9)
          .padding(.top, 25)
          .padding(.bottom, 7)
          .shadow(color: AdonisTheme.ink.opacity(0.15), radius: 5, y: 3)
      }

      previewTag(
        "原图处理",
        foreground: AdonisTheme.leafInk,
        background: Color.white.opacity(0.9)
      )
      .padding(8)
    }
  }

  private func previewTag(
    _ title: String,
    foreground: Color,
    background: Color
  ) -> some View {
    Text(title)
      .font(.system(size: 9, weight: .black, design: .rounded))
      .foregroundStyle(foreground)
      .padding(.horizontal, 7)
      .padding(.vertical, 5)
      .background(background, in: Capsule())
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
