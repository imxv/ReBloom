import XCTest

@testable import Adonis

final class GarmentVisualSignatureTests: XCTestCase {
  func testPatternSurvivesCleanBackgroundAndOutfitCropBetterThanPlainDistractor() throws {
    let analyzer = GarmentVisualSignatureAnalyzer()
    let catalog = try analyzer.signature(for: makePlaidCatalogImage())
    let outfitCrop = try analyzer.signature(for: makePlaidOutfitCrop())
    let plainDistractor = try analyzer.signature(for: makePlainOutfitCrop())

    let sameGarment = catalog.similarity(to: outfitCrop)
    let distractor = catalog.similarity(to: plainDistractor)

    XCTAssertGreaterThan(sameGarment.overall, 0.72)
    XCTAssertGreaterThan(sameGarment.overall, distractor.overall + 0.12)
    XCTAssertGreaterThan(sameGarment.color, distractor.color)
    XCTAssertGreaterThan(sameGarment.texture, distractor.texture)
  }

  func testEncodedSignatureRoundTripsWithoutChangingSimilarity() throws {
    let signature = try GarmentVisualSignatureAnalyzer().signature(
      for: makePlaidCatalogImage()
    )
    let encoded = try XCTUnwrap(signature.encoded())
    let decoded = try XCTUnwrap(GarmentVisualSignature(encoded: encoded))

    XCTAssertEqual(decoded.version, GarmentVisualSignature.currentVersion)
    XCTAssertEqual(decoded, signature)
    XCTAssertEqual(decoded.similarity(to: signature).overall, 1, accuracy: 0.0001)
  }

  func testNearlyEmptyImageDoesNotInventVisualEvidence() {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    let image = UIGraphicsImageRenderer(
      size: CGSize(width: 120, height: 120),
      format: format
    ).image { context in
      UIColor.black.setFill()
      context.fill(CGRect(x: 59, y: 59, width: 2, height: 2))
    }

    XCTAssertThrowsError(try GarmentVisualSignatureAnalyzer().signature(for: image))
  }

  private func makePlaidCatalogImage() -> UIImage {
    makeGarmentImage(
      size: CGSize(width: 240, height: 320),
      garmentRect: CGRect(x: 50, y: 58, width: 140, height: 210),
      background: .white,
      plaid: true
    )
  }

  private func makePlaidOutfitCrop() -> UIImage {
    makeGarmentImage(
      size: CGSize(width: 180, height: 180),
      garmentRect: CGRect(x: 16, y: 10, width: 148, height: 162),
      background: .clear,
      plaid: true
    )
  }

  private func makePlainOutfitCrop() -> UIImage {
    makeGarmentImage(
      size: CGSize(width: 180, height: 180),
      garmentRect: CGRect(x: 16, y: 10, width: 148, height: 162),
      background: .clear,
      plaid: false
    )
  }

  private func makeGarmentImage(
    size: CGSize,
    garmentRect: CGRect,
    background: UIColor,
    plaid: Bool
  ) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = background != .clear
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
      background.setFill()
      context.fill(CGRect(origin: .zero, size: size))

      let garment = UIBezierPath(roundedRect: garmentRect, cornerRadius: 18)
      UIColor(red: 0.39, green: 0.23, blue: 0.13, alpha: 1).setFill()
      garment.fill()
      guard plaid else { return }

      context.cgContext.saveGState()
      garment.addClip()
      UIColor(red: 0.82, green: 0.69, blue: 0.49, alpha: 1).setStroke()
      context.cgContext.setLineWidth(5)
      let spacing = max(22, garmentRect.width / 5)
      for x in stride(
        from: garmentRect.minX + 10,
        through: garmentRect.maxX,
        by: spacing
      ) {
        context.cgContext.move(to: CGPoint(x: x, y: garmentRect.minY))
        context.cgContext.addLine(to: CGPoint(x: x, y: garmentRect.maxY))
      }
      for y in stride(
        from: garmentRect.minY + 12,
        through: garmentRect.maxY,
        by: spacing
      ) {
        context.cgContext.move(to: CGPoint(x: garmentRect.minX, y: y))
        context.cgContext.addLine(to: CGPoint(x: garmentRect.maxX, y: y))
      }
      context.cgContext.strokePath()
      context.cgContext.restoreGState()
    }
  }
}
