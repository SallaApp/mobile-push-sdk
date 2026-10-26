import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_push/mobile_push.dart';
import 'package:mobile_push/src/mapping.dart';
import 'package:mobile_push/src/messages.g.dart';

/// A notification as the iOS plugin sends it: typed values of every kind.
NotificationMessage iosMessage() => NotificationMessage(
  notificationId: 'msg_1',
  title: 'Order shipped',
  subtitle: 'Today',
  body: 'Your order is on its way',
  imageUrl: 'https://cdn.example.com/order.png',
  launchUrl: 'https://store.example.com/orders/42',
  additionalData: <String, Object?>{'order_id': 42, 'express': true},
  rawPayload: <String, Object?>{
    'aps': <String, Object?>{'badge': 3},
    'sp_v': '1',
  },
  source: PayloadSourceMessage.compat,
  stringValues: <String, String>{'order_id': '42', 'express': 'true'},
  intValues: <String, int>{'order_id': 42, 'express': 1},
  boolValues: <String, bool>{'express': true},
  numberValues: <String, Object>{'order_id': 42, 'express': 1},
  sound: 'default',
  badge: 3,
  threadId: 'orders',
);

/// A notification as the Android plugin sends it: no numbers, Android fields.
NotificationMessage androidMessage() => NotificationMessage(
  notificationId: 'msg_2',
  additionalData: <String, Object?>{'order_id': '42', 'price': '9.5'},
  rawPayload: <String, Object?>{'sp_v': '1', 'order_id': '42'},
  source: PayloadSourceMessage.native,
  stringValues: <String, String>{'order_id': '42', 'price': '9.5'},
  intValues: <String, int>{'order_id': 42},
  boolValues: <String, bool>{},
  numberValues: <String, Object>{},
  androidNotificationId: -1408375307,
  collapseId: 'orders',
  channelId: 'updates',
);

