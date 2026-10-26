import SallaPush
@testable import SallaPushReactNative
import UserNotifications

final class RecordingConsole: ConsoleOutput {
    private(set) var errors: [String] = []
    private(set) var warnings: [String] = []
    private(set) var infos: [String] = []

    func error(_ message: String) {
        errors.append(message)
    }

    func warn(_ message: String) {
        warnings.append(message)
    }

    func info(_ message: String) {
        infos.append(message)
    }
}

/// Records the native calls in order, and answers the getters with the values a test sets.
final class FakeNativeSallaPush: NativeSallaPush {
    private(set) var calls: [String] = []
    private(set) var initializedAppIds: [String] = []
    private(set) var configurations: [SallaPushConfiguration] = []
    private(set) var addedTags: [[AnyHashable: Any]] = []
    private(set) var removedTags: [[Any]] = []
    private(set) var deviceTokens: [Data] = []
    private(set) var checkedPayloads: [[AnyHashable: Any]] = []
    var isInitialized = false
    var appId: String?
    var sdkVersion = "1.1.0"
    var externalId: String?
    var isLoggedIn = false
    var tags: [String: String] = [:]
    var pushSubscriptionId: String?
    var pushSubscriptionToken: String?
    var pushSubscriptionOptedIn = false
    var permission = false
    var canRequestPermission = false
    var permissionStatus: UNAuthorizationStatus = .notDetermined
    var permissionAnswer = false
    var recognizesPayloads = false
    var logLevel: SallaPushLogLevel = .warn
    private(set) var observations: [FakeObservation] = []
    private(set) var clickHandlers: [(SallaPushClickEvent) -> Void] = []
    private(set) var willDisplayHandlers: [(SallaPushWillDisplayEvent) -> Void] = []
    private(set) var displayed: [SallaPushNotification] = []
    private(set) var permissionHandlers: [(Bool) -> Void] = []
    private(set) var userHandlers: [(SallaPushUserChangedState) -> Void] = []
    private(set) var loginFailureHandlers: [(SallaPushLoginFailure) -> Void] = []
    private(set) var subscriptionHandlers: [(SallaPushSubscriptionChangedState) -> Void] = []
    private(set) var logHandlers: [(level: SallaPushLogLevel, handler: (SallaPushLogEntry) -> Void)] = []

    func initialize(_ appId: String, configuration: SallaPushConfiguration) {
        initializedAppIds.append(appId)
        configurations.append(configuration)
    }

    func setConsentRequired(_ required: Bool) {
        calls.append("setConsentRequired(\(required))")
    }

    func setConsentGiven(_ given: Bool) {
        calls.append("setConsentGiven(\(given))")
    }

    func login(externalId: String, identityToken: String) {
        calls.append("login(\(externalId), \(identityToken))")
    }

    func logout() {
        calls.append("logout()")
    }

    func addTag(key: String, value: String) {
        calls.append("addTag(\(key), \(value))")
    }

    func addTags(_ tags: [AnyHashable: Any]) {
        calls.append("addTags")
        addedTags.append(tags)
    }

    func removeTag(_ key: String) {
        calls.append("removeTag(\(key))")
    }

    func removeTags(_ keys: [Any]) {
        calls.append("removeTags")
        removedTags.append(keys)
    }

    func setLanguage(_ language: String?) {
        calls.append("setLanguage(\(language ?? "nil"))")
    }

    func optIn() {
        calls.append("optIn()")
    }

    func optOut() {
        calls.append("optOut()")
    }

    func requestPermission(fallbackToSettings: Bool, completion: @escaping (Bool) -> Void) {
        calls.append("requestPermission(\(fallbackToSettings))")
        completion(permissionAnswer)
    }

    func registerForProvisionalAuthorization(completion: @escaping (Bool) -> Void) {
        calls.append("registerForProvisionalAuthorization()")
        completion(permissionAnswer)
    }

    func refreshPermission() {
        calls.append("refreshPermission()")
    }

    func registerForRemoteNotifications() {
        calls.append("registerForRemoteNotifications()")
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        calls.append("didRegisterForRemoteNotifications")
        deviceTokens.append(deviceToken)
    }

    func clearAll() {
        calls.append("clearAll()")
    }

