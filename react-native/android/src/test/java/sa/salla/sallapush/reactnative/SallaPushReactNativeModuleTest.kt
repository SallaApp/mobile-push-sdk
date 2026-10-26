package sa.salla.sallapush.reactnative

import android.content.Context
import android.util.Log
import androidx.test.core.app.ApplicationProvider
import com.facebook.react.bridge.JavaOnlyArray
import com.facebook.react.bridge.JavaOnlyMap
import com.facebook.react.bridge.WritableMap
import com.salla.push.SallaPushConfig
import com.salla.push.SallaPushLogLevel
import org.json.JSONObject
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

@RunWith(RobolectricTestRunner::class)
class SallaPushReactNativeModuleTest {
  private val context: Context = ApplicationProvider.getApplicationContext()
  private val native = FakeNativeSallaPush()
  private val once = OncePerProcess()

  @Before
  fun clearLog() {
    ShadowLog.clear()
  }

  @Test
  fun initializesWithTheAppIdTheApplicationContextAndEveryAndroidOption() {
    module().initWithAppId(
      "st_42_android",
      JavaOnlyMap.of(
        "logLevel", "debug",
        "appVersion", "2.1.0",
        "clearTagsOnLogout", false,
        "requiresUserConsent", true,
        "openLaunchUrls", true,
        "autoClearBadge", false,
        "autoUpdateBadge", false,
        "iosAppGroupIdentifier", "group.sa.salla.example",
      )
    )

    assertEquals(listOf("initWithContext(st_42_android)"), native.calls)
    assertSame(context, native.initContexts.single())
    val config = native.initConfigs.single()
    assertEquals(SallaPushLogLevel.DEBUG, config.logLevel)
    assertEquals("2.1.0", config.appVersion)
    assertFalse(config.clearTagsOnLogout)
    assertTrue(config.requiresUserConsent)
    assertTrue(config.openLaunchUrls)
    assertFalse(config.autoClearBadge)
    assertFalse(config.autoUpdateBadge)
    assertTrue(errors().isEmpty())
  }

  // Each boolean alone, at the value that isn't native's default, so options swapped with each other can't pass.
  @Test
  fun passesEachBooleanOptionAloneAndLeavesTheOthersAtNativesDefaults() {
    val options = mapOf<String, (SallaPushConfig) -> Boolean>(
      "clearTagsOnLogout" to { it.clearTagsOnLogout },
      "requiresUserConsent" to { it.requiresUserConsent },
      "openLaunchUrls" to { it.openLaunchUrls },
      "autoClearBadge" to { it.autoClearBadge },
      "autoUpdateBadge" to { it.autoUpdateBadge },
    )
    val defaults = SallaPushConfig.Builder().build()
    options.forEach { (name, read) ->
      val native = FakeNativeSallaPush()

      module(native = native).initWithAppId("st_42_android", JavaOnlyMap.of(name, !read(defaults)))

      val config = native.initConfigs.single()
      options.forEach { (other, readOther) ->
        val expected = if (other == name) !readOther(defaults) else readOther(defaults)
        assertEquals("$name alone: $other", expected, readOther(config))
      }
    }
  }

  @Test
  fun initializesWithNativeDefaultsForLeftOutOptions() {
    module().initWithAppId("st_42_android", JavaOnlyMap.of("appVersion", null))

    val config = native.initConfigs.single()
    assertNull(config.logLevel)
    assertNull(config.appVersion)
    assertTrue(config.clearTagsOnLogout)
    assertFalse(config.requiresUserConsent)
    assertFalse(config.openLaunchUrls)
    val defaults = SallaPushConfig.Builder().build()
    assertEquals(defaults.autoClearBadge, config.autoClearBadge)
    assertEquals(defaults.autoUpdateBadge, config.autoUpdateBadge)
  }

