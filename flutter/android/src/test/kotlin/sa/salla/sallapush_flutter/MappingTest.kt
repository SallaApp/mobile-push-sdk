package sa.salla.sallapush_flutter

import com.salla.push.SallaPushLogLevel
import com.salla.push.SallaPushLoginFailure
import com.salla.push.SallaPushPayloadSource
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.math.BigDecimal
import java.math.BigInteger

/** The bridge form of real SallaPush values. */
class MappingTest {
    private val typedData: Map<String, Any?> = mapOf(
        "text" to "tea",
        "count" to "7",
        "padded" to " 12 ",
        "price" to "9.5",
        "flag" to "true",
        "off" to "0",
        "one" to 1,
        "big" to 9_007_199_254_740_993L,
        "ratio" to 2.5,
        "whole" to 3.0,
        "on" to true,
        "decimal" to BigDecimal("1.50"),
        "huge" to BigInteger("123456789012345678901234567890"),
        "nested" to mapOf("items" to listOf(1, "two", null)),
        "nothing" to null,
    )

    @Test
    fun aNotificationKeepsEveryField() {
        val notification = NativeValues.notification(
            notificationId = "msg_1",
            androidNotificationId = -1408375307,
            title = "Order shipped",
            subtitle = "Today",
            body = "Your order is on its way",
            imageUrl = "https://cdn.example.com/order.png",
            launchUrl = "https://store.example.com/orders/42",
            additionalData = mapOf("order_id" to "42"),
            collapseId = "orders",
            channelId = "updates",
            sound = "chime",
            source = SallaPushPayloadSource.COMPAT,
            rawPayload = mapOf("custom" to """{"i":"f6b1","a":{"push_ref":"msg_1"}}""", "title" to "Order shipped"),
        )

        assertEquals(
            NotificationMessage(
                notificationId = "msg_1",
                title = "Order shipped",
                subtitle = "Today",
                body = "Your order is on its way",
                imageUrl = "https://cdn.example.com/order.png",
                launchUrl = "https://store.example.com/orders/42",
                additionalData = mapOf("order_id" to "42"),
                rawPayload = mapOf("custom" to """{"i":"f6b1","a":{"push_ref":"msg_1"}}""", "title" to "Order shipped"),
                source = PayloadSourceMessage.COMPAT,
                stringValues = mapOf("order_id" to "42"),
                intValues = mapOf("order_id" to 42L),
                boolValues = emptyMap(),
                numberValues = emptyMap(),
                sound = "chime",
                androidNotificationId = -1408375307L,
                collapseId = "orders",
                channelId = "updates",
            ),
            notification.toMessage(),
        )
    }

    @Test
    fun theTypedValuesAreSallaPushsOwnAccessorResultsForEachKey() {
        val notification = NativeValues.notification(additionalData = typedData)

        val message = notification.toMessage()

        assertEquals(results { notification.getString(it) }, message.stringValues)
        assertEquals(results { notification.getLong(it) }, message.intValues)
        assertEquals(results { notification.getBoolean(it) }, message.boolValues)
        assertEquals(emptyMap<String, Any>(), message.numberValues)
        assertEquals("1", message.stringValues["one"])
        assertEquals("1.5", message.stringValues["decimal"])
        assertEquals(12L, message.intValues["padded"])
        assertEquals(3L, message.intValues["whole"])
        assertNull(message.intValues["price"])
        assertEquals(true, message.boolValues["one"])
        assertEquals(false, message.boolValues["off"])
        assertNull(message.stringValues["nested"])
    }

    @Test
    fun additionalDataReachesTheBridgeAsTheCodecCarriesIt() {
        assertEquals(
            mapOf(
                "text" to "tea",
                "one" to 1,
                "big" to 9_007_199_254_740_993L,
                "ratio" to 2.5,
                "on" to true,
                "decimal" to "1.50",
                "huge" to "123456789012345678901234567890",
                "nested" to mapOf("items" to listOf(1, "two", null), "7" to "seven"),
                "nothing" to null,
                "other" to "other value",
            ),
            mapOf(
                "text" to "tea",
                "one" to 1,
                "big" to 9_007_199_254_740_993L,
                "ratio" to 2.5,
                "on" to true,
                "decimal" to BigDecimal("1.50"),
                "huge" to BigInteger("123456789012345678901234567890"),
                "nested" to mapOf("items" to listOf(1, "two", null), 7 to "seven"),
                "nothing" to null,
                "other" to object {
                    override fun toString() = "other value"
                },
            ).toBridgeValues(),
        )
    }

