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

  func testVisualEvidenceRanksPatternMatchAheadOfSameColorDistractor() throws {
    let observation = makeObservation(category: .top, colorHex: "#704020")
    observation.visualSignatureRawValue = try makeSignature(
      color: [0.62, 0.25, 0.13],
      texture: [0.45, 0.05, 0.45, 0.05]
    ).encoded()
    let patternMatch = makeItem(name: "格纹上装", category: .top, colorHex: "#704020")
    patternMatch.visualSignatureRawValue = try makeSignature(
      color: [0.6, 0.27, 0.13],
      texture: [0.43, 0.07, 0.44, 0.06]
    ).encoded()
    let plainDistractor = makeItem(name: "纯色上装", category: .top, colorHex: "#704020")
    plainDistractor.visualSignatureRawValue = try makeSignature(
      color: [0.92, 0.05, 0.03],
      texture: [0.05, 0.05, 0.05, 0.85]
    ).encoded()

    let results = WardrobeCandidateMatcher().candidates(
      for: observation,
      among: [plainDistractor, patternMatch]
    )

    XCTAssertEqual(results.first?.item.id, patternMatch.id)
    XCTAssertGreaterThan(
      try XCTUnwrap(results.first?.visualSimilarity),
      try XCTUnwrap(results.last?.visualSimilarity)
    )
    XCTAssertTrue(try XCTUnwrap(results.first).reasonText.contains("画面线索更接近"))
  }

  func testWeakVisualEvidenceIsDescribedAsLimitedInsteadOfSameItemFact() throws {
    let observation = makeObservation(category: .top, colorHex: "#704020")
    observation.visualSignatureRawValue = try makeSignature(
      color: [0.9, 0.08, 0.02],
      texture: [0.85, 0.05, 0.05, 0.05]
    ).encoded()
    let item = makeItem(name: "同色候选", category: .top, colorHex: "#704020")
    item.visualSignatureRawValue = try makeSignature(
      color: [0.05, 0.05, 0.05, 0.85],
      texture: [0.05, 0.05, 0.05, 0.85]
    ).encoded()

    let candidate = try XCTUnwrap(
      WardrobeCandidateMatcher().candidates(for: observation, among: [item]).first
    )

    XCTAssertTrue(candidate.reasonText.contains("画面线索有限"))
    XCTAssertFalse(candidate.reasonText.contains("同一件"))
  }

  func testWeakVisualEvidenceDoesNotRemoveCandidateAcceptedByLegacySignals() throws {
    let observation = makeObservation(category: .top, colorHex: "#704020")
    observation.confidence = 1
    observation.visualSignatureRawValue = try makeSignature(
      color: [1, 0, 0],
      texture: [1, 0, 0, 0]
    ).encoded()
    let item = makeItem(name: "分类待确认", category: .bottom, colorHex: "#704020")
    item.visualSignatureRawValue = try makeSignature(
      color: [0, 0, 0, 1],
      texture: [0, 0, 0, 1]
    ).encoded()

    let candidate = WardrobeCandidateMatcher().candidates(
      for: observation,
      among: [item]
    ).first

    XCTAssertNotNil(candidate)
    XCTAssertTrue(try XCTUnwrap(candidate).reasonText.contains("画面线索有限"))
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

  private func makeSignature(
    color: [Double],
    texture: [Double]
  ) -> GarmentVisualSignature {
    GarmentVisualSignature(
      colorHistogram: color,
      luminanceHistogram: [0.1, 0.2, 0.4, 0.3],
      textureHistogram: texture,
      edgeDensity: 0.34,
      sampleCount: 1_024
    )
  }
}
