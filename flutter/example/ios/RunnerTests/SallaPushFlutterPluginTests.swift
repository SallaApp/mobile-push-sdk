import Flutter
import UIKit
import UserNotifications
import XCTest

@testable import mobile_push

final class SallaPushFlutterPluginTests: XCTestCase {
  private let native = FakeNativeSallaPush()
  private let recorder = ConsoleRecorder()
  private var earlyInit: StaticConfig?

  private lazy var plugin = SallaPushFlutterPlugin(
    native: native, earlyInit: { [unowned self] in self.earlyInit }, console: recorder.console,
    platformOnly: PlatformOnlyCalls())

  private static let hostApi = "dev.flutter.pigeon.mobile_push.SallaPushHostApi"
  private static let hostMethods = [
    "initialize", "isInitialized", "appId", "sdkVersion", "setConsentRequired", "setConsentGiven", "login", "logout",
    "externalId", "isLoggedIn", "addTag", "addTags", "removeTag", "removeTags", "getTags", "setLanguage",
    "pushSubscriptionId", "pushSubscriptionToken", "pushSubscriptionOptedIn", "optIn", "optOut",
    "addPushSubscriptionListener", "removePushSubscriptionListener", "permission", "canRequestPermission",
    "permissionStatus", "requestPermission", "registerForProvisionalAuthorization", "refreshPermission",
    "registerForRemoteNotifications", "forwardApnsToken", "clearAll", "removeNotification", "isSallaPushNotification",
    "trackOpened", "displayNotification", "setDisplayCompatPayloads", "logLevel", "setLogLevel",
    "setLogHandlerLevel",
  ]
  private static let eventStreams = [
    "clickEvents", "willDisplayEvents", "permissionChanges", "userChanges", "loginFailures", "pushSubscriptionChanges",
    "logEntries",
  ]

  func testRegisteringSetsUpTheHostApiAndTheEventStreamsAndPublishesThePlugin() {
    let registrar = FakeRegistrar()

    SallaPushFlutterPlugin.register(with: registrar)

    XCTAssertEqual(
      Set(registrar.binaryMessenger.handlers.keys),
      Set(Self.hostMethods.map { "\(Self.hostApi).\($0)" } + Self.eventStreams.map(FakeBinaryMessenger.eventChannel)))
    XCTAssertEqual(
      registrar.binaryMessenger.send("\(Self.hostApi).sdkVersion", arguments: nil)?.first as? String,
      SallaPush.sdkVersion)
    XCTAssertEqual(registrar.published.count, 1)
    XCTAssertTrue(registrar.published.first is SallaPushFlutterPlugin)
    // SallaPushAppLifeCycle already gets the app delegate's calls; a second registration would deliver them twice.
    XCTAssertTrue(registrar.applicationDelegates.isEmpty)
  }

  func testDetachingFromTheEngineRemovesTheHostApiAndTheEventStreams() throws {
    let registrar = FakeRegistrar()
    SallaPushFlutterPlugin.register(with: registrar)
    let plugin = try XCTUnwrap(registrar.published.first as? SallaPushFlutterPlugin)

    plugin.detachFromEngine(for: registrar)

    XCTAssertTrue(registrar.binaryMessenger.handlers.isEmpty)
  }

  func testGettersReadSallaPushAtEveryCall() {
    native.isInitialized = true
    native.appId = "st_42_ios"
    native.sdkVersion = "1.0.2"

    XCTAssertTrue(plugin.isInitialized())
    XCTAssertEqual(plugin.appId(), "st_42_ios")
    XCTAssertEqual(plugin.sdkVersion(), "1.0.2")

    native.isInitialized = false
    native.appId = nil

    XCTAssertFalse(plugin.isInitialized())
    XCTAssertNil(plugin.appId())
  }

  func testConsentLoginAndLogoutReachSallaPushUnchanged() {
    plugin.setConsentRequired(required: false)
    plugin.setConsentGiven(given: true)
    plugin.setConsentGiven(given: false)
    plugin.login(externalId: " 42 ", identityToken: " token ")
    plugin.logout()

    XCTAssertEqual(
      native.calls,
      [
        .setConsentRequired(false), .setConsentGiven(true), .setConsentGiven(false),
        .login(externalId: " 42 ", identityToken: " token "), .logout,
      ])
    XCTAssertEqual(recorder.lines, [])
  }

