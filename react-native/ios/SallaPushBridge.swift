import Foundation
import SallaPush
import UserNotifications

/// The TurboModule's logic. RNSallaPush.mm converts the codegen types and calls it on the main thread; apps don't use
/// it.
@objc(SallaPushBridge)
public final class SallaPushBridge: NSObject {
    private let native: NativeSallaPush
    private let console: ConsoleOutput
    private let once: OncePerProcess
    private let earlyInit: () -> StaticConfig?
    private let displays: DisplayStore
    private let events: EventRegistry

    /// The live bridge, which RNSallaPush.mm creates when JavaScript first uses the module; it emits events through
    /// `emitter`, held weakly. When the app didn't call `SallaPushRN.start()`, it starts SallaPush now and says so.
    @objc public convenience init(emitter: SallaPushEventEmitter) {
        self.init(native: LiveNativeSallaPush(), console: Console(), once: .shared, emitter: emitter) {
            SallaPushRN.shared.earlyInit
        }
        SallaPushRN.startLate()
    }

    init(native: NativeSallaPush, console: ConsoleOutput, once: OncePerProcess, emitter: SallaPushEventEmitter,
         earlyInit: @escaping () -> StaticConfig?) {
        self.native = native
        self.console = console
        self.once = once
        self.earlyInit = earlyInit
        displays = DisplayStore(native: native, console: console)
        events = EventRegistry(native: native, displays: displays, emitter: emitter)
        super.init()
    }

    // MARK: - Initialization and consent

    /// Initializes SallaPush with the `ConfigSpec` fields that JavaScript set, keyed by name.
    @objc public func initialize(appId: String, options: [String: Any]) {
        let options = InitOptions(options)
        if let earlyInit = earlyInit(), earlyInit.appId == appId {
            reportIgnoredOptions(options.startOptions)
        }
        native.initialize(appId, configuration: options.configuration())
    }

    @objc public var isInitialized: Bool { native.isInitialized }

    @objc public var appId: String? { native.appId }

    @objc public var sdkVersion: String { native.sdkVersion }

    @objc public func setConsentRequired(_ required: Bool) {
        if required, let earlyInit = earlyInit(), earlyInit.requiresUserConsent != true {
            let key = StaticConfig.Key.requiresUserConsent
            console.error("setConsentRequired(true) came after SallaPush started from SallaPushAppId without \(key), "
                + "so the device may already have registered and sent data. Set \(key) to YES in the Info.plist to "
                + "require consent from the start.")
        }
        native.setConsentRequired(required)
    }

    @objc public func setConsentGiven(_ given: Bool) {
        native.setConsentGiven(given)
    }

    // MARK: - Identity

    @objc public func login(externalId: String, identityToken: String) {
        native.login(externalId: externalId, identityToken: identityToken)
    }

    @objc public func logout() {
        native.logout()
    }

    // MARK: - User

    @objc public var externalId: String? { native.externalId }

    @objc public var isLoggedIn: Bool { native.isLoggedIn }

    @objc public func addTag(key: String, value: String) {
        native.addTag(key: key, value: value)
    }

    /// The tags from JavaScript, entries unchecked: native skips and logs the ones that aren't strings.
    @objc public func addTags(_ tags: [AnyHashable: Any]) {
        native.addTags(tags)
    }

    @objc public func removeTag(_ key: String) {
        native.removeTag(key)
    }

    /// The keys from JavaScript, unchecked: native skips and logs the ones that aren't strings.
    @objc public func removeTags(_ keys: [Any]) {
        native.removeTags(keys)
    }

    @objc public var tags: [String: String] { native.tags }

    @objc public func setLanguage(_ language: String?) {
        native.setLanguage(language)
    }

    // MARK: - Push subscription

    @objc public var pushSubscriptionId: String? { native.pushSubscriptionId }

    @objc public var pushSubscriptionToken: String? { native.pushSubscriptionToken }

    @objc public var pushSubscriptionOptedIn: Bool { native.pushSubscriptionOptedIn }

    @objc public func optIn() {
        native.optIn()
    }

    @objc public func optOut() {
        native.optOut()
    }

    // MARK: - Notifications

    @objc public var permission: Bool { native.permission }

    @objc public var canRequestPermission: Bool { native.canRequestPermission }

    @objc public var permissionStatus: String { native.permissionStatus.name }

    @objc public func requestPermission(fallbackToSettings: Bool, completion: @escaping (Bool) -> Void) {
        native.requestPermission(fallbackToSettings: fallbackToSettings, completion: completion)
    }

    @objc public func registerForProvisionalAuthorization(completion: @escaping (Bool) -> Void) {
        native.registerForProvisionalAuthorization(completion: completion)
    }

    @objc public func refreshPermission() {
        native.refreshPermission()
    }

    @objc public func registerForRemoteNotifications() {
        native.registerForRemoteNotifications()
    }

