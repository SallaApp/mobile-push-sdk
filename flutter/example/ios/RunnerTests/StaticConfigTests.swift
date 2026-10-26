import XCTest

@testable import mobile_push

final class StaticConfigTests: XCTestCase {
  private let recorder = ConsoleRecorder()

  private func read(_ infoDictionary: [String: Any]) -> StaticConfig {
    StaticConfig(infoDictionary: infoDictionary, console: recorder.console)
  }

  func testReadsEveryKeyFromPlistValues() {
    let config = read([
      "SallaPushAppId": "st_42_ios",
      "SallaPushOpenLaunchURLs": true,
      "SallaPushRequiresUserConsent": true,
      "SallaPushClearTagsOnLogout": false,
      "SallaPushAppVersion": "5.0.38",
      "SallaPushAutoClearBadge": false,
      "SallaPushAutoUpdateBadge": false,
      "SallaPushRegisterForRemoteNotificationsOnInit": false,
      "SallaPushAPNsEnvironment": "sandbox",
    ])

    XCTAssertEqual(
      config,
      StaticConfig(
        appId: "st_42_ios",
        openLaunchURLs: true,
        requiresUserConsent: true,
        clearTagsOnLogout: false,
        appVersion: "5.0.38",
        autoClearBadge: false,
        autoUpdateBadge: false,
        registerForRemoteNotificationsOnInit: false,
        apnsEnvironment: .sandbox))
    XCTAssertEqual(recorder.lines, [])
  }

  func testReadsBooleansAsBuildSettingsWriteThem() {
    let config = read([
      "SallaPushOpenLaunchURLs": "YES",
      "SallaPushRequiresUserConsent": "no",
      "SallaPushClearTagsOnLogout": "1",
      "SallaPushAutoClearBadge": "False",
      "SallaPushAutoUpdateBadge": "NO",
      "SallaPushRegisterForRemoteNotificationsOnInit": " true ",
    ])

    XCTAssertEqual(config.openLaunchURLs, true)
    XCTAssertEqual(config.requiresUserConsent, false)
    XCTAssertEqual(config.clearTagsOnLogout, true)
    XCTAssertEqual(config.autoClearBadge, false)
    XCTAssertEqual(config.autoUpdateBadge, false)
    XCTAssertEqual(config.registerForRemoteNotificationsOnInit, true)
    XCTAssertEqual(recorder.lines, [])
  }

  func testReadsEachBadgeKeyIntoItsOwnSetting() {
    XCTAssertEqual(read(["SallaPushAutoClearBadge": false]), StaticConfig(autoClearBadge: false))
    XCTAssertEqual(read(["SallaPushAutoUpdateBadge": "NO"]), StaticConfig(autoUpdateBadge: false))
    XCTAssertEqual(recorder.lines, [])
  }

  func testTreatsEmptyValuesOfUnsetBuildSettingsAsAbsent() {
    let config = read([
      "SallaPushAppId": "",
      "SallaPushAppVersion": "  ",
      "SallaPushOpenLaunchURLs": "",
      "SallaPushAPNsEnvironment": "",
    ])

    XCTAssertEqual(config, StaticConfig())
    XCTAssertEqual(recorder.lines, [])
  }

  func testTrimsStrings() {
    XCTAssertEqual(read(["SallaPushAppId": " st_42_ios\n"]).appId, "st_42_ios")
  }

  func testTreatsAbsentKeysAsAbsent() {
    XCTAssertEqual(read([:]), StaticConfig())
    XCTAssertEqual(recorder.lines, [])
  }

  func testIgnoresTextThatIsNotABooleanWithOneConsoleLine() {
    XCTAssertNil(read(["SallaPushOpenLaunchURLs": "maybe"]).openLaunchURLs)
    XCTAssertEqual(
      recorder.lines,
      [
        .init(
          level: .error,
          message: "Info.plist key SallaPushOpenLaunchURLs is \"maybe\", not YES, NO, true, false, 1 or 0. It is ignored.")
      ])
  }

  func testIgnoresANumberForABooleanWithOneConsoleLine() {
    XCTAssertNil(read(["SallaPushAutoClearBadge": 1]).autoClearBadge)
    XCTAssertEqual(
      recorder.lines, [.init(level: .error, message: "Info.plist key SallaPushAutoClearBadge must be a Boolean. It is ignored.")])
  }

