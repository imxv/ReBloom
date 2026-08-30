import Foundation

enum EventInputSource: String, Sendable {
  case photoLibrary
  case camera
  case preparedSample
  case shareExtension
  case testFixture

  var title: String {
    switch self {
    case .photoLibrary: "相册"
    case .camera: "相机"
    case .preparedSample: "内置样片"
    case .shareExtension: "其他 App"
    case .testFixture: "测试样片"
    }
  }
}

enum AdonisProcessingVersion {
  static let sticker = "sticker-vision-v1"
  static let stickerQuality = "sticker-quality-raw-and-delivery-v2"
  static let shareCard = "share-card-v1"
  static let digitalFigurineCard = "digital-figurine-card-v1"
  static let botanicalPoster = "botanical-poster-v1"
  static let floralSketch = "floral-sketch-v1"
  static let mythicGarden = "mythic-garden-v1"
  static let moonlitTheater = "moonlit-theater-v1"
  static let stickerTryOn = "sticker-try-on-v1"
  static let digitalCabinet = "digital-cabinet-v1"
  static let seasonalBloom = "seasonal-bloom-v1"
  static let rebloomSuggestion = "rebloom-suggestion-v1"
  static let rebloomReminder = "rebloom-reminder-v1"
  static let wardrobeAnalysis = "wardrobe-local-v2"
  static let wardrobeImageUpgrade = "wardrobe-image-upgrade-v1"
  static let outfitObservation = "ootd-observation-local-v2"
  static let candidateMatching = "wardrobe-candidate-local-v2"
  static let wardrobeVisualSignature = GarmentVisualSignature.currentVersion
  static let wardrobeHistoryMatching = "wardrobe-history-backfill-v1"
  static let sharedWardrobeInbox = SharedImageInbox.version
  static let generationPipeline =
    "\(sticker)+\(stickerQuality)+\(shareCard)+\(outfitObservation)"
}

enum GenerationPerformanceStage: String, CaseIterable, Codable, Sendable {
  case inputLoading
  case subjectExtraction
  case qualityAssessment
  case shareCardComposition
  case garmentObservation

  var title: String {
    switch self {
    case .inputLoading: "读取照片"
    case .subjectExtraction: "抠图与白边"
    case .qualityAssessment: "蒙版与成品检查"
    case .shareCardComposition: "收藏卡排版"
    case .garmentObservation: "衣物线索"
    }
  }
}

struct GenerationStageTiming: Codable, Equatable, Sendable {
  let stage: GenerationPerformanceStage
  let milliseconds: Int

  init(stage: GenerationPerformanceStage, milliseconds: Int) {
    self.stage = stage
    self.milliseconds = max(0, milliseconds)
  }
}

enum GenerationBudgetStatus: String, Codable, Sendable {
  case withinTarget
  case exceededTarget

  var title: String {
    switch self {
    case .withinTarget: "目标内"
    case .exceededTarget: "超过目标"
    }
  }
}

struct GenerationPerformanceTrace: Codable, Equatable, Sendable {
  static let currentVersion = "generation-performance-v1"
  static let firstResultTargetMilliseconds = 45_000

  let version: String
  let totalMilliseconds: Int
  let targetMilliseconds: Int
  let stageTimings: [GenerationStageTiming]
  let retryCount: Int
  let externalRequestCount: Int
  let usesPreparedSample: Bool
  let interruptedStage: GenerationPerformanceStage?

  init(
    version: String = Self.currentVersion,
    totalMilliseconds: Int,
    targetMilliseconds: Int = Self.firstResultTargetMilliseconds,
    stageTimings: [GenerationStageTiming],
    retryCount: Int = 0,
    externalRequestCount: Int = 0,
    usesPreparedSample: Bool,
    interruptedStage: GenerationPerformanceStage? = nil
  ) {
    self.version = version
    self.totalMilliseconds = max(0, totalMilliseconds)
    self.targetMilliseconds = max(1, targetMilliseconds)
    self.stageTimings = stageTimings
    self.retryCount = max(0, retryCount)
    self.externalRequestCount = max(0, externalRequestCount)
    self.usesPreparedSample = usesPreparedSample
    self.interruptedStage = interruptedStage
  }

