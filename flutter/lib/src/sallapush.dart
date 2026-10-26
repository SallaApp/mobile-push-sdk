import 'channels.dart';
import 'config.dart';
import 'debug.dart';
import 'mapping.dart';
import 'messages.g.dart';
import 'migration.dart';
import 'notifications.dart';
import 'user.dart';

/// Entry point. All members are static; calls are safe at any time, before or
/// after initialization.
///
/// Every call goes to the native SallaPush SDK, which validates it: invalid
/// arguments are logged natively and ignored, and the futures still complete
/// normally. They fail only when the plugin is missing from the app.
abstract final class SallaPush {
  /// Starts SallaPush with [appId] when the app id is known only at run time.
  /// Apps that set the static app id (SallaPushAppId / com.salla.push.APP_ID)
  /// never need it: SallaPush has already started natively, and a call with the
  /// same app id changes nothing, its [config] included. Such a call with
  /// options set prints a console error naming the ignored options and the
  /// static keys to use instead.
  ///
  /// A call with another app id switches SallaPush to it. An invalid first app
  /// id disables SallaPush until the app is launched again.
  static Future<void> initialize(
    String appId, {
    SallaPushConfig config = const SallaPushConfig(),
  }) => _host.initialize(appId, config.message);

  /// Whether SallaPush runs: true once a valid app id started it, natively at
  /// launch or with [initialize]; false before, and for the rest of the
  /// process after an invalid first app id.
  static Future<bool> get isInitialized => _host.isInitialized();

  /// The app id SallaPush runs with; null before it started, and after an
  /// invalid first app id.
  static Future<String?> get appId => _host.appId();

  /// The version of the native SallaPush SDK in use on this platform, for
  /// example "1.1.0".
  static Future<String> get sdkVersion => _host.sdkVersion();

  /// Requires consent before any data processing. With the static app id,
  /// SallaPush started before Dart ran: require consent with the static key
  /// (SallaPushRequiresUserConsent / com.salla.push.REQUIRES_USER_CONSENT)
  /// instead. A call with true after that start, without the key, prints a
  /// console error: data may already be sent.
  ///
  /// It is not persisted: without the static key, call it before [initialize]
  /// at every launch. False lowers only what an earlier true raised.
  static Future<void> setConsentRequired(bool required) =>
      _host.setConsentRequired(required);

  /// Records the user's consent answer, persisted for the app. While consent is
  /// required, withdrawing it opts the device out, deletes its tags and unlinks
  /// it on the server, in separate requests, and SallaPush then sends nothing
  /// until consent is given again.
  static Future<void> setConsentGiven(bool given) =>
      _host.setConsentGiven(given);

  /// Links this device to the customer [externalId] (the Salla customer id),
  /// proven by [identityToken], the customer token your app received from
  /// Salla when the customer signed in, without a `Bearer ` prefix. The token
  /// is kept in memory only.
  ///
  /// At every app start, call exactly one of [login] (signed in) or [logout]
  /// (signed out), right after SallaPush starts and before any tag call, and
  /// call it again at sign-in and whenever the app refreshes the token:
  /// SallaPush links the device with the token it holds. Call [logout] before
  /// another customer's login. Both arguments are trimmed natively; an empty or
  /// too long one is logged and ignored. A token the SallaPush server refuses
  /// comes on `SallaPush.user.onLoginFailure`, as
  /// `SallaPushLoginFailure.tokenRejected`; there is no success event.
  static Future<void> login({
    required String externalId,
    required String identityToken,
  }) => _host.login(externalId, identityToken);

  /// Unlinks the customer; the device stays registered as a guest. It works
  /// offline and without a token, and SallaPush retries it until the
  /// SallaPush server confirms it. Call it at sign-out, and at every app start
  /// while signed out (see [login]).
  static Future<void> logout() => _host.logout();

  /// The user of this device: the customer the app logged in, tags, language
  /// and the push subscription.
  static final SallaPushUser user = userNamespace;

  /// Notification permission, push token forwarding and notification helpers.
  static final SallaPushNotifications notifications = notificationsNamespace;

  /// Logging controls.
  static final SallaPushDebug debug = debugNamespace;

  /// Helpers for apps that also run another push SDK.
  static final SallaPushMigration migration = migrationNamespace;

  static SallaPushHostApi get _host => SallaPushChannels.current.host;
}
