import Flutter
import Foundation
import UserNotifications

/// The smoke tests' hooks (integration_test/sallapush_smoke_test.dart) on the `example/test_hooks` channel. They are
/// example code: an app never needs them, and the README's `AppDelegate` leaves their registration out.
enum TestHooks {
  static func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "SallaPushExampleTestHooks") else { return }
    let channel = FlutterMethodChannel(name: "example/test_hooks", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "deliverTestNotification":
        deliverTestNotification(call.arguments, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Posts a local notification whose `userInfo` is the APNs payload in `arguments`. In the foreground, iOS hands it to
  /// the notification-center delegate as it does a push, when the app may show notifications.
  private static func deliverTestNotification(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let payload = arguments as? [String: Any] else {
      result(FlutterError(code: "invalid_arguments", message: "The APNs payload must be a map.", details: nil))
      return
    }
    let alert = (payload["aps"] as? [String: Any])?["alert"] as? [String: Any]
    let content = UNMutableNotificationContent()
    content.title = alert?["title"] as? String ?? ""
    content.body = alert?["body"] as? String ?? ""
    content.userInfo = payload
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { error in
      DispatchQueue.main.async {
        if let error {
          result(FlutterError(code: "not_delivered", message: error.localizedDescription, details: nil))
        } else {
          result(nil)
        }
      }
    }
  }
}