  @Test
  fun mapsEveryLogLevelByItsJavaScriptName() {
    val levels = mapOf(
      "off" to SallaPushLogLevel.OFF,
      "error" to SallaPushLogLevel.ERROR,
      "warn" to SallaPushLogLevel.WARN,
      "info" to SallaPushLogLevel.INFO,
      "debug" to SallaPushLogLevel.DEBUG,
      "verbose" to SallaPushLogLevel.VERBOSE,
    )
    val module = module()

    levels.keys.forEach { module.initWithAppId("st_42_android", JavaOnlyMap.of("logLevel", it)) }
    module.initWithAppId("st_42_android", JavaOnlyMap.of("logLevel", "Debug"))

    assertEquals(levels.values.toList() + listOf(null), native.initConfigs.map { it.logLevel })
  }

  @Test
  fun reportsTheOptionsASecondInitializeWithTheStaticAppIdIgnores() {
    val module = module(earlyInit = StaticConfig(appId = "st_42_android"))

    module.initWithAppId(
      "st_42_android",
      JavaOnlyMap.of("logLevel", "debug", "openLaunchUrls", true, "iosApnsEnvironment", "sandbox")
    )

    assertEquals(
      listOf(
        "[SallaPush] initialize ignored logLevel, openLaunchUrls: SallaPush already started with this app id from " +
          "com.salla.push.APP_ID, so the call changes nothing. Set them with the meta-data com.salla.push.LOG_LEVEL, " +
          "com.salla.push.OPEN_LAUNCH_URLS instead."
      ),
      errors()
    )
    assertEquals(listOf("initWithContext(st_42_android)"), native.calls)
  }

  @Test
  fun namesTheMetaDataOfEveryIgnoredOption() {
    val module = module(earlyInit = StaticConfig(appId = "st_42_android"))

    module.initWithAppId(
      "st_42_android",
      JavaOnlyMap.of(
        "logLevel", "warn",
        "appVersion", "2.1.0",
        "clearTagsOnLogout", true,
        "requiresUserConsent", true,
        "openLaunchUrls", false,
        "autoClearBadge", true,
        "autoUpdateBadge", true,
      )
    )

    assertEquals(
      listOf(
        "[SallaPush] initialize ignored logLevel, appVersion, clearTagsOnLogout, requiresUserConsent, " +
          "openLaunchUrls, autoClearBadge, autoUpdateBadge: SallaPush already started with this app id from " +
          "com.salla.push.APP_ID, so the call changes nothing. Set them with the meta-data com.salla.push.LOG_LEVEL, " +
          "com.salla.push.APP_VERSION, com.salla.push.CLEAR_TAGS_ON_LOGOUT, com.salla.push.REQUIRES_USER_CONSENT, " +
          "com.salla.push.OPEN_LAUNCH_URLS, com.salla.push.AUTO_CLEAR_BADGE, com.salla.push.AUTO_UPDATE_BADGE " +
          "instead."
      ),
      errors()
    )
  }

  @Test
  fun reportsNothingForASecondInitializeWithoutAndroidOptions() {
    val module = module(earlyInit = StaticConfig(appId = "st_42_android"))

    module.initWithAppId("st_42_android", JavaOnlyMap())
    module.initWithAppId("st_42_android", JavaOnlyMap.of("iosApnsEnvironment", "sandbox"))

    assertTrue(errors().isEmpty())
    assertEquals(2, native.initConfigs.size)
  }

  @Test
  fun reportsNothingForAnotherAppId() {
    module(earlyInit = StaticConfig(appId = "st_42_android"))
      .initWithAppId("st_7_android", JavaOnlyMap.of("logLevel", "debug"))

    assertTrue(errors().isEmpty())
  }

  @Test
  fun reportsNothingWithoutEarlyInit() {
    module().initWithAppId("st_42_android", JavaOnlyMap.of("logLevel", "debug"))

    assertTrue(errors().isEmpty())
  }

