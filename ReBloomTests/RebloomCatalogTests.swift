import XCTest

@testable import Adonis

@MainActor
final class RebloomCatalogTests: XCTestCase {
  func testContractIsEmptyWithoutTwoConfirmedComplementaryItems() {
    XCTAssertEqual(AdonisProcessingVersion.rebloomSuggestion, "rebloom-suggestion-v1")
    XCTAssertEqual(AppEventKind.rebloomOpened.title, "打开再次盛开")
    XCTAssertEqual(AppEventKind.rebloomShareOpened.title, "打开再次盛开分享")
    XCTAssertTrue(
      RebloomCatalog().suggestions(records: [], wardrobeItems: [], now: date(2026, 8, 30))
        .isEmpty
    )

    let top = item(name: "待确认上装", category: .top)
    let record = outfit(
      date: date(2026, 8, 20),
      observations: [observation(slot: .upperBody, state: .pending, itemID: top.id)]
    )
    XCTAssertTrue(
      RebloomCatalog().suggestions(
        records: [record],
        wardrobeItems: [top],
        now: date(2026, 8, 30)
      ).isEmpty
    )
  }

  func testBuildsNovelTopAndBottomPairFromSeparateConfirmedOutfits() throws {
    let top = item(name: "白色短袖", category: .top)
    let bottom = item(name: "蓝色长裙", category: .bottom)
    let oldOutfit = outfit(
      date: date(2026, 7, 1),
      observations: [
        observation(slot: .upperBody, state: .linkedExisting, itemID: top.id)
      ]
    )
    let recentOutfit = outfit(
      date: date(2026, 8, 28),
      observations: [
        observation(slot: .lowerBody, state: .createdNew, itemID: bottom.id)
      ]
    )

    let suggestion = try XCTUnwrap(
      RebloomCatalog().suggestions(
        records: [recentOutfit, oldOutfit],
        wardrobeItems: [bottom, top],
        now: date(2026, 8, 30),
        calendar: calendar
      ).first
    )

    XCTAssertEqual(suggestion.top.item.id, top.id)
    XCTAssertEqual(suggestion.bottom.item.id, bottom.id)
    XCTAssertEqual(suggestion.returningItem.id, top.id)
    XCTAssertEqual(suggestion.familiarItem.id, bottom.id)
    XCTAssertEqual(suggestion.reason, .longUnworn(dayCount: 60))
    XCTAssertEqual(suggestion.sourceRecordIDs, [oldOutfit.id, recentOutfit.id])
    XCTAssertTrue(suggestion.isNovelCombination)
  }

  func testNeverSuggestsItemsAlreadyConfirmedInTheSameOutfit() throws {
    let top = item(name: "针织上装", category: .top)
    let alreadyPairedBottom = item(name: "黑色长裤", category: .bottom)
    let newBottom = item(name: "米色半裙", category: .bottom)
    let sharedOutfit = outfit(
      date: date(2026, 7, 10),
      observations: [
        observation(slot: .upperBody, state: .linkedExisting, itemID: top.id),
        observation(slot: .lowerBody, state: .linkedExisting, itemID: alreadyPairedBottom.id),
      ]
    )
    let separateOutfit = outfit(
      date: date(2026, 8, 20),
      observations: [
        observation(slot: .lowerBody, state: .linkedExisting, itemID: newBottom.id)
      ]
    )

    let suggestions = RebloomCatalog().suggestions(
      records: [sharedOutfit, separateOutfit],
      wardrobeItems: [top, alreadyPairedBottom, newBottom],
      now: date(2026, 8, 30),
      calendar: calendar
    )

    XCTAssertEqual(suggestions.count, 1)
    XCTAssertEqual(try XCTUnwrap(suggestions.first).bottom.item.id, newBottom.id)
  }

  func testPrioritizesLeastRecentlyWornItemAndThenMostRecentFamiliarBase() throws {
    let oldestTop = item(name: "旧白衬衫", category: .top, createdAt: date(2025, 1, 1))
    let newerTop = item(name: "灰色上装", category: .top, createdAt: date(2026, 1, 1))
    let recentBottom = item(name: "常穿牛仔裤", category: .bottom)
    let olderBottom = item(name: "棕色长裤", category: .bottom)
    let records = [
      outfit(
        date: date(2026, 2, 1),
        observations: [
          observation(slot: .upperBody, state: .linkedExisting, itemID: oldestTop.id)
        ]
      ),
      outfit(
        date: date(2026, 6, 1),
        observations: [
          observation(slot: .upperBody, state: .linkedExisting, itemID: newerTop.id)
        ]
      ),
      outfit(
        date: date(2026, 8, 29),
        observations: [
          observation(slot: .lowerBody, state: .linkedExisting, itemID: recentBottom.id)
        ]
      ),
      outfit(
        date: date(2026, 7, 1),
        observations: [
          observation(slot: .lowerBody, state: .linkedExisting, itemID: olderBottom.id)
        ]
      ),
    ]

    let suggestions = RebloomCatalog().suggestions(
      records: records,
      wardrobeItems: [newerTop, olderBottom, oldestTop, recentBottom],
      now: date(2026, 8, 30),
      calendar: calendar
    )

    XCTAssertEqual(try XCTUnwrap(suggestions.first).returningItem.id, oldestTop.id)
    XCTAssertEqual(try XCTUnwrap(suggestions.first).familiarItem.id, recentBottom.id)
    XCTAssertEqual(
      suggestions.map(\.id),
      RebloomCatalog().suggestions(
        records: Array(records.reversed()),
        wardrobeItems: [recentBottom, oldestTop, olderBottom, newerTop],
        now: date(2026, 8, 30),
        calendar: calendar
      ).map(\.id)
    )
  }

