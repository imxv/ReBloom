import XCTest

@testable import Adonis

final class CreationImageIntentRouterTests: XCTestCase {
  func testHighConfidenceCatalogGarmentRoutesDirectlyToWardrobe() {
    let analysis = makeAnalysis(
      sourceKind: .catalogImage,
      category: .top,
      confidence: 0.91,
      cleanBackgroundScore: 0.92
    )

    let route = CreationImageIntentRouter().route(analysis)

    XCTAssertEqual(route, .wardrobe)
  }

  func testCleanCatalogWithoutCategoryKeepsCreationAndOffersWardrobeOnlyAfterFailure() {
    let analysis = makeAnalysis(
      sourceKind: .catalogImage,
      category: nil,
      confidence: nil,
      cleanBackgroundScore: 0.9
    )

    let route = CreationImageIntentRouter().route(analysis)

    XCTAssertEqual(route, .creation(offersWardrobeFallback: true))
  }

  func testUncategorizedSuggestionNeverRoutesDirectlyToWardrobe() {
    let analysis = makeAnalysis(
      sourceKind: .catalogImage,
      category: .uncategorized,
      confidence: 0.95,
      cleanBackgroundScore: 0.94
    )

    let route = CreationImageIntentRouter().route(analysis)

    XCTAssertEqual(route, .creation(offersWardrobeFallback: true))
  }

  func testLowConfidenceCatalogGarmentRequiresConfirmationAfterCreationFailure() {
    let analysis = makeAnalysis(
      sourceKind: .catalogImage,
      category: .top,
      confidence: 0.71,
      cleanBackgroundScore: 0.94
    )

    let route = CreationImageIntentRouter().route(analysis)

    XCTAssertEqual(route, .creation(offersWardrobeFallback: true))
  }

  func testFlatLayPhotoContinuesCreationWithoutWardrobeInterruption() {
    let analysis = makeAnalysis(
      sourceKind: .flatLay,
      category: .top,
      confidence: 0.95,
      cleanBackgroundScore: 0.94
    )

    let route = CreationImageIntentRouter().route(analysis)

    XCTAssertEqual(route, .creation(offersWardrobeFallback: false))
  }

  func testIntentRouterKeepsAStableTraceVersion() {
    XCTAssertEqual(CreationImageIntentRouter.version, "creation-image-intent-v1")
  }

  private func makeAnalysis(
    sourceKind: WardrobeSourceKind,
    category: WardrobeCategory?,
    confidence: Double?,
    cleanBackgroundScore: Double
  ) -> WardrobeImageAnalysis {
    WardrobeImageAnalysis(
      sourceKind: sourceKind,
      dominantColorName: "棕色",
      dominantColorHex: "#704020",
      suggestedCategory: category,
      categoryConfidence: confidence,
      cleanBackgroundScore: cleanBackgroundScore,
      imageWidth: 900,
      imageHeight: 1200,
      imageFingerprint: String(repeating: "a", count: 64),
      visualSignatureRawValue: "fixture",
      processingMilliseconds: 8,
      analysisVersion: AdonisProcessingVersion.wardrobeAnalysis
    )
  }
}
