import UIKit
import XCTest

@testable import Adonis

final class MonthlyLookbookRendererTests: XCTestCase {
  func testProvenanceFooterNamesSavedOriginalsAndProgrammaticLayout() {
    XCTAssertEqual(
      MonthlyLookbookRenderer.provenanceFooter,
      "人物与衣物来自已收藏原图 · 画册由 ADONIS 排版"
    )
  }

  func testSelectionKeepsOnlyLatestSixEntriesFromVisibleMonth() throws {
    let calendar = Calendar(identifier: .gregorian)
    let month = try XCTUnwrap(
      calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))
    )
    let entries =
      try (1...8).map { day in
        MonthlyLookbookEntry(
          sticker: solidImage(color: .systemPink),
          bloomNumber: day,
          date: try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: day))
          )
        )
      } + [
        MonthlyLookbookEntry(
          sticker: solidImage(color: .systemGreen),
          bloomNumber: 99,
          date: try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 31))
          )
        )
      ]

    let selected = MonthlyLookbookRenderer().entriesForRendering(
      entries,
      month: month,
      calendar: calendar
    )

    XCTAssertEqual(selected.map(\.bloomNumber), [8, 7, 6, 5, 4, 3])
  }

  func testRendererReturnsNilWhenVisibleMonthHasNoEntries() throws {
    let calendar = Calendar(identifier: .gregorian)
    let august = try XCTUnwrap(
      calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))
    )
    let julyEntry = MonthlyLookbookEntry(
      sticker: solidImage(color: .systemPink),
      bloomNumber: 1,
      date: try XCTUnwrap(
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 31))
      )
    )

    XCTAssertNil(
      MonthlyLookbookRenderer().render(
        entries: [julyEntry],
        month: august,
        calendar: calendar
      )
    )
  }

  func testRendererProducesOpaqueSocialImageAtContractSize() throws {
    let calendar = Calendar(identifier: .gregorian)
    let month = try XCTUnwrap(
      calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))
    )
    let entry = MonthlyLookbookEntry(
      sticker: solidImage(color: .systemPink),
      bloomNumber: 7,
      date: month
    )

    let lookbook = try XCTUnwrap(
      MonthlyLookbookRenderer().render(
        entries: [entry],
        month: month,
        calendar: calendar
      )
    )
    let image = try XCTUnwrap(lookbook.cgImage)

    XCTAssertEqual(image.width, 1080)
    XCTAssertEqual(image.height, 1440)
    XCTAssertEqual(try minimumAlpha(in: image), 255)
  }

  private func solidImage(color: UIColor) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(
      size: CGSize(width: 120, height: 220),
      format: format
    ).image { context in
      color.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 120, height: 220))
    }
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
