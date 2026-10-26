package sa.salla.sallapush_flutter

import android.content.Context
import android.os.Bundle
import android.util.Log
import org.robolectric.Shadows.shadowOf
import org.robolectric.shadows.ShadowLog

/** Meta-data typed as AAPT types it: String, Integer (a number or a resource id), Boolean or Float. */
internal fun metaData(vararg entries: Pair<String, Any>): Bundle = Bundle().apply {
    for ((key, value) in entries) {
        when (value) {
            is String -> putString(key, value)
            is Int -> putInt(key, value)
            is Boolean -> putBoolean(key, value)
            is Float -> putFloat(key, value)
            else -> throw IllegalArgumentException("AAPT never produces a ${value.javaClass.simpleName}")
        }
    }
}

/** Makes [metaData] the app's manifest meta-data, as PackageManager returns it. */
internal fun installMetaData(context: Context, metaData: Bundle) {
    val packageInfo = shadowOf(context.packageManager).getInternalMutablePackageInfo(context.packageName)
    checkNotNull(packageInfo.applicationInfo).metaData = metaData
}

/** The plugin's Logcat lines at [level], without the [SallaPush] prefix. */
internal fun consoleLines(level: Int = Log.ERROR): List<String> =
    ShadowLog.getLogsForTag("SallaPush").filter { it.type == level }.map { it.msg.removePrefix("[SallaPush] ") }
