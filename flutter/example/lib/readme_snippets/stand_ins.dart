// Stand-ins for the app code that the README snippets call. They have the
// members the snippets use, so that the snippets compile exactly as the README
// shows them; the example never runs them.

/// The app's router for notification taps.
final class AppRouter {
  /// Shows the product with this id.
  void showProduct(int id) {}

  /// Opens a link.
  void openUrl(String url) {}
}

/// The app's settings screen.
final class SettingsScreen {
  /// Shows the SallaPush device id and whether SallaPush notifications are on.
  void showDevice(String? deviceId, {required bool optedIn}) {}
}

/// The app's telemetry.
final class Telemetry {
  /// Reports an entry of [source], with its stable [code].
  void report(
    String source,
    String code,
    String message,
    Map<String, String> metadata,
  ) {}
}
