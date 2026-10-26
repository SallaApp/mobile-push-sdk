import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_push/mobile_push.dart';
import 'package:mobile_push/src/channels.dart';
import 'package:mobile_push/src/messages.g.dart';

import 'fakes/fake_channels.dart';

SubscriptionChangedMessage change(
  int listenerId, {
  String? previousId,
  String? id,
  bool optedIn = true,
}) => SubscriptionChangedMessage(
  listenerId: listenerId,
  previous: SubscriptionStateMessage(id: previousId, optedIn: optedIn),
  current: SubscriptionStateMessage(
    id: id,
    token: 'ab12cd34',
    optedIn: optedIn,
  ),
);

void main() {
  final SallaPushSubscription subscription = SallaPush.user.pushSubscription;
  late FakeChannels native;

  setUp(() {
    native = FakeChannels();
    SallaPushChannels.debugOverride = native;
  });

  tearDown(() {
    SallaPushChannels.debugOverride = null;
  });

  test('id, token and optedIn read native at every call', () async {
    native
      ..pushSubscriptionIdResult = '7d1b2c4e-5f60-4a8b-9c0d-1e2f3a4b5c6d'
      ..pushSubscriptionTokenResult = 'ab12cd34'
      ..pushSubscriptionOptedInResult = true;

    expect(await subscription.id, '7d1b2c4e-5f60-4a8b-9c0d-1e2f3a4b5c6d');
    expect(await subscription.token, 'ab12cd34');
    expect(await subscription.optedIn, isTrue);

    native
      ..pushSubscriptionIdResult = null
      ..pushSubscriptionTokenResult = null
      ..pushSubscriptionOptedInResult = false;

    expect(await subscription.id, isNull);
    expect(await subscription.token, isNull);
    expect(await subscription.optedIn, isFalse);
    expect(native.calls, <Object?>[
      <Object?>['pushSubscriptionId'],
      <Object?>['pushSubscriptionToken'],
      <Object?>['pushSubscriptionOptedIn'],
      <Object?>['pushSubscriptionId'],
      <Object?>['pushSubscriptionToken'],
      <Object?>['pushSubscriptionOptedIn'],
    ]);
  });

  test('optIn and optOut', () async {
    await subscription.optOut();
    await subscription.optIn();

    expect(native.calls, <Object?>[
      <Object?>['optOut'],
      <Object?>['optIn'],
    ]);
  });

  group('onChange', () {
    test('maps the previous and the current state', () async {
      final List<SallaPushSubscriptionChangedState> changes =
          <SallaPushSubscriptionChangedState>[];
      final StreamSubscription<SallaPushSubscriptionChangedState> listener =
          subscription.onChange.listen(changes.add);

      native.subscriptions.emit(
        SubscriptionChangedMessage(
          listenerId: 1,
          previous: SubscriptionStateMessage(optedIn: false),
          current: SubscriptionStateMessage(
            id: 'device-1',
            token: 'ab12cd34',
            optedIn: true,
          ),
        ),
      );
      await pumpEventQueue();

      final SallaPushSubscriptionChangedState state = changes.single;
      expect(state.previous.id, isNull);
      expect(state.previous.token, isNull);
      expect(state.previous.optedIn, isFalse);
      expect(state.current.id, 'device-1');
      expect(state.current.token, 'ab12cd34');
      expect(state.current.optedIn, isTrue);
      await listener.cancel();
    });

    test(
      'adds a native observer for each listener, after the platform listen',
      () async {
        final StreamSubscription<SallaPushSubscriptionChangedState> first =
            subscription.onChange.listen((_) {});
        final StreamSubscription<SallaPushSubscriptionChangedState> second =
            subscription.onChange.listen((_) {});
        await first.cancel();
        await second.cancel();
        final StreamSubscription<SallaPushSubscriptionChangedState> third =
            subscription.onChange.listen((_) {});
        await third.cancel();

        expect(native.calls, <Object?>[
          <Object?>['listen', 'pushSubscriptionChanges'],
          <Object?>['addPushSubscriptionListener', 1],
          <Object?>['addPushSubscriptionListener', 2],
          <Object?>['removePushSubscriptionListener', 1],
          <Object?>['removePushSubscriptionListener', 2],
          <Object?>['cancel', 'pushSubscriptionChanges'],
          <Object?>['listen', 'pushSubscriptionChanges'],
          <Object?>['addPushSubscriptionListener', 3],
          <Object?>['removePushSubscriptionListener', 3],
          <Object?>['cancel', 'pushSubscriptionChanges'],
        ]);
      },
    );

    test('gives each event only to the listener whose id it carries', () async {
      final List<String?> first = <String?>[];
      final List<String?> second = <String?>[];
      final List<StreamSubscription<SallaPushSubscriptionChangedState>>
      listeners = <StreamSubscription<SallaPushSubscriptionChangedState>>[
        subscription.onChange.listen(
          (SallaPushSubscriptionChangedState state) =>
              first.add(state.current.id),
        ),
        subscription.onChange.listen(
          (SallaPushSubscriptionChangedState state) =>
              second.add(state.current.id),
        ),
      ];

      native.subscriptions
        ..emit(change(2, id: 'for-second'))
        ..emit(change(1, id: 'for-first'))
        ..emit(change(3, id: 'for-nobody'));
      await pumpEventQueue();

      expect(first, <String?>['for-first']);
      expect(second, <String?>['for-second']);
      for (final StreamSubscription<SallaPushSubscriptionChangedState> listener
          in listeners) {
        await listener.cancel();
      }
    });

    test(
      'a listener added later gets its own replay, the first none',
      () async {
        final List<SallaPushSubscriptionChangedState> first =
            <SallaPushSubscriptionChangedState>[];
        final List<SallaPushSubscriptionChangedState> second =
            <SallaPushSubscriptionChangedState>[];
        final StreamSubscription<SallaPushSubscriptionChangedState> early =
            subscription.onChange.listen(first.add);
        // Native replays the current state to each new observer.
        native.subscriptions.emit(
          change(1, previousId: 'device-1', id: 'device-1'),
        );
        await pumpEventQueue();

        final StreamSubscription<SallaPushSubscriptionChangedState> later =
            subscription.onChange.listen(second.add);
        native.subscriptions.emit(
          change(2, previousId: 'device-1', id: 'device-1'),
        );
        await pumpEventQueue();

        expect(first, hasLength(1));
        expect(second, hasLength(1));
        expect(second.single.previous.id, second.single.current.id);
        expect(native.subscriptions.listens, 1);
        await early.cancel();
        await later.cancel();
      },
    );

    test('gives platform errors to every listener', () async {
      final List<Object> errors = <Object>[];
      final List<StreamSubscription<SallaPushSubscriptionChangedState>>
      listeners = <StreamSubscription<SallaPushSubscriptionChangedState>>[
        for (int i = 0; i < 2; i++)
          subscription.onChange.listen((_) {}, onError: errors.add),
      ];

      native.subscriptions.emitError(PlatformException(code: 'error'));
      await pumpEventQueue();

      expect(errors, hasLength(2));
      for (final StreamSubscription<SallaPushSubscriptionChangedState> listener
          in listeners) {
        await listener.cancel();
      }
    });

    test(
      'reports failed host calls as Flutter reports a failed listen',
      () async {
        final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
        final FlutterExceptionHandler? onError = FlutterError.onError;
        FlutterError.onError = reported.add;
        addTearDown(() => FlutterError.onError = onError);
        native.failing.addAll(<String>[
          'addPushSubscriptionListener',
          'removePushSubscriptionListener',
        ]);

        final StreamSubscription<SallaPushSubscriptionChangedState> listener =
            subscription.onChange.listen((_) {});
        await pumpEventQueue();
        await listener.cancel();

        expect(
          reported.map((FlutterErrorDetails details) => '${details.context}'),
          <String>[
            'while adding a push subscription listener',
            'while removing a push subscription listener',
          ],
        );
        expect(reported.first.exception, isA<PlatformException>());
        expect(reported.first.library, 'mobile_push');
        expect(native.subscriptions.isListening, isFalse);
      },
    );

    test('listens on the platform lazily', () async {
      await expectListensLazily(
        () => subscription.onChange,
        native.subscriptions,
      );
    });
  });
}
