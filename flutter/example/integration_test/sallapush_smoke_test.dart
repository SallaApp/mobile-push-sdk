// Smoke tests of SallaPush through the plugin and the native SDKs, on a
// simulator or an emulator: flutter test integration_test -d <device>.
//
// They need the smoke configuration, with a made-up app id:
// - iOS: ios/Flutter/SallaPush.smoke.xcconfig with
//   SALLAPUSH_APP_ID = example_smoke
// - Android: the environment variable
//   ORG_GRADLE_PROJECT_sallapushAppId=example_smoke
//
// A case that would show the system permission prompt is skipped: grant the
// permission beforehand to run it (Android: install with adb install -g).

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_push/mobile_push.dart';
import 'package:sallapush_flutter_example/main.dart' as example;

import 'test_notification.dart';

const String _smokeAppId = 'example_smoke';
const Duration _eventTimeout = Duration(seconds: 20);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final String? appId = await SallaPush.appId;
    if (appId != _smokeAppId) {
      throw StateError(
        'SallaPush runs with the app id $appId: the smoke tests run only with '
        'the smoke configuration (app id $_smokeAppId), described at the top '
        'of this file.',
      );
    }
    // Quiet notifications, granted without a prompt, let iOS deliver the test
    // notification. On Android it does nothing.
    await SallaPush.notifications.registerForProvisionalAuthorization();
  });

  testWidgets('SallaPush started natively from the static configuration', (
    WidgetTester tester,
  ) async {
    expect(await SallaPush.isInitialized, isTrue);
    expect(await SallaPush.appId, _smokeAppId);
    expect(await SallaPush.sdkVersion, matches(RegExp(r'^\d+\.\d+\.\d+')));
  });

  testWidgets(
    'a foreground notification reaches onWillDisplay with native values',
    (WidgetTester tester) async {
      if (Platform.isIOS && !await SallaPush.notifications.permission) {
        markTestSkipped(
          'iOS delivers the test notification only while notifications are '
          'allowed, and they are not.',
        );
        return;
      }
      if (!await SallaPush.notifications.canRequestPermission()) {
        // Clears an opt-out an earlier run left; it prompts otherwise.
        await SallaPush.user.pushSubscription.optIn();
      }
      final List<SallaPushWillDisplayEvent> events =
          <SallaPushWillDisplayEvent>[];
      final StreamSubscription<SallaPushWillDisplayEvent> listener = SallaPush
          .notifications
          .onWillDisplay
          .listen(events.add);
      addTearDown(listener.cancel);

      final Object? delivered = await deliverTestNotification();
      await _eventually(() => events.isNotEmpty);

      expect(delivered, Platform.isAndroid ? isTrue : isNull);
      final SallaPushNotification notification = events.single.notification;
      expect(notification.title, 'SallaPush test');
      expect(notification.body, 'A native SallaPush notification');
      expect(notification.notificationId, 'msg_5a11a90001');
      expect(notification.launchUrl, 'https://example.com/products/42');
      expect(notification.source, SallaPushPayloadSource.native);
      expect(notification.additionalData, <String, Object?>{
        'type': 'product',
        'id': '42',
        'in_stock': 'true',
      });
      expect(
        <Object?>[
          notification.getString('type'),
          notification.getInt('type'),
          notification.getBool('type'),
          notification.getString('id'),
          notification.getInt('id'),
          notification.getBool('id'),
          notification.getString('in_stock'),
          notification.getInt('in_stock'),
          notification.getBool('in_stock'),
          notification.getString('missing'),
        ],
        <Object?>[
          'product',
          null,
          null,
          '42',
          42,
          null,
          'true',
          null,
          true,
          null,
        ],
      );
      expect(notification.getNumber('id'), Platform.isIOS ? 42 : isNull);
      expect(notification.getNumber('in_stock'), isNull);

      // Not prevented, so it shows; the copy iOS then shows is not offered.
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(events, hasLength(1));
      expect(events.single.isPrevented, isFalse);
    },
  );

  testWidgets('each stream subscribes and cancels, and delivers events', (
    WidgetTester tester,
  ) async {
    final List<StreamSubscription<Object?>> subscriptions =
        <StreamSubscription<Object?>>[
          SallaPush.notifications.onClick.listen((_) {}),
          SallaPush.notifications.onWillDisplay.listen((_) {}),
          SallaPush.notifications.onPermissionChange.listen((_) {}),
          SallaPush.user.onLoginFailure.listen((_) {}),
          SallaPush.user.pushSubscription.onChange.listen((_) {}),
        ];
    await SallaPush.logout();

    final Future<SallaPushUserChangedState> loggedIn = SallaPush.user.onChange
        .firstWhere(
          (SallaPushUserChangedState change) => change.current.isLoggedIn,
        )
        .timeout(_eventTimeout);
    await SallaPush.login(
      externalId: 'smoke_customer',
      identityToken: 'smoke-identity-token',
    );
    expect((await loggedIn).current.externalId, 'smoke_customer');

    final Future<SallaPushUserChangedState> loggedOut = SallaPush.user.onChange
        .firstWhere(
          (SallaPushUserChangedState change) => !change.current.isLoggedIn,
        )
        .timeout(_eventTimeout);
    await SallaPush.logout();
    expect((await loggedOut).previous.externalId, 'smoke_customer');

    final Completer<SallaPushLogEntry> invalidKey =
        Completer<SallaPushLogEntry>();
    await SallaPush.debug.setLogHandler(SallaPushLogLevel.warn, (
      SallaPushLogEntry entry,
    ) {
      if (entry.code == 'tags.invalid_key' && !invalidKey.isCompleted) {
        invalidKey.complete(entry);
      }
    });
    await SallaPush.user.addTag('not a key!', 'value');
    final SallaPushLogEntry entry = await invalidKey.future.timeout(
      _eventTimeout,
    );
    expect(entry.level, SallaPushLogLevel.warn);
    expect(entry.category, 'tags');
    await SallaPush.debug.setLogHandler(SallaPushLogLevel.warn, null);

    for (final StreamSubscription<Object?> subscription in subscriptions) {
      await subscription.cancel();
    }
  });

  testWidgets('every member completes, with native normalisation', (
    WidgetTester tester,
  ) async {
    await SallaPush.initialize(_smokeAppId);
    expect(await SallaPush.appId, _smokeAppId);
    await SallaPush.setConsentRequired(false);
    await SallaPush.setConsentGiven(true);
    await SallaPush.login(
      externalId: ' smoke_customer ',
      identityToken: 'smoke-identity-token',
    );
    expect(await SallaPush.user.externalId, 'smoke_customer');
    expect(await SallaPush.user.isLoggedIn, isTrue);

    final SallaPushUser user = SallaPush.user;
    await user.addTag('Key', 'v');
    await user.addTags(<String, String>{'Tier': 'gold', 'City': 'riyadh'});
    expect(
      await user.getTags(),
      allOf(
        containsPair('key', 'v'),
        containsPair('tier', 'gold'),
        containsPair('city', 'riyadh'),
      ),
    );
    await user.removeTag('Key');
    await user.removeTags(<String>['Tier', 'City']);
    expect(
      (await user.getTags()).keys,
      isNot(anyOf(contains('key'), contains('tier'), contains('city'))),
    );
    await user.setLanguage('ar');
    await user.setLanguage(null);

    final SallaPushSubscription subscription = user.pushSubscription;
    expect(await subscription.id, anyOf(isNull, isNotEmpty));
    expect(await subscription.token, anyOf(isNull, isNotEmpty));
    await subscription.optOut();
    expect(await subscription.optedIn, isFalse);

    final SallaPushNotifications notifications = SallaPush.notifications;
    final bool permission = await notifications.permission;
    await notifications.canRequestPermission();
    expect(
      await notifications.permissionStatus,
      Platform.isIOS ? isNotNull : isNull,
    );
    expect(
      await notifications.registerForProvisionalAuthorization(),
      Platform.isIOS ? permission : isFalse,
    );
    await notifications.refreshPermission();
    await notifications.registerForRemoteNotifications();
    await notifications.forwardApnsToken(
      'F0E1D2C3B4A5968778695A4B3C2D1E0F00112233445566778899AABBCCDDEEFF',
    );
    await notifications.clearAll();
    await notifications.removeNotification(1);
    expect(await notifications.isSallaPushNotification(testPayload), isTrue);
    expect(
      await notifications.isSallaPushNotification(<String, Object?>{
        'title': 'Not SallaPush',
      }),
      isFalse,
    );
    expect(
      await notifications.trackOpened(<String, Object?>{
        'push_ref': 'msg_5a11a90002',
      }),
      Platform.isAndroid,
    );
    expect(await notifications.trackOpened(null), isFalse);

    await SallaPush.migration.setDisplayCompatPayloads(true);

    final SallaPushLogLevel level = await SallaPush.debug.logLevel;
    await SallaPush.debug.setLogLevel(SallaPushLogLevel.debug);
    expect(await SallaPush.debug.logLevel, SallaPushLogLevel.debug);
    await SallaPush.debug.setLogLevel(level);

    await SallaPush.logout();
    expect(await SallaPush.user.isLoggedIn, isFalse);
    expect(await SallaPush.user.externalId, isNull);
  });

  testWidgets('requestPermission and optIn complete without a prompt', (
    WidgetTester tester,
  ) async {
    final String? prompt = await _promptReason();
    if (prompt != null) {
      markTestSkipped(prompt);
      return;
    }
    expect(
      await SallaPush.notifications.requestPermission(),
      await SallaPush.notifications.permission,
    );
    await SallaPush.user.pushSubscription.optIn();
  });

  testWidgets('the example app starts and shows what SallaPush reports', (
    WidgetTester tester,
  ) async {
    await example.main();
    final Finder appId = find.byKey(const ValueKey<String>('status:App id'));
    await _pumpUntil(tester, appId);

    expect(tester.widget<Text>(appId).data, _smokeAppId);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('status:Initialized')),
          )
          .data,
      'Yes',
    );
    expect(find.text('Not configured'), findsNothing);
  });
}

