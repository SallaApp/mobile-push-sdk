// The app of verify.sh smoke's hot-restart check (SMOKE_HOT_RESTART=1), run
// with flutter run --machine. At every start, a hot restart included, it
// listens to onWillDisplay, prints each event, and delivers the test
// notification: one event per start means that the hot restart replaced the
// old isolate's native listener, without losing or doubling it.

import 'package:flutter/widgets.dart';
import 'package:mobile_push/mobile_push.dart';

import 'test_notification.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SallaPush.notifications.onWillDisplay.listen((
    SallaPushWillDisplayEvent event,
  ) {
    debugPrint(
      'SALLAPUSH_HOT_RESTART will-display ${event.notification.notificationId}',
    );
  });
  // Quiet notifications, granted without a prompt, let iOS deliver the test
  // notification. On Android it does nothing.
  await SallaPush.notifications.registerForProvisionalAuthorization();
  runApp(const SizedBox.shrink());
  await deliverTestNotification();
  debugPrint('SALLAPUSH_HOT_RESTART delivered');
}
