import UIKit
import XCTest

@testable import Adonis

final class RebloomCardRendererTests: XCTestCase {
  func testContractNamesRealWardrobeImagesAndNonTryOnComposition() {
    XCTAssertEqual(
      RebloomCardRenderer.provenanceFooter,
      "真实衣橱图片 · ADONIS 本机组合建议 · 非试穿效果"
    )
    XCTAssertEqual(RebloomCardRenderer.provenance, .programmaticComposition)
  }

  func testRendererRejectsMissingItemImage() {
    XCTAssertNil(
      RebloomCardRenderer().render(
        topImage: UIImage(),
        topName: "白色上装",
        bottomImage: solidImage(color: .systemBlue),
        bottomName: "蓝色下装",
        reasonTitle: "从两次真实穿着里换个组合"
      )
    )
  }

  func testRendererProducesOpaqueShareImageAndKeepsBothSourceColors() throws {
    let topColor = UIColor(red: 0.82, green: 0.16, blue: 0.24, alpha: 1)
    let bottomColor = UIColor(red: 0.10, green: 0.36, blue: 0.78, alpha: 1)
    let card = try XCTUnwrap(
      RebloomCardRenderer().render(
        topImage: solidImage(color: topColor),
        topName: "红色上装",
        bottomImage: solidImage(color: bottomColor),
        bottomName: "蓝色下装",
        reasonTitle: "从两次真实穿着里换个组合"
      )
    )
    let image = try XCTUnwrap(card.cgImage)
    let pixels = try rgbaPixels(in: image)

    XCTAssertEqual(image.width, 1080)
    XCTAssertEqual(image.height, 1440)
    XCTAssertEqual(pixels.alpha.min(), 255)
    XCTAssertGreaterThan(matchingPixelCount(pixels.bytes, color: topColor), 5_000)
    XCTAssertGreaterThan(matchingPixelCount(pixels.bytes, color: bottomColor), 5_000)
  }

  private func solidImage(color: UIColor) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(
      size: CGSize(width: 260, height: 340),
      format: format
    ).image { context in
      color.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 260, height: 340))
    }
  }

  private func matchingPixelCount(_ pixels: [UInt8], color: UIColor) -> Int {
    let expected = rgba8(color)
    return stride(from: 0, to: pixels.count, by: 4).reduce(into: 0) { count, offset in
      if abs(Int(pixels[offset]) - Int(expected.red)) <= 3,
        abs(Int(pixels[offset + 1]) - Int(expected.green)) <= 3,
        abs(Int(pixels[offset + 2]) - Int(expected.blue)) <= 3,
        pixels[offset + 3] == 255
      {
        count += 1
      }
    }
  }

  private func rgba8(_ color: UIColor) -> (red: UInt8, green: UInt8, blue: UInt8) {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return (
      UInt8((red * 255).rounded()),
      UInt8((green * 255).rounded()),
      UInt8((blue * 255).rounded())
    )
  }

  private func rgbaPixels(in image: CGImage) throws -> (bytes: [UInt8], alpha: [UInt8]) {
    let width = image.width
    let height = image.height
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
    let context = try XCTUnwrap(
      CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          | CGBitmapInfo.byteOrder32Big.rawValue
      ))
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return (pixels, stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] })
  }
}
