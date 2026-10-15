import UserNotifications
import XCTest

@testable import Adonis

@MainActor
final class RebloomReminderServiceTests: XCTestCase {
  func testRequestIsPrivateRouteableAndFiresOnceAfterSevenDays() throws {
    let center = ReminderCenterSpy()
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let suggestionID = pairID(1)
    let service = RebloomReminderService(center: center, now: { now })

    XCTAssertEqual(AdonisProcessingVersion.rebloomReminder, "rebloom-reminder-v1")
    XCTAssertEqual(AppEventKind.rebloomReminderScheduled.title, "安排再次盛开提醒")
    XCTAssertEqual(AppEventKind.rebloomReminderCancelled.title, "取消再次盛开提醒")
    XCTAssertEqual(AppEventKind.rebloomReminderOpened.title, "从提醒打开再次盛开")

    let request = service.makeRequest(for: suggestionID)
    let trigger = try XCTUnwrap(request.trigger as? UNTimeIntervalNotificationTrigger)

    XCTAssertEqual(
      request.identifier,
      RebloomReminderService.identifier(for: suggestionID)
    )
    XCTAssertEqual(
      RebloomReminderService.suggestionID(from: request.identifier),
      suggestionID
    )
    XCTAssertEqual(trigger.timeInterval, 7 * 24 * 60 * 60, accuracy: 0.001)
    XCTAssertFalse(trigger.repeats)
    XCTAssertEqual(
      request.content.categoryIdentifier,
      RebloomReminderService.categoryIdentifier
    )
    XCTAssertEqual(request.content.userInfo["route"] as? String, "rebloom")
    XCTAssertFalse(request.content.title.contains("白色上装"))
    XCTAssertFalse(request.content.body.contains("蓝色下装"))
    XCTAssertFalse(request.content.body.contains(suggestionID.topItemID.uuidString))
    XCTAssertFalse(request.content.body.contains(suggestionID.bottomItemID.uuidString))
  }

  func testCheckingStatusDoesNotRequestNotificationPermission() async {
    let center = ReminderCenterSpy()
    let suggestionID = pairID(2)
    let service = RebloomReminderService(center: center)
    center.pending = [service.makeRequest(for: suggestionID)]

    let scheduledDate = await service.scheduledDate(for: suggestionID)

    XCTAssertNotNil(scheduledDate)
    XCTAssertEqual(center.authorizationRequestCount, 0)
    XCTAssertEqual(center.addedRequests.count, 0)
  }

  func testExplicitScheduleRequestsPermissionAndKeepsOnlyOneRebloomReminder() async throws {
    let center = ReminderCenterSpy()
    center.authorization = .notDetermined
    center.authorizationRequestResult = true
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let service = RebloomReminderService(center: center, now: { now })
    let oldPair = pairID(3)
    let newPair = pairID(4)
    let deliveredPair = pairID(9)
    let unrelated = UNNotificationRequest(
      identifier: "another-feature",
      content: UNMutableNotificationContent(),
      trigger: nil
    )
    center.pending = [service.makeRequest(for: oldPair), unrelated]
    center.deliveredIdentifiers = [
      RebloomReminderService.identifier(for: deliveredPair),
      "another-delivered-feature",
    ]

    let fireDate = try await service.schedule(for: newPair)

    XCTAssertEqual(center.authorizationRequestCount, 1)
    XCTAssertEqual(fireDate, now.addingTimeInterval(RebloomReminderService.delay))
    XCTAssertEqual(
      center.removedPendingIdentifiers,
      [RebloomReminderService.identifier(for: oldPair)]
    )
    XCTAssertEqual(center.addedRequests.count, 1)
    XCTAssertEqual(
      center.addedRequests.first?.identifier,
      RebloomReminderService.identifier(for: newPair)
    )
    XCTAssertFalse(center.removedPendingIdentifiers.contains("another-feature"))
    XCTAssertEqual(
      center.removedDeliveredIdentifiers,
      [RebloomReminderService.identifier(for: deliveredPair)]
    )
    XCTAssertFalse(center.removedDeliveredIdentifiers.contains("another-delivered-feature"))
  }

  func testDeniedPermissionDoesNotCreateReminder() async {
    let center = ReminderCenterSpy()
    center.authorization = .denied
    let service = RebloomReminderService(center: center)

    do {
      _ = try await service.schedule(for: pairID(5))
      XCTFail("Expected permission denial")
    } catch {
      XCTAssertEqual(error as? RebloomReminderError, .permissionDenied)
    }

    XCTAssertEqual(center.authorizationRequestCount, 0)
    XCTAssertTrue(center.addedRequests.isEmpty)
  }

