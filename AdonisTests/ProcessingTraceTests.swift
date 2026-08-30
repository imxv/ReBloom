import SwiftData
import XCTest

@testable import Adonis

final class ProcessingTraceTests: XCTestCase {
  @MainActor
  func testEventLoggerPersistsInputSourceAndProcessingVersion() throws {
    let schema = Schema([AppEvent.self])
    let container = try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)

    let trace = GenerationPerformanceTrace(
      totalMilliseconds: 420,
      targetMilliseconds: 500,
      stageTimings: [
        GenerationStageTiming(stage: .subjectExtraction, milliseconds: 300),
        GenerationStageTiming(stage: .qualityAssessment, milliseconds: 120),
      ],
      retryCount: 1,
      externalRequestCount: 0,
      usesPreparedSample: true
    )
    XCTAssertTrue(
      EventLogger.log(
        .generationSucceeded,
        durationMilliseconds: 999,
        detail: "prepared_sample",
        inputSource: .preparedSample,
        processingVersion: AdonisProcessingVersion.generationPipeline,
        generationPerformanceTrace: trace,
        in: context
      ))

    let event = try XCTUnwrap(try context.fetch(FetchDescriptor<AppEvent>()).first)
    XCTAssertEqual(event.kind, .generationSucceeded)
    XCTAssertEqual(event.durationMilliseconds, 420)
    XCTAssertEqual(event.inputSource, .preparedSample)
    XCTAssertEqual(event.processingVersion, AdonisProcessingVersion.generationPipeline)
    XCTAssertEqual(event.detail, "prepared_sample")
    XCTAssertEqual(event.generationPerformanceTrace, trace)
  }

  @MainActor
  func testFailureEventRetainsInterruptedStageWithoutExternalRequests() throws {
    let schema = Schema([AppEvent.self])
    let container = try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let trace = GenerationPerformanceTrace(
      totalMilliseconds: 730,
      stageTimings: [
        GenerationStageTiming(stage: .subjectExtraction, milliseconds: 730)
      ],
      usesPreparedSample: false,
      interruptedStage: .subjectExtraction
    )

    XCTAssertTrue(
      EventLogger.log(
        .generationFailed,
        detail: "test_failure",
        inputSource: .camera,
        processingVersion: AdonisProcessingVersion.generationPipeline,
        generationPerformanceTrace: trace,
        in: context
      ))

    let event = try XCTUnwrap(try context.fetch(FetchDescriptor<AppEvent>()).first)
    XCTAssertEqual(event.kind, .generationFailed)
    XCTAssertEqual(event.generationPerformanceTrace?.interruptedStage, .subjectExtraction)
    XCTAssertEqual(event.generationPerformanceTrace?.externalRequestCount, 0)
    XCTAssertEqual(event.generationPerformanceTrace?.retryCount, 0)
  }

  @MainActor
  func testAIStickerGenerationStageAndProviderMetadataSurviveEventPersistence() throws {
    let schema = Schema([AppEvent.self])
    let container = try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let trace = GenerationPerformanceTrace(
      totalMilliseconds: 940,
      stageTimings: [
        GenerationStageTiming(stage: .aiStickerGeneration, milliseconds: 800),
        GenerationStageTiming(stage: .subjectExtraction, milliseconds: 140),
      ],
      usesPreparedSample: false,
      executionMetadata: .appleImagePlayground
    )

    XCTAssertTrue(
      EventLogger.log(
        .generationSucceeded,
        inputSource: .photoLibrary,
        processingVersion: AdonisProcessingVersion.generationPipeline,
        generationPerformanceTrace: trace,
        in: context
      )
    )

    let event = try XCTUnwrap(try context.fetch(FetchDescriptor<AppEvent>()).first)
    XCTAssertEqual(event.generationPerformanceTrace, trace)
    XCTAssertEqual(
      event.generationPerformanceTrace?.milliseconds(for: .aiStickerGeneration),
      800
    )
    XCTAssertEqual(event.generationPerformanceTrace?.executionMetadata, .appleImagePlayground)
  }

  @MainActor
  func testRecorderMeasuresSequentialStagesAgainstBudget() {
    let clock = ContinuousClock()
    var now = clock.now
    let recorder = GenerationPerformanceRecorder(
      targetMilliseconds: 200,
      usesPreparedSample: false,
      now: { now }
    )

    recorder.begin(.subjectExtraction)
    now = now.advanced(by: .milliseconds(125))
    recorder.finish(.subjectExtraction)
    recorder.begin(.qualityAssessment)
    now = now.advanced(by: .milliseconds(25))
    recorder.finish(.qualityAssessment)
    recorder.recordRetry()
    recorder.recordExternalRequest()

    let trace = recorder.makeTrace(interrupted: false)
    XCTAssertEqual(trace.totalMilliseconds, 150)
    XCTAssertEqual(trace.milliseconds(for: .subjectExtraction), 125)
    XCTAssertEqual(trace.milliseconds(for: .qualityAssessment), 25)
    XCTAssertEqual(trace.slowestStage?.stage, .subjectExtraction)
    XCTAssertEqual(trace.budgetStatus, .withinTarget)
    XCTAssertNil(trace.interruptedStage)
    XCTAssertFalse(trace.usesPreparedSample)
    XCTAssertEqual(trace.retryCount, 1)
    XCTAssertEqual(trace.externalRequestCount, 1)

    recorder.recordRetry()
    recorder.begin(.shareCardComposition)
    XCTAssertEqual(recorder.makeTrace(interrupted: true), trace)
  }

  @MainActor
  func testInterruptedRecorderPersistsPartialActiveStageAndExceededBudget() {
    let clock = ContinuousClock()
    var now = clock.now
    let recorder = GenerationPerformanceRecorder(
      targetMilliseconds: 100,
      usesPreparedSample: true,
      now: { now }
    )

    recorder.begin(.garmentObservation)
    now = now.advanced(by: .milliseconds(150))
    let trace = recorder.makeTrace(interrupted: true)

    XCTAssertEqual(trace.totalMilliseconds, 150)
    XCTAssertEqual(trace.milliseconds(for: .garmentObservation), 150)
    XCTAssertEqual(trace.interruptedStage, .garmentObservation)
    XCTAssertEqual(trace.budgetStatus, .exceededTarget)
    XCTAssertTrue(trace.usesPreparedSample)
  }

  func testGenerationPerformanceContractUsesStableVersionAndFirstResultTarget() {
    XCTAssertEqual(
      GenerationPerformanceTrace.currentVersion,
      "generation-performance-v2"
    )
    XCTAssertEqual(
      GenerationPerformanceTrace.firstResultTargetMilliseconds,
      45_000
    )
    XCTAssertEqual(GenerationPerformanceStage.allCases.count, 6)

    let sanitized = GenerationPerformanceTrace(
      totalMilliseconds: -10,
      targetMilliseconds: 0,
      stageTimings: [
        GenerationStageTiming(stage: .inputLoading, milliseconds: -20)
      ],
      retryCount: -1,
      externalRequestCount: -1,
      usesPreparedSample: false
    )
    XCTAssertEqual(sanitized.totalMilliseconds, 0)
    XCTAssertEqual(sanitized.targetMilliseconds, 1)
    XCTAssertEqual(sanitized.milliseconds(for: .inputLoading), 0)
    XCTAssertEqual(sanitized.retryCount, 0)
    XCTAssertEqual(sanitized.externalRequestCount, 0)
  }

  func testShareExtensionHasAUserFacingInputSourceAndStableVersion() {
    XCTAssertEqual(EventInputSource.shareExtension.title, "其他 App")
    XCTAssertEqual(
      AdonisProcessingVersion.sharedWardrobeInbox,
      "wardrobe-share-inbox-v1"
    )
  }

  func testGenerationPipelineIncludesRawMatteSourceFidelityAndDeliveryQualityAssessment() {
    XCTAssertEqual(
      StickerSourceFidelityAssessor.version,
      "sticker-source-fidelity-v1"
    )
    XCTAssertEqual(
      StickerQualityAssessor.version,
      "sticker-quality-raw-fidelity-delivery-v3"
    )
    XCTAssertTrue(
      AdonisProcessingVersion.generationPipeline.contains(
        StickerSourceFidelityAssessor.version
      )
    )
    XCTAssertTrue(
      AdonisProcessingVersion.generationPipeline.contains(StickerQualityAssessor.version)
    )
    XCTAssertEqual(AppEventKind.generationQualityWarning.title, "贴纸建议复查")
    XCTAssertEqual(AppEventKind.generationQualityRejected.title, "贴纸质量未通过")
  }
}
