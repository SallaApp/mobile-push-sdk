import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_push/mobile_push.dart';
import 'package:mobile_push/src/channels.dart';
import 'package:mobile_push/src/messages.g.dart';

import 'fakes/fake_channels.dart';

void main() {
  final SallaPushUser user = SallaPush.user;
  late FakeChannels native;

  setUp(() {
    native = FakeChannels();
    SallaPushChannels.debugOverride = native;
  });

  tearDown(() {
    SallaPushChannels.debugOverride = null;
  });

  test('externalId and isLoggedIn read native at every call', () async {
    native
      ..externalIdResult = '42'
      ..isLoggedInResult = true;

    expect(await user.externalId, '42');
    expect(await user.isLoggedIn, isTrue);

    native
      ..externalIdResult = null
      ..isLoggedInResult = false;

    expect(await user.externalId, isNull);
    expect(await user.isLoggedIn, isFalse);
    expect(native.calls, <Object?>[
      <Object?>['externalId'],
      <Object?>['isLoggedIn'],
      <Object?>['externalId'],
      <Object?>['isLoggedIn'],
    ]);
  });

  test('addTag and removeTag pass their arguments unchanged', () async {
    await user.addTag(' Tier ', 'gold');
    await user.addTag('tier', '');
    await user.removeTag('tier');

    expect(native.calls, <Object?>[
      <Object?>['addTag', ' Tier ', 'gold'],
      <Object?>['addTag', 'tier', ''],
      <Object?>['removeTag', 'tier'],
    ]);
  });

  test('addTags and removeTags pass every entry unchanged', () async {
    await user.addTags(<String, String>{'tier': 'gold', ' City ': ''});
    await user.removeTags(<String>['tier', ' City ']);

    expect(native.calls, <Object?>[
      <Object?>[
        'addTags',
        <String, String>{'tier': 'gold', ' City ': ''},
      ],
      <Object?>[
        'removeTags',
        <String>['tier', ' City '],
      ],
    ]);
  });

  test('getTags returns the tags native knows at every call', () async {
    native.tagsResult = <String, String>{'tier': 'gold'};
    expect(await user.getTags(), <String, String>{'tier': 'gold'});

    native.tagsResult = <String, String>{};
    expect(await user.getTags(), isEmpty);

    expect(native.calls, <Object?>[
      <Object?>['getTags'],
      <Object?>['getTags'],
    ]);
  });

  test('setLanguage passes a language and null', () async {
    await user.setLanguage('ar');
    await user.setLanguage(null);

    expect(native.calls, <Object?>[
      <Object?>['setLanguage', 'ar'],
      <Object?>['setLanguage', null],
    ]);
  });

  test('pushSubscription is always the same subscription', () {
    expect(user.pushSubscription, same(SallaPush.user.pushSubscription));
    expect(native.calls, isEmpty);
  });

  group('onChange', () {
    test('maps the previous and the current state', () async {
      final List<SallaPushUserChangedState> changes =
          <SallaPushUserChangedState>[];
      final StreamSubscription<SallaPushUserChangedState> subscription = user
          .onChange
          .listen(changes.add);

      native.users
        ..emit(
          UserChangedMessage(
            previous: UserStateMessage(isLoggedIn: false),
            current: UserStateMessage(externalId: '42', isLoggedIn: true),
          ),
        )
        ..emit(
          UserChangedMessage(
            previous: UserStateMessage(externalId: '42', isLoggedIn: true),
            current: UserStateMessage(isLoggedIn: false),
          ),
        );
      await pumpEventQueue();

      expect(
        changes.map(
          (SallaPushUserChangedState change) => <Object?>[
            change.previous.externalId,
            change.previous.isLoggedIn,
            change.current.externalId,
            change.current.isLoggedIn,
          ],
        ),
        <List<Object?>>[
          <Object?>[null, false, '42', true],
          <Object?>['42', true, null, false],
        ],
      );
      await subscription.cancel();
    });

    test('listens on the platform lazily', () async {
      await expectListensLazily(() => user.onChange, native.users);
    });
  });

  group('onLoginFailure', () {
    test('maps both failures', () async {
      final List<SallaPushLoginFailure> failures = <SallaPushLoginFailure>[];
      final StreamSubscription<SallaPushLoginFailure> subscription = user
          .onLoginFailure
          .listen(failures.add);

      native.failures
        ..emit(
          LoginFailureEventMessage(failure: LoginFailureMessage.tokenRejected),
        )
        ..emit(
          LoginFailureEventMessage(failure: LoginFailureMessage.invalidRequest),
        );
      await pumpEventQueue();

      expect(failures, <SallaPushLoginFailure>[
        SallaPushLoginFailure.tokenRejected,
        SallaPushLoginFailure.invalidRequest,
      ]);
      await subscription.cancel();
    });

    test('listens on the platform lazily', () async {
      await expectListensLazily(() => user.onLoginFailure, native.failures);
    });
  });
}
