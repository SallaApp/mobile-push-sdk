import Flutter
import UIKit
import UserNotifications
import XCTest

@testable import mobile_push

final class StartTests: XCTestCase {
  private let native = FakeNativeSallaPush()
  private let recorder = ConsoleRecorder()
  private let notificationCenter = NotificationCenterSlot()
  private let lifeCycle = SallaPushAppLifeCycle(native: FakeNativeSallaPush())

  private func starter(_ infoDictionary: [String: Any] = [:], appDelegate: UIApplicationDelegate?) -> Starter {
    let slot = notificationCenter
    return Starter(
      environment: StartEnvironment(
        infoDictionary: infoDictionary,
        native: native,
        console: recorder.console,
        appDelegate: { appDelegate },
        notificationCenterDelegate: { slot.delegate },
        setNotificationCenterDelegate: { slot.delegate = $0 },
        lifeCycle: lifeCycle))
  }

  func testTheExampleAppStartedSallaPushAtLaunch() {
    XCTAssertTrue(Starter.shared.hasStarted)
  }

  func testTheExampleAppDelegateIsTheNotificationCenterDelegate() {
    XCTAssertTrue(UNUserNotificationCenter.current().delegate === UIApplication.shared.delegate)
  }

  func testTheExampleAppDelegateForwardsRemoteNotificationsToSallaPush() {
    let selector = #selector(
      UIApplicationDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:))
    // FlutterAppDelegate answers this selector only for a registered life-cycle delegate that implements it.
    XCTAssertEqual(UIApplication.shared.delegate?.responds(to: selector), true)
  }

  func testInitializesOnceFromTheInfoDictionary() throws {
    let starter = starter(
      ["SallaPushAppId": "st_42_ios", "SallaPushOpenLaunchURLs": "YES"], appDelegate: LifeCycleProviderAppDelegate())

    starter.start()
    starter.start()

    XCTAssertEqual(native.initializations.count, 1)
    let initialization = try XCTUnwrap(native.initializations.first)
    XCTAssertEqual(initialization.appId, "st_42_ios")
    XCTAssertTrue(initialization.configuration.openLaunchURLs)
    XCTAssertTrue(starter.hasStarted)
  }

  func testInitializesWithTheBadgeSettingsOfTheInfoDictionary() throws {
    // Different values, so that a swap of the two keys fails.
    let starter = starter(
      ["SallaPushAppId": "st_42_ios", "SallaPushAutoClearBadge": false, "SallaPushAutoUpdateBadge": "YES"],
      appDelegate: LifeCycleProviderAppDelegate())

    starter.start()

    let configuration = try XCTUnwrap(native.initializations.first?.configuration)
    XCTAssertFalse(configuration.autoClearBadge)
    XCTAssertTrue(configuration.autoUpdateBadge)
    XCTAssertEqual(
      starter.earlyInit, StaticConfig(appId: "st_42_ios", autoClearBadge: false, autoUpdateBadge: true))
  }

  func testRecordsTheConfigurationSallaPushStartedWith() {
    let starter = starter(
      ["SallaPushAppId": "st_42_ios", "SallaPushRequiresUserConsent": true],
      appDelegate: LifeCycleProviderAppDelegate())

    starter.start()

    XCTAssertEqual(starter.earlyInit, StaticConfig(appId: "st_42_ios", requiresUserConsent: true))
  }

  func testInitializesNothingWithoutAnAppId() {
    let starter = starter(
      ["SallaPushAppId": "", "SallaPushOpenLaunchURLs": true], appDelegate: LifeCycleProviderAppDelegate())

    starter.start()

    XCTAssertTrue(native.initializations.isEmpty)
    XCTAssertNil(starter.earlyInit)
    XCTAssertTrue(starter.hasStarted)
    XCTAssertEqual(recorder.lines, [])
  }

  func testRegistersTheLifeCycleObjectOnce() {
    let appDelegate = LifeCycleProviderAppDelegate()
    let starter = starter(appDelegate: appDelegate)

    starter.start()
    starter.start()

    XCTAssertEqual(appDelegate.lifeCycleDelegates.count, 1)
    XCTAssertTrue(appDelegate.lifeCycleDelegates.first === lifeCycle)
  }

  func testRemindsToForwardTheCallsWhenTheAppDelegateIsNotAFlutterAppDelegate() {
    let appDelegate = PlainAppDelegate()

    starter(appDelegate: appDelegate).start()

    XCTAssertEqual(
      recorder.lines,
      [
        .init(
          level: .info,
          message: "The app delegate is not a FlutterAppDelegate, so SallaPush receives none of its calls. Forward the "
            + "APNs token, the registration failure, didReceiveRemoteNotification, willPresent and didReceive to "
            + "SallaPush.Notifications, as the SallaPush iOS README shows.")
      ])
    XCTAssertNil(notificationCenter.delegate)
  }

  func testMakesTheAppDelegateTheNotificationCenterDelegateWhenNoneIsSet() {
    let appDelegate = LifeCycleProviderAppDelegate()

    starter(appDelegate: appDelegate).start()

    XCTAssertTrue(notificationCenter.delegate === appDelegate)
    XCTAssertEqual(recorder.lines, [])
  }

  func testKeepsAnotherNotificationCenterDelegateAndReportsIt() {
    let other = OtherNotificationCenterDelegate()
    notificationCenter.delegate = other

    starter(appDelegate: LifeCycleProviderAppDelegate()).start()

    XCTAssertTrue(notificationCenter.delegate === other)
    XCTAssertEqual(
      recorder.lines,
      [
        .init(
          level: .error,
          message: "OtherNotificationCenterDelegate is already the notification-center delegate. SallaPush receives "
            + "taps and foreground notifications only when that delegate forwards them to the FlutterAppDelegate or "
            + "calls SallaPush.Notifications itself.")
      ])
  }

  func testReplacesOneSignalsPlaceholderDelegateWithTheAppDelegate() {
    let appDelegate = LifeCycleProviderAppDelegate()
    notificationCenter.delegate = OneSignalPlaceholderDelegate()

    starter(appDelegate: appDelegate).start()

    XCTAssertTrue(notificationCenter.delegate === appDelegate)
    XCTAssertEqual(recorder.lines, [])
  }

  func testAcceptsTheAppDelegateAlreadyBeingTheNotificationCenterDelegate() {
    let appDelegate = LifeCycleProviderAppDelegate()
    notificationCenter.delegate = appDelegate

    starter(appDelegate: appDelegate).start()

    XCTAssertTrue(notificationCenter.delegate === appDelegate)
    XCTAssertEqual(recorder.lines, [])
  }

  func testAcceptsAFlutterAppDelegateThatOverridesNoNotificationCenterMethod() {
    starter(appDelegate: FlutterAppDelegate()).start()

    XCTAssertEqual(recorder.lines, [])
  }

  func testReportsAnOverriddenWillPresent() {
    starter(appDelegate: WillPresentAppDelegate()).start()

    XCTAssertEqual(
      recorder.lines,
      [
        .init(
          level: .info,
          message: "WillPresentAppDelegate overrides userNotificationCenter(_:willPresent:withCompletionHandler:). "
            + "Answer SallaPush's notifications first with SallaPush.Notifications, or call super; otherwise SallaPush "
            + "gets no foreground notifications or taps.")
      ])
  }

  func testReportsOverriddenWillPresentAndDidReceive() {
    starter(appDelegate: NotificationCenterAppDelegate()).start()

    XCTAssertEqual(recorder.lines.count, 1)
    XCTAssertEqual(recorder.lines.first?.level, .info)
    XCTAssertTrue(
      recorder.lines.first?.message.hasPrefix(
        "NotificationCenterAppDelegate overrides userNotificationCenter(_:willPresent:withCompletionHandler:) and "
          + "userNotificationCenter(_:didReceive:withCompletionHandler:).") == true)
  }

  func testStartsLateFromThePluginWithAnError() {
    let appDelegate = LifeCycleProviderAppDelegate()
    let starter = starter(["SallaPushAppId": "st_42_ios"], appDelegate: appDelegate)

    starter.startFromPlugin()

    XCTAssertTrue(starter.hasStarted)
    XCTAssertEqual(native.initializations.count, 1)
    XCTAssertEqual(appDelegate.lifeCycleDelegates.count, 1)
    XCTAssertEqual(
      recorder.lines,
      [
        .init(
          level: .error,
          message: "SallaPushFlutter.start() was not called from AppDelegate. If another plugin already set the "
            + "notification-center delegate, SallaPush receives no taps and no foreground notifications; otherwise "
            + "the tap that launched the app can be missed.")
      ])
  }

  func testThePluginChangesNothingAfterTheAppDelegateStartedSallaPush() {
    let appDelegate = LifeCycleProviderAppDelegate()
    let starter = starter(["SallaPushAppId": "st_42_ios"], appDelegate: appDelegate)

    starter.start()
    starter.startFromPlugin()

    XCTAssertEqual(native.initializations.count, 1)
    XCTAssertEqual(appDelegate.lifeCycleDelegates.count, 1)
    XCTAssertEqual(recorder.lines, [])
  }
}

private final class PlainAppDelegate: NSObject, UIApplicationDelegate {}

private final class OtherNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {}

/// OneSignal iOS's placeholder delegate, by its Objective-C name.
@objc(OSUNUserNotificationCenterDelegate)
private final class OneSignalPlaceholderDelegate: NSObject, UNUserNotificationCenterDelegate {}

// The overrides only call super: they make start() see an app delegate that overrides these methods.
// swiftlint:disable unneeded_override
private final class WillPresentAppDelegate: FlutterAppDelegate {
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
  }
}

private final class NotificationCenterAppDelegate: FlutterAppDelegate {
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}
// swiftlint:enable unneeded_override
