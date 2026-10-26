package sa.salla.sallapush_flutter

import android.os.SystemClock
import java.util.UUID

/**
 * The foreground notifications that Dart may still show, each under a random handle, because SallaPush shows only the
 * very notification it offered. Main thread only.
 */
internal class DisplayStore(private val now: () -> Long = SystemClock::elapsedRealtime) {
    private class Entry(val display: () -> Unit, val createdAtMillis: Long)

    private val entries = LinkedHashMap<String, Entry>()

    /** Keeps [display], which shows the original notification, and returns its new handle. */
    fun put(display: () -> Unit): String {
        removeExpired()
        val handle = UUID.randomUUID().toString()
        entries[handle] = Entry(display, now())
        if (entries.size > CAPACITY) entries.remove(entries.keys.first())
        return handle
    }

    /** Shows the notification held under [handle] and forgets it; false for an unknown or expired handle. */
    fun display(handle: String): Boolean {
        removeExpired()
        val entry = entries.remove(handle) ?: return false
        entry.display()
        return true
    }

    fun clear() {
        entries.clear()
    }

    private fun removeExpired() {
        val now = now()
        entries.values.removeAll { now - it.createdAtMillis > LIFETIME_MILLIS }
    }

    companion object {
        /** SallaPush's own display window. */
        const val LIFETIME_MILLIS = 600_000L

        /** Bounds this store's memory only: SallaPush keeps the display window on each notification, with no count. */
        const val CAPACITY = 500
    }
}
