import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_push/mobile_push.dart';
import 'package:mobile_push/src/channels.dart';
import 'package:mobile_push/src/messages.g.dart';

import 'fakes/fake_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeChannels native;

  setUp(() {
    native = FakeChannels();
    SallaPushChannels.debugOverride = native;
  });

  tearDown(() {
    SallaPushChannels.debugOverride = null;
  });

  group('initialize', () {
    test('passes the app id and every option', () async {
      await SallaPush.initialize(
        'st_42_ios',
        config: const SallaPushConfig(
          logLevel: SallaPushLogLevel.debug,
          appVersion: '5.0.38',
          clearTagsOnLogout: false,
          requiresUserConsent: true,
          openLaunchUrls: true,
          autoClearBadge: false,
          autoUpdateBadge: false,
          ios: SallaPushIosConfig(
            appGroupIdentifier: 'group.sa.salla.example',
            apnsEnvironment: SallaPushApnsEnvironment.sandbox,
            registerForRemoteNotificationsOnInit: false,
          ),
        ),
      );

      expect(native.calls, <Object?>[
        <Object?>[
          'initialize',
          'st_42_ios',
          ConfigMessage(
            logLevel: LogLevelMessage.debug,
            appVersion: '5.0.38',
            clearTagsOnLogout: false,
            requiresUserConsent: true,
            openLaunchUrls: true,
            autoClearBadge: false,
            autoUpdateBadge: false,
            iosAppGroupIdentifier: 'group.sa.salla.example',
            iosApnsEnvironment: ApnsEnvironmentMessage.sandbox,
            iosRegisterForRemoteNotificationsOnInit: false,
          ),
        ],
      ]);
    });

    test('passes each boolean option alone, in its own field', () async {
      final List<(SallaPushConfig, ConfigMessage)> options =
          <(SallaPushConfig, ConfigMessage)>[
            (
              const SallaPushConfig(clearTagsOnLogout: false),
              ConfigMessage(clearTagsOnLogout: false),
            ),
            (
              const SallaPushConfig(requiresUserConsent: true),
              ConfigMessage(requiresUserConsent: true),
            ),
            (
              const SallaPushConfig(openLaunchUrls: true),
              ConfigMessage(openLaunchUrls: true),
            ),
            (
              const SallaPushConfig(autoClearBadge: false),
              ConfigMessage(autoClearBadge: false),
            ),
            (
              const SallaPushConfig(autoUpdateBadge: false),
              ConfigMessage(autoUpdateBadge: false),
            ),
            (
              const SallaPushConfig(
                ios: SallaPushIosConfig(
                  registerForRemoteNotificationsOnInit: false,
                ),
              ),
              ConfigMessage(iosRegisterForRemoteNotificationsOnInit: false),
            ),
          ];

      for (final (SallaPushConfig config, ConfigMessage _) in options) {
        await SallaPush.initialize('st_42', config: config);
      }

      expect(native.calls, <Object?>[
        for (final (SallaPushConfig _, ConfigMessage message) in options)
          <Object?>['initialize', 'st_42', message],
      ]);
    });

    test('keeps every option null by default', () async {
      await SallaPush.initialize('st_42_android');

      expect(native.calls, <Object?>[
        <Object?>['initialize', 'st_42_android', ConfigMessage()],
      ]);
    });

    test('passes the app id unchanged', () async {
      await SallaPush.initialize(' st_42 ');

      expect(native.calls.single[1], ' st_42 ');
    });

    test('maps every log level by case', () async {
      for (final SallaPushLogLevel level in SallaPushLogLevel.values) {
        await SallaPush.initialize(
          'st_42',
          config: SallaPushConfig(logLevel: level),
        );
      }

      expect(
        native.calls.map((List<Object?> call) {
          return (call[2]! as ConfigMessage).logLevel;
        }),
        <LogLevelMessage>[
          LogLevelMessage.off,
          LogLevelMessage.error,
          LogLevelMessage.warn,
          LogLevelMessage.info,
          LogLevelMessage.debug,
          LogLevelMessage.verbose,
        ],
      );
    });

    test('maps every APNs environment by case', () async {
      for (final SallaPushApnsEnvironment environment
          in SallaPushApnsEnvironment.values) {
        await SallaPush.initialize(
          'st_42_ios',
          config: SallaPushConfig(
            ios: SallaPushIosConfig(apnsEnvironment: environment),
          ),
        );
      }

      expect(
        native.calls.map((List<Object?> call) {
          return (call[2]! as ConfigMessage).iosApnsEnvironment;
        }),
        <ApnsEnvironmentMessage>[
          ApnsEnvironmentMessage.automatic,
          ApnsEnvironmentMessage.sandbox,
          ApnsEnvironmentMessage.production,
        ],
      );
    });
  });

  test(
    'isInitialized, appId and sdkVersion read native at every call',
    () async {
      native
        ..isInitializedResult = true
        ..appIdResult = 'st_42_ios'
        ..sdkVersionResult = '1.0.2';

      expect(await SallaPush.isInitialized, isTrue);
      expect(await SallaPush.appId, 'st_42_ios');
      expect(await SallaPush.sdkVersion, '1.0.2');

      native
        ..isInitializedResult = false
        ..appIdResult = null;

      expect(await SallaPush.isInitialized, isFalse);
      expect(await SallaPush.appId, isNull);
      expect(native.calls, <Object?>[
        <Object?>['isInitialized'],
        <Object?>['appId'],
        <Object?>['sdkVersion'],
        <Object?>['isInitialized'],
        <Object?>['appId'],
      ]);
    },
  );

  test('setConsentRequired and setConsentGiven pass true and false', () async {
    await SallaPush.setConsentRequired(true);
    await SallaPush.setConsentRequired(false);
    await SallaPush.setConsentGiven(true);
    await SallaPush.setConsentGiven(false);

    expect(native.calls, <Object?>[
      <Object?>['setConsentRequired', true],
      <Object?>['setConsentRequired', false],
      <Object?>['setConsentGiven', true],
      <Object?>['setConsentGiven', false],
    ]);
  });

  test('login passes both arguments untrimmed', () async {
    await SallaPush.login(externalId: ' 42 ', identityToken: ' token ');

    expect(native.calls, <Object?>[
      <Object?>['login', ' 42 ', ' token '],
    ]);
  });

  test('logout', () async {
    await SallaPush.logout();

    expect(native.calls, <Object?>[
      <Object?>['logout'],
    ]);
  });

  group('the plugin channels', () {
    const String channelPrefix =
        'dev.flutter.pigeon.mobile_push.SallaPushHostApi';
    const MessageCodec<Object?> codec = SallaPushHostApi.pigeonChannelCodec;
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() {
      SallaPushChannels.debugOverride = null;
    });

    void answer(String method, Object? result, [List<Object?>? received]) {
      messenger.setMockMessageHandler('$channelPrefix.$method', (
        ByteData? message,
      ) async {
        received?.add(codec.decodeMessage(message));
        return codec.encodeMessage(<Object?>[result]);
      });
      addTearDown(
        () => messenger.setMockMessageHandler('$channelPrefix.$method', null),
      );
    }

    test('send the calls and their arguments over Pigeon', () async {
      final List<Object?> received = <Object?>[];
      answer('initialize', null, received);
      answer('sdkVersion', '1.0.2');

      await SallaPush.initialize(
        'st_42_ios',
        config: const SallaPushConfig(logLevel: SallaPushLogLevel.info),
      );

      expect(received, <Object?>[
        <Object?>['st_42_ios', ConfigMessage(logLevel: LogLevelMessage.info)],
      ]);
      expect(await SallaPush.sdkVersion, '1.0.2');
    });

    test('carry the tags maps and lists over Pigeon', () async {
      final List<Object?> received = <Object?>[];
      answer('addTags', null, received);
      answer('removeTags', null, received);
      answer('getTags', <String, String>{'tier': 'gold'});

      await SallaPush.user.addTags(<String, String>{'tier': 'gold'});
      await SallaPush.user.removeTags(<String>['city']);
      final Map<String, String> tags = await SallaPush.user.getTags();

      expect(received, <Object?>[
        <Object?>[
          <Object?, Object?>{'tier': 'gold'},
        ],
        <Object?>[
          <Object?>['city'],
        ],
      ]);
      expect(tags, <String, String>{'tier': 'gold'});
      expect(tags['tier'], 'gold');
    });

    test('carry the iOS permission status over Pigeon', () async {
      answer('permissionStatus', IosPermissionStatusMessage.provisional);

      expect(
        await SallaPush.notifications.permissionStatus,
        SallaPushIosPermissionStatus.provisional,
      );
    });

    test('carry taps over the Pigeon event channel', () async {
      messenger.setMockStreamHandler(
        const EventChannel(
          'dev.flutter.pigeon.mobile_push.SallaPushEventChannelApi.clickEvents',
          pigeonMethodCodec,
        ),
        MockStreamHandler.inline(
          onListen: (Object? arguments, MockStreamHandlerEventSink events) =>
              events.success(
                ClickEventMessage(
                  notification: NotificationMessage(
                    notificationId: 'msg_1',
                    additionalData: <String, Object?>{
                      'order': <String, Object?>{'id': 42},
                    },
                    rawPayload: <String, Object?>{'sp_v': '1'},
                    source: PayloadSourceMessage.native,
                    stringValues: <String, String>{},
                    intValues: <String, int>{},
                    boolValues: <String, bool>{},
                    numberValues: <String, Object>{},
                  ),
                  url: 'https://store.example.com/orders/42',
                ),
              ),
        ),
      );

      final SallaPushClickEvent event =
          await SallaPush.notifications.onClick.first;

      expect(event.notification.notificationId, 'msg_1');
      expect(event.notification.additionalData['order'], <String, Object?>{
        'id': 42,
      });
      expect(event.result.url, 'https://store.example.com/orders/42');
    });

    test('route each push subscription replay to its listener', () async {
      MockStreamHandlerEventSink? sink;
      messenger.setMockStreamHandler(
        const EventChannel(
          'dev.flutter.pigeon.mobile_push.SallaPushEventChannelApi.pushSubscriptionChanges',
          pigeonMethodCodec,
        ),
        MockStreamHandler.inline(
          onListen: (Object? arguments, MockStreamHandlerEventSink events) =>
              sink = events,
        ),
      );
      // Native replays the current state to each observer it adds.
      messenger.setMockMessageHandler(
        '$channelPrefix.addPushSubscriptionListener',
        (ByteData? message) async {
          final List<Object?> arguments =
              codec.decodeMessage(message)! as List<Object?>;
          final SubscriptionStateMessage state = SubscriptionStateMessage(
            id: 'device-1',
            optedIn: true,
          );
          sink?.success(
            SubscriptionChangedMessage(
              listenerId: arguments.single! as int,
              previous: state,
              current: state,
            ),
          );
          return codec.encodeMessage(<Object?>[null]);
        },
      );
      addTearDown(
        () => messenger.setMockMessageHandler(
          '$channelPrefix.addPushSubscriptionListener',
          null,
        ),
      );
      answer('removePushSubscriptionListener', null);
      final List<String?> first = <String?>[];
      final List<String?> second = <String?>[];

      final StreamSubscription<SallaPushSubscriptionChangedState> early =
          SallaPush.user.pushSubscription.onChange.listen(
            (SallaPushSubscriptionChangedState state) =>
                first.add(state.current.id),
          );
      await pumpEventQueue();
      final StreamSubscription<SallaPushSubscriptionChangedState> later =
          SallaPush.user.pushSubscription.onChange.listen(
            (SallaPushSubscriptionChangedState state) =>
                second.add(state.current.id),
          );
      await pumpEventQueue();

      expect(first, <String?>['device-1']);
      expect(second, <String?>['device-1']);
      await early.cancel();
      await later.cancel();
    });

    test('fail when the native plugin is missing', () async {
      await expectLater(
        SallaPush.isInitialized,
        throwsA(
          isA<PlatformException>().having(
            (PlatformException error) => error.code,
            'code',
            'channel-error',
          ),
        ),
      );
    });
  });
}
