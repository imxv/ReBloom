import UIKit
import XCTest

@testable import Adonis

final class SharedImageInboxTests: XCTestCase {
  func testValidImagesAreQueuedInOrderAndRemovedExplicitly() throws {
    let directory = temporaryDirectory(named: "adonis-shared-inbox")
    defer { try? FileManager.default.removeItem(at: directory) }
    let inbox = try SharedImageInbox(baseURL: directory)
    let firstData = try XCTUnwrap(WardrobeTestImageFactory.brownCatalogShirt().pngData())
    let secondData = try XCTUnwrap(WardrobeTestImageFactory.blueCatalogShirt().pngData())

    let second = try inbox.enqueue(
      data: secondData,
      createdAt: Date(timeIntervalSince1970: 1_700_000_002)
    )
    let first = try inbox.enqueue(
      data: firstData,
      createdAt: Date(timeIntervalSince1970: 1_700_000_001)
    )

    XCTAssertEqual(try inbox.pendingItems().map(\.id), [first.id, second.id])
    XCTAssertEqual(try inbox.data(for: first), firstData)

    try inbox.remove(first)
    XCTAssertEqual(try inbox.pendingItems().map(\.id), [second.id])
    try inbox.removeAll()
    XCTAssertTrue(try inbox.pendingItems().isEmpty)
  }

  func testUnreadableAndTinyImagesNeverEnterSharedInbox() throws {
    let directory = temporaryDirectory(named: "adonis-shared-inbox-validation")
    defer { try? FileManager.default.removeItem(at: directory) }
    let inbox = try SharedImageInbox(baseURL: directory)

    XCTAssertThrowsError(try inbox.enqueue(data: Data("not-an-image".utf8))) { error in
      XCTAssertEqual(error as? SharedImageInboxError, .unreadableImage)
    }

    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let tinyImage = UIGraphicsImageRenderer(
      size: CGSize(width: 32, height: 32),
      format: format
    ).image { context in
      UIColor.systemPink.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
    }
    XCTAssertThrowsError(try inbox.enqueue(data: try XCTUnwrap(tinyImage.pngData()))) { error in
      XCTAssertEqual(error as? SharedImageInboxError, .imageTooSmall)
    }
    XCTAssertTrue(try inbox.pendingItems().isEmpty)
  }

  func testQueueLimitRejectsMoreImagesWithoutOverwritingPendingData() throws {
    let directory = temporaryDirectory(named: "adonis-shared-inbox-capacity")
    defer { try? FileManager.default.removeItem(at: directory) }
    let data = try XCTUnwrap(WardrobeTestImageFactory.brownCatalogShirt().pngData())
    let inbox = try SharedImageInbox(
      baseURL: directory,
      queuedImageCountLimit: 1,
      queuedImageBytesLimit: data.count * 2
    )

    let first = try inbox.enqueue(data: data)
    XCTAssertThrowsError(try inbox.enqueue(data: data)) { error in
      XCTAssertEqual(error as? SharedImageInboxError, .inboxFull)
    }
    XCTAssertEqual(try inbox.pendingItems().map(\.id), [first.id])
    XCTAssertEqual(try inbox.data(for: first), data)
  }

  func testOversizedPixelDimensionsAreRejectedBeforeQueueing() throws {
    let directory = temporaryDirectory(named: "adonis-shared-inbox-pixels")
    defer { try? FileManager.default.removeItem(at: directory) }
    let data = try XCTUnwrap(WardrobeTestImageFactory.brownCatalogShirt().pngData())
    let inbox = try SharedImageInbox(
      baseURL: directory,
      maximumImagePixelCount: 4_095
    )

    XCTAssertThrowsError(try inbox.enqueue(data: data)) { error in
      XCTAssertEqual(error as? SharedImageInboxError, .imageDimensionsTooLarge)
    }
    XCTAssertTrue(try inbox.pendingItems().isEmpty)
  }

  private func temporaryDirectory(named prefix: String) -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
  }
}