  var budgetStatus: GenerationBudgetStatus {
    totalMilliseconds <= targetMilliseconds ? .withinTarget : .exceededTarget
  }

  var slowestStage: GenerationStageTiming? {
    stageTimings.max { lhs, rhs in lhs.milliseconds < rhs.milliseconds }
  }

  func milliseconds(for stage: GenerationPerformanceStage) -> Int? {
    let values = stageTimings.filter { $0.stage == stage }.map(\.milliseconds)
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +)
  }
}

@MainActor
final class GenerationPerformanceRecorder {
  private let startedAt: ContinuousClock.Instant
  private let targetMilliseconds: Int
  private let usesPreparedSample: Bool
  private let now: () -> ContinuousClock.Instant

  private var activeStage: GenerationPerformanceStage?
  private var activeStageStartedAt: ContinuousClock.Instant?
  private var lastStage: GenerationPerformanceStage?
  private var stageTimings: [GenerationStageTiming] = []
  private var retryCount = 0
  private var externalRequestCount = 0
  private var finishedAt: ContinuousClock.Instant?
  private var finishedTrace: GenerationPerformanceTrace?

  init(
    targetMilliseconds: Int = GenerationPerformanceTrace.firstResultTargetMilliseconds,
    usesPreparedSample: Bool,
    now: @escaping () -> ContinuousClock.Instant = { ContinuousClock.now }
  ) {
    self.targetMilliseconds = targetMilliseconds
    self.usesPreparedSample = usesPreparedSample
    self.now = now
    self.startedAt = now()
  }

  func begin(_ stage: GenerationPerformanceStage) {
    guard finishedAt == nil else { return }
    let instant = now()
    finishActiveStage(at: instant)
    activeStage = stage
    activeStageStartedAt = instant
    lastStage = stage
  }

  func finish(_ stage: GenerationPerformanceStage) {
    guard finishedAt == nil else { return }
    assert(activeStage == stage, "Tried to finish a generation stage that is not active")
    guard activeStage == stage else { return }
    finishActiveStage(at: now())
  }

  func recordRetry() {
    guard finishedAt == nil else { return }
    retryCount += 1
  }

  func recordExternalRequest() {
    guard finishedAt == nil else { return }
    externalRequestCount += 1
  }

  func makeTrace(interrupted: Bool) -> GenerationPerformanceTrace {
    if let finishedTrace { return finishedTrace }
    let instant = finishedAt ?? now()
    let interruptedStage = interrupted ? (activeStage ?? lastStage) : nil
    finishActiveStage(at: instant)
    finishedAt = instant
    let trace = GenerationPerformanceTrace(
      totalMilliseconds: Self.milliseconds(from: startedAt.duration(to: instant)),
      targetMilliseconds: targetMilliseconds,
      stageTimings: stageTimings,
      retryCount: retryCount,
      externalRequestCount: externalRequestCount,
      usesPreparedSample: usesPreparedSample,
      interruptedStage: interruptedStage
    )
    finishedTrace = trace
    return trace
  }

  private func finishActiveStage(at instant: ContinuousClock.Instant) {
    guard let activeStage, let activeStageStartedAt else { return }
    stageTimings.append(
      GenerationStageTiming(
        stage: activeStage,
        milliseconds: Self.milliseconds(from: activeStageStartedAt.duration(to: instant))
      ))
    self.activeStage = nil
    self.activeStageStartedAt = nil
  }

  private static func milliseconds(from duration: Duration) -> Int {
    max(
      0,
      Int(duration.components.seconds * 1_000)
        + Int(duration.components.attoseconds / 1_000_000_000_000_000)
    )
  }
}