    func isSallaPushNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        checkedPayloads.append(userInfo)
        return recognizesPayloads
    }

    func addClickListener(_ handler: @escaping (SallaPushClickEvent) -> Void) -> NativeObservation {
        clickHandlers.append(handler)
        return observation("addClickListener")
    }

    func addForegroundLifecycleListener(_ handler: @escaping (SallaPushWillDisplayEvent) -> Void) -> NativeObservation {
        willDisplayHandlers.append(handler)
        return observation("addForegroundLifecycleListener")
    }

    func display(_ notification: SallaPushNotification) {
        displayed.append(notification)
    }

    func addPermissionObserver(_ handler: @escaping (Bool) -> Void) -> NativeObservation {
        permissionHandlers.append(handler)
        return observation("addPermissionObserver")
    }

    func addUserObserver(_ handler: @escaping (SallaPushUserChangedState) -> Void) -> NativeObservation {
        userHandlers.append(handler)
        return observation("addUserObserver")
    }

    func addLoginFailureHandler(_ handler: @escaping (SallaPushLoginFailure) -> Void) -> NativeObservation {
        loginFailureHandlers.append(handler)
        return observation("addLoginFailureHandler")
    }

    func addSubscriptionObserver(_ handler: @escaping (SallaPushSubscriptionChangedState) -> Void) -> NativeObservation {
        subscriptionHandlers.append(handler)
        return observation("addSubscriptionObserver")
    }

    func setLogHandler(level: SallaPushLogLevel, _ handler: @escaping (SallaPushLogEntry) -> Void) -> NativeObservation {
        logHandlers.append((level, handler))
        return observation("setLogHandler")
    }

    private func observation(_ call: String) -> FakeObservation {
        calls.append(call)
        let observation = FakeObservation()
        observations.append(observation)
        return observation
    }
}

/// A native registration that records its cancellation.
final class FakeObservation: NativeObservation {
    private(set) var isCancelled = false

    func cancel() {
        isCancelled = true
    }
}

/// Records the events the bridge emits to JavaScript, in order, and whether each came on the main thread.
final class RecordingEmitter: NSObject, SallaPushEventEmitter {
    private(set) var events: [(name: String, body: NSDictionary)] = []
    private(set) var onMainThread: [Bool] = []

    func emitOnClick(_ value: [String: Any]) {
        record("onClick", value)
    }

    func emitOnWillDisplay(_ value: [String: Any]) {
        record("onWillDisplay", value)
    }

    func emitOnPermissionChange(_ value: [String: Any]) {
        record("onPermissionChange", value)
    }

    func emitOnUserChange(_ value: [String: Any]) {
        record("onUserChange", value)
    }

    func emitOnLoginFailure(_ value: [String: Any]) {
        record("onLoginFailure", value)
    }

    func emitOnPushSubscriptionChange(_ value: [String: Any]) {
        record("onPushSubscriptionChange", value)
    }

    func emitOnLog(_ value: [String: Any]) {
        record("onLog", value)
    }

    private func record(_ name: String, _ value: [String: Any]) {
        events.append((name, value as NSDictionary))
        onMainThread.append(Thread.isMainThread)
    }
}

/// Holds its delegate weakly, as UNUserNotificationCenter does.
final class FakeNotificationCenter: UserNotificationCenter {
    weak var delegate: UNUserNotificationCenterDelegate?
}

/// Another SDK's delegate: it handles every notification it gets and completes it.
final class RecordingNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let presentationOptions: UNNotificationPresentationOptions
    private(set) var presented: [UNNotification] = []
    private(set) var received: [UNNotificationResponse] = []
    private(set) var settingsRequests: [UNNotification?] = []

    init(presentationOptions: UNNotificationPresentationOptions = [.sound]) {
        self.presentationOptions = presentationOptions
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        presented.append(notification)
        completionHandler(presentationOptions)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        received.append(response)
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, openSettingsFor notification: UNNotification?) {
        settingsRequests.append(notification)
    }
}

/// Another SDK's delegate that implements taps only.
final class TapOnlyNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    private(set) var received: [UNNotificationResponse] = []

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        received.append(response)
        completionHandler()
    }
}

/// Stands in for the placeholder delegate OneSignal 5 sets when the app has none, under its Objective-C name.
@objc(OSUNUserNotificationCenterDelegate)
final class OneSignalPlaceholderDelegate: NSObject, UNUserNotificationCenterDelegate {
    private(set) var presented: [UNNotification] = []
    private(set) var received: [UNNotificationResponse] = []

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        presented.append(notification)
        completionHandler([])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        received.append(response)
        completionHandler()
    }
}
