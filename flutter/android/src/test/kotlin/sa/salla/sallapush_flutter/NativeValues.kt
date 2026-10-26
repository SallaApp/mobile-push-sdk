package sa.salla.sallapush_flutter

import com.salla.push.SallaPushClickEvent
import com.salla.push.SallaPushClickResult
import com.salla.push.SallaPushConfig
import com.salla.push.SallaPushLogEvent
import com.salla.push.SallaPushLogLevel
import com.salla.push.SallaPushNotification
import com.salla.push.SallaPushPayloadSource
import com.salla.push.SallaPushSubscriptionState
import com.salla.push.SallaPushUserChangedState
import com.salla.push.SallaPushUserState
import com.salla.push.SallaPushWillDisplayEvent

/**
 * Real SallaPush values. Their constructors are internal to Kotlin and public on the JVM, so tests build them as
 * SallaPush does, and the mapping reads them through SallaPush's own accessors.
 */
internal object NativeValues {
    /**
     * A configuration with nothing set: SallaPush's own defaults, which the tests read rather than assume. Only
     * SallaPushFlutterPluginTest.initializeKeepsTheSdkDefaultsForOptionsNotSet pins them, as the docs give them.
     */
    fun defaults(): SallaPushConfig = SallaPushConfig.Builder().build()

    fun notification(
        notificationId: String? = "msg_1",
        androidNotificationId: Int = 7,
        title: String? = null,
        subtitle: String? = null,
        body: String? = null,
        imageUrl: String? = null,
        launchUrl: String? = null,
        additionalData: Map<String, Any?> = emptyMap(),
        collapseId: String? = null,
        channelId: String? = null,
        sound: String? = null,
        source: SallaPushPayloadSource = SallaPushPayloadSource.NATIVE,
        rawPayload: Map<String, String> = emptyMap(),
    ): SallaPushNotification = construct(
        notificationId, androidNotificationId, title, subtitle, body, imageUrl, launchUrl, additionalData, collapseId,
        channelId, sound, source, rawPayload,
    )

    fun click(notification: SallaPushNotification, actionId: String?, url: String?): SallaPushClickEvent =
        construct(notification, construct<SallaPushClickResult>(actionId, url))

    fun willDisplay(notification: SallaPushNotification): SallaPushWillDisplayEvent = construct(notification)

    fun subscriptionState(id: String?, token: String?, optedIn: Boolean): SallaPushSubscriptionState =
        construct(id, token, optedIn)

    fun userChange(previous: SallaPushUserState, current: SallaPushUserState): SallaPushUserChangedState =
        construct(previous, current)

    fun userState(externalId: String?, isLoggedIn: Boolean): SallaPushUserState = construct(externalId, isLoggedIn)

    fun logEvent(
        level: SallaPushLogLevel,
        category: String,
        code: String,
        message: String,
        metadata: Map<String, String>,
        timestampMillis: Long,
    ): SallaPushLogEvent = construct(level, category, code, message, metadata, timestampMillis)

    private inline fun <reified T> construct(vararg arguments: Any?): T =
        T::class.java.constructors.single().newInstance(*arguments) as T
}
