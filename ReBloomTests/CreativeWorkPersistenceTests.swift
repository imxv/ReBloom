import SwiftData
import UIKit
import XCTest

@testable import Adonis

final class CreativeWorkPersistenceTests: XCTestCase {
  @MainActor
  func testSavedWorkKeepsRecipeProvenanceSourceAndPerformanceAfterRefetch() throws {
    let schema = Schema([OutfitRecord.self, GarmentObservation.self, CreativeWork.self])
    let container = try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let outfit = OutfitRecord(
      sourceImageFilename: "source.png",
      stickerImageFilename: "sticker.png",
      cardImageFilename: "card.png",
      bloomNumber: 9
    )
    let work = CreativeWork(
      createdAt: Date(timeIntervalSince1970: 123),
      recipe: .mythicGarden,
      imageFilename: "botanical.png",
      processingMilliseconds: 87,
      executionMetadata: .appleImagePlayground,
      sourceOutfit: outfit
    )
    context.insert(outfit)
    context.insert(work)
    outfit.creativeWorks.append(work)
    try context.save()

    let stored = try XCTUnwrap(
      try ModelContext(container).fetch(FetchDescriptor<CreativeWork>()).first
    )
    XCTAssertEqual(stored.recipe, .mythicGarden)
    XCTAssertEqual(stored.recipeVersion, "mythic-garden-v1")
    XCTAssertEqual(stored.provenance, .aiGenerated)
    XCTAssertTrue(stored.containsAIGeneratedPixels)
    XCTAssertEqual(stored.processingMilliseconds, 87)
    XCTAssertEqual(stored.executionMetadata, .appleImagePlayground)
    XCTAssertEqual(stored.sourceOutfit?.id, outfit.id)
  }

  @MainActor
  func testStoreSavesPNGAndLinksWorkToExistingOutfit() throws {
    let schema = Schema([OutfitRecord.self, GarmentObservation.self, CreativeWork.self])
    let container = try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let outfit = OutfitRecord(
      sourceImageFilename: "source.png",
      stickerImageFilename: "sticker.png",
      cardImageFilename: "card.png",
      bloomNumber: 11
    )
    context.insert(outfit)
    try context.save()

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "adonis-creative-work-\(UUID().uuidString)",
      isDirectory: true
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    let mediaStore = MediaStore(baseURL: directory)
    let draft = CreativeWorkDraft(
      id: UUID(uuidString: "CCDB8F50-5DB5-4C31-A4E1-C233536AB664")!,
      createdAt: Date(timeIntervalSince1970: 456),
      recipe: .botanicalPoster,
      image: solidImage(),
      processingMilliseconds: 31,
      executionMetadata: .botanicalPoster
    )

    let store = CreativeWorkStore(mediaStore: mediaStore)
    let stored = try store.save(
      draft,
      for: outfit,
      in: context
    )
    let repeatedSave = try store.save(
      draft,
      for: outfit,
      in: context
    )

    XCTAssertEqual(stored.id, draft.id)
    XCTAssertEqual(repeatedSave.id, stored.id)
    XCTAssertEqual(outfit.creativeWorks.map(\.id), [draft.id])
    XCTAssertNotNil(mediaStore.image(filename: stored.imageFilename))
    XCTAssertEqual(try mediaStore.storedFileURLs().count, 1)
    XCTAssertEqual(
      try ModelContext(container).fetchCount(FetchDescriptor<CreativeWork>()),
      1
    )
  }

  @MainActor
  func testStorePersistsInheritedAIProvenanceForLocalDerivative() throws {
    let schema = Schema([OutfitRecord.self, GarmentObservation.self, CreativeWork.self])
    let container = try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let outfit = OutfitRecord(
      sourceImageFilename: "source.png",
      aiStickerSourceImageFilename: "ai-source.png",
      stickerImageFilename: "sticker.png",
      cardImageFilename: "card.png",
      bloomNumber: 11,
      stickerProvenance: .aiGenerated,
      stickerExecutionMetadata: .appleImagePlayground
    )
    context.insert(outfit)
    try context.save()

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "adonis-ai-creative-work-\(UUID().uuidString)",
      isDirectory: true
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    let draft = CreativeWorkDraft(
      recipe: .botanicalPoster,
      image: solidImage(),
      processingMilliseconds: 31,
      executionMetadata: .botanicalPoster,
      provenance: BotanicalPosterRenderer.provenance(for: outfit.stickerProvenance)
    )

    let stored = try CreativeWorkStore(mediaStore: MediaStore(baseURL: directory)).save(
      draft,
      for: outfit,
      in: context
    )

    XCTAssertEqual(stored.provenance, .aiGenerated)
    XCTAssertTrue(stored.containsAIGeneratedPixels)
    XCTAssertEqual(stored.executionMetadata, .botanicalPoster)
  }

  @MainActor
  func testDeletingSourceOutfitCascadesSavedCreativeWork() throws {
    let schema = Schema([OutfitRecord.self, GarmentObservation.self, CreativeWork.self])
    let container = try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let outfit = OutfitRecord(
      sourceImageFilename: "source.png",
      stickerImageFilename: "sticker.png",
      cardImageFilename: "card.png",
      bloomNumber: 12
    )
    let work = CreativeWork(
      recipe: .botanicalPoster,
      imageFilename: "botanical.png",
      processingMilliseconds: 22,
      executionMetadata: .botanicalPoster,
      sourceOutfit: outfit
    )
    context.insert(outfit)
    context.insert(work)
    outfit.creativeWorks.append(work)
    try context.save()

    context.delete(outfit)
    try context.save()

    let verificationContext = ModelContext(container)
    XCTAssertEqual(
      try verificationContext.fetchCount(FetchDescriptor<CreativeWork>()),
      0
    )
  }

  private func solidImage() -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { context in
      UIColor.systemPink.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
    }
  }
}
