package sa.salla.sallapush_flutter

import android.content.Context
import android.os.Bundle
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.shadows.ShadowLog

@RunWith(RobolectricTestRunner::class)
class StaticConfigTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val defaults = NativeValues.defaults()

    @Before
    fun clearLogcat() {
        ShadowLog.reset()
    }

    @Test
    fun readsEveryKeyFromText() {
        val config = StaticConfig.from(
            context,
            metaData(
                StaticConfig.APP_ID to " st_42_android ",
                StaticConfig.OPEN_LAUNCH_URLS to "true",
                StaticConfig.REQUIRES_USER_CONSENT to "YES",
                StaticConfig.CLEAR_TAGS_ON_LOGOUT to "no",
                StaticConfig.APP_VERSION to "5.0.38",
                StaticConfig.AUTO_CLEAR_BADGE to "false",
                StaticConfig.AUTO_UPDATE_BADGE to "No",
                StaticConfig.DISPLAY_COMPAT_PAYLOADS to "False",
            ),
        )

        assertEquals(
            StaticConfig(
                appId = "st_42_android",
                openLaunchUrls = true,
                requiresUserConsent = true,
                clearTagsOnLogout = false,
                appVersion = "5.0.38",
                autoClearBadge = false,
                autoUpdateBadge = false,
                displayCompatPayloads = false,
            ),
            config,
        )
        assertEquals(emptyList<String>(), consoleLines())
    }

    @Test
    fun readsAnAppIdFromAStringResource() {
        val config = StaticConfig.from(context, metaData(StaticConfig.APP_ID to android.R.string.ok))

        assertEquals(context.getString(android.R.string.ok), config.appId)
    }

    @Test
    fun readsANumericAppIdAsItsDigits() {
        val config = StaticConfig.from(context, metaData(StaticConfig.APP_ID to 12345))

        assertEquals("12345", config.appId)
    }

    @Test
    fun rejectsALongNumericAppIdWithOneConsoleLine() {
        val config = StaticConfig.from(context, metaData(StaticConfig.APP_ID to 1.2345679E10f))

        assertNull(config.appId)
        val line = consoleLines().single()
        assertTrue(line, line.startsWith("Manifest meta-data com.salla.push.APP_ID is a Float"))
        assertTrue(line, line.contains("string resource"))
    }

    @Test
    fun readsBooleansWrittenAsBooleansAndAsNumbers() {
        val config = StaticConfig.from(
            context,
            metaData(
                StaticConfig.OPEN_LAUNCH_URLS to true,
                StaticConfig.REQUIRES_USER_CONSENT to false,
                StaticConfig.CLEAR_TAGS_ON_LOGOUT to 1,
                StaticConfig.AUTO_CLEAR_BADGE to false,
                StaticConfig.AUTO_UPDATE_BADGE to 0,
                StaticConfig.DISPLAY_COMPAT_PAYLOADS to 0,
            ),
        )

        assertEquals(
            StaticConfig(
                openLaunchUrls = true,
                requiresUserConsent = false,
                clearTagsOnLogout = true,
                autoClearBadge = false,
                autoUpdateBadge = false,
                displayCompatPayloads = false,
            ),
            config,
        )
    }

    @Test
    fun readsEachBadgeKeyIntoItsOwnSetting() {
        assertEquals(
            StaticConfig(autoClearBadge = true),
            StaticConfig.from(context, metaData(StaticConfig.AUTO_CLEAR_BADGE to true)),
        )
        assertEquals(
            StaticConfig(autoUpdateBadge = false),
            StaticConfig.from(context, metaData(StaticConfig.AUTO_UPDATE_BADGE to "false")),
        )
        assertEquals(emptyList<String>(), consoleLines())
    }

    @Test
    fun ignoresAValueThatIsNotABooleanWithOneConsoleLine() {
        val config = StaticConfig.from(context, metaData(StaticConfig.OPEN_LAUNCH_URLS to "maybe"))

        assertNull(config.openLaunchUrls)
        assertEquals(
            listOf(
                "Manifest meta-data com.salla.push.OPEN_LAUNCH_URLS is \"maybe\", not true, false, yes, no, 1 or 0. " +
                    "It is ignored.",
            ),
            consoleLines(),
        )
    }

    @Test
    fun ignoresABadgeSettingThatIsNotABooleanWithOneConsoleLine() {
        val config = StaticConfig.from(context, metaData(StaticConfig.AUTO_CLEAR_BADGE to "sometimes"))

        assertNull(config.autoClearBadge)
        assertEquals(
            listOf(
                "Manifest meta-data com.salla.push.AUTO_CLEAR_BADGE is \"sometimes\", not true, false, yes, no, 1 " +
                    "or 0. It is ignored.",
            ),
            consoleLines(),
        )
    }

    @Test
    fun treatsEmptyValuesAsAbsent() {
        val config = StaticConfig.from(
            context,
            metaData(
                StaticConfig.APP_ID to "  ",
                StaticConfig.APP_VERSION to "",
                StaticConfig.REQUIRES_USER_CONSENT to "",
            ),
        )

        assertEquals(StaticConfig(), config)
        assertEquals(emptyList<String>(), consoleLines())
    }

    @Test
    fun treatsAbsentKeysAsAbsent() {
        assertEquals(StaticConfig(), StaticConfig.from(context, Bundle()))
        assertEquals(emptyList<String>(), consoleLines())
    }

    @Test
    fun readsTheAppsManifestMetaData() {
        installMetaData(
            context,
            metaData(StaticConfig.APP_ID to "st_42_android", StaticConfig.OPEN_LAUNCH_URLS to true),
        )

        assertEquals(StaticConfig(appId = "st_42_android", openLaunchUrls = true), StaticConfig.read(context))
    }

    @Test
    fun buildsTheSdkConfigurationFromTheOptionsSet() {
        val config = StaticConfig(
            appId = "st_42_android",
            openLaunchUrls = true,
            requiresUserConsent = true,
            clearTagsOnLogout = false,
            appVersion = "5.0.38",
            autoClearBadge = !defaults.autoClearBadge,
            autoUpdateBadge = !defaults.autoUpdateBadge,
        ).sallaPushConfig()

        assertTrue(config.openLaunchUrls)
        assertTrue(config.requiresUserConsent)
        assertFalse(config.clearTagsOnLogout)
        assertEquals("5.0.38", config.appVersion)
        assertEquals(!defaults.autoClearBadge, config.autoClearBadge)
        assertEquals(!defaults.autoUpdateBadge, config.autoUpdateBadge)
    }

    @Test
    fun setsEachBadgeOptionAloneOnItsOwnSetting() {
        // Each option, set to the opposite of SallaPush's default, changes only its own setting.
        val clear = StaticConfig(autoClearBadge = !defaults.autoClearBadge).sallaPushConfig()
        val update = StaticConfig(autoUpdateBadge = !defaults.autoUpdateBadge).sallaPushConfig()

        assertEquals(!defaults.autoClearBadge, clear.autoClearBadge)
        assertEquals(defaults.autoUpdateBadge, clear.autoUpdateBadge)
        assertEquals(defaults.autoClearBadge, update.autoClearBadge)
        assertEquals(!defaults.autoUpdateBadge, update.autoUpdateBadge)
    }

    @Test
    fun keepsTheSdkDefaultsForOptionsNotSet() {
        val config = StaticConfig(appId = "st_42_android").sallaPushConfig()

        assertFalse(config.openLaunchUrls)
        assertFalse(config.requiresUserConsent)
        assertTrue(config.clearTagsOnLogout)
        assertNull(config.appVersion)
        assertEquals(defaults.autoClearBadge, config.autoClearBadge)
        assertEquals(defaults.autoUpdateBadge, config.autoUpdateBadge)
        // The SDK then reads its own com.salla.push.LOG_LEVEL meta-data.
        assertNull(config.logLevel)
    }
}
