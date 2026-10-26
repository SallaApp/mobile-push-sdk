import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_push/mobile_push.dart';
import 'package:mobile_push/src/channels.dart';

import 'fakes/fake_channels.dart';

void main() {
  late FakeChannels native;

  setUp(() {
    native = FakeChannels();
    SallaPushChannels.debugOverride = native;
  });

  tearDown(() {
    SallaPushChannels.debugOverride = null;
  });

  test('setDisplayCompatPayloads passes false and true', () async {
    await SallaPush.migration.setDisplayCompatPayloads(false);
    await SallaPush.migration.setDisplayCompatPayloads(true);

    expect(native.calls, <Object?>[
      <Object?>['setDisplayCompatPayloads', false],
      <Object?>['setDisplayCompatPayloads', true],
    ]);
  });
}
