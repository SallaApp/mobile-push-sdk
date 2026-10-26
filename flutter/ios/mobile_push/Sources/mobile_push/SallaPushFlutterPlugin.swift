import Flutter
import UIKit

/// The bridge from Dart: each host method is one call into SallaPush, and each event stream a native listener.
public final class SallaPushFlutterPlugin: NSObject, FlutterPlugin {
  private static let eventChannels = [
    "clickEvents", "willDisplayEvents", "permissionChanges", "userChanges", "loginFailures", "pushSubscriptionChanges",
    "logEntries",
  ].map { "dev.flutter.pigeon.mobile_push.SallaPushEventChannelApi.\($0)" }

  private let native: NativeSallaPush
  private let earlyInit: () -> StaticConfig?
  private let console: Console
  private let platformOnly: PlatformOnlyCalls
  private let displays = DisplayStore()
  private let events: EventRegistry

  init(
    native: NativeSallaPush, earlyInit: @escaping () -> StaticConfig?, console: Console,
    platformOnly: PlatformOnlyCalls
  ) {
    self.native = native
    self.earlyInit = earlyInit
    self.console = console
    self.platformOnly = platformOnly
    events = EventRegistry(native: native, displays: displays)
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    // No addApplicationDelegate: the life-cycle object that start() registers already gets those calls.
    Starter.shared.startFromPlugin()
    let plugin = SallaPushFlutterPlugin(
      native: LiveNativeSallaPush(), earlyInit: { Starter.shared.earlyInit }, console: .live,
      platformOnly: .shared)
    plugin.attach(to: registrar.messenger())
    // A published plugin is told when its engine goes away.
    registrar.publish(plugin)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    detach(from: registrar.messenger())
  }

  /// Sets up the host API and the event streams on the engine's messenger.
  func attach(to messenger: FlutterBinaryMessenger) {
    SallaPushHostApiSetup.setUp(binaryMessenger: messenger, api: self)
    ClickEventsStreamHandler.register(with: messenger, streamHandler: ClickEvents(events))
    WillDisplayEventsStreamHandler.register(with: messenger, streamHandler: WillDisplayEvents(events))
    PermissionChangesStreamHandler.register(with: messenger, streamHandler: PermissionChanges(events))
    UserChangesStreamHandler.register(with: messenger, streamHandler: UserChanges(events))
    LoginFailuresStreamHandler.register(with: messenger, streamHandler: LoginFailures(events))
    PushSubscriptionChangesStreamHandler.register(with: messenger, streamHandler: PushSubscriptionChanges(events))
    LogEntriesStreamHandler.register(with: messenger, streamHandler: LogEntries(events))
  }

  /// Removes every native listener, the held notifications, the host API and the event streams.
  func detach(from messenger: FlutterBinaryMessenger) {
    events.stopAll()
    displays.clear()
    SallaPushHostApiSetup.setUp(binaryMessenger: messenger, api: nil)
    for channel in Self.eventChannels {
      messenger.setMessageHandlerOnChannel(channel, binaryMessageHandler: nil)
    }
  }
}

extension SallaPushFlutterPlugin: SallaPushHostApi {
  func initialize(appId: String, config: ConfigMessage) {
    if let early = earlyInit(), early.appId == appId {
      reportOptionsIgnored(by: config)
    }
    native.initialize(appId: appId, configuration: config.configuration())
  }

  func isInitialized() -> Bool {
    native.isInitialized
  }

  func appId() -> String? {
    native.appId
  }

  func sdkVersion() -> String {
    native.sdkVersion
  }

  func setConsentRequired(required: Bool) {
    if required, let early = earlyInit(), early.requiresUserConsent != true {
      console.error(
        "setConsentRequired(true) came after SallaPush started at launch without requiring consent, so this device "
          + "may already have registered and sent data. To require consent from the start, set the Info.plist key "
          + "\(StaticConfig.requiresUserConsentKey) to YES.")
    }
    native.setConsentRequired(required)
  }

  func setConsentGiven(given: Bool) {
    native.setConsentGiven(given)
  }

  func login(externalId: String, identityToken: String) {
    native.login(externalId: externalId, identityToken: identityToken)
  }

  func logout() {
    native.logout()
  }

