import UIKit
import XCTest

@testable import Adonis

final class MythicGardenCardRendererTests: XCTestCase {
  func testSystemRendererProducesAnOpaquePortraitCardForEveryCuratedRecipe() throws {
    let generatedColor = UIColor(red: 0.19, green: 0.42, blue: 0.71, alpha: 1)
    let generated = solidImage(color: generatedColor)

    for recipe in CreativeRecipe.curatedSystemRecipes {
      let card = try XCTUnwrap(
        SystemCreativeCardRenderer().render(
          generatedImage: generated,
          recipe: recipe,
          bloomNumber: 12,
          date: Date(timeIntervalSince1970: 0)
        )
      )
      let image = try XCTUnwrap(card.cgImage)

      XCTAssertEqual(image.width, 1080, recipe.title)
      XCTAssertEqual(image.height, 1440, recipe.title)
      let pixels = try rgbaPixels(in: image)
      XCTAssertEqual(minimumAlpha(in: pixels), 255, recipe.title)
      XCTAssertGreaterThan(pixelCount(near: generatedColor, in: pixels), 500_000, recipe.title)
    }
  }

  func testContractMarksEveryShareableOutputAsAIGeneratedAndNotRealPhoto() {
    XCTAssertEqual(MythicGardenCardRenderer.provenance, .aiGenerated)
    XCTAssertEqual(
      MythicGardenCardRenderer.provenanceFooter,
      "AI 生成画面 · 仅作风格创作 · 非真实照片"
    )
  }

  func testRendererProducesOpaquePortraitCardAndKeepsGeneratedPixelsVisible() throws {
    let generatedColor = UIColor(red: 0.19, green: 0.42, blue: 0.71, alpha: 1)
    let generated = solidImage(color: generatedColor)
    let card = try XCTUnwrap(
      MythicGardenCardRenderer().render(
        generatedImage: generated,
        bloomNumber: 12,
        date: Date(timeIntervalSince1970: 0)
      )
    )
    let image = try XCTUnwrap(card.cgImage)

    XCTAssertEqual(image.width, 1080)
    XCTAssertEqual(image.height, 1440)
    let pixels = try rgbaPixels(in: image)
    XCTAssertEqual(minimumAlpha(in: pixels), 255)
    XCTAssertGreaterThan(pixelCount(near: generatedColor, in: pixels), 500_000)
  }

  private func solidImage(color: UIColor) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(
      size: CGSize(width: 512, height: 512),
      format: format
    ).image { context in
      color.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
    }
  }

  private func rgbaPixels(in image: CGImage) throws -> [UInt8] {
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
      )
    )
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return pixels
  }

  private func minimumAlpha(in pixels: [UInt8]) -> UInt8 {
    stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }.min() ?? 0
  }

  private func pixelCount(near color: UIColor, in pixels: [UInt8]) -> Int {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    let expected = (
      UInt8((red * 255).rounded()),
      UInt8((green * 255).rounded()),
      UInt8((blue * 255).rounded())
    )
    return stride(from: 0, to: pixels.count, by: 4).reduce(into: 0) { count, offset in
      if abs(Int(pixels[offset]) - Int(expected.0)) <= 3,
        abs(Int(pixels[offset + 1]) - Int(expected.1)) <= 3,
        abs(Int(pixels[offset + 2]) - Int(expected.2)) <= 3,
        pixels[offset + 3] == 255
      {
        count += 1
      }
    }
  }
}
