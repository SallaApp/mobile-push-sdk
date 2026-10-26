package sa.salla.sallapush_flutter

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger

/** The bridge from Dart: each host method is one call into SallaPush, and each event stream a native listener. */
class SallaPushFlutterPlugin internal constructor(
    private val native: NativeSallaPush,
    private val earlyInit: () -> StaticConfig?,
    private val platformOnly: PlatformOnlyCalls,
) : FlutterPlugin, SallaPushHostApi {

    constructor() : this(LiveNativeSallaPush, { SallaPushInitProvider.earlyInit }, PlatformOnlyCalls.process)

    private lateinit var applicationContext: Context
    private val displays = DisplayStore()
    private val events = EventRegistry(native, displays)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        attach(binding.applicationContext, binding.binaryMessenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        detach(binding.binaryMessenger)
    }

    internal fun attach(context: Context, messenger: BinaryMessenger) {
        applicationContext = context
        SallaPushHostApi.setUp(messenger, this)
        ClickEventsStreamHandler.register(messenger, ClickEvents(events))
        WillDisplayEventsStreamHandler.register(messenger, WillDisplayEvents(events))
        PermissionChangesStreamHandler.register(messenger, PermissionChanges(events))
        UserChangesStreamHandler.register(messenger, UserChanges(events))
        LoginFailuresStreamHandler.register(messenger, LoginFailures(events))
        PushSubscriptionChangesStreamHandler.register(messenger, PushSubscriptionChanges(events))
        LogEntriesStreamHandler.register(messenger, LogEntries(events))
    }

    /** Removes every native listener, the held notifications, the host API and the event streams. */
    internal fun detach(messenger: BinaryMessenger) {
        events.stopAll()
        displays.clear()
        SallaPushHostApi.setUp(messenger, null)
        for (channel in EVENT_CHANNELS) messenger.setMessageHandler(channel, null)
    }

    override fun initialize(appId: String, config: ConfigMessage) {
        val early = earlyInit()
        if (early != null && early.appId == appId) reportOptionsIgnoredBy(config)
        native.initWithContext(applicationContext, appId, config.toSallaPushConfig())
    }

    override fun isInitialized(): Boolean = native.isInitialized

    override fun appId(): String? = native.appId

    override fun sdkVersion(): String = native.sdkVersion

    override fun setConsentRequired(required: Boolean) {
        val early = earlyInit()
        if (required && early != null && early.requiresUserConsent != true) {
            Console.error(
                "setConsentRequired(true) came after SallaPush started at launch without requiring consent, so this " +
                    "device may already have registered and sent data. To require consent from the start, set the " +
                    "meta-data ${StaticConfig.REQUIRES_USER_CONSENT} to true.",
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

    override fun externalId(): String? = native.externalId

    override fun isLoggedIn(): Boolean = native.isLoggedIn

    override fun addTag(key: String, value: String) {
        native.addTag(key, value)
    }

    override fun addTags(tags: Map<String, String>) {
        native.addTags(tags)
    }

    override fun removeTag(key: String) {
        native.removeTag(key)
    }

    override fun removeTags(keys: List<String>) {
        native.removeTags(keys)
    }

    override fun getTags(): Map<String, String> = native.getTags()

    override fun setLanguage(language: String?) {
        native.setLanguage(language)
    }

    override fun pushSubscriptionId(): String? = native.pushSubscriptionId

    override fun pushSubscriptionToken(): String? = native.pushSubscriptionToken

    override fun pushSubscriptionOptedIn(): Boolean = native.pushSubscriptionOptedIn

    override fun optIn() {
        native.optIn()
    }

    override fun optOut() {
        native.optOut()
    }

    override fun addPushSubscriptionListener(listenerId: Long) {
        events.addSubscriptionListener(listenerId)
    }

    override fun removePushSubscriptionListener(listenerId: Long) {
        events.removeSubscriptionListener(listenerId)
    }

    override fun permission(): Boolean = native.permission

    override fun canRequestPermission(): Boolean = native.canRequestPermission()

    override fun permissionStatus(): IosPermissionStatusMessage? {
        reportIosOnly("notifications.permissionStatus", "returns null")
        return null
    }

    override fun requestPermission(fallbackToSettings: Boolean, callback: (Result<Boolean>) -> Unit) {
        native.requestPermission(fallbackToSettings) { callback(Result.success(it)) }
    }

    override fun registerForProvisionalAuthorization(callback: (Result<Boolean>) -> Unit) {
        reportIosOnly("notifications.registerForProvisionalAuthorization", "returns false")
        callback(Result.success(false))
    }

    override fun refreshPermission() {
        native.refreshPermission()
    }

    override fun registerForRemoteNotifications() {
        reportIosOnly("notifications.registerForRemoteNotifications", "does nothing")
    }

    override fun forwardApnsToken(apnsToken: String) {
        reportIosOnly("notifications.forwardApnsToken", "does nothing")
    }

    override fun clearAll() {
        native.clearAllNotifications()
    }

    override fun removeNotification(androidNotificationId: Long) {
        if (androidNotificationId !in Int.MIN_VALUE..Int.MAX_VALUE) {
            Console.error(
                "SallaPush.notifications.removeNotification ignored $androidNotificationId: Android notification ids " +
                    "are 32-bit integers.",
            )
            return
        }
        native.removeNotification(androidNotificationId.toInt())
    }

    override fun isSallaPushNotification(payload: Map<String, Any?>): Boolean =
        native.isSallaPushMessage(payload.toFcmData())

    override fun trackOpened(additionalData: Map<String, Any?>?): Boolean =
        native.trackOpened(additionalData?.toJsonObject())

    override fun displayNotification(handle: String) {
        if (!displays.display(handle)) {
            Console.info(
                "display() did nothing: a notification from onWillDisplay can be shown once, within 10 minutes of " +
                    "its event.",
            )
        }
    }

    override fun setDisplayCompatPayloads(display: Boolean) {
        native.setDisplayCompatPayloads(display)
    }

    override fun logLevel(): LogLevelMessage = native.logLevel.toMessage()

    override fun setLogLevel(level: LogLevelMessage) {
        native.setLogLevel(level.toNative())
    }

    override fun setLogHandlerLevel(level: LogLevelMessage) {
        events.setLogLevel(level.toNative())
    }

    private fun reportIosOnly(member: String, outcome: String) {
        if (platformOnly.isFirst(member)) Console.info("SallaPush.$member works on iOS only; on Android it $outcome.")
    }

    /** SallaPush ignores every option of an initialization with the app id it already runs with. */
    private fun reportOptionsIgnoredBy(config: ConfigMessage) {
        val ignored = listOfNotNull(
            config.logLevel?.let { "logLevel (com.salla.push.LOG_LEVEL)" },
            config.appVersion?.let { "appVersion (${StaticConfig.APP_VERSION})" },
            config.clearTagsOnLogout?.let { "clearTagsOnLogout (${StaticConfig.CLEAR_TAGS_ON_LOGOUT})" },
            config.requiresUserConsent?.let { "requiresUserConsent (${StaticConfig.REQUIRES_USER_CONSENT})" },
            config.openLaunchUrls?.let { "openLaunchUrls (${StaticConfig.OPEN_LAUNCH_URLS})" },
            config.autoClearBadge?.let { "autoClearBadge (${StaticConfig.AUTO_CLEAR_BADGE})" },
            config.autoUpdateBadge?.let { "autoUpdateBadge (${StaticConfig.AUTO_UPDATE_BADGE})" },
        )
        if (ignored.isEmpty()) return
        Console.error(
            "SallaPush already started at launch with this app id, so initialize ignored its options. Set each with " +
                "its manifest meta-data instead: ${ignored.joinToString(", ")}.",
        )
    }

    private companion object {
        val EVENT_CHANNELS = listOf(
            "clickEvents", "willDisplayEvents", "permissionChanges", "userChanges", "loginFailures",
            "pushSubscriptionChanges", "logEntries",
        ).map { "dev.flutter.pigeon.mobile_push.SallaPushEventChannelApi.$it" }
    }
}

// Each Dart event stream: Dart's first listen registers the native listener, and its last cancel, which a hot restart's
// first listen also sends, removes it.

private class ClickEvents(private val events: EventRegistry) : ClickEventsStreamHandler() {
    override fun onListen(p0: Any?, sink: PigeonEventSink<ClickEventMessage>) {
        events.clickSink = sink
        events.start(EventKind.CLICK)
    }

    override fun onCancel(p0: Any?) {
        events.stop(EventKind.CLICK)
        events.clickSink = null
    }
}

private class WillDisplayEvents(private val events: EventRegistry) : WillDisplayEventsStreamHandler() {
    override fun onListen(p0: Any?, sink: PigeonEventSink<WillDisplayEventMessage>) {
        events.willDisplaySink = sink
        events.start(EventKind.WILL_DISPLAY)
    }

    override fun onCancel(p0: Any?) {
        events.stop(EventKind.WILL_DISPLAY)
        events.willDisplaySink = null
    }
}

private class PermissionChanges(private val events: EventRegistry) : PermissionChangesStreamHandler() {
    override fun onListen(p0: Any?, sink: PigeonEventSink<PermissionChangeMessage>) {
        events.permissionSink = sink
        events.start(EventKind.PERMISSION)
    }

    override fun onCancel(p0: Any?) {
        events.stop(EventKind.PERMISSION)
        events.permissionSink = null
    }
}

private class UserChanges(private val events: EventRegistry) : UserChangesStreamHandler() {
    override fun onListen(p0: Any?, sink: PigeonEventSink<UserChangedMessage>) {
        events.userSink = sink
        events.start(EventKind.USER)
    }

    override fun onCancel(p0: Any?) {
        events.stop(EventKind.USER)
        events.userSink = null
    }
}

private class LoginFailures(private val events: EventRegistry) : LoginFailuresStreamHandler() {
    override fun onListen(p0: Any?, sink: PigeonEventSink<LoginFailureEventMessage>) {
        events.loginFailureSink = sink
        events.start(EventKind.LOGIN_FAILURE)
    }

    override fun onCancel(p0: Any?) {
        events.stop(EventKind.LOGIN_FAILURE)
        events.loginFailureSink = null
    }
}

/** The native observers are added per Dart listener, by addPushSubscriptionListener. */
private class PushSubscriptionChanges(private val events: EventRegistry) : PushSubscriptionChangesStreamHandler() {
    override fun onListen(p0: Any?, sink: PigeonEventSink<SubscriptionChangedMessage>) {
        events.pushSubscriptionSink = sink
    }

    override fun onCancel(p0: Any?) {
        events.removeSubscriptionListeners()
        events.pushSubscriptionSink = null
    }
}

/** The native log listener is registered at the level setLogHandlerLevel set before Dart listens. */
private class LogEntries(private val events: EventRegistry) : LogEntriesStreamHandler() {
    override fun onListen(p0: Any?, sink: PigeonEventSink<LogEntryMessage>) {
        events.logSink = sink
        events.start(EventKind.LOG)
    }

    override fun onCancel(p0: Any?) {
        events.stop(EventKind.LOG)
        events.logSink = null
    }
}
