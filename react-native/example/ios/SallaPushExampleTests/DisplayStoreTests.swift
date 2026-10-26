@testable import SallaPush
@testable import SallaPushReactNative
import XCTest

final class DisplayStoreTests: XCTestCase {
    private let native = FakeNativeSallaPush()
    private let console = RecordingConsole()
    private var now = Date(timeIntervalSince1970: 1_800_000_000)
    private lazy var store = DisplayStore(native: native, console: console) { [unowned self] in now }
    private let refused = "SallaPushNotification.display() did nothing: a prevented notification is shown once, within "
        + "10 minutes of its foregroundWillDisplay event."

    func testHoldsEachNotificationUnderANewRandomHandle() throws {
        let first = store.put(try notification())
        let second = store.put(try notification())

        XCTAssertNotEqual(first, second)
        XCTAssertNotNil(UUID(uuidString: first))
    }

    func testDisplaysTheVeryObjectItHeldOnce() throws {
        let held = try notification()
        let handle = store.put(held)

        XCTAssertTrue(store.display(handle))
        XCTAssertFalse(store.display(handle))

        XCTAssertEqual(native.displayed.count, 1)
        XCTAssertTrue(native.displayed.first === held)
        XCTAssertEqual(console.warnings, [refused])
    }

    func testAnUnknownHandleDisplaysNothing() {
        XCTAssertFalse(store.display("8d1e3d0a-1a1b-4c63-9d38-4c2b2b7e5f10"))

        XCTAssertTrue(native.displayed.isEmpty)
        XCTAssertEqual(console.warnings, [refused])
    }

    func testDisplaysWithinNativesTenMinuteWindowOnly() throws {
        let onTime = store.put(try notification())
        now += 600
        XCTAssertTrue(store.display(onTime))

        let late = store.put(try notification())
        now += 600.5
        XCTAssertFalse(store.display(late))

        XCTAssertEqual(native.displayed.count, 1)
    }

    func testKeepsNativesTwentyRecordsDroppingTheOldestFirst() throws {
        let handles = try (0...DisplayStore.capacity).map { _ in store.put(try notification()) }

        XCTAssertFalse(store.display(handles[0]))
        for handle in handles.dropFirst() {
            XCTAssertTrue(store.display(handle))
        }
        XCTAssertEqual(native.displayed.count, 20)
    }

    func testClearForgetsEveryNotification() throws {
        let handle = store.put(try notification())

        store.clear()

        XCTAssertFalse(store.display(handle))
        XCTAssertTrue(native.displayed.isEmpty)
    }

    private func notification() throws -> SallaPushNotification {
        try XCTUnwrap(SallaPush.Notifications.parse(TestNotifications.payload("native")))
    }
}
