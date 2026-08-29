import XCTest

@testable import Adonis

final class WardrobeCandidateMatcherTests: XCTestCase {
  func testExactCategoryAndNearbyColorRanksFirst() throws {
    let observation = makeObservation(category: .top, colorHex: "#704020")
    let matchingTop = makeItem(name: "棕色上装", category: .top, colorHex: "#6E3F22")
    let blueTop = makeItem(name: "蓝色上装", category: .top, colorHex: "#2048B0")
    let brownBottom = makeItem(name: "棕色下装", category: .bottom, colorHex: "#704020")

    let results = WardrobeCandidateMatcher().candidates(
      for: observation,
      among: [blueTop, brownBottom, matchingTop]
    )

    XCTAssertEqual(results.first?.item.id, matchingTop.id)
    XCTAssertTrue(try XCTUnwrap(results.first).reasonText.contains("同为上装"))
    XCTAssertTrue(try XCTUnwrap(results.first).reasonText.contains("颜色很接近"))
    XCTAssertLessThanOrEqual(results.count, 3)
  }

  func testRejectedCandidateDoesNotReturnAgain() {
    let observation = makeObservation(category: .top, colorHex: "#704020")
    let rejected = makeItem(name: "旧候选", category: .top, colorHex: "#704020")
    let remaining = makeItem(name: "另一个候选", category: .top, colorHex: "#744525")
    observation.rejectWardrobeItem(id: rejected.id)

    let results = WardrobeCandidateMatcher().candidates(
      for: observation,
      among: [rejected, remaining]
    )

    XCTAssertFalse(results.contains(where: { $0.item.id == rejected.id }))
    XCTAssertEqual(results.first?.item.id, remaining.id)
  }

  func testUnrelatedCategoryAndColorAreNotPresented() {
    let observation = makeObservation(category: .top, colorHex: "#6F3E20")
    let unrelated = makeItem(name: "蓝色鞋", category: .shoes, colorHex: "#2040C0")

    let results = WardrobeCandidateMatcher().candidates(
      for: observation,
      among: [unrelated]
    )

    XCTAssertTrue(results.isEmpty)
  }

  func testCandidateListNeverExceedsRequestedLimit() {
    let observation = makeObservation(category: .top, colorHex: "#704020")
    let items = (0..<6).map { index in
      makeItem(
        name: "棕色上装 \(index)",
        category: .top,
        colorHex: String(format: "#%02X4020", 0x68 + index)
      )
    }

    let results = WardrobeCandidateMatcher().candidates(
      for: observation,
      among: items,
      limit: 3
    )

    XCTAssertEqual(results.count, 3)
  }

  private func makeObservation(
    category: WardrobeCategory,
    colorHex: String
  ) -> GarmentObservation {
    GarmentObservation(
      slot: .upperBody,
      suggestedCategory: category,
      dominantColorName: "棕色",
      dominantColorHex: colorHex,
      confidence: 0.68,
      previewImageFilename: "observation.png"
    )
  }

  private func makeItem(
    name: String,
    category: WardrobeCategory,
    colorHex: String
  ) -> WardrobeItem {
    WardrobeItem(
      name: name,
      category: category,
      imageFilename: "\(UUID().uuidString).png",
      sourceKind: .catalogImage,
      dominantColorName: "棕色",
      dominantColorHex: colorHex
    )
  }
}
