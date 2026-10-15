import UIKit
import XCTest

@testable import Adonis

final class DigitalFigurineCardRendererTests: XCTestCase {
  func testLegacyContractNamesOriginalStickerAndProgrammaticStage() {
    XCTAssertEqual(
      DigitalFigurineCardRenderer.provenanceFooter,
      "人物与衣物来自原图贴纸 · 展台由 REBLOOM 排版"
    )
    XCTAssertEqual(DigitalFigurineCardRenderer.provenance, .programmaticComposition)
    XCTAssertEqual(AdonisProcessingVersion.digitalFigurineCard, "digital-figurine-card-v1")
    XCTAssertEqual(AppEventKind.digitalFigurineCardCreated.title, "生成手办收藏卡")
    XCTAssertEqual(AppEventKind.digitalFigurineCardShareOpened.title, "打开手办卡分享")
  }

  func testAIStickerKeepsAIProvenanceThroughFigurineStageLayout() {
    XCTAssertEqual(DigitalFigurineCardRenderer.provenance(for: .aiGenerated), .aiGenerated)
    XCTAssertEqual(
      DigitalFigurineCardRenderer.provenanceFooter(for: .aiGenerated),
      "人物与衣物来自 AI 贴纸 · 展台由 REBLOOM 排版"
    )
  }

  func testRendererRejectsEmptyStickerInsteadOfProducingAnEmptyStage() {
    XCTAssertNil(
      DigitalFigurineCardRenderer().render(
        sticker: UIImage(),
        bloomNumber: 7,
        date: Date(timeIntervalSince1970: 0)
      )
    )
  }

  func testRendererProducesOpaqueSocialImageAtContractSize() throws {
    let card = try XCTUnwrap(
      DigitalFigurineCardRenderer().render(
        sticker: stickerImage(),
        bloomNumber: 7,
        date: Date(timeIntervalSince1970: 0)
      )
    )
    let image = try XCTUnwrap(card.cgImage)

    XCTAssertEqual(image.width, 1080)
    XCTAssertEqual(image.height, 1440)
    XCTAssertEqual(try minimumAlpha(in: image), 255)
  }

  func testRendererCompositesOriginalStickerPixelsWithoutGenerativeRedraw() throws {
    let card = try XCTUnwrap(
      DigitalFigurineCardRenderer().render(
        sticker: stickerImage(),
        bloomNumber: 12,
        date: Date(timeIntervalSince1970: 0)
      )
    )
    let image = try XCTUnwrap(card.cgImage)

    XCTAssertGreaterThan(try matchingSourcePixelCount(in: image), 4_000)
  }

  private func stickerImage() -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    return UIGraphicsImageRenderer(
      size: CGSize(width: 240, height: 420),
      format: format
    ).image { context in
      Self.sourceColor.setFill()
      UIBezierPath(
        roundedRect: CGRect(x: 42, y: 24, width: 156, height: 372),
        cornerRadius: 48
      ).fill()
      UIColor.white.setStroke()
      let outline = UIBezierPath(
        roundedRect: CGRect(x: 34, y: 16, width: 172, height: 388),
        cornerRadius: 56
      )
      outline.lineWidth = 16
      outline.stroke()
      context.cgContext.setBlendMode(.normal)
    }
  }

  private func minimumAlpha(in image: CGImage) throws -> UInt8 {
    try rgbaPixels(in: image).alpha.min() ?? 0
  }

  private func matchingSourcePixelCount(in image: CGImage) throws -> Int {
    let pixels = try rgbaPixels(in: image).bytes
    let expected = Self.sourceColor.rgba8
    return stride(from: 0, to: pixels.count, by: 4).reduce(into: 0) { count, offset in
      let matches =
        abs(Int(pixels[offset]) - Int(expected.red)) <= 3
        && abs(Int(pixels[offset + 1]) - Int(expected.green)) <= 3
        && abs(Int(pixels[offset + 2]) - Int(expected.blue)) <= 3
        && pixels[offset + 3] == 255
      if matches { count += 1 }
    }
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

  private static let sourceColor = UIColor(
    red: 19 / 255,
    green: 112 / 255,
    blue: 210 / 255,
    alpha: 1
  )
}

extension UIColor {
  fileprivate var rgba8: (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return (
      UInt8((red * 255).rounded()),
      UInt8((green * 255).rounded()),
      UInt8((blue * 255).rounded()),
      UInt8((alpha * 255).rounded())
    )
  }
}
