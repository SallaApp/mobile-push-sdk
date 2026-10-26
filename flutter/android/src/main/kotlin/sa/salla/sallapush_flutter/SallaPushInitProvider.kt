package sa.salla.sallapush_flutter

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri

/** Starts SallaPush from the manifest meta-data before Application.onCreate, in every start of the app's process. */
class SallaPushInitProvider internal constructor(private val native: NativeSallaPush) : ContentProvider() {

    constructor() : this(LiveNativeSallaPush)

    override fun onCreate(): Boolean {
        val context = context ?: return true
        val config = StaticConfig.read(context)
        // The SDK shows FCM messages before and without initialization, so the flag applies without an app id too.
        config.displayCompatPayloads?.let { native.setDisplayCompatPayloads(it) }
        val appId = config.appId ?: return true
        native.initWithContext(context, appId, config.sallaPushConfig())
        earlyInit = config
        return true
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun getType(uri: Uri): String? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0

    internal companion object {
        /** The static configuration SallaPush was started with in this process; null when no app id is set. */
        @Volatile
        var earlyInit: StaticConfig? = null
    }
}