  func testIgnoresABadgeSettingThatIsNotABooleanWithOneConsoleLine() {
    XCTAssertNil(read(["SallaPushAutoUpdateBadge": "sometimes"]).autoUpdateBadge)
    XCTAssertEqual(
      recorder.lines,
      [
        .init(
          level: .error,
          message: "Info.plist key SallaPushAutoUpdateBadge is \"sometimes\", not YES, NO, true, false, 1 or 0. It is ignored.")
      ])
  }

  func testIgnoresANonStringForAStringWithOneConsoleLine() {
    XCTAssertNil(read(["SallaPushAppId": 42]).appId)
    XCTAssertEqual(recorder.lines, [.init(level: .error, message: "Info.plist key SallaPushAppId must be a string. It is ignored.")])
  }

  func testReadsEveryApnsEnvironmentInAnyCase() {
    XCTAssertEqual(read(["SallaPushAPNsEnvironment": "automatic"]).apnsEnvironment, .automatic)
    XCTAssertEqual(read(["SallaPushAPNsEnvironment": "SANDBOX"]).apnsEnvironment, .sandbox)
    XCTAssertEqual(read(["SallaPushAPNsEnvironment": "Production"]).apnsEnvironment, .production)
    XCTAssertEqual(recorder.lines, [])
  }

  func testIgnoresAnUnknownApnsEnvironmentWithOneConsoleLine() {
    XCTAssertNil(read(["SallaPushAPNsEnvironment": "staging"]).apnsEnvironment)
    XCTAssertEqual(
      recorder.lines,
      [
        .init(
          level: .error,
          message: "Info.plist key SallaPushAPNsEnvironment is \"staging\", not automatic, sandbox or production. It is ignored.")
      ])
  }

  func testBuildsTheConfigurationFromTheOptionsSet() {
    let configuration = StaticConfig(
      appId: "st_42_ios",
      openLaunchURLs: true,
      requiresUserConsent: true,
      clearTagsOnLogout: false,
      appVersion: "5.0.38",
      autoClearBadge: false,
      autoUpdateBadge: false,
      registerForRemoteNotificationsOnInit: false,
      apnsEnvironment: .production
    ).configuration()

    XCTAssertTrue(configuration.openLaunchURLs)
    XCTAssertTrue(configuration.requiresUserConsent)
    XCTAssertFalse(configuration.clearTagsOnLogout)
    XCTAssertEqual(configuration.appVersion, "5.0.38")
    XCTAssertFalse(configuration.autoClearBadge)
    XCTAssertFalse(configuration.autoUpdateBadge)
    XCTAssertFalse(configuration.registerForRemoteNotificationsOnInit)
    XCTAssertEqual(configuration.apnsEnvironment, .production)
  }

  func testSetsEachBadgeSettingAloneOnItsOwnOption() {
    // SallaPush's defaults are true for both: each setting turned off alone leaves the other on.
    let clear = StaticConfig(appId: "st_42_ios", autoClearBadge: false).configuration()
    let update = StaticConfig(appId: "st_42_ios", autoUpdateBadge: false).configuration()

    XCTAssertFalse(clear.autoClearBadge)
    XCTAssertTrue(clear.autoUpdateBadge)
    XCTAssertTrue(update.autoClearBadge)
    XCTAssertFalse(update.autoUpdateBadge)
  }

  func testKeepsSallaPushDefaultsForOptionsNotSet() {
    let configuration = StaticConfig(appId: "st_42_ios").configuration()

    XCTAssertFalse(configuration.openLaunchURLs)
    XCTAssertFalse(configuration.requiresUserConsent)
    XCTAssertTrue(configuration.clearTagsOnLogout)
    XCTAssertNil(configuration.appVersion)
    XCTAssertTrue(configuration.autoClearBadge)
    XCTAssertTrue(configuration.autoUpdateBadge)
    XCTAssertTrue(configuration.registerForRemoteNotificationsOnInit)
    XCTAssertEqual(configuration.apnsEnvironment, .automatic)
    // SallaPush then reads its own SallaPushAppGroup key.
    XCTAssertNil(configuration.appGroupIdentifier)
  }
}