    @Test
    fun theBridgeFormGoesThroughTheEventChannelCodec() {
        val notification = NativeValues.notification(additionalData = typedData, rawPayload = mapOf("sp_v" to "1"))
        val click = NativeValues.click(notification, null, "https://store.example.com/orders/42").toMessage()

        val buffer = MessagesPigeonMethodCodec.encodeSuccessEnvelope(click).also { it.flip() }

        assertEquals(click, MessagesPigeonMethodCodec.decodeEnvelope(buffer))
    }

    @Test
    fun aTapKeepsItsNotificationActionAndUrl() {
        val notification = NativeValues.notification(notificationId = "msg_2")

        assertEquals(
            ClickEventMessage(notification.toMessage(), null, "https://store.example.com/orders/42"),
            NativeValues.click(notification, null, "https://store.example.com/orders/42").toMessage(),
        )
        assertEquals(
            ClickEventMessage(notification.toMessage(), "track", null),
            NativeValues.click(notification, "track", null).toMessage(),
        )
    }

    @Test
    fun aForegroundNotificationKeepsItsOriginalForDisplay() {
        val notification = NativeValues.notification(additionalData = typedData)
        val event = NativeValues.willDisplay(notification)

        val willDisplay = event.toNative()

        assertEquals(notification.toMessage(), willDisplay.message)
        assertEquals(notification::display, willDisplay.display)
        assertFalse(event.isPrevented)
        willDisplay.preventDefault()
        assertTrue(event.isPrevented)
    }

    @Test
    fun subscriptionAndUserStatesKeepEveryField() {
        assertEquals(
            SubscriptionStateMessage("device-1", "ab12cd34", true),
            NativeValues.subscriptionState("device-1", "ab12cd34", true).toMessage(),
        )
        assertEquals(
            SubscriptionStateMessage(null, null, false),
            NativeValues.subscriptionState(null, null, false).toMessage(),
        )
        assertEquals(
            UserChangedMessage(UserStateMessage(null, false), UserStateMessage("42", true)),
            NativeValues.userChange(NativeValues.userState(null, false), NativeValues.userState("42", true))
                .toMessage(),
        )
    }

    @Test
    fun aLogEntryKeepsEveryField() {
        assertEquals(
            LogEntryMessage(
                LogLevelMessage.WARN,
                "network",
                "net.retry_exhausted",
                "The push service could not be reached; SallaPush retries later.",
                mapOf("http_status" to "503", "attempt" to "5"),
                1_791_842_518_123L,
            ),
            NativeValues.logEvent(
                SallaPushLogLevel.WARN,
                "network",
                "net.retry_exhausted",
                "The push service could not be reached; SallaPush retries later.",
                mapOf("http_status" to "503", "attempt" to "5"),
                1_791_842_518_123L,
            ).toMessage(),
        )
        assertEquals(
            LogLevelMessage.entries,
            SallaPushLogLevel.entries.map {
                NativeValues.logEvent(it, "lifecycle", "init.started", "Started.", emptyMap(), 0L).toMessage().level
            },
        )
    }

    @Test
    fun enumsMapByCase() {
        assertEquals(
            listOf(PayloadSourceMessage.NATIVE, PayloadSourceMessage.COMPAT),
            SallaPushPayloadSource.entries.map { it.toMessage() },
        )
        assertEquals(
            listOf(LoginFailureMessage.TOKEN_REJECTED, LoginFailureMessage.INVALID_REQUEST),
            SallaPushLoginFailure.entries.map { it.toMessage() },
        )
    }

    /** The non-null results of [read] for each key of the typed data. */
    private fun <T : Any> results(read: (String) -> T?): Map<String, T> =
        typedData.keys.mapNotNull { key -> read(key)?.let { key to it } }.toMap()
}
