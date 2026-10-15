import CoreImage
import XCTest

@testable import Adonis

final class StickerMatteRefinerTests: XCTestCase {
  func testRefinementUpsamplesMaskAndKeepsDefiniteForegroundAndBackground() throws {
    let source = makeVerticalGuide(width: 16, height: 8, edgeX: 8)
    let coarseMask = makeMask(width: 4, height: 2) { column, _ in
      column < 2 ? 255 : 0
    }

    let refined = StickerMatteRefiner.refine(
      source: source,
      coarseMask: coarseMask
    )
    let pixels = try renderMask(refined)

    XCTAssertEqual(refined.extent.integral, source.extent.integral)
    XCTAssertGreaterThanOrEqual(pixels[4 * 16 + 1], 250)
    XCTAssertLessThanOrEqual(pixels[4 * 16 + 14], 5)
  }

  func testRefinementUsesSourceLuminanceToPlaceTheUnknownEdge() throws {
    let coarseMask = makeMask(width: 8, height: 2) { column, _ in
      column < 4 ? 255 : 0
    }
    let earlierEdge = StickerMatteRefiner.refine(
      source: makeVerticalGuide(width: 64, height: 16, edgeX: 28),
      coarseMask: coarseMask
    )
    let laterEdge = StickerMatteRefiner.refine(
      source: makeVerticalGuide(width: 64, height: 16, edgeX: 36),
      coarseMask: coarseMask
    )

    let earlierPixels = try renderMask(earlierEdge)
    let laterPixels = try renderMask(laterEdge)
    let earlierForeground = earlierPixels.reduce(0) { $0 + Int($1) }
    let laterForeground = laterPixels.reduce(0) { $0 + Int($1) }

    XCTAssertGreaterThan(
      laterForeground,
      earlierForeground + 16 * 255,
      "相同粗蒙版应随原图明暗边缘移动过渡，而不是只做普通缩放"
    )
  }

  func testRefinedSubjectPreservesOpaqueSourcePixelsAndOnlyChangesAlpha() throws {
    let source = makeVerticalGuide(width: 16, height: 8, edgeX: 8)
    let coarseMask = makeMask(width: 4, height: 2) { column, _ in
      column < 2 ? 255 : 0
    }

    let result = StickerMatteRefiner.extractSubject(
      source: source,
      coarseMask: coarseMask
    )
    let pixels = try renderRGBA(result.subject)
    let foregroundOffset = (4 * 16 + 1) * 4
    let backgroundOffset = (4 * 16 + 14) * 4

    let foregroundAlpha = Int(pixels[foregroundOffset + 3])
    let unpremultiplied = (0..<3).map { channel in
      Int((Double(pixels[foregroundOffset + channel]) * 255 / Double(foregroundAlpha)).rounded())
    }
    XCTAssertEqual(unpremultiplied, [235, 235, 235])
    XCTAssertGreaterThanOrEqual(foregroundAlpha, 240)
    XCTAssertLessThanOrEqual(pixels[backgroundOffset + 3], 5)
  }

  private func makeVerticalGuide(width: Int, height: Int, edgeX: Int) -> CIImage {
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    for row in 0..<height {
      for column in 0..<width {
        let value: UInt8 = column < edgeX ? 235 : 20
        let offset = (row * width + column) * 4
        pixels[offset] = value
        pixels[offset + 1] = value
        pixels[offset + 2] = value
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

  private func renderMask(_ image: CIImage) throws -> [UInt8] {
    let extent = image.extent.integral
    let width = Int(extent.width)
    let height = Int(extent.height)
    var pixels = [UInt8](repeating: 0, count: width * height)
    CIContext(options: [.cacheIntermediates: false]).render(
      image,
      toBitmap: &pixels,
      rowBytes: width,
      bounds: extent,
      format: .L8,
      colorSpace: CGColorSpaceCreateDeviceGray()
    )
    return pixels
  }

  private func renderRGBA(_ image: CIImage) throws -> [UInt8] {
    let extent = image.extent.integral
    let width = Int(extent.width)
    let height = Int(extent.height)
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    CIContext(options: [.cacheIntermediates: false]).render(
      image,
      toBitmap: &pixels,
      rowBytes: width * 4,
      bounds: extent,
      format: .RGBA8,
      colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
    )
    return pixels
  }
}
