import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_push/mobile_push.dart';
import 'package:mobile_push/src/channels.dart';
import 'package:mobile_push/src/messages.g.dart';

import 'fakes/fake_channels.dart';

LogEntryMessage logEntry(String code, {LogLevelMessage? level}) =>
    LogEntryMessage(
      level: level ?? LogLevelMessage.warn,
      category: 'registration',
      code: code,
      message: 'The push service is unavailable; SallaPush retries later.',
      metadata: <String, String>{'http_status': '503', 'attempt': '2'},
      timestampMillis: 1791842518123,
    );

void main() {
  final SallaPushDebug debug = SallaPush.debug;
  late FakeChannels native;

  setUp(() {
    native = FakeChannels();
    SallaPushChannels.debugOverride = native;
  });

  tearDown(() {
    SallaPushChannels.debugOverride = null;
  });

  test('logLevel reads every level by case at every call', () async {
    final List<SallaPushLogLevel> levels = <SallaPushLogLevel>[];
    for (final LogLevelMessage level in LogLevelMessage.values) {
      native.logLevelResult = level;
      levels.add(await debug.logLevel);
    }

    expect(levels, SallaPushLogLevel.values);
    expect(native.calls, hasLength(LogLevelMessage.values.length));
  });

  test('setLogLevel passes every level by case', () async {
    for (final SallaPushLogLevel level in SallaPushLogLevel.values) {
      await debug.setLogLevel(level);
    }

    expect(native.calls, <Object?>[
      <Object?>['setLogLevel', LogLevelMessage.off],
      <Object?>['setLogLevel', LogLevelMessage.error],
      <Object?>['setLogLevel', LogLevelMessage.warn],
      <Object?>['setLogLevel', LogLevelMessage.info],
      <Object?>['setLogLevel', LogLevelMessage.debug],
      <Object?>['setLogLevel', LogLevelMessage.verbose],
    ]);
  });

  group('setLogHandler', () {
    test('sets the level before the platform listens', () async {
      await debug.setLogHandler(SallaPushLogLevel.debug, (_) {});

      expect(native.calls, <Object?>[
        <Object?>['setLogHandlerLevel', LogLevelMessage.debug],
        <Object?>['listen', 'logEntries'],
      ]);
    });

    test('gives the handler each entry, timestamped in UTC', () async {
      final List<SallaPushLogEntry> entries = <SallaPushLogEntry>[];
      await debug.setLogHandler(SallaPushLogLevel.warn, entries.add);

      native.logs.emit(logEntry('register.failed'));
      await pumpEventQueue();

      final SallaPushLogEntry entry = entries.single;
      expect(entry.level, SallaPushLogLevel.warn);
      expect(entry.category, 'registration');
      expect(entry.code, 'register.failed');
      expect(
        entry.message,
        'The push service is unavailable; SallaPush retries later.',
      );
      expect(entry.metadata, <String, String>{
        'http_status': '503',
        'attempt': '2',
      });
      expect(entry.timestamp, DateTime.utc(2026, 10, 12, 22, 1, 58, 123));
      expect(entry.timestamp.isUtc, isTrue);
    });

    test('maps every level by case', () async {
      final List<SallaPushLogLevel> levels = <SallaPushLogLevel>[];
      await debug.setLogHandler(
        SallaPushLogLevel.verbose,
        (SallaPushLogEntry entry) => levels.add(entry.level),
      );

      for (final LogLevelMessage level in LogLevelMessage.values) {
        native.logs.emit(logEntry('log.level', level: level));
      }
      await pumpEventQueue();

      expect(levels, SallaPushLogLevel.values);
    });

    test(
      'a new handler replaces the old one and re-registers at its level',
      () async {
        final List<String> first = <String>[];
        final List<String> second = <String>[];
        await debug.setLogHandler(
          SallaPushLogLevel.warn,
          (SallaPushLogEntry entry) => first.add(entry.code),
        );
        await debug.setLogHandler(
          SallaPushLogLevel.verbose,
          (SallaPushLogEntry entry) => second.add(entry.code),
        );

        native.logs.emit(logEntry('register.ok'));
        await pumpEventQueue();

        expect(first, isEmpty);
        expect(second, <String>['register.ok']);
        expect(native.logs.listens, 1);
        expect(native.calls, <Object?>[
          <Object?>['setLogHandlerLevel', LogLevelMessage.warn],
          <Object?>['listen', 'logEntries'],
          <Object?>['setLogHandlerLevel', LogLevelMessage.verbose],
        ]);
      },
    );

    test('null removes the handler and stops the platform stream', () async {
      final List<String> codes = <String>[];
      await debug.setLogHandler(
        SallaPushLogLevel.warn,
        (SallaPushLogEntry entry) => codes.add(entry.code),
      );

      await debug.setLogHandler(SallaPushLogLevel.warn, null);
      native.logs.emit(logEntry('register.ok'));
      await pumpEventQueue();

      expect(codes, isEmpty);
      expect(native.logs.cancels, 1);
      expect(native.logs.isListening, isFalse);

      await debug.setLogHandler(
        SallaPushLogLevel.error,
        (SallaPushLogEntry entry) => codes.add(entry.code),
      );
      native.logs.emit(logEntry('register.failed'));
      await pumpEventQueue();

      expect(codes, <String>['register.failed']);
      expect(native.logs.listens, 2);
    });

    test('a handler removed before its level was set never listens', () async {
      final Future<void> set = debug.setLogHandler(
        SallaPushLogLevel.warn,
        (_) {},
      );
      final Future<void> removed = debug.setLogHandler(
        SallaPushLogLevel.warn,
        null,
      );
      await set;
      await removed;

      expect(native.logs.listens, 0);
      expect(native.calls, <Object?>[
        <Object?>['setLogHandlerLevel', LogLevelMessage.warn],
      ]);
    });

    test('fails, and listens to nothing, without the plugin', () async {
      native.failing.add('setLogHandlerLevel');

      await expectLater(
        debug.setLogHandler(SallaPushLogLevel.warn, (_) {}),
        throwsA(isA<PlatformException>()),
      );
      expect(native.logs.listens, 0);
    });
  });
}
