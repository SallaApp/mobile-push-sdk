import 'package:flutter/foundation.dart';

import 'config.dart';
import 'messages.g.dart';
import 'models.dart';

/// The bridge form of a [SallaPushConfig].
extension ConfigMapping on SallaPushConfig {
  /// The bridge form. Null fields stay null, so native keeps its defaults.
  ConfigMessage get message => ConfigMessage(
    logLevel: logLevel?.message,
    appVersion: appVersion,
    clearTagsOnLogout: clearTagsOnLogout,
    requiresUserConsent: requiresUserConsent,
    openLaunchUrls: openLaunchUrls,
    autoClearBadge: autoClearBadge,
    autoUpdateBadge: autoUpdateBadge,
    iosAppGroupIdentifier: ios.appGroupIdentifier,
    iosApnsEnvironment: ios.apnsEnvironment?.message,
    iosRegisterForRemoteNotificationsOnInit:
        ios.registerForRemoteNotificationsOnInit,
  );
}

/// The bridge form of a [SallaPushLogLevel].
extension LogLevelMapping on SallaPushLogLevel {
  /// The bridge form, by case.
  LogLevelMessage get message => switch (this) {
    SallaPushLogLevel.off => LogLevelMessage.off,
    SallaPushLogLevel.error => LogLevelMessage.error,
    SallaPushLogLevel.warn => LogLevelMessage.warn,
    SallaPushLogLevel.info => LogLevelMessage.info,
    SallaPushLogLevel.debug => LogLevelMessage.debug,
    SallaPushLogLevel.verbose => LogLevelMessage.verbose,
  };
}

/// The public form of a [LogLevelMessage].
extension LogLevelMessageMapping on LogLevelMessage {
  /// The public form, by case.
  SallaPushLogLevel get level => switch (this) {
    LogLevelMessage.off => SallaPushLogLevel.off,
    LogLevelMessage.error => SallaPushLogLevel.error,
    LogLevelMessage.warn => SallaPushLogLevel.warn,
    LogLevelMessage.info => SallaPushLogLevel.info,
    LogLevelMessage.debug => SallaPushLogLevel.debug,
    LogLevelMessage.verbose => SallaPushLogLevel.verbose,
  };
}

/// The bridge form of a [SallaPushApnsEnvironment].
extension ApnsEnvironmentMapping on SallaPushApnsEnvironment {
  /// The bridge form, by case.
  ApnsEnvironmentMessage get message => switch (this) {
    SallaPushApnsEnvironment.automatic => ApnsEnvironmentMessage.automatic,
    SallaPushApnsEnvironment.sandbox => ApnsEnvironmentMessage.sandbox,
    SallaPushApnsEnvironment.production => ApnsEnvironmentMessage.production,
  };
}

/// The public form of an [IosPermissionStatusMessage].
extension IosPermissionStatusMapping on IosPermissionStatusMessage {
  /// The public form, by case.
  SallaPushIosPermissionStatus get status => switch (this) {
    IosPermissionStatusMessage.notDetermined =>
      SallaPushIosPermissionStatus.notDetermined,
    IosPermissionStatusMessage.denied => SallaPushIosPermissionStatus.denied,
    IosPermissionStatusMessage.authorized =>
      SallaPushIosPermissionStatus.authorized,
    IosPermissionStatusMessage.provisional =>
      SallaPushIosPermissionStatus.provisional,
    IosPermissionStatusMessage.ephemeral =>
      SallaPushIosPermissionStatus.ephemeral,
  };
}

/// The public form of a [PayloadSourceMessage].
extension PayloadSourceMessageMapping on PayloadSourceMessage {
  /// The public form, by case.
  SallaPushPayloadSource get source => switch (this) {
    PayloadSourceMessage.native => SallaPushPayloadSource.native,
    PayloadSourceMessage.compat => SallaPushPayloadSource.compat,
  };
}

/// The public form of a [LoginFailureMessage].
extension LoginFailureMessageMapping on LoginFailureMessage {
  /// The public form, by case.
  SallaPushLoginFailure get failure => switch (this) {
    LoginFailureMessage.tokenRejected => SallaPushLoginFailure.tokenRejected,
    LoginFailureMessage.invalidRequest => SallaPushLoginFailure.invalidRequest,
  };
}

