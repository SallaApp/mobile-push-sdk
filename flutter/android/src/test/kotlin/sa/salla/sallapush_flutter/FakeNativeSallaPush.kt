package sa.salla.sallapush_flutter

import android.content.Context
import com.salla.push.SallaPushConfig
import com.salla.push.SallaPushLogLevel
import org.json.JSONObject

/** Records the SallaPush calls the plugin makes, in order, and answers with the scripted values. */
internal class FakeNativeSallaPush : NativeSallaPush {
    /** A listener SallaPush keeps until its registration is removed. */
    class Registration<H>(val handler: H) : NativeRegistration {
        var isRemoved = false
            private set

        override fun remove() {
            isRemoved = true
        }
    }
    sealed interface Call {
        data class InitWithContext(val context: Context, val appId: String, val config: SallaPushConfig) : Call

        data class SetConsentRequired(val required: Boolean) : Call

        data class SetConsentGiven(val given: Boolean) : Call

        data class Login(val externalId: String, val identityToken: String) : Call

        data object Logout : Call

        data class AddTag(val key: String, val value: String) : Call

        data class AddTags(val tags: Map<String, String>) : Call

        data class RemoveTag(val key: String) : Call

        data class RemoveTags(val keys: List<String>) : Call

        data class SetLanguage(val language: String?) : Call

        data object OptIn : Call

        data object OptOut : Call

        data class RequestPermission(val fallbackToSettings: Boolean) : Call

        data object RefreshPermission : Call

        data object ClearAllNotifications : Call

        data class RemoveNotification(val androidNotificationId: Int) : Call

        data class IsSallaPushMessage(val data: Map<String, String>) : Call

        /** The JSON text: JSONObject has no value equality. */
        data class TrackOpened(val additionalData: String?) : Call

        data class SetDisplayCompatPayloads(val display: Boolean) : Call

        data class SetLogLevel(val level: SallaPushLogLevel) : Call
    }

    val calls = mutableListOf<Call>()

    override var isInitialized = false

    override var appId: String? = null

    override var sdkVersion = "1.0.2"

    override var externalId: String? = null

    override var isLoggedIn = false

    var savedTags = emptyMap<String, String>()

    override var pushSubscriptionId: String? = null

    override var pushSubscriptionToken: String? = null

    override var pushSubscriptionOptedIn = false

    override var permission = false

    var canRequest = false

    var isSallaPushMessageAnswer = false

    var trackOpenedAnswer = false

    var currentLogLevel = SallaPushLogLevel.WARN

    override val logLevel: SallaPushLogLevel
        get() = currentLogLevel

    private val permissionAnswers = mutableListOf<(Boolean) -> Unit>()

    val clickListeners = mutableListOf<Registration<(ClickEventMessage) -> Unit>>()

    val foregroundListeners = mutableListOf<Registration<(NativeWillDisplay) -> Unit>>()

    val logListeners = mutableListOf<Registration<(LogEntryMessage) -> Unit>>()

    /** The level of each log listener, in the order of [logListeners]. */
    val logListenerLevels = mutableListOf<SallaPushLogLevel>()

    val permissionObservers = mutableListOf<Registration<(Boolean) -> Unit>>()

    val userObservers = mutableListOf<Registration<(UserChangedMessage) -> Unit>>()

    val loginFailureObservers = mutableListOf<Registration<(LoginFailureMessage) -> Unit>>()

    val subscriptionObservers =
        mutableListOf<Registration<(SubscriptionStateMessage, SubscriptionStateMessage) -> Unit>>()

    /** Every listener registration that is not removed. */
    val liveRegistrations: List<Registration<*>>
        get() = listOf(
            clickListeners, foregroundListeners, permissionObservers, userObservers, loginFailureObservers,
            subscriptionObservers, logListeners,
        ).flatten().filterNot { it.isRemoved }

    override fun initWithContext(context: Context, appId: String, config: SallaPushConfig) {
        calls += Call.InitWithContext(context, appId, config)
    }

    override fun setConsentRequired(required: Boolean) {
        calls += Call.SetConsentRequired(required)
    }

    override fun setConsentGiven(given: Boolean) {
        calls += Call.SetConsentGiven(given)
    }

    override fun login(externalId: String, identityToken: String) {
        calls += Call.Login(externalId, identityToken)
    }

