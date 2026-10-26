import Foundation
import SallaPush
import UserNotifications

/// A native registration the wrapper cancels once JavaScript stops listening.
protocol NativeObservation: AnyObject {
    func cancel()
}

extension SallaPushObservation: NativeObservation {}

/// The native SallaPush calls the wrapper makes. Tests replace it with a fake.
protocol NativeSallaPush: AnyObject {
    func initialize(_ appId: String, configuration: SallaPushConfiguration)
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
    /// Native's Objective-C `addTags:`, which skips and logs the entries that aren't strings.
    func addTags(_ tags: [AnyHashable: Any])
    func removeTag(_ key: String)
    /// Native's Objective-C `removeTags:`, which skips and logs the keys that aren't strings.
    func removeTags(_ keys: [Any])
    var tags: [String: String] { get }
    func setLanguage(_ language: String?)
    func addUserObserver(_ handler: @escaping (SallaPushUserChangedState) -> Void) -> NativeObservation
    func addLoginFailureHandler(_ handler: @escaping (SallaPushLoginFailure) -> Void) -> NativeObservation

    var pushSubscriptionId: String? { get }
    var pushSubscriptionToken: String? { get }
    var pushSubscriptionOptedIn: Bool { get }
    func optIn()
    func optOut()
    func addSubscriptionObserver(_ handler: @escaping (SallaPushSubscriptionChangedState) -> Void) -> NativeObservation

    var permission: Bool { get }
    var canRequestPermission: Bool { get }
    var permissionStatus: UNAuthorizationStatus { get }
    func requestPermission(fallbackToSettings: Bool, completion: @escaping (Bool) -> Void)
    func registerForProvisionalAuthorization(completion: @escaping (Bool) -> Void)
    func refreshPermission()
    func registerForRemoteNotifications()
    func didRegisterForRemoteNotifications(deviceToken: Data)
    func clearAll()
    func isSallaPushNotification(_ userInfo: [AnyHashable: Any]) -> Bool
    func addClickListener(_ handler: @escaping (SallaPushClickEvent) -> Void) -> NativeObservation
    /// Native calls `handler` synchronously on the main thread, before a SallaPush notification shows in the foreground.
    func addForegroundLifecycleListener(_ handler: @escaping (SallaPushWillDisplayEvent) -> Void) -> NativeObservation
    func display(_ notification: SallaPushNotification)
    func addPermissionObserver(_ handler: @escaping (Bool) -> Void) -> NativeObservation

    var logLevel: SallaPushLogLevel { get set }
    /// Native's one log handler for the process, called on native's own queue; cancelling the registration removes it.
    func setLogHandler(level: SallaPushLogLevel, _ handler: @escaping (SallaPushLogEntry) -> Void) -> NativeObservation
}

final class LiveNativeSallaPush: NativeSallaPush {
    func initialize(_ appId: String, configuration: SallaPushConfiguration) {
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

    // Swift can't name the Objective-C forms (`@available(swift, obsoleted: 1)`), so their selectors are sent.
    func addTags(_ tags: [AnyHashable: Any]) {
        _ = SallaPush.User.perform(NSSelectorFromString("addTags:"), with: tags)
    }

    func removeTag(_ key: String) {
        SallaPush.User.removeTag(key)
    }

    func removeTags(_ keys: [Any]) {
        _ = SallaPush.User.perform(NSSelectorFromString("removeTags:"), with: keys)
    }

    var tags: [String: String] { SallaPush.User.getTags() }

    func setLanguage(_ language: String?) {
        SallaPush.User.setLanguage(language)
    }

    func addUserObserver(_ handler: @escaping (SallaPushUserChangedState) -> Void) -> NativeObservation {
        SallaPush.User.addObserver { handler($0) }
    }

    func addLoginFailureHandler(_ handler: @escaping (SallaPushLoginFailure) -> Void) -> NativeObservation {
        SallaPush.User.addLoginFailureHandler { handler($0) }
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

    func addSubscriptionObserver(_ handler: @escaping (SallaPushSubscriptionChangedState) -> Void) -> NativeObservation {
        SallaPush.User.pushSubscription.addObserver { handler($0) }
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

    func registerForRemoteNotifications() {
        SallaPush.Notifications.registerForRemoteNotifications()
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        SallaPush.Notifications.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func clearAll() {
        SallaPush.Notifications.clearAll()
    }

    func isSallaPushNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        SallaPush.Notifications.isSallaPushNotification(userInfo)
    }

    func addClickListener(_ handler: @escaping (SallaPushClickEvent) -> Void) -> NativeObservation {
        SallaPush.Notifications.addClickListener { handler($0) }
    }

    func addForegroundLifecycleListener(_ handler: @escaping (SallaPushWillDisplayEvent) -> Void) -> NativeObservation {
        SallaPush.Notifications.addForegroundLifecycleListener { handler($0) }
    }

    func display(_ notification: SallaPushNotification) {
        notification.display()
    }

    func addPermissionObserver(_ handler: @escaping (Bool) -> Void) -> NativeObservation {
        SallaPush.Notifications.addPermissionObserver { handler($0) }
    }

    var logLevel: SallaPushLogLevel {
        get { SallaPush.Debug.logLevel }
        set { SallaPush.Debug.logLevel = newValue }
    }

    func setLogHandler(level: SallaPushLogLevel, _ handler: @escaping (SallaPushLogEntry) -> Void) -> NativeObservation {
        SallaPush.Debug.setLogHandler(level: level) { handler($0) }
        return LogHandlerRegistration()
    }
}

/// The process-wide log handler as a registration.
private final class LogHandlerRegistration: NativeObservation {
    func cancel() {
        SallaPush.Debug.setLogHandler(level: .warn, nil)
    }
}
