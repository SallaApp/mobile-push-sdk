import Foundation
import SallaPush
import UserNotifications

extension ConfigMessage {
  /// The SallaPush configuration of these options; the ones not set keep SallaPush's defaults.
  func configuration() -> SallaPushConfiguration {
    let configuration = SallaPushConfiguration()
    if let logLevel { configuration.logLevel = logLevel.native }
    if let appVersion { configuration.appVersion = appVersion }
    if let clearTagsOnLogout { configuration.clearTagsOnLogout = clearTagsOnLogout }
    if let requiresUserConsent { configuration.requiresUserConsent = requiresUserConsent }
    if let openLaunchUrls { configuration.openLaunchURLs = openLaunchUrls }
    setBadgeOptions(of: configuration)
    setIosOptions(of: configuration)
    return configuration
  }

  private func setBadgeOptions(of configuration: SallaPushConfiguration) {
    if let autoClearBadge { configuration.autoClearBadge = autoClearBadge }
    if let autoUpdateBadge { configuration.autoUpdateBadge = autoUpdateBadge }
  }

  private func setIosOptions(of configuration: SallaPushConfiguration) {
    if let iosAppGroupIdentifier { configuration.appGroupIdentifier = iosAppGroupIdentifier }
    if let iosApnsEnvironment { configuration.apnsEnvironment = iosApnsEnvironment.native }
    if let iosRegisterForRemoteNotificationsOnInit {
      configuration.registerForRemoteNotificationsOnInit = iosRegisterForRemoteNotificationsOnInit
    }
  }
}

extension LogLevelMessage {
  var native: SallaPushLogLevel {
    switch self {
    case .off: return .off
    case .error: return .error
    case .warn: return .warn
    case .info: return .info
    case .debug: return .debug
    case .verbose: return .verbose
    }
  }
}

extension SallaPushLogLevel {
  var message: LogLevelMessage {
    switch self {
    case .off: return .off
    case .error: return .error
    case .warn: return .warn
    case .info: return .info
    case .debug: return .debug
    case .verbose: return .verbose
    }
  }
}

extension ApnsEnvironmentMessage {
  var native: SallaPushAPNsEnvironment {
    switch self {
    case .automatic: return .automatic
    case .sandbox: return .sandbox
    case .production: return .production
    }
  }
}

extension UNAuthorizationStatus {
  /// By case; a status a later iOS adds reads as not determined.
  var message: IosPermissionStatusMessage {
    switch self {
    case .notDetermined: return .notDetermined
    case .denied: return .denied
    case .authorized: return .authorized
    case .provisional: return .provisional
    case .ephemeral: return .ephemeral
    @unknown default: return .notDetermined
    }
  }
}

extension SallaPushNotification {
  /// The bridge form: every field, the payloads as JSON values, and for each top-level additionalData key the non-nil
  /// results of SallaPush's own typed accessors.
  var message: NotificationMessage {
    var strings: [String: String] = [:]
    var ints: [String: Int64] = [:]
    var bools: [String: Bool] = [:]
    var numbers: [String: Any] = [:]
    for key in additionalData.keys {
      strings[key] = string(forKey: key)
      ints[key] = int(forKey: key).map(Int64.init)
      bools[key] = bool(forKey: key)
      numbers[key] = number(forKey: key)?.bridgeNumber
    }
    return NotificationMessage(
      notificationId: notificationId,
      title: title,
      subtitle: subtitle,
      body: body,
      imageUrl: imageURL?.absoluteString,
      launchUrl: launchURL,
      additionalData: JSON.object(additionalData),
      rawPayload: JSON.object(rawPayload),
      source: source.message,
      stringValues: strings,
      intValues: ints,
      boolValues: bools,
      numberValues: numbers,
      sound: sound,
      badge: badge?.int64Value,
      threadId: threadId)
  }
}

extension SallaPushClickEvent {
  var message: ClickEventMessage {
    ClickEventMessage(notification: notification.message, actionId: result.actionId, url: result.url)
  }
}

extension SallaPushSubscriptionState {
  var message: SubscriptionStateMessage {
    SubscriptionStateMessage(id: id, token: token, optedIn: optedIn)
  }
}

