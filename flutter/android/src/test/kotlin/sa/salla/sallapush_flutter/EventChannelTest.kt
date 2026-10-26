package sa.salla.sallapush_flutter

import android.content.Context
import android.os.Looper
import android.util.Log
import androidx.test.core.app.ApplicationProvider
import com.salla.push.SallaPushLogLevel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.shadows.ShadowLog

/** The plugin's event streams: Dart's listen and cancel on each channel start and stop the native listeners. */
@RunWith(RobolectricTestRunner::class)
class EventChannelTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val native = FakeNativeSallaPush()
    private val messenger = FakeBinaryMessenger()
    private val plugin = SallaPushFlutterPlugin(native, { null }, PlatformOnlyCalls())

    private val streams =
        listOf("clickEvents", "willDisplayEvents", "permissionChanges", "userChanges", "loginFailures", "logEntries")

    @Before
    fun attachToTheEngine() {
        ShadowLog.reset()
        plugin.attach(context, messenger)
    }

    @Test
    fun eachStreamRegistersItsNativeListenerOnListenAndRemovesItOnCancel() {
        for (stream in streams) {
            assertEquals(stream, emptyList<Boolean>(), removed(stream))

            messenger.streamCall("listen", stream)

            assertEquals(stream, listOf(false), removed(stream))

            messenger.streamCall("cancel", stream)

            assertEquals(stream, listOf(true), removed(stream))
        }
    }

    @Test
    fun theListenOfAHotRestartReplacesTheNativeListener() {
        messenger.streamCall("listen", "clickEvents")
        messenger.streamCall("listen", "clickEvents")

        assertEquals(listOf(true, false), removed("clickEvents"))
    }

    @Test
    fun whatSallaPushReportsReachesDartOnItsStream() {
        streams.forEach { messenger.streamCall("listen", it) }
        val click = ClickEventMessage(notification(), url = "https://store.example.com/orders/42")
        val change = UserChangedMessage(UserStateMessage("42", true), UserStateMessage(isLoggedIn = false))

        native.clickListeners.single().handler(click)
        native.permissionObservers.single().handler(false)
        native.userObservers.single().handler(change)
        native.loginFailureObservers.single().handler(LoginFailureMessage.TOKEN_REJECTED)

        assertEquals(listOf(click), messenger.events("clickEvents"))
        assertEquals(listOf(PermissionChangeMessage(false)), messenger.events("permissionChanges"))
        assertEquals(listOf(change), messenger.events("userChanges"))
        assertEquals(
            listOf(LoginFailureEventMessage(LoginFailureMessage.TOKEN_REJECTED)),
            messenger.events("loginFailures"),
        )
    }

    @Test
    fun aForegroundNotificationIsOfferedToDartWhichShowsItWithItsHandle() {
        messenger.streamCall("listen", "willDisplayEvents")
        val notification = FakeWillDisplay()

        native.foregroundListeners.single().handler(notification.event)

        assertTrue(notification.isPrevented)
        val event = messenger.events("willDisplayEvents").single() as WillDisplayEventMessage
        assertEquals(notification.message, event.notification)

        assertEquals(listOf(null), messenger.callHostApi("displayNotification", listOf(event.handle)))

        assertEquals(1, notification.displays)
        assertEquals(emptyList<String>(), consoleLines(Log.INFO))
    }

    @Test
    fun showingANotificationTwiceOrUnknownSaysSoOnTheConsole() {
        messenger.streamCall("listen", "willDisplayEvents")
        val notification = FakeWillDisplay()
        native.foregroundListeners.single().handler(notification.event)
        val event = messenger.events("willDisplayEvents").single() as WillDisplayEventMessage

        messenger.callHostApi("displayNotification", listOf(event.handle))
        messenger.callHostApi("displayNotification", listOf(event.handle))
        messenger.callHostApi("displayNotification", listOf("unknown"))

        assertEquals(1, notification.displays)
        assertEquals(
            List(2) {
                "display() did nothing: a notification from onWillDisplay can be shown once, within 10 minutes of " +
                    "its event."
            },
            consoleLines(Log.INFO),
        )
    }

    @Test
    fun logsRegisterAtTheLevelDartSetFirstAndReachDartFromTheMainThread() {
        messenger.callHostApi("setLogHandlerLevel", listOf(LogLevelMessage.DEBUG))
        messenger.streamCall("listen", "logEntries")

        assertEquals(listOf(SallaPushLogLevel.DEBUG), native.logListenerLevels)

        native.logListeners.single().handler(logEntry())

        assertEquals(emptyList<Any?>(), messenger.events("logEntries"))

        shadowOf(Looper.getMainLooper()).idle()

        assertEquals(listOf(logEntry()), messenger.events("logEntries"))

        messenger.callHostApi("setLogHandlerLevel", listOf(LogLevelMessage.ERROR))

        assertEquals(listOf(SallaPushLogLevel.DEBUG, SallaPushLogLevel.ERROR), native.logListenerLevels)
        assertEquals(listOf(true, false), removed("logEntries"))

        messenger.streamCall("cancel", "logEntries")

        assertEquals(listOf(true, true), removed("logEntries"))
    }

    @Test
    fun aCallbackAfterDartCancelledReachesNoStream() {
        messenger.streamCall("listen", "clickEvents")
        val handler = native.clickListeners.single().handler

        messenger.streamCall("cancel", "clickEvents")
        handler(ClickEventMessage(notification()))

        assertEquals(emptyList<Any?>(), messenger.events("clickEvents"))
    }

    @Test
    fun eachDartSubscriptionListenerAddsAndRemovesItsOwnObserver() {
        messenger.streamCall("listen", "pushSubscriptionChanges")

        assertEquals(emptyList<Boolean>(), removed("pushSubscriptionChanges"))

        assertEquals(listOf(null), messenger.callHostApi("addPushSubscriptionListener", listOf(1L)))
        assertEquals(listOf(null), messenger.callHostApi("addPushSubscriptionListener", listOf(2L)))
        val state = SubscriptionStateMessage("device-1", "ab12cd34", true)
        native.subscriptionObservers[1].handler(state, state)

        assertEquals(listOf(false, false), removed("pushSubscriptionChanges"))
        assertEquals(listOf(SubscriptionChangedMessage(2, state, state)), messenger.events("pushSubscriptionChanges"))

        messenger.callHostApi("removePushSubscriptionListener", listOf(1L))

        assertEquals(listOf(true, false), removed("pushSubscriptionChanges"))

        messenger.streamCall("cancel", "pushSubscriptionChanges")

        assertEquals(listOf(true, true), removed("pushSubscriptionChanges"))
    }

    @Test
    fun detachingFromTheEngineStopsEveryNativeListenerAndForgetsTheHeldNotifications() {
        (streams + "pushSubscriptionChanges").forEach { messenger.streamCall("listen", it) }
        messenger.callHostApi("addPushSubscriptionListener", listOf(1L))
        val notification = FakeWillDisplay()
        native.foregroundListeners.single().handler(notification.event)
        val event = messenger.events("willDisplayEvents").single() as WillDisplayEventMessage

        plugin.detach(messenger)

        assertEquals(emptyList<Any>(), native.liveRegistrations)
        assertEquals(emptySet<String>(), messenger.handlers.keys)
        plugin.displayNotification(event.handle)
        assertEquals(0, notification.displays)
    }

    /** Whether each native registration behind [stream] was removed, oldest first. */
    private fun removed(stream: String): List<Boolean> = when (stream) {
        "clickEvents" -> native.clickListeners
        "willDisplayEvents" -> native.foregroundListeners
        "permissionChanges" -> native.permissionObservers
        "userChanges" -> native.userObservers
        "loginFailures" -> native.loginFailureObservers
        "logEntries" -> native.logListeners
        else -> native.subscriptionObservers
    }.map { it.isRemoved }

    private fun notification() = NotificationMessage(
        notificationId = "msg_1",
        additionalData = emptyMap(),
        rawPayload = emptyMap(),
        source = PayloadSourceMessage.NATIVE,
        stringValues = emptyMap(),
        intValues = emptyMap(),
        boolValues = emptyMap(),
        numberValues = emptyMap(),
    )
}
