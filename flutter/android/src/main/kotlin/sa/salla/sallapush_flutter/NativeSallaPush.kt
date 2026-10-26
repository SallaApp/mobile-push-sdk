package sa.salla.sallapush_flutter

import android.content.Context
import com.salla.push.SallaPush
import com.salla.push.SallaPushClickListener
import com.salla.push.SallaPushConfig
import com.salla.push.SallaPushForegroundLifecycleListener
import com.salla.push.SallaPushLogLevel
import com.salla.push.SallaPushLogListener
import com.salla.push.SallaPushLoginFailure
import com.salla.push.SallaPushPermissionObserver
import com.salla.push.SallaPushSubscriptionObserver
import com.salla.push.SallaPushUserChangedState
import com.salla.push.SallaPushUserObserver
import org.json.JSONObject

/** A native listener registration: [remove] removes the very object that was added, as SallaPush matches by equals. */
internal fun interface NativeRegistration {
    fun remove()
}

/** A foreground SallaPush notification about to be shown, as the registry gets it. */
internal class NativeWillDisplay(
    /** The notification's bridge form. */
    val message: NotificationMessage,
    /** Keeps the notification from being shown now; it counts only before the listener returns. */
    val preventDefault: () -> Unit,
    /** Shows the original notification later: its display window lives on that very object. */
    val display: () -> Unit,
)

/** The SallaPush Android calls the plugin makes; tests replace them. Listeners get their events in bridge form. */
internal interface NativeSallaPush {
    fun initWithContext(context: Context, appId: String, config: SallaPushConfig)

    val isInitialized: Boolean

    val appId: String?

    val sdkVersion: String

    fun setConsentRequired(required: Boolean)

    fun setConsentGiven(given: Boolean)

    fun login(externalId: String, identityToken: String)

    fun logout()

    val externalId: String?

    val isLoggedIn: Boolean

    fun addTag(key: String, value: String)

    fun addTags(tags: Map<String, String>)

    fun removeTag(key: String)

    fun removeTags(keys: List<String>)

    fun getTags(): Map<String, String>

    fun setLanguage(language: String?)

    val pushSubscriptionId: String?

    val pushSubscriptionToken: String?

    val pushSubscriptionOptedIn: Boolean

    fun optIn()

    fun optOut()

    fun addPushSubscriptionObserver(
        onChange: (previous: SubscriptionStateMessage, current: SubscriptionStateMessage) -> Unit,
    ): NativeRegistration

    fun addUserObserver(onChange: (UserChangedMessage) -> Unit): NativeRegistration

    fun addLoginFailureObserver(onFailure: (LoginFailureMessage) -> Unit): NativeRegistration

    val permission: Boolean

    fun canRequestPermission(): Boolean

    fun requestPermission(fallbackToSettings: Boolean, callback: (Boolean) -> Unit)

    fun refreshPermission()

    fun addPermissionObserver(onChange: (Boolean) -> Unit): NativeRegistration

    fun addClickListener(onClick: (ClickEventMessage) -> Unit): NativeRegistration

    fun addForegroundLifecycleListener(onWillDisplay: (NativeWillDisplay) -> Unit): NativeRegistration

    fun clearAllNotifications()

    fun removeNotification(androidNotificationId: Int)

    fun isSallaPushMessage(data: Map<String, String>): Boolean

    fun trackOpened(additionalData: JSONObject?): Boolean

    fun setDisplayCompatPayloads(display: Boolean)

    val logLevel: SallaPushLogLevel

    fun setLogLevel(level: SallaPushLogLevel)

    /** [onEntry] gets SallaPush's entries on SallaPush's log thread, not on the main thread. */
    fun addLogListener(level: SallaPushLogLevel, onEntry: (LogEntryMessage) -> Unit): NativeRegistration
}

internal object LiveNativeSallaPush : NativeSallaPush {
    override fun initWithContext(context: Context, appId: String, config: SallaPushConfig) {
        SallaPush.initWithContext(context, appId, config)
    }

    override val isInitialized: Boolean
        get() = SallaPush.isInitialized

    override val appId: String?
        get() = SallaPush.appId

    override val sdkVersion: String
        get() = SallaPush.sdkVersion

    override fun setConsentRequired(required: Boolean) {
        SallaPush.setConsentRequired(required)
    }

    override fun setConsentGiven(given: Boolean) {
        SallaPush.setConsentGiven(given)
    }

    override fun login(externalId: String, identityToken: String) {
        SallaPush.login(externalId, identityToken)
    }

    override fun logout() {
        SallaPush.logout()
    }

    override val externalId: String?
        get() = SallaPush.User.externalId

    override val isLoggedIn: Boolean
        get() = SallaPush.User.isLoggedIn

    override fun addTag(key: String, value: String) {
        SallaPush.User.addTag(key, value)
    }

    override fun addTags(tags: Map<String, String>) {
        SallaPush.User.addTags(tags)
    }

