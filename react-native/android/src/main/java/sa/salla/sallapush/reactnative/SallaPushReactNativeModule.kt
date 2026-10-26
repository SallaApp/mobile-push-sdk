package sa.salla.sallapush.reactnative

import android.content.Context
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.UiThreadUtil
import com.facebook.react.bridge.WritableMap
import com.salla.push.SallaPushConfig

/**
 * The TurboModule. React Native calls it on its native-modules thread, in call order, and SallaPush is thread-safe, so
 * every call goes straight to native. The event registrations are confined to the main thread, where native calls
 * back, so those calls are posted there, in call order too.
 */
class SallaPushReactNativeModule internal constructor(
  reactContext: ReactApplicationContext?,
  private val context: Context,
  private val native: NativeSallaPush,
  private val once: OncePerProcess,
  private val earlyInit: () -> StaticConfig?,
  private val toWritableMap: (Map<String, Any?>) -> WritableMap,
  private val runOnMain: (() -> Unit) -> Unit,
) : NativeRNSallaPushSpec(reactContext) {

  constructor(reactContext: ReactApplicationContext) : this(
    reactContext,
    reactContext.applicationContext,
    LiveNativeSallaPush,
    OncePerProcess.shared,
    { EarlyInit.config },
    { Arguments.makeNativeMap(it) },
    { block -> UiThreadUtil.runOnUiThread { block() } },
  )

  // Set by invalidate(), on React Native's thread, before the runtime is destroyed.
  @Volatile private var invalidated = false

  private val displays = DisplayStore(native)
  private val events = EventRegistry(native, displays, runOnMain, { !invalidated }, ::emit)

  override fun initWithAppId(appId: String, config: ReadableMap) {
    val options = InitOptions(config)
    if (earlyInit()?.appId == appId) {
      reportIgnoredOptions(options.startOptions)
    }
    native.initWithContext(context, appId, options.toSallaPushConfig())
  }

  override fun isInitialized(promise: Promise) = promise.resolveWith { native.isInitialized }

  override fun getAppId(promise: Promise) = promise.resolveWith { native.appId }

  override fun getSdkVersion(promise: Promise) = promise.resolveWith { native.sdkVersion }

  override fun setConsentRequired(required: Boolean) {
    val earlyInit = earlyInit()
    if (required && earlyInit != null && earlyInit.requiresUserConsent != true) {
      val key = StaticConfig.REQUIRES_USER_CONSENT
      Console.error(
        "setConsentRequired(true) came after SallaPush started from ${StaticConfig.APP_ID} without $key, so the " +
          "device may already have registered and sent data. Set $key to true in the manifest to require consent " +
          "from the start."
      )
    }
    native.setConsentRequired(required)
  }

  override fun setConsentGiven(given: Boolean) {
    native.setConsentGiven(given)
  }

  override fun login(externalId: String, identityToken: String) {
    native.login(externalId, identityToken)
  }

  override fun logout() {
    native.logout()
  }

  override fun getExternalId(promise: Promise) = promise.resolveWith { native.externalId }

  override fun isLoggedIn(promise: Promise) = promise.resolveWith { native.isLoggedIn }

  override fun addTag(key: String, value: String) {
    native.addTag(key, value)
  }

  // The entries from JavaScript go to native unchecked: native skips and logs the ones that aren't strings.
  @Suppress("UNCHECKED_CAST")
  override fun addTags(tags: ReadableMap) {
    native.addTags(tags.toHashMap() as Map<String, String>)
  }

  override fun removeTag(key: String) {
    native.removeTag(key)
  }

  @Suppress("UNCHECKED_CAST")
  override fun removeTags(keys: ReadableArray) {
    native.removeTags(keys.toArrayList() as Collection<String>)
  }

  override fun getTags(promise: Promise) = promise.resolveWith { toWritableMap(native.tags) }

  override fun setLanguage(language: String?) {
    native.setLanguage(language)
  }

  override fun getPushSubscriptionId(promise: Promise) = promise.resolveWith { native.pushSubscriptionId }

  override fun getPushSubscriptionToken(promise: Promise) = promise.resolveWith { native.pushSubscriptionToken }

  override fun getPushSubscriptionOptedIn(promise: Promise) = promise.resolveWith { native.pushSubscriptionOptedIn }

  override fun optIn() {
    native.optIn()
  }

  override fun optOut() {
    native.optOut()
  }

  override fun addPushSubscriptionListener(listenerId: Double) = runOnMain {
    events.addSubscriptionListener(listenerId.toInt())
  }

  override fun removePushSubscriptionListener(listenerId: Double) = runOnMain {
    events.removeSubscriptionListener(listenerId.toInt())
  }

  override fun getPermission(promise: Promise) = promise.resolveWith { native.permission }

  override fun canRequestPermission(promise: Promise) = promise.resolveWith { native.canRequestPermission() }

  override fun getPermissionStatus(promise: Promise) {
    once.info("Notifications.getPermissionStatus is iOS only and resolves null on Android.")
    promise.resolve(null)
  }

  override fun requestPermission(fallbackToSettings: Boolean, promise: Promise) {
    native.requestPermission(fallbackToSettings) { promise.resolve(it) }
  }

  override fun registerForProvisionalAuthorization(promise: Promise) {
    once.info("Notifications.registerForProvisionalAuthorization is iOS only and resolves false on Android.")
    promise.resolve(false)
  }

  override fun refreshPermission() {
    native.refreshPermission()
  }

  override fun registerForRemoteNotifications() {
    once.info("Notifications.registerForRemoteNotifications is iOS only and does nothing on Android.")
  }

  override fun forwardApnsToken(apnsToken: String) {
    once.info("Notifications.forwardApnsToken is iOS only and does nothing on Android.")
  }

  override fun clearAll() {
    native.clearAllNotifications()
  }

  override fun removeNotification(androidNotificationId: Double) {
    native.removeNotification(androidNotificationId.toInt())
  }

  override fun isSallaPushNotification(payload: ReadableMap, promise: Promise) =
    promise.resolveWith { native.isSallaPushMessage(Conversions.messageData(payload.toHashMap())) }

  override fun trackOpened(additionalData: ReadableMap?, promise: Promise) =
    promise.resolveWith { native.trackOpened(Conversions.jsonObject(additionalData?.toHashMap())) }

  /** Shows a foreground notification held for JavaScript: it wasn't prevented there, or the app calls display(). */
  override fun displayNotification(handle: String) = runOnMain { displays.display(handle) }

  override fun setDisplayCompatPayloads(display: Boolean) {
    native.setDisplayCompatPayloads(display)
  }

  override fun getLogLevel(promise: Promise) = promise.resolveWith { native.logLevel.jsName }

  override fun setLogLevel(level: String) {
    logLevelNamed(level)?.let { native.logLevel = it }
  }

  /** The level of JavaScript's log handler; a name that isn't a level is ignored. */
  override fun setLogHandlerLevel(level: String) {
    val known = logLevelNamed(level) ?: return
    runOnMain { events.setLogLevel(known) }
  }

  override fun startEvents(kind: String) = runOnMain { events.start(kind) }

  override fun stopEvents(kind: String) = runOnMain { events.stop(kind) }

  /**
   * React Native calls it when the JavaScript runtime goes away, then destroys the runtime without waiting for the main
   * thread. So from now on nothing is emitted, and native shows foreground notifications itself, also for callbacks
   * already queued there; then every native registration is removed, and the held notifications are forgotten.
   */
  override fun invalidate() {
    invalidated = true
    runOnMain {
      events.stopAll()
      displays.clear()
    }
    super.invalidate()
  }

  private fun emit(event: Event, body: Map<String, Any?>) {
    if (invalidated) return
    val value = toWritableMap(body)
    when (event) {
      Event.CLICK -> emitOnClick(value)
      Event.WILL_DISPLAY -> emitOnWillDisplay(value)
      Event.PERMISSION_CHANGE -> emitOnPermissionChange(value)
      Event.USER_CHANGE -> emitOnUserChange(value)
      Event.LOGIN_FAILURE -> emitOnLoginFailure(value)
      Event.PUSH_SUBSCRIPTION_CHANGE -> emitOnPushSubscriptionChange(value)
      Event.LOG -> emitOnLog(value)
    }
  }

  /** A second init with the static app id changes nothing natively, its options included. */
  private fun reportIgnoredOptions(options: List<Pair<String, String>>) {
    if (options.isEmpty()) return
    val names = options.joinToString(", ") { it.first }
    val keys = options.joinToString(", ") { it.second }
    Console.error(
      "initialize ignored $names: SallaPush already started with this app id from ${StaticConfig.APP_ID}, so the " +
        "call changes nothing. Set them with the meta-data $keys instead."
    )
  }

  companion object {
    const val NAME = NativeRNSallaPushSpec.NAME
  }
}

