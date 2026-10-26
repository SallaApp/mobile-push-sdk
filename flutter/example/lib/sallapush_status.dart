import 'package:flutter/foundation.dart';
import 'package:mobile_push/mobile_push.dart';

/// What SallaPush reports at one moment, read with its getters.
@immutable
final class SallaPushStatus {
  /// Creates a status.
  const SallaPushStatus({
    required this.isInitialized,
    required this.appId,
    required this.sdkVersion,
    required this.deviceId,
    required this.optedIn,
    required this.tokenEnd,
    required this.permission,
    required this.permissionStatus,
    required this.externalId,
    required this.isLoggedIn,
    required this.tags,
    required this.logLevel,
  });

  /// Reads every getter; the iOS-only permission status on iOS only.
  static Future<SallaPushStatus> read() async {
    final String? token = await SallaPush.user.pushSubscription.token;
    return SallaPushStatus(
      isInitialized: await SallaPush.isInitialized,
      appId: await SallaPush.appId,
      sdkVersion: await SallaPush.sdkVersion,
      deviceId: await SallaPush.user.pushSubscription.id,
      optedIn: await SallaPush.user.pushSubscription.optedIn,
      tokenEnd: token == null ? null : _lastSix(token),
      permission: await SallaPush.notifications.permission,
      permissionStatus: defaultTargetPlatform == TargetPlatform.iOS
          ? await SallaPush.notifications.permissionStatus
          : null,
      externalId: await SallaPush.user.externalId,
      isLoggedIn: await SallaPush.user.isLoggedIn,
      tags: await SallaPush.user.getTags(),
      logLevel: await SallaPush.debug.logLevel,
    );
  }

  static String _lastSix(String text) =>
      text.length <= 6 ? text : text.substring(text.length - 6);

  /// Whether SallaPush runs.
  final bool isInitialized;

  /// The app id SallaPush runs with.
  final String? appId;

  /// The native SallaPush SDK's version.
  final String sdkVersion;

  /// The push subscription's SallaPush device id.
  final String? deviceId;

  /// Whether this device receives SallaPush notifications.
  final bool optedIn;

  /// The push token's last 6 characters: the token is private.
  final String? tokenEnd;

  /// Whether the app may show notifications.
  final bool permission;

  /// iOS only: the notification authorization status.
  final SallaPushIosPermissionStatus? permissionStatus;

  /// The logged-in customer's id.
  final String? externalId;

  /// Whether a customer is logged in.
  final bool isLoggedIn;

  /// This device's tags.
  final Map<String, String> tags;

  /// The console log level.
  final SallaPushLogLevel logLevel;
}