  func testUserGettersReadSallaPushAtEveryCall() {
    native.externalId = "42"
    native.isLoggedIn = true
    native.savedTags = ["tier": "gold"]

    XCTAssertEqual(plugin.externalId(), "42")
    XCTAssertTrue(plugin.isLoggedIn())
    XCTAssertEqual(plugin.getTags(), ["tier": "gold"])

    native.externalId = nil
    native.isLoggedIn = false
    native.savedTags = [:]

    XCTAssertNil(plugin.externalId())
    XCTAssertFalse(plugin.isLoggedIn())
    XCTAssertEqual(plugin.getTags(), [:])
  }

  func testTagsAndLanguageReachSallaPushUnchanged() {
    plugin.addTag(key: " Tier ", value: "gold")
    plugin.addTags(tags: ["tier": "gold", " City ": ""])
    plugin.removeTag(key: "tier")
    plugin.removeTags(keys: ["tier", " City "])
    plugin.setLanguage(language: "ar")
    plugin.setLanguage(language: nil)

    XCTAssertEqual(
      native.calls,
      [
        .addTag(key: " Tier ", value: "gold"), .addTags(["tier": "gold", " City ": ""]), .removeTag("tier"),
        .removeTags(["tier", " City "]), .setLanguage("ar"), .setLanguage(nil),
      ])
  }

  func testPushSubscriptionGettersReadSallaPushAtEveryCall() {
    native.pushSubscriptionId = "7d1b2c4e-5f60-4a8b-9c0d-1e2f3a4b5c6d"
    native.pushSubscriptionToken = "ab12cd34"
    native.pushSubscriptionOptedIn = true

    XCTAssertEqual(plugin.pushSubscriptionId(), "7d1b2c4e-5f60-4a8b-9c0d-1e2f3a4b5c6d")
    XCTAssertEqual(plugin.pushSubscriptionToken(), "ab12cd34")
    XCTAssertTrue(plugin.pushSubscriptionOptedIn())

    native.pushSubscriptionId = nil
    native.pushSubscriptionToken = nil
    native.pushSubscriptionOptedIn = false

    XCTAssertNil(plugin.pushSubscriptionId())
    XCTAssertNil(plugin.pushSubscriptionToken())
    XCTAssertFalse(plugin.pushSubscriptionOptedIn())
  }

  func testOptInAndOptOutReachSallaPush() {
    plugin.optOut()
    plugin.optIn()

    XCTAssertEqual(native.calls, [.optOut, .optIn])
  }

  func testPermissionGettersReadSallaPushAtEveryCall() {
    native.permission = true
    native.canRequestPermission = false

    XCTAssertTrue(plugin.permission())
    XCTAssertFalse(plugin.canRequestPermission())

    native.permission = false
    native.canRequestPermission = true

    XCTAssertFalse(plugin.permission())
    XCTAssertTrue(plugin.canRequestPermission())
  }

  func testPermissionStatusMapsEveryStatusByCase() {
    let statuses: [(UNAuthorizationStatus, IosPermissionStatusMessage)] = [
      (.notDetermined, .notDetermined), (.denied, .denied), (.authorized, .authorized), (.provisional, .provisional),
      (.ephemeral, .ephemeral),
    ]

    for (status, message) in statuses {
      native.permissionStatus = status
      XCTAssertEqual(plugin.permissionStatus(), message)
    }
  }

  func testPermissionStatusReadsAStatusOfALaterIosAsNotDetermined() throws {
    native.permissionStatus = try XCTUnwrap(UNAuthorizationStatus(rawValue: 99))

    XCTAssertEqual(plugin.permissionStatus(), .notDetermined)
  }

  func testPermissionRequestsCompleteWhenSallaPushAnswers() {
    var answers: [Bool?] = []

    plugin.requestPermission(fallbackToSettings: true) { answers.append(try? $0.get()) }
    plugin.registerForProvisionalAuthorization { answers.append(try? $0.get()) }

    XCTAssertEqual(native.calls, [.requestPermission(fallbackToSettings: true), .registerForProvisionalAuthorization])
    XCTAssertEqual(answers, [])

    native.answerPermissionRequests(true)

    XCTAssertEqual(answers, [true, true])
  }

