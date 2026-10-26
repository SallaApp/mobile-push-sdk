import Flutter
import XCTest

@testable import mobile_push

/// The bridge form of real SallaPush notifications, parsed by SallaPush itself.
final class MappingTests: XCTestCase {
  private static let typedNative = """
    {"aps": {"alert": {"title": "Typed", "subtitle": "Values", "body": "Native"}, "badge": 3, "thread-id": "orders"},
     "sp_v": "1", "sp_id": "msg_5a11a90003", "sp_image": "https://cdn.example.com/order.png",
     "count": "7", "price": "9.5", "flag": "true", "off": "0", "padded": " 12 ", "big": "18446744073709551615",
     "text": "tea"}
    """
  private static let typedCompat = """
    {"aps": {"alert": "A compatible body", "sound": "chime.caf"},
     "custom": {"i": "5f0d2c4e-8a61-4b7d-9c3e-2a1b0f9e8d7c", "u": "https://example.com/orders/42",
                "a": {"push_ref": "msg_5a11a90004", "count": 7, "price": 9.5, "flag": true, "whole": 3.0,
                      "nested": {"items": [1, "two", null]}, "nothing": null, "text": "tea"}}}
    """

  func testANativeNotificationKeepsEveryField() throws {
    let userInfo = try TestNotifications.payload(named: "native")
    let message = try XCTUnwrap(SallaPush.Notifications.parse(userInfo)).message

    XCTAssertEqual(message.notificationId, "msg_5a11a90001")
    XCTAssertEqual(message.title, "SallaPush test")
    XCTAssertNil(message.subtitle)
    XCTAssertEqual(message.body, "A native SallaPush notification")
    XCTAssertNil(message.imageUrl)
    XCTAssertEqual(message.launchUrl, "https://example.com/products/42")
    XCTAssertEqual(message.source, .native)
    XCTAssertEqual(message.sound, "default")
    XCTAssertNil(message.badge)
    XCTAssertNil(message.threadId)
    XCTAssertNil(message.androidNotificationId)
    XCTAssertNil(message.collapseId)
    XCTAssertNil(message.channelId)
    XCTAssertEqual(
      try json(message.additionalData),
      ["Simulator Target Bundle": "com.salla.push.example", "type": "product", "id": "42"])
    XCTAssertEqual(try json(message.rawPayload), try json(userInfo))
  }

  func testACompatibleNotificationKeepsEveryField() throws {
    let userInfo = try TestNotifications.payload(named: "compat")
    let message = try XCTUnwrap(SallaPush.Notifications.parse(userInfo)).message

    XCTAssertEqual(message.notificationId, "msg_5a11a90002")
    XCTAssertEqual(message.title, "SallaPush test")
    XCTAssertEqual(message.body, "A OneSignal-compatible SallaPush notification")
    XCTAssertEqual(message.launchUrl, "https://example.com/products/42")
    XCTAssertEqual(message.source, .compat)
    XCTAssertEqual(try json(message.additionalData), ["type": "product", "id": 42])
    XCTAssertEqual(try json(message.rawPayload), try json(userInfo))
  }

  func testTheAlertBadgeThreadAndImageFieldsAreMapped() throws {
    let message = try XCTUnwrap(SallaPush.Notifications.parse(try payload(Self.typedNative))).message

    XCTAssertEqual(message.notificationId, "msg_5a11a90003")
    XCTAssertEqual(message.title, "Typed")
    XCTAssertEqual(message.subtitle, "Values")
    XCTAssertEqual(message.body, "Native")
    XCTAssertEqual(message.badge, 3)
    XCTAssertEqual(message.threadId, "orders")
    XCTAssertEqual(message.imageUrl, "https://cdn.example.com/order.png")
  }

  func testTheTypedValuesAreSallaPushsOwnAccessorResultsForEachKey() throws {
    let payloads = [
      try TestNotifications.payload(named: "native"), try TestNotifications.payload(named: "compat"),
      try payload(Self.typedNative), try payload(Self.typedCompat),
    ]

    for userInfo in payloads {
      let notification = try XCTUnwrap(SallaPush.Notifications.parse(userInfo))
      let message = notification.message
      let keys = Set(notification.additionalData.keys)

      XCTAssertEqual(message.stringValues, results(keys) { notification.string(forKey: $0) })
      XCTAssertEqual(message.intValues, results(keys) { notification.int(forKey: $0).map(Int64.init) })
      XCTAssertEqual(message.boolValues, results(keys) { notification.bool(forKey: $0) })
      XCTAssertEqual(Set(message.numberValues.keys), keys.filter { notification.number(forKey: $0) != nil })
    }
  }

  func testTheTypedValuesOfNativeTextPayloads() throws {
    let message = try XCTUnwrap(SallaPush.Notifications.parse(try payload(Self.typedNative))).message

    XCTAssertEqual(message.stringValues["count"], "7")
    XCTAssertEqual(message.intValues["count"], 7)
    XCTAssertEqual(message.intValues["padded"], 12)
    XCTAssertNil(message.intValues["price"])
    XCTAssertNil(message.intValues["big"])
    XCTAssertEqual(message.boolValues["flag"], true)
    XCTAssertEqual(message.boolValues["off"], false)
    XCTAssertNil(message.boolValues["text"])
    XCTAssertEqual(message.numberValues["count"] as? Int64, 7)
    XCTAssertEqual(message.numberValues["price"] as? Double, 9.5)
    XCTAssertEqual(message.numberValues["big"] as? Double, Double(UInt64.max))
    XCTAssertNil(message.numberValues["text"])
  }

