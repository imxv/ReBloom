import SwiftData
import XCTest

@testable import Adonis

final class WardrobeHistoryMatcherTests: XCTestCase {
  func testHistoryCandidatesOnlyIncludePendingUnrejectedObservationsAndRespectLimit() {
    let item = makeItem()
    let newest = makeObservation(daysAgo: 1)
    let older = makeObservation(daysAgo: 4)
    let third = makeObservation(daysAgo: 8)
    let fourth = makeObservation(daysAgo: 12)
    let dismissed = makeObservation(daysAgo: 2, state: .dismissed)
    let linked = makeObservation(daysAgo: 3, state: .linkedExisting, matchedItemID: UUID())
    let rejected = makeObservation(daysAgo: 5)
    rejected.rejectWardrobeItem(id: item.id)

    let results = WardrobeHistoryMatcher().candidates(
      for: item,
      among: [fourth, dismissed, linked, older, rejected, newest, third],
      limit: 3
    )

    XCTAssertEqual(results.map(\.observation.id), [newest.id, older.id, third.id])
    XCTAssertFalse(results.contains(where: { $0.observation.id == dismissed.id }))
    XCTAssertFalse(results.contains(where: { $0.observation.id == linked.id }))
    XCTAssertFalse(results.contains(where: { $0.observation.id == rejected.id }))
  }

  func testHistoryCandidateRejectsUnrelatedCategoryAndColor() {
    let item = makeItem()
    let unrelated = makeObservation(
      daysAgo: 1,
      category: .shoes,
      colorName: "蓝色",
      colorHex: "#2048B0"
    )

    let results = WardrobeHistoryMatcher().candidates(for: item, among: [unrelated])

    XCTAssertTrue(results.isEmpty)
  }

  @MainActor
  func testConfirmAndRejectPersistExplicitHistoryDecision() throws {
    let schema = Schema([OutfitRecord.self, GarmentObservation.self, WardrobeItem.self])
    let container = try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let item = makeItem()
    let observation = makeObservation(daysAgo: 1)
    let outfit = try XCTUnwrap(observation.outfit)
    context.insert(item)
    context.insert(outfit)
    try context.save()

    try WardrobeHistoryLinker.confirm(
      observation: observation,
      as: item,
      in: context
    )

    let verificationContext = ModelContext(container)
    let storedObservation = try XCTUnwrap(
      try verificationContext.fetch(FetchDescriptor<GarmentObservation>()).first
    )
    let storedItem = try XCTUnwrap(
      try verificationContext.fetch(FetchDescriptor<WardrobeItem>()).first
    )
    XCTAssertEqual(storedObservation.state, .linkedExisting)
    XCTAssertEqual(storedObservation.matchedWardrobeItemID, storedItem.id)

    try WardrobeHistoryLinker.reject(
      observation: storedObservation,
      for: storedItem,
      in: verificationContext
    )

    XCTAssertEqual(storedObservation.state, .pending)
    XCTAssertNil(storedObservation.matchedWardrobeItemID)
    XCTAssertTrue(storedObservation.rejectedWardrobeItemIDs.contains(storedItem.id))
  }

  private func makeItem() -> WardrobeItem {
    WardrobeItem(
      name: "棕色上装",
      category: .top,
      imageFilename: "brown-top.png",
      sourceKind: .catalogImage,
      dominantColorName: "棕色",
      dominantColorHex: "#704020"
    )
  }

  private func makeObservation(
    daysAgo: Int,
    state: GarmentObservationState = .pending,
    matchedItemID: UUID? = nil,
    category: WardrobeCategory = .top,
    colorName: String = "棕色",
    colorHex: String = "#704020"
  ) -> GarmentObservation {
    let date = Date(timeIntervalSince1970: 1_780_000_000 - Double(daysAgo * 86_400))
    let outfit = OutfitRecord(
      createdAt: date,
      sourceImageFilename: "source-\(daysAgo).jpg",
      stickerImageFilename: "sticker-\(daysAgo).png",
      cardImageFilename: "card-\(daysAgo).png",
      bloomNumber: daysAgo
    )
    let observation = GarmentObservation(
      createdAt: date,
      slot: .upperBody,
      suggestedCategory: category,
      dominantColorName: colorName,
      dominantColorHex: colorHex,
      confidence: 0.68,
      previewImageFilename: "observation-\(daysAgo).png",
      state: state,
      matchedWardrobeItemID: matchedItemID
    )
    outfit.garmentObservations.append(observation)
    return observation
  }
}
