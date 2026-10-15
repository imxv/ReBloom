import Foundation
import UserNotifications

enum RebloomReminderAuthorization: Equatable {
  case notDetermined
  case denied
  case authorized
}

enum RebloomReminderError: LocalizedError, Equatable {
  case permissionDenied
  case authorizationFailed
  case schedulingFailed

  var errorDescription: String? {
    switch self {
    case .permissionDenied:
      "通知没有打开。原搭配不会改变；需要时可以在系统设置里允许 ReBloom 通知。"
    case .authorizationFailed:
      "暂时无法确认通知权限。原搭配不会改变，请稍后再试。"
    case .schedulingFailed:
      "这次提醒没有约好。原搭配不会改变，请稍后再试。"
    }
  }
}

@MainActor
protocol RebloomNotificationCenterClient: AnyObject {
  func authorizationStatus() async -> RebloomReminderAuthorization
  func requestAuthorization() async throws -> Bool
  func pendingNotificationRequests() async -> [UNNotificationRequest]
  func deliveredNotificationIdentifiers() async -> [String]
  func add(_ request: UNNotificationRequest) async throws
  func removePendingNotificationRequests(withIdentifiers identifiers: [String])
  func removeDeliveredNotifications(withIdentifiers identifiers: [String])
  func removeAllPendingNotificationRequests()
  func removeAllDeliveredNotifications()
}

@MainActor
struct RebloomReminderService {
  static let delay: TimeInterval = 7 * 24 * 60 * 60
  static let categoryIdentifier = "ADONIS_REBLOOM_REMINDER"
  static let processingVersion = AdonisProcessingVersion.rebloomReminder

  private static let identifierPrefix = "adonis.rebloom.once."

  private let center: any RebloomNotificationCenterClient
  private let now: () -> Date

  init(
    center: any RebloomNotificationCenterClient,
    now: @escaping () -> Date = Date.init
  ) {
    self.center = center
    self.now = now
  }

  static var live: RebloomReminderService {
    #if DEBUG
      let arguments = ProcessInfo.processInfo.arguments
      if arguments.contains("-ui-testing-rebloom-reminder-authorized") {
        return RebloomReminderService(center: UITestRebloomNotificationCenter.authorized)
      }
      if arguments.contains("-ui-testing-rebloom-reminder-denied") {
        return RebloomReminderService(center: UITestRebloomNotificationCenter.denied)
      }
    #endif
    return RebloomReminderService(center: SystemRebloomNotificationCenter.shared)
  }

  static func identifier(for suggestionID: RebloomSuggestionID) -> String {
    identifierPrefix
      + suggestionID.topItemID.uuidString.lowercased()
      + "."
      + suggestionID.bottomItemID.uuidString.lowercased()
  }

  static func suggestionID(from identifier: String) -> RebloomSuggestionID? {
    guard identifier.hasPrefix(identifierPrefix) else { return nil }
    let suffix = identifier.dropFirst(identifierPrefix.count)
    let components = suffix.split(separator: ".", omittingEmptySubsequences: false)
    guard components.count == 2,
      let topItemID = UUID(uuidString: String(components[0])),
      let bottomItemID = UUID(uuidString: String(components[1]))
    else {
      return nil
    }
    return RebloomSuggestionID(topItemID: topItemID, bottomItemID: bottomItemID)
  }

  func makeRequest(for suggestionID: RebloomSuggestionID) -> UNNotificationRequest {
    let content = UNMutableNotificationContent()
    content.title = "一组真实搭配可以再次盛开"
    content.body = "打开 ReBloom，直接看看那组由过往穿着重组的搭配。"
    content.sound = .default
    content.categoryIdentifier = Self.categoryIdentifier
    content.threadIdentifier = "adonis.rebloom"
    content.userInfo = ["route": "rebloom"]

    let trigger = UNTimeIntervalNotificationTrigger(
      timeInterval: Self.delay,
      repeats: false
    )
    return UNNotificationRequest(
      identifier: Self.identifier(for: suggestionID),
      content: content,
      trigger: trigger
    )
  }

  func scheduledDate(for suggestionID: RebloomSuggestionID) async -> Date? {
    let identifier = Self.identifier(for: suggestionID)
    guard
      let request = await center.pendingNotificationRequests().first(where: {
        $0.identifier == identifier
      }),
      let trigger = request.trigger as? UNTimeIntervalNotificationTrigger
    else {
      return nil
    }
    return trigger.nextTriggerDate() ?? now().addingTimeInterval(trigger.timeInterval)
  }

