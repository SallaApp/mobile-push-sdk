// Keeps README.md and the docs equal to code that scripts/verify.sh builds.
//
//   dart run tool/check_readme_snippets.dart                          checks; exits 1 on drift
//   dart run tool/check_readme_snippets.dart --print <source>         prints a snippet source
//   dart run tool/check_readme_snippets.dart --readme-block <source>  prints README.md's block of a source
//   dart run tool/check_readme_snippets.dart --doc-block <file> <source>
//                                                                     prints the block of a source in <file>:
//                                                                     README.md or a .md file directly in docs/
//
// Run it from the flutter/ folder. Every fenced code block of README.md and of
// each .md file directly in docs/ in dart, swift, kotlin, xml, ruby, yaml,
// json, ts, tsx, js or groovy follows exactly one marker line, and a block in
// any other language may follow one:
//
//   <!-- snippet:<path> -->          the block equals that file, byte for byte
//   <!-- snippet:<path>#<name> -->   the block equals the region <name> of that file: the lines between a
//                                    `snippet:<name>` comment line and an `end-snippet` comment line (//, # or
//                                    <!-- -->); the parts of a split region joined in file order, without their
//                                    common indentation
//   <!-- unchecked: <reason> -->     the block is not checked, for the reason given
//
// A snippet source is a file that scripts/verify.sh builds: one under
// example/ or docs/snippets/. The versions table of README.md names this
// package's version and the native pins, and every line of README.md or the
// docs that names "SallaPush iOS <version>" or "SallaPush Android <version>"
// names the pin.
import 'dart:io';

import 'check_api_parity.dart' show pinFiles;

/// The languages whose blocks need a marker.
const Set<String> checkedLanguages = <String>{
  'dart',
  'swift',
  'kotlin',
  'xml',
  'ruby',
  'yaml',
  'json',
  'ts',
  'tsx',
  'js',
  'groovy',
};

/// The folders that hold snippet sources.
const List<String> sourceFolders = <String>['example/', 'docs/snippets/'];

void main(List<String> arguments) {
  final String root = Directory.current.path;
  try {
    switch (arguments) {
      case <String>[]:
        final SnippetReport report = checkSnippets(root);
        report.problems.forEach(stdout.writeln);
        stdout.writeln(report.summary);
        if (report.problems.isNotEmpty) {
          exitCode = 1;
        }
      case <String>['--print', final String source]:
        stdout.write(snippetSource(root, source));
      case <String>['--readme-block', final String source]:
        stdout.write(readmeBlock(root, source));
      case <String>['--doc-block', final String file, final String source]:
        stdout.write(readmeBlock(root, source, file: file));
      default:
        stderr.writeln(
          'usage: dart run tool/check_readme_snippets.dart '
          '[--print <source> | --readme-block <source> | --doc-block <file> <source>]',
        );
        exitCode = 2;
    }
  } on SnippetException catch (error) {
    stderr.writeln('check_readme_snippets: $error');
    exitCode = 1;
  }
}

/// A snippet that can't be read, or a README without the block asked for.
final class SnippetException implements Exception {
  /// Creates the exception with its [message].
  SnippetException(this.message);

  /// What is wrong.
  final String message;

  @override
  String toString() => message;
}

/// The outcome of a check.
final class SnippetReport {
  /// Creates a report.
  SnippetReport(this.problems, this.summary);

  /// Each problem, as `<file>:<line>: <what is wrong>`.
  final List<String> problems;

  /// What was checked, and how many problems were found.
  final String summary;
}

/// Checks README.md and the docs of the repository at [root].
SnippetReport checkSnippets(String root) {
  final List<String> problems = <String>[];
  final List<String> files = markdownFiles(root);
  int checked = 0;
  int unchecked = 0;
  for (final String file in files) {
    for (final _Block block in _blocks(file, _read(root, file), problems)) {
      final _Marker? marker = block.marker;
      if (marker == null) {
        continue;
      }
      if (marker.kind == 'unchecked') {
        unchecked++;
        if (marker.value.isEmpty) {
          problems.add(
            '$file:${marker.line}: an unchecked block needs a reason',
          );
        }
        continue;
      }
      checked++;
      final String expected;
      try {
        expected = snippetSource(root, marker.value);
      } on SnippetException catch (error) {
        problems.add('$file:${marker.line}: $error');
        continue;
      }
      if (block.text != expected) {
        problems.add(
          '$file:${marker.line}: the block differs from ${marker.value}: ${_firstDifference(block.text, expected)}',
        );
      }
    }
  }
  _checkVersions(root, files, problems);
  return SnippetReport(
    problems,
    'check_readme_snippets: ${files.length} Markdown file(s), $checked checked block(s), '
    '$unchecked unchecked, ${problems.length} problem(s)',
  );
}

/// The Markdown files of the check: README.md, then each .md file directly in
/// docs/, by name.
List<String> markdownFiles(String root) {
  final Directory docs = Directory('$root/docs');
  return <String>[
    'README.md',
    if (docs.existsSync())
      ...(docs
          .listSync()
          .whereType<File>()
          .map((file) => 'docs/${file.uri.pathSegments.last}')
          .where((name) => name.endsWith('.md'))
          .toList()
        ..sort()),
  ];
}

