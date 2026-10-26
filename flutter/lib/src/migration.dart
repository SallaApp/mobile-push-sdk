import 'channels.dart';
import 'messages.g.dart';

/// Helpers for apps that also run another push SDK, which can show
/// SallaPush's messages in the compatible format.
final class SallaPushMigration {
  const SallaPushMigration._();

  /// Android only. Does nothing on iOS. Applies to this process only; for
  /// every process use the static key
  /// com.salla.push.DISPLAY_COMPAT_PAYLOADS.
  ///
  /// Whether SallaPush shows the messages in the compatible format that reach
  /// it (default true). Turn it off only if a device shows two copies of a
  /// notification.
  Future<void> setDisplayCompatPayloads(bool display) =>
      _host.setDisplayCompatPayloads(display);

  static SallaPushHostApi get _host => SallaPushChannels.current.host;
}

/// The one [SallaPushMigration], `SallaPush.migration`.
const SallaPushMigration migrationNamespace = SallaPushMigration._();
