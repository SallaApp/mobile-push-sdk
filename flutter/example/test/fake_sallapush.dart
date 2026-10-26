// The fake speaks the plugin's generated Pigeon messages, which only its
// implementation files declare.
// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_push/src/messages.g.dart';

const String _hostApi = 'dev.flutter.pigeon.mobile_push.SallaPushHostApi';
const String _eventApi =
    'dev.flutter.pigeon.mobile_push.SallaPushEventChannelApi';

/// SallaPush's native side, faked on the plugin's channels: every host call is
/// recorded in [calls] and answered from [answers], and each event stream can
/// send events while Dart listens to it.
final class FakeSallaPush {
  /// Creates the fake for [messenger]'s channels; [install] sets it up.
  FakeSallaPush(this._messenger);

  /// Sets up the channels. Call it in the test body: the event streams deliver
  /// in the zone they were set up in.
  void install() {
    for (final String method in _hostMethods) {
      _messenger.setMockMessageHandler('$_hostApi.$method', (
        ByteData? message,
      ) async {
        final Object? arguments = _codec.decodeMessage(message);
        calls.add(<Object?>[
          method,
          if (arguments is List<Object?>) ...arguments,
        ]);
        final Completer<void>? hold = holds.remove(method);
        if (hold != null) await hold.future;
        return _codec.encodeMessage(<Object?>[answers[method]]);
      });
    }
    for (final String stream in _eventStreams) {
      _messenger.setMockStreamHandler(
        EventChannel('$_eventApi.$stream', pigeonMethodCodec),
        MockStreamHandler.inline(
          onListen: (Object? arguments, MockStreamHandlerEventSink events) {
            _sinks[stream] = events;
          },
          onCancel: (Object? arguments) {
            _sinks.remove(stream);
          },
        ),
      );
    }
  }

  static const MessageCodec<Object?> _codec =
      SallaPushHostApi.pigeonChannelCodec;

  static const List<String> _hostMethods = <String>[
    'initialize',
    'isInitialized',
    'appId',
    'sdkVersion',
    'setConsentRequired',
    'setConsentGiven',
    'login',
    'logout',
    'externalId',
    'isLoggedIn',
    'addTag',
    'addTags',
    'removeTag',
    'removeTags',
    'getTags',
    'setLanguage',
    'pushSubscriptionId',
    'pushSubscriptionToken',
    'pushSubscriptionOptedIn',
    'optIn',
    'optOut',
    'addPushSubscriptionListener',
    'removePushSubscriptionListener',
    'permission',
    'canRequestPermission',
    'permissionStatus',
    'requestPermission',
    'registerForProvisionalAuthorization',
    'refreshPermission',
    'registerForRemoteNotifications',
    'forwardApnsToken',
    'clearAll',
    'removeNotification',
    'isSallaPushNotification',
    'trackOpened',
    'displayNotification',
    'setDisplayCompatPayloads',
    'logLevel',
    'setLogLevel',
    'setLogHandlerLevel',
  ];

  static const List<String> _eventStreams = <String>[
    'clickEvents',
    'willDisplayEvents',
    'permissionChanges',
    'userChanges',
    'loginFailures',
    'pushSubscriptionChanges',
    'logEntries',
  ];

  final TestDefaultBinaryMessenger _messenger;
  final Map<String, MockStreamHandlerEventSink> _sinks =
      <String, MockStreamHandlerEventSink>{};

  /// Every host call in order: the method's name, then its arguments.
  final List<List<Object?>> calls = <List<Object?>>[];

  /// Host methods whose next call waits to answer until the test completes its
  /// completer.
  final Map<String, Completer<void>> holds = <String, Completer<void>>{};

