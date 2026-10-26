package sa.salla.sallapush.example

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import com.salla.push.SallaPush
import org.json.JSONException
import org.json.JSONObject
import kotlin.concurrent.thread

/**
 * The example's hook for the smoke tests (scripts/verify.sh smoke); never part of the library or of an app. It hands
 * the FCM data map in the "payload" extra (a JSON object of strings, such as android/TestPayloads/native.json) to
 * SallaPush on a background thread, as FCM delivers a message. Only holders of android.permission.DUMP can send it.
 */
class TestPushReceiver : BroadcastReceiver() {

  override fun onReceive(context: Context, intent: Intent) {
    val data = intent.getStringExtra(PAYLOAD)?.let(::dataOf)
    if (data == null) {
      Log.w(TAG, "The \"$PAYLOAD\" extra must be a JSON object of strings.")
      return
    }
    val appContext = context.applicationContext
    val pending = goAsync()
    thread(name = "SallaPushExample-smoke") {
      try {
        val message = RemoteMessage.Builder("sallapush-example@fcm.googleapis.com").setData(data).build()
        val handled = SallaPush.Notifications.handleFirebaseMessage(appContext, message)
        Log.i(TAG, if (handled) "SallaPush handled the notification." else "The notification isn't SallaPush's.")
      } finally {
        pending.finish()
      }
    }
  }

  private fun dataOf(payload: String): Map<String, String>? =
      try {
        val json = JSONObject(payload)
        json.keys().asSequence().associateWith { json.getString(it) }
      } catch (e: JSONException) {
        null
      }

  private companion object {
    const val PAYLOAD = "payload"
    const val TAG = "SallaPushExample"
  }
}