/**
 * The options of a JavaScript initialize call that apply on Android; null means the option was left out. The ios
 * options don't apply here.
 */
private class InitOptions(config: ReadableMap) {
  val logLevel = config.stringOrNull("logLevel")?.let(::logLevelNamed)
  val appVersion = config.stringOrNull("appVersion")
  val clearTagsOnLogout = config.booleanOrNull("clearTagsOnLogout")
  val requiresUserConsent = config.booleanOrNull("requiresUserConsent")
  val openLaunchUrls = config.booleanOrNull("openLaunchUrls")
  val autoClearBadge = config.booleanOrNull("autoClearBadge")
  val autoUpdateBadge = config.booleanOrNull("autoUpdateBadge")

  /** The given options that only the first init applies, each with the meta-data that sets it at launch. */
  val startOptions: List<Pair<String, String>>
    get() = listOfNotNull(
      logLevel?.let { "logLevel" to "com.salla.push.LOG_LEVEL" },
      appVersion?.let { "appVersion" to StaticConfig.APP_VERSION },
      clearTagsOnLogout?.let { "clearTagsOnLogout" to StaticConfig.CLEAR_TAGS_ON_LOGOUT },
      requiresUserConsent?.let { "requiresUserConsent" to StaticConfig.REQUIRES_USER_CONSENT },
      openLaunchUrls?.let { "openLaunchUrls" to StaticConfig.OPEN_LAUNCH_URLS },
      autoClearBadge?.let { "autoClearBadge" to StaticConfig.AUTO_CLEAR_BADGE },
      autoUpdateBadge?.let { "autoUpdateBadge" to StaticConfig.AUTO_UPDATE_BADGE },
    )

