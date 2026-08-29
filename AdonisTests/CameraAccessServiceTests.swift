import AVFoundation
import XCTest

@testable import Adonis

final class CameraAccessServiceTests: XCTestCase {
  @MainActor
  func testUnavailableCameraDoesNotRequestPermission() async {
    var requestCount = 0
    let service = CameraAccessService(
      isCameraAvailable: { false },
      authorizationStatus: { .notDetermined },
      requestAccess: {
        requestCount += 1
        return true
      }
    )

    let outcome = await service.resolveLaunchOutcome()

    XCTAssertEqual(outcome, .unavailable)
    XCTAssertEqual(requestCount, 0)
  }

  @MainActor
  func testAuthorizedCameraOpensWithoutRequestingAgain() async {
    var requestCount = 0
    let service = CameraAccessService(
      isCameraAvailable: { true },
      authorizationStatus: { .authorized },
      requestAccess: {
        requestCount += 1
        return true
      }
    )

    let outcome = await service.resolveLaunchOutcome()

    XCTAssertEqual(outcome, .openCamera)
    XCTAssertEqual(requestCount, 0)
  }

  @MainActor
  func testUndeterminedCameraRequestsOnceAndOpensWhenGranted() async {
    var requestCount = 0
    let service = CameraAccessService(
      isCameraAvailable: { true },
      authorizationStatus: { .notDetermined },
      requestAccess: {
        requestCount += 1
        return true
      }
    )

    let outcome = await service.resolveLaunchOutcome()

    XCTAssertEqual(outcome, .openCamera)
    XCTAssertEqual(requestCount, 1)
  }

  @MainActor
  func testUndeterminedCameraBecomesRecoverableDenialWhenDeclined() async {
    let service = CameraAccessService(
      isCameraAvailable: { true },
      authorizationStatus: { .notDetermined },
      requestAccess: { false }
    )

    let outcome = await service.resolveLaunchOutcome()

    XCTAssertEqual(outcome, .permissionDenied)
  }

  @MainActor
  func testDeniedAndRestrictedStatesStayDistinct() async {
    let denied = CameraAccessService(
      isCameraAvailable: { true },
      authorizationStatus: { .denied },
      requestAccess: { true }
    )
    let restricted = CameraAccessService(
      isCameraAvailable: { true },
      authorizationStatus: { .restricted },
      requestAccess: { true }
    )

    let deniedOutcome = await denied.resolveLaunchOutcome()
    let restrictedOutcome = await restricted.resolveLaunchOutcome()

    XCTAssertEqual(deniedOutcome, .permissionDenied)
    XCTAssertEqual(restrictedOutcome, .restricted)
  }
}
