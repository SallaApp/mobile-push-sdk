package sa.salla.sallapush_flutter_example

// The setup guide's Android snippet, compiled so that it stays correct. The app never declares the service.

// snippet:messaging-service
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.salla.push.SallaPush

class AppMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        if (SallaPush.Notifications.handleFirebaseMessage(applicationContext, message)) return
        // Not a SallaPush message: hand it to your other SDK here.
    }

    override fun onNewToken(token: String) {
        SallaPush.Notifications.onNewToken(applicationContext, token)
        // Hand the token to your other SDK here too.
    }
}
// end-snippet