  func externalId() -> String? {
    native.externalId
  }

  func isLoggedIn() -> Bool {
    native.isLoggedIn
  }

  func addTag(key: String, value: String) {
    native.addTag(key: key, value: value)
  }

  func addTags(tags: [String: String]) {
    native.addTags(tags)
  }

  func removeTag(key: String) {
    native.removeTag(key)
  }

  func removeTags(keys: [String]) {
    native.removeTags(keys)
  }

  func getTags() -> [String: String] {
    native.getTags()
  }

  func setLanguage(language: String?) {
    native.setLanguage(language)
  }

  func pushSubscriptionId() -> String? {
    native.pushSubscriptionId
  }

  func pushSubscriptionToken() -> String? {
    native.pushSubscriptionToken
  }

  func pushSubscriptionOptedIn() -> Bool {
    native.pushSubscriptionOptedIn
  }

  func optIn() {
    native.optIn()
  }

  func optOut() {
    native.optOut()
  }

  func addPushSubscriptionListener(listenerId: Int64) {
    events.addSubscriptionListener(listenerId)
  }

  func removePushSubscriptionListener(listenerId: Int64) {
    events.removeSubscriptionListener(listenerId)
  }

  func permission() -> Bool {
    native.permission
  }

  func canRequestPermission() -> Bool {
    native.canRequestPermission
  }

  func permissionStatus() -> IosPermissionStatusMessage? {
    native.permissionStatus.message
  }

  func requestPermission(fallbackToSettings: Bool, completion: @escaping (Result<Bool, Error>) -> Void) {
    native.requestPermission(fallbackToSettings: fallbackToSettings) { completion(.success($0)) }
  }

  func registerForProvisionalAuthorization(completion: @escaping (Result<Bool, Error>) -> Void) {
    native.registerForProvisionalAuthorization { completion(.success($0)) }
  }

  func refreshPermission() {
    native.refreshPermission()
  }

  func registerForRemoteNotifications() {
    native.registerForRemoteNotifications()
  }

  func forwardApnsToken(apnsToken: String) {
    guard let deviceToken = Data(hexadecimalText: apnsToken) else {
      console.error(
        "SallaPush.notifications.forwardApnsToken ignored a token that is not hexadecimal text of even length.")
      return
    }
    native.didRegisterForRemoteNotifications(deviceToken: deviceToken)
  }

  func clearAll() {
    native.clearAll()
  }

  func removeNotification(androidNotificationId: Int64) {
    reportAndroidOnly("notifications.removeNotification", outcome: "does nothing")
  }

  func isSallaPushNotification(payload: [String: Any?]) -> Bool {
    native.isSallaPushNotification(payload.userInfo)
  }

  func trackOpened(additionalData: [String: Any?]?) -> Bool {
    reportAndroidOnly("notifications.trackOpened", outcome: "returns false")
    return false
  }

  func displayNotification(handle: String) {
    guard displays.display(handle) else {
      console.info(
        "display() did nothing: a notification from onWillDisplay can be shown once, within 10 minutes of its event.")
      return
    }
  }

  func setDisplayCompatPayloads(display: Bool) {
    reportAndroidOnly("migration.setDisplayCompatPayloads", outcome: "does nothing")
  }

  func logLevel() -> LogLevelMessage {
    native.logLevel.message
  }

  func setLogLevel(level: LogLevelMessage) {
    native.setLogLevel(level.native)
  }

  func setLogHandlerLevel(level: LogLevelMessage) {
    events.setLogLevel(level.native)
  }

  private func reportAndroidOnly(_ member: String, outcome: String) {
    guard platformOnly.isFirst(member) else { return }
    console.info("SallaPush.\(member) works on Android only; on iOS it \(outcome).")
  }

