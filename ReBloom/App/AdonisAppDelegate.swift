import UIKit
import UserNotifications

final class AdonisAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return true
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    guard
      RebloomReminderService.suggestionID(
        from: notification.request.identifier
      ) != nil
    else {
      completionHandler([])
      return
    }
    completionHandler([.banner, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let identifier = response.notification.request.identifier
    if RebloomReminderService.suggestionID(from: identifier) != nil {
      Task { @MainActor in
        AppNavigationRouter.shared.receiveReminderRequest(identifier: identifier)
        completionHandler()
      }
    } else {
      completionHandler()
    }
  }
}
