import CoreImage
import XCTest

@testable import Adonis

final class StickerSourceFidelityAssessorTests: XCTestCase {
  func testAlphaOnlyExtractionKeepsCoreSourcePixelsAcceptable() {
    let source = makeSource(width: 16, height: 8)
    let coarseMask = makeMask(width: 4, height: 2) { column, _ in
      column < 2 ? 255 : 0
    }
    let matte = StickerMatteRefiner.extractSubject(
      source: source,
      coarseMask: coarseMask
    )

    let report = StickerSourceFidelityAssessor.assessSynchronously(
      source: source,
      subject: matte.subject,
      mask: matte.mask
    )

    XCTAssertEqual(report.assessment, .acceptable)
    XCTAssertGreaterThan(report.comparedCorePixelCount, 0)
    XCTAssertEqual(report.changedCorePixelRatio, 0, accuracy: 0.000_001)
  }

  func testChangedCoreColorPixelsAreRejected() {
    let source = makeSource(width: 16, height: 8)
    let coarseMask = makeMask(width: 4, height: 2) { column, _ in
      column < 2 ? 255 : 0
    }
    let matte = StickerMatteRefiner.extractSubject(
      source: source,
      coarseMask: coarseMask
    )
    let changedSubject = matte.subject.applyingFilter(
      "CIColorMatrix",
      parameters: [
        "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
        "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
        "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        "inputBiasVector": CIVector(x: 1, y: 0, z: 0, w: 0),
      ]
    )

    let report = StickerSourceFidelityAssessor.assessSynchronously(
      source: source,
      subject: changedSubject,
      mask: matte.mask
    )

    XCTAssertEqual(report.assessment.level, .rejected)
    XCTAssertTrue(report.assessment.issues.contains(.sourcePixelsChanged))
    XCTAssertGreaterThan(report.changedCorePixelRatio, 0.5)
  }

  func testDownsampledLargeAlphaOnlyExtractionRemainsAcceptable() {
    let source = makeSource(width: 1_024, height: 512)
    let mask = makeMask(width: 1_024, height: 512) { column, _ in
      (64..<960).contains(column) ? 255 : 0
    }
    let subject = source.applyingFilter(
      "CIBlendWithMask",
      parameters: [
        kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: source.extent),
        kCIInputMaskImageKey: mask,
      ]
    )

    let report = StickerSourceFidelityAssessor.assessSynchronously(
      source: source,
      subject: subject,
      mask: mask
    )

    XCTAssertEqual(report.assessment, .acceptable)
    XCTAssertGreaterThan(report.comparedCorePixelCount, 100_000)
    XCTAssertLessThanOrEqual(report.changedCorePixelRatio, 0.005)
  }

  private func makeSource(width: Int, height: Int) -> CIImage {
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    for row in 0..<height {
      for column in 0..<width {
        let offset = (row * width + column) * 4
        pixels[offset] = UInt8((40 + column * 7) % 220)
        pixels[offset + 1] = UInt8((70 + row * 11) % 230)
        pixels[offset + 2] = UInt8((190 + column * 5 + row * 3) % 240)
        pixels[offset + 3] = 255
      }
    }
    return CIImage(
      bitmapData: Data(pixels),
      bytesPerRow: width * 4,
      size: CGSize(width: width, height: height),
      format: .RGBA8,
      colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
    )
  }

  private func makeMask(
    width: Int,
    height: Int,
    value: (Int, Int) -> UInt8
  ) -> CIImage {
    var pixels = [UInt8](repeating: 0, count: width * height)
    for row in 0..<height {
      for column in 0..<width {
        pixels[row * width + column] = value(column, row)
      }
    }
    return CIImage(
      bitmapData: Data(pixels),
      bytesPerRow: width,
      size: CGSize(width: width, height: height),
      format: .L8,
      colorSpace: CGColorSpaceCreateDeviceGray()
    )
  }
}