  @Test
  fun reportsConsentRequiredAfterEarlyInitWithoutTheStaticKey() {
    module(earlyInit = StaticConfig(appId = "st_42_android", requiresUserConsent = false)).setConsentRequired(true)

    assertEquals(
      listOf(
        "[SallaPush] setConsentRequired(true) came after SallaPush started from com.salla.push.APP_ID without " +
          "com.salla.push.REQUIRES_USER_CONSENT, so the device may already have registered and sent data. Set " +
          "com.salla.push.REQUIRES_USER_CONSENT to true in the manifest to require consent from the start."
      ),
      errors()
    )
    assertEquals(listOf("setConsentRequired(true)"), native.calls)
  }

  @Test
  fun reportsNothingWhenTheStaticKeyRequiresConsent() {
    module(earlyInit = StaticConfig(appId = "st_42_android", requiresUserConsent = true)).setConsentRequired(true)

    assertTrue(errors().isEmpty())
    assertEquals(listOf("setConsentRequired(true)"), native.calls)
  }

  @Test
  fun reportsNothingForConsentWithoutEarlyInitOrWhenNotRequired() {
    module().setConsentRequired(true)
    module(earlyInit = StaticConfig(appId = "st_42_android")).setConsentRequired(false)

    assertTrue(errors().isEmpty())
    assertEquals(listOf("setConsentRequired(true)", "setConsentRequired(false)"), native.calls)
  }

  @Test
  fun resolvesTheNativeValuesAtCallTime() {
    val module = module()
    assertEquals(false, resolved { module.isInitialized(it) })
    assertNull(resolved { module.getAppId(it) })

    native.isInitialized = true
    native.appId = "st_42_android"

    assertEquals(true, resolved { module.isInitialized(it) })
    assertEquals("st_42_android", resolved { module.getAppId(it) })
    assertEquals("1.1.0", resolved { module.getSdkVersion(it) })
  }

  @Test
  fun rejectsWithTheInternalCodeWhenTheBridgeFails() {
    val failing = object : NativeSallaPush by native {
      override val isInitialized: Boolean
        get() = throw IllegalStateException("bridge failure")
    }
    val promise = RecordingPromise()

    module(native = failing).isInitialized(promise)

    assertFalse(promise.resolved)
    assertEquals("E_SALLAPUSH_INTERNAL", promise.rejectionCode)
  }

  @Test
  fun passesConsentAndIdentityCallsUnchanged() {
    val module = module()

    module.setConsentGiven(true)
    module.setConsentGiven(false)
    module.login(" customer-7 ", " token ")
    module.logout()

    assertEquals(
      listOf("setConsentGiven(true)", "setConsentGiven(false)", "login( customer-7 ,  token )", "logout()"),
      native.calls
    )
  }

  @Test
  fun resolvesTheUserAndThePushSubscriptionAtCallTime() {
    val module = module()
    assertNull(resolved { module.getExternalId(it) })
    assertEquals(false, resolved { module.isLoggedIn(it) })
    assertEquals(JavaOnlyMap(), resolved { module.getTags(it) })
    assertNull(resolved { module.getPushSubscriptionId(it) })
    assertNull(resolved { module.getPushSubscriptionToken(it) })
    assertEquals(false, resolved { module.getPushSubscriptionOptedIn(it) })

    native.externalId = "customer-7"
    native.isLoggedIn = true
    native.tags = mapOf("level" to "gold", "city" to "riyadh")
    native.pushSubscriptionId = "3f1c5a52-6a7e-4d1e-9a53-0c7b9e1d2f40"
    native.pushSubscriptionToken = "fcm-token"
    native.pushSubscriptionOptedIn = true

    assertEquals("customer-7", resolved { module.getExternalId(it) })
    assertEquals(true, resolved { module.isLoggedIn(it) })
    assertEquals(JavaOnlyMap.of("level", "gold", "city", "riyadh"), resolved { module.getTags(it) })
    assertEquals("3f1c5a52-6a7e-4d1e-9a53-0c7b9e1d2f40", resolved { module.getPushSubscriptionId(it) })
    assertEquals("fcm-token", resolved { module.getPushSubscriptionToken(it) })
    assertEquals(true, resolved { module.getPushSubscriptionOptedIn(it) })
  }