  /** The native configuration with the options that were given, and native's defaults for the others. */
  fun toSallaPushConfig(): SallaPushConfig {
    val builder = SallaPushConfig.Builder()
    logLevel?.let { builder.setLogLevel(it) }
    appVersion?.let { builder.setAppVersion(it) }
    clearTagsOnLogout?.let { builder.setClearTagsOnLogout(it) }
    requiresUserConsent?.let { builder.setRequiresUserConsent(it) }
    openLaunchUrls?.let { builder.setOpenLaunchUrls(it) }
    autoClearBadge?.let { builder.setAutoClearBadge(it) }
    autoUpdateBadge?.let { builder.setAutoUpdateBadge(it) }
    return builder.build()
  }
}

private const val INTERNAL_ERROR = "E_SALLAPUSH_INTERNAL"

/** Resolves with [value]; a bridge failure, which native never causes, rejects with E_SALLAPUSH_INTERNAL. */
private inline fun Promise.resolveWith(value: () -> Any?) {
  try {
    resolve(value())
  } catch (e: Exception) {
    reject(INTERNAL_ERROR, e)
  }
}

private fun ReadableMap.stringOrNull(key: String): String? =
  if (hasKey(key) && !isNull(key)) getString(key) else null

private fun ReadableMap.booleanOrNull(key: String): Boolean? =
  if (hasKey(key) && !isNull(key)) getBoolean(key) else null
