import SallaPush
@testable import SallaPushReactNative
import UserNotifications
import XCTest

final class NotificationCenterDelegateTests: XCTestCase {
    private let center = UNUserNotificationCenter.current()
    private let delegate = SallaPushRNNotificationCenterDelegate()

    func testAForeignNotificationIsPresentedByThePreviousDelegateOnly() throws {
        let previous = RecordingNotificationCenterDelegate(presentationOptions: [.sound])
        delegate.previous = previous

        let options = present(try TestNotifications.notification(userInfo: TestNotifications.foreign))

        XCTAssertEqual(options, [[.sound]])
        XCTAssertEqual(previous.presented.count, 1)
    }

    func testANativeSallaPushNotificationIsPresentedBySallaPushOnce() throws {
        try assertSallaPushPresents(TestNotifications.payload("native"))
    }

    func testACompatibleSallaPushNotificationIsPresentedBySallaPushOnce() throws {
        try assertSallaPushPresents(TestNotifications.payload("compat"))
    }

    func testWithoutAPreviousDelegateAForeignNotificationGetsTheDefaultOptions() throws {
        let options = present(try TestNotifications.notification(userInfo: TestNotifications.foreign))

        XCTAssertEqual(options, [[.banner, .list, .sound, .badge]])
    }

    func testAPreviousDelegateThatDoesNotPresentLeavesForeignNotificationsToTheDefault() throws {
        let previous = TapOnlyNotificationCenterDelegate()
        delegate.previous = previous

        let options = present(try TestNotifications.notification(userInfo: TestNotifications.foreign))

        XCTAssertEqual(options, [[.banner, .list, .sound, .badge]])
    }

    func testAForeignTapGoesToThePreviousDelegateOnly() throws {
        let previous = RecordingNotificationCenterDelegate()
        delegate.previous = previous

        let completions = receive(try TestNotifications.response(userInfo: TestNotifications.foreign))

        XCTAssertEqual(completions, 1)
        XCTAssertEqual(previous.received.count, 1)
    }

    func testASallaPushTapGoesToSallaPushAndCompletesOnce() throws {
        let previous = RecordingNotificationCenterDelegate()
        delegate.previous = previous

        let completions = receive(try TestNotifications.response(userInfo: TestNotifications.payload("native")))

        XCTAssertEqual(completions, 1)
        XCTAssertTrue(previous.received.isEmpty)
    }

    func testWithoutAPreviousDelegateATapCompletesOnce() throws {
        XCTAssertEqual(receive(try TestNotifications.response(userInfo: TestNotifications.foreign)), 1)
        XCTAssertEqual(receive(try TestNotifications.response(userInfo: TestNotifications.payload("compat"))), 1)
    }

    func testATapPreviousDelegateStillGetsForeignTaps() throws {
        let previous = TapOnlyNotificationCenterDelegate()
        delegate.previous = previous

        let completions = receive(try TestNotifications.response(userInfo: TestNotifications.foreign))

        XCTAssertEqual(completions, 1)
        XCTAssertEqual(previous.received.count, 1)
    }

    // OneSignal's swizzled willPresent already ran OneSignal's handling on this delegate, and completes OneSignal's own
    // notifications right after it returns; its placeholder would run that handling a second time.
    func testAForeignNotificationIsNotForwardedToOneSignalsPlaceholderAndGetsTheDefaultOptionsOnce() throws {
        let placeholder = OneSignalPlaceholderDelegate()
        delegate.previous = placeholder
        let completed = expectation(description: "completed")
        var options: [UNNotificationPresentationOptions] = []

        delegate.userNotificationCenter(center, willPresent: try TestNotifications.notification(userInfo: TestNotifications.foreign)) {
            options.append($0)
            completed.fulfill()
        }

        XCTAssertTrue(options.isEmpty)
        wait(for: [completed], timeout: 5)
        XCTAssertEqual(options, [[.banner, .list, .sound, .badge]])
        XCTAssertTrue(placeholder.presented.isEmpty)
    }

    func testASallaPushNotificationCompletesAtOnceWithOneSignalsPlaceholder() throws {
        let placeholder = OneSignalPlaceholderDelegate()
        delegate.previous = placeholder

        let options = present(try TestNotifications.notification(userInfo: TestNotifications.payload("native")))

        XCTAssertEqual(options.count, 1)
        XCTAssertTrue(placeholder.presented.isEmpty)
    }

    func testAForeignTapStillGoesToOneSignalsPlaceholder() throws {
        let placeholder = OneSignalPlaceholderDelegate()
        delegate.previous = placeholder

        let completions = receive(try TestNotifications.response(userInfo: TestNotifications.foreign))

        XCTAssertEqual(completions, 1)
        XCTAssertEqual(placeholder.received.count, 1)
    }

    func testOpenSettingsIsForwardedToThePreviousDelegate() throws {
        let previous = RecordingNotificationCenterDelegate()
        delegate.previous = previous
        let notification = try TestNotifications.notification(userInfo: TestNotifications.foreign)

        (delegate as UNUserNotificationCenterDelegate).userNotificationCenter?(center, openSettingsFor: notification)

        XCTAssertEqual(previous.settingsRequests.count, 1)
        XCTAssertTrue(previous.settingsRequests.first.flatMap { $0 } === notification)
    }

    func testOpenSettingsWithoutAPreviousDelegateDoesNothing() {
        let selector = #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:openSettingsFor:))

        XCTAssertTrue(delegate.responds(to: selector))
        delegate.userNotificationCenter(center, openSettingsFor: nil)
    }

    private func assertSallaPushPresents(_ userInfo: [AnyHashable: Any], line: UInt = #line) throws {
        let previous = RecordingNotificationCenterDelegate(presentationOptions: [.sound])
        delegate.previous = previous
        let notification = try TestNotifications.notification(userInfo: userInfo)
        var nativeOptions: [UNNotificationPresentationOptions] = []
        SallaPushNotificationCenterDelegate().userNotificationCenter(center, willPresent: notification) {
            nativeOptions.append($0)
        }

        let options = present(notification)

        XCTAssertEqual(options, nativeOptions, line: line)
        XCTAssertEqual(options.count, 1, line: line)
        XCTAssertTrue(previous.presented.isEmpty, line: line)
    }

    private func present(_ notification: UNNotification) -> [UNNotificationPresentationOptions] {
        var completions: [UNNotificationPresentationOptions] = []
        delegate.userNotificationCenter(center, willPresent: notification) { completions.append($0) }
        return completions
    }

    private func receive(_ response: UNNotificationResponse) -> Int {
        var completions = 0
        delegate.userNotificationCenter(center, didReceive: response) { completions += 1 }
        return completions
    }
}