/// Why requestPermission() would show the system prompt now, which nobody
/// answers in a smoke run; null when it completes at once.
Future<String?> _promptReason() async {
  if (Platform.isIOS) {
    final SallaPushIosPermissionStatus? status =
        await SallaPush.notifications.permissionStatus;
    return switch (status) {
      SallaPushIosPermissionStatus.authorized ||
      SallaPushIosPermissionStatus.denied ||
      SallaPushIosPermissionStatus.ephemeral => null,
      _ =>
        'The permission is ${status?.name}, so requestPermission() would '
            'prompt: allow notifications beforehand to run this case.',
    };
  }
  return await SallaPush.notifications.canRequestPermission()
      ? 'The permission can still be requested, so requestPermission() would '
            'prompt: grant android.permission.POST_NOTIFICATIONS beforehand.'
      : null;
}

Future<void> _eventually(bool Function() condition) async {
  final Stopwatch waited = Stopwatch()..start();
  while (!condition()) {
    if (waited.elapsed > _eventTimeout) {
      fail('Nothing arrived within $_eventTimeout.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  final Stopwatch waited = Stopwatch()..start();
  while (finder.evaluate().isEmpty) {
    if (waited.elapsed > _eventTimeout) {
      fail('$finder found nothing within $_eventTimeout.');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}
