import CoreImage
import XCTest

@testable import Adonis

final class RawMatteQualityAssessorTests: XCTestCase {
  func testCleanCenteredPersonMaskIsAccepted() {
    let mask = makeMask(width: 64, height: 96) { pixels, width in
      fill(
        pixels: &pixels,
        width: width,
        x: 22..<42,
        y: 8..<90,
        value: 255
      )
    }

    let report = RawMatteQualityAssessor.assessSynchronously(mask: mask)

    XCTAssertEqual(report.assessment, .acceptable)
    XCTAssertEqual(report.foregroundCoverage, 1_640.0 / 6_144.0, accuracy: 0.01)
  }

  func testLargeUncertainFurnitureAdhesionIsRejected() {
    let mask = makeMask(width: 64, height: 96) { pixels, width in
      fill(
        pixels: &pixels,
        width: width,
        x: 4..<60,
        y: 58..<76,
        value: 128
      )
      fill(
        pixels: &pixels,
        width: width,
        x: 22..<42,
        y: 8..<90,
        value: 255
      )
    }

    let report = RawMatteQualityAssessor.assessSynchronously(mask: mask)

    XCTAssertEqual(report.assessment.level, .rejected)
    XCTAssertTrue(report.assessment.issues.contains(.backgroundAdhesionSuspected))
  }

  func testEmptyRawMaskIsRejectedBeforeStickerRendering() {
    let mask = makeMask(width: 64, height: 96) { _, _ in }

    let report = RawMatteQualityAssessor.assessSynchronously(mask: mask)

    XCTAssertEqual(report.assessment.level, .rejected)
    XCTAssertTrue(report.assessment.issues.contains(.subjectMissing))
  }

  func testTwoLargeDisconnectedMaskRegionsAreRejected() {
    let mask = makeMask(width: 64, height: 96) { pixels, width in
      fill(
        pixels: &pixels,
        width: width,
        x: 18..<34,
        y: 8..<90,
        value: 255
      )
      fill(
        pixels: &pixels,
        width: width,
        x: 42..<60,
        y: 34..<86,
        value: 255
      )
    }

    let report = RawMatteQualityAssessor.assessSynchronously(mask: mask)

    XCTAssertEqual(report.assessment.level, .rejected)
    XCTAssertTrue(report.assessment.issues.contains(.subjectFragmented))
  }

  func testDiffuseUncertainEdgeRequestsReviewWithoutRejectingSubject() {
    let mask = makeMask(width: 64, height: 96) { pixels, width in
      fill(
        pixels: &pixels,
        width: width,
        x: 18..<46,
        y: 8..<90,
        value: 128
      )
      fill(
        pixels: &pixels,
        width: width,
        x: 22..<42,
        y: 8..<90,
        value: 255
      )
    }

    let report = RawMatteQualityAssessor.assessSynchronously(mask: mask)

    XCTAssertEqual(report.assessment.level, .reviewRecommended)
    XCTAssertTrue(report.assessment.issues.contains(.edgeMayIncludeBackground))
  }

  private func makeMask(
    width: Int,
    height: Int,
    paint: (inout [UInt8], Int) -> Void
  ) -> CIImage {
    var pixels = [UInt8](repeating: 0, count: width * height)
    paint(&pixels, width)
    return CIImage(
      bitmapData: Data(pixels),
      bytesPerRow: width,
      size: CGSize(width: width, height: height),
      format: .L8,
      colorSpace: CGColorSpaceCreateDeviceGray()
    )
  }

  private func fill(
    pixels: inout [UInt8],
    width: Int,
    x: Range<Int>,
    y: Range<Int>,
    value: UInt8
  ) {
    for row in y {
      for column in x {
        pixels[row * width + column] = value
      }
    }
  }
}