/// The text of a snippet source: the file `<path>`, or the region `<name>` of
/// `<path>#<name>`.
String snippetSource(String root, String source) {
  final int hash = source.indexOf('#');
  final String path = hash < 0 ? source : source.substring(0, hash);
  if (path.split('/').contains('..') ||
      !sourceFolders.any((folder) => path.startsWith(folder))) {
    throw SnippetException(
      '$path is not a snippet source: it must be a file under ${sourceFolders.join(' or ')}, which scripts/verify.sh builds',
    );
  }
  final File file = File('$root/$path');
  if (!file.existsSync()) {
    throw SnippetException('$path does not exist');
  }
  final String text = file.readAsStringSync();
  return hash < 0 ? text : region(path, text, source.substring(hash + 1));
}

final RegExp _regionStart = RegExp(
  r'^\s*(?://|#|<!--)\s*snippet:([A-Za-z0-9_.-]+)\s*(?:-->)?\s*$',
);
final RegExp _regionEnd = RegExp(
  r'^\s*(?://|#|<!--)\s*end-snippet\s*(?:-->)?\s*$',
);

/// The region [name] of [text], the content of [path]: every part of it, in
/// file order, without their common indentation.
String region(String path, String text, String name) {
  final List<String> lines = text.split('\n');
  final List<String> collected = <String>[];
  String? open;
  bool found = false;
  for (int index = 0; index < lines.length; index++) {
    final String line = lines[index];
    final String? start = _regionStart.firstMatch(line)?[1];
    if (start != null) {
      if (open != null) {
        throw SnippetException(
          '$path:${index + 1}: the region $start starts inside the region $open',
        );
      }
      open = start;
      found = found || start == name;
    } else if (_regionEnd.hasMatch(line)) {
      if (open == null) {
        throw SnippetException(
          '$path:${index + 1}: end-snippet outside a region',
        );
      }
      open = null;
    } else if (open == name) {
      collected.add(line);
    }
  }
  if (open != null) {
    throw SnippetException('$path: the region $open is not closed');
  }
  if (!found) {
    throw SnippetException('$path has no region $name');
  }
  return dedent(collected).map((line) => '$line\n').join();
}

/// [lines] without the white space that every line that isn't blank starts
/// with; blank lines become empty.
List<String> dedent(List<String> lines) {
  String? common;
  for (final String line in lines) {
    if (line.trim().isEmpty) {
      continue;
    }
    final String indent = RegExp(r'^\s*').firstMatch(line)?[0] ?? '';
    if (common == null) {
      common = indent;
    } else {
      int length = 0;
      while (length < common.length &&
          length < indent.length &&
          common[length] == indent[length]) {
        length++;
      }
      common = common.substring(0, length);
    }
  }
  final int cut = common?.length ?? 0;
  return <String>[
    for (final String line in lines)
      line.trim().isEmpty ? '' : line.substring(cut),
  ];
}

/// The text of the first block of [file], README.md or a .md file directly
/// in docs/, whose marker is `<!-- snippet:<source> -->`.
String readmeBlock(String root, String source, {String file = 'README.md'}) {
  if (!markdownFiles(root).contains(file)) {
    throw SnippetException(
      '$file is not a checked Markdown file: README.md or a .md file directly in docs/',
    );
  }
  for (final _Block block in _blocks(file, _read(root, file), <String>[])) {
    final _Marker? marker = block.marker;
    if (marker != null && marker.kind == 'snippet' && marker.value == source) {
      return block.text;
    }
  }
  throw SnippetException('$file shows no block of $source');
}

String _read(String root, String file) {
  final File source = File('$root/$file');
  if (!source.existsSync()) {
    throw SnippetException('$file does not exist');
  }
  return source.readAsStringSync();
}

/// A marker line: its kind (snippet or unchecked), its value (the source or
/// the reason), and its line number.
final class _Marker {
  _Marker(this.kind, this.value, this.line);

  final String kind;
  final String value;
  final int line;
}

/// A fenced code block, its language and the marker before it.
final class _Block {
  _Block(this.language, this.text, this.marker);

  final String language;
  final String text;
  final _Marker? marker;
}

final RegExp _markerLine = RegExp(
  r'^<!--\s*(snippet|unchecked):\s*(.*?)\s*-->$',
);
final RegExp _fenceLine = RegExp(r'^(`{3,}|~{3,})(.*)$');

