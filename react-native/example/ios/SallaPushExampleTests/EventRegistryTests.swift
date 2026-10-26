@testable import SallaPush
@testable import SallaPushReactNative
import XCTest

final class EventRegistryTests: XCTestCase {
    private let native = FakeNativeSallaPush()
    private let emitter = RecordingEmitter()
    private let console = RecordingConsole()
    private lazy var displays = DisplayStore(native: native, console: console)
    private lazy var registry = EventRegistry(native: native, displays: displays, emitter: emitter)

    // MARK: - Registrations

    func testStartsOneNativeRegistrationPerKindOnce() {

        for kind in [EventRegistry.Kind.click, .permission, .user, .loginFailure] {
            registry.start(kind)
            registry.start(kind)
        }

        XCTAssertEqual(native.calls, [
            "addClickListener", "addPermissionObserver", "addUserObserver", "addLoginFailureHandler"
        ])
    }

    func testStopCancelsTheObservationItsStartKept() {
        registry.start(.click)
        registry.start(.user)

        registry.stop(.click)
        registry.stop(.click)
        registry.stop(.permission)

        XCTAssertEqual(native.observations.map(\.isCancelled), [true, false])
    }

    func testStartsAgainAfterAStop() {

        registry.start(.permission)
        registry.stop(.permission)
        registry.start(.permission)

        XCTAssertEqual(native.calls, ["addPermissionObserver", "addPermissionObserver"])
        XCTAssertEqual(native.observations.map(\.isCancelled), [true, false])
    }

    func testAddsOneSubscriptionObserverPerListenerAndRemovesOnlyItsOwn() {

        registry.addSubscriptionListener(1)
        registry.addSubscriptionListener(1)
        registry.addSubscriptionListener(2)
        registry.removeSubscriptionListener(1)
        registry.removeSubscriptionListener(1)
        registry.removeSubscriptionListener(3)

        XCTAssertEqual(native.calls, ["addSubscriptionObserver", "addSubscriptionObserver"])
        XCTAssertEqual(native.observations.map(\.isCancelled), [true, false])
    }

    func testStopAllCancelsEveryRegistration() {
        registry.start(.click)
        registry.start(.loginFailure)
        registry.addSubscriptionListener(1)
        registry.addSubscriptionListener(2)

        registry.stopAll()
        registry.start(.click)

        XCTAssertEqual(native.observations.map(\.isCancelled), [true, true, true, true, false])
    }

    // MARK: - Emitted events

    func testEmitsPermissionChanges() {
        registry.start(.permission)

        native.permissionHandlers.first?(true)
        native.permissionHandlers.first?(false)

        XCTAssertEqual(emitter.events.map(\.name), ["onPermissionChange", "onPermissionChange"])
        XCTAssertEqual(emitter.events.map(\.body), [["permission": true], ["permission": false]])
    }

    func testEmitsLoginFailuresByCase() {
        registry.start(.loginFailure)

        native.loginFailureHandlers.first?(.tokenRejected)
        native.loginFailureHandlers.first?(.invalidRequest)

        XCTAssertEqual(emitter.events.map(\.name), ["onLoginFailure", "onLoginFailure"])
        XCTAssertEqual(emitter.events.map(\.body), [["failure": "tokenRejected"], ["failure": "invalidRequest"]])
    }

    func testEmitsUserChanges() {
        registry.start(.user)

        native.userHandlers.first?(userChange)

        XCTAssertEqual(emitter.events.map(\.name), ["onUserChange"])
        XCTAssertEqual(emitter.events.first?.body, [
            "previous": ["isLoggedIn": false],
            "current": ["externalId": "customer-7", "isLoggedIn": true] as [String: Any]
        ])
    }

    func testEmitsEachSubscriptionChangeWithTheIdOfItsListener() {
        registry.addSubscriptionListener(1)
        registry.addSubscriptionListener(2)

        native.subscriptionHandlers.last?(subscriptionChange)

        XCTAssertEqual(emitter.events.map(\.name), ["onPushSubscriptionChange"])
        XCTAssertEqual(emitter.events.first?.body, [
            "listenerId": 2,
            "previous": ["optedIn": false],
            "current": ["id": "3f1c5a52-6a7e-4d1e-9a53-0c7b9e1d2f40", "token": "a1b2c3", "optedIn": true] as [String: Any]
        ])
    }

