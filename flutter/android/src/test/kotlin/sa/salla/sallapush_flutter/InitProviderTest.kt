package sa.salla.sallapush_flutter

import android.content.ComponentName
import android.content.Context
import android.os.Bundle
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import sa.salla.sallapush_flutter.FakeNativeSallaPush.Call

@RunWith(RobolectricTestRunner::class)
class InitProviderTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val native = FakeNativeSallaPush()
    private val defaults = NativeValues.defaults()

    @Before
    fun startWithoutEarlyInit() {
        SallaPushInitProvider.earlyInit = null
    }

    @After
    fun forgetEarlyInit() {
        SallaPushInitProvider.earlyInit = null
    }

    private fun startProcess(metaData: Bundle) {
        installMetaData(context, metaData)
        SallaPushInitProvider(native).attachInfo(context, null)
    }

    @Test
    fun startsNothingWithoutMetaData() {
        startProcess(Bundle())

        assertEquals(emptyList<Call>(), native.calls)
        assertNull(SallaPushInitProvider.earlyInit)
    }

    @Test
    fun initializesWithTheAppIdAndTheConfigurationBuiltFromTheMetaData() {
        startProcess(
            metaData(
                StaticConfig.APP_ID to "st_42_android",
                StaticConfig.OPEN_LAUNCH_URLS to true,
                StaticConfig.REQUIRES_USER_CONSENT to "yes",
                StaticConfig.CLEAR_TAGS_ON_LOGOUT to false,
                StaticConfig.APP_VERSION to "5.0.38",
                StaticConfig.AUTO_CLEAR_BADGE to !defaults.autoClearBadge,
                StaticConfig.AUTO_UPDATE_BADGE to (!defaults.autoUpdateBadge).toString(),
            ),
        )

        val call = native.calls.single() as Call.InitWithContext
        assertSame(context, call.context)
        assertEquals("st_42_android", call.appId)
        assertTrue(call.config.openLaunchUrls)
        assertTrue(call.config.requiresUserConsent)
        assertFalse(call.config.clearTagsOnLogout)
        assertEquals("5.0.38", call.config.appVersion)
        assertEquals(!defaults.autoClearBadge, call.config.autoClearBadge)
        assertEquals(!defaults.autoUpdateBadge, call.config.autoUpdateBadge)
    }

    @Test
    fun appliesTheCompatibilityFlagWithoutAnAppId() {
        startProcess(metaData(StaticConfig.DISPLAY_COMPAT_PAYLOADS to false))

        assertEquals(listOf(Call.SetDisplayCompatPayloads(false)), native.calls)
        assertNull(SallaPushInitProvider.earlyInit)
    }

    @Test
    fun appliesTheCompatibilityFlagBeforeInitializing() {
        startProcess(
            metaData(
                StaticConfig.APP_ID to "st_42_android",
                StaticConfig.DISPLAY_COMPAT_PAYLOADS to "true",
            ),
        )

        assertEquals(2, native.calls.size)
        assertEquals(Call.SetDisplayCompatPayloads(true), native.calls[0])
        assertEquals("st_42_android", (native.calls[1] as Call.InitWithContext).appId)
    }

    @Test
    fun recordsTheConfigurationSallaPushStartedWith() {
        startProcess(metaData(StaticConfig.APP_ID to "st_42_android", StaticConfig.REQUIRES_USER_CONSENT to true))

        assertEquals(
            StaticConfig(appId = "st_42_android", requiresUserConsent = true),
            SallaPushInitProvider.earlyInit,
        )
    }

    @Test
    fun recordsNoConfigurationWithoutAnAppId() {
        startProcess(metaData(StaticConfig.REQUIRES_USER_CONSENT to true))

        assertEquals(emptyList<Call>(), native.calls)
        assertNull(SallaPushInitProvider.earlyInit)
    }

    @Test
    fun isDeclaredPrivateAndAfterFirebaseAndAndroidxStartup() {
        val info = context.packageManager.getProviderInfo(ComponentName(context, SallaPushInitProvider::class.java), 0)

        assertEquals("${context.packageName}.sallapush-flutter-init", info.authority)
        assertFalse(info.exported)
        assertEquals(-1, info.initOrder)
    }
}
