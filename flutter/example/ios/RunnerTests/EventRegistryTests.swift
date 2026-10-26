import Flutter
import XCTest

@testable import mobile_push

final class EventRegistryTests: XCTestCase {
  private let native = FakeNativeSallaPush()
  private let displays = DisplayStore()
  private lazy var registry = EventRegistry(native: native, displays: displays)

  func testStartRegistersEachKindOnceAndStopCancelsThatRegistration() throws {
    for kind in EventKind.allCases {
      registry.start(kind)
      registry.start(kind)
    }

    XCTAssertEqual(native.clickListeners.count, 1)
    XCTAssertEqual(native.foregroundListeners.count, 1)
    XCTAssertEqual(native.permissionObservers.count, 1)
    XCTAssertEqual(native.userObservers.count, 1)
    XCTAssertEqual(native.loginFailureHandlers.count, 1)
    XCTAssertEqual(native.logHandlers.count, 1)

    registry.stop(.click)
    registry.stop(.click)

    XCTAssertTrue(try XCTUnwrap(native.clickListeners.first).isCancelled)
    XCTAssertEqual(native.liveRegistrations.count, 5)

    registry.start(.click)

    XCTAssertEqual(native.clickListeners.count, 2)
    XCTAssertFalse(native.clickListeners[1].isCancelled)
  }

  func testEachKindSendsWhatSallaPushReportsToItsSink() throws {
    let sinks = RecordingSinks(registry)
    for kind in EventKind.allCases {
      registry.start(kind)
    }
    let click = TestMessages.click(url: "https://store.example.com/orders/42")
    let change = UserChangedMessage(
      previous: UserStateMessage(isLoggedIn: false), current: UserStateMessage(externalId: "42", isLoggedIn: true))

    try XCTUnwrap(native.clickListeners.first).handler(click)
    try XCTUnwrap(native.permissionObservers.first).handler(true)
    try XCTUnwrap(native.userObservers.first).handler(change)
    try XCTUnwrap(native.loginFailureHandlers.first).handler(.invalidRequest)
    try XCTUnwrap(native.loginFailureHandlers.first).handler(.tokenRejected)

    XCTAssertEqual(sinks.clicks, [click])
    XCTAssertEqual(sinks.permissions, [PermissionChangeMessage(permission: true)])
    XCTAssertEqual(sinks.users, [change])
    XCTAssertEqual(
      sinks.loginFailures,
      [LoginFailureEventMessage(failure: .invalidRequest), LoginFailureEventMessage(failure: .tokenRejected)])
  }

  func testAForegroundNotificationIsHeldAndOfferedToDartUnderANewHandle() throws {
    let sinks = RecordingSinks(registry)
    registry.start(.willDisplay)
    let first = FakeWillDisplay("msg_1")
    let second = FakeWillDisplay("msg_2")

    try XCTUnwrap(native.foregroundListeners.first).handler(first.event)
    try XCTUnwrap(native.foregroundListeners.first).handler(second.event)

    XCTAssertTrue(first.isPrevented)
    XCTAssertTrue(second.isPrevented)
    XCTAssertEqual(sinks.willDisplays.map(\.notification), [first.message, second.message])
    let handles = sinks.willDisplays.map(\.handle)
    XCTAssertEqual(Set(handles).count, 2)
    XCTAssertEqual(first.displays, 0)

    XCTAssertTrue(displays.display(handles[1]))

    XCTAssertEqual(first.displays, 0)
    XCTAssertEqual(second.displays, 1)
  }

  func testWithoutADartStreamSallaPushShowsTheNotificationItself() throws {
    registry.start(.willDisplay)
    let notification = FakeWillDisplay()

    try XCTUnwrap(native.foregroundListeners.first).handler(notification.event)

    XCTAssertFalse(notification.isPrevented)
  }

  func testTheLogHandlerRegistersAtTheLevelSetBeforeIt() {
    registry.setLogLevel(.debug)

    XCTAssertEqual(native.logHandlers.count, 0)

    registry.start(.log)

    XCTAssertEqual(native.logHandlerLevels, [.debug])
  }

  func testANewLogLevelReRegistersAtOnceWhileDartListens() {
    registry.start(.log)

    registry.setLogLevel(.verbose)

    XCTAssertEqual(native.logHandlerLevels, [.warn, .verbose])
    XCTAssertEqual(native.logHandlers.map(\.isCancelled), [true, false])

    registry.setLogLevel(.verbose)

    XCTAssertEqual(native.logHandlerLevels, [.warn, .verbose])

    registry.stop(.log)
    registry.setLogLevel(.error)

    XCTAssertEqual(native.logHandlerLevels, [.warn, .verbose])
  }

  func testLogEntriesReachTheSinkLaterOnTheMainQueue() throws {
    var queued: [() -> Void] = []
    let registry = EventRegistry(native: native, displays: displays) { queued.append($0) }
    let sinks = RecordingSinks(registry)
    registry.start(.log)

    try XCTUnwrap(native.logHandlers.first).handler(TestMessages.logEntry())

    XCTAssertEqual(sinks.logs, [])
    XCTAssertEqual(queued.count, 1)

    queued.forEach { $0() }

    XCTAssertEqual(sinks.logs, [TestMessages.logEntry()])
  }