    override fun removeTag(key: String) {
        SallaPush.User.removeTag(key)
    }

    override fun removeTags(keys: List<String>) {
        SallaPush.User.removeTags(keys)
    }

    override fun getTags(): Map<String, String> = SallaPush.User.getTags()

    override fun setLanguage(language: String?) {
        SallaPush.User.setLanguage(language)
    }

    override val pushSubscriptionId: String?
        get() = SallaPush.User.pushSubscription.id

    override val pushSubscriptionToken: String?
        get() = SallaPush.User.pushSubscription.token

    override val pushSubscriptionOptedIn: Boolean
        get() = SallaPush.User.pushSubscription.optedIn

    override fun optIn() {
        SallaPush.User.pushSubscription.optIn()
    }

    override fun optOut() {
        SallaPush.User.pushSubscription.optOut()
    }

    override fun addPushSubscriptionObserver(
        onChange: (previous: SubscriptionStateMessage, current: SubscriptionStateMessage) -> Unit,
    ): NativeRegistration {
        val observer = SallaPushSubscriptionObserver { onChange(it.previous.toMessage(), it.current.toMessage()) }
        SallaPush.User.pushSubscription.addObserver(observer)
        return NativeRegistration { SallaPush.User.pushSubscription.removeObserver(observer) }
    }

    override fun addUserObserver(onChange: (UserChangedMessage) -> Unit): NativeRegistration {
        val observer = object : SallaPushUserObserver {
            override fun onUserStateChange(state: SallaPushUserChangedState) = onChange(state.toMessage())
        }
        SallaPush.User.addObserver(observer)
        return NativeRegistration { SallaPush.User.removeObserver(observer) }
    }

    override fun addLoginFailureObserver(onFailure: (LoginFailureMessage) -> Unit): NativeRegistration {
        val observer = object : SallaPushUserObserver {
            override fun onUserStateChange(state: SallaPushUserChangedState) = Unit

            override fun onLoginFailure(failure: SallaPushLoginFailure) = onFailure(failure.toMessage())
        }
        SallaPush.User.addObserver(observer)
        return NativeRegistration { SallaPush.User.removeObserver(observer) }
    }

    override val permission: Boolean
        get() = SallaPush.Notifications.permission

    override fun canRequestPermission(): Boolean = SallaPush.Notifications.canRequestPermission()

    override fun requestPermission(fallbackToSettings: Boolean, callback: (Boolean) -> Unit) {
        SallaPush.Notifications.requestPermission(fallbackToSettings) { callback(it) }
    }

    override fun refreshPermission() {
        SallaPush.Notifications.refreshPermission()
    }

    override fun addPermissionObserver(onChange: (Boolean) -> Unit): NativeRegistration {
        val observer = SallaPushPermissionObserver { onChange(it) }
        SallaPush.Notifications.addPermissionObserver(observer)
        return NativeRegistration { SallaPush.Notifications.removePermissionObserver(observer) }
    }

    override fun addClickListener(onClick: (ClickEventMessage) -> Unit): NativeRegistration {
        val listener = SallaPushClickListener { onClick(it.toMessage()) }
        SallaPush.Notifications.addClickListener(listener)
        return NativeRegistration { SallaPush.Notifications.removeClickListener(listener) }
    }

    override fun addForegroundLifecycleListener(onWillDisplay: (NativeWillDisplay) -> Unit): NativeRegistration {
        val listener = SallaPushForegroundLifecycleListener { onWillDisplay(it.toNative()) }
        SallaPush.Notifications.addForegroundLifecycleListener(listener)
        return NativeRegistration { SallaPush.Notifications.removeForegroundLifecycleListener(listener) }
    }

    override fun clearAllNotifications() {
        SallaPush.Notifications.clearAllNotifications()
    }

    override fun removeNotification(androidNotificationId: Int) {
        SallaPush.Notifications.removeNotification(androidNotificationId)
    }

    override fun isSallaPushMessage(data: Map<String, String>): Boolean =
        SallaPush.Notifications.isSallaPushMessage(data)

    override fun trackOpened(additionalData: JSONObject?): Boolean =
        SallaPush.Notifications.trackOpened(additionalData)

    override fun setDisplayCompatPayloads(display: Boolean) {
        SallaPush.Migration.setDisplayCompatPayloads(display)
    }

    override val logLevel: SallaPushLogLevel
        get() = SallaPush.Debug.logLevel

    override fun setLogLevel(level: SallaPushLogLevel) {
        SallaPush.Debug.logLevel = level
    }

    override fun addLogListener(level: SallaPushLogLevel, onEntry: (LogEntryMessage) -> Unit): NativeRegistration {
        val listener = SallaPushLogListener { onEntry(it.toMessage()) }
        SallaPush.Debug.addLogListener(listener, level)
        return NativeRegistration { SallaPush.Debug.removeLogListener(listener) }
    }
}
