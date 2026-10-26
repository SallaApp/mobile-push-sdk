@testable import SallaPushReactNative
import UserNotifications
import XCTest

final class SallaPushRNTests: XCTestCase {
    private let native = FakeNativeSallaPush()
    private let console = RecordingConsole()
    private let center = FakeNotificationCenter()
    private let delegate = SallaPushRNNotificationCenterDelegate()

    func testStartsSallaPushOnceWithTheStaticConfiguration() {
        let start = makeStart(info: [
            "SallaPushAppId": "st_42_ios",
            "SallaPushOpenLaunchURLs": true,
            "SallaPushAPNsEnvironment": "sandbox"
        ])

        start.startOnce()
        start.startOnce()

        XCTAssertEqual(native.initializedAppIds, ["st_42_ios"])
        XCTAssertEqual(native.configurations.first?.openLaunchURLs, true)
        XCTAssertEqual(native.configurations.first?.apnsEnvironment, .sandbox)
        XCTAssertEqual(start.earlyInit, StaticConfig(appId: "st_42_ios", openLaunchURLs: true, apnsEnvironment: .sandbox))
    }

    func testStartsSallaPushWithTheStaticBadgeSettings() {
        let start = makeStart(info: [
            "SallaPushAppId": "st_42_ios",
            "SallaPushAutoClearBadge": false,
            "SallaPushAutoUpdateBadge": "NO"
        ])

        start.startOnce()

        XCTAssertEqual(native.configurations.first?.autoClearBadge, false)
        XCTAssertEqual(native.configurations.first?.autoUpdateBadge, false)
        XCTAssertEqual(console.errors, [])
    }

    func testStartsNothingWithoutAnAppId() {
        let start = makeStart(info: ["SallaPushRequiresUserConsent": true])

        start.startOnce()

        XCTAssertEqual(native.initializedAppIds, [])
        XCTAssertNil(start.earlyInit)
    }

    func testStartsNothingWhenTheAppIdBuildSettingIsUnset() {
        let start = makeStart(info: ["SallaPushAppId": ""])

        start.startOnce()

        XCTAssertEqual(native.initializedAppIds, [])
        XCTAssertNil(start.earlyInit)
        XCTAssertEqual(console.errors, [])
    }

    func testReportsIgnoredKeysOnceAndStillStarts() {
        let start = makeStart(info: ["SallaPushAppId": "st_42_ios", "SallaPushAutoClearBadge": "sometimes"])

        start.startOnce()
        start.startOnce()

        XCTAssertEqual(native.initializedAppIds, ["st_42_ios"])
        XCTAssertEqual(native.configurations.first?.autoClearBadge, true)
        XCTAssertEqual(console.errors, ["Ignored SallaPushAutoClearBadge: \"sometimes\" is not true, false, YES, NO, 1 or 0."])
    }

    func testInstallsItsDelegateAndKeepsThePreviousOneStrongly() {
        weak var weakPrevious: RecordingNotificationCenterDelegate?
        do {
            let previous = RecordingNotificationCenterDelegate()
            weakPrevious = previous
            center.delegate = previous

            makeStart(info: [:]).startOnce()
        }

        XCTAssertTrue(center.delegate === delegate)
        XCTAssertNotNil(weakPrevious)
        XCTAssertTrue(delegate.previous === weakPrevious)
    }

    func testInstallsItsDelegateWhenNoneIsSet() {
        makeStart(info: ["SallaPushAppId": "st_42_ios"]).startOnce()

        XCTAssertTrue(center.delegate === delegate)
        XCTAssertNil(delegate.previous)
    }

    func testInstallsItsDelegateOnce() {
        let start = makeStart(info: [:])
        start.startOnce()
        let later = RecordingNotificationCenterDelegate()
        center.delegate = later

        start.startOnce()

        XCTAssertTrue(center.delegate === later)
        XCTAssertNil(delegate.previous)
    }

    func testStartingLateStartsSallaPushAndSaysTheStartCallIsMissing() {
        let start = makeStart(info: ["SallaPushAppId": "st_42_ios"])

        start.startLateOnce()
        start.startLateOnce()

        XCTAssertEqual(native.initializedAppIds, ["st_42_ios"])
        XCTAssertTrue(center.delegate === delegate)
        XCTAssertEqual(console.errors, [
            "SallaPushRN.start() was not called in application(_:didFinishLaunchingWithOptions:), so SallaPush started "
                + "only when JavaScript first used it, and the tap that launched the app can be missed. Call "
                + "SallaPushRN.start() as the first statement there."
        ])
    }

    func testStartingLateAfterStartDoesNothing() {
        let start = makeStart(info: ["SallaPushAppId": "st_42_ios"])

        start.startOnce()
        start.startLateOnce()

        XCTAssertEqual(native.initializedAppIds, ["st_42_ios"])
        XCTAssertEqual(console.errors, [])
    }

    func testTheExampleAppInstalledSallaPushsDelegateAtLaunch() {
        XCTAssertTrue(UNUserNotificationCenter.current().delegate === SallaPushRNNotificationCenterDelegate.shared)
    }

    private func makeStart(info: [String: Any]) -> SallaPushRN {
        SallaPushRN(native: native, info: info, console: console, notificationCenter: { [center] in center }, delegate: delegate)
    }
}
