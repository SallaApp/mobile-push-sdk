import XCTest

@testable import mobile_push

final class DisplayStoreTests: XCTestCase {
  private var now: TimeInterval = 1_000
  private lazy var store = DisplayStore(now: { self.now })
  private var shown: [Int] = []

  func testShowsTheNotificationUnderItsHandleOnce() {
    let first = store.put { self.shown.append(1) }
    let second = store.put { self.shown.append(2) }

    XCTAssertNotEqual(first, second)
    XCTAssertTrue(store.display(second))
    XCTAssertFalse(store.display(second))
    XCTAssertTrue(store.display(first))
    XCTAssertEqual(shown, [2, 1])
  }

  func testAnUnknownHandleShowsNothing() {
    _ = store.put { self.shown.append(1) }

    XCTAssertFalse(store.display("unknown"))
    XCTAssertEqual(shown, [])
  }

  func testANotificationCanBeShownFor600Seconds() {
    let kept = store.put { self.shown.append(1) }
    let expired = store.put { self.shown.append(2) }

    now += 600
    XCTAssertTrue(store.display(kept))
    now += 0.001
    XCTAssertFalse(store.display(expired))
    XCTAssertEqual(shown, [1])
  }

  func testKeepsTheLast20AsSallaPushDoes() {
    let handles = (1...21).map { index in store.put { self.shown.append(index) } }

    XCTAssertFalse(store.display(handles[0]))
    for handle in handles.dropFirst() {
      XCTAssertTrue(store.display(handle))
    }
    XCTAssertEqual(shown, Array(2...21))
  }

  func testTheDefaultClockIsTheWallClockAsSallaPushs() {
    XCTAssertEqual(DisplayStore().now(), Date().timeIntervalSince1970, accuracy: 60)
  }

  func testClearForgetsEveryNotification() {
    let handle = store.put { self.shown.append(1) }

    store.clear()

    XCTAssertFalse(store.display(handle))
    XCTAssertEqual(shown, [])
  }
}
