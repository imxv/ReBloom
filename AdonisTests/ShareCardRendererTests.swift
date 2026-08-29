import XCTest

@testable import Adonis

final class ShareCardRendererTests: XCTestCase {
  func testRendererProducesOpaqueSocialCardAtContractSize() throws {
    let sticker = try XCTUnwrap(SampleCatalog.photos.first?.preparedStickerImage())
    let date = try XCTUnwrap(
      Calendar(identifier: .gregorian).date(
        from: DateComponents(year: 2026, month: 8, day: 29)
      )
    )

    let card = ShareCardRenderer().render(
      sticker: sticker,
      bloomNumber: 7,
      date: date
    )
    let image = try XCTUnwrap(card.cgImage)

    XCTAssertEqual(image.width, 1080)
    XCTAssertEqual(image.height, 1440)
    XCTAssertEqual(try minimumAlpha(in: image), 255)
  }

  private func minimumAlpha(in image: CGImage) throws -> UInt8 {
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

    return stride(from: 3, to: pixels.count, by: 4)
      .map { pixels[$0] }
      .min() ?? 0
  }
}