  @Test
  fun passesTagEntriesToNativeUncheckedForItsPerEntryRule() {
    val module = module()

    module.addTags(JavaOnlyMap.of("level", "gold", "visits", 3, "vip", true, "note", null))
    module.removeTags(JavaOnlyArray.of("level", 3.0, null))

    assertEquals(listOf(mapOf("level" to "gold", "visits" to 3.0, "vip" to true, "note" to null)), native.addedTags)
    assertEquals(listOf(listOf("level", 3.0, null)), native.removedTags)
  }

  @Test
  fun passesTagLanguageAndSubscriptionCallsUnchanged() {
    val module = module()

    module.addTag(" Level ", "")
    module.removeTag(" City ")
    module.setLanguage("ar")
    module.setLanguage(null)
    module.optIn()
    module.optOut()

    assertEquals(
      listOf("addTag( Level , )", "removeTag( City )", "setLanguage(ar)", "setLanguage(null)", "optIn()", "optOut()"),
      native.calls
    )
  }

  @Test
  fun resolvesThePermissionAtCallTime() {
    val module = module()
    assertEquals(false, resolved { module.getPermission(it) })
    assertEquals(false, resolved { module.canRequestPermission(it) })

    native.permission = true
    native.canRequest = true

    assertEquals(true, resolved { module.getPermission(it) })
    assertEquals(true, resolved { module.canRequestPermission(it) })
  }

  @Test
  fun requestsThePermissionAndResolvesNativesAnswer() {
    native.permissionAnswer = true
    val module = module()

    assertEquals(true, resolved { module.requestPermission(true, it) })
    assertEquals(true, resolved { module.requestPermission(false, it) })
    assertEquals(listOf("requestPermission(true)", "requestPermission(false)"), native.calls)
  }

  @Test
  fun iosOnlyCallsResolveNeutralValuesAndSayItOncePerProcess() {
    val module = module()

    repeat(2) {
      assertNull(resolved { module.getPermissionStatus(it) })
      assertEquals(false, resolved { module.registerForProvisionalAuthorization(it) })
      module.registerForRemoteNotifications()
      module.forwardApnsToken("0A1BFF7C")
    }
    module(native = native).registerForRemoteNotifications()

    assertTrue(native.calls.isEmpty())
    assertEquals(
      listOf(
        "[SallaPush] Notifications.getPermissionStatus is iOS only and resolves null on Android.",
        "[SallaPush] Notifications.registerForProvisionalAuthorization is iOS only and resolves false on Android.",
        "[SallaPush] Notifications.registerForRemoteNotifications is iOS only and does nothing on Android.",
        "[SallaPush] Notifications.forwardApnsToken is iOS only and does nothing on Android.",
      ),
      infos()
    )
  }

  @Test
  fun passesRefreshClearAllAndRemoveNotification() {
    val module = module()

    module.refreshPermission()
    module.clearAll()
    module.removeNotification(42.0)
    module.removeNotification(-2147483648.0)

    assertEquals(
      listOf(
        "refreshPermission()",
        "clearAllNotifications()",
        "removeNotification(42)",
        "removeNotification(-2147483648)",
      ),
      native.calls
    )
  }

  @Test
  fun checksAPayloadAsAnFcmDataMapAndResolvesNativesAnswer() {
    native.recognizesMessages = true
    val custom = mapOf("i" to "os-id", "a" to mapOf("push_ref" to "msg_1a2b"))

    val recognized = resolved {
      module().isSallaPushNotification(JavaOnlyMap.of("alert", "Hi", "custom", custom, "badge", 2, "none", null), it)
    }

    assertEquals(true, recognized)
    val data = native.checkedMessages.single()
    assertEquals(setOf("alert", "custom", "badge"), data.keys)
    assertEquals("Hi", data["alert"])
    assertEquals("2.0", data["badge"])
    assertEquals("msg_1a2b", JSONObject(data.getValue("custom")).getJSONObject("a").getString("push_ref"))
  }

