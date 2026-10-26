import 'package:flutter/foundation.dart';

import 'messages.g.dart';
import 'messages.g.dart'
    as pigeon
    show
        clickEvents,
        logEntries,
        loginFailures,
        permissionChanges,
        pushSubscriptionChanges,
        userChanges,
        willDisplayEvents;

/// The platform channels of SallaPush in this isolate: the Pigeon host API and
/// the platform event streams.
///
/// Each event stream is created once per isolate: a second platform listen on
/// a channel cancels the first, which is also what removes an earlier isolate's
/// native registrations after a hot restart.
class SallaPushChannels {
  /// The plugin's channels, on the default binary messenger.
  SallaPushChannels() : host = SallaPushHostApi();

  /// The channels every SallaPush call uses: [debugOverride] when a test set
  /// it, else the plugin's.
  static SallaPushChannels get current => debugOverride ?? _plugin;

  /// The channels this package's tests use in place of the plugin's; null
  /// restores the plugin's.
  @visibleForTesting
  static SallaPushChannels? debugOverride;

  static final SallaPushChannels _plugin = SallaPushChannels();

  /// The host API: each method is one call into the native SallaPush SDK.
  final SallaPushHostApi host;

  /// Taps on SallaPush notifications. Native listens while this stream has a
  /// listener.
  late final Stream<ClickEventMessage> clickEvents = pigeon.clickEvents();

  /// The foreground notifications SallaPush holds for Dart's decision, each
  /// under a handle for `SallaPushHostApi.displayNotification`.
  late final Stream<WillDisplayEventMessage> willDisplayEvents = pigeon
      .willDisplayEvents();

  /// Changes of the notification permission.
  late final Stream<PermissionChangeMessage> permissionChanges = pigeon
      .permissionChanges();

  /// Changes of the user's login state.
  late final Stream<UserChangedMessage> userChanges = pigeon.userChanges();

  /// Refusals of the current login.
  late final Stream<LoginFailureEventMessage> loginFailures = pigeon
      .loginFailures();

  /// The push subscription changes of every native observer that
  /// `SallaPushHostApi.addPushSubscriptionListener` added, each tagged with
  /// its listener id.
  late final Stream<SubscriptionChangedMessage> pushSubscriptionChanges = pigeon
      .pushSubscriptionChanges();

  /// SallaPush's log entries at the level of
  /// `SallaPushHostApi.setLogHandlerLevel`. Native registers its log handler
  /// while this stream has a listener.
  late final Stream<LogEntryMessage> logEntries = pigeon.logEntries();
}

/// [call], with a failure reported to Flutter as Flutter's event channels
/// report a failed platform listen; [context] says what failed, for example
/// "while adding a push subscription listener".
Future<void> reportingFailure(Future<void> call, String context) =>
    call.catchError(
      (Object error, StackTrace stack) => FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'mobile_push',
          context: ErrorDescription(context),
        ),
      ),
    );
