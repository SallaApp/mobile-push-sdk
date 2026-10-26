import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_api_parity.dart';

const String iosApi = '''
SallaPush | swift.class | SallaPush | @objc(SallaPush) final class SallaPush
SallaPush | swift.type.method | SallaPush.logout() | @objc static func logout()
SallaPush | swift.method | SallaPushNotifications.parse(_:) | @objc func parse(_ userInfo: [AnyHashable : Any]) -> SallaPushNotification?
''';

const String androidApi = '''
public final class com/salla/push/SallaPush {
\tpublic static final field INSTANCE Lcom/salla/push/SallaPush;
\tpublic static final fun logout ()V
}

public final class com/salla/push/SallaPushConfig\$Builder {
\tpublic fun <init> ()V
}
''';

const String dump = '''
abstract final class SallaPush
SallaPush.logout() -> Future<void> [static]
final class SallaPushConfig
SallaPushConfig.new({this.logLevel}) [const constructor]
enum SallaPushLogLevel { off, error }
''';

const Map<String, String> pins = <String, String>{
  'ios/mobile_push.podspec': "  s.dependency 'SallaPush', '1.0.2'\n",
  'ios/mobile_push/Package.swift':
      '.package(url: "https://github.com/SallaApp/mobile-push-ios-sdk.git", exact: "1.0.2")\n',
  'android/build.gradle.kts': '    api("com.salla:mobile-push:1.0.2")\n',
};

Map<String, Object?> entry(
  String id,
  String status, {
  List<String> ios = const <String>[],
  List<String> android = const <String>[],
  List<String> dart = const <String>[],
  String? reason,
}) => <String, Object?>{
  'id': id,
  'status': status,
  'ios': ios,
  'android': android,
  'dart': dart,
  'reason': reason,
};

/// A complete mapping of [iosApi] and [androidApi].
List<Map<String, Object?>> completeEntries() => <Map<String, Object?>>[
  entry(
    'P01',
    'W',
    ios: <String>[iosSymbols(iosApi)[0]],
    android: <String>['com/salla/push/SallaPush'],
    dart: <String>['SallaPush'],
  ),
  entry(
    'P01b',
    'N',
    android: <String>['com/salla/push/SallaPush#INSTANCE'],
    reason: 'Kotlin object plumbing.',
  ),
  entry(
    'P09',
    'W',
    ios: <String>[iosSymbols(iosApi)[1]],
    android: <String>['com/salla/push/SallaPush#logout ()V'],
    dart: <String>['SallaPush.logout'],
  ),
  entry(
    'P11',
    'A',
    android: <String>[
      r'com/salla/push/SallaPushConfig$Builder',
      r'com/salla/push/SallaPushConfig$Builder#<init> ()V',
    ],
    dart: <String>['SallaPushConfig', 'SallaPushConfig.new'],
  ),
  entry(
    'P64',
    'X',
    ios: <String>[iosSymbols(iosApi)[2]],
    reason: 'Native delegate code only.',
  ),
];

String mappingText(
  List<Map<String, Object?>> entries, {
  String ios = '1.0.2',
  String android = '1.0.2',
}) => jsonEncode(<String, Object?>{
  'nativeVersions': <String, String>{'ios': ios, 'android': android},
  'entries': entries,
});

ParityReport check(
  List<Map<String, Object?>> entries, {
  String? mapping,
  String wrapperDump = dump,
  Map<String, String> pinTexts = pins,
}) => checkParity(
  iosApi: iosApi,
  androidApi: androidApi,
  mapping: mapping ?? mappingText(entries),
  wrapperDump: wrapperDump,
  pins: pinTexts,
);

