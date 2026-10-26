import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_push/mobile_push.dart';
import 'package:mobile_push/src/channels.dart';
import 'package:mobile_push/src/messages.g.dart';

import 'fakes/fake_channels.dart';

WillDisplayEventMessage willDisplay(String handle) => WillDisplayEventMessage(
  handle: handle,
  notification: NotificationMessage(
    notificationId: 'msg_1',
    title: 'New message',
    body: 'Are you there?',
    additionalData: <String, Object?>{'chat_id': '7'},
    rawPayload: <String, Object?>{'sp_v': '1', 'chat_id': '7'},
    source: PayloadSourceMessage.native,
    stringValues: <String, String>{'chat_id': '7'},
    intValues: <String, int>{'chat_id': 7},
    boolValues: <String, bool>{},
    numberValues: <String, Object>{'chat_id': 7},
  ),
);

void main() {
  final SallaPushNotifications notifications = SallaPush.notifications;
  late FakeChannels native;
  final List<StreamSubscription<SallaPushWillDisplayEvent>> subscriptions =
      <StreamSubscription<SallaPushWillDisplayEvent>>[];

  setUp(() {
    native = FakeChannels();
    SallaPushChannels.debugOverride = native;
  });

  tearDown(() async {
    for (final StreamSubscription<SallaPushWillDisplayEvent> subscription
        in subscriptions) {
      await subscription.cancel();
    }
    subscriptions.clear();
    SallaPushChannels.debugOverride = null;
  });

  void listen(void Function(SallaPushWillDisplayEvent event) listener) {
    subscriptions.add(notifications.onWillDisplay.listen(listener));
  }

  List<Object?> displays() => native.calls
      .where((List<Object?> call) => call.first == 'displayNotification')
      .toList();

  test('shows a notification no listener prevented, once', () async {
    listen((_) {});

    native.willDisplays.emit(willDisplay('handle-1'));
    await pumpEventQueue();

    expect(displays(), <Object?>[
      <Object?>['displayNotification', 'handle-1'],
    ]);
  });

  test('keeps a notification one of two listeners prevented', () async {
    final List<SallaPushWillDisplayEvent> seen = <SallaPushWillDisplayEvent>[];
    listen(seen.add);
    listen((SallaPushWillDisplayEvent event) {
      seen.add(event);
      event.preventDefault();
    });

    native.willDisplays.emit(willDisplay('handle-1'));
    await pumpEventQueue();

    expect(seen, hasLength(2));
    expect(seen.last, same(seen.first));
    expect(seen.first.isPrevented, isTrue);
    expect(displays(), isEmpty);
  });

  test('runs the listeners in order and decides once they returned', () async {
    final List<String> order = <String>[];
    listen((SallaPushWillDisplayEvent event) {
      order.add('first, prevented: ${event.isPrevented}');
      event.preventDefault();
    });
    listen((SallaPushWillDisplayEvent event) {
      order.add('second, prevented: ${event.isPrevented}');
      expect(displays(), isEmpty);
    });

    native.willDisplays.emit(willDisplay('handle-1'));
    await pumpEventQueue();

    expect(order, <String>[
      'first, prevented: false',
      'second, prevented: true',
    ]);
    expect(displays(), isEmpty);
  });

  test('a preventDefault after an await comes too late', () async {
    listen((SallaPushWillDisplayEvent event) async {
      await Future<void>.value();
      event.preventDefault();
    });

    native.willDisplays.emit(willDisplay('handle-1'));
    await pumpEventQueue();

    expect(displays(), <Object?>[
      <Object?>['displayNotification', 'handle-1'],
    ]);
  });

  test(
    'a throwing listener stops neither the others nor the decision',
    () async {
      final List<Object> errors = <Object>[];
      final List<String> ran = <String>[];
      runZonedGuarded(
        () => listen((_) => throw StateError('listener failed')),
        (Object error, StackTrace stack) => errors.add(error),
      );
      listen((_) => ran.add('second'));

      native.willDisplays.emit(willDisplay('handle-1'));
      await pumpEventQueue();

      expect(errors, <Matcher>[isStateError]);
      expect(ran, <String>['second']);
      expect(displays(), <Object?>[
        <Object?>['displayNotification', 'handle-1'],
      ]);
    },
  );

  test(
    'shows a notification whose listeners were all gone once they returned',
    () async {
      final Future<SallaPushWillDisplayEvent> first =
          notifications.onWillDisplay.first;

      native.willDisplays.emit(willDisplay('handle-1'));
      await pumpEventQueue();

      expect((await first).notification.notificationId, 'msg_1');
      expect(native.willDisplays.isListening, isFalse);
      expect(displays(), <Object?>[
        <Object?>['displayNotification', 'handle-1'],
      ]);
    },
  );

  test('a prevented notification is shown by a later display()', () async {
    final List<SallaPushWillDisplayEvent> events =
        <SallaPushWillDisplayEvent>[];
    listen((SallaPushWillDisplayEvent event) {
      event.preventDefault();
      events.add(event);
    });

    native.willDisplays
      ..emit(willDisplay('handle-1'))
      ..emit(willDisplay('handle-2'));
    await pumpEventQueue();
    expect(displays(), isEmpty);

    await events.last.notification.display();
    await events.first.notification.display();

    expect(displays(), <Object?>[
      <Object?>['displayNotification', 'handle-2'],
      <Object?>['displayNotification', 'handle-1'],
    ]);
  });

  test(
    'display() before any listener prevented shows nothing, as natively',
    () async {
      final List<String?> printed = <String?>[];
      final DebugPrintCallback print = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => printed.add(message);
      addTearDown(() => debugPrint = print);
      listen((SallaPushWillDisplayEvent event) {
        unawaited(event.notification.display());
      });
      listen((SallaPushWillDisplayEvent event) => event.preventDefault());

      native.willDisplays.emit(willDisplay('handle-1'));
      await pumpEventQueue();

      expect(displays(), isEmpty);
      expect(printed, <String>[
        '[SallaPush] display() did nothing: the notification was not '
            'prevented. Call event.preventDefault() first.',
      ]);
    },
  );

  test(
    'display() of a notification nobody prevented shows it no second time',
    () async {
      final List<SallaPushWillDisplayEvent> events =
          <SallaPushWillDisplayEvent>[];
      final DebugPrintCallback print = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {};
      addTearDown(() => debugPrint = print);
      listen(events.add);

      native.willDisplays.emit(willDisplay('handle-1'));
      await pumpEventQueue();
      await events.single.notification.display();

      expect(displays(), <Object?>[
        <Object?>['displayNotification', 'handle-1'],
      ]);
    },
  );

  test(
    'preventDefault() then display() in one listener shows it once',
    () async {
      listen((SallaPushWillDisplayEvent event) {
        event.preventDefault();
        unawaited(event.notification.display());
      });

      native.willDisplays.emit(willDisplay('handle-1'));
      await pumpEventQueue();

      expect(displays(), <Object?>[
        <Object?>['displayNotification', 'handle-1'],
      ]);
    },
  );

  test('display() of a tapped notification asks nothing of native', () async {
    final List<String?> printed = <String?>[];
    final DebugPrintCallback print = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => printed.add(message);
    addTearDown(() => debugPrint = print);
    final List<SallaPushClickEvent> taps = <SallaPushClickEvent>[];
    final StreamSubscription<SallaPushClickEvent> subscription = notifications
        .onClick
        .listen(taps.add);
    addTearDown(subscription.cancel);
    native.clicks.emit(
      ClickEventMessage(notification: willDisplay('handle-1').notification),
    );
    await pumpEventQueue();

    await taps.single.notification.display();

    expect(displays(), isEmpty);
    expect(printed, <String>[
      '[SallaPush] display() does nothing for a notification that '
          'onWillDisplay did not offer.',
    ]);
  });

  test('offers the notification with every field', () async {
    final List<SallaPushWillDisplayEvent> events =
        <SallaPushWillDisplayEvent>[];
    listen(events.add);

    native.willDisplays.emit(willDisplay('handle-1'));
    await pumpEventQueue();

    final SallaPushNotification notification = events.single.notification;
    expect(notification.notificationId, 'msg_1');
    expect(notification.title, 'New message');
    expect(notification.body, 'Are you there?');
    expect(notification.additionalData, <String, Object?>{'chat_id': '7'});
    expect(notification.source, SallaPushPayloadSource.native);
    expect(notification.getInt('chat_id'), 7);
    expect(
      events.single.toString(),
      allOf(
        startsWith('SallaPushWillDisplayEvent(notification: '),
        endsWith('isPrevented: false)'),
      ),
    );
  });

  test('gives platform errors to the listeners', () async {
    final List<Object> errors = <Object>[];
    subscriptions.add(
      notifications.onWillDisplay.listen((_) {}, onError: errors.add),
    );

    native.willDisplays.emitError(PlatformException(code: 'error'));
    await pumpEventQueue();

    expect(errors, <Matcher>[isA<PlatformException>()]);
  });

  test('reports a failed display as Flutter reports a failed listen', () async {
    final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
    final FlutterExceptionHandler? onError = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = onError);
    native.failing.add('displayNotification');
    listen((_) {});

    native.willDisplays.emit(willDisplay('handle-1'));
    await pumpEventQueue();

    expect(
      reported.map((FlutterErrorDetails details) => '${details.context}'),
      <String>['while showing a foreground notification'],
    );
  });

  test('listens on the platform lazily', () async {
    await expectListensLazily(
      () => notifications.onWillDisplay,
      native.willDisplays,
    );
  });
}
