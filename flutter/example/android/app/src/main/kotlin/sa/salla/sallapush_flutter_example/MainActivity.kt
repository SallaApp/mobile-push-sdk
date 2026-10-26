package sa.salla.sallapush_flutter_example

import android.os.Handler
import android.os.Looper
import com.google.firebase.messaging.RemoteMessage
import com.salla.push.SallaPush
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "example/test_hooks")
            .setMethodCallHandler(::onTestHook)
    }

    /**
     * The smoke tests' hooks (integration_test/sallapush_smoke_test.dart). They are example code: an app never needs
     * them.
     */
    private fun onTestHook(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "deliverTestNotification" -> deliverTestNotification(call.arguments, result)
            else -> result.notImplemented()
        }
    }

    /**
     * Hands the FCM data in [arguments] to SallaPush on a background thread, as FCM delivers a message, and answers
     * whether SallaPush handled it.
     */
    private fun deliverTestNotification(arguments: Any?, result: MethodChannel.Result) {
        val data = (arguments as? Map<*, *>)
            ?.mapNotNull { (key, value) -> if (key is String && value is String) key to value else null }
            ?.toMap()
        if (data == null) {
            result.error("invalid_arguments", "The FCM data must be a map of strings.", null)
            return
        }
        val context = applicationContext
        val main = Handler(Looper.getMainLooper())
        thread(name = "SallaPushExample-fcm") {
            val message = RemoteMessage.Builder("test@fcm.googleapis.com").setData(data).build()
            val handled = SallaPush.Notifications.handleFirebaseMessage(context, message)
            main.post { result.success(handled) }
        }
    }
}