    /// Forwards the APNs token another SDK holds, given as hexadecimal text, as native's token data.
    @objc public func forwardApnsToken(_ apnsToken: String) {
        guard let deviceToken = Data(hexadecimal: apnsToken) else {
            console.error("Notifications.forwardApnsToken ignored: the APNs token must be hexadecimal text of even "
                + "length, as React Native Firebase's getAPNSToken(getMessaging()) returns it.")
            return
        }
        native.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    @objc public func clearAll() {
        native.clearAll()
    }

    @objc public func removeNotification() {
        once.info("Notifications.removeNotification is Android only and does nothing on iOS.", to: console)
    }

    /// Whether a payload from JavaScript is SallaPush's; its null values are dropped first.
    @objc public func isSallaPushNotification(_ payload: [String: Any]) -> Bool {
        native.isSallaPushNotification(payload.filter { !($0.value is NSNull) })
    }

    /// Shows a foreground notification held for JavaScript: it wasn't prevented there, or the app calls display().
    @objc public func displayNotification(_ handle: String) {
        displays.display(handle)
    }

    @objc public func trackOpened() -> Bool {
        once.info("Notifications.trackOpened is Android only and resolves false on iOS.", to: console)
        return false
    }

    // MARK: - Debug and migration

    /// The console log level by its JavaScript name; a name that isn't a level is ignored.
    @objc public var logLevel: String {
        get { native.logLevel.name }
        set {
            guard let level = SallaPushLogLevel(name: newValue) else { return }
            native.logLevel = level
        }
    }

    /// The level of JavaScript's log handler; a name that isn't a level is ignored.
    @objc public func setLogHandlerLevel(_ level: String) {
        guard let level = SallaPushLogLevel(name: level) else { return }
        events.setLogLevel(level)
    }

    @objc public func setDisplayCompatPayloads() {
        once.info("Migration.setDisplayCompatPayloads is Android only and does nothing on iOS.", to: console)
    }

    // MARK: - Events

    /// Registers the native listener of an event kind once JavaScript listens to it; an unknown kind is ignored.
    @objc public func startEvents(_ kind: String) {
        guard let kind = EventRegistry.Kind(rawValue: kind) else { return }
        events.start(kind)
    }

    @objc public func stopEvents(_ kind: String) {
        guard let kind = EventRegistry.Kind(rawValue: kind) else { return }
        events.stop(kind)
    }

    @objc public func addPushSubscriptionListener(_ listenerId: Int) {
        events.addSubscriptionListener(listenerId)
    }

    @objc public func removePushSubscriptionListener(_ listenerId: Int) {
        events.removeSubscriptionListener(listenerId)
    }

    /// Removes every native registration and forgets the held notifications: React Native calls it when the JavaScript
    /// runtime goes away.
    @objc public func invalidate() {
        events.stopAll()
        displays.clear()
    }

    // MARK: - Console

    /// A second initialize with the static app id changes nothing natively, its options included.
    private func reportIgnoredOptions(_ options: [(option: String, key: String)]) {
        guard !options.isEmpty else { return }
        let names = options.map(\.option).joined(separator: ", ")
        let keys = options.map(\.key).joined(separator: ", ")
        console.error("initialize ignored \(names): SallaPush already started with this app id from SallaPushAppId, "
            + "so the call changes nothing. Set them with the Info.plist keys \(keys) instead.")
    }
}

extension SallaPushLogLevel {
    /// The level named as JavaScript names it.
    init?(name: String) {
        switch name {
        case "off": self = .off
        case "error": self = .error
        case "warn": self = .warn
        case "info": self = .info
        case "debug": self = .debug
        case "verbose": self = .verbose
        default: return nil
        }
    }

    /// The level's JavaScript name.
    var name: String {
        switch self {
        case .off: return "off"
        case .error: return "error"
        case .warn: return "warn"
        case .info: return "info"
        case .debug: return "debug"
        case .verbose: return "verbose"
        }
    }
}

extension SallaPushAPNsEnvironment {
    /// The environment named as JavaScript and the Info.plist name it.
    init?(name: String) {
        switch name {
        case "automatic": self = .automatic
        case "sandbox": self = .sandbox
        case "production": self = .production
        default: return nil
        }
    }
}

extension UNAuthorizationStatus {
    /// The status as JavaScript names it; a status newer than this SDK reads as notDetermined.
    var name: String {
        switch self {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .provisional: return "provisional"
        case .ephemeral: return "ephemeral"
        @unknown default: return "notDetermined"
        }
    }
}

extension Data {
    /// The bytes of hexadecimal text of even length, in either case; nil for any other text.
    init?(hexadecimal text: String) {
        let digits = Array(text.utf8)
        guard !digits.isEmpty, digits.count.isMultiple(of: 2) else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(digits.count / 2)
        for index in stride(from: 0, to: digits.count, by: 2) {
            guard let high = Self.hexadecimalValue(digits[index]),
                  let low = Self.hexadecimalValue(digits[index + 1]) else { return nil }
            bytes.append(high << 4 | low)
        }
        self.init(bytes)
    }

    private static func hexadecimalValue(_ digit: UInt8) -> UInt8? {
        switch digit {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): return digit - UInt8(ascii: "0")
        case UInt8(ascii: "a")...UInt8(ascii: "f"): return digit - UInt8(ascii: "a") + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"): return digit - UInt8(ascii: "A") + 10
        default: return nil
        }
    }
}
