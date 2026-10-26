import Flutter
import XCTest

@testable import mobile_push

/// The plugin's event streams: Dart's listen and cancel on each channel start and stop the native listeners.
final class EventChannelTests: XCTestCase {
  private static let hostApi = "dev.flutter.pigeon.mobile_push.SallaPushHostApi"
  private static let streams = [
    "clickEvents", "willDisplayEvents", "permissionChanges", "userChanges", "loginFailures", "logEntries",
  ]

  private let native = FakeNativeSallaPush()
  private let messenger = FakeBinaryMessenger()
  private let recorder = ConsoleRecorder()
  private lazy var plugin = SallaPushFlutterPlugin(
    native: native, earlyInit: { nil }, console: recorder.console, platformOnly: PlatformOnlyCalls())

  override func setUp() {
    super.setUp()
    plugin.attach(to: messenger)
  }

  func testEachStreamRegistersItsNativeListenerOnListenAndRemovesItOnCancel() {
    for stream in Self.streams {
      XCTAssertEqual(cancelled(stream), [], stream)

      messenger.streamCall("listen", on: stream)

      XCTAssertEqual(cancelled(stream), [false], stream)

      messenger.streamCall("cancel", on: stream)

      XCTAssertEqual(cancelled(stream), [true], stream)
    }
  }

  func testTheListenOfAHotRestartReplacesTheNativeListener() {
    messenger.streamCall("listen", on: "clickEvents")
    messenger.streamCall("listen", on: "clickEvents")

    XCTAssertEqual(cancelled("clickEvents"), [true, false])
  }

  func testWhatSallaPushReportsReachesDartOnItsStream() throws {
    for stream in Self.streams {
      messenger.streamCall("listen", on: stream)
    }
    let click = TestMessages.click(url: "https://store.example.com/orders/42")
    let change = UserChangedMessage(
      previous: UserStateMessage(externalId: "42", isLoggedIn: true), current: UserStateMessage(isLoggedIn: false))

    try XCTUnwrap(native.clickListeners.first).handler(click)
    try XCTUnwrap(native.permissionObservers.first).handler(false)
    try XCTUnwrap(native.userObservers.first).handler(change)
    try XCTUnwrap(native.loginFailureHandlers.first).handler(.tokenRejected)

    XCTAssertEqual(messenger.events(on: "clickEvents", as: ClickEventMessage.self), [click])
    XCTAssertEqual(
      messenger.events(on: "permissionChanges", as: PermissionChangeMessage.self),
      [PermissionChangeMessage(permission: false)])
    XCTAssertEqual(messenger.events(on: "userChanges", as: UserChangedMessage.self), [change])
    XCTAssertEqual(
      messenger.events(on: "loginFailures", as: LoginFailureEventMessage.self),
      [LoginFailureEventMessage(failure: .tokenRejected)])
  }

  func testAForegroundNotificationIsOfferedToDartWhichShowsItWithItsHandle() throws {
    messenger.streamCall("listen", on: "willDisplayEvents")
    let notification = FakeWillDisplay()

    try XCTUnwrap(native.foregroundListeners.first).handler(notification.event)

    XCTAssertTrue(notification.isPrevented)
    let event = try XCTUnwrap(messenger.events(on: "willDisplayEvents", as: WillDisplayEventMessage.self).first)
    XCTAssertEqual(event.notification, notification.message)

    displayNotification(event.handle)

    XCTAssertEqual(notification.displays, 1)
    XCTAssertEqual(recorder.lines, [])
  }

  func testShowingANotificationTwiceOrUnknownSaysSoOnTheConsole() throws {
    messenger.streamCall("listen", on: "willDisplayEvents")
    let notification = FakeWillDisplay()
    try XCTUnwrap(native.foregroundListeners.first).handler(notification.event)
    let event = try XCTUnwrap(messenger.events(on: "willDisplayEvents", as: WillDisplayEventMessage.self).first)

    displayNotification(event.handle)
    displayNotification(event.handle)
    displayNotification("unknown")

    XCTAssertEqual(notification.displays, 1)
    XCTAssertEqual(
      recorder.lines,
      Array(
        repeating: .init(
          level: .info,
          message: "display() did nothing: a notification from onWillDisplay can be shown once, within 10 minutes of "
            + "its event."),
        count: 2))
  }

