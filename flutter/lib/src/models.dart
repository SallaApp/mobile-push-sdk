import 'package:flutter/foundation.dart';

/// How much SallaPush logs, from silent to most detailed.
///
/// A sink, such as the console, gets an entry when the sink's level is not
/// [off] and the entry is at that level or more severe.
enum SallaPushLogLevel {
  /// Nothing is logged.
  off,

  /// Failures that need attention.
  error,

  /// Problems SallaPush recovered from, and likely integration mistakes. The
  /// default level.
  warn,

  /// Milestones such as registration, login and logout.
  info,

  /// Decisions and skipped work, for debugging an integration.
  debug,

  /// Everything.
  verbose,
}

/// iOS only: the APNs environment SallaPush reports for this build's push
/// token.
enum SallaPushApnsEnvironment {
  /// Read from the app's embedded provisioning profile: development means
  /// sandbox, anything else production. The simulator is always sandbox, and a
  /// build without a profile (App Store, TestFlight) is production.
  automatic,

  /// The development APNs servers, for debug builds signed with a development
  /// profile.
  sandbox,

  /// The production APNs servers, for App Store, TestFlight, ad hoc and
  /// enterprise builds.
  production,
}

/// iOS only: the notification authorization status, as iOS reports it.
enum SallaPushIosPermissionStatus {
  /// The user hasn't been asked yet. Also the status until SallaPush has read
  /// it, and for a status a later iOS adds.
  notDetermined,

  /// The user doesn't allow notifications.
  denied,

  /// The user allows notifications.
  authorized,

  /// Quiet notifications, allowed without asking the user.
  provisional,

  /// Allowed for a limited time, in an App Clip.
  ephemeral,
}

/// The format a SallaPush notification arrived in.
enum SallaPushPayloadSource {
  /// SallaPush's own format.
  native,

  /// The compatible format, which another push SDK in the app can also show.
  compat,
}

/// Why SallaPush could not link this device to the customer of the current
/// `SallaPush.login`.
enum SallaPushLoginFailure {
  /// The SallaPush server refused the identity token for this external id:
  /// it expired, was revoked or belongs to another customer, has a `Bearer `
  /// prefix, or the server couldn't check it. Call `SallaPush.login` again
  /// when the app next refreshes the token or at the next launch, never from
  /// the `onLoginFailure` listener.
  tokenRejected,

  /// The SallaPush server refused the login request. SallaPush doesn't send
  /// it again.
  invalidRequest,
}

/// A SallaPush notification, as SallaPush parsed it from the push.
///
/// Route with the typed getters rather than with [additionalData]: SallaPush's
/// own payloads carry text, while those in the compatible format keep JSON
/// types, and the getters read both the way SallaPush does natively.
final class SallaPushNotification {
  const SallaPushNotification._({
    required this.notificationId,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.imageUrl,
    required this.launchUrl,
    required this.additionalData,
    required this.rawPayload,
    required this.source,
    required this.sound,
    required this.badge,
    required this.threadId,
    required this.androidNotificationId,
    required this.collapseId,
    required this.channelId,
    required this._stringValues,
    required this._intValues,
    required this._boolValues,
    required this._numberValues,
    required this._display,
  });

  /// The SallaPush message id (`msg_…`); null when the push carries no valid
  /// id.
  final String? notificationId;

  /// The title.
  final String? title;

  /// The subtitle.
  final String? subtitle;

  /// The body text.
  final String? body;

  /// The https image URL.
  final String? imageUrl;

  /// The launch URL, exactly as sent. SallaPush opens an https launch URL
  /// itself only when openLaunchUrls is on.
  final String? launchUrl;

  /// The custom data, read-only: text values in SallaPush's own payloads, JSON
  /// values in those in the compatible format.
  final Map<String, Object?> additionalData;

  /// The push as received, read-only: the APNs payload on iOS, without values
  /// JSON can't hold, and the FCM data on Android.
  final Map<String, Object?> rawPayload;

  /// The format the push arrived in.
  final SallaPushPayloadSource source;

  /// The sound to play.
  final String? sound;

  /// iOS only: the badge number.
  final int? badge;

  /// iOS only: the thread identifier that groups notifications.
  final String? threadId;

  /// Android only: the id of the shown notification, for
  /// `SallaPush.notifications.removeNotification`.
  final int? androidNotificationId;

