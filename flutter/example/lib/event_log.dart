import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile_push/mobile_push.dart';

/// The kinds of entries in the [EventLog].
enum EventKind {
  /// A tap on a notification.
  click('Click'),

  /// A foreground notification offered to the will-display listener.
  willDisplay('Will display'),

  /// A change of the notification permission.
  permission('Permission'),

  /// A change of the logged-in customer.
  user('User'),

  /// A refused login.
  loginFailure('Login failure'),

  /// A change of the push subscription.
  subscription('Subscription'),

  /// A SallaPush log entry.
  log('Log');

  const EventKind(this.label);

  /// The kind as the log shows it.
  final String label;
}

/// One entry of the [EventLog].
@immutable
final class LoggedEvent {
  /// Creates an entry.
  const LoggedEvent(this.kind, this.text, this.time);

  /// What happened.
  final EventKind kind;

  /// The details.
  final String text;

  /// When the example received it.
  final DateTime time;
}

/// The SallaPush events the example received, newest first.
final class EventLog extends ChangeNotifier {
  /// The most entries the log keeps.
  static const int capacity = 200;

  final List<LoggedEvent> _entries = <LoggedEvent>[];
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];
  SallaPushLogLevel? _logLevel;

  /// The entries, newest first.
  List<LoggedEvent> get entries => List<LoggedEvent>.unmodifiable(_entries);

  /// The newest entry; null while the log is empty.
  LoggedEvent? get latest => _entries.isEmpty ? null : _entries.first;

  /// The level of the SallaPush log entries the log receives; null before
  /// [listen].
  SallaPushLogLevel? get logLevel => _logLevel;

  /// Adds an entry.
  void add(EventKind kind, String text) {
    _entries.insert(0, LoggedEvent(kind, text, DateTime.now()));
    if (_entries.length > capacity) {
      _entries.removeLast();
    }
    notifyListeners();
  }

  /// Adds a tap.
  void addClick(SallaPushClickEvent event) {
    final SallaPushClickResult result = event.result;
    add(
      EventKind.click,
      '${describeNotification(event.notification)}, '
      'url: ${result.url ?? 'none'}, action: ${result.actionId ?? 'none'}',
    );
  }

  /// Listens to the permission, user, login failure and push subscription
  /// events, and to SallaPush's log entries at [logLevel].
  Future<void> listen({SallaPushLogLevel logLevel = SallaPushLogLevel.info}) {
    _subscriptions.addAll(<StreamSubscription<Object?>>[
      SallaPush.notifications.onPermissionChange.listen(
        (bool allowed) =>
            add(EventKind.permission, allowed ? 'Allowed' : 'Not allowed'),
      ),
      SallaPush.user.onChange.listen(
        (SallaPushUserChangedState change) => add(
          EventKind.user,
          '${_customer(change.previous)} → ${_customer(change.current)}',
        ),
      ),
      SallaPush.user.onLoginFailure.listen(
        (SallaPushLoginFailure failure) =>
            add(EventKind.loginFailure, failure.name),
      ),
      SallaPush.user.pushSubscription.onChange.listen(
        (SallaPushSubscriptionChangedState change) => add(
          EventKind.subscription,
          '${_subscription(change.previous)} → '
          '${_subscription(change.current)}',
        ),
      ),
    ]);
    return setLogLevel(logLevel);
  }

  /// Receives SallaPush's log entries at [level] or more severe.
  Future<void> setLogLevel(SallaPushLogLevel level) async {
    _logLevel = level;
    notifyListeners();
    await SallaPush.debug.setLogHandler(level, (SallaPushLogEntry entry) {
      add(EventKind.log, '${entry.level.name} ${entry.code}: ${entry.message}');
    });
  }

  /// Removes every entry.
  void clear() {
    _entries.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    final SallaPushLogLevel? logLevel = _logLevel;
    if (logLevel != null) {
      unawaited(SallaPush.debug.setLogHandler(logLevel, null));
    }
    super.dispose();
  }

  static String _customer(SallaPushUserState state) =>
      state.isLoggedIn ? state.externalId ?? 'unknown customer' : 'guest';

  static String _subscription(SallaPushSubscriptionState state) =>
      '${state.id ?? 'unregistered'}, '
      '${state.optedIn ? 'opted in' : 'not opted in'}';
}

/// A notification in one line: its title, else its id, and its format.
String describeNotification(SallaPushNotification notification) {
  final String name =
      notification.title ?? notification.notificationId ?? 'Untitled';
  return '$name (${notification.source.name})';
}
