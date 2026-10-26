package sa.salla.sallapush_flutter

import com.salla.push.SallaPushLogLevel
import io.flutter.plugin.common.EventChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class EventRegistryTest {
    private val native = FakeNativeSallaPush()
    private val displays = DisplayStore { 0L }
    private val registry = EventRegistry(native, displays)

    @Test
    fun startRegistersEachKindOnceAndStopRemovesThatRegistration() {
        for (kind in EventKind.entries) {
            registry.start(kind)
            registry.start(kind)
        }

        assertEquals(1, native.clickListeners.size)
        assertEquals(1, native.foregroundListeners.size)
        assertEquals(1, native.permissionObservers.size)
        assertEquals(1, native.userObservers.size)
        assertEquals(1, native.loginFailureObservers.size)
        assertEquals(1, native.logListeners.size)

        registry.stop(EventKind.CLICK)
        registry.stop(EventKind.CLICK)

        assertTrue(native.clickListeners.single().isRemoved)
        assertEquals(5, native.liveRegistrations.size)

        registry.start(EventKind.CLICK)

        assertEquals(listOf(true, false), native.clickListeners.map { it.isRemoved })
    }

    @Test
    fun eachKindSendsWhatSallaPushReportsToItsSink() {
        val sinks = RecordingSinks(registry)
        EventKind.entries.forEach(registry::start)
        val click = ClickEventMessage(notification(), url = "https://store.example.com/orders/42")
        val change = UserChangedMessage(UserStateMessage(isLoggedIn = false), UserStateMessage("42", true))

        native.clickListeners.single().handler(click)
        native.permissionObservers.single().handler(true)
        native.userObservers.single().handler(change)
        native.loginFailureObservers.single().handler(LoginFailureMessage.INVALID_REQUEST)
        native.loginFailureObservers.single().handler(LoginFailureMessage.TOKEN_REJECTED)

        assertEquals(listOf(click), sinks.clicks.events)
        assertEquals(listOf(PermissionChangeMessage(true)), sinks.permissions.events)
        assertEquals(listOf(change), sinks.users.events)
        assertEquals(
            listOf(
                LoginFailureEventMessage(LoginFailureMessage.INVALID_REQUEST),
                LoginFailureEventMessage(LoginFailureMessage.TOKEN_REJECTED),
            ),
            sinks.loginFailures.events,
        )
    }

    @Test
    fun aForegroundNotificationIsHeldAndOfferedToDartUnderANewHandle() {
        val sinks = RecordingSinks(registry)
        registry.start(EventKind.WILL_DISPLAY)
        val first = FakeWillDisplay("msg_1")
        val second = FakeWillDisplay("msg_2")

        native.foregroundListeners.single().handler(first.event)
        native.foregroundListeners.single().handler(second.event)

        assertTrue(first.isPrevented)
        assertTrue(second.isPrevented)
        val events = sinks.willDisplays.events.map { it as WillDisplayEventMessage }
        assertEquals(listOf(first.message, second.message), events.map { it.notification })
        assertEquals(2, events.map { it.handle }.toSet().size)

        assertTrue(displays.display(events[1].handle))

        assertEquals(0, first.displays)
        assertEquals(1, second.displays)
    }

    @Test
    fun withoutADartStreamSallaPushShowsTheNotificationItself() {
        registry.start(EventKind.WILL_DISPLAY)
        val notification = FakeWillDisplay()

        native.foregroundListeners.single().handler(notification.event)

        assertFalse(notification.isPrevented)
    }

    @Test
    fun theLogListenerRegistersAtTheLevelSetBeforeIt() {
        registry.setLogLevel(SallaPushLogLevel.DEBUG)

        assertEquals(0, native.logListeners.size)

        registry.start(EventKind.LOG)

        assertEquals(listOf(SallaPushLogLevel.DEBUG), native.logListenerLevels)
    }

    @Test
    fun aNewLogLevelReRegistersAtOnceWhileDartListens() {
        registry.start(EventKind.LOG)

        registry.setLogLevel(SallaPushLogLevel.VERBOSE)

        assertEquals(listOf(SallaPushLogLevel.WARN, SallaPushLogLevel.VERBOSE), native.logListenerLevels)
        assertEquals(listOf(true, false), native.logListeners.map { it.isRemoved })

        registry.setLogLevel(SallaPushLogLevel.VERBOSE)

        assertEquals(listOf(SallaPushLogLevel.WARN, SallaPushLogLevel.VERBOSE), native.logListenerLevels)

        registry.stop(EventKind.LOG)
        registry.setLogLevel(SallaPushLogLevel.ERROR)

        assertEquals(listOf(SallaPushLogLevel.WARN, SallaPushLogLevel.VERBOSE), native.logListenerLevels)
    }

    @Test
    fun logEntriesReachTheSinkLaterOnTheMainThread() {
        val posted = mutableListOf<() -> Unit>()
        val registry = EventRegistry(native, displays) { posted += it }
        val sinks = RecordingSinks(registry)
        registry.start(EventKind.LOG)

        native.logListeners.single().handler(logEntry())

        assertEquals(emptyList<Any?>(), sinks.logs.events)
        assertEquals(1, posted.size)

        posted.forEach { it() }

        assertEquals(listOf(logEntry()), sinks.logs.events)
    }

    @Test
    fun eachPushSubscriptionListenerHasItsOwnObserver() {
        val sinks = RecordingSinks(registry)
        registry.addSubscriptionListener(1)
        registry.addSubscriptionListener(2)
        registry.addSubscriptionListener(1)

        assertEquals(2, native.subscriptionObservers.size)

        val previous = SubscriptionStateMessage(optedIn = false)
        val current = SubscriptionStateMessage("device-1", "ab12cd34", true)
        native.subscriptionObservers[1].handler(previous, current)
        native.subscriptionObservers[0].handler(current, current)

        assertEquals(
            listOf(SubscriptionChangedMessage(2, previous, current), SubscriptionChangedMessage(1, current, current)),
            sinks.subscriptions.events,
        )

        registry.removeSubscriptionListener(1)
        registry.removeSubscriptionListener(1)

        assertEquals(listOf(true, false), native.subscriptionObservers.map { it.isRemoved })

        registry.removeSubscriptionListeners()

        assertEquals(listOf(true, true), native.subscriptionObservers.map { it.isRemoved })

        registry.addSubscriptionListener(1)

        assertEquals(3, native.subscriptionObservers.size)
        assertFalse(native.subscriptionObservers[2].isRemoved)
    }

    @Test
    fun stopAllRemovesEveryRegistrationAndForgetsTheSinks() {
        val sinks = RecordingSinks(registry)
        EventKind.entries.forEach(registry::start)
        registry.addSubscriptionListener(1)
        registry.addSubscriptionListener(2)

        registry.stopAll()

        assertEquals(emptyList<Any>(), native.liveRegistrations)
        assertNull(registry.clickSink)
        assertNull(registry.willDisplaySink)
        assertNull(registry.permissionSink)
        assertNull(registry.userSink)
        assertNull(registry.loginFailureSink)
        assertNull(registry.pushSubscriptionSink)
        assertNull(registry.logSink)

        // A callback SallaPush had already posted reaches no sink.
        native.clickListeners.single().handler(ClickEventMessage(notification()))
        val state = SubscriptionStateMessage(optedIn = true)
        native.subscriptionObservers.first().handler(state, state)
        assertEquals(emptyList<Any>(), sinks.clicks.events)
        assertEquals(emptyList<Any>(), sinks.subscriptions.events)
    }

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

/** An event channel's sink, faked: keeps the events sent to Dart. */
internal class RecordingEventSink : EventChannel.EventSink {
    val events = mutableListOf<Any?>()

    override fun success(event: Any?) {
        events.add(event)
    }

    override fun error(errorCode: String?, errorMessage: String?, errorDetails: Any?) {
        events.add("error $errorCode")
    }

    override fun endOfStream() {
        events.add("end of stream")
    }
}

/** Sinks set on a registry that keep the messages that reach them. */
private class RecordingSinks(registry: EventRegistry) {
    val clicks = RecordingEventSink()
    val willDisplays = RecordingEventSink()
    val permissions = RecordingEventSink()
    val users = RecordingEventSink()
    val loginFailures = RecordingEventSink()
    val subscriptions = RecordingEventSink()
    val logs = RecordingEventSink()

    init {
        registry.clickSink = PigeonEventSink(clicks)
        registry.willDisplaySink = PigeonEventSink(willDisplays)
        registry.permissionSink = PigeonEventSink(permissions)
        registry.userSink = PigeonEventSink(users)
        registry.loginFailureSink = PigeonEventSink(loginFailures)
        registry.pushSubscriptionSink = PigeonEventSink(subscriptions)
        registry.logSink = PigeonEventSink(logs)
    }
}
