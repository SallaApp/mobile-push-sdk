import Foundation
import SallaPush
import UserNotifications

/// Starts SallaPush natively at launch, so the tap that launched the app and pushes in processes without JavaScript
/// behave as in a native app. Call `SallaPushRN.start()` as the first statement of
/// `application(_:didFinishLaunchingWithOptions:)`.
@objc(SallaPushRN)
public final class SallaPushRN: NSObject {
    static let shared = SallaPushRN(
        native: LiveNativeSallaPush(),
        info: Bundle.main.infoDictionary ?? [:],
        console: Console(),
        notificationCenter: { UNUserNotificationCenter.current() },
        delegate: .shared
    )

    private let native: NativeSallaPush
    private let info: [String: Any]
    private let console: ConsoleOutput
    private let notificationCenter: () -> UserNotificationCenter
    private let delegate: SallaPushRNNotificationCenterDelegate
    private var started = false

    /// The static configuration SallaPush was started with in this process; nil when SallaPushAppId is not set.
    private(set) var earlyInit: StaticConfig?

    init(
        native: NativeSallaPush,
        info: [String: Any],
        console: ConsoleOutput,
        notificationCenter: @escaping () -> UserNotificationCenter,
        delegate: SallaPushRNNotificationCenterDelegate
    ) {
        self.native = native
        self.info = info
        self.console = console
        self.notificationCenter = notificationCenter
        self.delegate = delegate
    }

    /// Initializes SallaPush from the SallaPush… Info.plist keys when SallaPushAppId is set, then makes SallaPush's
    /// delegate the notification center's delegate, chained to the one set before. It runs once per process, on the main
    /// thread; later calls do nothing.
    @objc public static func start() {
        onMain { shared.startOnce() }
    }

    /// The TurboModule's fallback for apps that don't call `start()`: SallaPush starts when JavaScript first uses it,
    /// too late for the tap that launched the app, and an error line says so.
    static func startLate() {
        onMain { shared.startLateOnce() }
    }

    private static func onMain(_ work: @escaping () -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async(execute: work)
            return
        }
        work()
    }

    func startLateOnce() {
        guard !started else { return }
        console.error("SallaPushRN.start() was not called in application(_:didFinishLaunchingWithOptions:), so "
            + "SallaPush started only when JavaScript first used it, and the tap that launched the app can be missed. "
            + "Call SallaPushRN.start() as the first statement there.")
        startOnce()
    }

    func startOnce() {
        guard !started else { return }
        started = true
        let config = StaticConfig(info: info, console: console)
        if let appId = config.appId {
            native.initialize(appId, configuration: config.configuration())
            earlyInit = config
        }
        let center = notificationCenter()
        guard center.delegate !== delegate else { return }
        delegate.previous = center.delegate
        center.delegate = delegate
    }
}
