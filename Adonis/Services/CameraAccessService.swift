import AVFoundation
import UIKit

enum CameraLaunchOutcome: Equatable {
  case openCamera
  case unavailable
  case permissionDenied
  case restricted
}

@MainActor
struct CameraAccessService {
  let isCameraAvailable: () -> Bool
  let authorizationStatus: () -> AVAuthorizationStatus
  let requestAccess: () async -> Bool

  func resolveLaunchOutcome() async -> CameraLaunchOutcome {
    guard isCameraAvailable() else { return .unavailable }

    switch authorizationStatus() {
    case .authorized:
      return .openCamera
    case .notDetermined:
      return await requestAccess() ? .openCamera : .permissionDenied
    case .denied:
      return .permissionDenied
    case .restricted:
      return .restricted
    @unknown default:
      return .restricted
    }
  }

  static var live: CameraAccessService {
    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("-ui-testing-camera-denied") {
        return CameraAccessService(
          isCameraAvailable: { true },
          authorizationStatus: { .denied },
          requestAccess: { false }
        )
      }
      if ProcessInfo.processInfo.arguments.contains("-ui-testing-camera-restricted") {
        return CameraAccessService(
          isCameraAvailable: { true },
          authorizationStatus: { .restricted },
          requestAccess: { false }
        )
      }
    #endif

    return CameraAccessService(
      isCameraAvailable: {
        UIImagePickerController.isSourceTypeAvailable(.camera)
      },
      authorizationStatus: {
        AVCaptureDevice.authorizationStatus(for: .video)
      },
      requestAccess: {
        await AVCaptureDevice.requestAccess(for: .video)
      }
    )
  }
}
