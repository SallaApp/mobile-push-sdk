// Checks that every public symbol of the native SallaPush SDKs has a decision in
// tool/api-parity/mapping.json: wrapped on both platforms (W), on iOS only (I)
// or on Android only (A), used natively by the plugin or the app (N), or not
// wrapped (X), with a reason for N and X.
//
//   dart run tool/check_api_parity.dart    run from the flutter/ folder; exits 1 on a problem
//
// It reads the native API files vendored at the pinned versions, the mapping,
// the Dart API dump (api/mobile_push.api, see tool/dump_api.dart) and the
// native pins, and names every problem:
//   1. nativeVersions differs from a pin;
//   2. a native symbol is in no entry, or in more than one;
//   3. an entry names a symbol that the native files don't have;
//   4. a status other than W, I, A, N or X; N or X without a reason; W, I or A
//      without a Dart symbol; native symbols of the wrong platform for the
//      status;
//   5. a Dart symbol that the API dump doesn't have.
// The output ends with a count per status.
import 'dart:convert';
import 'dart:io';

/// SallaPush iOS's API.txt at the pinned version.
const String iosApiFile = 'tool/api-parity/native-ios-API.txt';

/// SallaPush Android's sallapush/api/sallapush.api at the pinned version.
const String androidApiFile = 'tool/api-parity/native-android-sallapush.api';

/// The decisions: one entry per status of each row of the parity table.
const String mappingFile = 'tool/api-parity/mapping.json';

/// The Dart API dump.
const String wrapperDumpFile = 'api/mobile_push.api';

/// The files that pin a native SDK: the platform, and the pattern whose first
/// group is the pinned version.
const Map<String, (String, String)> pinFiles = <String, (String, String)>{
  'ios/mobile_push.podspec': ('ios', r"s\.dependency 'SallaPush', '([^']+)'"),
  'ios/mobile_push/Package.swift': (
    'ios',
    r'/mobile-push-ios-sdk\.git", exact: "([^"]+)"',
  ),
  'android/build.gradle.kts': ('android', r'"com\.salla:mobile-push:([^"]+)"'),
};

/// The statuses, in the order of the summary.
const List<String> statuses = <String>['W', 'I', 'A', 'N', 'X'];

void main() {
  final ParityReport report;
  try {
    report = checkParity(
      iosApi: File(iosApiFile).readAsStringSync(),
      androidApi: File(androidApiFile).readAsStringSync(),
      mapping: File(mappingFile).readAsStringSync(),
      wrapperDump: File(wrapperDumpFile).readAsStringSync(),
      pins: <String, String>{
        for (final String path in pinFiles.keys)
          path: File(path).readAsStringSync(),
      },
    );
  } on FileSystemException catch (error) {
    stderr.writeln(
      'check_api_parity: cannot read ${error.path}: ${error.message}',
    );
    exitCode = 1;
    return;
  }
  report.problems.forEach(stdout.writeln);
  stdout.writeln(
    report.problems.isEmpty
        ? 'check_api_parity: each of the ${report.iosSymbols} iOS and '
              '${report.androidSymbols} Android symbols has exactly one decision '
              '(${report.entries} entries)'
        : 'check_api_parity: ${report.problems.length} problem(s)',
  );
  report.summary.forEach(stdout.writeln);
  if (report.problems.isNotEmpty) {
    exitCode = 1;
  }
}

/// The outcome of a parity check.
final class ParityReport {
  /// Creates a report.
  ParityReport({
    required this.problems,
    required this.summary,
    required this.iosSymbols,
    required this.androidSymbols,
    required this.entries,
  });

  /// Each problem, named; empty when every decision is complete and
  /// consistent.
  final List<String> problems;

  /// One line per status: its entries and native symbols.
  final List<String> summary;

  /// The number of native iOS symbols.
  final int iosSymbols;

  /// The number of native Android symbols.
  final int androidSymbols;

  /// The number of entries.
  final int entries;
}