  func schedule(for suggestionID: RebloomSuggestionID) async throws -> Date {
    switch await center.authorizationStatus() {
    case .notDetermined:
      do {
        guard try await center.requestAuthorization() else {
          throw RebloomReminderError.permissionDenied
        }
      } catch let error as RebloomReminderError {
        throw error
      } catch {
        throw RebloomReminderError.authorizationFailed
      }
    case .denied:
      throw RebloomReminderError.permissionDenied
    case .authorized:
      break
    }

    do {
      try await center.add(makeRequest(for: suggestionID))
    } catch {
      throw RebloomReminderError.schedulingFailed
    }

    let newIdentifier = Self.identifier(for: suggestionID)
    let oldPendingIdentifiers: [String] = await center.pendingNotificationRequests().compactMap {
      request in
      guard request.identifier != newIdentifier,
        Self.suggestionID(from: request.identifier) != nil
      else { return nil }
      return request.identifier
    }
    if !oldPendingIdentifiers.isEmpty {
      center.removePendingNotificationRequests(withIdentifiers: oldPendingIdentifiers)
    }

    let deliveredIdentifiers = await center.deliveredNotificationIdentifiers().filter {
      Self.suggestionID(from: $0) != nil
    }
    if !deliveredIdentifiers.isEmpty {
      center.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)
    }
    return now().addingTimeInterval(Self.delay)
  }

  func cancel(for suggestionID: RebloomSuggestionID) {
    let identifier = Self.identifier(for: suggestionID)
    center.removePendingNotificationRequests(withIdentifiers: [identifier])
    center.removeDeliveredNotifications(withIdentifiers: [identifier])
  }

  func synchronize(validSuggestionIDs: Set<RebloomSuggestionID>) async {
    let stalePendingIdentifiers: [String] = await center.pendingNotificationRequests().compactMap {
      request in
      guard let suggestionID = Self.suggestionID(from: request.identifier) else { return nil }
      return validSuggestionIDs.contains(suggestionID) ? nil : request.identifier
    }
    if !stalePendingIdentifiers.isEmpty {
      center.removePendingNotificationRequests(withIdentifiers: stalePendingIdentifiers)
    }

    let staleDeliveredIdentifiers = await center.deliveredNotificationIdentifiers().filter {
      identifier in
      guard let suggestionID = Self.suggestionID(from: identifier) else { return false }
      return !validSuggestionIDs.contains(suggestionID)
    }
    if !staleDeliveredIdentifiers.isEmpty {
      center.removeDeliveredNotifications(withIdentifiers: staleDeliveredIdentifiers)
    }
  }
}

@MainActor
private final class SystemRebloomNotificationCenter: RebloomNotificationCenterClient {
  static let shared = SystemRebloomNotificationCenter()

  private let center = UNUserNotificationCenter.current()

  func authorizationStatus() async -> RebloomReminderAuthorization {
    let settings = await center.notificationSettings()
    switch settings.authorizationStatus {
    case .notDetermined:
      return .notDetermined
    case .denied:
      return .denied
    case .authorized, .provisional, .ephemeral:
      return .authorized
    @unknown default:
      return .denied
    }
  }

  func requestAuthorization() async throws -> Bool {
    try await center.requestAuthorization(options: [.alert, .sound])
  }

  func pendingNotificationRequests() async -> [UNNotificationRequest] {
    await center.pendingNotificationRequests()
  }

  func deliveredNotificationIdentifiers() async -> [String] {
    await center.deliveredNotifications().map(\.request.identifier)
  }

  func add(_ request: UNNotificationRequest) async throws {
    try await center.add(request)
  }

  func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
    center.removePendingNotificationRequests(withIdentifiers: identifiers)
  }

  func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
    center.removeDeliveredNotifications(withIdentifiers: identifiers)
  }

  func removeAllPendingNotificationRequests() {
    center.removeAllPendingNotificationRequests()
  }

  func removeAllDeliveredNotifications() {
    center.removeAllDeliveredNotifications()
  }
}

protocol RebloomReminderCleaning {
  func removeAllRebloomReminders()
}

struct SystemRebloomReminderCleaner: RebloomReminderCleaning {
  func removeAllRebloomReminders() {
    let center = UNUserNotificationCenter.current()
    center.removeAllPendingNotificationRequests()
    center.removeAllDeliveredNotifications()
  }
}

#if DEBUG
  @MainActor
  private final class UITestRebloomNotificationCenter: RebloomNotificationCenterClient {
    static let authorized = UITestRebloomNotificationCenter(authorization: .authorized)
    static let denied = UITestRebloomNotificationCenter(authorization: .denied)

    private var authorization: RebloomReminderAuthorization
    private var requests: [UNNotificationRequest] = []

    private init(authorization: RebloomReminderAuthorization) {
      self.authorization = authorization
    }

    func authorizationStatus() async -> RebloomReminderAuthorization {
      authorization
    }

    func requestAuthorization() async throws -> Bool {
      authorization == .authorized
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
      requests
    }

    func deliveredNotificationIdentifiers() async -> [String] {
      []
    }

    func add(_ request: UNNotificationRequest) async throws {
      requests.removeAll { $0.identifier == request.identifier }
      requests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
      requests.removeAll { identifiers.contains($0.identifier) }
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {}

    func removeAllPendingNotificationRequests() {
      requests.removeAll()
    }

    func removeAllDeliveredNotifications() {}
  }
#endif
