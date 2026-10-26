// Fails when the unit tests cover less than the given share of the lines of
// lib/src, the generated messages.g.dart excluded.
//
//   dart run tool/check_coverage.dart --min 90 coverage/lcov.info
//
// coverage/lcov.info is what `flutter test --coverage` writes.
import 'dart:io';

/// The library files that count, by their path: lib/src, without the code
/// Pigeon generates.
bool counts(String path) =>
    RegExp(r'(^|/)lib/src/').hasMatch(path) &&
    !path.endsWith('/messages.g.dart');

void main(List<String> arguments) {
  final double? minimum = arguments.length == 3 && arguments[0] == '--min'
      ? double.tryParse(arguments[1])
      : null;
  if (minimum == null || minimum < 0 || minimum > 100) {
    stderr.writeln(
      'usage: dart run tool/check_coverage.dart --min <percent> <lcov.info>',
    );
    exitCode = 2;
    return;
  }
  final File lcov = File(arguments[2]);
  if (!lcov.existsSync()) {
    stderr.writeln(
      'check_coverage: ${lcov.path} does not exist; run flutter test --coverage first',
    );
    exitCode = 1;
    return;
  }
  final CoverageReport report = checkCoverage(
    lcov.readAsStringSync(),
    minimum: minimum,
  );
  report.lines.forEach(stdout.writeln);
  if (!report.passed) {
    exitCode = 1;
  }
}

/// The outcome of a coverage check.
final class CoverageReport {
  /// Creates a report.
  CoverageReport({required this.passed, required this.lines});

  /// Whether the counted files reach the minimum.
  final bool passed;

  /// One line per counted file, then the total and the verdict.
  final List<String> lines;
}

/// Checks the line coverage that [lcov], the text of an lcov.info file, gives
/// the files that [counts], against [minimum] percent.
CoverageReport checkCoverage(String lcov, {required double minimum}) {
  final Map<String, (int, int)> files = <String, (int, int)>{};
  String? file;
  for (final String line in lcov.split('\n')) {
    if (line.startsWith('SF:')) {
      file = line.substring(3).trim();
      files.putIfAbsent(file, () => (0, 0));
    } else if (line.startsWith('DA:') && file != null) {
      final List<String> fields = line.substring(3).split(',');
      final int hits = fields.length < 2 ? 0 : int.tryParse(fields[1]) ?? 0;
      final (int covered, int total) = files[file] ?? (0, 0);
      files[file] = (covered + (hits > 0 ? 1 : 0), total + 1);
    } else if (line.trim() == 'end_of_record') {
      file = null;
    }
  }
  final List<String> counted = files.keys.where(counts).toList()..sort();
  if (counted.isEmpty) {
    return CoverageReport(
      passed: false,
      lines: <String>[
        'check_coverage: no file of lib/src in the coverage data; did the tests run?',
      ],
    );
  }
  int covered = 0;
  int total = 0;
  final List<String> lines = <String>[];
  for (final String path in counted) {
    final (int fileCovered, int fileTotal) = files[path] ?? (0, 0);
    covered += fileCovered;
    total += fileTotal;
    lines.add(
      '${_percent(fileCovered, fileTotal)}  $path ($fileCovered/$fileTotal)',
    );
  }
  final double share = total == 0 ? 100 : 100 * covered / total;
  final bool passed = share >= minimum;
  lines.add(
    'check_coverage: ${_percent(covered, total)} of the lines of lib/src '
    '($covered/$total), ${passed ? 'at least' : 'below'} the minimum of '
    '${minimum.toStringAsFixed(minimum.truncateToDouble() == minimum ? 0 : 1)} %',
  );
  return CoverageReport(passed: passed, lines: lines);
}

String _percent(int covered, int total) =>
    '${(total == 0 ? 100 : 100 * covered / total).toStringAsFixed(1)} %';
