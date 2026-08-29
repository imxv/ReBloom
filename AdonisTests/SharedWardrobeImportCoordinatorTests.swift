import SwiftData
import XCTest

@testable import Adonis

final class SharedWardrobeImportCoordinatorTests: XCTestCase {
  @MainActor
  func testPendingImagesImportOnceAndDuplicateDataReusesExistingItem() async throws {
    let fixture = try makeFixture()
    defer { fixture.cleanup() }
    let data = try XCTUnwrap(WardrobeTestImageFactory.brownCatalogShirt().pngData())
    try fixture.inbox.enqueue(data: data)
    try fixture.inbox.enqueue(data: data)

    let coordinator = SharedWardrobeImportCoordinator(
      importer: WardrobeItemImportService(mediaStore: fixture.store)
    )
    let summary = try await coordinator.importPending(
      from: fixture.inbox,
      in: fixture.context
    )

    XCTAssertEqual(summary, SharedWardrobeImportSummary(addedCount: 1, reusedCount: 1))
    XCTAssertEqual(try fixture.context.fetchCount(FetchDescriptor<WardrobeItem>()), 1)
    XCTAssertTrue(try fixture.inbox.pendingItems().isEmpty)
    XCTAssertEqual(
      try FileManager.default.contentsOfDirectory(atPath: fixture.mediaDirectory.path).count,
      1
    )

    let events = try fixture.context.fetch(FetchDescriptor<AppEvent>())
    XCTAssertEqual(events.filter { $0.kind == .wardrobeImportStarted }.count, 2)
    XCTAssertEqual(events.filter { $0.kind == .wardrobeItemAdded }.count, 1)
    XCTAssertEqual(events.filter { $0.kind == .wardrobeItemReused }.count, 1)
    XCTAssertTrue(
      events
        .filter { $0.kind == .wardrobeItemAdded || $0.kind == .wardrobeItemReused }
        .allSatisfy { $0.inputSource == .shareExtension }
    )
  }

  @MainActor
  func testFailedPendingImageIsRetainedForExplicitRetry() async throws {
    let fixture = try makeFixture()
    defer { fixture.cleanup() }
    let invalidURL = fixture.inboxDirectory
      .appendingPathComponent("1700000000000-invalid.\(SharedImageInbox.filenameExtension)")
    try Data("not-an-image".utf8).write(to: invalidURL, options: .atomic)

    let coordinator = SharedWardrobeImportCoordinator(
      importer: WardrobeItemImportService(mediaStore: fixture.store)
    )
    let summary = try await coordinator.importPending(
      from: fixture.inbox,
      in: fixture.context
    )

    XCTAssertEqual(summary, SharedWardrobeImportSummary(failedCount: 1))
    XCTAssertEqual(try fixture.context.fetchCount(FetchDescriptor<WardrobeItem>()), 0)
    XCTAssertEqual(try fixture.inbox.pendingItems().count, 1)
    let failedEvent = try XCTUnwrap(
      try fixture.context.fetch(FetchDescriptor<AppEvent>())
        .first(where: { $0.kind == .wardrobeImportFailed })
    )
    XCTAssertEqual(failedEvent.inputSource, .shareExtension)
    XCTAssertEqual(failedEvent.processingVersion, SharedImageInbox.version)
  }

  @MainActor
  private func makeFixture() throws -> Fixture {
    let schema = Schema([WardrobeItem.self, AppEvent.self])
    let container = try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("adonis-shared-import-test-\(UUID().uuidString)", isDirectory: true)
    let inboxDirectory = root.appendingPathComponent("inbox", isDirectory: true)
    let mediaDirectory = root.appendingPathComponent("media", isDirectory: true)
    return try Fixture(
      context: ModelContext(container),
      inbox: SharedImageInbox(baseURL: inboxDirectory),
      store: MediaStore(baseURL: mediaDirectory),
      root: root,
      inboxDirectory: inboxDirectory,
      mediaDirectory: mediaDirectory
    )
  }
}

private struct Fixture {
  let context: ModelContext
  let inbox: SharedImageInbox
  let store: MediaStore
  let root: URL
  let inboxDirectory: URL
  let mediaDirectory: URL

  func cleanup() {
    try? FileManager.default.removeItem(at: root)
  }
}
