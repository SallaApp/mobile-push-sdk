import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_push/src/channels.dart';
import 'package:mobile_push/src/messages.g.dart';

/// Checks that [getter] always gives the same stream, which listens on
/// [platform] lazily: one platform listen for the first listener and none for
/// the next, one platform cancel after the last, and a new listen after that.
Future<void> expectListensLazily(
  Stream<Object?> Function() getter,
  FakePlatformStream<Object?> platform,
) async {
  final Stream<Object?> stream = getter();
  expect(getter(), same(stream));
  expect(platform.listens, 0);

  final StreamSubscription<Object?> first = stream.listen((_) {});
  final StreamSubscription<Object?> second = stream.listen((_) {});
  expect(platform.listens, 1);

  await first.cancel();
  expect(platform.cancels, 0);
  await second.cancel();
  expect(platform.cancels, 1);
  expect(platform.isListening, isFalse);

  final StreamSubscription<Object?> again = stream.listen((_) {});
  expect(platform.listens, 2);
  await again.cancel();
  expect(platform.cancels, 2);
}

/// A platform event stream, faked: a broadcast stream, asynchronous like an
/// event channel's, that counts the platform listens and cancels and records
/// them in [FakeChannels.calls].
class FakePlatformStream<T> {
  FakePlatformStream(this._name, this._calls);

  final String _name;
  final List<List<Object?>> _calls;

  /// How often the platform was told to listen, and to cancel.
  int listens = 0;
  int cancels = 0;

  late final StreamController<T> _controller = StreamController<T>.broadcast(
    onListen: () {
      listens++;
      _calls.add(<Object?>['listen', _name]);
    },
    onCancel: () {
      cancels++;
      _calls.add(<Object?>['cancel', _name]);
    },
  );

  Stream<T> get stream => _controller.stream;

  /// Whether the platform is listening.
  bool get isListening => _controller.hasListener;

  /// Sends [event] as the native side does.
  void emit(T event) => _controller.add(event);

  /// Sends an error, as an event channel does for a failed message.
  void emitError(Object error) => _controller.addError(error);
}

/// The native side, faked: records every host call and platform listen, and
/// answers with the scripted values.
class FakeChannels implements SallaPushChannels, SallaPushHostApi {
  /// Every host call in order, as the method name followed by its arguments,
  /// with each platform listen and cancel as `['listen', stream]` and
  /// `['cancel', stream]`.
  final List<List<Object?>> calls = <List<Object?>>[];

  late final FakePlatformStream<ClickEventMessage> clicks =
      FakePlatformStream<ClickEventMessage>('clickEvents', calls);
  late final FakePlatformStream<WillDisplayEventMessage> willDisplays =
      FakePlatformStream<WillDisplayEventMessage>('willDisplayEvents', calls);
  late final FakePlatformStream<PermissionChangeMessage> permissions =
      FakePlatformStream<PermissionChangeMessage>('permissionChanges', calls);
  late final FakePlatformStream<UserChangedMessage> users =
      FakePlatformStream<UserChangedMessage>('userChanges', calls);
  late final FakePlatformStream<LoginFailureEventMessage> failures =
      FakePlatformStream<LoginFailureEventMessage>('loginFailures', calls);
  late final FakePlatformStream<SubscriptionChangedMessage> subscriptions =
      FakePlatformStream<SubscriptionChangedMessage>(
        'pushSubscriptionChanges',
        calls,
      );
  late final FakePlatformStream<LogEntryMessage> logs =
      FakePlatformStream<LogEntryMessage>('logEntries', calls);

  /// The host methods that fail, as without the native plugin.
  final Set<String> failing = <String>{};

  bool isInitializedResult = false;
  String? appIdResult;
  String sdkVersionResult = '1.0.2';
  String? externalIdResult;
  bool isLoggedInResult = false;
  Map<String, String> tagsResult = <String, String>{};
  String? pushSubscriptionIdResult;
  String? pushSubscriptionTokenResult;
  bool pushSubscriptionOptedInResult = false;
  bool permissionResult = false;
  bool canRequestPermissionResult = false;
  IosPermissionStatusMessage? permissionStatusResult;
  bool requestPermissionResult = false;
  bool registerForProvisionalAuthorizationResult = false;
  bool isSallaPushNotificationResult = false;
  bool trackOpenedResult = false;
  LogLevelMessage logLevelResult = LogLevelMessage.warn;

  @override
  SallaPushHostApi get host => this;

  @override
  Stream<ClickEventMessage> get clickEvents => clicks.stream;

  @override
  Stream<WillDisplayEventMessage> get willDisplayEvents => willDisplays.stream;

  @override
  Stream<PermissionChangeMessage> get permissionChanges => permissions.stream;

  @override
  Stream<UserChangedMessage> get userChanges => users.stream;

  @override
  Stream<LoginFailureEventMessage> get loginFailures => failures.stream;

  @override
  Stream<SubscriptionChangedMessage> get pushSubscriptionChanges =>
      subscriptions.stream;

  @override
  Stream<LogEntryMessage> get logEntries => logs.stream;

  @override
  // ignore: non_constant_identifier_names
  BinaryMessenger? get pigeonVar_binaryMessenger => null;

  @override
  // ignore: non_constant_identifier_names
  String get pigeonVar_messageChannelSuffix => '';

