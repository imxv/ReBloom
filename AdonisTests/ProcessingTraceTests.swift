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
}
