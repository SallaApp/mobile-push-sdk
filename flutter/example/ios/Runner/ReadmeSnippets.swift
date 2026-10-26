import Flutter
import UIKit
import UserNotifications
import mobile_push

/// The setup guide's AppDelegate methods for apps with other push SDKs, compiled so that they stay correct. The app
/// never uses it.
final class OtherPushSDKsAppDelegate: FlutterAppDelegate {
  // snippet:other-push-sdks
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if let options = SallaPush.Notifications.willPresent(notification) {
      completionHandler(options)
      return
    }
    super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if SallaPush.Notifications.didReceive(response) {
      completionHandler()
      return
    }
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    SallaPush.Notifications.didReceiveRemoteNotification(userInfo)
    completionHandler(.noData)
  }
  // end-snippet
}