/// Checks [mapping], the text of mapping.json, against the native API files
/// [iosApi] and [androidApi], the Dart API dump [wrapperDump], and [pins]: the
/// text of each file of [pinFiles], by path.
ParityReport checkParity({
  required String iosApi,
  required String androidApi,
  required String mapping,
  required String wrapperDump,
  required Map<String, String> pins,
}) {
  final List<String> problems = <String>[];
  final List<String> iosKeys = _nativeKeys(
    iosApiFile,
    iosApi,
    iosSymbols,
    problems,
  );
  final List<String> androidKeys = _nativeKeys(
    androidApiFile,
    androidApi,
    androidSymbols,
    problems,
  );
  final Set<String> wrapperSymbols = dumpSymbols(wrapperDump);
  Object? json;
  try {
    json = jsonDecode(mapping);
  } on FormatException catch (error) {
    problems.add('$mappingFile is not JSON: ${error.message}');
  }
  final List<_Entry> entries;
  switch (json) {
    case <String, Object?>{
              'nativeVersions': <String, Object?>{
                'ios': final String ios,
                'android': final String android,
              },
              'entries': final List<Object?> list,
            } &&
            final Map<String, Object?> root
        when root.length == 2:
      _checkPins(ios, android, pins, problems);
      entries = _entries(list, problems);
    default:
      if (json != null) {
        problems.add(
          '$mappingFile must be {"nativeVersions": {"ios": "<version>", '
          '"android": "<version>"}, "entries": [...]}',
        );
      }
      entries = const <_Entry>[];
  }

  for (final (String platform, String file, List<String> keys)
      in <(String, String, List<String>)>[
        ('ios', iosApiFile, iosKeys),
        ('android', androidApiFile, androidKeys),
      ]) {
    final Map<String, List<String>> owners = <String, List<String>>{};
    for (final _Entry entry in entries) {
      for (final String key in platform == 'ios' ? entry.ios : entry.android) {
        (owners[key] ??= <String>[]).add(entry.id);
      }
    }
    for (final String key in keys) {
      final List<String> ids = owners[key] ?? const <String>[];
      if (ids.isEmpty) {
        problems.add('unmapped $platform symbol: $key');
      } else if (ids.length > 1) {
        problems.add(
          '$platform symbol mapped ${ids.length} times (${ids.join(', ')}): $key',
        );
      }
    }
    final Set<String> known = keys.toSet();
    for (final MapEntry<String, List<String>> owner in owners.entries) {
      if (!known.contains(owner.key)) {
        problems.add(
          '${owner.value.join(', ')}: $file has no such symbol: ${owner.key}',
        );
      }
    }
  }

  for (final _Entry entry in entries) {
    _checkStatus(entry, problems);
    for (final String symbol in entry.dart) {
      if (!wrapperSymbols.contains(symbol)) {
        problems.add(
          '${entry.id}: $wrapperDumpFile has no Dart symbol $symbol',
        );
      }
    }
  }

  return ParityReport(
    problems: problems,
    summary: <String>[
      for (final String status in statuses)
        _count(
          status,
          entries.where((entry) => entry.status == status).toList(),
        ),
    ],
    iosSymbols: iosKeys.length,
    androidSymbols: androidKeys.length,
    entries: entries.length,
  );
}

String _count(String status, List<_Entry> entries) {
  int ios = 0;
  int android = 0;
  for (final _Entry entry in entries) {
    ios += entry.ios.length;
    android += entry.android.length;
  }
  final String count = entries.length == 1
      ? '1 entry'
      : '${entries.length} entries';
  return '$status: $count, $ios iOS and $android Android symbols';
}

void _checkPins(
  String ios,
  String android,
  Map<String, String> pins,
  List<String> problems,
) {
  for (final MapEntry<String, (String, String)> pin in pinFiles.entries) {
    final (String platform, String pattern) = pin.value;
    final String expected = platform == 'ios' ? ios : android;
    final List<String?> found = <String?>[
      for (final RegExpMatch match in RegExp(
        pattern,
      ).allMatches(pins[pin.key] ?? ''))
        match[1],
    ];
    if (found.length != 1) {
      problems.add(
        '${pin.key}: expected one SallaPush $platform pin, found ${found.length}',
      );
    } else if (found.single != expected) {
      problems.add(
        '${pin.key} pins SallaPush $platform ${found.single}, but nativeVersions.$platform '
        'is $expected: map the API files of the pinned version (scripts/bump-native.sh)',
      );
    }
  }
}

