import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_readme_snippets.dart';

const String appDelegate = '''
// snippet:appdelegate
import Flutter

class AppDelegate {
  func didInitialize(_ registry: Registry) {
    GeneratedPluginRegistrant.register(with: registry)
    // end-snippet
    TestHooks.register(with: registry)
    // snippet:appdelegate
  }
}
// end-snippet
''';

const String joinedAppDelegate = '''
import Flutter

class AppDelegate {
  func didInitialize(_ registry: Registry) {
    GeneratedPluginRegistrant.register(with: registry)
  }
}
''';

const String plist = '''
<dict>
\t<!-- snippet:app-id -->
\t<key>SallaPushAppId</key>
\t<string>\$(SALLAPUSH_APP_ID)</string>
\t<!-- end-snippet -->
</dict>
''';

const String podfile = '''
target 'Runner' do
  # snippet:pods
  pod 'SallaPush', :tag => '1.0.2'
  # end-snippet
end
''';

const String versions = '''
| Wrapper | SallaPush iOS | SallaPush Android | Framework | iOS | Android |
|---|---|---|---|---|---|
| Flutter 1.0.0 | 1.0.2 | 1.0.2 | Flutter ≥ 3.44 | 15.0 | minSdk 23 |
''';

void main() {
  late Directory root;

  /// Writes [files] under the fixture repository, by path relative to it.
  void write(Map<String, String> files) {
    files.forEach((path, content) {
      File('${root.path}/$path')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(content);
    });
  }

  /// A README of [body] after the versions table.
  void readme(String body) => write(<String, String>{
    'README.md':
        '# SallaPush\n\nSallaPush iOS 1.0.2 and SallaPush Android 1.0.2.\n\n$versions\n$body',
  });

  List<String> problems() => checkSnippets(root.path).problems;

  setUp(() {
    root = Directory.systemTemp.createTempSync('check_readme_snippets_test');
    write(<String, String>{
      'pubspec.yaml': 'name: mobile_push\nversion: 1.0.0\n',
      'ios/mobile_push.podspec': "  s.dependency 'SallaPush', '1.0.2'\n",
      'ios/mobile_push/Package.swift':
          '.package(url: "https://github.com/SallaApp/mobile-push-ios-sdk.git", exact: "1.0.2")\n',
      'android/build.gradle.kts': 'api("com.salla:mobile-push:1.0.2")\n',
      'example/ios/Runner/AppDelegate.swift': appDelegate,
      'example/ios/Runner/Info.plist': plist,
      'example/lib/whole.dart': 'void main() {}\n',
      'docs/snippets/Podfile': podfile,
    });
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  test('blocks equal to their sources pass', () {
    readme('''
<!-- snippet:example/ios/Runner/AppDelegate.swift#appdelegate -->
```swift
$joinedAppDelegate```

<!-- snippet:example/ios/Runner/Info.plist#app-id -->
```xml
<key>SallaPushAppId</key>
<string>\$(SALLAPUSH_APP_ID)</string>
```

1. In a list, the block is indented:

   <!-- snippet:docs/snippets/Podfile#pods -->
   ```ruby
   pod 'SallaPush', :tag => '1.0.2'
   ```

<!-- snippet:example/lib/whole.dart -->
```dart
void main() {}
```

```sh
flutter run
```

<!-- unchecked: needs another push plugin in the app -->
```dart
OtherPushPlugin.onMessage.listen(print);
```
''');

    final SnippetReport report = checkSnippets(root.path);

    expect(report.problems, isEmpty);
    expect(
      report.summary,
      'check_readme_snippets: 1 Markdown file(s), 4 checked block(s), 1 unchecked, 0 problem(s)',
    );
  });

  test('a changed block fails, naming the first different line', () {
    readme('''
<!-- snippet:example/ios/Runner/Info.plist#app-id -->
```xml
<key>SallaPushAppId</key>
<string>st_42_ios</string>
```
''');

    expect(problems(), <String>[
      'README.md:9: the block differs from example/ios/Runner/Info.plist#app-id: line 2 of the block is '
          '"<string>st_42_ios</string>", the source has "<string>\$(SALLAPUSH_APP_ID)</string>"',
    ]);
  });

  test(
    'a block of a checked language needs a marker; one of another language does not',
    () {
      readme('```kotlin\nval a = 1\n```\n\n```sh\nflutter run\n```\n');

      expect(problems(), <String>[
        'README.md:9: a kotlin block without a marker: <!-- snippet:<path> -->, '
            '<!-- snippet:<path>#<region> --> or <!-- unchecked: <reason> -->',
      ]);
    },
  );

  test(
    'an unknown region, a missing file or a source outside the built folders fails',
    () {
      readme('''
<!-- snippet:example/ios/Runner/Info.plist#bundle-id -->
```xml
```

<!-- snippet:example/lib/missing.dart -->
```dart
```

<!-- snippet:lib/src/sallapush.dart -->
```dart
```
''');

      expect(problems(), <String>[
        'README.md:9: example/ios/Runner/Info.plist has no region bundle-id',
        'README.md:13: example/lib/missing.dart does not exist',
        'README.md:17: lib/src/sallapush.dart is not a snippet source: it must be a file under example/ or '
            'docs/snippets/, which scripts/verify.sh builds',
      ]);
    },
  );

  test(
    'the parts of a split region are joined in file order, without what lies between them',
    () {
      expect(
        snippetSource(
          root.path,
          'example/ios/Runner/AppDelegate.swift#appdelegate',
        ),
        joinedAppDelegate,
      );
      expect(
        snippetSource(root.path, 'docs/snippets/Podfile#pods'),
        "pod 'SallaPush', :tag => '1.0.2'\n",
      );
      expect(
        snippetSource(root.path, 'example/lib/whole.dart'),
        'void main() {}\n',
      );
    },
  );

  test('regions that nest, end outside a region or never end are refused', () {
    expect(
      () => region(
        'a.dart',
        '// snippet:a\n// snippet:b\n// end-snippet\n// end-snippet\n',
        'a',
      ),
      throwsA(
        isA<SnippetException>().having(
          (error) => error.message,
          'message',
          'a.dart:2: the region b starts inside the region a',
        ),
      ),
    );
    expect(
      () => region('a.dart', 'code\n// end-snippet\n', 'a'),
      throwsA(
        isA<SnippetException>().having(
          (error) => error.message,
          'message',
          'a.dart:2: end-snippet outside a region',
        ),
      ),
    );
    expect(
      () => region('a.dart', '# snippet:a\ncode\n', 'a'),
      throwsA(
        isA<SnippetException>().having(
          (error) => error.message,
          'message',
          'a.dart: the region a is not closed',
        ),
      ),
    );
  });

  test('a region loses only the indentation that all its lines share', () {
    expect(dedent(<String>['\t\t<a>', '\t\t\t<b/>', '', '\t\t</a>']), <String>[
      '<a>',
      '\t<b/>',
      '',
      '</a>',
    ]);
    expect(dedent(<String>['    if a {', '      b()', '    }']), <String>[
      'if a {',
      '  b()',
      '}',
    ]);
  });

  test(
    'a native version other than the pin fails, in the table and in any line',
    () {
      write(<String, String>{
        'README.md':
            '# SallaPush\n\n${versions.replaceFirst('| 1.0.2 | 1.0.2 |', '| 1.0.2 | 1.0.3 |')}\n',
        'docs/GUIDE.md': 'Built on SallaPush iOS 1.0.1.\n',
      });

      expect(problems(), <String>[
        'docs/GUIDE.md:1: names SallaPush iOS 1.0.1, but the pin is 1.0.2',
        'README.md:5: the versions table says 1.0.3, not 1.0.2',
      ]);
    },
  );

  test("the versions table names the package's version", () {
    write(<String, String>{
      'README.md': versions.replaceFirst('Flutter 1.0.0', 'Flutter 0.9.0'),
    });

    expect(problems(), <String>[
      'README.md:3: the versions table says Flutter 0.9.0, not Flutter 1.0.0',
    ]);
  });

  test('a README without the versions table fails', () {
    write(<String, String>{'README.md': '# SallaPush\n'});

    expect(problems(), <String>[
      'README.md: no versions table (| Wrapper | SallaPush iOS | SallaPush Android | Framework | iOS | Android |)',
    ]);
  });

  test(
    'a marker needs a block, one marker per block, and an unchecked block a reason',
    () {
      readme('''
<!-- snippet:example/lib/whole.dart -->
Text in between.

<!-- unchecked: one -->
<!-- unchecked: two -->
```dart
```

<!-- unchecked: -->
```dart
```

<!-- snippet:example/lib/whole.dart -->
''');

      expect(problems(), <String>[
        'README.md:9: no code block follows the marker',
        'README.md:12: two markers before one block',
        'README.md:21: no code block follows the marker',
        'README.md:17: an unchecked block needs a reason',
      ]);
    },
  );

  test('the docs are checked too, and a block that is never closed fails', () {
    readme('');
    write(<String, String>{
      'docs/REFERENCE.md':
          '<!-- snippet:example/lib/whole.dart -->\n```dart\nvoid main() {}\n```\n',
      'docs/TROUBLESHOOTING.md': '```dart\nvoid main() {}\n',
      'docs/notes.txt': '```dart\n',
    });

    final SnippetReport report = checkSnippets(root.path);

    expect(report.problems, <String>[
      'docs/TROUBLESHOOTING.md:1: the code block is not closed',
    ]);
    expect(markdownFiles(root.path), <String>[
      'README.md',
      'docs/REFERENCE.md',
      'docs/TROUBLESHOOTING.md',
    ]);
  });

  test(
    "README.md's block of a source is its text; a source the README does not show is refused",
    () {
      readme('''
<!-- snippet:docs/snippets/Podfile#pods -->
```ruby
pod 'SallaPush', :tag => '1.0.2'
```
''');

      expect(
        readmeBlock(root.path, 'docs/snippets/Podfile#pods'),
        "pod 'SallaPush', :tag => '1.0.2'\n",
      );
      expect(
        () => readmeBlock(root.path, 'example/lib/whole.dart'),
        throwsA(
          isA<SnippetException>().having(
            (error) => error.message,
            'message',
            'README.md shows no block of example/lib/whole.dart',
          ),
        ),
      );
    },
  );

  test(
    "a doc's block of a source is its text; a file the check doesn't read is refused",
    () {
      readme('');
      write(<String, String>{
        'docs/SETUP.md': '''
<!-- snippet:docs/snippets/Podfile#pods -->
```ruby
pod 'SallaPush', :tag => '1.0.2'
```
''',
      });

      expect(
        readmeBlock(
          root.path,
          'docs/snippets/Podfile#pods',
          file: 'docs/SETUP.md',
        ),
        "pod 'SallaPush', :tag => '1.0.2'\n",
      );
      expect(
        () => readmeBlock(root.path, 'docs/snippets/Podfile#pods'),
        throwsA(
          isA<SnippetException>().having(
            (error) => error.message,
            'message',
            'README.md shows no block of docs/snippets/Podfile#pods',
          ),
        ),
      );
      expect(
        () => readmeBlock(
          root.path,
          'docs/snippets/Podfile#pods',
          file: 'docs/snippets/Podfile',
        ),
        throwsA(
          isA<SnippetException>().having(
            (error) => error.message,
            'message',
            'docs/snippets/Podfile is not a checked Markdown file: README.md or a .md file directly in docs/',
          ),
        ),
      );
    },
  );

  test('the repository passes', () {
    final SnippetReport report = checkSnippets(Directory.current.path);

    expect(report.problems, isEmpty);
  });
}
