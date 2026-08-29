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

    EventLogger.log(
      .generationSucceeded,
      durationMilliseconds: 420,
      detail: "prepared_sample",
      inputSource: .preparedSample,
      processingVersion: AdonisProcessingVersion.generationPipeline,
      in: context
    )

    let event = try XCTUnwrap(try context.fetch(FetchDescriptor<AppEvent>()).first)
    XCTAssertEqual(event.kind, .generationSucceeded)
    XCTAssertEqual(event.durationMilliseconds, 420)
    XCTAssertEqual(event.inputSource, .preparedSample)
    XCTAssertEqual(event.processingVersion, AdonisProcessingVersion.generationPipeline)
    XCTAssertEqual(event.detail, "prepared_sample")
  }

  func testShareExtensionHasAUserFacingInputSourceAndStableVersion() {
    XCTAssertEqual(EventInputSource.shareExtension.title, "其他 App")
    XCTAssertEqual(
      AdonisProcessingVersion.sharedWardrobeInbox,
      "wardrobe-share-inbox-v1"
    )
  }

  func testGenerationPipelineIncludesStructuralQualityAssessment() {
    XCTAssertEqual(
      StickerQualityAssessor.version,
      "sticker-quality-structural-v1"
    )
    XCTAssertTrue(
      AdonisProcessingVersion.generationPipeline.contains(StickerQualityAssessor.version)
    )
    XCTAssertEqual(AppEventKind.generationQualityWarning.title, "贴纸建议复查")
    XCTAssertEqual(AppEventKind.generationQualityRejected.title, "贴纸质量未通过")
  }
}
