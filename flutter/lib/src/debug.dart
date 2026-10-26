import 'dart:async';

import 'channels.dart';
import 'mapping.dart';
import 'messages.g.dart';
import 'models.dart';

/// Logging controls.
final class SallaPushDebug {
  const SallaPushDebug._();

  /// The console log level in effect.
  Future<SallaPushLogLevel> get logLevel async =>
      (await _host.logLevel()).level;

  /// Sets the console log level at run time. It overrides
  /// `SallaPushConfig.logLevel` and the static keys, and stays until the app
  /// ends. [SallaPushLogLevel.off] silences the console only.
  Future<void> setLogLevel(SallaPushLogLevel level) =>
      _host.setLogLevel(level.message);

  /// One handler for the app: a new one replaces the previous one; null
  /// removes it. Entries at [level] or more severe. On iOS the native handler
  /// is process-wide, so this replaces a handler set from native code.
  ///
  /// The handler's level is its own: [setLogLevel] and the static keys set the
  /// console's. Entries arrive asynchronously, on this isolate. The first
  /// handler set in the process also receives up to 100 warnings and errors
  /// SallaPush logged before it, such as those of its start at launch.
  Future<void> setLogHandler(
    SallaPushLogLevel level,
    void Function(SallaPushLogEntry entry)? handler,
  ) {
    final SallaPushChannels channels = SallaPushChannels.current;
    return (_logHandlers[channels] ??= _LogHandler(
      channels,
    )).set(level, handler);
  }

  static SallaPushHostApi get _host => SallaPushChannels.current.host;

  static final Expando<_LogHandler> _logHandlers = Expando<_LogHandler>();
}

/// The log handler of one isolate, fed by the platform log stream while it is
/// set.
final class _LogHandler {
  _LogHandler(this._channels);

  final SallaPushChannels _channels;
  void Function(SallaPushLogEntry entry)? _handler;
  StreamSubscription<LogEntryMessage>? _entries;

  Future<void> set(
    SallaPushLogLevel level,
    void Function(SallaPushLogEntry entry)? handler,
  ) async {
    _handler = handler;
    if (handler == null) {
      final StreamSubscription<LogEntryMessage>? entries = _entries;
      _entries = null;
      await entries?.cancel();
      return;
    }
    // Native registers at the level it has when the listen arrives, so the
    // level goes first; while listening, a new level re-registers natively.
    await _channels.host.setLogHandlerLevel(level.message);
    if (identical(_handler, handler)) {
      _entries ??= _channels.logEntries.listen(
        (LogEntryMessage message) => _handler?.call(message.entry),
      );
    }
  }
}

/// The one [SallaPushDebug], `SallaPush.debug`.
const SallaPushDebug debugNamespace = SallaPushDebug._();