/// The public form of a [NotificationMessage].
extension NotificationMessageMapping on NotificationMessage {
  /// The public form. Its additionalData and rawPayload are read-only JSON
  /// values whose nested maps are keyed by text, as `jsonDecode` gives them.
  SallaPushNotification get notification => _notification(this, null);
}

/// The public form of a [WillDisplayEventMessage].
extension WillDisplayEventMessageMapping on WillDisplayEventMessage {
  /// The public form, whose notification's `display()` asks [host] to show
  /// the notification held under this event's handle once a listener
  /// prevented it, as SallaPush's own `display()` does.
  SallaPushWillDisplayEvent event(SallaPushHostApi host) {
    late final SallaPushWillDisplayEvent event;
    Future<void> display() {
      if (event.isPrevented) return host.displayNotification(handle);
      debugPrint(
        '[SallaPush] display() did nothing: the notification was not '
        'prevented. Call event.preventDefault() first.',
      );
      return Future<void>.value();
    }

    return event = newWillDisplayEvent(
      notification: _notification(notification, display),
    );
  }
}

SallaPushNotification _notification(
  NotificationMessage message,
  Future<void> Function()? display,
) => newNotification(
  notificationId: message.notificationId,
  title: message.title,
  subtitle: message.subtitle,
  body: message.body,
  imageUrl: message.imageUrl,
  launchUrl: message.launchUrl,
  additionalData: _readOnlyJson(message.additionalData),
  rawPayload: _readOnlyJson(message.rawPayload),
  source: message.source.source,
  sound: message.sound,
  badge: message.badge,
  threadId: message.threadId,
  androidNotificationId: message.androidNotificationId,
  collapseId: message.collapseId,
  channelId: message.channelId,
  stringValues: Map<String, String>.of(message.stringValues),
  intValues: Map<String, int>.of(message.intValues),
  boolValues: Map<String, bool>.of(message.boolValues),
  numberValues: <String, num>{
    for (final MapEntry<String, Object>(:String key, :Object value)
        in message.numberValues.entries)
      if (value is num) key: value,
  },
  display: display,
);

/// The public form of a [ClickEventMessage].
extension ClickEventMessageMapping on ClickEventMessage {
  /// The public form.
  SallaPushClickEvent get event => newClickEvent(
    notification: notification.notification,
    result: newClickResult(actionId: actionId, url: url),
  );
}

/// The public form of a [SubscriptionStateMessage].
extension SubscriptionStateMessageMapping on SubscriptionStateMessage {
  /// The public form.
  SallaPushSubscriptionState get state =>
      newSubscriptionState(id: id, token: token, optedIn: optedIn);
}

/// The public form of a [SubscriptionChangedMessage].
extension SubscriptionChangedMessageMapping on SubscriptionChangedMessage {
  /// The public form.
  SallaPushSubscriptionChangedState get state => newSubscriptionChangedState(
    previous: previous.state,
    current: current.state,
  );
}

/// The public form of a [UserStateMessage].
extension UserStateMessageMapping on UserStateMessage {
  /// The public form.
  SallaPushUserState get state =>
      newUserState(externalId: externalId, isLoggedIn: isLoggedIn);
}

/// The public form of a [LogEntryMessage].
extension LogEntryMessageMapping on LogEntryMessage {
  /// The public form, timestamped in UTC.
  SallaPushLogEntry get entry => newLogEntry(
    level: level.level,
    category: category,
    code: code,
    message: message,
    metadata: Map<String, String>.unmodifiable(metadata),
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      timestampMillis,
      isUtc: true,
    ),
  );
}

/// The public form of a [UserChangedMessage].
extension UserChangedMessageMapping on UserChangedMessage {
  /// The public form.
  SallaPushUserChangedState get state =>
      newUserChangedState(previous: previous.state, current: current.state);
}

Map<String, Object?> _readOnlyJson(Map<Object?, Object?> map) =>
    Map<String, Object?>.unmodifiable(<String, Object?>{
      for (final MapEntry<Object?, Object?>(:Object? key, :Object? value)
          in map.entries)
        '$key': _readOnlyJsonValue(value),
    });

Object? _readOnlyJsonValue(Object? value) => switch (value) {
  final Map<Object?, Object?> map => _readOnlyJson(map),
  final List<Object?> list => List<Object?>.unmodifiable(
    list.map(_readOnlyJsonValue),
  ),
  _ => value,
};