void main() {
  group('a notification', () {
    test('keeps every field of the message', () {
      final SallaPushNotification notification = iosMessage().notification;

      expect(notification.notificationId, 'msg_1');
      expect(notification.title, 'Order shipped');
      expect(notification.subtitle, 'Today');
      expect(notification.body, 'Your order is on its way');
      expect(notification.imageUrl, 'https://cdn.example.com/order.png');
      expect(notification.launchUrl, 'https://store.example.com/orders/42');
      expect(notification.additionalData, <String, Object?>{
        'order_id': 42,
        'express': true,
      });
      expect(notification.rawPayload, <String, Object?>{
        'aps': <String, Object?>{'badge': 3},
        'sp_v': '1',
      });
      expect(notification.source, SallaPushPayloadSource.compat);
      expect(notification.sound, 'default');
      expect(notification.badge, 3);
      expect(notification.threadId, 'orders');
      expect(notification.androidNotificationId, isNull);
      expect(notification.collapseId, isNull);
      expect(notification.channelId, isNull);
    });

    test('keeps the Android fields and leaves the others null', () {
      final SallaPushNotification notification = androidMessage().notification;

      expect(notification.notificationId, 'msg_2');
      expect(notification.source, SallaPushPayloadSource.native);
      expect(notification.androidNotificationId, -1408375307);
      expect(notification.collapseId, 'orders');
      expect(notification.channelId, 'updates');
      for (final Object? field in <Object?>[
        notification.title,
        notification.subtitle,
        notification.body,
        notification.imageUrl,
        notification.launchUrl,
        notification.sound,
        notification.badge,
        notification.threadId,
      ]) {
        expect(field, isNull);
      }
    });

    test('gives nested JSON the types jsonDecode gives', () {
      final SallaPushNotification notification = NotificationMessage(
        additionalData: <String, Object?>{
          'order': <Object?, Object?>{
            'id': 42,
            'items': <Object?>[
              <Object?, Object?>{'sku': 'A1', 'tags': <Object?>[]},
              null,
            ],
          },
        },
        rawPayload: <String, Object?>{
          'custom': <Object?, Object?>{
            'a': <Object?, Object?>{'push_ref': 'msg_1'},
          },
        },
        source: PayloadSourceMessage.compat,
        stringValues: <String, String>{},
        intValues: <String, int>{},
        boolValues: <String, bool>{},
        numberValues: <String, Object>{},
      ).notification;

      final Map<String, Object?> order =
          notification.additionalData['order']! as Map<String, Object?>;
      final List<Object?> items = order['items']! as List<Object?>;
      final Map<String, Object?> item = items.first! as Map<String, Object?>;
      expect(order['id'], 42);
      expect(item, <String, Object?>{'sku': 'A1', 'tags': <Object?>[]});
      expect(items.last, isNull);
      expect(
        notification.rawPayload['custom'],
        isA<Map<String, Object?>>().having(
          (Map<String, Object?> custom) => custom['a'],
          'a',
          isA<Map<String, Object?>>(),
        ),
      );
    });

    test('is read-only, nested values included', () {
      final SallaPushNotification notification = NotificationMessage(
        additionalData: <String, Object?>{
          'order': <Object?, Object?>{
            'items': <Object?>['A1'],
          },
        },
        rawPayload: <String, Object?>{'sp_v': '1'},
        source: PayloadSourceMessage.native,
        stringValues: <String, String>{},
        intValues: <String, int>{},
        boolValues: <String, bool>{},
        numberValues: <String, Object>{},
      ).notification;
      final Map<String, Object?> order =
          notification.additionalData['order']! as Map<String, Object?>;

      expect(
        () => notification.additionalData['key'] = 'value',
        throwsUnsupportedError,
      );
      expect(() => notification.rawPayload.clear(), throwsUnsupportedError);
      expect(() => order['key'] = 'value', throwsUnsupportedError);
      expect(
        () => (order['items']! as List<Object?>).add('B2'),
        throwsUnsupportedError,
      );
    });

    test('decodes from the Pigeon codec with nested JSON', () {
      const MessageCodec<Object?> codec = SallaPushHostApi.pigeonChannelCodec;
      final NotificationMessage message = NotificationMessage(
        additionalData: <String, Object?>{
          'order': <String, Object?>{
            'items': <Object?>[
              <String, Object?>{'sku': 'A1'},
            ],
          },
        },
        rawPayload: <String, Object?>{'sp_v': '1'},
        source: PayloadSourceMessage.native,
        stringValues: <String, String>{'order': '{"items":[]}'},
        intValues: <String, int>{},
        boolValues: <String, bool>{},
        numberValues: <String, Object>{'price': 9.5},
      );

      final NotificationMessage decoded =
          codec.decodeMessage(codec.encodeMessage(message))!
              as NotificationMessage;
      final SallaPushNotification notification = decoded.notification;

      final Map<String, Object?> order =
          notification.additionalData['order']! as Map<String, Object?>;
      expect(
        (order['items']! as List<Object?>).single,
        isA<Map<String, Object?>>(),
      );
      expect(notification.getString('order'), '{"items":[]}');
      expect(notification.getNumber('price'), 9.5);
    });
  });

  group('the typed getters', () {
    test('read the values native gave for each key', () {
      final SallaPushNotification notification = iosMessage().notification;

      expect(notification.getString('order_id'), '42');
      expect(notification.getString('express'), 'true');
      expect(notification.getInt('order_id'), 42);
      expect(notification.getInt('express'), 1);
      expect(notification.getBool('express'), isTrue);
      expect(notification.getNumber('order_id'), 42);
      expect(notification.getNumber('order_id'), isA<int>());
    });

    test('return null for an absent key', () {
      final SallaPushNotification notification = iosMessage().notification;

      expect(notification.getString('absent'), isNull);
      expect(notification.getInt('absent'), isNull);
      expect(notification.getBool('absent'), isNull);
      expect(notification.getNumber('absent'), isNull);
    });

    test('return null for a key native could not convert', () {
      final SallaPushNotification notification = iosMessage().notification;

      expect(notification.additionalData, contains('order_id'));
      expect(notification.getBool('order_id'), isNull);
    });

    test('read doubles, and ignore values that are not numbers', () {
      final SallaPushNotification notification = NotificationMessage(
        additionalData: <String, Object?>{'price': 9.5, 'name': 'Tea'},
        rawPayload: <String, Object?>{},
        source: PayloadSourceMessage.compat,
        stringValues: <String, String>{'price': '9.5', 'name': 'Tea'},
        intValues: <String, int>{},
        boolValues: <String, bool>{},
        numberValues: <String, Object>{'price': 9.5, 'name': 'Tea'},
      ).notification;

      expect(notification.getNumber('price'), 9.5);
      expect(notification.getNumber('name'), isNull);
    });

    test('getNumber is null on Android, which sends no numbers', () {
      final SallaPushNotification notification = androidMessage().notification;

      expect(notification.getString('price'), '9.5');
      expect(notification.getInt('order_id'), 42);
      expect(notification.getInt('price'), isNull);
      expect(notification.getNumber('order_id'), isNull);
      expect(notification.getNumber('price'), isNull);
    });
  });

  test('maps every payload source and login failure by case', () {
    expect(
      PayloadSourceMessage.values.map(
        (PayloadSourceMessage source) => source.source,
      ),
      <SallaPushPayloadSource>[
        SallaPushPayloadSource.native,
        SallaPushPayloadSource.compat,
      ],
    );
    expect(
      LoginFailureMessage.values.map(
        (LoginFailureMessage failure) => failure.failure,
      ),
      <SallaPushLoginFailure>[
        SallaPushLoginFailure.tokenRejected,
        SallaPushLoginFailure.invalidRequest,
      ],
    );
  });

  test('a click keeps its notification, action and URL', () {
    final SallaPushClickEvent event = ClickEventMessage(
      notification: iosMessage(),
      actionId: 'track',
      url: 'https://store.example.com/orders/42',
    ).event;
    final SallaPushClickEvent tap = ClickEventMessage(
      notification: androidMessage(),
    ).event;

    expect(event.notification.notificationId, 'msg_1');
    expect(event.result.actionId, 'track');
    expect(event.result.url, 'https://store.example.com/orders/42');
    expect(tap.notification.notificationId, 'msg_2');
    expect(tap.result.actionId, isNull);
    expect(tap.result.url, isNull);
  });

  test('subscription and user changes keep previous and current', () {
    final SallaPushSubscriptionChangedState subscription =
        SubscriptionChangedMessage(
          listenerId: 1,
          previous: SubscriptionStateMessage(optedIn: false),
          current: SubscriptionStateMessage(
            id: 'device-1',
            token: 'ab12cd34',
            optedIn: true,
          ),
        ).state;
    final SallaPushUserChangedState user = UserChangedMessage(
      previous: UserStateMessage(isLoggedIn: false),
      current: UserStateMessage(externalId: '42', isLoggedIn: true),
    ).state;

    expect(subscription.previous.id, isNull);
    expect(subscription.previous.token, isNull);
    expect(subscription.previous.optedIn, isFalse);
    expect(subscription.current.id, 'device-1');
    expect(subscription.current.token, 'ab12cd34');
    expect(subscription.current.optedIn, isTrue);
    expect(user.previous.externalId, isNull);
    expect(user.previous.isLoggedIn, isFalse);
    expect(user.current.externalId, '42');
    expect(user.current.isLoggedIn, isTrue);
  });

  test('a log entry keeps every field, timestamped in UTC', () {
    final SallaPushLogEntry entry = LogEntryMessage(
      level: LogLevelMessage.error,
      category: 'identity',
      code: 'identity.token_rejected',
      message: 'The identity token was rejected; log in again.',
      metadata: <String, String>{'http_status': '403'},
      timestampMillis: 0,
    ).entry;

    expect(entry.level, SallaPushLogLevel.error);
    expect(entry.category, 'identity');
    expect(entry.code, 'identity.token_rejected');
    expect(entry.message, 'The identity token was rejected; log in again.');
    expect(entry.metadata, <String, String>{'http_status': '403'});
    expect(() => entry.metadata['reason'] = 'x', throwsUnsupportedError);
    expect(entry.timestamp, DateTime.utc(1970));
    expect(
      entry.toString(),
      'SallaPushLogEntry(level: error, category: identity, '
      'code: identity.token_rejected, '
      'message: The identity token was rejected; log in again., '
      'metadata: {http_status: 403}, timestamp: 1970-01-01T00:00:00.000Z)',
    );
  });

  group('toString', () {
    test('describes notifications and taps', () {
      final SallaPushClickEvent event = ClickEventMessage(
        notification: iosMessage(),
        url: 'https://store.example.com/orders/42',
      ).event;

      expect(
        event.toString(),
        allOf(
          startsWith(
            'SallaPushClickEvent(notification: SallaPushNotification(',
          ),
          contains('notificationId: msg_1'),
          contains('source: compat'),
          contains('additionalData: {order_id: 42, express: true}'),
          contains(
            'SallaPushClickResult(actionId: null, '
            'url: https://store.example.com/orders/42)',
          ),
        ),
      );
    });

    test('shows only the last 6 characters of a push token', () {
      SallaPushSubscriptionState state(String? token) =>
          SubscriptionChangedMessage(
            listenerId: 1,
            previous: SubscriptionStateMessage(optedIn: false),
            current: SubscriptionStateMessage(
              id: 'device-1',
              token: token,
              optedIn: true,
            ),
          ).state.current;

      expect(
        state('0a1b2c3d4e5f6a7b').toString(),
        'SallaPushSubscriptionState(id: device-1, token: …5f6a7b, '
        'optedIn: true)',
      );
      expect(state('5f6a7b').toString(), contains('token: …5f6a7b,'));
      expect(state('6a7b').toString(), contains('token: …6a7b,'));
      expect(state(null).toString(), contains('token: null,'));
    });

    test('describes user and subscription changes', () {
      final SallaPushUserChangedState user = UserChangedMessage(
        previous: UserStateMessage(isLoggedIn: false),
        current: UserStateMessage(externalId: '42', isLoggedIn: true),
      ).state;
      final SallaPushSubscriptionChangedState subscription =
          SubscriptionChangedMessage(
            listenerId: 1,
            previous: SubscriptionStateMessage(optedIn: false),
            current: SubscriptionStateMessage(optedIn: true),
          ).state;

      expect(
        user.toString(),
        'SallaPushUserChangedState('
        'previous: SallaPushUserState(externalId: null, isLoggedIn: false), '
        'current: SallaPushUserState(externalId: 42, isLoggedIn: true))',
      );
      expect(
        subscription.toString(),
        'SallaPushSubscriptionChangedState('
        'previous: SallaPushSubscriptionState(id: null, token: null, '
        'optedIn: false), '
        'current: SallaPushSubscriptionState(id: null, token: null, '
        'optedIn: true))',
      );
    });
  });
}
