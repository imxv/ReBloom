import XCTest

@testable import Adonis

final class StickerFidelityReviewTests: XCTestCase {
  func testReviewOnlyAppearsForAIGeneratedPixelsWithAnOpaqueAISource() {
    XCTAssertTrue(
      StickerFidelityReview.canReview(
        stickerProvenance: .aiGenerated,
        hasAIStickerSource: true
      ))
    XCTAssertFalse(
      StickerFidelityReview.canReview(
        stickerProvenance: .aiGenerated,
        hasAIStickerSource: false
      ))
    XCTAssertFalse(
      StickerFidelityReview.canReview(
        stickerProvenance: .derivedFromOriginal,
        hasAIStickerSource: true
      ))
  }

  @MainActor
  func testChangedReviewRoundTripsThroughOutfitAndKeepsStableUniqueIssues() {
    let reviewedAt = Date(timeIntervalSince1970: 1_700_100_000)
    let review = StickerFidelityReview(
      verdict: .changed,
      issues: [.clothing, .face, .clothing, .pose],
      reviewedAt: reviewedAt
    )

    let record = OutfitRecord(
      sourceImageFilename: "source.png",
      aiStickerSourceImageFilename: "ai-source.png",
      stickerImageFilename: "sticker.png",
      cardImageFilename: "card.png",
      bloomNumber: 12,
      stickerProvenance: .aiGenerated,
      stickerFidelityReview: review
    )

    XCTAssertEqual(record.stickerFidelityReview?.verdict, .changed)
    XCTAssertEqual(record.stickerFidelityReview?.issues, [.face, .pose, .clothing])
    XCTAssertEqual(record.stickerFidelityReview?.reviewedAt, reviewedAt)
    XCTAssertEqual(record.stickerFidelityReviewVersion, StickerFidelityReview.version)
  }
}