  @Test
  fun tracksOpenedWithTheDataAsAJsonObject() {
    native.tracksOpened = true
    val module = module()

    assertEquals(true, resolved { module.trackOpened(JavaOnlyMap.of("push_ref", "msg_1a2b", "screen", "offers"), it) })
    assertEquals(true, resolved { module.trackOpened(null, it) })

    assertEquals("msg_1a2b", native.openedData.first()?.getString("push_ref"))
    assertEquals("offers", native.openedData.first()?.getString("screen"))
    assertNull(native.openedData.last())
  }

  @Test
  fun readsAndSetsEveryLogLevelByItsJavaScriptName() {
    val levels = mapOf(
      "off" to SallaPushLogLevel.OFF,
      "error" to SallaPushLogLevel.ERROR,
      "warn" to SallaPushLogLevel.WARN,
      "info" to SallaPushLogLevel.INFO,
      "debug" to SallaPushLogLevel.DEBUG,
      "verbose" to SallaPushLogLevel.VERBOSE,
    )
    val module = module()

    levels.forEach { (name, level) ->
      native.logLevel = level
      assertEquals(name, resolved { module.getLogLevel(it) })
    }
    levels.entries.reversed().forEach { (name, level) ->
      module.setLogLevel(name)
      assertEquals(level, native.logLevel)
    }
  }

  @Test
  fun ignoresALogLevelNameThatIsNotALevel() {
    native.logLevel = SallaPushLogLevel.ERROR
    val module = module()

    module.setLogLevel("Debug")
    module.setLogLevel("trace")

    assertEquals(SallaPushLogLevel.ERROR, native.logLevel)
  }

  @Test
  fun passesTheCompatibilitySetting() {
    val module = module()

    module.setDisplayCompatPayloads(false)
    module.setDisplayCompatPayloads(true)

    assertEquals(
      listOf("setDisplayCompatPayloads(false)", "setDisplayCompatPayloads(true)"),
      native.calls
    )
  }

  @Test
  fun postsTheEventCallsToTheMainThreadInCallOrder() {
    val main = mutableListOf<() -> Unit>()
    val module = module(runOnMain = { main += it })

    module.startEvents("click")
    module.addPushSubscriptionListener(3.0)
    assertTrue(native.calls.isEmpty())
    main.drain()
    val click = native.clickListeners.single()
    val observer = native.subscriptionObservers.single()
    module.stopEvents("click")
    module.removePushSubscriptionListener(3.0)
    main.drain()

    assertEquals(
      listOf("addClickListener", "addSubscriptionObserver", "removeClickListener", "removeSubscriptionObserver"),
      native.calls
    )
    assertEquals(listOf<Any>(click, observer), native.removed)
  }

  @Test
  fun removesEveryRegistrationOnTheMainThreadWhenInvalidated() {
    val main = mutableListOf<() -> Unit>()
    val module = module(runOnMain = { main += it })
    module.startEvents("user")
    module.startEvents("permission")
    module.addPushSubscriptionListener(1.0)
    main.drain()

    module.invalidate()
    assertEquals(3, native.calls.size)
    main.drain()

    assertTrue(native.userObservers.isEmpty())
    assertTrue(native.permissionObservers.isEmpty())
    assertTrue(native.subscriptionObservers.isEmpty())
  }