  /// The answer of each host method; methods without one answer null.
  final Map<String, Object?> answers = <String, Object?>{
    'isInitialized': true,
    'appId': 'st_42_ios',
    'sdkVersion': '1.0.2',
    'isLoggedIn': false,
    'getTags': <String, String>{},
    'pushSubscriptionId': 'dev_1',
    'pushSubscriptionToken':
        '80f1c2d3e4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8091a2b',
    'pushSubscriptionOptedIn': true,
    'permission': true,
    'canRequestPermission': false,
    'permissionStatus': IosPermissionStatusMessage.authorized,
    'requestPermission': true,
    'registerForProvisionalAuthorization': true,
    'isSallaPushNotification': false,
    'trackOpened': false,
    'logLevel': LogLevelMessage.warn,
  };

  /// The names of the host methods called so far, in order.
  List<Object?> get methods => <Object?>[
    for (final List<Object?> call in calls) call.first,
  ];

  /// How often [method] was called.
  int count(String method) =>
      methods.where((Object? name) => name == method).length;

  /// Whether Dart listens to [stream], for example 'willDisplayEvents'.
  bool isListening(String stream) => _sinks.containsKey(stream);

  /// Offers a foreground notification under [handle].
  void emitWillDisplay(String handle, {String title = 'SallaPush test'}) =>
      _emit(
        'willDisplayEvents',
        WillDisplayEventMessage(
          handle: handle,
          notification: _notification(title),
        ),
      );

  /// Sends a tap.
  void emitClick({String? url, String? actionId}) => _emit(
    'clickEvents',
    ClickEventMessage(
      notification: _notification('SallaPush test'),
      url: url,
      actionId: actionId,
    ),
  );

  /// Sends a permission change.
  void emitPermission({required bool permission}) => _emit(
    'permissionChanges',
    PermissionChangeMessage(permission: permission),
  );

  /// Sends a user change from [from] to [to], external ids or null for guests.
  void emitUserChange({String? from, String? to}) => _emit(
    'userChanges',
    UserChangedMessage(
      previous: UserStateMessage(externalId: from, isLoggedIn: from != null),
      current: UserStateMessage(externalId: to, isLoggedIn: to != null),
    ),
  );

  /// Sends a refused login.
  void emitLoginFailure() => _emit(
    'loginFailures',
    LoginFailureEventMessage(failure: LoginFailureMessage.tokenRejected),
  );

  /// Sends a push subscription change to the listener Dart added last.
  void emitSubscriptionChange({required String id, required bool optedIn}) {
    final List<Object?> added = calls.lastWhere(
      (List<Object?> call) => call.first == 'addPushSubscriptionListener',
    );
    final SubscriptionStateMessage previous = SubscriptionStateMessage(
      optedIn: false,
    );
    _emit(
      'pushSubscriptionChanges',
      SubscriptionChangedMessage(
        listenerId: added[1] as int,
        previous: previous,
        current: SubscriptionStateMessage(id: id, optedIn: optedIn),
      ),
    );
  }

  /// Sends a log entry at info.
  void emitLog(String code, String message) => _emit(
    'logEntries',
    LogEntryMessage(
      level: LogLevelMessage.info,
      category: 'registration',
      code: code,
      message: message,
      metadata: <String, String>{},
      timestampMillis: 0,
    ),
  );

  void _emit(String stream, Object event) {
    final MockStreamHandlerEventSink? sink = _sinks[stream];
    if (sink == null) {
      throw StateError('Dart does not listen to $stream.');
    }
    sink.success(event);
  }

  /// SallaPush's test notification, as the native side maps it.
  static NotificationMessage _notification(String title) {
    return NotificationMessage(
      notificationId: 'msg_5a11a90001',
      title: title,
      body: 'A native SallaPush notification',
      launchUrl: 'https://example.com/products/42',
      additionalData: <String, Object?>{'type': 'product', 'id': '42'},
      rawPayload: <String, Object?>{'sp_v': '1', 'sp_id': 'msg_5a11a90001'},
      source: PayloadSourceMessage.native,
      stringValues: <String, String>{'type': 'product', 'id': '42'},
      intValues: <String, int>{'id': 42},
      boolValues: <String, bool>{},
      numberValues: <String, Object>{},
    );
  }
}