  /// Android only: the collapse key; notifications with the same key replace
  /// each other.
  final String? collapseId;

  /// Android only: the requested notification channel.
  final String? channelId;

  final Map<String, String> _stringValues;
  final Map<String, int> _intValues;
  final Map<String, bool> _boolValues;
  final Map<String, num> _numberValues;

  /// Shows this notification; set for the notifications of
  /// `SallaPush.notifications.onWillDisplay` only.
  final Future<void> Function()? _display;

  /// The top-level additionalData value for [key] as native's own accessor
  /// reads it (iOS string(forKey:), Android getString): numbers and booleans
  /// are converted. Null when absent or not convertible. Route with these typed
  /// getters: native payloads carry strings, those in the compatible format
  /// keep JSON types.
  String? getString(String key) => _stringValues[key];

  /// As native's int(forKey:) (iOS) or getLong(key) (Android): JSON numbers and
  /// numeric strings; exact or null.
  int? getInt(String key) => _intValues[key];

  /// As native's bool(forKey:) (iOS) or getBoolean(key) (Android): true/false,
  /// 1/0 and their string forms.
  bool? getBool(String key) => _boolValues[key];

  /// iOS only: as native's number(forKey:). Null on Android.
  num? getNumber(String key) => _numberValues[key];

  /// Shows a foreground notification a will-display listener prevented, once,
  /// within 10 minutes. Does nothing for any other notification, nor while
  /// its event isn't prevented: call `event.preventDefault()` first.
  ///
  /// On iOS it shows SallaPush's local copy of the notification, which has no
  /// image, no action buttons, no interruption level or relevance score, and is
  /// not replaced by a later push with the same collapse id.
  Future<void> display() {
    final Future<void> Function()? display = _display;
    if (display == null) {
      debugPrint(
        '[SallaPush] display() does nothing for a notification that '
        'onWillDisplay did not offer.',
      );
      return Future<void>.value();
    }
    return display();
  }

  @override
  String toString() =>
      'SallaPushNotification(notificationId: $notificationId, title: $title, '
      'subtitle: $subtitle, body: $body, imageUrl: $imageUrl, '
      'launchUrl: $launchUrl, additionalData: $additionalData, '
      'source: ${source.name}, sound: $sound, badge: $badge, '
      'threadId: $threadId, androidNotificationId: $androidNotificationId, '
      'collapseId: $collapseId, channelId: $channelId)';
}

/// What a tap on a notification asked for.
final class SallaPushClickResult {
  const SallaPushClickResult._({required this.actionId, required this.url});

  /// The identifier of the tapped action button; null for a tap on the
  /// notification itself, and always null on Android.
  final String? actionId;

  /// The notification's launch URL.
  final String? url;

  @override
  String toString() => 'SallaPushClickResult(actionId: $actionId, url: $url)';
}

/// A tap on a SallaPush notification.
final class SallaPushClickEvent {
  const SallaPushClickEvent._({
    required this.notification,
    required this.result,
  });

  /// The tapped notification.
  final SallaPushNotification notification;

  /// What the tap asked for.
  final SallaPushClickResult result;

  @override
  String toString() =>
      'SallaPushClickEvent(notification: $notification, result: $result)';
}

/// A SallaPush notification about to be shown while the app is in the
/// foreground.
///
/// Call [preventDefault] before the listener returns to keep it hidden:
/// SallaPush decides once the listeners have returned, so a call after an
/// `await` changes nothing, and neither does a call for an event that reached
/// an `await for` loop or a paused subscription late: listen with `listen()`.
/// A prevented notification can still be shown with `notification.display()`,
/// once, within 10 minutes.
final class SallaPushWillDisplayEvent {
  SallaPushWillDisplayEvent._({required this.notification});

  /// The notification about to be shown.
  final SallaPushNotification notification;

  bool _isPrevented = false;

  /// Whether [preventDefault] was called.
  bool get isPrevented => _isPrevented;

  /// Keeps the notification from being shown now.
  void preventDefault() {
    _isPrevented = true;
  }

  @override
  String toString() =>
      'SallaPushWillDisplayEvent(notification: $notification, '
      'isPrevented: $isPrevented)';
}

/// The push subscription at one moment.
final class SallaPushSubscriptionState {
  const SallaPushSubscriptionState._({
    required this.id,
    required this.token,
    required this.optedIn,
  });

  /// The SallaPush device id; null until the device is registered.
  final String? id;

