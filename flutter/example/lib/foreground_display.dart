import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile_push/mobile_push.dart';

import 'event_log.dart';

/// What the example does with the SallaPush notifications that arrive while it
/// is in the foreground.
enum ForegroundMode {
  /// No will-display listener: SallaPush shows the original notification.
  off,

  /// A will-display listener that lets each notification show.
  show,

  /// A will-display listener that holds each notification until the user
  /// displays it.
  hold,
}

/// The example's will-display listener, as [mode] asks, and the notifications
/// it holds.
final class ForegroundDisplay extends ChangeNotifier {
  /// Creates the listener's owner; it logs each decision in [log].
  ForegroundDisplay(this._log);

  final EventLog _log;
  final List<SallaPushNotification> _held = <SallaPushNotification>[];
  StreamSubscription<SallaPushWillDisplayEvent>? _listener;
  ForegroundMode _mode = ForegroundMode.off;

  /// The current mode.
  ForegroundMode get mode => _mode;

  /// The notifications held so far, oldest first.
  List<SallaPushNotification> get held =>
      List<SallaPushNotification>.unmodifiable(_held);

  set mode(ForegroundMode mode) {
    _mode = mode;
    if (mode == ForegroundMode.off) {
      unawaited(_listener?.cancel());
      _listener = null;
    } else {
      _listener ??= _listen();
    }
    notifyListeners();
  }

  /// Shows a held notification: SallaPush does it once, within 10 minutes of
  /// its event.
  Future<void> display(SallaPushNotification notification) {
    _held.remove(notification);
    notifyListeners();
    return notification.display();
  }

  StreamSubscription<SallaPushWillDisplayEvent> _listen() {
    return SallaPush.notifications.onWillDisplay.listen((
      SallaPushWillDisplayEvent event,
    ) {
      if (_mode == ForegroundMode.hold) {
        // Before any await: SallaPush decides once the listeners return.
        event.preventDefault();
        _held.add(event.notification);
      }
      _logDecision(event);
    });
  }

  void _logDecision(SallaPushWillDisplayEvent event) {
    final String decision = event.isPrevented ? 'held' : 'shown';
    _log.add(
      EventKind.willDisplay,
      '${describeNotification(event.notification)}, $decision',
    );
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_listener?.cancel());
    super.dispose();
  }
}