  /// SallaPush ignores every option of an initialize with the app id it already runs with.
  private func reportOptionsIgnored(by config: ConfigMessage) {
    let ignored = [
      (config.logLevel != nil, "logLevel", "SallaPushLogLevel"),
      (config.appVersion != nil, "appVersion", StaticConfig.appVersionKey),
      (config.clearTagsOnLogout != nil, "clearTagsOnLogout", StaticConfig.clearTagsOnLogoutKey),
      (config.requiresUserConsent != nil, "requiresUserConsent", StaticConfig.requiresUserConsentKey),
      (config.openLaunchUrls != nil, "openLaunchUrls", StaticConfig.openLaunchURLsKey),
      (config.autoClearBadge != nil, "autoClearBadge", StaticConfig.autoClearBadgeKey),
      (config.autoUpdateBadge != nil, "autoUpdateBadge", StaticConfig.autoUpdateBadgeKey),
      (config.iosAppGroupIdentifier != nil, "ios.appGroupIdentifier", "SallaPushAppGroup"),
      (config.iosApnsEnvironment != nil, "ios.apnsEnvironment", StaticConfig.apnsEnvironmentKey),
      (
        config.iosRegisterForRemoteNotificationsOnInit != nil, "ios.registerForRemoteNotificationsOnInit",
        StaticConfig.registerForRemoteNotificationsOnInitKey
      ),
    ].filter { isSet, _, _ in isSet }.map { _, option, key in "\(option) (\(key))" }
    guard !ignored.isEmpty else { return }
    console.error(
      "SallaPush already started at launch with this app id, so initialize ignored its options. Set each with its "
        + "Info.plist key instead: \(ignored.joined(separator: ", ")).")
  }
}

// Each Dart event stream: Dart's first listen registers the native listener, and its last cancel, which a hot restart's
// first listen also sends, removes it.

private final class ClickEvents: ClickEventsStreamHandler {
  private let events: EventRegistry

  init(_ events: EventRegistry) {
    self.events = events
  }

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<ClickEventMessage>) {
    events.clickSink = sink
    events.start(.click)
  }

  override func onCancel(withArguments arguments: Any?) {
    events.stop(.click)
    events.clickSink = nil
  }
}

private final class WillDisplayEvents: WillDisplayEventsStreamHandler {
  private let events: EventRegistry

  init(_ events: EventRegistry) {
    self.events = events
  }

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<WillDisplayEventMessage>) {
    events.willDisplaySink = sink
    events.start(.willDisplay)
  }

  override func onCancel(withArguments arguments: Any?) {
    events.stop(.willDisplay)
    events.willDisplaySink = nil
  }
}

private final class PermissionChanges: PermissionChangesStreamHandler {
  private let events: EventRegistry

  init(_ events: EventRegistry) {
    self.events = events
  }

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<PermissionChangeMessage>) {
    events.permissionSink = sink
    events.start(.permission)
  }

  override func onCancel(withArguments arguments: Any?) {
    events.stop(.permission)
    events.permissionSink = nil
  }
}

private final class UserChanges: UserChangesStreamHandler {
  private let events: EventRegistry

  init(_ events: EventRegistry) {
    self.events = events
  }

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<UserChangedMessage>) {
    events.userSink = sink
    events.start(.user)
  }

  override func onCancel(withArguments arguments: Any?) {
    events.stop(.user)
    events.userSink = nil
  }
}

private final class LoginFailures: LoginFailuresStreamHandler {
  private let events: EventRegistry

  init(_ events: EventRegistry) {
    self.events = events
  }

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<LoginFailureEventMessage>) {
    events.loginFailureSink = sink
    events.start(.loginFailure)
  }

  override func onCancel(withArguments arguments: Any?) {
    events.stop(.loginFailure)
    events.loginFailureSink = nil
  }
}

/// The native observers are added per Dart listener, by `addPushSubscriptionListener`.
private final class PushSubscriptionChanges: PushSubscriptionChangesStreamHandler {
  private let events: EventRegistry

  init(_ events: EventRegistry) {
    self.events = events
  }

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<SubscriptionChangedMessage>) {
    events.pushSubscriptionSink = sink
  }

  override func onCancel(withArguments arguments: Any?) {
    events.removeSubscriptionListeners()
    events.pushSubscriptionSink = nil
  }
}

/// The native log handler is registered at the level `setLogHandlerLevel` set before Dart listens.
private final class LogEntries: LogEntriesStreamHandler {
  private let events: EventRegistry

  init(_ events: EventRegistry) {
    self.events = events
  }

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<LogEntryMessage>) {
    events.logSink = sink
    events.start(.log)
  }

  override func onCancel(withArguments arguments: Any?) {
    events.stop(.log)
    events.logSink = nil
  }
}
