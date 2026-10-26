import Flutter
import UIKit
import XCTest

@testable import mobile_push

/// How `initialize` hands Dart's options to SallaPush, without a start at launch.
final class InitializeTests: XCTestCase {
  private let native = FakeNativeSallaPush()
  private let recorder = ConsoleRecorder()

  private lazy var plugin = SallaPushFlutterPlugin(
    native: native, earlyInit: { nil }, console: recorder.console, platformOnly: PlatformOnlyCalls())

  func testInitializeStartsSallaPushWithTheAppIdAndEveryOption() throws {
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

    XCTAssertEqual(native.initializations.count, 1)
    let initialization = try XCTUnwrap(native.initializations.first)
    XCTAssertEqual(initialization.appId, "st_42_ios")
    let configuration = initialization.configuration
    XCTAssertEqual(configuration.logLevel, .debug)
    XCTAssertEqual(configuration.appVersion, "5.0.38")
    XCTAssertFalse(configuration.clearTagsOnLogout)
    XCTAssertTrue(configuration.requiresUserConsent)
    XCTAssertTrue(configuration.openLaunchURLs)
    XCTAssertEqual(configuration.appGroupIdentifier, "group.sa.salla.example")
    XCTAssertEqual(configuration.apnsEnvironment, .sandbox)
    XCTAssertFalse(configuration.autoClearBadge)
    XCTAssertFalse(configuration.autoUpdateBadge)
    XCTAssertFalse(configuration.registerForRemoteNotificationsOnInit)
    XCTAssertEqual(recorder.lines, [])
  }

  func testInitializeSetsEachBooleanOptionAloneOnItsOwnSetting() {
    // clearTagsOnLogout, requiresUserConsent, openLaunchURLs, autoClearBadge, autoUpdateBadge,
    // registerForRemoteNotificationsOnInit; SallaPush's defaults are true, false, false, true, true, true.
    let options: [(ConfigMessage, [Bool])] = [
      (ConfigMessage(clearTagsOnLogout: false), [false, false, false, true, true, true]),
      (ConfigMessage(requiresUserConsent: true), [true, true, false, true, true, true]),
      (ConfigMessage(openLaunchUrls: true), [true, false, true, true, true, true]),
      (ConfigMessage(autoClearBadge: false), [true, false, false, false, true, true]),
      (ConfigMessage(autoUpdateBadge: false), [true, false, false, true, false, true]),
      (ConfigMessage(iosRegisterForRemoteNotificationsOnInit: false), [true, false, false, true, true, false]),
    ]

    for (message, expected) in options {
      plugin.initialize(appId: "st_42_ios", config: message)
      let settings = native.initializations.last.map { initialization -> [Bool] in
        let configuration = initialization.configuration
        return [
          configuration.clearTagsOnLogout, configuration.requiresUserConsent, configuration.openLaunchURLs,
          configuration.autoClearBadge, configuration.autoUpdateBadge, configuration.registerForRemoteNotificationsOnInit,
        ]
      }
      XCTAssertEqual(settings, expected, "\(message)")
    }
  }

  func testInitializeKeepsSallaPushDefaultsForOptionsNotSet() throws {
    plugin.initialize(appId: "st_42_ios", config: ConfigMessage())

    let configuration = try XCTUnwrap(native.initializations.first?.configuration)
    XCTAssertEqual(configuration.logLevel, .warn)
    XCTAssertNil(configuration.appVersion)
    XCTAssertTrue(configuration.clearTagsOnLogout)
    XCTAssertFalse(configuration.requiresUserConsent)
    XCTAssertFalse(configuration.openLaunchURLs)
    XCTAssertNil(configuration.appGroupIdentifier)
    XCTAssertEqual(configuration.apnsEnvironment, .automatic)
    XCTAssertTrue(configuration.autoClearBadge)
    XCTAssertTrue(configuration.autoUpdateBadge)
    XCTAssertTrue(configuration.registerForRemoteNotificationsOnInit)
  }

  func testInitializeMapsEveryLogLevelAndApnsEnvironmentByCase() {
    let levels: [(LogLevelMessage, SallaPushLogLevel)] = [
      (.off, .off), (.error, .error), (.warn, .warn), (.info, .info), (.debug, .debug), (.verbose, .verbose),
    ]
    let environments: [(ApnsEnvironmentMessage, SallaPushAPNsEnvironment)] = [
      (.automatic, .automatic), (.sandbox, .sandbox), (.production, .production),
    ]

    for (message, level) in levels {
      plugin.initialize(appId: "st_42_ios", config: ConfigMessage(logLevel: message))
      XCTAssertEqual(native.initializations.last?.configuration.logLevel, level)
    }
    for (message, environment) in environments {
      plugin.initialize(appId: "st_42_ios", config: ConfigMessage(iosApnsEnvironment: message))
      XCTAssertEqual(native.initializations.last?.configuration.apnsEnvironment, environment)
    }
  }
}