/// The fenced code blocks of [text], the content of [file]. Adds the problems
/// of the markers to [problems].
List<_Block> _blocks(String file, String text, List<String> problems) {
  final List<_Block> blocks = <_Block>[];
  final List<String> lines = text.split('\n');
  _Marker? pending;
  int index = 0;
  while (index < lines.length) {
    final String line = lines[index];
    final String trimmed = line.trimLeft();
    final RegExpMatch? fence = _fenceLine.firstMatch(trimmed);
    if (fence != null) {
      final String fenceChars = fence[1] ?? '```';
      final String language = (fence[2] ?? '')
          .trim()
          .split(RegExp(r'\s+'))
          .first
          .toLowerCase();
      final int indent = line.length - trimmed.length;
      int close = index + 1;
      while (close < lines.length && !_closes(lines[close], fenceChars)) {
        close++;
      }
      if (close >= lines.length) {
        problems.add('$file:${index + 1}: the code block is not closed');
        return blocks;
      }
      final String content = <String>[
        for (final String inner in lines.sublist(index + 1, close))
          _withoutIndent(inner, indent),
      ].map((inner) => '$inner\n').join();
      if (pending == null && checkedLanguages.contains(language)) {
        problems.add(
          '$file:${index + 1}: a $language block without a marker: '
          '<!-- snippet:<path> -->, <!-- snippet:<path>#<region> --> or <!-- unchecked: <reason> -->',
        );
      }
      blocks.add(_Block(language, content, pending));
      pending = null;
      index = close + 1;
      continue;
    }
    final RegExpMatch? marker = _markerLine.firstMatch(line.trim());
    if (marker != null) {
      if (pending != null) {
        problems.add('$file:${pending.line}: two markers before one block');
      }
      pending = _Marker(marker[1] ?? '', marker[2] ?? '', index + 1);
    } else if (line.trim().isNotEmpty && pending != null) {
      problems.add('$file:${pending.line}: no code block follows the marker');
      pending = null;
    }
    index++;
  }
  if (pending != null) {
    problems.add('$file:${pending.line}: no code block follows the marker');
  }
  return blocks;
}

bool _closes(String line, String fenceChars) {
  final String trimmed = line.trim();
  return trimmed.length >= fenceChars.length &&
      trimmed.split('').every((char) => char == fenceChars[0]);
}

String _withoutIndent(String line, int indent) {
  int cut = 0;
  while (cut < indent && cut < line.length && line[cut] == ' ') {
    cut++;
  }
  return line.substring(cut);
}

String _firstDifference(String actual, String expected) {
  final List<String> shown = actual.split('\n');
  final List<String> source = expected.split('\n');
  for (int index = 0; index < shown.length || index < source.length; index++) {
    final String? left = index < shown.length ? shown[index] : null;
    final String? right = index < source.length ? source[index] : null;
    if (left != right) {
      return 'line ${index + 1} of the block is ${left == null ? 'missing' : '"$left"'}, '
          'the source has ${right == null ? 'no such line' : '"$right"'}';
    }
  }
  return 'they differ';
}

final RegExp _namedVersion = RegExp(
  r'SallaPush (iOS|Android) ([0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.]+)?)',
);

void _checkVersions(String root, List<String> files, List<String> problems) {
  final Map<String, String> pins = <String, String>{};
  for (final MapEntry<String, (String, String)> pin in pinFiles.entries) {
    final (String platform, String pattern) = pin.value;
    final File file = File('$root/${pin.key}');
    final RegExpMatch? match = file.existsSync()
        ? RegExp(pattern).firstMatch(file.readAsStringSync())
        : null;
    final String? version = match?[1];
    if (version == null) {
      problems.add('${pin.key}: no SallaPush $platform pin');
    } else {
      pins.putIfAbsent(platform, () => version);
    }
  }
  final String? package = RegExp(
    r'^version: (\S+)$',
    multiLine: true,
  ).firstMatch(_read(root, 'pubspec.yaml'))?[1];

  for (final String file in files) {
    final List<String> lines = _read(root, file).split('\n');
    for (int index = 0; index < lines.length; index++) {
      for (final RegExpMatch match in _namedVersion.allMatches(lines[index])) {
        final String platform = match[1] == 'iOS' ? 'ios' : 'android';
        final String? pin = pins[platform];
        if (pin != null && match[2] != pin) {
          problems.add(
            '$file:${index + 1}: names SallaPush ${match[1]} ${match[2]}, but the pin is $pin',
          );
        }
      }
    }
  }

  final List<String> readme = _read(root, 'README.md').split('\n');
  final int header = readme.indexWhere(
    (line) => RegExp(
      r'^\|\s*Wrapper\s*\|\s*SallaPush iOS\s*\|\s*SallaPush Android\s*\|',
    ).hasMatch(line),
  );
  if (header < 0) {
    problems.add(
      'README.md: no versions table (| Wrapper | SallaPush iOS | SallaPush Android | Framework | iOS | Android |)',
    );
    return;
  }
  for (
    int index = header + 2;
    index < readme.length && readme[index].startsWith('|');
    index++
  ) {
    final List<String> cells = readme[index]
        .split('|')
        .map((cell) => cell.trim())
        .toList();
    if (cells.length < 4 || !cells[1].startsWith('Flutter ')) {
      continue;
    }
    final List<(String, String?)> expected = <(String, String?)>[
      (cells[1], 'Flutter $package'),
      (cells[2], pins['ios']),
      (cells[3], pins['android']),
    ];
    for (final (String actual, String? wanted) in expected) {
      if (wanted != null && actual != wanted) {
        problems.add(
          'README.md:${index + 1}: the versions table says $actual, not $wanted',
        );
      }
    }
    return;
  }
  problems.add(
    'README.md:${header + 1}: the versions table has no Flutter row',
  );
}