void _checkStatus(_Entry entry, List<String> problems) {
  final String id = entry.id;
  switch (entry.status) {
    case 'W' when entry.ios.isEmpty || entry.android.isEmpty:
      problems.add(
        '$id: status W (both platforms) needs iOS and Android symbols',
      );
    case 'I' when entry.ios.isEmpty || entry.android.isNotEmpty:
      problems.add(
        '$id: status I (iOS only) needs iOS symbols and no Android symbol',
      );
    case 'A' when entry.android.isEmpty || entry.ios.isNotEmpty:
      problems.add(
        '$id: status A (Android only) needs Android symbols and no iOS symbol',
      );
    case 'W' || 'I' || 'A':
      break;
    case 'N' || 'X':
      if (entry.ios.isEmpty && entry.android.isEmpty) {
        problems.add('$id: status ${entry.status} needs a native symbol');
      }
      if ((entry.reason ?? '').trim().isEmpty) {
        problems.add('$id: status ${entry.status} needs a reason');
      }
      if (entry.dart.isNotEmpty) {
        problems.add(
          '$id: status ${entry.status} is not wrapped, so it lists no Dart symbol',
        );
      }
    default:
      problems.add('$id: unknown status "${entry.status}" (W, I, A, N or X)');
  }
  if ((entry.status == 'W' || entry.status == 'I' || entry.status == 'A') &&
      entry.dart.isEmpty) {
    problems.add('$id: status ${entry.status} needs at least one Dart symbol');
  }
}

List<String> _nativeKeys(
  String file,
  String text,
  List<String> Function(String text) parse,
  List<String> problems,
) {
  try {
    final List<String> keys = parse(text);
    final Set<String> seen = <String>{};
    for (final String key in keys) {
      if (!seen.add(key)) {
        problems.add('$file lists a symbol twice: $key');
      }
    }
    return keys;
  } on FormatException catch (error) {
    problems.add('$file: ${error.message}');
    return const <String>[];
  }
}

/// The symbols of SallaPush iOS's API.txt: each line,
/// `<module> | <kind> | <name> | <declaration>`, is one symbol's key.
List<String> iosSymbols(String text) {
  final List<String> keys = <String>[];
  final List<String> lines = const LineSplitter().convert(text);
  for (int index = 0; index < lines.length; index++) {
    final String line = lines[index];
    if (line.trim().isEmpty) {
      continue;
    }
    if (line.split(' | ').length < 4) {
      throw FormatException(
        'line ${index + 1} is not "<module> | <kind> | <name> | <declaration>": $line',
      );
    }
    keys.add(line);
  }
  return keys;
}

final RegExp _androidClass = RegExp(
  r'^(?:public |protected )?(?:(?:abstract|final|open|sealed|static) )*'
  r'(?:(?:interface|annotation|enum) )?class ([\w/$]+)(?: : .*)? \{$',
);
final RegExp _androidFunction = RegExp(
  r'^\t(?:public |protected )?(?:(?:abstract|final|open|static|synthetic) )*fun (\S+) (\S+)$',
);
final RegExp _androidField = RegExp(
  r'^\t(?:public |protected )?(?:(?:final|static|synthetic) )*field (\S+) \S+$',
);

/// The symbols of SallaPush Android's API dump (sallapush.api):
/// `<class path>` for a class, `<class path>#<name> <descriptor>` for a fun
/// (a constructor is `<init>`), and `<class path>#<NAME>` for a field.
List<String> androidSymbols(String text) {
  final List<String> keys = <String>[];
  String? owner;
  final List<String> lines = const LineSplitter().convert(text);
  for (int index = 0; index < lines.length; index++) {
    final String line = lines[index];
    if (line.trim().isEmpty) {
      continue;
    }
    if (owner == null) {
      final String? path = _androidClass.firstMatch(line)?[1];
      if (path == null) {
        throw FormatException('line ${index + 1} is not a class line: $line');
      }
      owner = path;
      keys.add(path);
      continue;
    }
    if (line == '}') {
      owner = null;
      continue;
    }
    final RegExpMatch? function = _androidFunction.firstMatch(line);
    final RegExpMatch? field = _androidField.firstMatch(line);
    if (function != null) {
      keys.add('$owner#${function[1]} ${function[2]}');
    } else if (field != null) {
      keys.add('$owner#${field[1]}');
    } else {
      throw FormatException(
        'line ${index + 1} is not a fun, a field or "}": $line',
      );
    }
  }
  if (owner != null) {
    throw FormatException('the class $owner is not closed');
  }
  return keys;
}