  /// The push token; null until one is known. Treat it as private: never send
  /// it to analytics. [toString] shows only its last 6 characters.
  final String? token;

  /// Whether this device receives SallaPush notifications.
  final bool optedIn;

  @override
  String toString() {
    final String? token = this.token;
    final String shown = token == null
        ? 'null'
        : '…${token.substring(token.length < 6 ? 0 : token.length - 6)}';
    return 'SallaPushSubscriptionState(id: $id, token: $shown, '
        'optedIn: $optedIn)';
  }
}

/// A change of the push subscription.
final class SallaPushSubscriptionChangedState {
  const SallaPushSubscriptionChangedState._({
    required this.previous,
    required this.current,
  });

  /// The state before the change; equal to [current] in the replay a new
  /// listener gets.
  final SallaPushSubscriptionState previous;

  /// The state after the change.
  final SallaPushSubscriptionState current;

  @override
  String toString() =>
      'SallaPushSubscriptionChangedState(previous: $previous, '
      'current: $current)';
}

/// The login state of the user at one moment.
final class SallaPushUserState {
  const SallaPushUserState._({
    required this.externalId,
    required this.isLoggedIn,
  });

  /// The external id of the last `SallaPush.login`; null for a guest.
  final String? externalId;

  /// Whether a `SallaPush.login` was made and no `SallaPush.logout` since.
  final bool isLoggedIn;

  @override
  String toString() =>
      'SallaPushUserState(externalId: $externalId, isLoggedIn: $isLoggedIn)';
}

/// A change of the user's login state.
final class SallaPushUserChangedState {
  const SallaPushUserChangedState._({
    required this.previous,
    required this.current,
  });

  /// The state before the change.
  final SallaPushUserState previous;

  /// The state after the change.
  final SallaPushUserState current;

  @override
  String toString() =>
      'SallaPushUserChangedState(previous: $previous, current: $current)';
}

/// One SallaPush log entry, as `SallaPush.debug.setLogHandler` delivers it.
///
/// Every field is redacted by SallaPush: no secret or identity token appears
/// in an entry. What SallaPush iOS writes in the info entries `status.launch`
/// and `status.changed` is described in its logging guide: don't forward info
/// entries to third parties.
final class SallaPushLogEntry {
  const SallaPushLogEntry._({
    required this.level,
    required this.category,
    required this.code,
    required this.message,
    required this.metadata,
    required this.timestamp,
  });

  /// The level of the entry.
  final SallaPushLogLevel level;

  /// The area that logged it: lifecycle, registration, identity,
  /// notifications, events, tags, network, storage or consent.
  final String category;

  /// A stable identifier, such as `register.ok`: codes never change between
  /// releases.
  final String code;

  /// One line that says what happened and, for a problem, what to do.
  final String message;

  /// Details, read-only. The keys are limited to http_status, error_code,
  /// request_id, device_id, app_id, attempt, delay_s, route, reason and count.
  final Map<String, String> metadata;

  /// When SallaPush logged it, in UTC.
  final DateTime timestamp;

  @override
  String toString() =>
      'SallaPushLogEntry(level: ${level.name}, category: $category, '
      'code: $code, message: $message, metadata: $metadata, '
      'timestamp: ${timestamp.toIso8601String()})';
}

// SallaPush creates these values, apps don't: the constructors are private, and
// these tear-offs, which the library doesn't export, give them to the mapping.

/// Creates a [SallaPushNotification].
const newNotification = SallaPushNotification._;

/// Creates a [SallaPushClickResult].
const newClickResult = SallaPushClickResult._;

/// Creates a [SallaPushClickEvent].
const newClickEvent = SallaPushClickEvent._;

/// Creates a [SallaPushWillDisplayEvent].
const newWillDisplayEvent = SallaPushWillDisplayEvent._;

/// Creates a [SallaPushSubscriptionState].
const newSubscriptionState = SallaPushSubscriptionState._;

/// Creates a [SallaPushSubscriptionChangedState].
const newSubscriptionChangedState = SallaPushSubscriptionChangedState._;

/// Creates a [SallaPushUserState].
const newUserState = SallaPushUserState._;

/// Creates a [SallaPushUserChangedState].
const newUserChangedState = SallaPushUserChangedState._;

/// Creates a [SallaPushLogEntry].
const newLogEntry = SallaPushLogEntry._;
