import Foundation
import SallaPush
import UserNotifications

/// A native listener registration: `cancel()` removes it. SallaPushObservation is one.
protocol NativeObservation: AnyObject {
  func cancel()
}

extension SallaPushObservation: NativeObservation {}

/// A foreground SallaPush notification about to be shown, as the registry gets it.
struct NativeWillDisplay {
  /// The notification's bridge form.
  let message: NotificationMessage
  /// Keeps the notification from being shown now; it counts only before the listener returns.
  let preventDefault: () -> Void
  /// Shows the original notification later: SallaPush shows only the very object it offered.
  let display: () -> Void
}

/// The SallaPush iOS calls the plugin makes; tests replace them. Listeners get their events in bridge form.
protocol NativeSallaPush {
  func initialize(appId: String, configuration: SallaPushConfiguration)
  var isInitialized: Bool { get }
  var appId: String? { get }
  var sdkVersion: String { get }
  func setConsentRequired(_ required: Bool)
  func setConsentGiven(_ given: Bool)
  func login(externalId: String, identityToken: String)
  func logout()
  var externalId: String? { get }
  var isLoggedIn: Bool { get }
  func addTag(key: String, value: String)
  func addTags(_ tags: [String: String])
  func removeTag(_ key: String)
  func removeTags(_ keys: [String])
  func getTags() -> [String: String]
  func setLanguage(_ language: String?)
  var pushSubscriptionId: String? { get }
  var pushSubscriptionToken: String? { get }
  var pushSubscriptionOptedIn: Bool { get }
  func optIn()
  func optOut()
  func addPushSubscriptionObserver(
    _ handler: @escaping (_ previous: SubscriptionStateMessage, _ current: SubscriptionStateMessage) -> Void
  ) -> NativeObservation
  func addUserObserver(_ handler: @escaping (UserChangedMessage) -> Void) -> NativeObservation
  func addLoginFailureHandler(_ handler: @escaping (LoginFailureMessage) -> Void) -> NativeObservation
  var permission: Bool { get }
  var canRequestPermission: Bool { get }
  var permissionStatus: UNAuthorizationStatus { get }
  func requestPermission(fallbackToSettings: Bool, completion: @escaping (Bool) -> Void)
  func registerForProvisionalAuthorization(completion: @escaping (Bool) -> Void)
  func refreshPermission()
  func addPermissionObserver(_ handler: @escaping (Bool) -> Void) -> NativeObservation
  func addClickListener(_ handler: @escaping (ClickEventMessage) -> Void) -> NativeObservation
  func addForegroundLifecycleListener(_ handler: @escaping (NativeWillDisplay) -> Void) -> NativeObservation
  func registerForRemoteNotifications()
  func clearAll()
  func isSallaPushNotification(_ userInfo: [AnyHashable: Any]) -> Bool
  var logLevel: SallaPushLogLevel { get }
  func setLogLevel(_ level: SallaPushLogLevel)
  /// The handler gets SallaPush's entries on SallaPush's log queue, not on the main thread.
  func addLogHandler(level: SallaPushLogLevel, _ handler: @escaping (LogEntryMessage) -> Void) -> NativeObservation
  func didRegisterForRemoteNotifications(deviceToken: Data)
  func didFailToRegisterForRemoteNotifications(error: Error)
  func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any]) -> Bool
  func willPresent(_ notification: UNNotification) -> UNNotificationPresentationOptions?
  func didReceive(_ response: UNNotificationResponse) -> Bool
}

struct LiveNativeSallaPush: NativeSallaPush {
  func initialize(appId: String, configuration: SallaPushConfiguration) {
    SallaPush.initialize(appId, withLaunchOptions: nil, configuration: configuration)
  }

  var isInitialized: Bool { SallaPush.isInitialized }

  var appId: String? { SallaPush.appId }

  var sdkVersion: String { SallaPush.sdkVersion }

  func setConsentRequired(_ required: Bool) {
    SallaPush.setConsentRequired(required)
  }

  func setConsentGiven(_ given: Bool) {
    SallaPush.setConsentGiven(given)
  }

  func login(externalId: String, identityToken: String) {
    SallaPush.login(externalId: externalId, identityToken: identityToken)
  }

  func logout() {
    SallaPush.logout()
  }

  var externalId: String? { SallaPush.User.externalId }

  var isLoggedIn: Bool { SallaPush.User.isLoggedIn }

  func addTag(key: String, value: String) {
    SallaPush.User.addTag(key: key, value: value)
  }

  func addTags(_ tags: [String: String]) {
    SallaPush.User.addTags(tags)
  }

  func removeTag(_ key: String) {
    SallaPush.User.removeTag(key)
  }

  func removeTags(_ keys: [String]) {
    SallaPush.User.removeTags(keys)
  }

