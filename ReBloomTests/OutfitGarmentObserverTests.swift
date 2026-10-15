import XCTest

@testable import Adonis

final class OutfitGarmentObserverTests: XCTestCase {
  func testTransparentOutfitCreatesUpperAndLowerProvisionalObservations() async throws {
    let sticker = makeOutfitSticker()

    let observations = await OutfitGarmentObserver().observe(sticker: sticker)

    XCTAssertEqual(observations.count, 2)
    let upper = try XCTUnwrap(observations.first(where: { $0.slot == .upperBody }))
    let lower = try XCTUnwrap(observations.first(where: { $0.slot == .lowerBody }))
    XCTAssertEqual(upper.suggestedCategory, .top)
    XCTAssertEqual(upper.dominantColorName, "棕色")
    XCTAssertEqual(lower.suggestedCategory, .bottom)
    XCTAssertEqual(lower.dominantColorName, "蓝色")
    XCTAssertGreaterThanOrEqual(upper.confidence, 0.28)
    XCTAssertLessThanOrEqual(upper.confidence, 0.78)
    XCTAssertGreaterThan(upper.previewImage.size.width, 20)
    XCTAssertNotNil(upper.visualSignatureRawValue)
    XCTAssertEqual(upper.observerVersion, AdonisProcessingVersion.outfitObservation)
  }

  func testTransparentImageDoesNotInventGarmentObservations() async {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    let image = UIGraphicsImageRenderer(
      size: CGSize(width: 180, height: 240),
      format: format
    ).image { _ in }

    let observations = await OutfitGarmentObserver().observe(sticker: image)

    XCTAssertTrue(observations.isEmpty)
  }

  private func makeOutfitSticker() -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    return UIGraphicsImageRenderer(
      size: CGSize(width: 240, height: 400),
      format: format
    ).image { context in
      UIColor(red: 0.77, green: 0.58, blue: 0.48, alpha: 1).setFill()
      context.cgContext.fillEllipse(in: CGRect(x: 90, y: 22, width: 60, height: 62))

      UIColor(red: 0.42, green: 0.24, blue: 0.12, alpha: 1).setFill()
      context.fill(CGRect(x: 55, y: 92, width: 130, height: 112))

      UIColor(red: 0.12, green: 0.34, blue: 0.72, alpha: 1).setFill()
      context.fill(CGRect(x: 68, y: 204, width: 104, height: 138))
    }
  }
}