  func testFailedReplacementKeepsExistingPendingAndDeliveredReminders() async {
    let center = ReminderCenterSpy()
    center.authorization = .authorized
    center.addError = NSError(domain: "RebloomReminderServiceTests", code: 1)
    let service = RebloomReminderService(center: center)
    let pendingPair = pairID(11)
    let deliveredPair = pairID(12)
    center.pending = [service.makeRequest(for: pendingPair)]
    center.deliveredIdentifiers = [RebloomReminderService.identifier(for: deliveredPair)]

    do {
      _ = try await service.schedule(for: pairID(13))
      XCTFail("Expected scheduling failure")
    } catch {
      XCTAssertEqual(error as? RebloomReminderError, .schedulingFailed)
    }

    XCTAssertEqual(
      center.pending.map(\.identifier),
      [RebloomReminderService.identifier(for: pendingPair)]
    )
    XCTAssertEqual(
      center.deliveredIdentifiers,
      [RebloomReminderService.identifier(for: deliveredPair)]
    )
    XCTAssertTrue(center.removedPendingIdentifiers.isEmpty)
    XCTAssertTrue(center.removedDeliveredIdentifiers.isEmpty)
  }

  func testSynchronizationAndCancellationRemoveOnlyStaleRebloomRequests() async {
    let center = ReminderCenterSpy()
    let service = RebloomReminderService(center: center)
    let valid = pairID(6)
    let stale = pairID(7)
    let staleDelivered = pairID(10)
    center.pending = [
      service.makeRequest(for: valid),
      service.makeRequest(for: stale),
      UNNotificationRequest(
        identifier: "another-feature",
        content: UNMutableNotificationContent(),
        trigger: nil
      ),
    ]
    center.deliveredIdentifiers = [
      RebloomReminderService.identifier(for: valid),
      RebloomReminderService.identifier(for: staleDelivered),
      "another-delivered-feature",
    ]

    await service.synchronize(validSuggestionIDs: [valid])

    XCTAssertEqual(
      center.removedPendingIdentifiers,
      [RebloomReminderService.identifier(for: stale)]
    )
    XCTAssertEqual(
      center.removedDeliveredIdentifiers,
      [RebloomReminderService.identifier(for: staleDelivered)]
    )

    service.cancel(for: valid)
    XCTAssertEqual(
      center.removedPendingIdentifiers,
      [
        RebloomReminderService.identifier(for: stale),
        RebloomReminderService.identifier(for: valid),
      ]
    )
  }

  func testNavigationRouterAcceptsReminderRouteAndConsumesItOnce() throws {
    let router = AppNavigationRouter()
    let suggestionID = pairID(8)

    router.receiveReminderRequest(identifier: "another-feature")
    XCTAssertNil(router.pendingRebloomRoute)

    router.receiveReminderRequest(
      identifier: RebloomReminderService.identifier(for: suggestionID)
    )
    let route = try XCTUnwrap(router.pendingRebloomRoute)
    XCTAssertEqual(route.suggestionID, suggestionID)

    router.consume(route)
    XCTAssertNil(router.pendingRebloomRoute)
  }

  private func pairID(_ seed: UInt8) -> RebloomSuggestionID {
    let top = UUID(uuid: (seed, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    let bottom = UUID(uuid: (seed, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
    return RebloomSuggestionID(topItemID: top, bottomItemID: bottom)
  }
}

@MainActor
private final class ReminderCenterSpy: RebloomNotificationCenterClient {
  var authorization = RebloomReminderAuthorization.notDetermined
  var authorizationRequestResult = false
  var authorizationRequestCount = 0
  var addError: Error?
  var pending: [UNNotificationRequest] = []
  var deliveredIdentifiers: [String] = []
  var addedRequests: [UNNotificationRequest] = []
  var removedPendingIdentifiers: [String] = []
  var removedDeliveredIdentifiers: [String] = []

  func authorizationStatus() async -> RebloomReminderAuthorization {
    authorization
  }

  func requestAuthorization() async throws -> Bool {
    authorizationRequestCount += 1
    if authorizationRequestResult {
      authorization = .authorized
    }
    return authorizationRequestResult
  }

  func pendingNotificationRequests() async -> [UNNotificationRequest] {
    pending
  }

  func deliveredNotificationIdentifiers() async -> [String] {
    deliveredIdentifiers
  }

  func add(_ request: UNNotificationRequest) async throws {
    if let addError {
      throw addError
    }
    addedRequests.append(request)
    pending.append(request)
  }

  func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
    removedPendingIdentifiers.append(contentsOf: identifiers)
    pending.removeAll { identifiers.contains($0.identifier) }
  }

  func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
    removedDeliveredIdentifiers.append(contentsOf: identifiers)
    deliveredIdentifiers.removeAll { identifiers.contains($0) }
  }

  func removeAllPendingNotificationRequests() {
    pending.removeAll()
  }

  func removeAllDeliveredNotifications() {}
}
