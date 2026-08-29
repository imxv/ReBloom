import Photos
import UIKit

enum PhotoLibrarySaver {
  static func save(_ image: UIImage) async throws {
    let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    guard status == .authorized || status == .limited else {
      throw PhotoLibrarySaveError.permissionDenied
    }

    try await PHPhotoLibrary.shared().performChanges {
      PHAssetChangeRequest.creationRequestForAsset(from: image)
    }
  }
}

enum PhotoLibrarySaveError: LocalizedError {
  case permissionDenied

  var errorDescription: String? {
    "没有获得保存到相册的权限。你仍然可以使用系统分享。"
  }
}