  func testRefreshRegisterAndClearReachSallaPush() {
    plugin.refreshPermission()
    plugin.registerForRemoteNotifications()
    plugin.clearAll()

    XCTAssertEqual(native.calls, [.refreshPermission, .registerForRemoteNotifications, .clearAll])
  }

  func testForwardApnsTokenDecodesHexadecimalTextInEitherCase() {
    plugin.forwardApnsToken(apnsToken: "0a1b2c3d")
    plugin.forwardApnsToken(apnsToken: "0A1B2C3D")
    plugin.forwardApnsToken(apnsToken: "0a1B2c3D")

    XCTAssertEqual(native.deviceTokens, Array(repeating: Data([0x0A, 0x1B, 0x2C, 0x3D]), count: 3))
    XCTAssertEqual(recorder.lines, [])
  }

  func testForwardApnsTokenIgnoresOtherTextWithAConsoleLine() {
    for text in ["abc", "zz", "+f", "0x0a", "0a 1b2", "\u{0661}\u{0662}"] {
      plugin.forwardApnsToken(apnsToken: text)
    }

    XCTAssertEqual(native.deviceTokens, [])
    XCTAssertEqual(
      recorder.lines,
      Array(
        repeating: .init(
          level: .error,
          message: "SallaPush.notifications.forwardApnsToken ignored a token that is not hexadecimal text of even "
            + "length."),
        count: 6))
  }

  func testIsSallaPushNotificationDropsNullsAndAnswersLikeSallaPush() throws {
    var payload = Dictionary(
      uniqueKeysWithValues: try TestNotifications.payload(named: "native").map { ("\($0.key)", Optional($0.value)) })
    payload["absent"] = .some(nil)
    payload["null"] = NSNull()

    XCTAssertTrue(plugin.isSallaPushNotification(payload: payload))
    let checked = try XCTUnwrap(native.checkedPayloads.last)
    XCTAssertNil(checked["absent"])
    XCTAssertNil(checked["null"])
    XCTAssertEqual(checked.count, payload.count - 2)
    XCTAssertFalse(plugin.isSallaPushNotification(payload: ["aps": ["alert": "Another SDK"]]))
  }

  func testAndroidOnlyCallsDoNothingAndSaySoOncePerProcess() {
    plugin.removeNotification(androidNotificationId: 7)
    plugin.removeNotification(androidNotificationId: 8)

    XCTAssertFalse(plugin.trackOpened(additionalData: ["push_ref": "msg_1"]))
    XCTAssertFalse(plugin.trackOpened(additionalData: nil))
    XCTAssertEqual(native.calls, [])
    XCTAssertEqual(
      recorder.lines,
      [
        .init(
          level: .info,
          message: "SallaPush.notifications.removeNotification works on Android only; on iOS it does nothing."),
        .init(level: .info, message: "SallaPush.notifications.trackOpened works on Android only; on iOS it returns false."),
      ])
  }

  func testAndroidOnlyCallsAreReportedOnceForEveryEngine() {
    let platformOnly = PlatformOnlyCalls()
    let engines = (1...2).map { _ in
      SallaPushFlutterPlugin(
        native: native, earlyInit: { nil }, console: recorder.console, platformOnly: platformOnly)
    }

    engines.forEach { $0.removeNotification(androidNotificationId: 7) }

    XCTAssertEqual(recorder.lines.count, 1)
  }

  func testLogLevelMapsEveryLevelByCaseBothWays() {
    let levels: [(SallaPushLogLevel, LogLevelMessage)] = [
      (.off, .off), (.error, .error), (.warn, .warn), (.info, .info), (.debug, .debug), (.verbose, .verbose),
    ]

    for (level, message) in levels {
      native.logLevel = level
      XCTAssertEqual(plugin.logLevel(), message)
      plugin.setLogLevel(level: message)
    }

    XCTAssertEqual(native.calls, levels.map { level, _ in .setLogLevel(level) })
  }

  func testDisplayingCompatPayloadsIsAndroidOnly() {
    plugin.setDisplayCompatPayloads(display: false)
    plugin.setDisplayCompatPayloads(display: true)

    XCTAssertEqual(native.calls, [])
    XCTAssertEqual(
      recorder.lines,
      [
        .init(
          level: .info,
          message: "SallaPush.migration.setDisplayCompatPayloads works on Android only; on iOS it does nothing.")
      ])
  }

