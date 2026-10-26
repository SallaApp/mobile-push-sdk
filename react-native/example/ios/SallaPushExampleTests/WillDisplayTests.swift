@testable import SallaPush
@testable import SallaPushReactNative
import UserNotifications
import XCTest

final class WillDisplayTests: XCTestCase {
    private let native = FakeNativeSallaPush()
    private let emitter = RecordingEmitter()
    private let console = RecordingConsole()
    private lazy var bridge = SallaPushBridge(native: native, console: console, once: OncePerProcess(), emitter: emitter) {
        nil
    }

    func testRegistersOneForegroundListenerAndRemovesIt() {
        bridge.startEvents("willDisplay")
        bridge.startEvents("willDisplay")
        bridge.stopEvents("willDisplay")

        XCTAssertEqual(native.calls, ["addForegroundLifecycleListener"])
        XCTAssertEqual(native.observations.map(\.isCancelled), [true])
    }

    func testPreventsHoldsAndEmitsEachForegroundNotification() throws {
        let notification = try parse("native")
        let event = SallaPushWillDisplayEvent(notification: notification)
        bridge.startEvents("willDisplay")

        native.willDisplayHandlers.first?(event)

        XCTAssertTrue(event.isPrevented)
        XCTAssertEqual(emitter.events.map(\.name), ["onWillDisplay"])
        let body = try XCTUnwrap(emitter.events.first?.body)
        XCTAssertNotNil(UUID(uuidString: try XCTUnwrap(body["handle"] as? String)))
        XCTAssertEqual(body["notification"] as? NSDictionary, Mapping.notification(notification) as NSDictionary)
        XCTAssertTrue(native.displayed.isEmpty)
    }

    func testShowsTheHeldNotificationOnceThroughItsHandle() throws {
        let notification = try parse("compat")
        bridge.startEvents("willDisplay")
        native.willDisplayHandlers.first?(SallaPushWillDisplayEvent(notification: notification))
        let handle = try XCTUnwrap(emitter.events.first?.body["handle"] as? String)

        bridge.displayNotification(handle)
        bridge.displayNotification(handle)

        XCTAssertEqual(native.displayed.count, 1)
        XCTAssertTrue(native.displayed.first === notification)
        XCTAssertEqual(console.warnings.count, 1)
    }

    func testLeavesTheNotificationToNativeOnceStopped() throws {
        bridge.startEvents("willDisplay")
        let handler = native.willDisplayHandlers.first
        bridge.stopEvents("willDisplay")
        let event = SallaPushWillDisplayEvent(notification: try parse("native"))

        handler?(event)

        XCTAssertFalse(event.isPrevented)
        XCTAssertTrue(emitter.events.isEmpty)
    }

    func testForgetsTheHeldNotificationsWhenInvalidated() throws {
        bridge.startEvents("willDisplay")
        native.willDisplayHandlers.first?(SallaPushWillDisplayEvent(notification: try parse("native")))
        let handle = try XCTUnwrap(emitter.events.first?.body["handle"] as? String)

        bridge.invalidate()
        bridge.displayNotification(handle)

        XCTAssertTrue(native.displayed.isEmpty)
        XCTAssertEqual(native.observations.map(\.isCancelled), [true])
    }

    func testTheLiveForegroundListenerDecidesInsideWillPresent() throws {
        let notification = try TestNotifications.notification(userInfo: TestNotifications.payload("native"))
        var notificationIds: [String?] = []
        let observation = LiveNativeSallaPush().addForegroundLifecycleListener { event in
            notificationIds.append(event.notification.notificationId)
            event.preventDefault()
        }
        defer { observation.cancel() }

        let options = SallaPush.Notifications.willPresent(notification)

        XCTAssertEqual(options, [])
        XCTAssertEqual(notificationIds, ["msg_5a11a90001"])
    }

    private func parse(_ name: String) throws -> SallaPushNotification {
        try XCTUnwrap(SallaPush.Notifications.parse(TestNotifications.payload(name)))
    }
}
