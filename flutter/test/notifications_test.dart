import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_push/mobile_push.dart';
import 'package:mobile_push/src/channels.dart';
import 'package:mobile_push/src/messages.g.dart';

import 'fakes/fake_channels.dart';

NotificationMessage notificationMessage(String notificationId) =>
    NotificationMessage(
      notificationId: notificationId,
      additionalData: <String, Object?>{'order_id': '42'},
      rawPayload: <String, Object?>{'sp_v': '1', 'order_id': '42'},
      source: PayloadSourceMessage.native,
      stringValues: <String, String>{'order_id': '42'},
      intValues: <String, int>{'order_id': 42},
      boolValues: <String, bool>{},
      numberValues: <String, Object>{'order_id': 42},
    );

void main() {
  final SallaPushNotifications notifications = SallaPush.notifications;
  late FakeChannels native;

  setUp(() {
    native = FakeChannels();
    SallaPushChannels.debugOverride = native;
  });

  tearDown(() {
    SallaPushChannels.debugOverride = null;
  });

  test(
    'permission and canRequestPermission read native at every call',
    () async {
      native
        ..permissionResult = true
        ..canRequestPermissionResult = false;

      expect(await notifications.permission, isTrue);
      expect(await notifications.canRequestPermission(), isFalse);

      native
        ..permissionResult = false
        ..canRequestPermissionResult = true;

      expect(await notifications.permission, isFalse);
      expect(await notifications.canRequestPermission(), isTrue);
      expect(native.calls, <Object?>[
        <Object?>['permission'],
        <Object?>['canRequestPermission'],
        <Object?>['permission'],
        <Object?>['canRequestPermission'],
      ]);
    },
  );

  test('permissionStatus maps every status by case, and null', () async {
    final List<SallaPushIosPermissionStatus?> statuses =
        <SallaPushIosPermissionStatus?>[];
    for (final IosPermissionStatusMessage? status
        in <IosPermissionStatusMessage?>[
          ...IosPermissionStatusMessage.values,
          null,
        ]) {
      native.permissionStatusResult = status;
      statuses.add(await notifications.permissionStatus);
    }

    expect(statuses, <SallaPushIosPermissionStatus?>[
      SallaPushIosPermissionStatus.notDetermined,
      SallaPushIosPermissionStatus.denied,
      SallaPushIosPermissionStatus.authorized,
      SallaPushIosPermissionStatus.provisional,
      SallaPushIosPermissionStatus.ephemeral,
      null,
    ]);
  });

  test('requestPermission falls back to settings only when asked', () async {
    native.requestPermissionResult = true;

    expect(await notifications.requestPermission(), isTrue);
    expect(
      await notifications.requestPermission(fallbackToSettings: true),
      isTrue,
    );
    expect(native.calls, <Object?>[
      <Object?>['requestPermission', false],
      <Object?>['requestPermission', true],
    ]);
  });

  test('requestPermission completes with the native answer', () async {
    native.requestPermissionResult = false;

    expect(await notifications.requestPermission(), isFalse);
  });

  test('registerForProvisionalAuthorization completes with native', () async {
    native.registerForProvisionalAuthorizationResult = true;
    expect(await notifications.registerForProvisionalAuthorization(), isTrue);

    native.registerForProvisionalAuthorizationResult = false;
    expect(await notifications.registerForProvisionalAuthorization(), isFalse);
  });

  test('refresh, register, token, clear and remove reach native', () async {
    await notifications.refreshPermission();
    await notifications.registerForRemoteNotifications();
    await notifications.forwardApnsToken('AB12CD34');
    await notifications.clearAll();
    await notifications.removeNotification(-1408375307);

    expect(native.calls, <Object?>[
      <Object?>['refreshPermission'],
      <Object?>['registerForRemoteNotifications'],
      <Object?>['forwardApnsToken', 'AB12CD34'],
      <Object?>['clearAll'],
      <Object?>['removeNotification', -1408375307],
    ]);
  });

  test('isSallaPushNotification forwards the map unchanged', () async {
    final Map<String, Object?> payload = <String, Object?>{
      'sp_v': '1',
      'custom': <String, Object?>{
        'i': 'f6b1',
        'a': <String, Object?>{'push_ref': 'msg_1'},
      },
      'count': 2,
      'note': null,
    };
    native.isSallaPushNotificationResult = true;

    expect(await notifications.isSallaPushNotification(payload), isTrue);
    expect(native.calls, <Object?>[
      <Object?>['isSallaPushNotification', payload],
    ]);
  });

  test('trackOpened forwards a map and null', () async {
    native.trackOpenedResult = true;

    expect(
      await notifications.trackOpened(<String, Object?>{'push_ref': 'msg_1'}),
      isTrue,
    );

    native.trackOpenedResult = false;

    expect(await notifications.trackOpened(null), isFalse);
    expect(native.calls, <Object?>[
      <Object?>[
        'trackOpened',
        <String, Object?>{'push_ref': 'msg_1'},
      ],
      <Object?>['trackOpened', null],
    ]);
  });

  group('onClick', () {
    test('maps each tap, null fields included', () async {
      final List<SallaPushClickEvent> events = <SallaPushClickEvent>[];
      final StreamSubscription<SallaPushClickEvent> subscription = notifications
          .onClick
          .listen(events.add);

      native.clicks.emit(
        ClickEventMessage(
          notification: notificationMessage('msg_1'),
          actionId: 'track',
          url: 'https://store.example.com/orders/42',
        ),
      );
      native.clicks.emit(
        ClickEventMessage(notification: notificationMessage('msg_2')),
      );
      await pumpEventQueue();

      expect(events, hasLength(2));
      expect(events.first.notification.notificationId, 'msg_1');
      expect(events.first.notification.additionalData, <String, Object?>{
        'order_id': '42',
      });
      expect(events.first.notification.getInt('order_id'), 42);
      expect(events.first.result.actionId, 'track');
      expect(events.first.result.url, 'https://store.example.com/orders/42');
      expect(events.last.notification.notificationId, 'msg_2');
      expect(events.last.notification.title, isNull);
      expect(events.last.result.actionId, isNull);
      expect(events.last.result.url, isNull);
      await subscription.cancel();
    });

    test('gives every listener each tap, in registration order', () async {
      final List<String> received = <String>[];
      final List<StreamSubscription<SallaPushClickEvent>> subscriptions =
          <StreamSubscription<SallaPushClickEvent>>[
            for (final String listener in <String>['first', 'second'])
              notifications.onClick.listen(
                (SallaPushClickEvent event) => received.add(
                  '$listener ${event.notification.notificationId}',
                ),
              ),
          ];

      native.clicks
        ..emit(ClickEventMessage(notification: notificationMessage('msg_1')))
        ..emit(ClickEventMessage(notification: notificationMessage('msg_2')));
      await pumpEventQueue();

      expect(received, <String>[
        'first msg_1',
        'second msg_1',
        'first msg_2',
        'second msg_2',
      ]);
      for (final StreamSubscription<SallaPushClickEvent> subscription
          in subscriptions) {
        await subscription.cancel();
      }
    });

    test('listens on the platform lazily', () async {
      await expectListensLazily(() => notifications.onClick, native.clicks);
    });
  });

  group('onPermissionChange', () {
    test('maps each change', () async {
      final List<bool> changes = <bool>[];
      final StreamSubscription<bool> subscription = notifications
          .onPermissionChange
          .listen(changes.add);

      native.permissions
        ..emit(PermissionChangeMessage(permission: true))
        ..emit(PermissionChangeMessage(permission: false));
      await pumpEventQueue();

      expect(changes, <bool>[true, false]);
      await subscription.cancel();
    });

    test('listens on the platform lazily', () async {
      await expectListensLazily(
        () => notifications.onPermissionChange,
        native.permissions,
      );
    });
  });
}
