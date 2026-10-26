import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_coverage.dart';

/// An lcov record of [path] with [covered] lines hit and [missed] lines not.
String record(String path, int covered, int missed) => <String>[
  'SF:$path',
  for (int line = 1; line <= covered; line++) 'DA:$line,3',
  for (int line = covered + 1; line <= covered + missed; line++) 'DA:$line,0',
  'LF:${covered + missed}',
  'LH:$covered',
  'end_of_record',
].join('\n');

void main() {
  test('counts the lines of lib/src only, without the generated messages', () {
    final CoverageReport report = checkCoverage(
      <String>[
        record('lib/src/user.dart', 18, 2),
        record('lib/src/messages.g.dart', 10, 90),
        record('lib/mobile_push.dart', 0, 5),
        record('/home/runner/work/sdk/lib/src/debug.dart', 9, 1),
      ].join('\n'),
      minimum: 90,
    );

    expect(report.passed, isTrue);
    expect(report.lines, <String>[
      '90.0 %  /home/runner/work/sdk/lib/src/debug.dart (9/10)',
      '90.0 %  lib/src/user.dart (18/20)',
      'check_coverage: 90.0 % of the lines of lib/src (27/30), at least the minimum of 90 %',
    ]);
  });

  test('fails below the minimum', () {
    final CoverageReport report = checkCoverage(
      record('lib/src/user.dart', 89, 11),
      minimum: 90,
    );

    expect(report.passed, isFalse);
    expect(
      report.lines.last,
      'check_coverage: 89.0 % of the lines of lib/src (89/100), below the minimum of 90 %',
    );
  });

  test('fails when no file of lib/src was measured', () {
    final CoverageReport report = checkCoverage(
      record('lib/src/messages.g.dart', 1, 0),
      minimum: 90,
    );

    expect(report.passed, isFalse);
    expect(report.lines, <String>[
      'check_coverage: no file of lib/src in the coverage data; did the tests run?',
    ]);
  });

  test('a fractional minimum is shown with its decimal', () {
    expect(
      checkCoverage(
        record('lib/src/user.dart', 1, 0),
        minimum: 87.5,
      ).lines.last,
      'check_coverage: 100.0 % of the lines of lib/src (1/1), at least the minimum of 87.5 %',
    );
  });
}
