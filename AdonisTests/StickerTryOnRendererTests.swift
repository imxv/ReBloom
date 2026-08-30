import UIKit
import XCTest

@testable import Adonis

final class StickerTryOnRendererTests: XCTestCase {
  @MainActor
  func testUIFixtureKeepsAuthorizedSampleFaceAndChangesOnlyTorsoArea() async throws {
    let source = try XCTUnwrap(
      SampleCatalog.photos.first(where: { $0.id == "sample-02" })?.image()
    )
    let generator = StickerTryOnGeneratorFactory.make(
      arguments: ["-ui-testing-sticker-try-on"]
    )

    let result = try await generator.generate(
      person: source,
      garment: WardrobeTestImageFactory.brownCatalogShirt(),
      category: .top
    )

    XCTAssertEqual(
      try pixel(in: result.image, x: 550, y: 610),
      try pixel(in: source, x: 550, y: 610),
      "贴纸试搭不能覆盖脸部"
    )
    XCTAssertNotEqual(
      try pixel(in: result.image, x: 550, y: 800),
      try pixel(in: source, x: 550, y: 800),
      "衣物应覆盖到上身区域"
    )

    let attachment = XCTAttachment(image: result.image)
    attachment.name = "Adonis-sticker-try-on-render"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  @MainActor
  func testDebugFactoryUsesExplicitFixtureWithoutChangingProductionMetadata() async throws {
    let fixture = StickerTryOnGeneratorFactory.make(
      arguments: ["-ui-testing-sticker-try-on"]
    )
    XCTAssertEqual(fixture.executionMetadata, .uiTestFixture)

    let person = solidImage(
      size: CGSize(width: 600, height: 900),
      color: UIColor(red: 0.91, green: 0.86, blue: 0.78, alpha: 1)
    )
    let result = try await fixture.generate(
      person: person,
      garment: WardrobeTestImageFactory.brownCatalogShirt(),
      category: .top
    )
    XCTAssertEqual(result.provenance, .programmaticComposition)
    XCTAssertGreaterThan(result.garmentCoverage, 0.03)

    let production = StickerTryOnGeneratorFactory.make(arguments: [])
    XCTAssertEqual(production.executionMetadata, .stickerTryOn)
  }

  func testEligibilityAcceptsOnlyCleanCatalogTopOrOuterwear() {
    XCTAssertEqual(
      StickerTryOnEligibility.evaluate(
        sourceKind: .catalogImage,
        cleanBackgroundScore: 0.82,
        category: .top
      ),
      .ready
    )
    XCTAssertEqual(
      StickerTryOnEligibility.evaluate(
        sourceKind: .catalogImage,
        cleanBackgroundScore: 0.82,
        category: .outerwear
      ),
      .ready
    )
    XCTAssertEqual(
      StickerTryOnEligibility.evaluate(
        sourceKind: .outfitObservation,
        cleanBackgroundScore: 0.82,
        category: .top
      ),
      .needsCleanCatalogImage
    )
    XCTAssertEqual(
      StickerTryOnEligibility.evaluate(
        sourceKind: .catalogImage,
        cleanBackgroundScore: 0.55,
        category: .top
      ),
      .needsCleanCatalogImage
    )
    XCTAssertEqual(
      StickerTryOnEligibility.evaluate(
        sourceKind: .catalogImage,
        cleanBackgroundScore: 0.82,
        category: .shoes
      ),
      .unsupportedCategory
    )
  }

  func testAuthorizedStandingSampleUsesVisionOrReportsRuntimeBoundary() async throws {
    let sample = try XCTUnwrap(
      SampleCatalog.photos.first(where: { $0.id == "sample-02" })?.image()
    )

    #if targetEnvironment(simulator)
      do {
        let pose = try await StickerTryOnPoseDetector().detect(in: sample)
        assertUsable(pose)
      } catch let error as StickerTryOnError {
        XCTAssertEqual(error, .poseDetectionUnavailable)
      }
    #else
      let pose = try await StickerTryOnPoseDetector().detect(in: sample)
      assertUsable(pose)
    #endif
  }

  private func assertUsable(_ pose: StickerTryOnPose) {
    XCTAssertGreaterThanOrEqual(pose.confidence, 0.35)
    XCTAssertGreaterThan(pose.leftShoulder.distance(to: pose.rightShoulder), 0.07)
    XCTAssertGreaterThan(
      pose.leftShoulder.midpoint(to: pose.rightShoulder)
        .distance(to: pose.leftHip.midpoint(to: pose.rightHip)),
      0.1
    )
    for point in [pose.leftShoulder, pose.rightShoulder, pose.leftHip, pose.rightHip] {
      XCTAssertTrue((0...1).contains(point.x))
      XCTAssertTrue((0...1).contains(point.y))
    }
  }

  func testCleanCatalogTopComposesOntoKnownTorsoWithoutChangingCanvas() throws {
    let person = solidImage(
      size: CGSize(width: 600, height: 900),
      color: UIColor(red: 0.91, green: 0.86, blue: 0.78, alpha: 1)
    )
    let garment = WardrobeTestImageFactory.brownCatalogShirt()
    let pose = StickerTryOnPose(
      leftShoulder: CGPoint(x: 0.36, y: 0.27),
      rightShoulder: CGPoint(x: 0.64, y: 0.27),
      leftHip: CGPoint(x: 0.41, y: 0.58),
      rightHip: CGPoint(x: 0.59, y: 0.58),
      leftKnee: CGPoint(x: 0.42, y: 0.77),
      rightKnee: CGPoint(x: 0.58, y: 0.77),
      confidence: 0.94
    )

    let result = try StickerTryOnRenderer().render(
      person: person,
      garment: garment,
      category: .top,
      pose: pose
    )

    XCTAssertEqual(result.image.size, person.size)
    XCTAssertEqual(result.provenance, .programmaticComposition)
    XCTAssertEqual(result.poseConfidence, 0.94, accuracy: 0.001)
    XCTAssertGreaterThan(result.garmentCoverage, 0.03)
    XCTAssertLessThan(result.garmentCoverage, 0.5)

    let sourceCorner = try pixel(in: person, x: 30, y: 30)
    let resultCorner = try pixel(in: result.image, x: 30, y: 30)
    XCTAssertEqual(resultCorner, sourceCorner)

    let sourceTorso = try pixel(in: person, x: 300, y: 380)
    let resultTorso = try pixel(in: result.image, x: 300, y: 380)
    XCTAssertNotEqual(resultTorso, sourceTorso)
    XCTAssertGreaterThan(resultTorso.red, resultTorso.blue)
    XCTAssertGreaterThan(
      try nearWhitePixelCount(in: result.image),
      100,
      "衣物贴纸应有可见的纯白描边"
    )
  }

  private func solidImage(size: CGSize, color: UIColor) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
      color.setFill()
      context.fill(CGRect(origin: .zero, size: size))
    }
  }

  private func pixel(in image: UIImage, x: Int, y: Int) throws -> RGBA {
    let cgImage = try XCTUnwrap(image.cgImage)
    let width = cgImage.width
    let height = cgImage.height
    XCTAssertTrue((0..<width).contains(x))
    XCTAssertTrue((0..<height).contains(y))

    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let context = try XCTUnwrap(
      CGContext(
        data: &bytes,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          | CGBitmapInfo.byteOrder32Big.rawValue
      )
    )
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    let topLeftRow = height - 1 - y
    let offset = (topLeftRow * width + x) * 4
    return RGBA(
      red: bytes[offset],
      green: bytes[offset + 1],
      blue: bytes[offset + 2],
      alpha: bytes[offset + 3]
    )
  }

  private func nearWhitePixelCount(in image: UIImage) throws -> Int {
    let cgImage = try XCTUnwrap(image.cgImage)
    let width = cgImage.width
    let height = cgImage.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let context = try XCTUnwrap(
      CGContext(
        data: &bytes,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          | CGBitmapInfo.byteOrder32Big.rawValue
      )
    )
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    return stride(from: 0, to: bytes.count, by: 4).reduce(into: 0) { count, offset in
      if bytes[offset] >= 245,
        bytes[offset + 1] >= 245,
        bytes[offset + 2] >= 245,
        bytes[offset + 3] >= 245
      {
        count += 1
      }
    }
  }
}

private struct RGBA: Equatable {
  let red: UInt8
  let green: UInt8
  let blue: UInt8
  let alpha: UInt8
}

extension CGPoint {
  fileprivate func distance(to other: CGPoint) -> CGFloat {
    hypot(x - other.x, y - other.y)
  }

  fileprivate func midpoint(to other: CGPoint) -> CGPoint {
    CGPoint(x: (x + other.x) / 2, y: (y + other.y) / 2)
  }
}
