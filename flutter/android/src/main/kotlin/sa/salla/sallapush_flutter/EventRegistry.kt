package sa.salla.sallapush_flutter

import android.os.Handler
import android.os.Looper
import com.salla.push.SallaPushLogLevel
import java.util.EnumMap

/** The events that have one native registration each, made while Dart listens to their stream. */
internal enum class EventKind { CLICK, WILL_DISPLAY, PERMISSION, USER, LOGIN_FAILURE, LOG }

private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

/** Runs [block] on the main thread, later. */
private fun postToMainLooper(block: () -> Unit) {
    mainHandler.post(block)
}

/**
 * The native listeners behind the Dart event streams, and the sinks of those streams while Dart listens.
 *
 * A kind has one native registration while Dart listens to it, so taps made before that stay queued natively, and
 * foreground notifications are held for Dart's decision only while Dart listens for them. Each Dart push-subscription
 * listener has its own native observer, so it gets SallaPush's own replay. Main thread only.
 */
internal class EventRegistry(
    private val native: NativeSallaPush,
    private val displays: DisplayStore,
    private val postToMain: (() -> Unit) -> Unit = ::postToMainLooper,
) {
    var clickSink: PigeonEventSink<ClickEventMessage>? = null
    var willDisplaySink: PigeonEventSink<WillDisplayEventMessage>? = null
    var permissionSink: PigeonEventSink<PermissionChangeMessage>? = null
    var userSink: PigeonEventSink<UserChangedMessage>? = null
    var loginFailureSink: PigeonEventSink<LoginFailureEventMessage>? = null
    var pushSubscriptionSink: PigeonEventSink<SubscriptionChangedMessage>? = null
    var logSink: PigeonEventSink<LogEntryMessage>? = null

    private val registrations = EnumMap<EventKind, NativeRegistration>(EventKind::class.java)
    private val subscriptionObservers = HashMap<Long, NativeRegistration>()
    private var logLevel = SallaPushLogLevel.WARN

    /** Registers the native listener of [kind], unless it is registered. */
    fun start(kind: EventKind) {
        if (kind !in registrations) registrations[kind] = register(kind)
    }

    /** Removes the native listener of [kind], if any. */
    fun stop(kind: EventKind) {
        registrations.remove(kind)?.remove()
    }

    /** Sets the level of the native log listener: for its next registration, and at once while Dart listens to logs. */
    fun setLogLevel(level: SallaPushLogLevel) {
        if (level == logLevel) return
        logLevel = level
        val previous = registrations[EventKind.LOG] ?: return
        registrations[EventKind.LOG] = register(EventKind.LOG)
        previous.remove()
    }

    /** Adds the native observer of the Dart push-subscription listener [id], unless it exists. */
    fun addSubscriptionListener(id: Long) {
        if (id in subscriptionObservers) return
        subscriptionObservers[id] = native.addPushSubscriptionObserver { previous, current ->
            pushSubscriptionSink?.success(SubscriptionChangedMessage(id, previous, current))
        }
    }

    /** Removes the native observer of the Dart push-subscription listener [id], if any. */
    fun removeSubscriptionListener(id: Long) {
        subscriptionObservers.remove(id)?.remove()
    }

    /** Removes the native observer of every Dart push-subscription listener. */
    fun removeSubscriptionListeners() {
        val observers = subscriptionObservers.values.toList()
        subscriptionObservers.clear()
        observers.forEach { it.remove() }
    }

    /** Removes every native registration and forgets the sinks: the engine is going away. */
    fun stopAll() {
        EventKind.entries.forEach(::stop)
        removeSubscriptionListeners()
        clickSink = null
        willDisplaySink = null
        permissionSink = null
        userSink = null
        loginFailureSink = null
        pushSubscriptionSink = null
        logSink = null
    }

    private fun register(kind: EventKind): NativeRegistration = when (kind) {
        EventKind.CLICK -> native.addClickListener { clickSink?.success(it) }
        // SallaPush decides when this returns: the notification is held here, and Dart shows it unless it prevents it.
        EventKind.WILL_DISPLAY -> native.addForegroundLifecycleListener { event ->
            val sink = willDisplaySink ?: return@addForegroundLifecycleListener
            event.preventDefault()
            sink.success(WillDisplayEventMessage(displays.put(event.display), event.message))
        }
        EventKind.PERMISSION -> native.addPermissionObserver { permissionSink?.success(PermissionChangeMessage(it)) }
        EventKind.USER -> native.addUserObserver { userSink?.success(it) }
        EventKind.LOGIN_FAILURE -> native.addLoginFailureObserver {
            loginFailureSink?.success(LoginFailureEventMessage(it))
        }
        // SallaPush logs on its own thread, and Flutter takes events on the main thread only.
        EventKind.LOG -> native.addLogListener(logLevel) { entry -> postToMain { logSink?.success(entry) } }
    }
}
