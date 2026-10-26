import Flutter
import UIKit
import UserNotifications
import XCTest

@testable import mobile_push

/// Records the plugin's SallaPush calls, and answers like SallaPush: only for SallaPush payloads.
final class FakeNativeSallaPush: NativeSallaPush {
  struct Initialization {
    let appId: String
    let configuration: SallaPushConfiguration
  }

  enum Call: Equatable {
    case setConsentRequired(Bool)
    case setConsentGiven(Bool)
    case login(externalId: String, identityToken: String)
    case logout
    case addTag(key: String, value: String)
    case addTags([String: String])
    case removeTag(String)
    case removeTags([String])
    case setLanguage(String?)
    case optIn
    case optOut
    case requestPermission(fallbackToSettings: Bool)
    case registerForProvisionalAuthorization
    case refreshPermission
    case registerForRemoteNotifications
    case clearAll
    case setLogLevel(SallaPushLogLevel)
  }

  /// A listener SallaPush keeps until its registration is cancelled.
  final class Registration<Handler>: NativeObservation {
    let handler: Handler
    private(set) var isCancelled = false

    init(_ handler: Handler) {
      self.handler = handler
    }

    func cancel() {
      isCancelled = true
    }
  }

  typealias SubscriptionHandler = (SubscriptionStateMessage, SubscriptionStateMessage) -> Void

  static let options: UNNotificationPresentationOptions = [.banner, .list, .sound, .badge]

  var isInitialized = false
  var appId: String?
  var sdkVersion = "1.0.2"
  var externalId: String?
  var isLoggedIn = false
  var savedTags: [String: String] = [:]
  var pushSubscriptionId: String?
  var pushSubscriptionToken: String?
  var pushSubscriptionOptedIn = false
  var permission = false
  var canRequestPermission = false
  var permissionStatus: UNAuthorizationStatus = .notDetermined
  var logLevel: SallaPushLogLevel = .warn

  private(set) var initializations: [Initialization] = []
  private(set) var calls: [Call] = []
  private(set) var deviceTokens: [Data] = []
  private(set) var registrationErrors: [Error] = []
  private(set) var remoteNotifications: [[AnyHashable: Any]] = []
  private(set) var presentedNotifications: [UNNotification] = []
  private(set) var responses: [UNNotificationResponse] = []
  private(set) var checkedPayloads: [[AnyHashable: Any]] = []
  private(set) var clickListeners: [Registration<(ClickEventMessage) -> Void>] = []
  private(set) var foregroundListeners: [Registration<(NativeWillDisplay) -> Void>] = []
  private(set) var logHandlers: [Registration<(LogEntryMessage) -> Void>] = []
  /// The level of each log handler, in the order of `logHandlers`.
  private(set) var logHandlerLevels: [SallaPushLogLevel] = []
  private(set) var permissionObservers: [Registration<(Bool) -> Void>] = []
  private(set) var userObservers: [Registration<(UserChangedMessage) -> Void>] = []
  private(set) var loginFailureHandlers: [Registration<(LoginFailureMessage) -> Void>] = []
  private(set) var subscriptionObservers: [Registration<SubscriptionHandler>] = []
  private var permissionAnswers: [(Bool) -> Void] = []

  /// Every listener registration that is not cancelled.
  var liveRegistrations: [NativeObservation] {
    let registrations: [[NativeObservation]] = [
      clickListeners.filter { !$0.isCancelled }, foregroundListeners.filter { !$0.isCancelled },
      permissionObservers.filter { !$0.isCancelled }, userObservers.filter { !$0.isCancelled },
      loginFailureHandlers.filter { !$0.isCancelled }, subscriptionObservers.filter { !$0.isCancelled },
      logHandlers.filter { !$0.isCancelled },
    ]
    return registrations.flatMap { $0 }
  }

  func initialize(appId: String, configuration: SallaPushConfiguration) {
    initializations.append(Initialization(appId: appId, configuration: configuration))
  }

