package sa.salla.sallapush_flutter

import com.salla.push.SallaPushClickEvent
import com.salla.push.SallaPushConfig
import com.salla.push.SallaPushLogEvent
import com.salla.push.SallaPushLogLevel
import com.salla.push.SallaPushLoginFailure
import com.salla.push.SallaPushNotification
import com.salla.push.SallaPushPayloadSource
import com.salla.push.SallaPushSubscriptionState
import com.salla.push.SallaPushUserChangedState
import com.salla.push.SallaPushUserState
import com.salla.push.SallaPushWillDisplayEvent
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal

/** The SallaPush configuration of these options; the ones not set keep SallaPush's defaults. iOS options are ignored. */
internal fun ConfigMessage.toSallaPushConfig(): SallaPushConfig {
    val builder = SallaPushConfig.Builder()
    logLevel?.let { builder.setLogLevel(it.toNative()) }
    appVersion?.let { builder.setAppVersion(it) }
    clearTagsOnLogout?.let { builder.setClearTagsOnLogout(it) }
    requiresUserConsent?.let { builder.setRequiresUserConsent(it) }
    openLaunchUrls?.let { builder.setOpenLaunchUrls(it) }
    autoClearBadge?.let { builder.setAutoClearBadge(it) }
    autoUpdateBadge?.let { builder.setAutoUpdateBadge(it) }
    return builder.build()
}

internal fun LogLevelMessage.toNative(): SallaPushLogLevel = when (this) {
    LogLevelMessage.OFF -> SallaPushLogLevel.OFF
    LogLevelMessage.ERROR -> SallaPushLogLevel.ERROR
    LogLevelMessage.WARN -> SallaPushLogLevel.WARN
    LogLevelMessage.INFO -> SallaPushLogLevel.INFO
    LogLevelMessage.DEBUG -> SallaPushLogLevel.DEBUG
    LogLevelMessage.VERBOSE -> SallaPushLogLevel.VERBOSE
}

internal fun SallaPushLogLevel.toMessage(): LogLevelMessage = when (this) {
    SallaPushLogLevel.OFF -> LogLevelMessage.OFF
    SallaPushLogLevel.ERROR -> LogLevelMessage.ERROR
    SallaPushLogLevel.WARN -> LogLevelMessage.WARN
    SallaPushLogLevel.INFO -> LogLevelMessage.INFO
    SallaPushLogLevel.DEBUG -> LogLevelMessage.DEBUG
    SallaPushLogLevel.VERBOSE -> LogLevelMessage.VERBOSE
}

/**
 * The bridge form: every field, additionalData as the codec carries it, and for each top-level additionalData key the
 * non-null results of SallaPush's own typed accessors.
 */
internal fun SallaPushNotification.toMessage(): NotificationMessage = NotificationMessage(
    notificationId = notificationId,
    title = title,
    subtitle = subtitle,
    body = body,
    imageUrl = imageUrl,
    launchUrl = launchUrl,
    additionalData = additionalData.toBridgeValues(),
    rawPayload = rawPayload,
    source = source.toMessage(),
    stringValues = typedValues(additionalData.keys, this::getString),
    intValues = typedValues(additionalData.keys, this::getLong),
    boolValues = typedValues(additionalData.keys, this::getBoolean),
    numberValues = emptyMap(),
    sound = sound,
    androidNotificationId = androidNotificationId.toLong(),
    collapseId = collapseId,
    channelId = channelId,
)

internal fun SallaPushClickEvent.toMessage() =
    ClickEventMessage(notification = notification.toMessage(), actionId = result.actionId, url = result.url)

internal fun SallaPushWillDisplayEvent.toNative() = NativeWillDisplay(
    message = notification.toMessage(),
    preventDefault = this::preventDefault,
    display = notification::display,
)

internal fun SallaPushSubscriptionState.toMessage() =
    SubscriptionStateMessage(id = id, token = token, optedIn = optedIn)

internal fun SallaPushUserState.toMessage() = UserStateMessage(externalId = externalId, isLoggedIn = isLoggedIn)

internal fun SallaPushUserChangedState.toMessage() =
    UserChangedMessage(previous = previous.toMessage(), current = current.toMessage())

internal fun SallaPushLogEvent.toMessage() = LogEntryMessage(
    level = level.toMessage(),
    category = category,
    code = code,
    message = message,
    metadata = metadata,
    timestampMillis = timestampMillis,
)

internal fun SallaPushPayloadSource.toMessage(): PayloadSourceMessage = when (this) {
    SallaPushPayloadSource.NATIVE -> PayloadSourceMessage.NATIVE
    SallaPushPayloadSource.COMPAT -> PayloadSourceMessage.COMPAT
}

internal fun SallaPushLoginFailure.toMessage(): LoginFailureMessage = when (this) {
    SallaPushLoginFailure.TOKEN_REJECTED -> LoginFailureMessage.TOKEN_REJECTED
    SallaPushLoginFailure.INVALID_REQUEST -> LoginFailureMessage.INVALID_REQUEST
}

/** The non-null results of [read] for each of [keys]. */
internal fun <T : Any> typedValues(keys: Set<String>, read: (String) -> T?): Map<String, T> {
    val values = LinkedHashMap<String, T>()
    for (key in keys) read(key)?.let { values[key] = it }
    return values
}

/**
 * JSON values as the Flutter codec carries them: nested maps keyed by text, and BigDecimal and BigInteger, which it
 * can't carry, as their decimal text.
 */
internal fun Map<String, Any?>.toBridgeValues(): Map<String, Any?> = mapValues { (_, value) -> bridgeValue(value) }

private fun bridgeValue(value: Any?): Any? = when (value) {
    null, is String, is Boolean, is Int, is Long, is Short, is Byte, is Double, is Float -> value
    is BigDecimal -> value.toPlainString()
    is Map<*, *> -> value.entries.associate { (key, item) -> key.toString() to bridgeValue(item) }
    is List<*> -> value.map(::bridgeValue)
    else -> value.toString()
}

/** The payload as an FCM data map: text kept, maps and lists as JSON text, other values as their text, nulls dropped. */
internal fun Map<String, Any?>.toFcmData(): Map<String, String> {
    val data = LinkedHashMap<String, String>()
    for ((key, value) in this) {
        data[key] = when (value) {
            null -> continue
            is String -> value
            is Map<*, *>, is List<*> -> jsonValue(value).toString()
            else -> value.toString()
        }
    }
    return data
}

/** The map as JSON; nested maps and lists too, any key as its text. */
internal fun Map<*, *>.toJsonObject(): JSONObject = JSONObject().also { json ->
    for ((key, value) in this) json.put(key.toString(), jsonValue(value))
}

private fun jsonValue(value: Any?): Any = when (value) {
    null -> JSONObject.NULL
    is Map<*, *> -> value.toJsonObject()
    is List<*> -> JSONArray().also { json -> value.forEach { json.put(jsonValue(it)) } }
    else -> value
}
