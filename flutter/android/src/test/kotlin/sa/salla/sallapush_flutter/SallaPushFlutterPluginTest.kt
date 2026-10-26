package sa.salla.sallapush_flutter

import android.content.Context
import android.util.Log
import androidx.test.core.app.ApplicationProvider
import com.salla.push.SallaPushConfig
import com.salla.push.SallaPushLogLevel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.shadows.ShadowLog
import sa.salla.sallapush_flutter.FakeBinaryMessenger.Companion.HOST_API
import sa.salla.sallapush_flutter.FakeNativeSallaPush.Call

@RunWith(RobolectricTestRunner::class)
class SallaPushFlutterPluginTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val native = FakeNativeSallaPush()
    private val messenger = FakeBinaryMessenger()
    private var earlyInit: StaticConfig? = null
    private val plugin = SallaPushFlutterPlugin(native, { earlyInit }, PlatformOnlyCalls())
    private val defaults = NativeValues.defaults()

    private val hostMethods = listOf(
        "initialize", "isInitialized", "appId", "sdkVersion", "setConsentRequired", "setConsentGiven", "login", "logout",
        "externalId", "isLoggedIn", "addTag", "addTags", "removeTag", "removeTags", "getTags", "setLanguage",
        "pushSubscriptionId", "pushSubscriptionToken", "pushSubscriptionOptedIn", "optIn", "optOut",
        "addPushSubscriptionListener", "removePushSubscriptionListener", "permission", "canRequestPermission",
        "permissionStatus", "requestPermission", "registerForProvisionalAuthorization", "refreshPermission",
        "registerForRemoteNotifications", "forwardApnsToken", "clearAll", "removeNotification",
        "isSallaPushNotification", "trackOpened", "displayNotification", "setDisplayCompatPayloads", "logLevel",
        "setLogLevel", "setLogHandlerLevel",
    )
    private val eventStreams = listOf(
        "clickEvents", "willDisplayEvents", "permissionChanges", "userChanges", "loginFailures",
        "pushSubscriptionChanges", "logEntries",
    )

    @Before
    fun attachToTheEngine() {
        ShadowLog.reset()
        plugin.attach(context, messenger)
    }

    private fun initializations() = native.calls.filterIsInstance<Call.InitWithContext>()

    @Test
    fun setsUpTheHostApiAndTheEventStreamsWhenAttachedAndRemovesThemWhenDetached() {
        assertEquals(
            (hostMethods.map { "$HOST_API.$it" } + eventStreams.map { FakeBinaryMessenger.eventChannel(it) }).toSet(),
            messenger.handlers.keys,
        )

        plugin.detach(messenger)

        assertEquals(emptySet<String>(), messenger.handlers.keys)
    }

    @Test
    fun answersDartThroughTheHostApi() {
        native.sdkVersion = "1.0.2"

        assertEquals(listOf("1.0.2"), messenger.callHostApi("sdkVersion"))
        assertEquals(
            listOf(null),
            messenger.callHostApi("initialize", listOf("st_42_android", ConfigMessage(logLevel = LogLevelMessage.INFO))),
        )
        val initialization = initializations().single()
        assertEquals("st_42_android", initialization.appId)
        assertEquals(SallaPushLogLevel.INFO, initialization.config.logLevel)
    }

    @Test
    fun initializeStartsSallaPushWithTheApplicationContextTheAppIdAndTheOptions() {
        plugin.initialize(
            "st_42_android",
            ConfigMessage(
                logLevel = LogLevelMessage.DEBUG,
                appVersion = "5.0.38",
                clearTagsOnLogout = false,
                requiresUserConsent = true,
                openLaunchUrls = true,
                autoClearBadge = !defaults.autoClearBadge,
                autoUpdateBadge = !defaults.autoUpdateBadge,
                iosAppGroupIdentifier = "group.sa.salla.example",
                iosApnsEnvironment = ApnsEnvironmentMessage.SANDBOX,
                iosRegisterForRemoteNotificationsOnInit = false,
            ),
        )

        val initialization = initializations().single()
        assertSame(context, initialization.context)
        assertEquals("st_42_android", initialization.appId)
        val config = initialization.config
        assertEquals(SallaPushLogLevel.DEBUG, config.logLevel)
        assertEquals("5.0.38", config.appVersion)
        assertFalse(config.clearTagsOnLogout)
        assertTrue(config.requiresUserConsent)
        assertTrue(config.openLaunchUrls)
        assertEquals(!defaults.autoClearBadge, config.autoClearBadge)
        assertEquals(!defaults.autoUpdateBadge, config.autoUpdateBadge)
        assertEquals(emptyList<String>(), consoleLines())
    }

    @Test
    fun initializeSetsEachBooleanOptionAloneOnItsOwnSetting() {
        // Each option, set to the opposite of SallaPush's default, changes only its own setting: clearTagsOnLogout,
        // requiresUserConsent, openLaunchUrls, autoClearBadge, autoUpdateBadge.
        fun settings(config: SallaPushConfig) = listOf(
            config.clearTagsOnLogout,
            config.requiresUserConsent,
            config.openLaunchUrls,
            config.autoClearBadge,
            config.autoUpdateBadge,
        )
        val options = listOf(
            ConfigMessage(clearTagsOnLogout = !defaults.clearTagsOnLogout) to 0,
            ConfigMessage(requiresUserConsent = !defaults.requiresUserConsent) to 1,
            ConfigMessage(openLaunchUrls = !defaults.openLaunchUrls) to 2,
            ConfigMessage(autoClearBadge = !defaults.autoClearBadge) to 3,
            ConfigMessage(autoUpdateBadge = !defaults.autoUpdateBadge) to 4,
        )

        for ((message, changed) in options) {
            plugin.initialize("st_42_android", message)
            val expected = settings(defaults).mapIndexed { index, value -> if (index == changed) !value else value }
            assertEquals(message.toString(), expected, settings(initializations().last().config))
        }
    }

    @Test
    fun initializeKeepsTheSdkDefaultsForOptionsNotSet() {
        plugin.initialize("st_42_android", ConfigMessage())

        val config = initializations().single().config
        assertNull(config.logLevel)
        assertNull(config.appVersion)
        assertTrue(config.clearTagsOnLogout)
        assertFalse(config.requiresUserConsent)
        assertFalse(config.openLaunchUrls)
        // The badge defaults the docs give for Android: a SallaPush Android with other defaults fails here.
        assertFalse(config.autoClearBadge)
        assertTrue(config.autoUpdateBadge)
    }

    @Test
    fun initializeMapsEveryLogLevelByCase() {
        for (level in LogLevelMessage.entries) {
            plugin.initialize("st_42_android", ConfigMessage(logLevel = level))
        }

        assertEquals(
            listOf(
                SallaPushLogLevel.OFF,
                SallaPushLogLevel.ERROR,
                SallaPushLogLevel.WARN,
                SallaPushLogLevel.INFO,
                SallaPushLogLevel.DEBUG,
                SallaPushLogLevel.VERBOSE,
            ),
            initializations().map { it.config.logLevel },
        )
    }

    @Test
    fun gettersReadSallaPushAtEveryCall() {
        native.isInitialized = true
        native.appId = "st_42_android"
        native.sdkVersion = "1.0.2"

        assertTrue(plugin.isInitialized())
        assertEquals("st_42_android", plugin.appId())
        assertEquals("1.0.2", plugin.sdkVersion())

        native.isInitialized = false
        native.appId = null

        assertFalse(plugin.isInitialized())
        assertNull(plugin.appId())
    }

    @Test
    fun consentLoginAndLogoutReachSallaPushUnchanged() {
        plugin.setConsentRequired(false)
        plugin.setConsentGiven(true)
        plugin.setConsentGiven(false)
        plugin.login(" 42 ", " token ")
        plugin.logout()

        assertEquals(
            listOf(
                Call.SetConsentRequired(false),
                Call.SetConsentGiven(true),
                Call.SetConsentGiven(false),
                Call.Login(" 42 ", " token "),
                Call.Logout,
            ),
            native.calls,
        )
        assertEquals(emptyList<String>(), consoleLines())
    }

    @Test
    fun userGettersReadSallaPushAtEveryCall() {
        native.externalId = "42"
        native.isLoggedIn = true
        native.savedTags = mapOf("tier" to "gold")

        assertEquals("42", plugin.externalId())
        assertTrue(plugin.isLoggedIn())
        assertEquals(mapOf("tier" to "gold"), plugin.getTags())

        native.externalId = null
        native.isLoggedIn = false
        native.savedTags = emptyMap()

        assertNull(plugin.externalId())
        assertFalse(plugin.isLoggedIn())
        assertEquals(emptyMap<String, String>(), plugin.getTags())
    }

    @Test
    fun tagsAndLanguageReachSallaPushUnchanged() {
        plugin.addTag(" Tier ", "gold")
        plugin.addTags(mapOf("tier" to "gold", " City " to ""))
        plugin.removeTag("tier")
        plugin.removeTags(listOf("tier", " City "))
        plugin.setLanguage("ar")
        plugin.setLanguage(null)

        assertEquals(
            listOf(
                Call.AddTag(" Tier ", "gold"),
                Call.AddTags(mapOf("tier" to "gold", " City " to "")),
                Call.RemoveTag("tier"),
                Call.RemoveTags(listOf("tier", " City ")),
                Call.SetLanguage("ar"),
                Call.SetLanguage(null),
            ),
            native.calls,
        )
    }

    @Test
    fun tagsCrossTheHostApiAsMapsAndLists() {
        native.savedTags = mapOf("tier" to "gold")

        messenger.callHostApi("addTags", listOf(mapOf("tier" to "gold")))
        messenger.callHostApi("removeTags", listOf(listOf("city")))

        assertEquals(listOf(mapOf("tier" to "gold")), messenger.callHostApi("getTags"))
        assertEquals(listOf(Call.AddTags(mapOf("tier" to "gold")), Call.RemoveTags(listOf("city"))), native.calls)
    }

    @Test
    fun pushSubscriptionGettersReadSallaPushAtEveryCall() {
        native.pushSubscriptionId = "7d1b2c4e-5f60-4a8b-9c0d-1e2f3a4b5c6d"
        native.pushSubscriptionToken = "fcm-token"
        native.pushSubscriptionOptedIn = true

        assertEquals("7d1b2c4e-5f60-4a8b-9c0d-1e2f3a4b5c6d", plugin.pushSubscriptionId())
        assertEquals("fcm-token", plugin.pushSubscriptionToken())
        assertTrue(plugin.pushSubscriptionOptedIn())

        native.pushSubscriptionId = null
        native.pushSubscriptionToken = null
        native.pushSubscriptionOptedIn = false

        assertNull(plugin.pushSubscriptionId())
        assertNull(plugin.pushSubscriptionToken())
        assertFalse(plugin.pushSubscriptionOptedIn())
    }

    @Test
    fun optInAndOptOutReachSallaPush() {
        plugin.optOut()
        plugin.optIn()

        assertEquals(listOf(Call.OptOut, Call.OptIn), native.calls)
    }

    @Test
    fun permissionGettersReadSallaPushAtEveryCall() {
        native.permission = true
        native.canRequest = false

        assertTrue(plugin.permission())
        assertFalse(plugin.canRequestPermission())

        native.permission = false
        native.canRequest = true

        assertFalse(plugin.permission())
        assertTrue(plugin.canRequestPermission())
    }

    @Test
    fun requestPermissionAnswersDartWhenSallaPushAnswers() {
        var reply: List<Any?>? = null

        messenger.sendToHostApi("requestPermission", listOf(true)) { reply = it }

        assertEquals(listOf(Call.RequestPermission(true)), native.calls)
        assertNull(reply)

        native.answerPermissionRequests(true)

        assertEquals(listOf(true), reply)
    }

    @Test
    fun iosOnlyCallsAnswerNeutrallyAndSaySoOncePerProcess() {
        var provisional: Result<Boolean>? = null

        assertNull(plugin.permissionStatus())
        assertNull(plugin.permissionStatus())
        plugin.registerForProvisionalAuthorization { provisional = it }
        plugin.registerForRemoteNotifications()
        plugin.forwardApnsToken("0A1B2C3D")
        plugin.forwardApnsToken("0A1B2C3D")

        assertEquals(Result.success(false), provisional)
        assertEquals(emptyList<Call>(), native.calls)
        assertEquals(
            listOf(
                "SallaPush.notifications.permissionStatus works on iOS only; on Android it returns null.",
                "SallaPush.notifications.registerForProvisionalAuthorization works on iOS only; on Android it returns " +
                    "false.",
                "SallaPush.notifications.registerForRemoteNotifications works on iOS only; on Android it does nothing.",
                "SallaPush.notifications.forwardApnsToken works on iOS only; on Android it does nothing.",
            ),
            consoleLines(Log.INFO),
        )
    }

    @Test
    fun iosOnlyCallsAreReportedOnceForEveryEngine() {
        val platformOnly = PlatformOnlyCalls()
        val engines = List(2) { SallaPushFlutterPlugin(native, { null }, platformOnly) }

        engines.forEach { it.registerForRemoteNotifications() }

        assertEquals(1, consoleLines(Log.INFO).size)
    }

    @Test
    fun refreshClearAndRemoveReachSallaPush() {
        plugin.refreshPermission()
        plugin.clearAll()
        plugin.removeNotification(-1_408_375_307L)

        assertEquals(
            listOf(Call.RefreshPermission, Call.ClearAllNotifications, Call.RemoveNotification(-1_408_375_307)),
            native.calls,
        )
    }

    @Test
    fun removeNotificationIgnoresAnIdBeyond32BitsWithAConsoleLine() {
        plugin.removeNotification(4_294_967_301L)

        assertEquals(emptyList<Call>(), native.calls)
        assertEquals(
            listOf(
                "SallaPush.notifications.removeNotification ignored 4294967301: Android notification ids are 32-bit " +
                    "integers.",
            ),
            consoleLines(),
        )
    }

    @Test
    fun isSallaPushNotificationAsksSallaPushWithTheFcmDataForm() {
        native.isSallaPushMessageAnswer = true

        val answer = plugin.isSallaPushNotification(mapOf("sp_v" to "1", "sp_id" to "msg_1", "badge" to 2, "note" to null))

        assertTrue(answer)
        assertEquals(
            listOf(Call.IsSallaPushMessage(mapOf("sp_v" to "1", "sp_id" to "msg_1", "badge" to "2"))),
            native.calls,
        )
    }

    @Test
    fun trackOpenedPassesTheAdditionalDataAsJsonAndNull() {
        native.trackOpenedAnswer = true

        assertTrue(plugin.trackOpened(mapOf("push_ref" to "msg_1")))
        assertTrue(plugin.trackOpened(null))
        assertEquals(listOf(Call.TrackOpened("{\"push_ref\":\"msg_1\"}"), Call.TrackOpened(null)), native.calls)
    }

    @Test
    fun logLevelMapsEveryLevelByCaseBothWays() {
        val levels = listOf(
            SallaPushLogLevel.OFF to LogLevelMessage.OFF,
            SallaPushLogLevel.ERROR to LogLevelMessage.ERROR,
            SallaPushLogLevel.WARN to LogLevelMessage.WARN,
            SallaPushLogLevel.INFO to LogLevelMessage.INFO,
            SallaPushLogLevel.DEBUG to LogLevelMessage.DEBUG,
            SallaPushLogLevel.VERBOSE to LogLevelMessage.VERBOSE,
        )

        for ((level, message) in levels) {
            native.currentLogLevel = level
            assertEquals(message, plugin.logLevel())
            plugin.setLogLevel(message)
        }

        assertEquals(levels.map { (level, _) -> Call.SetLogLevel(level) }, native.calls)
    }

    @Test
    fun displayOfCompatPayloadsReachesSallaPush() {
        plugin.setDisplayCompatPayloads(false)
        plugin.setDisplayCompatPayloads(true)

        assertEquals(
            listOf(Call.SetDisplayCompatPayloads(false), Call.SetDisplayCompatPayloads(true)),
            native.calls,
        )
        assertEquals(emptyList<String>(), consoleLines(Log.INFO))
    }

    @Test
    fun initializeWithTheStaticAppIdNamesTheOptionsSallaPushIgnores() {
        earlyInit = StaticConfig(appId = "st_42_android")

        plugin.initialize(
            "st_42_android",
            ConfigMessage(
                logLevel = LogLevelMessage.DEBUG,
                appVersion = "5.0.38",
                clearTagsOnLogout = false,
                requiresUserConsent = true,
                openLaunchUrls = true,
                autoClearBadge = false,
                autoUpdateBadge = false,
            ),
        )

        assertEquals(
            listOf(
                "SallaPush already started at launch with this app id, so initialize ignored its options. Set each " +
                    "with its manifest meta-data instead: logLevel (com.salla.push.LOG_LEVEL), appVersion " +
                    "(com.salla.push.APP_VERSION), clearTagsOnLogout (com.salla.push.CLEAR_TAGS_ON_LOGOUT), " +
                    "requiresUserConsent (com.salla.push.REQUIRES_USER_CONSENT), openLaunchUrls " +
                    "(com.salla.push.OPEN_LAUNCH_URLS), autoClearBadge (com.salla.push.AUTO_CLEAR_BADGE), " +
                    "autoUpdateBadge (com.salla.push.AUTO_UPDATE_BADGE).",
            ),
            consoleLines(),
        )
        assertEquals(1, initializations().size)
    }

    @Test
    fun initializeWithTheStaticAppIdAndNoAndroidOptionPrintsNothing() {
        earlyInit = StaticConfig(appId = "st_42_android")

        plugin.initialize("st_42_android", ConfigMessage())
        plugin.initialize("st_42_android", ConfigMessage(iosRegisterForRemoteNotificationsOnInit = false))

        assertEquals(emptyList<String>(), consoleLines())
        assertEquals(2, initializations().size)
    }

    @Test
    fun initializeWithAnotherAppIdPrintsNothing() {
        earlyInit = StaticConfig(appId = "st_42_android")

        plugin.initialize("st_43_android", ConfigMessage(openLaunchUrls = true))

        assertEquals(emptyList<String>(), consoleLines())
        assertEquals(1, initializations().size)
    }

    @Test
    fun initializeWithoutEarlyInitPrintsNothing() {
        plugin.initialize("st_42_android", ConfigMessage(openLaunchUrls = true))

        assertEquals(emptyList<String>(), consoleLines())
    }

    @Test
    fun requiringConsentAfterEarlyInitWithoutConsentPrintsAnError() {
        earlyInit = StaticConfig(appId = "st_42_android", requiresUserConsent = false)

        plugin.setConsentRequired(true)

        assertEquals(
            listOf(
                "setConsentRequired(true) came after SallaPush started at launch without requiring consent, so this " +
                    "device may already have registered and sent data. To require consent from the start, set the " +
                    "meta-data com.salla.push.REQUIRES_USER_CONSENT to true.",
            ),
            consoleLines(),
        )
        assertEquals(listOf(Call.SetConsentRequired(true)), native.calls)
    }

    @Test
    fun requiringConsentAfterEarlyInitThatRequiredItPrintsNothing() {
        earlyInit = StaticConfig(appId = "st_42_android", requiresUserConsent = true)

        plugin.setConsentRequired(true)

        assertEquals(emptyList<String>(), consoleLines())
        assertEquals(listOf(Call.SetConsentRequired(true)), native.calls)
    }

    @Test
    fun requiringConsentWithoutEarlyInitPrintsNothing() {
        plugin.setConsentRequired(true)

        assertEquals(emptyList<String>(), consoleLines())
        assertEquals(listOf(Call.SetConsentRequired(true)), native.calls)
    }
}
