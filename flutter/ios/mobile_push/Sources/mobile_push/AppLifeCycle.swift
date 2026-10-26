import Flutter
import UIKit
import UserNotifications

/// The app delegate calls a native app forwards to SallaPush; `start()` registers it before any plugin.
final class SallaPushAppLifeCycle: NSObject, FlutterApplicationLifeCycleDelegate {
  /// Flutter holds life-cycle delegates weakly.
  static let shared = SallaPushAppLifeCycle(native: LiveNativeSallaPush())

  private let native: NativeSallaPush

  init(native: NativeSallaPush) {
    self.native = native
  }

  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    native.didRegisterForRemoteNotifications(deviceToken: deviceToken)
  }

  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    native.didFailToRegisterForRemoteNotifications(error: error)
  }

  /// Flutter stops this fan-out at the first plugin that returns true, so other payloads go on to the next one.
  func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) -> Bool {
    guard native.didReceiveRemoteNotification(userInfo) else { return false }
    completionHandler(.noData)
    return true
  }

  /// Only SallaPush's notifications: the plugin that owns a notification completes it.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if let options = native.willPresent(notification) {
      completionHandler(options)
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if native.didReceive(response) {
      completionHandler()
    }
  }
}