  func setConsentRequired(_ required: Bool) {
    calls.append(.setConsentRequired(required))
  }

  func setConsentGiven(_ given: Bool) {
    calls.append(.setConsentGiven(given))
  }

  func login(externalId: String, identityToken: String) {
    calls.append(.login(externalId: externalId, identityToken: identityToken))
  }

  func logout() {
    calls.append(.logout)
  }

  func addTag(key: String, value: String) {
    calls.append(.addTag(key: key, value: value))
  }

  func addTags(_ tags: [String: String]) {
    calls.append(.addTags(tags))
  }

  func removeTag(_ key: String) {
    calls.append(.removeTag(key))
  }

  func removeTags(_ keys: [String]) {
    calls.append(.removeTags(keys))
  }

  func getTags() -> [String: String] {
    savedTags
  }

  func setLanguage(_ language: String?) {
    calls.append(.setLanguage(language))
  }

  func optIn() {
    calls.append(.optIn)
  }

  func optOut() {
    calls.append(.optOut)
  }

  func addPushSubscriptionObserver(_ handler: @escaping SubscriptionHandler) -> NativeObservation {
    let registration = Registration(handler)
    subscriptionObservers.append(registration)
    return registration
  }

  func addUserObserver(_ handler: @escaping (UserChangedMessage) -> Void) -> NativeObservation {
    let registration = Registration(handler)
    userObservers.append(registration)
    return registration
  }

  func addLoginFailureHandler(_ handler: @escaping (LoginFailureMessage) -> Void) -> NativeObservation {
    let registration = Registration(handler)
    loginFailureHandlers.append(registration)
    return registration
  }

  func addPermissionObserver(_ handler: @escaping (Bool) -> Void) -> NativeObservation {
    let registration = Registration(handler)
    permissionObservers.append(registration)
    return registration
  }

  func addClickListener(_ handler: @escaping (ClickEventMessage) -> Void) -> NativeObservation {
    let registration = Registration(handler)
    clickListeners.append(registration)
    return registration
  }

  func addForegroundLifecycleListener(_ handler: @escaping (NativeWillDisplay) -> Void) -> NativeObservation {
    let registration = Registration(handler)
    foregroundListeners.append(registration)
    return registration
  }

  func requestPermission(fallbackToSettings: Bool, completion: @escaping (Bool) -> Void) {
    calls.append(.requestPermission(fallbackToSettings: fallbackToSettings))
    permissionAnswers.append(completion)
  }

  func registerForProvisionalAuthorization(completion: @escaping (Bool) -> Void) {
    calls.append(.registerForProvisionalAuthorization)
    permissionAnswers.append(completion)
  }

  /// Answers the pending permission requests, as SallaPush does when the user has answered.
  func answerPermissionRequests(_ granted: Bool) {
    let answers = permissionAnswers
    permissionAnswers = []
    answers.forEach { $0(granted) }
  }

  func refreshPermission() {
    calls.append(.refreshPermission)
  }

  func registerForRemoteNotifications() {
    calls.append(.registerForRemoteNotifications)
  }

  func clearAll() {
    calls.append(.clearAll)
  }

  func isSallaPushNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
    checkedPayloads.append(userInfo)
    return SallaPush.Notifications.isSallaPushNotification(userInfo)
  }

  func setLogLevel(_ level: SallaPushLogLevel) {
    calls.append(.setLogLevel(level))
  }

  func addLogHandler(level: SallaPushLogLevel, _ handler: @escaping (LogEntryMessage) -> Void) -> NativeObservation {
    let registration = Registration(handler)
    logHandlers.append(registration)
    logHandlerLevels.append(level)
    return registration
  }

  func didRegisterForRemoteNotifications(deviceToken: Data) {
    deviceTokens.append(deviceToken)
  }

  func didFailToRegisterForRemoteNotifications(error: Error) {
    registrationErrors.append(error)
  }

  func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
    remoteNotifications.append(userInfo)
    return SallaPush.Notifications.isSallaPushNotification(userInfo)
  }

  func willPresent(_ notification: UNNotification) -> UNNotificationPresentationOptions? {
    presentedNotifications.append(notification)
    return SallaPush.Notifications.isSallaPushNotification(notification.request.content.userInfo) ? Self.options : nil
  }

  func didReceive(_ response: UNNotificationResponse) -> Bool {
    responses.append(response)
    return SallaPush.Notifications.isSallaPushNotification(response.notification.request.content.userInfo)
  }
}

