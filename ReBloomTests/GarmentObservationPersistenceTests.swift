import SwiftData
import XCTest

@testable import Adonis

final class GarmentObservationPersistenceTests: XCTestCase {
  @MainActor
  func testObservationStateAndRejectionsPersist() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let record = makeRecord()
    let observation = makeObservation()
    let rejectedID = UUID()

    record.garmentObservations.append(observation)
    context.insert(record)
    try context.save()

    observation.matchedWardrobeItemID = rejectedID
    observation.rejectWardrobeItem(id: rejectedID)
    observation.state = .linkedExisting
    try context.save()

    let verificationContext = ModelContext(container)
    let stored = try XCTUnwrap(
      try verificationContext.fetch(FetchDescriptor<GarmentObservation>()).first
    )
    XCTAssertEqual(stored.state, .linkedExisting)
    XCTAssertEqual(stored.matchedWardrobeItemID, rejectedID)
    XCTAssertTrue(stored.rejectedWardrobeItemIDs.contains(rejectedID))
    XCTAssertEqual(stored.outfit?.id, record.id)
  }

  @MainActor
  func testDeletingOutfitCascadesToObservations() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let record = makeRecord()

    record.garmentObservations.append(makeObservation())
    context.insert(record)
    try context.save()
    XCTAssertEqual(try context.fetchCount(FetchDescriptor<GarmentObservation>()), 1)

    context.delete(record)
    try context.save()

    let verificationContext = ModelContext(container)
    XCTAssertEqual(
      try verificationContext.fetchCount(FetchDescriptor<GarmentObservation>()),
      0
    )
  }

  @MainActor
  private func makeContainer() throws -> ModelContainer {
    let schema = Schema([OutfitRecord.self, GarmentObservation.self])
    return try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
  }

  private func makeRecord() -> OutfitRecord {
    OutfitRecord(
      sourceImageFilename: "source.jpg",
      stickerImageFilename: "sticker.png",
      cardImageFilename: "card.png",
      bloomNumber: 1
    )
  }

  private func makeObservation() -> GarmentObservation {
    GarmentObservation(
      slot: .upperBody,
      dominantColorName: "棕色",
      dominantColorHex: "#69422B",
      confidence: 0.72,
      previewImageFilename: "upper.png"
    )
  }
}
