import Photos
import UIKit
import XCTest

@testable import Adonis

@MainActor
final class PhotoLibrarySaverTests: XCTestCase {
  func testPhotoSaveEventsAndFailureReasonsHaveStableNames() {
    XCTAssertEqual(AppEventKind.stickerPhotoSaved.title, "贴纸存入相册")
    XCTAssertEqual(AppEventKind.stickerPhotoSaveFailed.title, "贴纸未存入相册")
    XCTAssertEqual(PhotoLibrarySaveError.permissionDenied.eventCode, "permission_denied")
    XCTAssertEqual(PhotoLibrarySaveError.writeFailed.eventCode, "write_failed")
  }

  func testAuthorizedSaveWritesTransparentPNGOnce() async throws {
    var writeCount = 0
    let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }
    let saver = PhotoLibrarySaver(
      requestAuthorization: { .authorized },
      performSave: { (pngData: Data) in
        XCTAssertEqual(Array(pngData.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
        let decoded = try XCTUnwrap(UIImage(data: pngData)?.cgImage)
        XCTAssertTrue(
          [.first, .last, .premultipliedFirst, .premultipliedLast]
            .contains(decoded.alphaInfo)
        )
        writeCount += 1
      }
    )

    try await saver.save(image)

    XCTAssertEqual(writeCount, 1)
  }

  func testDeniedAuthorizationStopsBeforeWriting() async {
    var didWrite = false
    let saver = PhotoLibrarySaver(
      requestAuthorization: { .denied },
      performSave: { _ in didWrite = true }
    )

    do {
      try await saver.save(UIImage())
      XCTFail("权限拒绝时不应保存图片")
    } catch let error as PhotoLibrarySaveError {
      XCTAssertEqual(error, .permissionDenied)
    } catch {
      XCTFail("应返回稳定的相册保存错误，实际为 \(error)")
    }

    XCTAssertFalse(didWrite)
  }

  func testWriterFailureBecomesStableSaveError() async {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }
    let saver = PhotoLibrarySaver(
      requestAuthorization: { .authorized },
      performSave: { _ in throw PhotoLibraryWriterFixtureError() }
    )

    do {
      try await saver.save(image)
      XCTFail("相册写入失败时不应报告成功")
    } catch let error as PhotoLibrarySaveError {
      XCTAssertEqual(error, .writeFailed)
      XCTAssertTrue(error.localizedDescription.contains("写入"))
    } catch {
      XCTFail("应返回稳定的相册保存错误，实际为 \(error)")
    }
  }
}

private struct PhotoLibraryWriterFixtureError: Error {}
