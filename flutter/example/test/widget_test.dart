import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_push/mobile_push.dart';
import 'package:sallapush_flutter_example/customer_session.dart';
import 'package:sallapush_flutter_example/event_log.dart';
import 'package:sallapush_flutter_example/example_app.dart';

import 'fake_sallapush.dart';

void main() {
  late FakeSallaPush native;

  setUp(() {
    native = FakeSallaPush(
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger,
    );
  });

  Future<EventLog> pumpExample(
    WidgetTester tester, {
    CustomerSession? session,
  }) async {
    native.install();
    final EventLog log = EventLog();
    addTearDown(log.dispose);
    await tester.pumpWidget(
      SallaPushExampleApp(session: session ?? CustomerSession(), log: log),
    );
    await tester.pumpAndSettle();
    return log;
  }

  String status(WidgetTester tester, String label) =>
      tester.widget<Text>(find.byKey(ValueKey<String>('status:$label'))).data ??
      '';

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final Finder finder = find.text(text);
    await reveal(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String field, String text) async {
    final Finder finder = find.widgetWithText(TextField, field);
    await reveal(tester, finder);
    await tester.enterText(finder, text);
  }

  Future<void> pickLevel(
    WidgetTester tester,
    String picker,
    SallaPushLogLevel level,
  ) async {
    final Finder finder = find.byKey(ValueKey<String>('level:$picker'));
    await reveal(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
    await tester.tap(find.text(level.name).last);
    await tester.pumpAndSettle();
  }

  testWidgets('shows what SallaPush reports, and only the end of the token', (
    WidgetTester tester,
  ) async {
    native.answers
      ..['externalId'] = 'cust_42'
      ..['isLoggedIn'] = true
      ..['getTags'] = <String, String>{'tier': 'gold', 'city': 'riyadh'};

    await pumpExample(tester);

    expect(status(tester, 'Initialized'), 'Yes');
    expect(status(tester, 'App id'), 'st_42_ios');
    expect(status(tester, 'SallaPush SDK'), '1.0.2');
    expect(status(tester, 'Device id'), 'dev_1');
    expect(status(tester, 'Opted in'), 'Yes');
    expect(status(tester, 'Token'), '…091a2b');
    expect(status(tester, 'Permission'), 'Allowed');
    expect(status(tester, 'External id'), 'cust_42');
    expect(status(tester, 'Logged in'), 'Yes');
    expect(status(tester, 'Tags'), 'tier=gold, city=riyadh');
    expect(find.textContaining('80f1c2'), findsNothing);
    expect(find.text('Not configured'), findsNothing);
  });

  testWidgets('says SallaPush is not configured without an app id', (
    WidgetTester tester,
  ) async {
    native.answers
      ..['isInitialized'] = false
      ..['appId'] = null
      ..['pushSubscriptionId'] = null
      ..['pushSubscriptionToken'] = null;

    await pumpExample(tester);

    expect(find.text('Not configured'), findsOneWidget);
    expect(status(tester, 'Initialized'), 'No');
    expect(status(tester, 'App id'), 'None');
    expect(status(tester, 'Device id'), 'Not registered');
    expect(status(tester, 'Token'), 'None');
  });

  testWidgets('reads the status again with the refresh button', (
    WidgetTester tester,
  ) async {
    await pumpExample(tester);
    native.answers['pushSubscriptionOptedIn'] = false;

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(status(tester, 'Opted in'), 'No');
  });

  testWidgets('logs out at launch, then the customer in and out', (
    WidgetTester tester,
  ) async {
    final CustomerSession session = CustomerSession();
    await pumpExample(tester, session: session);

    await enter(tester, 'External id', 'cust_42');
    await enter(tester, 'Identity token', 'token-42');
    await tapText(tester, 'Log in');

    expect(
      native.calls,
      contains(equals(<Object?>['login', 'cust_42', 'token-42'])),
    );
    expect(session.customer?.id, 'cust_42');
    expect(session.customer?.identityToken, 'token-42');

    await tapText(tester, 'Log out');

    expect(
      native.calls
          .where(
            (List<Object?> call) =>
                <Object?>['login', 'logout'].contains(call.first),
          )
          .toList(),
      <List<Object?>>[
        <Object?>['logout'],
        <Object?>['login', 'cust_42', 'token-42'],
        <Object?>['logout'],
      ],
    );
    expect(session.customer, isNull);
  });

  testWidgets('logs out before another customer logs in, not for a new token', (
    WidgetTester tester,
  ) async {
    final CustomerSession session = CustomerSession(
      const Customer(id: 'cust_42', identityToken: 'token-42'),
    );
    await pumpExample(tester, session: session);

    await enter(tester, 'External id', 'cust_42');
    await enter(tester, 'Identity token', 'token-42-refreshed');
    await tapText(tester, 'Log in');
    await enter(tester, 'External id', 'cust_7');
    await enter(tester, 'Identity token', 'token-7');
    await tapText(tester, 'Log in');

    expect(
      native.calls
          .where(
            (List<Object?> call) =>
                <Object?>['login', 'logout'].contains(call.first),
          )
          .toList(),
      <List<Object?>>[
        <Object?>['login', 'cust_42', 'token-42'],
        <Object?>['login', 'cust_42', 'token-42-refreshed'],
        <Object?>['logout'],
        <Object?>['login', 'cust_7', 'token-7'],
      ],
    );
    expect(session.customer?.id, 'cust_7');
  });

  testWidgets('a sign-out during an account switch is not undone', (
    WidgetTester tester,
  ) async {
    native.install();
    final CustomerSession session = CustomerSession(
      const Customer(id: 'cust_42', identityToken: 'token-42'),
    );
    final Completer<void> previousLogout = Completer<void>();
    native.holds['logout'] = previousLogout;

    final Future<void> switching = session.signIn(
      const Customer(id: 'cust_7', identityToken: 'token-7'),
    );
    await tester.pump();
    await session.signOut();
    previousLogout.complete();
    await switching;

    expect(
      native.calls
          .where(
            (List<Object?> call) =>
                <Object?>['login', 'logout'].contains(call.first),
          )
          .toList(),
      <List<Object?>>[
        <Object?>['logout'],
        <Object?>['logout'],
      ],
    );
    expect(session.customer, isNull);
  });

  testWidgets('adds and removes tags, and sets the language', (
    WidgetTester tester,
  ) async {
    await pumpExample(tester);

    await enter(tester, 'Tag key', 'Tier');
    await enter(tester, 'Tag value', 'gold');
    await tapText(tester, 'Add tag');
    await tapText(tester, 'Remove tag');
    await tapText(tester, 'Set language');
    await enter(tester, 'Language', ' ar ');
    await tapText(tester, 'Set language');

    expect(
      native.calls,
      containsAllInOrder(<Matcher>[
        equals(<Object?>['addTag', 'Tier', 'gold']),
        equals(<Object?>['removeTag', 'Tier']),
        equals(<Object?>['setLanguage', null]),
        equals(<Object?>['setLanguage', 'ar']),
      ]),
    );
  });

  testWidgets('opts in and out, and clears the notifications', (
    WidgetTester tester,
  ) async {
    await pumpExample(tester);

    await tapText(tester, 'Opt out');
    await tapText(tester, 'Opt in');
    await tapText(tester, 'Refresh permission');
    await tapText(tester, 'Clear all');

    expect(
      native.methods,
      containsAllInOrder(<String>[
        'optOut',
        'optIn',
        'refreshPermission',
        'clearAll',
      ]),
    );
  });

  testWidgets('asks for the permission and shows the answer', (
    WidgetTester tester,
  ) async {
    native.answers['requestPermission'] = false;
    await pumpExample(tester);

    await tapText(tester, 'Fall back to settings');
    await tapText(tester, 'Request permission');

    expect(
      native.calls,
      contains(equals(<Object?>['requestPermission', true])),
    );
    expect(find.text('Notifications are not allowed.'), findsOneWidget);
  });

  testWidgets('shows the iOS-only status and actions on iOS', (
    WidgetTester tester,
  ) async {
    await pumpExample(tester);

    expect(status(tester, 'Permission status'), 'authorized');
    await tapText(tester, 'Provisional');
    expect(find.text('Notifications are allowed.'), findsOneWidget);
    await tapText(tester, 'Register');
    await reveal(tester, find.text('Events'));

    expect(
      native.methods,
      containsAllInOrder(<String>[
        'registerForProvisionalAuthorization',
        'registerForRemoteNotifications',
      ]),
    );
    expect(find.text('Android notification id'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('shows the Android-only actions on Android', (
    WidgetTester tester,
  ) async {
    await pumpExample(tester);

    expect(
      find.byKey(const ValueKey<String>('status:Permission status')),
      findsNothing,
    );
    expect(native.methods, isNot(contains('permissionStatus')));
    expect(find.text('Provisional'), findsNothing);
    expect(find.text('Register'), findsNothing);
    await enter(tester, 'Android notification id', '7');
    await tapText(tester, 'Remove');

    expect(native.calls, contains(equals(<Object?>['removeNotification', 7])));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('removes a notification by a negative Android id', (
    WidgetTester tester,
  ) async {
    await pumpExample(tester);

    await enter(tester, 'Android notification id', '-1408375307');
    await tapText(tester, 'Remove');

    expect(
      native.calls,
      contains(equals(<Object?>['removeNotification', -1408375307])),
    );
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, 'Android notification id'),
          )
          .keyboardType,
      const TextInputType.numberWithOptions(signed: true),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('holds foreground notifications until Display', (
    WidgetTester tester,
  ) async {
    final EventLog log = await pumpExample(tester);
    expect(native.isListening('willDisplayEvents'), isFalse);

    await tapText(tester, 'Hold');
    expect(native.isListening('willDisplayEvents'), isTrue);
    native.emitWillDisplay('handle-1', title: 'Order shipped');
    await tester.pumpAndSettle();

    expect(native.methods, isNot(contains('displayNotification')));
    expect(log.latest?.text, 'Order shipped (native), held');

    await tapText(tester, 'Display');

    expect(
      native.calls,
      contains(equals(<Object?>['displayNotification', 'handle-1'])),
    );
    expect(find.text('Display'), findsNothing);
  });

  testWidgets('lets foreground notifications show, and stops listening off', (
    WidgetTester tester,
  ) async {
    final EventLog log = await pumpExample(tester);

    await tapText(tester, 'Show');
    native.emitWillDisplay('handle-2');
    await tester.pumpAndSettle();

    expect(
      native.calls,
      contains(equals(<Object?>['displayNotification', 'handle-2'])),
    );
    expect(log.latest?.text, 'SallaPush test (native), shown');

    await tapText(tester, 'Off');

    expect(native.isListening('willDisplayEvents'), isFalse);
  });

  testWidgets(
    'logs SallaPush events, and reads the status after each',
    (WidgetTester tester) async {
      final EventLog log = await pumpExample(tester);
      await log.listen(logLevel: SallaPushLogLevel.debug);
      final StreamSubscription<SallaPushClickEvent> clicks = SallaPush
          .notifications
          .onClick
          .listen(log.addClick);
      addTearDown(clicks.cancel);
      await tester.pumpAndSettle();
      final int reads = native.count('isInitialized');

      native
        ..emitClick(url: 'https://example.com/products/42', actionId: 'view')
        ..emitPermission(permission: false)
        ..emitUserChange(to: 'cust_42')
        ..emitLoginFailure()
        ..emitSubscriptionChange(id: 'dev_1', optedIn: true);
      await tester.pumpAndSettle();

      expect(
        log.entries.map(
          (LoggedEvent entry) => '${entry.kind.label}: ${entry.text}',
        ),
        <String>[
          'Subscription: unregistered, not opted in → dev_1, opted in',
          'Login failure: tokenRejected',
          'User: guest → cust_42',
          'Permission: Not allowed',
          'Click: SallaPush test (native), '
              'url: https://example.com/products/42, action: view',
        ],
      );
      expect(native.count('isInitialized'), greaterThan(reads));
      await reveal(tester, find.text('User: guest → cust_42'));
      expect(find.text('User: guest → cust_42'), findsOneWidget);

      final int readsBeforeLog = native.count('isInitialized');
      native.emitLog('register.ok', 'Registered.');
      await tester.pumpAndSettle();

      expect(log.latest?.text, 'info register.ok: Registered.');
      expect(native.count('isInitialized'), readsBeforeLog);
    },
  );

  testWidgets('sets consent and the log levels', (WidgetTester tester) async {
    final EventLog log = await pumpExample(tester);
    await log.listen();
    await tester.pumpAndSettle();

    await tapText(tester, 'Consent required');
    await tapText(tester, 'Consent given');
    await pickLevel(tester, 'Console level', SallaPushLogLevel.verbose);
    await pickLevel(tester, 'Event log level', SallaPushLogLevel.error);

    expect(
      native.calls,
      containsAllInOrder(<Matcher>[
        equals(<Object?>['setConsentRequired', true]),
        equals(<Object?>['setConsentGiven', true]),
      ]),
    );
    final List<String> levels = <String>[
      for (final List<Object?> call in native.calls)
        if (call.first == 'setLogLevel' || call.first == 'setLogHandlerLevel')
          '${call.first} ${(call[1] as Enum).name}',
    ];
    expect(levels, <String>[
      'setLogHandlerLevel info',
      'setLogLevel verbose',
      'setLogHandlerLevel error',
    ]);
    expect(log.logLevel, SallaPushLogLevel.error);
  });
}
