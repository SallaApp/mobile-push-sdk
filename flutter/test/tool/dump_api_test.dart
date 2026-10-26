import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/dump_api.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dump_api_test');
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  /// Writes [files] under the fixture package, by path relative to its root.
  void write(Map<String, String> files) {
    files.forEach((path, content) {
      File('${root.path}/$path')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(content);
    });
  }

  List<String> dump() => dumpApi(root.path, library: 'lib/fixture.dart');

  test('lists the exported classes and their public members, sorted', () {
    write(<String, String>{
      'lib/fixture.dart': "export 'src/api.dart' show Facade, Config;\n",
      'lib/src/api.dart': '''
/// Not listed: hidden by the show combinator.
class Internal {}

abstract final class Facade {
  static Future<void> start(String id, {Config config = const Config()}) async {}
  static Future<bool> get isReady async => true;
  static final Facade? instance = null;
  static set override(Facade? value) {}
  static void _private() {}
}

final class Config {
  const Config({this.url, this.timeout = 30});
  const Config._internal() : url = null, timeout = 0;
  factory Config.fromUrl(String url) => Config(url: url);

  final String? url;
  final int timeout;
  late final int _cache;

  @override
  String toString() => 'Config(\$url)';
}
''',
    });

    expect(dump(), <String>[
      'final class Config',
      'Config.fromUrl(String url) [factory constructor]',
      'Config.new({this.url, this.timeout = 30}) [const constructor]',
      'Config.timeout -> int [final]',
      'Config.toString() -> String [@override]',
      'Config.url -> String? [final]',
      'abstract final class Facade',
      'Facade.instance -> Facade? [static final]',
      'Facade.isReady -> Future<bool> [static getter]',
      'Facade.override(Facade? value) [static setter]',
      'Facade.start(String id, {Config config = const Config()}) -> Future<void> [static]',
    ]);
  });

  test('does not depend on formatting or comments', () {
    write(<String, String>{
      'lib/fixture.dart': "export 'src/a.dart';\nexport 'src/b.dart';\n",
      'lib/src/a.dart': '''
class A {
  Map<String, List<int>> run(int count, {required String name, bool loud = false}) => {};
}
''',
      'lib/src/b.dart': '''
class B {
  Map<String,
      List<int>>
  run(
    int count, // the count
    {
    required String name,
    /* default */ bool loud = false,
  }) => {};
}
''',
    });

    final List<String> lines = dump();

    expect(
      lines[1],
      'A.run(int count, {required String name, bool loud = false}) -> Map<String, List<int>>',
    );
    expect(lines[3], lines[1].replaceFirst('A.', 'B.'));
  });

  test('lists enums, mixins, extensions, typedefs and top-level members', () {
    write(<String, String>{
      'lib/fixture.dart': "export 'src/all.dart' hide hidden;\n",
      'lib/src/all.dart': '''
enum Level {
  low(1),
  high(2);

  const Level(this.value);

  final int value;

  bool get isHigh => this == high;
}

mixin Named on Object {
  String get name;
}

extension LevelText on Level {
  String get text => name;
}

extension on int {}

typedef Handler = void Function(Level level);

@Deprecated('Use start')
void begin<T extends Object>(T value) {}

const int limit = 3, hidden = 4;

int counter = 0;
''',
    });

    expect(dump(), <String>[
      'typedef Handler = void Function(Level level)',
      'enum Level { low, high }',
      'Level.isHigh -> bool [getter]',
      'Level.value -> int [final]',
      'extension LevelText on Level',
      'LevelText.text -> String [getter]',
      'mixin Named on Object',
      'Named.name -> String [getter]',
      "begin<T extends Object>(T value) -> void [function, @Deprecated('Use start')]",
      'counter -> int [var]',
      'limit -> int [const]',
    ]);
  });

  test(
    'follows parts, package URIs and export chains, and survives export cycles',
    () {
      write(<String, String>{
        'lib/fixture.dart': '''
export 'package:mobile_push/src/first.dart';
part 'src/fixture_part.dart';
''',
        'lib/src/fixture_part.dart':
            "part of '../fixture.dart';\n\nclass FromPart {}\n",
        'lib/src/first.dart':
            "export 'second.dart' show Second;\n\nclass First {}\n",
        'lib/src/second.dart':
            "export 'first.dart';\n\nclass Second {}\n\nclass NotShown {}\n",
      });

      expect(dump(), <String>['class First', 'class FromPart', 'class Second']);
    },
  );

  test('refuses what it cannot list', () {
    write(<String, String>{
      'lib/fixture.dart': "export 'package:meta/meta.dart' show required;\n",
    });
    expect(
      dump,
      throwsA(
        isA<ApiDumpException>().having(
          (error) => error.message,
          'message',
          contains("exports package:meta/meta.dart, another package's API"),
        ),
      ),
    );

    write(<String, String>{'lib/fixture.dart': "export 'src/missing.dart';\n"});
    expect(
      dump,
      throwsA(
        isA<ApiDumpException>().having(
          (error) => error.message,
          'message',
          endsWith('lib/src/missing.dart does not exist'),
        ),
      ),
    );

    write(<String, String>{'lib/fixture.dart': 'class Broken {\n'});
    expect(
      dump,
      throwsA(
        isA<ApiDumpException>().having(
          (error) => error.message,
          'message',
          contains('fixture.dart does not parse'),
        ),
      ),
    );
  });
}