  Future<T> _answer<T>(
    T result,
    String method, [
    List<Object?> arguments = const <Object?>[],
  ]) async {
    calls.add(<Object?>[method, ...arguments]);
    if (failing.contains(method)) {
      throw PlatformException(code: 'channel-error');
    }
    return result;
  }

  @override
  Future<void> initialize(String appId, ConfigMessage config) =>
      _answer(null, 'initialize', <Object?>[appId, config]);

  @override
  Future<bool> isInitialized() => _answer(isInitializedResult, 'isInitialized');

  @override
  Future<String?> appId() => _answer(appIdResult, 'appId');

  @override
  Future<String> sdkVersion() => _answer(sdkVersionResult, 'sdkVersion');

  @override
  Future<void> setConsentRequired(bool required) =>
      _answer(null, 'setConsentRequired', <Object?>[required]);

  @override
  Future<void> setConsentGiven(bool given) =>
      _answer(null, 'setConsentGiven', <Object?>[given]);

  @override
  Future<void> login(String externalId, String identityToken) =>
      _answer(null, 'login', <Object?>[externalId, identityToken]);

  @override
  Future<void> logout() => _answer(null, 'logout');

  @override
  Future<String?> externalId() => _answer(externalIdResult, 'externalId');

  @override
  Future<bool> isLoggedIn() => _answer(isLoggedInResult, 'isLoggedIn');

  @override
  Future<void> addTag(String key, String value) =>
      _answer(null, 'addTag', <Object?>[key, value]);

  @override
  Future<void> addTags(Map<String, String> tags) =>
      _answer(null, 'addTags', <Object?>[tags]);

  @override
  Future<void> removeTag(String key) =>
      _answer(null, 'removeTag', <Object?>[key]);

  @override
  Future<void> removeTags(List<String> keys) =>
      _answer(null, 'removeTags', <Object?>[keys]);

  @override
  Future<Map<String, String>> getTags() => _answer(tagsResult, 'getTags');

  @override
  Future<void> setLanguage(String? language) =>
      _answer(null, 'setLanguage', <Object?>[language]);

  @override
  Future<String?> pushSubscriptionId() =>
      _answer(pushSubscriptionIdResult, 'pushSubscriptionId');

  @override
  Future<String?> pushSubscriptionToken() =>
      _answer(pushSubscriptionTokenResult, 'pushSubscriptionToken');

  @override
  Future<bool> pushSubscriptionOptedIn() =>
      _answer(pushSubscriptionOptedInResult, 'pushSubscriptionOptedIn');

  @override
  Future<void> optIn() => _answer(null, 'optIn');

  @override
  Future<void> optOut() => _answer(null, 'optOut');

  @override
  Future<void> addPushSubscriptionListener(int listenerId) =>
      _answer(null, 'addPushSubscriptionListener', <Object?>[listenerId]);

  @override
  Future<void> removePushSubscriptionListener(int listenerId) =>
      _answer(null, 'removePushSubscriptionListener', <Object?>[listenerId]);

  @override
  Future<bool> permission() => _answer(permissionResult, 'permission');

  @override
  Future<bool> canRequestPermission() =>
      _answer(canRequestPermissionResult, 'canRequestPermission');

  @override
  Future<IosPermissionStatusMessage?> permissionStatus() =>
      _answer(permissionStatusResult, 'permissionStatus');

  @override
  Future<bool> requestPermission(bool fallbackToSettings) => _answer(
    requestPermissionResult,
    'requestPermission',
    <Object?>[fallbackToSettings],
  );

  @override
  Future<bool> registerForProvisionalAuthorization() => _answer(
    registerForProvisionalAuthorizationResult,
    'registerForProvisionalAuthorization',
  );

  @override
  Future<void> refreshPermission() => _answer(null, 'refreshPermission');

  @override
  Future<void> registerForRemoteNotifications() =>
      _answer(null, 'registerForRemoteNotifications');

  @override
  Future<void> forwardApnsToken(String apnsToken) =>
      _answer(null, 'forwardApnsToken', <Object?>[apnsToken]);

  @override
  Future<void> clearAll() => _answer(null, 'clearAll');

  @override
  Future<void> removeNotification(int androidNotificationId) =>
      _answer(null, 'removeNotification', <Object?>[androidNotificationId]);

  @override
  Future<bool> isSallaPushNotification(Map<String, Object?> payload) => _answer(
    isSallaPushNotificationResult,
    'isSallaPushNotification',
    <Object?>[payload],
  );

  @override
  Future<bool> trackOpened(Map<String, Object?>? additionalData) =>
      _answer(trackOpenedResult, 'trackOpened', <Object?>[additionalData]);

  @override
  Future<void> displayNotification(String handle) =>
      _answer(null, 'displayNotification', <Object?>[handle]);

  @override
  Future<void> setDisplayCompatPayloads(bool display) =>
      _answer(null, 'setDisplayCompatPayloads', <Object?>[display]);

  @override
  Future<LogLevelMessage> logLevel() => _answer(logLevelResult, 'logLevel');

  @override
  Future<void> setLogLevel(LogLevelMessage level) =>
      _answer(null, 'setLogLevel', <Object?>[level]);

  @override
  Future<void> setLogHandlerLevel(LogLevelMessage level) =>
      _answer(null, 'setLogHandlerLevel', <Object?>[level]);
}