  func testInitializeWithTheStaticAppIdNamesTheOptionsSallaPushIgnores() {
    earlyInit = StaticConfig(appId: "st_42_ios")

    plugin.initialize(
      appId: "st_42_ios",
      config: ConfigMessage(
        logLevel: .debug,
        appVersion: "5.0.38",
        clearTagsOnLogout: false,
        requiresUserConsent: true,
        openLaunchUrls: true,
        autoClearBadge: false,
        autoUpdateBadge: false,
        iosAppGroupIdentifier: "group.sa.salla.example",
        iosApnsEnvironment: .sandbox,
        iosRegisterForRemoteNotificationsOnInit: false))

    XCTAssertEqual(
      recorder.lines,
      [
        .init(
          level: .error,
          message: "SallaPush already started at launch with this app id, so initialize ignored its options. Set each "
            + "with its Info.plist key instead: logLevel (SallaPushLogLevel), appVersion (SallaPushAppVersion), "
            + "clearTagsOnLogout (SallaPushClearTagsOnLogout), requiresUserConsent (SallaPushRequiresUserConsent), "
            + "openLaunchUrls (SallaPushOpenLaunchURLs), autoClearBadge (SallaPushAutoClearBadge), "
            + "autoUpdateBadge (SallaPushAutoUpdateBadge), ios.appGroupIdentifier (SallaPushAppGroup), "
            + "ios.apnsEnvironment (SallaPushAPNsEnvironment), "
            + "ios.registerForRemoteNotificationsOnInit (SallaPushRegisterForRemoteNotificationsOnInit).")
      ])
    XCTAssertEqual(native.initializations.count, 1)
  }

  func testInitializeWithTheStaticAppIdNamesOnlyTheOptionsSet() {
    earlyInit = StaticConfig(appId: "st_42_ios", openLaunchURLs: true)

    plugin.initialize(appId: "st_42_ios", config: ConfigMessage(openLaunchUrls: true))

    XCTAssertEqual(
      recorder.lines,
      [
        .init(
          level: .error,
          message: "SallaPush already started at launch with this app id, so initialize ignored its options. Set each "
            + "with its Info.plist key instead: openLaunchUrls (SallaPushOpenLaunchURLs).")
      ])
  }

  func testInitializeWithTheStaticAppIdAndNoOptionsPrintsNothing() {
    earlyInit = StaticConfig(appId: "st_42_ios")

    plugin.initialize(appId: "st_42_ios", config: ConfigMessage())

    XCTAssertEqual(recorder.lines, [])
    XCTAssertEqual(native.initializations.count, 1)
  }

  func testInitializeWithAnotherAppIdPrintsNothing() {
    earlyInit = StaticConfig(appId: "st_42_ios")

    plugin.initialize(appId: "st_43_ios", config: ConfigMessage(openLaunchUrls: true))

    XCTAssertEqual(recorder.lines, [])
    XCTAssertEqual(native.initializations.count, 1)
  }

  func testInitializeWithoutEarlyInitPrintsNothing() {
    plugin.initialize(appId: "st_42_ios", config: ConfigMessage(openLaunchUrls: true))

    XCTAssertEqual(recorder.lines, [])
  }

  func testRequiringConsentAfterEarlyInitWithoutConsentPrintsAnError() {
    earlyInit = StaticConfig(appId: "st_42_ios")

    plugin.setConsentRequired(required: true)

    XCTAssertEqual(
      recorder.lines,
      [
        .init(
          level: .error,
          message: "setConsentRequired(true) came after SallaPush started at launch without requiring consent, so "
            + "this device may already have registered and sent data. To require consent from the start, set the "
            + "Info.plist key SallaPushRequiresUserConsent to YES.")
      ])
    XCTAssertEqual(native.calls, [.setConsentRequired(true)])
  }

  func testRequiringConsentAfterEarlyInitThatRequiredItPrintsNothing() {
    earlyInit = StaticConfig(appId: "st_42_ios", requiresUserConsent: true)

    plugin.setConsentRequired(required: true)

    XCTAssertEqual(recorder.lines, [])
    XCTAssertEqual(native.calls, [.setConsentRequired(true)])
  }

  func testRequiringConsentWithoutEarlyInitPrintsNothing() {
    plugin.setConsentRequired(required: true)

    XCTAssertEqual(recorder.lines, [])
    XCTAssertEqual(native.calls, [.setConsentRequired(true)])
  }
}
