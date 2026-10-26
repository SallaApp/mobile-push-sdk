package sa.salla.sallapush_flutter

import android.util.Log

/** The plugin's own Logcat lines: tag SallaPush, as the SDK's, and prefixed [SallaPush]. */
internal object Console {
    private const val TAG = "SallaPush"

    fun info(message: String) {
        Log.i(TAG, "[SallaPush] $message")
    }

    fun error(message: String) {
        Log.e(TAG, "[SallaPush] $message")
    }
}

/** Calls to members that work on the other platform only, each reported once per process. */
internal class PlatformOnlyCalls {
    private val reported = HashSet<String>()

    /** True the first time [member] is passed in this process. */
    @Synchronized
    fun isFirst(member: String): Boolean = reported.add(member)

    companion object {
        val process = PlatformOnlyCalls()
    }
}
