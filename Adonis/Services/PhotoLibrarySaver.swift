import Photos
import UIKit
import UniformTypeIdentifiers

struct PhotoLibrarySaver {
  typealias AuthorizationRequest = @MainActor () async -> PHAuthorizationStatus
  typealias PNGWriter = @MainActor (Data) async throws -> Void

  private let requestAuthorization: AuthorizationRequest
  private let performSave: PNGWriter

  init(
    requestAuthorization: @escaping AuthorizationRequest,
    performSave: @escaping PNGWriter
  ) {
    self.requestAuthorization = requestAuthorization
    self.performSave = performSave
  }

  @MainActor
  func save(_ image: UIImage) async throws {
    let status = await requestAuthorization()
    guard status == .authorized || status == .limited else {
      throw PhotoLibrarySaveError.permissionDenied
    }

    guard let pngData = image.pngData() else {
      throw PhotoLibrarySaveError.writeFailed
    }

    do {
      try await performSave(pngData)
    } catch {
      throw PhotoLibrarySaveError.writeFailed
    }
  }

  static let live = PhotoLibrarySaver(
    requestAuthorization: {
      let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
      guard status == .notDetermined else { return status }
      return await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    },
    performSave: { pngData in
      let options = PHAssetResourceCreationOptions()
      options.originalFilename = "Adonis-Sticker-\(UUID().uuidString).png"
      options.uniformTypeIdentifier = UTType.png.identifier
      try await PHPhotoLibrary.shared().performChanges {
        let request = PHAssetCreationRequest.forAsset()
        request.addResource(with: .photo, data: pngData, options: options)
      }
    }
  )

  static var configuredForCurrentProcess: PhotoLibrarySaver {
    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("-ui-testing-photo-save-success") {
        return PhotoLibrarySaver(
          requestAuthorization: { .authorized },
          performSave: { _ in }
        )
      }
      if ProcessInfo.processInfo.arguments.contains("-ui-testing-photo-save-denied") {
        return PhotoLibrarySaver(
          requestAuthorization: { .denied },
          performSave: { _ in }
        )
      }
    #endif
    return .live
  }
}

enum PhotoLibrarySaveError: LocalizedError, Equatable {
  case permissionDenied
  case writeFailed

  var errorDescription: String? {
    switch self {
    case .permissionDenied:
      "Adonis 没有获得相册权限。你可以稍后在系统设置里允许添加照片。"
    case .writeFailed:
      "相册这次没有完成写入，可以稍后再试。"
    }
  }

  var eventCode: String {
    switch self {
    case .permissionDenied: "permission_denied"
    case .writeFailed: "write_failed"
    }
  }
}
