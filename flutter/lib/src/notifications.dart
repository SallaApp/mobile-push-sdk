import 'dart:async';

import 'channels.dart';
import 'mapping.dart';
import 'messages.g.dart';
import 'models.dart';

/// Notification permission, push token forwarding and notification helpers.
final class SallaPushNotifications {
  const SallaPushNotifications._();

  /// Whether this app may show notifications: on iOS when authorized,
  /// provisional or ephemeral; on Android when the app's notifications are on
  /// and, on Android 13 and later, the permission is granted. On iOS, false
  /// until SallaPush has first read it, right after it starts.
  Future<bool> get permission => _host.permission();

  /// Whether the system permission prompt can still be shown: on iOS while the
  /// status isn't determined; on Android 13 and later while the permission is
  /// neither granted nor permanently denied. False while the status is unknown.
  Future<bool> canRequestPermission() => _host.canRequestPermission();

  /// iOS only: the raw authorization status. Null on Android.
  Future<SallaPushIosPermissionStatus?> get permissionStatus async =>
      (await _host.permissionStatus())?.status;

  /// Shows the system permission prompt and completes with whether
  /// notifications are allowed. When the permission can no longer be
  /// requested, [fallbackToSettings] opens the app's notification settings
  /// instead. On Android it prompts only on Android 13 and later while the app
  /// is in the foreground, and otherwise completes with the current state.
  Future<bool> requestPermission({bool fallbackToSettings = false}) =>
      _host.requestPermission(fallbackToSettings);

  /// iOS only: allows quiet notifications without asking the user, and
  /// completes with whether they are allowed. False on Android.
  Future<bool> registerForProvisionalAuthorization() =>
      _host.registerForProvisionalAuthorization();

  /// Reads the permission again, for apps that ask for it in their own way.
  Future<void> refreshPermission() => _host.refreshPermission();

  /// iOS only: registers for remote notifications, which SallaPush does itself
  /// unless `SallaPushIosConfig.registerForRemoteNotificationsOnInit` is false.
  /// Does nothing on Android.
  Future<void> registerForRemoteNotifications() =>
      _host.registerForRemoteNotifications();

  /// iOS only: forwards the APNs token that another SDK or plugin holds, as
  /// hexadecimal text, for apps whose other SDKs swizzle the app delegate. Does
  /// nothing on Android.
  Future<void> forwardApnsToken(String apnsToken) =>
      _host.forwardApnsToken(apnsToken);

  /// Removes delivered SallaPush notifications only. On iOS it also sets
  /// SallaPush's count and the app icon's badge to 0 while
  /// `SallaPushConfig.autoUpdateBadge` is on; on Android the badge drops with
  /// the notifications.
  Future<void> clearAll() => _host.clearAll();

  /// Android only: removes the SallaPush notification with this id, the
  /// `androidNotificationId` of a SallaPush notification. Does nothing on iOS.
  Future<void> removeNotification(int androidNotificationId) =>
      _host.removeNotification(androidNotificationId);

  /// Whether [payload] was sent by SallaPush: FCM data, or the raw payload of a
  /// notification another SDK received. On Android, values that aren't text
  /// are read the way FCM data carries them: maps and lists as JSON text.
  Future<bool> isSallaPushNotification(Map<String, Object?> payload) =>
      _host.isSallaPushNotification(payload);

  /// Android only: records `opened` for a notification another push SDK
  /// showed. Pass that SDK's additional data; completes with whether it was
  /// SallaPush's. False on iOS.
  Future<bool> trackOpened(Map<String, Object?>? additionalData) =>
      _host.trackOpened(additionalData);

  /// Every tap. Taps made before the first listener (the tap that launched the
  /// app) arrive once, a moment after the first listener subscribes, at every
  /// listener subscribed by then: add the click listener at app start, before
  /// `runApp`. SallaPush keeps such taps for 5 minutes, at most 10. After the
  /// last listener is cancelled, it keeps new taps again.
  Stream<SallaPushClickEvent> get onClick {
    final SallaPushChannels channels = SallaPushChannels.current;
    return _onClick[channels] ??= channels.clickEvents.map(
      (ClickEventMessage message) => message.event,
    );
  }

  /// While a listener exists, every foreground SallaPush notification is held
  /// and offered here. Call event.preventDefault() synchronously to keep it
  /// hidden; otherwise it is shown when the listeners return. On iOS the
  /// notification is then shown as SallaPush's local copy, which has no image,
  /// no action buttons, no interruption level or relevance score, and is not
  /// replaced by a later push with the same collapse id. Without a listener,
  /// the original is shown.
  ///
  /// The listeners run synchronously, in the order they were added, and a
  /// listener that throws doesn't stop the others or the decision. Listen only
  /// where a notification needs a decision, such as a chat screen, and cancel
  /// when leaving it, so that iOS shows the original notifications elsewhere.
  ///
  /// Use `listen()` on this stream, not `await for`, and don't pause the
  /// subscription or put an asynchronous transformer such as `asyncMap` before
  /// your listener: an event that reaches it late, while an `await for` body
  /// awaits or while the subscription is paused, was decided already, so its
  /// preventDefault() has no effect.
  ///
  /// Listen in one Flutter engine only: with listeners in several engines, a
  /// notification is shown unless every engine prevents it. A notification on
  /// its way to Dart when the last listener is cancelled, or when the engine
  /// goes away, stays hidden.
  Stream<SallaPushWillDisplayEvent> get onWillDisplay {
    final SallaPushChannels channels = SallaPushChannels.current;
    return _onWillDisplay[channels] ??= _willDisplayEvents(channels);
  }

  /// Changes between allowed and not allowed. No replay.
  Stream<bool> get onPermissionChange {
    final SallaPushChannels channels = SallaPushChannels.current;
    return _onPermissionChange[channels] ??= channels.permissionChanges.map(
      (PermissionChangeMessage message) => message.permission,
    );
  }

  static SallaPushHostApi get _host => SallaPushChannels.current.host;

  static final Expando<Stream<SallaPushClickEvent>> _onClick =
      Expando<Stream<SallaPushClickEvent>>();
  static final Expando<Stream<SallaPushWillDisplayEvent>> _onWillDisplay =
      Expando<Stream<SallaPushWillDisplayEvent>>();
  static final Expando<Stream<bool>> _onPermissionChange =
      Expando<Stream<bool>>();
}

/// The one [SallaPushNotifications], `SallaPush.notifications`.
const SallaPushNotifications notificationsNamespace =
    SallaPushNotifications._();

/// The will-display events of one isolate. Native holds each notification
/// while a listener exists here; the listeners run synchronously, and once
/// they returned, the notification is shown unless one of them prevented it.
Stream<SallaPushWillDisplayEvent> _willDisplayEvents(
  SallaPushChannels channels,
) {
  StreamSubscription<WillDisplayEventMessage>? platform;
  late final StreamController<SallaPushWillDisplayEvent> listeners;

  void decide(WillDisplayEventMessage message) {
    final SallaPushWillDisplayEvent event = message.event(channels.host);
    listeners.add(event);
    if (!event.isPrevented) {
      unawaited(
        reportingFailure(
          channels.host.displayNotification(message.handle),
          'while showing a foreground notification',
        ),
      );
    }
  }

  listeners = StreamController<SallaPushWillDisplayEvent>.broadcast(
    sync: true,
    onListen: () => platform = channels.willDisplayEvents.listen(
      decide,
      onError: listeners.addError,
    ),
    onCancel: () {
      unawaited(platform?.cancel());
      platform = null;
    },
  );
  return listeners.stream;
}
