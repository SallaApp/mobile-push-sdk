@testable import SallaPush
@testable import SallaPushReactNative
import XCTest

final class LogHandlerTests: XCTestCase {
    private let native = FakeNativeSallaPush()
    private let emitter = RecordingEmitter()
    private lazy var bridge = SallaPushBridge(native: native, console: RecordingConsole(), once: OncePerProcess(),
                                              emitter: emitter) { nil }

    // MARK: - The registration

    func testRegistersNativesHandlerOnceAtWarnByDefault() {
        bridge.startEvents("log")
        bridge.startEvents("log")

        XCTAssertEqual(native.logHandlers.map(\.level), [.warn])
    }

    func testRegistersAtTheLevelJavaScriptSetFirst() {
        bridge.setLogHandlerLevel("info")
        bridge.startEvents("log")

        XCTAssertEqual(native.logHandlers.map(\.level), [.info])
    }

    func testALevelChangeReplacesNativesHandlerOnlyWhileRegistered() {
        bridge.setLogHandlerLevel("debug")
        bridge.startEvents("log")
        bridge.setLogHandlerLevel("debug")
        bridge.setLogHandlerLevel("verbose")
        bridge.setLogHandlerLevel("trace")
        bridge.stopEvents("log")
        bridge.setLogHandlerLevel("error")

        XCTAssertEqual(native.logHandlers.map(\.level), [.debug, .verbose])
        XCTAssertEqual(native.observations.map(\.isCancelled), [false, true])
    }

    // MARK: - Entries

    func testEmitsEachEntryOnTheMainThreadInOrder() throws {
        let entry = try nativeEntry()
        bridge.startEvents("log")
        let handler = try XCTUnwrap(native.logHandlers.first?.handler)
        let queue = DispatchQueue(label: "test.native-log")

        queue.async {
            handler(entry)
            handler(entry)
        }
        queue.sync {}
        drainMainQueue()

        XCTAssertEqual(emitter.events.map(\.name), ["onLog", "onLog"])
        XCTAssertEqual(emitter.onMainThread, [true, true])
        XCTAssertEqual(emitter.events.first?.body, Mapping.logEntry(entry) as NSDictionary)
    }

    func testEmitsNothingForAnEntryQueuedBeforeTheStop() throws {
        let entry = try nativeEntry()
        bridge.startEvents("log")
        let handler = try XCTUnwrap(native.logHandlers.first?.handler)

        handler(entry)
        bridge.stopEvents("log")
        drainMainQueue()

        XCTAssertTrue(emitter.events.isEmpty)
    }

    func testMapsAnEntryAsNativeLoggedIt() throws {
        let entry = try nativeEntry()

        let body = Mapping.logEntry(entry) as NSDictionary

        XCTAssertEqual(body["level"] as? String, "verbose")
        XCTAssertEqual(body["category"] as? String, entry.category)
        XCTAssertEqual(body["code"] as? String, "notif.foreign")
        XCTAssertEqual(body["message"] as? String, entry.message)
        XCTAssertEqual(body["metadata"] as? [String: String], entry.metadata)
        let timestamp = try XCTUnwrap(body["timestamp"] as? Double)
        XCTAssertEqual(timestamp, (entry.date.timeIntervalSince1970 * 1000).rounded(.down))
    }

    // MARK: - The live seam

    func testCancellingTheLiveRegistrationRemovesNativesHandler() {
        let logged = expectation(description: "no entry reaches a cancelled handler")
        logged.isInverted = true
        LiveNativeSallaPush().setLogHandler(level: .verbose) { entry in
            if entry.code == "notif.foreign" { logged.fulfill() }
        }.cancel()

        SallaPush.Notifications.didReceiveRemoteNotification(TestNotifications.foreign)

        wait(for: [logged], timeout: 0.5)
    }

    // MARK: - Helpers

    /// A real entry from native's logger, through the live seam: a foreign payload logs notif.foreign at verbose.
    private func nativeEntry() throws -> SallaPushLogEntry {
        var entries: [SallaPushLogEntry] = []
        let logged = expectation(description: "native logs notif.foreign")
        logged.assertForOverFulfill = false
        let registration = LiveNativeSallaPush().setLogHandler(level: .verbose) { entry in
            guard entry.code == "notif.foreign" else { return }
            DispatchQueue.main.async {
                entries.append(entry)
                logged.fulfill()
            }
        }
        defer { registration.cancel() }

        SallaPush.Notifications.didReceiveRemoteNotification(TestNotifications.foreign)

        wait(for: [logged], timeout: 5)
        return try XCTUnwrap(entries.first)
    }

    private func drainMainQueue() {
        let drained = expectation(description: "the main queue ran what was queued before")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 5)
    }
}
