import XCTest

@testable import Adonis

@MainActor
final class DigitalCabinetCatalogTests: XCTestCase {
  func testCatalogIsEmptyWithoutSavedOutfits() {
    XCTAssertEqual(AdonisProcessingVersion.digitalCabinet, "digital-cabinet-v1")
    XCTAssertEqual(AppEventKind.digitalCabinetOpened.title, "打开数字展柜")
    XCTAssertTrue(
      DigitalCabinetCatalog().entries(records: [], wardrobeItems: []).isEmpty
    )
  }

  func testCatalogSortsNewestFirstAndBreaksDateTiesByBloomNumber() {
    let older = record(date: Date(timeIntervalSince1970: 100), bloomNumber: 2)
    let newerLowerBloom = record(date: Date(timeIntervalSince1970: 200), bloomNumber: 4)
    let newerHigherBloom = record(date: Date(timeIntervalSince1970: 200), bloomNumber: 7)

    let entries = DigitalCabinetCatalog().entries(
      records: [newerLowerBloom, older, newerHigherBloom],
      wardrobeItems: []
    )

    XCTAssertEqual(
      entries.map(\.id),
      [newerHigherBloom.id, newerLowerBloom.id, older.id]
    )
  }

  func testCatalogResolvesOnlyExplicitWardrobeLinksAndKeepsBodyOrder() throws {
    let top = wardrobeItem(name: "白色上装", category: .top)
    let bottom = wardrobeItem(name: "黑色下装", category: .bottom)
    let ignored = wardrobeItem(name: "不应出现", category: .accessory)
    let observations = [
      observation(slot: .lowerBody, state: .linkedExisting, matchedItemID: bottom.id),
      observation(slot: .upperBody, state: .createdNew, matchedItemID: top.id),
      observation(slot: .upperBody, state: .pending, matchedItemID: ignored.id),
    ]

    let entry = try XCTUnwrap(
      DigitalCabinetCatalog().entries(
        records: [record(observations: observations)],
        wardrobeItems: [ignored, bottom, top]
      ).first
    )

    XCTAssertEqual(entry.linkedGarments.map(\.name), ["白色上装", "黑色下装"])
    XCTAssertEqual(entry.linkedGarments.map(\.slot), [.upperBody, .lowerBody])
    XCTAssertEqual(entry.pendingGarmentCount, 1)
    XCTAssertEqual(entry.missingLinkedGarmentCount, 0)
    XCTAssertEqual(
      entry.relationshipSummary,
      "已确认 · 白色上装、黑色下装 · 还有 1 件待确认"
    )
  }

  func testCatalogDoesNotInventDeletedOrUnconfirmedWardrobeRelationships() throws {
    let missingID = UUID()
    let observations = [
      observation(slot: .upperBody, state: .linkedExisting, matchedItemID: missingID),
      observation(slot: .lowerBody, state: .dismissed),
    ]

    let entry = try XCTUnwrap(
      DigitalCabinetCatalog().entries(
        records: [record(observations: observations)],
        wardrobeItems: []
      ).first
    )

    XCTAssertTrue(entry.linkedGarments.isEmpty)
    XCTAssertEqual(entry.pendingGarmentCount, 0)
    XCTAssertEqual(entry.missingLinkedGarmentCount, 1)
    XCTAssertEqual(entry.relationshipSummary, "关联衣物已从衣橱移除")
  }

  func testCatalogDeduplicatesRepeatedLinksToTheSameWardrobeItem() throws {
    let item = wardrobeItem(name: "灰色套装", category: .dress)
    let observations = [
      observation(slot: .upperBody, state: .linkedExisting, matchedItemID: item.id),
      observation(slot: .lowerBody, state: .linkedExisting, matchedItemID: item.id),
    ]

    let entry = try XCTUnwrap(
      DigitalCabinetCatalog().entries(
        records: [record(observations: observations)],
        wardrobeItems: [item]
      ).first
    )

    XCTAssertEqual(entry.linkedGarments.map(\.name), ["灰色套装"])
    XCTAssertEqual(entry.relationshipSummary, "已确认 · 灰色套装")
  }

  func testCatalogKeepsPendingAndNoClueStatesHonest() throws {
    let pending = try XCTUnwrap(
      DigitalCabinetCatalog().entries(
        records: [
          record(observations: [observation(slot: .upperBody, state: .pending)])
        ],
        wardrobeItems: []
      ).first
    )
    let noClue = try XCTUnwrap(
      DigitalCabinetCatalog().entries(records: [record()], wardrobeItems: []).first
    )

    XCTAssertEqual(pending.relationshipSummary, "1 件衣物待你确认")
    XCTAssertEqual(noClue.relationshipSummary, "这天还没有衣物线索")
  }

  private func record(
    date: Date = Date(timeIntervalSince1970: 100),
    bloomNumber: Int = 1,
    observations: [GarmentObservation] = []
  ) -> OutfitRecord {
    OutfitRecord(
      createdAt: date,
      sourceImageFilename: "source.png",
      stickerImageFilename: "sticker.png",
      cardImageFilename: "card.png",
      bloomNumber: bloomNumber,
      garmentObservations: observations
    )
  }

  private func wardrobeItem(
    name: String,
    category: WardrobeCategory
  ) -> WardrobeItem {
    WardrobeItem(
      name: name,
      category: category,
      imageFilename: "\(UUID().uuidString).png"
    )
  }

  private func observation(
    slot: GarmentObservationSlot,
    state: GarmentObservationState,
    matchedItemID: UUID? = nil
  ) -> GarmentObservation {
    GarmentObservation(
      slot: slot,
      confidence: 0.8,
      previewImageFilename: "\(UUID().uuidString).png",
      state: state,
      matchedWardrobeItemID: matchedItemID
    )
  }
}
