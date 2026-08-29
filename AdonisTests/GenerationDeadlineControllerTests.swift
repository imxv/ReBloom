import SwiftData
import XCTest

@testable import Adonis

final class GenerationDeadlineControllerTests: XCTestCase {
  @MainActor
  func testDeadlineFiresOnceAfterSleeperCompletes() async {
    let generationID = UUID()
    var expiredGenerationIDs: [UUID] = []
    let controller = GenerationDeadlineController(sleeper: { _ in })

    controller.arm(generationID: generationID) { expiredGenerationID in
      expiredGenerationIDs.append(expiredGenerationID)
    }
    for _ in 0..<3 {
      await Task.yield()
    }

    XCTAssertEqual(expiredGenerationIDs, [generationID])
  }

  func testProductionDeadlineAndTimeoutEventUseStableUserFacingContract() {
    XCTAssertEqual(
      GenerationDeadlineController.productionTimeout,
      .seconds(90)
    )
    XCTAssertEqual(AppEventKind.generationTimedOut.title, "处理超时")
  }

  func testBasicStickerFallbackHasStableDisclosureContract() {
    XCTAssertEqual(
      GenerationCompletionMode.basicStickerFallback.rawValue,
      "basic_sticker_fallback"
    )
    XCTAssertEqual(
      GenerationCompletionMode.basicStickerFallback.resultTitle,
      "先收下这张贴纸"
    )
  }

  @MainActor
  func testBasicStickerFallbackPersistsWithSavedOutfit() throws {
    let schema = Schema([OutfitRecord.self, GarmentObservation.self])
    let container = try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    context.insert(
      OutfitRecord(
        sourceImageFilename: "source.png",
        stickerImageFilename: "sticker.png",
        cardImageFilename: "card.png",
        bloomNumber: 1,
        generationCompletionMode: .basicStickerFallback
      )
    )
    try context.save()

    let stored = try XCTUnwrap(
      try ModelContext(container).fetch(FetchDescriptor<OutfitRecord>()).first
    )
    XCTAssertEqual(stored.generationCompletionMode, .basicStickerFallback)
  }

  @MainActor
  func testRearmingRejectsCancelledStaleDeadline() async {
    let gate = DeadlineSleeperGate()
    let firstID = UUID()
    let secondID = UUID()
    var expiredGenerationIDs: [UUID] = []
    let controller = GenerationDeadlineController(sleeper: { _ in
      await gate.wait()
    })

    controller.arm(generationID: firstID) { expiredGenerationIDs.append($0) }
    await Task.yield()
    controller.arm(generationID: secondID) { expiredGenerationIDs.append($0) }
    await Task.yield()
    await gate.releaseAll()
    for _ in 0..<3 {
      await Task.yield()
    }

    XCTAssertEqual(expiredGenerationIDs, [secondID])
  }
}

private actor DeadlineSleeperGate {
  private var isReleased = false
  private var continuations: [CheckedContinuation<Void, Never>] = []

  func wait() async {
    guard !isReleased else { return }
    await withCheckedContinuation { continuation in
      continuations.append(continuation)
    }
  }

  func releaseAll() {
    isReleased = true
    let waiting = continuations
    continuations.removeAll()
    for continuation in waiting {
      continuation.resume()
    }
  }
}