final class ConsoleRecorder {
  enum Level {
    case info
    case error
  }

  struct Line: Equatable {
    let level: Level
    let message: String
  }

  private(set) var lines: [Line] = []

  var console: Console {
    Console(
      info: { self.lines.append(Line(level: .info, message: $0)) },
      error: { self.lines.append(Line(level: .error, message: $0)) })
  }
}

/// An app delegate that records the life-cycle delegates added to it.
final class LifeCycleProviderAppDelegate: NSObject, UIApplicationDelegate, FlutterAppLifeCycleProvider {
  private(set) var lifeCycleDelegates: [FlutterApplicationLifeCycleDelegate] = []

  func add(_ delegate: FlutterApplicationLifeCycleDelegate) {
    lifeCycleDelegates.append(delegate)
  }
}

/// UNUserNotificationCenter's delegate slot, held strongly.
final class NotificationCenterSlot {
  var delegate: UNUserNotificationCenterDelegate?
}

/// The engine's messenger, faked: keeps the handlers set on it, delivers messages to them as Dart sends them, and keeps
/// the messages sent to Dart.
final class FakeBinaryMessenger: NSObject, FlutterBinaryMessenger {
  private(set) var handlers: [String: FlutterBinaryMessageHandler] = [:]
  private(set) var sent: [(channel: String, message: Data?)] = []

  func send(onChannel channel: String, message: Data?) {
    sent.append((channel, message))
  }

  func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) {}

  func setMessageHandlerOnChannel(
    _ channel: String,
    binaryMessageHandler handler: FlutterBinaryMessageHandler?
  ) -> FlutterBinaryMessengerConnection {
    handlers[channel] = handler
    return 0
  }

  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}

  /// Sends `arguments` to the handler of `channel` and returns the decoded reply.
  func send(_ channel: String, arguments: [Any?]?) -> [Any?]? {
    let codec = SallaPushHostApiSetup.codec
    var reply: [Any?]?
    handlers[channel]?(arguments.flatMap { codec.encode($0) }) { data in
      reply = data.flatMap { codec.decode($0) as? [Any?] }
    }
    return reply
  }

  /// Sends Dart's `listen` or `cancel` to the event channel named `stream`.
  func streamCall(_ method: String, on stream: String) {
    let call = FlutterMethodCall(methodName: method, arguments: nil)
    handlers[FakeBinaryMessenger.eventChannel(stream)]?(messagesPigeonMethodCodec.encode(call)) { _ in }
  }

  /// The events of type `Message` sent to Dart on the event channel named `stream`, decoded.
  func events<Message>(on stream: String, as type: Message.Type) -> [Message] {
    sent.filter { $0.channel == FakeBinaryMessenger.eventChannel(stream) }.compactMap { sent in
      sent.message.flatMap { messagesPigeonMethodCodec.decodeEnvelope($0) as? Message }
    }
  }

  static func eventChannel(_ stream: String) -> String {
    "dev.flutter.pigeon.mobile_push.SallaPushEventChannelApi.\(stream)"
  }
}

/// A plugin registrar that records what a plugin registers with it.
final class FakeRegistrar: NSObject, FlutterPluginRegistrar {
  let binaryMessenger = FakeBinaryMessenger()
  private(set) var published: [NSObject] = []
  private(set) var applicationDelegates: [FlutterPlugin] = []

  var viewController: UIViewController? { nil }

  func messenger() -> FlutterBinaryMessenger { binaryMessenger }

  func textures() -> FlutterTextureRegistry { FakeTextureRegistry() }