  func testALogEntryFromSallaPushsQueueReachesTheSinkOnTheMainThread() throws {
    let delivered = expectation(description: "the entry reaches the sink")
    registry.logSink = PigeonEventSink { _ in
      XCTAssertTrue(Thread.isMainThread)
      delivered.fulfill()
    }
    registry.start(.log)
    let handler = try XCTUnwrap(native.logHandlers.first).handler

    DispatchQueue.global().async { handler(TestMessages.logEntry()) }

    wait(for: [delivered], timeout: 5)
  }

  func testEachPushSubscriptionListenerHasItsOwnObserver() {
    let sinks = RecordingSinks(registry)
    registry.addSubscriptionListener(1)
    registry.addSubscriptionListener(2)
    registry.addSubscriptionListener(1)

    XCTAssertEqual(native.subscriptionObservers.count, 2)

    let previous = SubscriptionStateMessage(optedIn: false)
    let current = SubscriptionStateMessage(id: "device-1", token: "ab12cd34", optedIn: true)
    native.subscriptionObservers[1].handler(previous, current)
    native.subscriptionObservers[0].handler(current, current)

    XCTAssertEqual(
      sinks.subscriptions,
      [
        SubscriptionChangedMessage(listenerId: 2, previous: previous, current: current),
        SubscriptionChangedMessage(listenerId: 1, previous: current, current: current),
      ])

    registry.removeSubscriptionListener(1)
    registry.removeSubscriptionListener(1)

    XCTAssertTrue(native.subscriptionObservers[0].isCancelled)
    XCTAssertFalse(native.subscriptionObservers[1].isCancelled)

    registry.removeSubscriptionListeners()

    XCTAssertTrue(native.subscriptionObservers[1].isCancelled)

    registry.addSubscriptionListener(1)

    XCTAssertEqual(native.subscriptionObservers.count, 3)
    XCTAssertFalse(native.subscriptionObservers[2].isCancelled)
  }

  func testStopAllCancelsEveryRegistrationAndForgetsTheSinks() throws {
    let sinks = RecordingSinks(registry)
    for kind in EventKind.allCases {
      registry.start(kind)
    }
    registry.addSubscriptionListener(1)
    registry.addSubscriptionListener(2)

    registry.stopAll()

    XCTAssertEqual(native.liveRegistrations.count, 0)
    XCTAssertNil(registry.clickSink)
    XCTAssertNil(registry.willDisplaySink)
    XCTAssertNil(registry.permissionSink)
    XCTAssertNil(registry.userSink)
    XCTAssertNil(registry.loginFailureSink)
    XCTAssertNil(registry.pushSubscriptionSink)
    XCTAssertNil(registry.logSink)

    // A callback SallaPush had already scheduled reaches no sink.
    try XCTUnwrap(native.clickListeners.first).handler(TestMessages.click())
    let state = SubscriptionStateMessage(optedIn: true)
    try XCTUnwrap(native.subscriptionObservers.first).handler(state, state)
    XCTAssertEqual(sinks.clicks, [])
    XCTAssertEqual(sinks.subscriptions, [])
  }

  func testSallaPushDoesNotKeepTheRegistryAlive() throws {
    weak var released: EventRegistry?
    do {
      let registry = EventRegistry(native: native, displays: displays)
      released = registry
      for kind in EventKind.allCases {
        registry.start(kind)
      }
      registry.addSubscriptionListener(1)
    }

    XCTAssertNil(released)
    let state = SubscriptionStateMessage(optedIn: true)
    let notification = FakeWillDisplay()
    try XCTUnwrap(native.foregroundListeners.first).handler(notification.event)
    XCTAssertFalse(notification.isPrevented)
    try XCTUnwrap(native.clickListeners.first).handler(TestMessages.click())
    try XCTUnwrap(native.permissionObservers.first).handler(true)
    try XCTUnwrap(native.subscriptionObservers.first).handler(state, state)
  }
}

/// Sinks set on a registry that keep the messages that reach them.
private final class RecordingSinks {
  private(set) var clicks: [ClickEventMessage] = []
  private(set) var willDisplays: [WillDisplayEventMessage] = []
  private(set) var permissions: [PermissionChangeMessage] = []
  private(set) var users: [UserChangedMessage] = []
  private(set) var loginFailures: [LoginFailureEventMessage] = []
  private(set) var subscriptions: [SubscriptionChangedMessage] = []
  private(set) var logs: [LogEntryMessage] = []

  init(_ registry: EventRegistry) {
    registry.clickSink = Self.sink { self.clicks.append($0) }
    registry.willDisplaySink = Self.sink { self.willDisplays.append($0) }
    registry.permissionSink = Self.sink { self.permissions.append($0) }
    registry.userSink = Self.sink { self.users.append($0) }
    registry.loginFailureSink = Self.sink { self.loginFailures.append($0) }
    registry.pushSubscriptionSink = Self.sink { self.subscriptions.append($0) }
    registry.logSink = Self.sink { self.logs.append($0) }
  }

  private static func sink<Message>(_ record: @escaping (Message) -> Void) -> PigeonEventSink<Message> {
    PigeonEventSink { event in
      if let message = event as? Message {
        record(message)
      }
    }
  }
}