void main() {
  group('native API files', () {
    test('each API.txt line is one iOS symbol', () {
      expect(iosSymbols('$iosApi\n'), <String>[
        'SallaPush | swift.class | SallaPush | @objc(SallaPush) final class SallaPush',
        'SallaPush | swift.type.method | SallaPush.logout() | @objc static func logout()',
        'SallaPush | swift.method | SallaPushNotifications.parse(_:) | '
            '@objc func parse(_ userInfo: [AnyHashable : Any]) -> SallaPushNotification?',
      ]);
      expect(
        () => iosSymbols('SallaPush | swift.class\n'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('line 1'),
          ),
        ),
      );
    });

    test('Android class, fun and field lines become class, member and field keys', () {
      expect(androidSymbols(androidApi), <String>[
        'com/salla/push/SallaPush',
        'com/salla/push/SallaPush#INSTANCE',
        'com/salla/push/SallaPush#logout ()V',
        r'com/salla/push/SallaPushConfig$Builder',
        r'com/salla/push/SallaPushConfig$Builder#<init> ()V',
      ]);
      expect(
        androidSymbols(
          'public final class com/salla/push/SallaPushLogLevel : java/lang/Enum {\n'
          '\tpublic static fun values ()[Lcom/salla/push/SallaPushLogLevel;\n'
          '}\n'
          'public abstract interface class com/salla/push/SallaPushClickListener {\n'
          '\tpublic abstract fun onClick (Lcom/salla/push/SallaPushClickEvent;)V\n'
          '}\n',
        ),
        <String>[
          'com/salla/push/SallaPushLogLevel',
          'com/salla/push/SallaPushLogLevel#values ()[Lcom/salla/push/SallaPushLogLevel;',
          'com/salla/push/SallaPushClickListener',
          'com/salla/push/SallaPushClickListener#onClick (Lcom/salla/push/SallaPushClickEvent;)V',
        ],
      );
    });

    test(
      'an Android line that is no symbol, or an unclosed class, is refused',
      () {
        expect(
          () =>
              androidSymbols('public final class a/B {\n\tsomething else\n}\n'),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('line 2'),
            ),
          ),
        );
        expect(
          () => androidSymbols('\tpublic fun f ()V\n'),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => androidSymbols('public final class a/B {\n'),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'the class a/B is not closed',
            ),
          ),
        );
      },
    );
  });

  test(
    'the dump declares classes, enum constants, members and top-level names',
    () {
      expect(
        dumpSymbols(
          '$dump'
          'mixin class Mixed\n'
          'typedef Handler = void Function(int value)\n'
          'Mixed.operator==(Object other) -> bool [@override]\n'
          'topLevel(int value) -> void [function]\n',
        ),
        <String>{
          'SallaPush',
          'SallaPush.logout',
          'SallaPushConfig',
          'SallaPushConfig.new',
          'SallaPushLogLevel',
          'SallaPushLogLevel.off',
          'SallaPushLogLevel.error',
          'Mixed',
          'Handler',
          'Mixed.operator==',
          'topLevel',
        },
      );
    },
  );

  test('a complete mapping passes, with a count per status', () {
    final ParityReport report = check(completeEntries());

    expect(report.problems, isEmpty);
    expect(report.iosSymbols, 3);
    expect(report.androidSymbols, 5);
    expect(report.entries, 5);
    expect(report.summary, <String>[
      'W: 2 entries, 2 iOS and 2 Android symbols',
      'I: 0 entries, 0 iOS and 0 Android symbols',
      'A: 1 entry, 0 iOS and 2 Android symbols',
      'N: 1 entry, 0 iOS and 1 Android symbols',
      'X: 1 entry, 1 iOS and 0 Android symbols',
    ]);
  });

  group('check 1: the native versions are the pins', () {
    test('a mapping of another native version fails, per pin file', () {
      final ParityReport report = check(
        const <Map<String, Object?>>[],
        mapping: mappingText(completeEntries(), ios: '1.0.3'),
      );

      expect(report.problems, <String>[
        'ios/mobile_push.podspec pins SallaPush ios 1.0.2, but nativeVersions.ios is 1.0.3: '
            'map the API files of the pinned version (scripts/bump-native.sh)',
        'ios/mobile_push/Package.swift pins SallaPush ios 1.0.2, but nativeVersions.ios is 1.0.3: '
            'map the API files of the pinned version (scripts/bump-native.sh)',
      ]);
    });

    test('a pin file without the pin, or with two, fails', () {
      final ParityReport report = check(
        completeEntries(),
        pinTexts: <String, String>{
          ...pins,
          'android/build.gradle.kts': '',
          'ios/mobile_push.podspec':
              "s.dependency 'SallaPush', '1.0.2'\ns.dependency 'SallaPush', '1.0.2'\n",
        },
      );

      expect(report.problems, <String>[
        'ios/mobile_push.podspec: expected one SallaPush ios pin, found 2',
        'android/build.gradle.kts: expected one SallaPush android pin, found 0',
      ]);
    });
  });

  group('checks 2 and 3: every native symbol in exactly one entry', () {
    test('an unmapped symbol fails, named', () {
      final ParityReport report = check(completeEntries().sublist(1));

      expect(report.problems, <String>[
        'unmapped ios symbol: ${iosSymbols(iosApi)[0]}',
        'unmapped android symbol: com/salla/push/SallaPush',
      ]);
    });

    test('a symbol in two entries, or twice in one, fails', () {
      final ParityReport report = check(<Map<String, Object?>>[
        ...completeEntries(),
        entry(
          'P99',
          'N',
          android: <String>[
            'com/salla/push/SallaPush#INSTANCE',
            'com/salla/push/SallaPush#INSTANCE',
          ],
          reason: 'Twice.',
        ),
      ]);

      expect(report.problems, <String>[
        'android symbol mapped 3 times (P01b, P99, P99): com/salla/push/SallaPush#INSTANCE',
      ]);
    });

    test('a mapped symbol that the native files lack fails', () {
      final ParityReport report = check(<Map<String, Object?>>[
        ...completeEntries(),
        entry(
          'P98',
          'N',
          ios: <String>['SallaPush | swift.method | Gone.f() | func f()'],
          reason: 'Removed natively.',
        ),
      ]);

      expect(report.problems, <String>[
        'P98: tool/api-parity/native-ios-API.txt has no such symbol: '
            'SallaPush | swift.method | Gone.f() | func f()',
      ]);
    });

    test('a native API file that does not parse fails', () {
      final ParityReport report = checkParity(
        iosApi: iosApi,
        androidApi: 'not an API dump\n',
        mapping: mappingText(completeEntries()),
        wrapperDump: dump,
        pins: pins,
      );

      expect(
        report.problems.first,
        'tool/api-parity/native-android-sallapush.api: line 1 is not a class line: not an API dump',
      );
    });
  });

  group('check 4: statuses and reasons', () {
    test('each status needs its platforms, its reason and its Dart symbols', () {
      final List<Map<String, Object?>> entries = completeEntries();
      entries[0] = entry(
        'P01',
        'W',
        ios: <String>[iosSymbols(iosApi)[0]],
        dart: <String>['SallaPush'],
      );
      entries[1] = entry(
        'P01b',
        'N',
        android: <String>['com/salla/push/SallaPush#INSTANCE'],
        dart: <String>['SallaPush'],
        reason: ' ',
      );
      entries[2] = entry(
        'P09',
        'I',
        ios: <String>[iosSymbols(iosApi)[1]],
        android: <String>['com/salla/push/SallaPush#logout ()V'],
      );
      entries[3] = entry(
        'P11',
        'A',
        ios: <String>[
          'SallaPush | swift.class | SallaPush | @objc(SallaPush) final class SallaPush',
        ],
        android: <String>[
          r'com/salla/push/SallaPushConfig$Builder',
          r'com/salla/push/SallaPushConfig$Builder#<init> ()V',
        ],
        dart: <String>['SallaPushConfig'],
      );
      entries[4] = entry('P64', 'Z', ios: <String>[iosSymbols(iosApi)[2]]);
      entries.add(entry('P97', 'X'));

      final ParityReport report = check(entries);

      expect(
        report.problems,
        containsAll(<String>[
          'P01: status W (both platforms) needs iOS and Android symbols',
          'P01b: status N needs a reason',
          'P01b: status N is not wrapped, so it lists no Dart symbol',
          'P09: status I (iOS only) needs iOS symbols and no Android symbol',
          'P09: status I needs at least one Dart symbol',
          'P11: status A (Android only) needs Android symbols and no iOS symbol',
          'P64: unknown status "Z" (W, I, A, N or X)',
          'P97: status X needs a native symbol',
          'P97: status X needs a reason',
        ]),
      );
    });

    test('a reused id and a malformed entry fail, named', () {
      final ParityReport report = check(<Map<String, Object?>>[
        ...completeEntries(),
        entry('P01', 'N', reason: 'Again.'),
        <String, Object?>{
          'id': 'P96',
          'status': 'W',
          'ios': <String>[],
          'notes': 'x',
        },
        <String, Object?>{'status': 'W'},
      ]);

      expect(report.problems, <String>[
        'P01: the id is used twice',
        'P96: an entry is {"id": "<id>", "status": "<status>", "ios": [...], "android": [...], '
            '"dart": [...], "reason": "<reason>" or null}; unknown: notes; missing: android, dart, reason',
        'entry 8: an entry is {"id": "<id>", "status": "<status>", "ios": [...], "android": [...], '
            '"dart": [...], "reason": "<reason>" or null}; missing: id, ios, android, dart, reason',
        'P01: status N needs a native symbol',
      ]);
    });

    test('a mapping that is not JSON, or not the expected object, fails', () {
      expect(
        check(const <Map<String, Object?>>[], mapping: '{').problems.first,
        startsWith('tool/api-parity/mapping.json is not JSON:'),
      );
      expect(
        check(
          const <Map<String, Object?>>[],
          mapping: '{"nativeVersions": {"ios": "1.0.2"}, "entries": []}',
        ).problems.first,
        'tool/api-parity/mapping.json must be {"nativeVersions": {"ios": "<version>", '
        '"android": "<version>"}, "entries": [...]}',
      );
    });
  });

  test('check 5: a Dart symbol missing from the API dump fails', () {
    final ParityReport report = check(
      completeEntries(),
      wrapperDump: dump.replaceFirst(
        'SallaPush.logout() -> Future<void> [static]\n',
        '',
      ),
    );

    expect(report.problems, <String>[
      'P09: api/mobile_push.api has no Dart symbol SallaPush.logout',
    ]);
  });

  test('the repository maps every native symbol of its pinned versions', () {
    final ParityReport report = checkParity(
      iosApi: File(iosApiFile).readAsStringSync(),
      androidApi: File(androidApiFile).readAsStringSync(),
      mapping: File(mappingFile).readAsStringSync(),
      wrapperDump: File(wrapperDumpFile).readAsStringSync(),
      pins: <String, String>{
        for (final String path in pinFiles.keys)
          path: File(path).readAsStringSync(),
      },
    );

    expect(report.problems, isEmpty);
    expect(report.iosSymbols, 175);
    expect(report.androidSymbols, 170);
  });
}
