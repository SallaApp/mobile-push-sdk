import Foundation
import SallaPush

/// The options of a JavaScript `initialize` call; nil means the option was left out.
struct InitOptions {
    var logLevel: SallaPushLogLevel?
    var appVersion: String?
    var clearTagsOnLogout: Bool?
    var requiresUserConsent: Bool?
    var openLaunchUrls: Bool?
    var autoClearBadge: Bool?
    var autoUpdateBadge: Bool?
    var appGroupIdentifier: String?
    var apnsEnvironment: SallaPushAPNsEnvironment?
    var registerForRemoteNotificationsOnInit: Bool?
}

extension InitOptions {
    init(_ options: [String: Any]) {
        self.init(
            logLevel: (options["logLevel"] as? String).flatMap(SallaPushLogLevel.init(name:)),
            appVersion: options["appVersion"] as? String,
            clearTagsOnLogout: options["clearTagsOnLogout"] as? Bool,
            requiresUserConsent: options["requiresUserConsent"] as? Bool,
            openLaunchUrls: options["openLaunchUrls"] as? Bool,
            autoClearBadge: options["autoClearBadge"] as? Bool,
            autoUpdateBadge: options["autoUpdateBadge"] as? Bool,
            appGroupIdentifier: options["iosAppGroupIdentifier"] as? String,
            apnsEnvironment: (options["iosApnsEnvironment"] as? String).flatMap(SallaPushAPNsEnvironment.init(name:)),
            registerForRemoteNotificationsOnInit: options["iosRegisterForRemoteNotificationsOnInit"] as? Bool
        )
    }

    /// The native configuration with the options that were given, and native's defaults for the others.
    func configuration() -> SallaPushConfiguration {
        let configuration = SallaPushConfiguration()
        if let logLevel { configuration.logLevel = logLevel }
        if let appVersion { configuration.appVersion = appVersion }
        if let clearTagsOnLogout { configuration.clearTagsOnLogout = clearTagsOnLogout }
        if let requiresUserConsent { configuration.requiresUserConsent = requiresUserConsent }
        if let openLaunchUrls { configuration.openLaunchURLs = openLaunchUrls }
        applyBadgeOptions(to: configuration)
        if let appGroupIdentifier { configuration.appGroupIdentifier = appGroupIdentifier }
        if let apnsEnvironment { configuration.apnsEnvironment = apnsEnvironment }
        if let registerForRemoteNotificationsOnInit {
            configuration.registerForRemoteNotificationsOnInit = registerForRemoteNotificationsOnInit
        }
        return configuration
    }

    /// The badge options given.
    private func applyBadgeOptions(to configuration: SallaPushConfiguration) {
        if let autoClearBadge { configuration.autoClearBadge = autoClearBadge }
        if let autoUpdateBadge { configuration.autoUpdateBadge = autoUpdateBadge }
    }

    /// The given options that only the first initialize applies, each with the Info.plist key that sets it at launch.
    var startOptions: [(option: String, key: String)] {
        let options: [(option: String, key: String)?] = [
            logLevel.map { _ in ("logLevel", "SallaPushLogLevel") },
            appVersion.map { _ in ("appVersion", StaticConfig.Key.appVersion) },
            clearTagsOnLogout.map { _ in ("clearTagsOnLogout", StaticConfig.Key.clearTagsOnLogout) },
            requiresUserConsent.map { _ in ("requiresUserConsent", StaticConfig.Key.requiresUserConsent) },
            openLaunchUrls.map { _ in ("openLaunchUrls", StaticConfig.Key.openLaunchURLs) },
            autoClearBadge.map { _ in ("autoClearBadge", StaticConfig.Key.autoClearBadge) },
            autoUpdateBadge.map { _ in ("autoUpdateBadge", StaticConfig.Key.autoUpdateBadge) },
            appGroupIdentifier.map { _ in ("ios.appGroupIdentifier", "SallaPushAppGroup") },
            apnsEnvironment.map { _ in ("ios.apnsEnvironment", StaticConfig.Key.apnsEnvironment) },
            registerForRemoteNotificationsOnInit.map { _ in
                ("ios.registerForRemoteNotificationsOnInit", StaticConfig.Key.registerForRemoteNotificationsOnInit)
            }
        ]
        return options.compactMap { $0 }
    }
}