  func testTheTypedValuesOfCompatibleJsonPayloads() throws {
    let message = try XCTUnwrap(SallaPush.Notifications.parse(try payload(Self.typedCompat))).message

    XCTAssertEqual(message.stringValues["count"], "7")
    XCTAssertEqual(message.stringValues["flag"], "true")
    XCTAssertEqual(message.stringValues["price"], "9.5")
    XCTAssertNil(message.stringValues["nested"])
    XCTAssertEqual(message.intValues["count"], 7)
    XCTAssertEqual(message.intValues["whole"], 3)
    XCTAssertNil(message.intValues["price"])
    XCTAssertEqual(message.boolValues["flag"], true)
    XCTAssertEqual(message.numberValues["count"] as? Int64, 7)
    XCTAssertEqual(message.numberValues["price"] as? Double, 9.5)
    XCTAssertEqual(message.numberValues["whole"] as? Double, 3)
    XCTAssertEqual(message.numberValues["flag"] as? Int64, 1)
    XCTAssertEqual(
      try json(message.additionalData)?["nested"] as? NSDictionary, ["items": [1, "two", NSNull()]] as NSDictionary)
    XCTAssertTrue(message.additionalData["nothing"].flatMap { $0 } is NSNull)
  }

  func testNumbersKeepTheirKind() {
    XCTAssertEqual(NSNumber(value: Int64.max).bridgeNumber as? Int64, Int64.max)
    XCTAssertEqual(NSNumber(value: -7).bridgeNumber as? Int64, -7)
    XCTAssertEqual(NSNumber(value: UInt8(7)).bridgeNumber as? Int64, 7)
    XCTAssertEqual(NSNumber(value: UInt64(Int64.max)).bridgeNumber as? Int64, Int64.max)
    XCTAssertEqual(NSNumber(value: UInt64.max).bridgeNumber as? Double, Double(UInt64.max))
    XCTAssertEqual(NSNumber(value: 9.5).bridgeNumber as? Double, 9.5)
    XCTAssertEqual(NSNumber(value: 3.0).bridgeNumber as? Double, 3)
    XCTAssertEqual(NSNumber(value: Float(1.5)).bridgeNumber as? Double, 1.5)
    XCTAssertEqual(NSNumber(value: true).bridgeNumber as? Int64, 1)
    XCTAssertEqual(NSNumber(value: false).bridgeNumber as? Int64, 0)
  }

  func testOnlyJsonValuesReachTheBridge() throws {
    let object = JSON.object([
      "text": "tea", "number": 7, "flag": true, "null": NSNull(), "date": Date(), "data": Data([1]),
      "list": [1, Date(), "two", ["date": Date(), "keep": "yes"]], 42: "number key",
    ])

    XCTAssertEqual(
      try json(object),
      [
        "text": "tea", "number": 7, "flag": true, "null": NSNull(), "list": [1, "two", ["keep": "yes"]],
        "42": "number key",
      ])
  }

  func testTheBridgeFormGoesThroughTheEventChannelCodec() throws {
    let notification = try XCTUnwrap(SallaPush.Notifications.parse(try payload(Self.typedCompat)))
    let click = ClickEventMessage(notification: notification.message, actionId: "track", url: "https://example.com")

    let decoded = messagesPigeonMethodCodec.decodeEnvelope(messagesPigeonMethodCodec.encodeSuccessEnvelope(click))

    let message = try XCTUnwrap(decoded as? ClickEventMessage)
    XCTAssertEqual(message.actionId, "track")
    XCTAssertEqual(message.notification.notificationId, "msg_5a11a90004")
    XCTAssertEqual(message.notification.source, .compat)
    XCTAssertEqual(message.notification.intValues["count"], 7)
    XCTAssertEqual(try json(message.notification.rawPayload), try json(try payload(Self.typedCompat)))
  }

  func testEnumsMapByCase() {
    XCTAssertEqual(SallaPushPayloadSource.native.message, .native)
    XCTAssertEqual(SallaPushPayloadSource.compat.message, .compat)
    XCTAssertEqual(SallaPushLoginFailure.tokenRejected.message, .tokenRejected)
    XCTAssertEqual(SallaPushLoginFailure.invalidRequest.message, .invalidRequest)
  }

  /// The non-nil results of `read` for each of `keys`.
  private func results<Value>(_ keys: Set<String>, _ read: (String) -> Value?) -> [String: Value] {
    var results: [String: Value] = [:]
    for key in keys {
      results[key] = read(key)
    }
    return results
  }

  private func payload(_ text: String) throws -> [AnyHashable: Any] {
    try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [AnyHashable: Any])
  }

  /// `object` read back through JSON, so it compares by value.
  private func json(_ object: Any) throws -> NSDictionary? {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    return try JSONSerialization.jsonObject(with: data) as? NSDictionary
  }
}
