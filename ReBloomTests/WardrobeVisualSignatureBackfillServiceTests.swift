import SwiftData
import XCTest

@testable import Adonis

final class WardrobeVisualSignatureBackfillServiceTests: XCTestCase {
  @MainActor
  func testBackfillPersistsMissingItemAndObservationSignaturesWithoutChangingDecisions()
    async throws
  {
    let fixture = try makeFixture()
    defer { fixture.cleanup() }
    let item = WardrobeItem(
      name: "格纹上装",
      category: .top,
      imageFilename: "item.png",
      sourceKind: .catalogImage,
      dominantColorName: "棕色",
      dominantColorHex: "#704020"
    )
    let outfit = OutfitRecord(
      sourceImageFilename: "source.png",
      stickerImageFilename: "sticker.png",
      cardImageFilename: "card.png",
      bloomNumber: 1
    )
    let rejectedID = UUID()
    let observation = GarmentObservation(
      slot: .upperBody,
      dominantColorName: "棕色",
      dominantColorHex: "#704020",
      confidence: 0.68,
      previewImageFilename: "observation.png",
      state: .pending,
      rejectedWardrobeItemIDs: [rejectedID],
      outfit: outfit
    )
    outfit.garmentObservations.append(observation)
    fixture.context.insert(item)
    fixture.context.insert(outfit)
    try fixture.store.savePNG(WardrobeTestImageFactory.brownCatalogShirt(), filename: "item.png")
    try fixture.store.savePNG(
      WardrobeTestImageFactory.brownCatalogShirt(), filename: "observation.png")
    try fixture.context.save()

    let summary = try await WardrobeVisualSignatureBackfillService(
      mediaStore: fixture.store
    ).backfill(in: fixture.context)

    XCTAssertEqual(summary.itemCount, 1)
    XCTAssertEqual(summary.observationCount, 1)
    XCTAssertEqual(summary.skippedCount, 0)
    XCTAssertNotNil(item.visualSignatureRawValue.flatMap(GarmentVisualSignature.init(encoded:)))
    XCTAssertNotNil(
      observation.visualSignatureRawValue.flatMap(GarmentVisualSignature.init(encoded:))
    )
    XCTAssertEqual(observation.state, .pending)
    XCTAssertNil(observation.matchedWardrobeItemID)
    XCTAssertEqual(observation.rejectedWardrobeItemIDs, [rejectedID])

    let verificationContext = ModelContext(fixture.container)
    let storedItem = try XCTUnwrap(
      try verificationContext.fetch(FetchDescriptor<WardrobeItem>()).first
    )
    let storedObservation = try XCTUnwrap(
      try verificationContext.fetch(FetchDescriptor<GarmentObservation>()).first
    )
    XCTAssertNotNil(storedItem.visualSignatureRawValue)
    XCTAssertNotNil(storedObservation.visualSignatureRawValue)
  }

  @MainActor
  func testBackfillPreservesValidSignatureAndSkipsMissingMedia() async throws {
    let fixture = try makeFixture()
    defer { fixture.cleanup() }
    let existing = try GarmentVisualSignatureAnalyzer()
      .signature(for: WardrobeTestImageFactory.brownCatalogShirt())
      .encoded()
    let item = WardrobeItem(
      name: "已有指纹",
      category: .top,
      imageFilename: "not-needed.png",
      visualSignatureRawValue: existing
    )
    let outfit = OutfitRecord(
      sourceImageFilename: "source.png",
      stickerImageFilename: "sticker.png",
      cardImageFilename: "card.png",
      bloomNumber: 1
    )
    let missingObservation = GarmentObservation(
      slot: .upperBody,
      confidence: 0.6,
      previewImageFilename: "missing.png",
      outfit: outfit
    )
    outfit.garmentObservations.append(missingObservation)
    fixture.context.insert(item)
    fixture.context.insert(outfit)
    try fixture.context.save()

    let summary = try await WardrobeVisualSignatureBackfillService(
      mediaStore: fixture.store
    ).backfill(in: fixture.context)

    XCTAssertEqual(summary.itemCount, 0)
    XCTAssertEqual(summary.observationCount, 0)
    XCTAssertEqual(summary.skippedCount, 1)
    XCTAssertEqual(item.visualSignatureRawValue, existing)
    XCTAssertNil(missingObservation.visualSignatureRawValue)
  }

  @MainActor
  private func makeFixture() throws -> Fixture {
    let schema = Schema([OutfitRecord.self, GarmentObservation.self, WardrobeItem.self])
    let container = try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("adonis-signature-backfill-\(UUID().uuidString)", isDirectory: true)
    return Fixture(
      container: container,
      context: ModelContext(container),
      store: MediaStore(baseURL: directory),
      directory: directory
    )
  }
}

private struct Fixture {
  let container: ModelContainer
  let context: ModelContext
  let store: MediaStore
  let directory: URL

  func cleanup() {
    try? FileManager.default.removeItem(at: directory)
  }
}
