import 'dart:async';

import 'channels.dart';
import 'mapping.dart';
import 'messages.g.dart';
import 'models.dart';

/// This device's push subscription: its SallaPush id, its push token, and
/// whether it receives notifications.
final class SallaPushSubscription {
  const SallaPushSubscription._();

  /// The SallaPush device id; null until the device is registered and
  /// SallaPush has loaded its saved state.
  Future<String?> get id => _host.pushSubscriptionId();

  /// The push token SallaPush uses: the APNs token as lowercase hexadecimal
  /// text on iOS, the FCM token on Android; null until one is known. Treat it
  /// as private: never send it to analytics.
  Future<String?> get token => _host.pushSubscriptionToken();

  /// True when notifications are allowed, the user did not opt out, and a push
  /// token exists. [optIn] and [optOut] show here as soon as they return.
  Future<bool> get optedIn => _host.pushSubscriptionOptedIn();

  /// Clears an earlier [optOut]. It also shows the system permission prompt
  /// when the permission can still be requested.
  Future<void> optIn() => _host.optIn();

  /// Stops SallaPush notifications to this device until [optIn]. The device
  /// stays registered.
  Future<void> optOut() => _host.optOut();

  /// Changes of id, token or optedIn. As with native observers, each listener
  /// added while the device is registered first gets the current state once
  /// (previous == current), whenever it is added; the other listeners get no
  /// replay then. A listener added at launch, before SallaPush has loaded its
  /// saved state, gets that replay once the state is loaded.
  Stream<SallaPushSubscriptionChangedState> get onChange {
    final SallaPushChannels channels = SallaPushChannels.current;
    return _onChange[channels] ??= _SubscriptionChanges(channels);
  }

  static SallaPushHostApi get _host => SallaPushChannels.current.host;

  static final Expando<Stream<SallaPushSubscriptionChangedState>> _onChange =
      Expando<Stream<SallaPushSubscriptionChangedState>>();
}

/// The push subscription changes of one isolate. Each listener has its own
/// native observer, so it gets SallaPush's own replay; the platform stream
/// carries the events of every observer, tagged with its listener's id.
final class _SubscriptionChanges
    extends Stream<SallaPushSubscriptionChangedState> {
  _SubscriptionChanges(this._channels);

  final SallaPushChannels _channels;
  final Map<int, StreamController<SallaPushSubscriptionChangedState>>
  _listeners = <int, StreamController<SallaPushSubscriptionChangedState>>{};
  StreamSubscription<SubscriptionChangedMessage>? _platform;
  int _lastId = 0;

  @override
  bool get isBroadcast => true;

  @override
  StreamSubscription<SallaPushSubscriptionChangedState> listen(
    void Function(SallaPushSubscriptionChangedState event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final int id = ++_lastId;
    final StreamController<SallaPushSubscriptionChangedState> listener =
        StreamController<SallaPushSubscriptionChangedState>(
          sync: true,
          onCancel: () => _remove(id),
        );
    _listeners[id] = listener;
    // The platform listen is sent before the host call, so the native replay
    // always finds the sink.
    _platform ??= _channels.pushSubscriptionChanges.listen(
      _deliver,
      onError: _deliverError,
    );
    unawaited(
      reportingFailure(
        _channels.host.addPushSubscriptionListener(id),
        'while adding a push subscription listener',
      ),
    );
    return listener.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  void _deliver(SubscriptionChangedMessage message) {
    _listeners[message.listenerId]?.add(message.state);
  }

  void _deliverError(Object error, StackTrace stack) {
    for (final StreamController<SallaPushSubscriptionChangedState> listener
        in _listeners.values.toList()) {
      listener.addError(error, stack);
    }
  }

  Future<void> _remove(int id) async {
    _listeners.remove(id);
    final List<Future<void>> calls = <Future<void>>[
      reportingFailure(
        _channels.host.removePushSubscriptionListener(id),
        'while removing a push subscription listener',
      ),
    ];
    final StreamSubscription<SubscriptionChangedMessage>? platform = _platform;
    if (_listeners.isEmpty && platform != null) {
      _platform = null;
      calls.add(platform.cancel());
    }
    await Future.wait(calls);
  }
}

/// The one [SallaPushSubscription], `SallaPush.user.pushSubscription`.
const SallaPushSubscription pushSubscriptionNamespace =
    SallaPushSubscription._();