  func register(_ factory: FlutterPlatformViewFactory, withId factoryId: String) {}

  func register(
    _ factory: FlutterPlatformViewFactory, withId factoryId: String,
    gestureRecognizersBlockingPolicy: FlutterPlatformViewGestureRecognizersBlockingPolicy
  ) {}

  func publish(_ value: NSObject) {
    published.append(value)
  }

  func addMethodCallDelegate(_ delegate: FlutterPlugin, channel: FlutterMethodChannel) {}

  func addApplicationDelegate(_ delegate: FlutterPlugin) {
    applicationDelegates.append(delegate)
  }

  func addSceneDelegate(_ delegate: FlutterSceneLifeCycleDelegate) {}

  func lookupKey(forAsset asset: String) -> String { asset }

  func lookupKey(forAsset asset: String, fromPackage package: String) -> String { asset }

  func valuePublished(byPlugin pluginKey: String) -> NSObject? { nil }
}

private final class FakeTextureRegistry: NSObject, FlutterTextureRegistry {
  func register(_ texture: FlutterTexture) -> Int64 { 0 }

  func textureFrameAvailable(_ textureId: Int64) {}

  func unregisterTexture(_ textureId: Int64) {}
}

/// UNNotification and UNNotificationResponse have no public initializers; these decode them from archived requests.
enum TestNotifications {
  static let foreignPayload: [AnyHashable: Any] = ["aps": ["alert": ["title": "Another SDK", "body": "Not SallaPush"]]]

  static func payload(named name: String) throws -> [AnyHashable: Any] {
    let url = try XCTUnwrap(Bundle(for: ConsoleRecorder.self).url(forResource: name, withExtension: "apns"))
    let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
    return try XCTUnwrap(object as? [AnyHashable: Any])
  }

  static func notification(userInfo: [AnyHashable: Any]) throws -> UNNotification {
    let content = UNMutableNotificationContent()
    content.userInfo = userInfo
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    return try XCTUnwrap(decoded(UNNotification.self, ["request": request, "date": Date()]))
  }

  static func response(userInfo: [AnyHashable: Any]) throws -> UNNotificationResponse {
    let notification = try notification(userInfo: userInfo)
    return try XCTUnwrap(
      decoded(
        UNNotificationResponse.self,
        ["notification": notification, "actionIdentifier": UNNotificationDefaultActionIdentifier]))
  }

  private static func decoded<T: NSObject & NSCoding>(_ type: T.Type, _ values: [String: Any]) throws -> T? {
    let archiver = NSKeyedArchiver(requiringSecureCoding: false)
    for (key, value) in values {
      archiver.encode(value, forKey: key)
    }
    archiver.finishEncoding()
    let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
    unarchiver.requiresSecureCoding = false
    return T(coder: unarchiver)
  }
}

/// Bridge messages for tests.
enum TestMessages {
  static func notification(_ notificationId: String = "msg_1") -> NotificationMessage {
    NotificationMessage(
      notificationId: notificationId, additionalData: [:], rawPayload: [:], source: .native, stringValues: [:],
      intValues: [:], boolValues: [:], numberValues: [:])
  }

  static func click(url: String? = nil) -> ClickEventMessage {
    ClickEventMessage(notification: notification(), url: url)
  }

  static func logEntry(_ code: String = "register.ok") -> LogEntryMessage {
    LogEntryMessage(
      level: .info, category: "registration", code: code, message: "The device is registered.", metadata: [:],
      timestampMillis: 1_791_842_518_123)
  }
}

/// A foreground notification SallaPush offers, faked: records whether it was prevented and how often it was shown.
final class FakeWillDisplay {
  let message: NotificationMessage
  private(set) var isPrevented = false
  private(set) var displays = 0

  init(_ notificationId: String = "msg_1") {
    message = TestMessages.notification(notificationId)
  }

  var event: NativeWillDisplay {
    NativeWillDisplay(message: message, preventDefault: { self.isPrevented = true }, display: { self.displays += 1 })
  }
}