    override fun logout() {
        calls += Call.Logout
    }

    override fun addTag(key: String, value: String) {
        calls += Call.AddTag(key, value)
    }

    override fun addTags(tags: Map<String, String>) {
        calls += Call.AddTags(tags)
    }

    override fun removeTag(key: String) {
        calls += Call.RemoveTag(key)
    }

    override fun removeTags(keys: List<String>) {
        calls += Call.RemoveTags(keys)
    }

    override fun getTags(): Map<String, String> = savedTags

    override fun setLanguage(language: String?) {
        calls += Call.SetLanguage(language)
    }

    override fun optIn() {
        calls += Call.OptIn
    }

    override fun optOut() {
        calls += Call.OptOut
    }

    override fun addPushSubscriptionObserver(
        onChange: (previous: SubscriptionStateMessage, current: SubscriptionStateMessage) -> Unit,
    ) = Registration(onChange).also { subscriptionObservers += it }

    override fun addUserObserver(onChange: (UserChangedMessage) -> Unit) =
        Registration(onChange).also { userObservers += it }

    override fun addLoginFailureObserver(onFailure: (LoginFailureMessage) -> Unit) =
        Registration(onFailure).also { loginFailureObservers += it }

    override fun addPermissionObserver(onChange: (Boolean) -> Unit) =
        Registration(onChange).also { permissionObservers += it }

    override fun addClickListener(onClick: (ClickEventMessage) -> Unit) =
        Registration(onClick).also { clickListeners += it }

    override fun addForegroundLifecycleListener(onWillDisplay: (NativeWillDisplay) -> Unit) =
        Registration(onWillDisplay).also { foregroundListeners += it }

    override fun canRequestPermission(): Boolean = canRequest

    override fun requestPermission(fallbackToSettings: Boolean, callback: (Boolean) -> Unit) {
        calls += Call.RequestPermission(fallbackToSettings)
        permissionAnswers += callback
    }

    /** Answers the pending permission requests, as SallaPush does when the user has answered. */
    fun answerPermissionRequests(granted: Boolean) {
        val answers = permissionAnswers.toList()
        permissionAnswers.clear()
        answers.forEach { it(granted) }
    }

    override fun refreshPermission() {
        calls += Call.RefreshPermission
    }

    override fun clearAllNotifications() {
        calls += Call.ClearAllNotifications
    }

    override fun removeNotification(androidNotificationId: Int) {
        calls += Call.RemoveNotification(androidNotificationId)
    }

    override fun isSallaPushMessage(data: Map<String, String>): Boolean {
        calls += Call.IsSallaPushMessage(data)
        return isSallaPushMessageAnswer
    }

    override fun trackOpened(additionalData: JSONObject?): Boolean {
        calls += Call.TrackOpened(additionalData?.toString())
        return trackOpenedAnswer
    }

    override fun setDisplayCompatPayloads(display: Boolean) {
        calls += Call.SetDisplayCompatPayloads(display)
    }

    override fun setLogLevel(level: SallaPushLogLevel) {
        calls += Call.SetLogLevel(level)
    }

    override fun addLogListener(level: SallaPushLogLevel, onEntry: (LogEntryMessage) -> Unit): Registration<*> {
        logListenerLevels += level
        return Registration(onEntry).also { logListeners += it }
    }
}

/** A foreground notification SallaPush offers, faked: records whether it was prevented and how often it was shown. */
internal class FakeWillDisplay(notificationId: String = "msg_1") {
    val message = NotificationMessage(
        notificationId = notificationId,
        additionalData = emptyMap(),
        rawPayload = emptyMap(),
        source = PayloadSourceMessage.NATIVE,
        stringValues = emptyMap(),
        intValues = emptyMap(),
        boolValues = emptyMap(),
        numberValues = emptyMap(),
    )
    var isPrevented = false
        private set
    var displays = 0
        private set

    val event = NativeWillDisplay(message, { isPrevented = true }, { displays += 1 })
}

internal fun logEntry(code: String = "register.ok") = LogEntryMessage(
    level = LogLevelMessage.INFO,
    category = "registration",
    code = code,
    message = "The device is registered.",
    metadata = emptyMap(),
    timestampMillis = 1_791_842_518_123L,
)
