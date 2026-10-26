@_exported import SallaPush
import Flutter
import Foundation
import UIKit
import UserNotifications

/// Starts SallaPush natively at launch. `import mobile_push` also gives Swift code the SallaPush iOS API.
@objc public final class SallaPushFlutter: NSObject {
  private override init() {
    super.init()
  }

  /// Call it first in `application(_:didFinishLaunchingWithOptions:)`, on the main thread: with `SallaPushAppId` in
  /// the Info.plist it initializes SallaPush from the Info.plist keys; it forwards the `FlutterAppDelegate`'s push
  /// calls to SallaPush and sets the notification-center delegate when none is set, or only another push SDK's
  /// placeholder. Only the first call does anything.
  @objc public static func start() {
    Starter.shared.start()
  }
}

struct StartEnvironment {
  var infoDictionary: [String: Any]
  var native: NativeSallaPush
  var console: Console
  var appDelegate: () -> UIApplicationDelegate?
  var notificationCenterDelegate: () -> UNUserNotificationCenterDelegate?
  var setNotificationCenterDelegate: (UNUserNotificationCenterDelegate) -> Void
  var lifeCycle: FlutterApplicationLifeCycleDelegate

  static func live() -> StartEnvironment {
    StartEnvironment(
      infoDictionary: Bundle.main.infoDictionary ?? [:],
      native: LiveNativeSallaPush(),
      console: .live,
      appDelegate: { UIApplication.shared.delegate },
      notificationCenterDelegate: { UNUserNotificationCenter.current().delegate },
      setNotificationCenterDelegate: { UNUserNotificationCenter.current().delegate = $0 },
      lifeCycle: SallaPushAppLifeCycle.shared)
  }
}

final class Starter {
  static let shared = Starter(environment: .live())

  private static let notificationCenterMethods = [
    (
      #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:)),
      "userNotificationCenter(_:willPresent:withCompletionHandler:)"
    ),
    (
      #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:)),
      "userNotificationCenter(_:didReceive:withCompletionHandler:)"
    ),
  ]

  private let environment: StartEnvironment
  private(set) var hasStarted = false
  /// The static configuration SallaPush was started with; nil without an app id.
  private(set) var earlyInit: StaticConfig?

  init(environment: StartEnvironment) {
    self.environment = environment
  }

  func start() {
    guard !hasStarted else { return }
    hasStarted = true
    initializeFromStaticConfig()
    let appDelegate = environment.appDelegate()
    registerLifeCycle(with: appDelegate)
    setNotificationCenterDelegate(to: appDelegate)
    checkNotificationCenterOverrides(of: appDelegate)
  }

  /// Plugin registration runs after launch under UIScene, too late for the notification-center delegate.
  func startFromPlugin() {
    if !hasStarted {
      environment.console.error(
        "SallaPushFlutter.start() was not called from AppDelegate. If another plugin already set the "
          + "notification-center delegate, SallaPush receives no taps and no foreground notifications; otherwise the "
          + "tap that launched the app can be missed.")
    }
    start()
  }

  private func initializeFromStaticConfig() {
    let config = StaticConfig(infoDictionary: environment.infoDictionary, console: environment.console)
    guard let appId = config.appId else { return }
    environment.native.initialize(appId: appId, configuration: config.configuration())
    earlyInit = config
  }

  private func registerLifeCycle(with appDelegate: UIApplicationDelegate?) {
    guard let provider = appDelegate as? FlutterAppLifeCycleProvider else {
      environment.console.info(
        "The app delegate is not a FlutterAppDelegate, so SallaPush receives none of its calls. Forward the APNs "
          + "token, the registration failure, didReceiveRemoteNotification, willPresent and didReceive to "
          + "SallaPush.Notifications, as the SallaPush iOS README shows.")
      return
    }
    provider.add(environment.lifeCycle)
  }

  private func setNotificationCenterDelegate(to appDelegate: UIApplicationDelegate?) {
    if let current = environment.notificationCenterDelegate(), !Self.isOneSignalPlaceholder(current) {
      guard current !== appDelegate else { return }
      environment.console.error(
        "\(type(of: current)) is already the notification-center delegate. SallaPush receives taps and foreground "
          + "notifications only when that delegate forwards them to the FlutterAppDelegate or calls "
          + "SallaPush.Notifications itself.")
      return
    }
    if let delegate = appDelegate as? UNUserNotificationCenterDelegate {
      environment.setNotificationCenterDelegate(delegate)
    }
  }

  /// OneSignal iOS sets this placeholder at load when no delegate is set, and hooks into the delegate that replaces it,
  /// as it does with a native app's own delegate.
  private static func isOneSignalPlaceholder(_ delegate: UNUserNotificationCenterDelegate) -> Bool {
    NSStringFromClass(type(of: delegate)) == "OSUNUserNotificationCenterDelegate"
  }

  private func checkNotificationCenterOverrides(of appDelegate: UIApplicationDelegate?) {
    guard let appDelegate = appDelegate as? FlutterAppDelegate else { return }
    let overridden = Self.notificationCenterMethods.filter { selector, _ in
      class_getMethodImplementation(type(of: appDelegate), selector)
        != class_getMethodImplementation(FlutterAppDelegate.self, selector)
    }
    guard !overridden.isEmpty else { return }
    let methods = overridden.map { _, name in name }.joined(separator: " and ")
    environment.console.info(
      "\(type(of: appDelegate)) overrides \(methods). Answer SallaPush's notifications first with "
        + "SallaPush.Notifications, or call super; otherwise SallaPush gets no foreground notifications or taps.")
  }
}
