import UIKit
import XCTest

@testable import Adonis

final class AITransparentStickerProcessorTests: XCTestCase {
  func testOpaqueFakeTransparencyIsRejected() async {
    let image = checkerboardImage()

    do {
      _ = try await AITransparentStickerProcessor().process(image)
      XCTFail("An opaque checkerboard must never be accepted as transparent PNG output.")
    } catch StickerProcessingError.aiOutputMissingTransparency {
      // Expected.
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testTransparentAIResultGetsPureWhiteOutlineWithoutDroppingDetachedAccessory() async throws {
    let source = transparentSubjectWithDetachedAccessory()

    let result = try await AITransparentStickerProcessor().process(source)
    let inspection = try XCTUnwrap(TransparentStickerInspector.inspect(result.image))
    let cgImage = try XCTUnwrap(result.image.cgImage)

    XCTAssertGreaterThanOrEqual(max(cgImage.width, cgImage.height), 1_536)
    XCTAssertGreaterThan(inspection.transparentRatio, 0.08)
    XCTAssertGreaterThan(inspection.cornerTransparentRatio, 0.95)
    XCTAssertTrue(containsBlueAccessory(result.image))
    let quality = StickerQualityAssessor.assessSynchronously(
      sticker: result.image,
      foregroundCoverage: result.foregroundCoverage,
      rawMatteAssessment: result.rawMatteAssessment,
      sourceFidelityAssessment: result.sourceFidelityAssessment
    )
    XCTAssertFalse(quality.isRejected)
    XCTAssertFalse(quality.issues.contains(.outlineMayBeBroken))
  }

  func testSeverelyFragmentedAIResultIsRejectedBeforeAStickerCardIsMade() async {
    let source = severelyFragmentedTransparentImage()

    do {
      _ = try await AITransparentStickerProcessor().process(source)
      XCTFail("Multiple similarly sized fragments must not become a sticker card.")
    } catch StickerProcessingError.outputQualityTooLow(let assessment) {
      XCTAssertTrue(assessment.isRejected)
      XCTAssertTrue(assessment.issues.contains(.subjectFragmented))
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  private func checkerboardImage() -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128), format: format).image {
      context in
      for row in 0..<8 {
        for column in 0..<8 {
          ((row + column).isMultiple(of: 2) ? UIColor.white : UIColor.lightGray).setFill()
          context.fill(
            CGRect(x: column * 16, y: row * 16, width: 16, height: 16)
          )
        }
      }
    }
  }

  private func transparentSubjectWithDetachedAccessory() -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    return UIGraphicsImageRenderer(size: CGSize(width: 128, height: 160), format: format).image {
      context in
      UIColor.clear.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 128, height: 160))
      UIColor(red: 0.35, green: 0.12, blue: 0.08, alpha: 1).setFill()
      context.fill(CGRect(x: 38, y: 12, width: 52, height: 136))
      UIColor.blue.setFill()
      context.fill(CGRect(x: 102, y: 68, width: 12, height: 18))
    }
  }

  private func severelyFragmentedTransparentImage() -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    return UIGraphicsImageRenderer(size: CGSize(width: 160, height: 160), format: format).image {
      context in
      UIColor.clear.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 160, height: 160))
      UIColor.brown.setFill()
      context.fill(CGRect(x: 18, y: 24, width: 48, height: 112))
      UIColor.darkGray.setFill()
      context.fill(CGRect(x: 94, y: 24, width: 48, height: 112))
    }
  }

  private func containsBlueAccessory(_ image: UIImage) -> Bool {
    guard let cgImage = image.cgImage else { return false }
    let width = cgImage.width
    let height = cgImage.height
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
    guard
      let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          | CGBitmapInfo.byteOrder32Big.rawValue
      )
    else {
      return false
    }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    return stride(from: 0, to: pixels.count, by: 4).contains { offset in
      pixels[offset + 2] > 180
        && pixels[offset] < 80
        && pixels[offset + 1] < 140
        && pixels[offset + 3] > 200
    }
  }
}
