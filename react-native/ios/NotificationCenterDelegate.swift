import Foundation
import SallaPush
import UserNotifications

/// The notification center whose delegate `SallaPushRN.start()` sets. Tests replace it with a fake.
protocol UserNotificationCenter: AnyObject {
    var delegate: UNUserNotificationCenterDelegate? { get set }
}

extension UNUserNotificationCenter: UserNotificationCenter {}

/// The delegate `SallaPushRN.start()` installs. SallaPush's notifications go to native's ready-made delegate, which
/// completes each once; other notifications go to the delegate that was set before, so other SDKs keep working.
final class SallaPushRNNotificationCenterDelegate: SallaPushNotificationCenterDelegate {
    static let shared = SallaPushRNNotificationCenterDelegate()

    /// The delegate set before SallaPush's, held strongly: the notification center holds its delegate weakly.
    var previous: UNUserNotificationCenterDelegate?

    override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                         withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let selector = #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:))
        if let previous = previous(respondingTo: selector, for: notification) {
            // The placeholder delegate of a swizzling SDK would run that SDK's handling a second time: its swizzling
            // already ran it on this delegate, and completes its notifications right after this method returns. Others
            // get the defaults.
            guard NSStringFromClass(type(of: previous)) != "OSUNUserNotificationCenterDelegate" else {
                DispatchQueue.main.async {
                    super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
                }
                return
            }
            previous.userNotificationCenter?(center, willPresent: notification, withCompletionHandler: completionHandler)
            return
        }
        super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
    }

    override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                         withCompletionHandler completionHandler: @escaping () -> Void) {
        let selector = #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:))
        if let previous = previous(respondingTo: selector, for: response.notification) {
            previous.userNotificationCenter?(center, didReceive: response, withCompletionHandler: completionHandler)
            return
        }
        super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, openSettingsFor notification: UNNotification?) {
        previous?.userNotificationCenter?(center, openSettingsFor: notification)
    }

    /// The previous delegate when it handles `selector` and the notification isn't SallaPush's.
    private func previous(respondingTo selector: Selector, for notification: UNNotification) -> UNUserNotificationCenterDelegate? {
        guard let previous, previous.responds(to: selector),
              !SallaPush.Notifications.isSallaPushNotification(notification.request.content.userInfo) else { return nil }
        return previous
    }
}
