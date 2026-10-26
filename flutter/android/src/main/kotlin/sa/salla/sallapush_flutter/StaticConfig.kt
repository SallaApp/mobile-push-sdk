package sa.salla.sallapush_flutter

import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Resources
import android.os.Build
import android.os.Bundle
import com.salla.push.SallaPushConfig
import java.util.Locale

/** The plugin's own manifest meta-data; the SDK reads its other keys (log level, icon, channel) itself. */
internal data class StaticConfig(
    val appId: String? = null,
    val openLaunchUrls: Boolean? = null,
    val requiresUserConsent: Boolean? = null,
    val clearTagsOnLogout: Boolean? = null,
    val appVersion: String? = null,
    val autoClearBadge: Boolean? = null,
    val autoUpdateBadge: Boolean? = null,
    val displayCompatPayloads: Boolean? = null,
) {
    fun sallaPushConfig(): SallaPushConfig {
        val builder = SallaPushConfig.Builder()
        openLaunchUrls?.let { builder.setOpenLaunchUrls(it) }
        requiresUserConsent?.let { builder.setRequiresUserConsent(it) }
        clearTagsOnLogout?.let { builder.setClearTagsOnLogout(it) }
        appVersion?.let { builder.setAppVersion(it) }
        autoClearBadge?.let { builder.setAutoClearBadge(it) }
        autoUpdateBadge?.let { builder.setAutoUpdateBadge(it) }
        return builder.build()
    }

    companion object {
        const val APP_ID = "com.salla.push.APP_ID"
        const val OPEN_LAUNCH_URLS = "com.salla.push.OPEN_LAUNCH_URLS"
        const val REQUIRES_USER_CONSENT = "com.salla.push.REQUIRES_USER_CONSENT"
        const val CLEAR_TAGS_ON_LOGOUT = "com.salla.push.CLEAR_TAGS_ON_LOGOUT"
        const val APP_VERSION = "com.salla.push.APP_VERSION"
        const val AUTO_CLEAR_BADGE = "com.salla.push.AUTO_CLEAR_BADGE"
        const val AUTO_UPDATE_BADGE = "com.salla.push.AUTO_UPDATE_BADGE"
        const val DISPLAY_COMPAT_PAYLOADS = "com.salla.push.DISPLAY_COMPAT_PAYLOADS"

        /** Never throws: it runs at process start, before the app's own code. */
        fun read(context: Context): StaticConfig =
            try {
                from(context, metaData(context) ?: Bundle.EMPTY)
            } catch (e: Exception) {
                Console.error("The app's manifest meta-data can't be read ($e); SallaPush doesn't start at launch.")
                StaticConfig()
            }

        fun from(context: Context, metaData: Bundle): StaticConfig {
            val reader = MetaDataReader(context, metaData)
            return StaticConfig(
                appId = reader.text(APP_ID),
                openLaunchUrls = reader.boolean(OPEN_LAUNCH_URLS),
                requiresUserConsent = reader.boolean(REQUIRES_USER_CONSENT),
                clearTagsOnLogout = reader.boolean(CLEAR_TAGS_ON_LOGOUT),
                appVersion = reader.text(APP_VERSION),
                autoClearBadge = reader.boolean(AUTO_CLEAR_BADGE),
                autoUpdateBadge = reader.boolean(AUTO_UPDATE_BADGE),
                displayCompatPayloads = reader.boolean(DISPLAY_COMPAT_PAYLOADS),
            )
        }

        private fun metaData(context: Context): Bundle? {
            val manager = context.packageManager
            val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                manager.getApplicationInfo(
                    context.packageName,
                    PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong()),
                )
            } else {
                @Suppress("DEPRECATION")
                manager.getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
            }
            return info.metaData
        }
    }
}

/** AAPT types "12345" as an Integer, "true" as a Boolean, "12345678901" as a Float and @string/x as its Integer id. */
private class MetaDataReader(private val context: Context, private val metaData: Bundle) {

    @Suppress("DEPRECATION")
    fun text(key: String): String? {
        val text = when (val value = metaData.get(key)) {
            null -> return null
            is String -> value
            is Int -> try {
                context.getString(value)
            } catch (e: Resources.NotFoundException) {
                value.toString()
            }
            is Boolean -> value.toString()
            else -> {
                Console.error(
                    "Manifest meta-data $key is a ${value.javaClass.simpleName}, which can't be read exactly; " +
                        "put the value in a string resource and reference it with android:resource. It is ignored.",
                )
                return null
            }
        }
        return text.trim().ifEmpty { null }
    }

    fun boolean(key: String): Boolean? {
        val text = text(key) ?: return null
        return when (text.lowercase(Locale.ROOT)) {
            "true", "yes", "1" -> true
            "false", "no", "0" -> false
            else -> {
                Console.error("Manifest meta-data $key is \"$text\", not true, false, yes, no, 1 or 0. It is ignored.")
                null
            }
        }
    }
}