  func getTags() -> [String: String] {
    SallaPush.User.getTags()
  }

  func setLanguage(_ language: String?) {
    SallaPush.User.setLanguage(language)
  }

  var pushSubscriptionId: String? { SallaPush.User.pushSubscription.id }

  var pushSubscriptionToken: String? { SallaPush.User.pushSubscription.token }

  var pushSubscriptionOptedIn: Bool { SallaPush.User.pushSubscription.optedIn }

  func optIn() {
    SallaPush.User.pushSubscription.optIn()
  }

  func optOut() {
    SallaPush.User.pushSubscription.optOut()
  }

  func addPushSubscriptionObserver(
    _ handler: @escaping (_ previous: SubscriptionStateMessage, _ current: SubscriptionStateMessage) -> Void
  ) -> NativeObservation {
    SallaPush.User.pushSubscription.addObserver { handler($0.previous.message, $0.current.message) }
  }

  func addUserObserver(_ handler: @escaping (UserChangedMessage) -> Void) -> NativeObservation {
    SallaPush.User.addObserver { handler($0.message) }
  }

  func addLoginFailureHandler(_ handler: @escaping (LoginFailureMessage) -> Void) -> NativeObservation {
    SallaPush.User.addLoginFailureHandler { handler($0.message) }
  }

  var permission: Bool { SallaPush.Notifications.permission }

  var canRequestPermission: Bool { SallaPush.Notifications.canRequestPermission }

  var permissionStatus: UNAuthorizationStatus { SallaPush.Notifications.permissionStatus }

  func requestPermission(fallbackToSettings: Bool, completion: @escaping (Bool) -> Void) {
    SallaPush.Notifications.requestPermission(fallbackToSettings: fallbackToSettings) { completion($0) }
  }

  func registerForProvisionalAuthorization(completion: @escaping (Bool) -> Void) {
    SallaPush.Notifications.registerForProvisionalAuthorization { completion($0) }
  }

  func refreshPermission() {
    SallaPush.Notifications.refreshPermission()
  }

  func addPermissionObserver(_ handler: @escaping (Bool) -> Void) -> NativeObservation {
    SallaPush.Notifications.addPermissionObserver { handler($0) }
  }

  func addClickListener(_ handler: @escaping (ClickEventMessage) -> Void) -> NativeObservation {
    SallaPush.Notifications.addClickListener { handler($0.message) }
  }

  func addForegroundLifecycleListener(_ handler: @escaping (NativeWillDisplay) -> Void) -> NativeObservation {
    SallaPush.Notifications.addForegroundLifecycleListener { event in
      handler(
        NativeWillDisplay(
          message: event.notification.message, preventDefault: event.preventDefault,
          display: event.notification.display))
    }
  }

  func registerForRemoteNotifications() {
    SallaPush.Notifications.registerForRemoteNotifications()
  }

  func clearAll() {
    SallaPush.Notifications.clearAll()
  }

  func isSallaPushNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
    SallaPush.Notifications.isSallaPushNotification(userInfo)
  }

  var logLevel: SallaPushLogLevel { SallaPush.Debug.logLevel }

  func setLogLevel(_ level: SallaPushLogLevel) {
    SallaPush.Debug.setLogLevel(level)
  }

  func addLogHandler(level: SallaPushLogLevel, _ handler: @escaping (LogEntryMessage) -> Void) -> NativeObservation {
    let registration = LogHandlerRegistration()
    SallaPush.Debug.setLogHandler(level: level) { handler(LogEntryMessage($0)) }
    return registration
  }

  func didRegisterForRemoteNotifications(deviceToken: Data) {
    SallaPush.Notifications.didRegisterForRemoteNotifications(deviceToken: deviceToken)
  }

  func didFailToRegisterForRemoteNotifications(error: Error) {
    SallaPush.Notifications.didFailToRegisterForRemoteNotifications(error: error)
  }

  func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
    SallaPush.Notifications.didReceiveRemoteNotification(userInfo)
  }

  func willPresent(_ notification: UNNotification) -> UNNotificationPresentationOptions? {
    SallaPush.Notifications.willPresent(notification)
  }

  func didReceive(_ response: UNNotificationResponse) -> Bool {
    SallaPush.Notifications.didReceive(response)
  }
}

/// The plugin's SallaPush log handler. SallaPush keeps one per process, so a cancel removes it only while no later
/// registration has replaced it. Main thread only.
final class LogHandlerRegistration: NativeObservation {
  /// The registration whose handler SallaPush holds; nil once that one is cancelled.
  private(set) static weak var current: LogHandlerRegistration?

  init() {
    Self.current = self
  }

  func cancel() {
    guard Self.current === self else { return }
    Self.current = nil
    SallaPush.Debug.setLogHandler(level: .warn, nil)
  }
}
