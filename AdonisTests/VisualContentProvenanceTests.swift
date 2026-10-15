import XCTest

@testable import Adonis

final class VisualContentProvenanceTests: XCTestCase {
  func testRawValuesAreStableAndUnique() {
    let rawValues = VisualContentProvenance.allCases.map(\.rawValue)

    XCTAssertEqual(Set(rawValues).count, VisualContentProvenance.allCases.count)
    XCTAssertEqual(VisualContentProvenance.userProvided.rawValue, "user_provided")
    XCTAssertEqual(VisualContentProvenance.derivedFromOriginal.rawValue, "derived_from_original")
    XCTAssertEqual(
      VisualContentProvenance.programmaticComposition.rawValue,
      "programmatic_composition"
    )
    XCTAssertEqual(
      VisualContentProvenance.recognitionSuggestion.rawValue,
      "recognition_suggestion"
    )
    XCTAssertEqual(VisualContentProvenance.aiFilled.rawValue, "ai_filled")
    XCTAssertEqual(VisualContentProvenance.aiGenerated.rawValue, "ai_generated")
  }

  func testCurrentOutfitAssetsMapToTheirActualPixelOrigins() {
    XCTAssertEqual(OutfitVisualAsset.originalPhoto.provenance, .userProvided)
    XCTAssertEqual(OutfitVisualAsset.sticker.provenance, .derivedFromOriginal)
    XCTAssertEqual(OutfitVisualAsset.shareCard.provenance, .programmaticComposition)
  }

  func testOnlyFutureAIPixelKindsAreMarkedAsAIGenerated() {
    let generatedKinds = VisualContentProvenance.allCases.filter(\.containsAIGeneratedPixels)

    XCTAssertEqual(generatedKinds, [.aiFilled, .aiGenerated])
    XCTAssertFalse(OutfitVisualAsset.allCases.contains { $0.provenance.containsAIGeneratedPixels })
  }

  func testOnlyRecognitionSuggestionRequiresConfirmation() {
    let confirmationKinds = VisualContentProvenance.allCases.filter(\.requiresUserConfirmation)

    XCTAssertEqual(confirmationKinds, [.recognitionSuggestion])
  }

  func testUserFacingCopyDoesNotDescribeCurrentDerivedImagesAsAIGenerated() {
    XCTAssertTrue(VisualContentProvenance.derivedFromOriginal.detail.contains("没有被重绘"))
    XCTAssertTrue(VisualContentProvenance.programmaticComposition.detail.contains("没有补画"))
    XCTAssertTrue(VisualContentProvenance.recognitionSuggestion.detail.contains("建议"))
    XCTAssertTrue(VisualContentProvenance.aiFilled.detail.contains("AI"))
    XCTAssertTrue(VisualContentProvenance.aiGenerated.detail.contains("AI"))
    XCTAssertEqual(
      VisualContentProvenance.programmaticComposition.shareCardFooter,
      "人物与衣物来自原图 · 卡面由 REBLOOM 排版"
    )
  }
}
