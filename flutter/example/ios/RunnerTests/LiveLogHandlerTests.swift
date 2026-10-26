import XCTest

@testable import mobile_push

/// The plugin's log handler with SallaPush's real logger. An empty APNs token makes SallaPush log `token.invalid`, and
/// nothing else.
final class LiveLogHandlerTests: XCTestCase {
  /// The tests' host, the example app, sets its own handler as soon as its Dart code runs, and a handler set later
  /// replaces the tests' one: SallaPush keeps one per process. So the tests start once the host's is set.
  override static func setUp() {
    super.setUp()
    let deadline = Date().addingTimeInterval(10)
    while LogHandlerRegistration.current == nil, Date() < deadline {
      RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
  }

  func testSallaPushsOwnEntriesReachTheSinkOnTheMainThread() throws {
    let registry = EventRegistry(native: LiveNativeSallaPush(), displays: DisplayStore())
    let received = expectation(description: "SallaPush logs token.invalid")
    received.assertForOverFulfill = false
    var entries: [LogEntryMessage] = []
    registry.logSink = PigeonEventSink { event in
      XCTAssertTrue(Thread.isMainThread)
      guard let entry = event as? LogEntryMessage, entry.code == "token.invalid" else { return }
      entries.append(entry)
      received.fulfill()
    }
    registry.setLogLevel(.verbose)
    registry.start(.log)
    defer { registry.stop(.log) }
    let before = Int64(Date().timeIntervalSince1970 * 1000)

    SallaPush.Notifications.didRegisterForRemoteNotifications(deviceToken: Data())

    wait(for: [received], timeout: 5)
    let entry = try XCTUnwrap(entries.first)
    XCTAssertEqual(entry.level, .warn)
    XCTAssertEqual(entry.category, "registration")
    XCTAssertEqual(entry.message, "The push token passed to SallaPush is empty or malformed; ignored.")
    XCTAssertEqual(entry.metadata, [:])
    XCTAssertGreaterThanOrEqual(entry.timestampMillis, before - 1)
    XCTAssertLessThanOrEqual(entry.timestampMillis, Int64(Date().timeIntervalSince1970 * 1000) + 1)
  }

  func testOnlyTheLatestRegistrationRemovesSallaPushsOneHandler() {
    let replaced = LiveNativeSallaPush().addLogHandler(level: .verbose) { _ in }
    let received = expectation(description: "the latest handler still gets entries")
    received.assertForOverFulfill = false
    let latest = LiveNativeSallaPush().addLogHandler(level: .verbose) { entry in
      if entry.code == "token.invalid" {
        received.fulfill()
      }
    }

    replaced.cancel()
    SallaPush.Notifications.didRegisterForRemoteNotifications(deviceToken: Data())
    wait(for: [received], timeout: 5)

    let removed = expectation(description: "no handler gets entries")
    removed.isInverted = true
    let handler = LiveNativeSallaPush().addLogHandler(level: .verbose) { entry in
      if entry.code == "token.invalid" {
        removed.fulfill()
      }
    }
    handler.cancel()
    latest.cancel()
    SallaPush.Notifications.didRegisterForRemoteNotifications(deviceToken: Data())
    wait(for: [removed], timeout: 1)
  }
}
