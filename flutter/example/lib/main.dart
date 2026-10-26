import 'package:flutter/widgets.dart';
import 'package:mobile_push/mobile_push.dart';

import 'customer_session.dart';
import 'event_log.dart';
import 'example_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final EventLog log = EventLog();

  // Listening before runApp also gets the tap that launched the app.
  SallaPush.notifications.onClick.listen(log.addClick);

  await log.listen();
  runApp(SallaPushExampleApp(session: CustomerSession.atLaunch(), log: log));
}