  // React Native destroys the runtime right after invalidate() returns, while callbacks native posted earlier are still
  // queued on the main thread, ahead of the removal.
  @Test
  fun emitsNothingAndLeavesForegroundNotificationsToNativeOnceInvalidated() {
    val main = mutableListOf<() -> Unit>()
    val converted = mutableListOf<Map<String, Any?>>()
    val module = module(runOnMain = { main += it }, toWritableMap = { converted += it; JavaOnlyMap() })
    listOf("click", "willDisplay", "log").forEach(module::startEvents)
    module.addPushSubscriptionListener(1.0)
    main.drain()

    module.invalidate()
    native.clickListeners.single().onClick(NativeValues.click(testNotification(), null, null))
    val event = NativeValues.willDisplay(testNotification())
    native.foregroundListeners.single().onWillDisplay(event)
    val state = NativeValues.subscription(null, null, false)
    native.subscriptionObservers.single().onPushSubscriptionChange(NativeValues.subscriptionChange(state, state))
    native.logListeners.keys.single().onLogEvent(
      NativeValues.logEvent(SallaPushLogLevel.ERROR, "registration", "register.failed", "Failed.", emptyMap(), 0L)
    )
    main.removeAt(main.lastIndex).invoke()

    assertTrue(converted.isEmpty())
    assertFalse(event.isPrevented)
    main.drain()
    assertTrue(native.clickListeners.isEmpty())
    assertTrue(native.foregroundListeners.isEmpty())
    assertTrue(native.subscriptionObservers.isEmpty())
    assertTrue(native.logListeners.isEmpty())
  }

  @Test
  fun postsTheLogHandlerLevelToTheMainThreadAndIgnoresAnUnknownName() {
    val main = mutableListOf<() -> Unit>()
    val module = module(runOnMain = { main += it })

    module.startEvents("log")
    module.setLogHandlerLevel("verbose")
    module.setLogHandlerLevel("trace")
    assertTrue(native.calls.isEmpty())
    main.drain()

    assertEquals(listOf("addLogListener(WARN)", "addLogListener(VERBOSE)"), native.calls)
  }

  @Test
  fun postsDisplayNotificationToTheMainThreadAndItsStore() {
    val main = mutableListOf<() -> Unit>()
    val module = module(runOnMain = { main += it })

    module.displayNotification("8d1e3d0a-1a1b-4c63-9d38-4c2b2b7e5f10")
    assertTrue(ShadowLog.getLogsForTag("SallaPush").isEmpty())
    main.drain()

    assertTrue(native.displayed.isEmpty())
    assertEquals(1, ShadowLog.getLogsForTag("SallaPush").count { it.type == Log.WARN })
  }

  /** Runs, in order, what the module posted to the main thread. */
  private fun MutableList<() -> Unit>.drain() {
    val posted = toList()
    clear()
    posted.forEach { it() }
  }

  // JavaOnlyMap.from(map) throws in React Native 0.87.1: it passes the map to the key-value constructor.
  private fun module(
    earlyInit: StaticConfig? = null,
    native: NativeSallaPush = this.native,
    once: OncePerProcess = this.once,
    runOnMain: (() -> Unit) -> Unit = { it() },
    toWritableMap: (Map<String, Any?>) -> WritableMap =
      { map -> JavaOnlyMap.of(*map.flatMap { (key, value) -> listOf(key, value) }.toTypedArray()) },
  ) = SallaPushReactNativeModule(
    reactContext = null,
    context = context,
    native = native,
    once = once,
    earlyInit = { earlyInit },
    toWritableMap = toWritableMap,
    runOnMain = runOnMain,
  )

  private fun resolved(call: (RecordingPromise) -> Unit): Any? {
    val promise = RecordingPromise()
    call(promise)
    assertTrue(promise.resolved)
    return promise.value
  }

  private fun errors(): List<String> = logs(Log.ERROR)

  private fun infos(): List<String> = logs(Log.INFO)

  private fun logs(type: Int): List<String> =
    ShadowLog.getLogsForTag("SallaPush").filter { it.type == type }.map { it.msg }
}