  func testLogsRegisterAtTheLevelDartSetFirstAndReachDartFromTheMainQueue() throws {
    setLogHandlerLevel(.debug)
    messenger.streamCall("listen", on: "logEntries")

    XCTAssertEqual(native.logHandlerLevels, [.debug])

    try XCTUnwrap(native.logHandlers.first).handler(TestMessages.logEntry())

    XCTAssertEqual(messenger.events(on: "logEntries", as: LogEntryMessage.self), [])

    runTheMainQueue()

    XCTAssertEqual(messenger.events(on: "logEntries", as: LogEntryMessage.self), [TestMessages.logEntry()])

    setLogHandlerLevel(.error)

    XCTAssertEqual(native.logHandlerLevels, [.debug, .error])
    XCTAssertEqual(native.logHandlers.map(\.isCancelled), [true, false])

    messenger.streamCall("cancel", on: "logEntries")

    XCTAssertEqual(native.logHandlers.map(\.isCancelled), [true, true])
  }

  func testACallbackAfterDartCancelledReachesNoStream() throws {
    messenger.streamCall("listen", on: "clickEvents")
    let handler = try XCTUnwrap(native.clickListeners.first).handler

    messenger.streamCall("cancel", on: "clickEvents")
    handler(TestMessages.click())

    XCTAssertEqual(messenger.events(on: "clickEvents", as: ClickEventMessage.self), [])
  }

  func testEachDartSubscriptionListenerAddsAndRemovesItsOwnObserver() {
    messenger.streamCall("listen", on: "pushSubscriptionChanges")

    XCTAssertEqual(cancelled("pushSubscriptionChanges"), [])

    addSubscriptionListener(1)
    addSubscriptionListener(2)
    let state = SubscriptionStateMessage(id: "device-1", token: "ab12cd34", optedIn: true)
    native.subscriptionObservers[1].handler(state, state)

    XCTAssertEqual(cancelled("pushSubscriptionChanges"), [false, false])
    XCTAssertEqual(
      messenger.events(on: "pushSubscriptionChanges", as: SubscriptionChangedMessage.self),
      [SubscriptionChangedMessage(listenerId: 2, previous: state, current: state)])

    _ = messenger.send("\(Self.hostApi).removePushSubscriptionListener", arguments: [Int64(1)])

    XCTAssertEqual(cancelled("pushSubscriptionChanges"), [true, false])

    messenger.streamCall("cancel", on: "pushSubscriptionChanges")

    XCTAssertEqual(cancelled("pushSubscriptionChanges"), [true, true])
  }

  func testDetachingFromTheEngineStopsEveryNativeListenerAndForgetsTheHeldNotifications() throws {
    for stream in Self.streams + ["pushSubscriptionChanges"] {
      messenger.streamCall("listen", on: stream)
    }
    addSubscriptionListener(1)
    let notification = FakeWillDisplay()
    try XCTUnwrap(native.foregroundListeners.first).handler(notification.event)
    let event = try XCTUnwrap(messenger.events(on: "willDisplayEvents", as: WillDisplayEventMessage.self).first)

    plugin.detach(from: messenger)

    XCTAssertEqual(native.liveRegistrations.count, 0)
    XCTAssertTrue(messenger.handlers.isEmpty)
    plugin.displayNotification(handle: event.handle)
    XCTAssertEqual(notification.displays, 0)
  }

  private func setLogHandlerLevel(_ level: LogLevelMessage) {
    XCTAssertEqual(messenger.send("\(Self.hostApi).setLogHandlerLevel", arguments: [level])?.count, 1)
  }

  /// Runs what is queued on the main queue so far: the queue runs blocks in order.
  private func runTheMainQueue() {
    let ran = expectation(description: "the main queue ran")
    DispatchQueue.main.async { ran.fulfill() }
    wait(for: [ran], timeout: 5)
  }

  private func displayNotification(_ handle: String) {
    XCTAssertEqual(messenger.send("\(Self.hostApi).displayNotification", arguments: [handle])?.count, 1)
  }

  private func addSubscriptionListener(_ id: Int64) {
    XCTAssertEqual(messenger.send("\(Self.hostApi).addPushSubscriptionListener", arguments: [id])?.count, 1)
  }

  /// Whether each native registration behind `stream` was cancelled, oldest first.
  private func cancelled(_ stream: String) -> [Bool] {
    switch stream {
    case "clickEvents": return native.clickListeners.map(\.isCancelled)
    case "willDisplayEvents": return native.foregroundListeners.map(\.isCancelled)
    case "permissionChanges": return native.permissionObservers.map(\.isCancelled)
    case "userChanges": return native.userObservers.map(\.isCancelled)
    case "loginFailures": return native.loginFailureHandlers.map(\.isCancelled)
    case "logEntries": return native.logHandlers.map(\.isCancelled)
    default: return native.subscriptionObservers.map(\.isCancelled)
    }
  }
}