final RegExp _declarationLine = RegExp(
  r'^(?:(?:abstract|base|final|interface|sealed|mixin) )*'
  r'(?:class|mixin|enum|extension type|extension|typedef) ([\w$]+)',
);
final RegExp _memberLine = RegExp(
  r'^[\w$]+(?:\.(?:operator[^\w\s(]+|[\w$]+))?',
);
final RegExp _enumConstants = RegExp(r' \{ ([^}]*) \}');

/// The symbols that the Dart API dump declares: `Name` for a class, enum,
/// mixin, extension or typedef line, and `Enum.constant` for each constant of
/// an enum; `Name.member`, or a top-level `name`, for each other line.
Set<String> dumpSymbols(String dump) {
  final Set<String> symbols = <String>{};
  for (final String line in const LineSplitter().convert(dump)) {
    final RegExpMatch? declaration = _declarationLine.firstMatch(line);
    final String? name = declaration?[1];
    if (name != null) {
      symbols.add(name);
      if (line.startsWith('enum ')) {
        for (final String constant
            in (_enumConstants.firstMatch(line)?[1] ?? '').split(', ')) {
          if (constant.isNotEmpty) {
            symbols.add('$name.$constant');
          }
        }
      }
      continue;
    }
    final String? member = _memberLine.firstMatch(line)?[0];
    if (member != null) {
      symbols.add(member);
    }
  }
  return symbols;
}

/// One entry of mapping.json.
final class _Entry {
  _Entry(this.id, this.status, this.ios, this.android, this.dart, this.reason);

  final String id;
  final String status;
  final List<String> ios;
  final List<String> android;
  final List<String> dart;
  final String? reason;
}

const Set<String> _entryFields = <String>{
  'id',
  'status',
  'ios',
  'android',
  'dart',
  'reason',
};

List<_Entry> _entries(List<Object?> list, List<String> problems) {
  final List<_Entry> entries = <_Entry>[];
  final Set<String> ids = <String>{};
  for (int index = 0; index < list.length; index++) {
    final Object? item = list[index];
    final String where = 'entry ${index + 1}';
    switch (item) {
      case <String, Object?>{
            'id': final String id,
            'status': final String status,
            'ios': final List<Object?> ios,
            'android': final List<Object?> android,
            'dart': final List<Object?> dart,
            'reason': final String? reason,
          }
          when id.isNotEmpty &&
              item.length == _entryFields.length &&
              <List<Object?>>[
                ios,
                android,
                dart,
              ].every((symbols) => symbols.every((symbol) => symbol is String)):
        if (!ids.add(id)) {
          problems.add('$id: the id is used twice');
        }
        entries.add(
          _Entry(
            id,
            status,
            ios.cast<String>(),
            android.cast<String>(),
            dart.cast<String>(),
            reason,
          ),
        );
      case <String, Object?>{'id': final String id} when id.isNotEmpty:
        problems.add(_shape(id, item));
      default:
        problems.add(_shape(where, item));
    }
  }
  return entries;
}

String _shape(String name, Object? item) {
  final Set<String> fields = item is Map<String, Object?>
      ? item.keys.toSet()
      : const <String>{};
  final Set<String> unknown = fields.difference(_entryFields);
  final Set<String> missing = _entryFields.difference(fields);
  return '$name: an entry is {"id": "<id>", "status": "<status>", "ios": [...], '
      '"android": [...], "dart": [...], "reason": "<reason>" or null}'
      '${unknown.isEmpty ? '' : '; unknown: ${unknown.join(', ')}'}'
      '${missing.isEmpty ? '' : '; missing: ${missing.join(', ')}'}';
}