extension SallaPushUserState {
  var message: UserStateMessage {
    UserStateMessage(externalId: externalId, isLoggedIn: isLoggedIn)
  }
}

extension SallaPushUserChangedState {
  var message: UserChangedMessage {
    UserChangedMessage(previous: previous.message, current: current.message)
  }
}

extension LogEntryMessage {
  /// The bridge form of a SallaPush log entry, timestamped in milliseconds since 1970.
  init(_ entry: SallaPushLogEntry) {
    self.init(
      level: entry.level.message, category: entry.category, code: entry.code, message: entry.message,
      metadata: entry.metadata,
      timestampMillis: Int64(exactly: (entry.date.timeIntervalSince1970 * 1000).rounded()) ?? 0)
  }
}

extension SallaPushPayloadSource {
  var message: PayloadSourceMessage {
    switch self {
    case .native: return .native
    case .compat: return .compat
    }
  }
}

extension SallaPushLoginFailure {
  var message: LoginFailureMessage {
    switch self {
    case .tokenRejected: return .tokenRejected
    case .invalidRequest: return .invalidRequest
    }
  }
}

extension NSNumber {
  private static let floatingPointTypes: Set<String> = ["f", "d"]
  private static let unsignedTypes: Set<String> = ["C", "S", "I", "L", "Q"]

  /// The number as Dart reads it: a double for a floating-point number, else an integer (a boolean as 1 or 0), or a
  /// double when it is above Int64's range.
  var bridgeNumber: Any {
    let type = String(cString: objCType)
    let isFloatingPoint = Self.floatingPointTypes.contains(type)
    let isAboveInt64 = Self.unsignedTypes.contains(type) && uint64Value > UInt64(Int64.max)
    return isFloatingPoint || isAboveInt64 ? doubleValue : int64Value
  }
}

/// The JSON values the Flutter codec carries: text, numbers, booleans, null, and arrays and objects of them.
enum JSON {
  /// `dictionary` with its keys as text, without the values that are not JSON (dates, data, ...).
  static func object(_ dictionary: [AnyHashable: Any]) -> [String: Any?] {
    var object: [String: Any?] = [:]
    for (key, value) in dictionary {
      if let value = self.value(value) {
        object["\(key)"] = .some(value)
      }
    }
    return object
  }

  /// `value` as a JSON value; nil when it is not one.
  static func value(_ value: Any) -> Any? {
    switch value {
    case let text as String: return text
    case let number as NSNumber: return number
    case is NSNull: return NSNull()
    case let array as [Any]: return array.compactMap { self.value($0) }
    case let dictionary as [AnyHashable: Any]: return object(dictionary)
    default: return nil
    }
  }
}

extension Dictionary where Key == String, Value == Any? {
  /// The payload as a notification's userInfo, without its null values.
  var userInfo: [AnyHashable: Any] {
    compactMapValues { $0 is NSNull ? nil : $0 }
  }
}

extension Data {
  /// The bytes of hexadecimal text of even length, in either case; nil for any other text.
  init?(hexadecimalText text: String) {
    let digits = Array(text.utf8)
    guard digits.count.isMultiple(of: 2) else { return nil }
    var bytes: [UInt8] = []
    bytes.reserveCapacity(digits.count / 2)
    for index in stride(from: 0, to: digits.count, by: 2) {
      guard let high = Self.hexValue(of: digits[index]), let low = Self.hexValue(of: digits[index + 1]) else {
        return nil
      }
      bytes.append(high << 4 | low)
    }
    self.init(bytes)
  }

  private static func hexValue(of digit: UInt8) -> UInt8? {
    switch digit {
    case UInt8(ascii: "0")...UInt8(ascii: "9"): return digit - UInt8(ascii: "0")
    case UInt8(ascii: "a")...UInt8(ascii: "f"): return digit - UInt8(ascii: "a") + 10
    case UInt8(ascii: "A")...UInt8(ascii: "F"): return digit - UInt8(ascii: "A") + 10
    default: return nil
    }
  }
}
