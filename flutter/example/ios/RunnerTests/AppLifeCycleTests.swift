import UIKit
import UserNotifications
import XCTest

@testable import mobile_push

final class AppLifeCycleTests: XCTestCase {
  private let native = FakeNativeSallaPush()
  private lazy var lifeCycle = SallaPushAppLifeCycle(native: native)

  private struct RegistrationError: Error {}

  func testForwardsTheApnsToken() {
    let token = Data(repeating: 0xAB, count: 32)

    lifeCycle.application(UIApplication.shared, didRegisterForRemoteNotificationsWithDeviceToken: token)

    XCTAssertEqual(native.deviceTokens, [token])
  }

  func testForwardsTheRegistrationFailure() {
    lifeCycle.application(UIApplication.shared, didFailToRegisterForRemoteNotificationsWithError: RegistrationError())

    XCTAssertEqual(native.registrationErrors.count, 1)
    XCTAssertTrue(native.registrationErrors.first is RegistrationError)
  }

  func testClaimsAndCompletesSallaPushRemoteNotificationsOnce() throws {
    for name in ["native", "compat"] {
      var results: [UIBackgroundFetchResult] = []

      let claimed = lifeCycle.application(
        UIApplication.shared,
        didReceiveRemoteNotification: try TestNotifications.payload(named: name),
        fetchCompletionHandler: { results.append($0) })

      XCTAssertTrue(claimed, name)
      XCTAssertEqual(results, [.noData], name)
    }
    XCTAssertEqual(native.remoteNotifications.count, 2)
  }

  func testLeavesOtherRemoteNotificationsToTheNextPlugin() {
    var completions = 0

    let claimed = lifeCycle.application(
      UIApplication.shared,
      didReceiveRemoteNotification: TestNotifications.foreignPayload,
      fetchCompletionHandler: { _ in completions += 1 })

    XCTAssertFalse(claimed)
    XCTAssertEqual(completions, 0)
    XCTAssertEqual(native.remoteNotifications.count, 1)
  }

  func testCompletesASallaPushForegroundNotificationOnceWithSallaPushsOptions() throws {
    for name in ["native", "compat"] {
      let notification = try TestNotifications.notification(userInfo: try TestNotifications.payload(named: name))
      var answers: [UNNotificationPresentationOptions] = []

      lifeCycle.userNotificationCenter(
        UNUserNotificationCenter.current(), willPresent: notification, withCompletionHandler: { answers.append($0) })

      XCTAssertEqual(answers, [FakeNativeSallaPush.options], name)
      XCTAssertTrue(native.presentedNotifications.last === notification, name)
    }
  }

  func testNeverCompletesAnotherSdksForegroundNotification() throws {
    let notification = try TestNotifications.notification(userInfo: TestNotifications.foreignPayload)
    var completions = 0

    lifeCycle.userNotificationCenter(
      UNUserNotificationCenter.current(), willPresent: notification, withCompletionHandler: { _ in completions += 1 })

    XCTAssertEqual(completions, 0)
    XCTAssertEqual(native.presentedNotifications.count, 1)
  }

  func testCompletesASallaPushTapOnce() throws {
    for name in ["native", "compat"] {
      let response = try TestNotifications.response(userInfo: try TestNotifications.payload(named: name))
      var completions = 0

      lifeCycle.userNotificationCenter(
        UNUserNotificationCenter.current(), didReceive: response, withCompletionHandler: { completions += 1 })

      XCTAssertEqual(completions, 1, name)
      XCTAssertTrue(native.responses.last === response, name)
    }
  }

  func testNeverCompletesAnotherSdksTap() throws {
    let response = try TestNotifications.response(userInfo: TestNotifications.foreignPayload)
    var completions = 0

    lifeCycle.userNotificationCenter(
      UNUserNotificationCenter.current(), didReceive: response, withCompletionHandler: { completions += 1 })

    XCTAssertEqual(completions, 0)
    XCTAssertEqual(native.responses.count, 1)
  }

  func testRecognisesTheTestPayloadsAsSallaPushNotifications() throws {
    XCTAssertTrue(SallaPush.Notifications.isSallaPushNotification(try TestNotifications.payload(named: "native")))
    XCTAssertTrue(SallaPush.Notifications.isSallaPushNotification(try TestNotifications.payload(named: "compat")))
    XCTAssertFalse(SallaPush.Notifications.isSallaPushNotification(TestNotifications.foreignPayload))
  }
}
