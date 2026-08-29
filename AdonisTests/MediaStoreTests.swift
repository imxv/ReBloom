import XCTest

@testable import Adonis

final class MediaStoreTests: XCTestCase {
  func testPNGWriteReadDeleteAndResetStayInsideConfiguredDirectory() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("adonis-media-test-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = MediaStore(baseURL: directory)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let image = UIGraphicsImageRenderer(
      size: CGSize(width: 80, height: 120),
      format: format
    ).image { context in
      UIColor.systemPink.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 80, height: 120))
    }

    let filename = try store.savePNG(image, filename: "outfit.png")
    XCTAssertEqual(filename, "outfit.png")
    XCTAssertTrue(FileManager.default.fileExists(atPath: store.url(for: filename).path))
    XCTAssertEqual(store.image(filename: filename)?.size, image.size)
    XCTAssertNotNil(store.data(filename: filename))

    store.delete(filename: filename)
    XCTAssertFalse(FileManager.default.fileExists(atPath: store.url(for: filename).path))

    _ = try store.savePNG(image, filename: "again.png")
    try store.removeAll()
    XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
    XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
  }
}