  func testRecentHistoryUsesRemixReasonWithoutPretendingItemWasLongUnworn() throws {
    let top = item(name: "红色上装", category: .top)
    let bottom = item(name: "白色下装", category: .bottom)
    let records = [
      outfit(
        date: date(2026, 8, 25),
        observations: [
          observation(slot: .upperBody, state: .linkedExisting, itemID: top.id)
        ]
      ),
      outfit(
        date: date(2026, 8, 29),
        observations: [
          observation(slot: .lowerBody, state: .linkedExisting, itemID: bottom.id)
        ]
      ),
    ]

    let suggestion = try XCTUnwrap(
      RebloomCatalog().suggestions(
        records: records,
        wardrobeItems: [top, bottom],
        now: date(2026, 8, 30),
        calendar: calendar
      ).first
    )

    XCTAssertEqual(suggestion.reason, .pastOutfitRemix)
    XCTAssertFalse(suggestion.reasonTitle.contains("很久"))
  }

  func testUncorrectedOOTDColorNameIsNotRepeatedAsFact() throws {
    let top = WardrobeItem(
      name: "白色上装",
      category: .top,
      imageFilename: "top.png",
      sourceKind: .outfitObservation,
      dominantColorName: "白色"
    )
    let bottom = WardrobeItem(
      name: "蓝色长裙",
      category: .bottom,
      imageFilename: "bottom.png",
      sourceKind: .catalogImage,
      dominantColorName: "蓝色"
    )
    let records = [
      outfit(
        date: date(2026, 8, 20),
        observations: [
          observation(slot: .upperBody, state: .createdNew, itemID: top.id)
        ]
      ),
      outfit(
        date: date(2026, 8, 21),
        observations: [
          observation(slot: .lowerBody, state: .linkedExisting, itemID: bottom.id)
        ]
      ),
    ]

    let provisional = try XCTUnwrap(
      RebloomCatalog().suggestions(
        records: records,
        wardrobeItems: [top, bottom],
        now: date(2026, 8, 30),
        calendar: calendar
      ).first
    )
    XCTAssertEqual(provisional.title, "这件上装 × 蓝色长裙")

    top.name = "旅行白 T"
    let corrected = try XCTUnwrap(
      RebloomCatalog().suggestions(
        records: records,
        wardrobeItems: [top, bottom],
        now: date(2026, 8, 30),
        calendar: calendar
      ).first
    )
    XCTAssertEqual(corrected.title, "旅行白 T × 蓝色长裙")
  }

  func testMissingItemOrSourceRecordImmediatelyRemovesSuggestion() {
    let top = item(name: "白色上装", category: .top)
    let bottom = item(name: "黑色下装", category: .bottom)
    let topRecord = outfit(
      date: date(2026, 7, 1),
      observations: [
        observation(slot: .upperBody, state: .linkedExisting, itemID: top.id)
      ]
    )
    let bottomRecord = outfit(
      date: date(2026, 8, 1),
      observations: [
        observation(slot: .lowerBody, state: .linkedExisting, itemID: bottom.id)
      ]
    )
    let catalog = RebloomCatalog()

    XCTAssertEqual(
      catalog.suggestions(
        records: [topRecord, bottomRecord],
        wardrobeItems: [top, bottom],
        now: date(2026, 8, 30),
        calendar: calendar
      ).count,
      1
    )
    XCTAssertTrue(
      catalog.suggestions(
        records: [topRecord, bottomRecord],
        wardrobeItems: [top],
        now: date(2026, 8, 30),
        calendar: calendar
      ).isEmpty
    )
    XCTAssertTrue(
      catalog.suggestions(
        records: [topRecord],
        wardrobeItems: [top, bottom],
        now: date(2026, 8, 30),
        calendar: calendar
      ).isEmpty
    )
  }

  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
  }

  private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day))!
  }

  private func item(
    name: String,
    category: WardrobeCategory,
    createdAt: Date = Date(timeIntervalSince1970: 0)
  ) -> WardrobeItem {
    WardrobeItem(
      createdAt: createdAt,
      name: name,
      category: category,
      imageFilename: "\(UUID().uuidString).png"
    )
  }

  private func outfit(
    date: Date,
    observations: [GarmentObservation]
  ) -> OutfitRecord {
    OutfitRecord(
      createdAt: date,
      sourceImageFilename: "source.png",
      stickerImageFilename: "sticker.png",
      cardImageFilename: "card.png",
      bloomNumber: 1,
      garmentObservations: observations
    )
  }

  private func observation(
    slot: GarmentObservationSlot,
    state: GarmentObservationState,
    itemID: UUID?
  ) -> GarmentObservation {
    GarmentObservation(
      slot: slot,
      confidence: 0.8,
      previewImageFilename: "preview.png",
      state: state,
      matchedWardrobeItemID: itemID
    )
  }
}