    func testEmitsClicksWithTheirNotification() throws {
        let notification = try XCTUnwrap(SallaPush.Notifications.parse(TestNotifications.payload("native")))
        let event = SallaPushClickEvent(notification: notification,
                                        result: SallaPushClickResult(actionId: "reply", url: notification.launchURL))
        registry.start(.click)

        native.clickHandlers.first?(event)

        XCTAssertEqual(emitter.events.map(\.name), ["onClick"])
        let body = try XCTUnwrap(emitter.events.first?.body)
        XCTAssertEqual(body["actionId"] as? String, "reply")
        XCTAssertEqual(body["url"] as? String, "https://example.com/products/42")
        XCTAssertEqual(body["notification"] as? NSDictionary, Mapping.notification(notification) as NSDictionary)
    }

    func testEmitsNothingForAnEventNativeDeliversAfterTheStop() {
        registry.start(.user)
        registry.addSubscriptionListener(1)
        let userHandler = native.userHandlers.first
        let subscriptionHandler = native.subscriptionHandlers.first

        registry.stop(.user)
        registry.removeSubscriptionListener(1)
        userHandler?(userChange)
        subscriptionHandler?(subscriptionChange)

        XCTAssertTrue(emitter.events.isEmpty)
    }

    func testHoldsTheEmitterWeakly() {
        weak var released: RecordingEmitter?
        let registry: EventRegistry = {
            let emitter = RecordingEmitter()
            released = emitter
            return EventRegistry(native: native, displays: displays, emitter: emitter)
        }()
        registry.start(.permission)

        withExtendedLifetime(registry) {
            native.permissionHandlers.first?(true)
        }

        XCTAssertNil(released)
    }

    // MARK: - The bridge

    func testTheBridgeRoutesEventCallsAndIgnoresUnknownKinds() {
        let bridge = makeBridge()

        bridge.startEvents("click")
        bridge.startEvents("opened")
        bridge.startEvents("Click")
        bridge.addPushSubscriptionListener(7)
        bridge.stopEvents("click")
        bridge.stopEvents("opened")
        bridge.removePushSubscriptionListener(7)

        XCTAssertEqual(native.calls, ["addClickListener", "addSubscriptionObserver"])
        XCTAssertEqual(native.observations.map(\.isCancelled), [true, true])
    }

    func testTheBridgeStopsEveryRegistrationWhenInvalidated() {
        let bridge = makeBridge()
        bridge.startEvents("user")
        bridge.startEvents("permission")
        bridge.addPushSubscriptionListener(1)

        bridge.invalidate()

        XCTAssertEqual(native.observations.map(\.isCancelled), [true, true, true])
    }

    // MARK: - The live seam

    func testTheLiveClickListenerGetsARealTap() throws {
        let marker = UUID().uuidString
        var payload = try TestNotifications.payload("native")
        payload["marker"] = marker
        var urls: [String?] = []
        let delivered = expectation(description: "the tap reaches the live click listener")
        let observation = LiveNativeSallaPush().addClickListener { event in
            guard event.notification.string(forKey: "marker") == marker else { return }
            urls.append(event.result.url)
            delivered.fulfill()
        }
        defer { observation.cancel() }

        XCTAssertTrue(SallaPush.Notifications.didReceive(try TestNotifications.response(userInfo: payload)))

        wait(for: [delivered], timeout: 5)
        XCTAssertEqual(urls, ["https://example.com/products/42"])
    }

    // MARK: - Helpers

    private var userChange: SallaPushUserChangedState {
        SallaPushUserChangedState(previous: SallaPushUserState(externalId: nil, isLoggedIn: false),
                                  current: SallaPushUserState(externalId: "customer-7", isLoggedIn: true))
    }

    private var subscriptionChange: SallaPushSubscriptionChangedState {
        SallaPushSubscriptionChangedState(
            previous: SallaPushSubscriptionState(id: nil, token: nil, optedIn: false),
            current: SallaPushSubscriptionState(id: "3f1c5a52-6a7e-4d1e-9a53-0c7b9e1d2f40", token: "a1b2c3", optedIn: true)
        )
    }

    private func makeBridge() -> SallaPushBridge {
        SallaPushBridge(native: native, console: RecordingConsole(), once: OncePerProcess(), emitter: emitter) { nil }
    }
}
