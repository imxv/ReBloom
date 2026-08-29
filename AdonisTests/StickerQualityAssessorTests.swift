import SwiftData
import UIKit
import XCTest

@testable import Adonis

final class StickerQualityAssessorTests: XCTestCase {
  func testAuthorizedSamplesHaveExpectedStructuralQualityLevels() throws {
    let expected: [String: StickerQualityLevel] = [
      "sample-01": .acceptable,
      "sample-02": .acceptable,
      "sample-03": .acceptable,
      "sample-04": .reviewRecommended,
    ]

    for sample in SampleCatalog.photos {
      let sticker = try XCTUnwrap(sample.preparedStickerImage())
      let assessment = StickerQualityAssessor.assessSynchronously(
        sticker: sticker,
        foregroundCoverage: 0
      )
      XCTAssertEqual(assessment.level, expected[sample.id], sample.id)

      if sample.id == "sample-04" {
        XCTAssertTrue(assessment.issues.contains(.edgeMayIncludeBackground))
      }
    }
  }

  func testOpaqueBackgroundIsRejectedInsteadOfBecomingACard() {
    let format = UIGraphicsImageRendererFormat()
    format.opaque = true
    let image = UIGraphicsImageRenderer(
      size: CGSize(width: 256, height: 256),
      format: format
    ).image { context in
      UIColor.systemBlue.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
    }

    let assessment = StickerQualityAssessor.assessSynchronously(
      sticker: image,
      foregroundCoverage: 0.5
    )

    XCTAssertEqual(assessment.level, .rejected)
    XCTAssertTrue(assessment.issues.contains(.backgroundNotSeparated))
  }

  func testNearlyEmptyStickerIsRejectedAsMissingSubject() {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256)).image { context in
      UIColor.black.setFill()
      context.fill(CGRect(x: 126, y: 126, width: 4, height: 4))
    }

    let assessment = StickerQualityAssessor.assessSynchronously(
      sticker: image,
      foregroundCoverage: 0.001
    )

    XCTAssertEqual(assessment.level, .rejected)
    XCTAssertTrue(assessment.issues.contains(.subjectMissing))
  }

  func testAssessmentRoundTripsWithoutShowingScoresToUser() {
    let assessment = StickerQualityAssessment(
      level: .reviewRecommended,
      issues: [.edgeMayIncludeBackground, .outlineMayBeBroken, .edgeMayIncludeBackground]
    )
    let restored = StickerQualityAssessment(
      levelRawValue: assessment.level.rawValue,
      issueRawValues: assessment.issueRawValues
    )

    XCTAssertEqual(restored, assessment)
    XCTAssertEqual(restored.issues.count, 2)
    XCTAssertNil(
      (restored.userTitle + restored.userDetail).rangeOfCharacter(
        from: CharacterSet(charactersIn: "0123456789%")
      )
    )
    XCTAssertTrue(restored.userDetail.contains("再做一张"))
  }

  @MainActor
  func testReviewStatePersistsWithOutfitRecord() throws {
    let schema = Schema([OutfitRecord.self, GarmentObservation.self])
    let container = try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let assessment = StickerQualityAssessment(
      level: .reviewRecommended,
      issues: [.edgeMayIncludeBackground]
    )
    context.insert(
      OutfitRecord(
        sourceImageFilename: "source.png",
        stickerImageFilename: "sticker.png",
        cardImageFilename: "card.png",
        bloomNumber: 1,
        stickerQualityAssessment: assessment
      )
    )
    try context.save()

    let stored = try XCTUnwrap(
      try ModelContext(container).fetch(FetchDescriptor<OutfitRecord>()).first
    )
    XCTAssertEqual(stored.stickerQualityAssessment, assessment)
    XCTAssertEqual(stored.stickerQualityVersion, StickerQualityAssessor.version)
  }
}
