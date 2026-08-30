import SwiftData
import UIKit
import XCTest

@testable import Adonis

final class StickerQualityAssessorTests: XCTestCase {
  func testShowcaseExcludesKnownRejectedMatteButRegressionCatalogKeepsIt() {
    XCTAssertTrue(SampleCatalog.photos.contains(where: { $0.id == "sample-04" }))
    XCTAssertFalse(SampleCatalog.showcasePhotos.contains(where: { $0.id == "sample-04" }))
    XCTAssertFalse(
      SampleCatalog.showcasePhotos.contains(where: \.preparedMatteAssessment.isRejected)
    )
  }

  func testAuthorizedSamplesHaveExpectedStructuralQualityLevels() throws {
    let expected: [String: StickerQualityLevel] = [
      "sample-01": .acceptable,
      "sample-02": .acceptable,
      "sample-03": .acceptable,
      "sample-04": .rejected,
    ]

    for sample in SampleCatalog.photos {
      let sticker = try XCTUnwrap(sample.preparedStickerImage())
      let assessment = StickerQualityAssessor.assessSynchronously(
        sticker: sticker,
        foregroundCoverage: 0,
        rawMatteAssessment: sample.preparedMatteAssessment
      )
      XCTAssertEqual(assessment.level, expected[sample.id], sample.id)

      if sample.id == "sample-04" {
        XCTAssertTrue(assessment.issues.contains(.backgroundAdhesionSuspected))
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

  func testRawMatteRejectionOverridesDeliveryReadySticker() throws {
    let sticker = try XCTUnwrap(SampleCatalog.photos.first?.preparedStickerImage())
    let rawMatteAssessment = StickerQualityAssessment(
      level: .rejected,
      issues: [.backgroundAdhesionSuspected]
    )

    let assessment = StickerQualityAssessor.assessSynchronously(
      sticker: sticker,
      foregroundCoverage: 0.3,
      rawMatteAssessment: rawMatteAssessment
    )

    XCTAssertEqual(assessment.level, .rejected)
    XCTAssertTrue(assessment.issues.contains(.backgroundAdhesionSuspected))
  }

  func testRawMatteReviewSurvivesAcceptableDeliveryChecks() throws {
    let sticker = try XCTUnwrap(SampleCatalog.photos.first?.preparedStickerImage())
    let rawMatteAssessment = StickerQualityAssessment(
      level: .reviewRecommended,
      issues: [.edgeMayIncludeBackground]
    )

    let assessment = StickerQualityAssessor.assessSynchronously(
      sticker: sticker,
      foregroundCoverage: 0.3,
      rawMatteAssessment: rawMatteAssessment
    )

    XCTAssertEqual(assessment.level, .reviewRecommended)
    XCTAssertTrue(assessment.issues.contains(.edgeMayIncludeBackground))
  }

  func testSourceFidelityRejectionOverridesDeliveryReadySticker() throws {
    let sticker = try XCTUnwrap(SampleCatalog.photos.first?.preparedStickerImage())
    let sourceFidelityAssessment = StickerQualityAssessment(
      level: .rejected,
      issues: [.sourcePixelsChanged]
    )

    let assessment = StickerQualityAssessor.assessSynchronously(
      sticker: sticker,
      foregroundCoverage: 0.3,
      sourceFidelityAssessment: sourceFidelityAssessment
    )

    XCTAssertEqual(assessment.level, .rejected)
    XCTAssertTrue(assessment.issues.contains(.sourcePixelsChanged))
  }

  func testRejectedQualityCopyNeverOffersAnUnavailableStickerPreview() {
    let rejectedIssues: [StickerQualityIssue] = [
      .subjectMissing,
      .subjectFragmented,
      .backgroundNotSeparated,
      .backgroundAdhesionSuspected,
      .sourcePixelsChanged,
    ]

    for issue in rejectedIssues {
      let assessment = StickerQualityAssessment(level: .rejected, issues: [issue])

      XCTAssertTrue(assessment.userDetail.contains("不会继续做成收藏卡"), issue.rawValue)
      XCTAssertTrue(assessment.userDetail.contains("换一张"), issue.rawValue)
      XCTAssertFalse(assessment.userDetail.contains("先看看"), issue.rawValue)
    }
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
