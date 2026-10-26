import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartPackageName: 'mobile_push',
    kotlinOut:
        'android/src/main/kotlin/sa/salla/sallapush_flutter/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'sa.salla.sallapush_flutter'),
    swiftOut: 'ios/mobile_push/Sources/mobile_push/Messages.g.swift',
    copyrightHeader: 'pigeons/copyright_header.txt',
  ),
)
enum LogLevelMessage { off, error, warn, info, debug, verbose }

enum PayloadSourceMessage { native, compat }

enum LoginFailureMessage { tokenRejected, invalidRequest }

enum ApnsEnvironmentMessage { automatic, sandbox, production }

enum IosPermissionStatusMessage {
  notDetermined,
  denied,
  authorized,
  provisional,
  ephemeral,
}

class ConfigMessage {
  ConfigMessage({
    this.logLevel,
    this.appVersion,
    this.clearTagsOnLogout,
    this.requiresUserConsent,
    this.openLaunchUrls,
    this.autoClearBadge,
    this.autoUpdateBadge,
    this.iosAppGroupIdentifier,
    this.iosApnsEnvironment,
    this.iosRegisterForRemoteNotificationsOnInit,
  });

  LogLevelMessage? logLevel;
  String? appVersion;
  bool? clearTagsOnLogout;
  bool? requiresUserConsent;
  bool? openLaunchUrls;
  bool? autoClearBadge;
  bool? autoUpdateBadge;
  String? iosAppGroupIdentifier;
  ApnsEnvironmentMessage? iosApnsEnvironment;
  bool? iosRegisterForRemoteNotificationsOnInit;
}

class NotificationMessage {
  NotificationMessage({
    required this.additionalData,
    required this.rawPayload,
    required this.source,
    required this.stringValues,
    required this.intValues,
    required this.boolValues,
    required this.numberValues,
    this.notificationId,
    this.title,
    this.subtitle,
    this.body,
    this.imageUrl,
    this.launchUrl,
    this.sound,
    this.badge,
    this.threadId,
    this.androidNotificationId,
    this.collapseId,
    this.channelId,
  });

  String? notificationId;
  String? title;
  String? subtitle;
  String? body;
  String? imageUrl;
  String? launchUrl;
  Map<String, Object?> additionalData;
  Map<String, Object?> rawPayload;
  PayloadSourceMessage source;
  // The non-null results of native's typed accessors for each top-level additionalData key.
  Map<String, String> stringValues;
  Map<String, int> intValues;
  Map<String, bool> boolValues;
  // iOS only (int or double); empty on Android.
  Map<String, Object> numberValues;
  String? sound;
  int? badge;
  String? threadId;
  int? androidNotificationId;
  String? collapseId;
  String? channelId;
}

class ClickEventMessage {
  ClickEventMessage({required this.notification, this.actionId, this.url});

  NotificationMessage notification;
  String? actionId;
  String? url;
}

class WillDisplayEventMessage {
  WillDisplayEventMessage({required this.handle, required this.notification});

  String handle;
  NotificationMessage notification;
}

class PermissionChangeMessage {
  PermissionChangeMessage({required this.permission});

  bool permission;
}

class SubscriptionStateMessage {
  SubscriptionStateMessage({required this.optedIn, this.id, this.token});

  String? id;
  String? token;
  bool optedIn;
}

class SubscriptionChangedMessage {
  SubscriptionChangedMessage({
    required this.listenerId,
    required this.previous,
    required this.current,
  });

  /// The Dart listener whose native observer produced this event.
  int listenerId;
  SubscriptionStateMessage previous;
  SubscriptionStateMessage current;
}

class UserStateMessage {
  UserStateMessage({required this.isLoggedIn, this.externalId});

  String? externalId;
  bool isLoggedIn;
}

class UserChangedMessage {
  UserChangedMessage({required this.previous, required this.current});

  UserStateMessage previous;
  UserStateMessage current;
}

class LoginFailureEventMessage {
  LoginFailureEventMessage({required this.failure});

  LoginFailureMessage failure;
}

class LogEntryMessage {
  LogEntryMessage({
    required this.level,
    required this.category,
    required this.code,
    required this.message,
    required this.metadata,
    required this.timestampMillis,
  });

  LogLevelMessage level;
  String category;
  String code;
  String message;
  Map<String, String> metadata;
  int timestampMillis;
}

@HostApi()
abstract class SallaPushHostApi {
  void initialize(String appId, ConfigMessage config);
  bool isInitialized();
  String? appId();
  String sdkVersion();
  void setConsentRequired(bool required);
  void setConsentGiven(bool given);
  void login(String externalId, String identityToken);
  void logout();

  String? externalId();
  bool isLoggedIn();
  void addTag(String key, String value);
  void addTags(Map<String, String> tags);
  void removeTag(String key);
  void removeTags(List<String> keys);
  Map<String, String> getTags();
  void setLanguage(String? language);

  String? pushSubscriptionId();
  String? pushSubscriptionToken();
  bool pushSubscriptionOptedIn();
  void optIn();
  void optOut();
  void addPushSubscriptionListener(int listenerId);
  void removePushSubscriptionListener(int listenerId);

  bool permission();
  bool canRequestPermission();
  IosPermissionStatusMessage? permissionStatus();
  @asyncCallback
  bool requestPermission(bool fallbackToSettings);
  @asyncCallback
  bool registerForProvisionalAuthorization();
  void refreshPermission();
  void registerForRemoteNotifications();
  void forwardApnsToken(String apnsToken);
  void clearAll();
  void removeNotification(int androidNotificationId);
  bool isSallaPushNotification(Map<String, Object?> payload);
  bool trackOpened(Map<String, Object?>? additionalData);
  void displayNotification(String handle);

  void setDisplayCompatPayloads(bool display);

  LogLevelMessage logLevel();
  void setLogLevel(LogLevelMessage level);
  void setLogHandlerLevel(LogLevelMessage level);
}

@EventChannelApi()
abstract class SallaPushEventChannelApi {
  ClickEventMessage clickEvents();
  WillDisplayEventMessage willDisplayEvents();
  PermissionChangeMessage permissionChanges();
  UserChangedMessage userChanges();
  LoginFailureEventMessage loginFailures();
  SubscriptionChangedMessage pushSubscriptionChanges();
  LogEntryMessage logEntries();
}
