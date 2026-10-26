import 'models.dart';

/// Options for `SallaPush.initialize`. Null keeps the native default for every
/// field.
///
/// Apps that set the static app id (`SallaPushAppId` /
/// `com.salla.push.APP_ID`) set these options with the static keys instead:
/// SallaPush has already started natively, and an `initialize` with the same
/// app id ignores them.
final class SallaPushConfig {
  /// Creates options for `SallaPush.initialize`.
  const SallaPushConfig({
    this.logLevel,
    this.appVersion,
    this.clearTagsOnLogout,
    this.requiresUserConsent,
    this.openLaunchUrls,
    this.autoClearBadge,
    this.autoUpdateBadge,
    this.ios = const SallaPushIosConfig(),
  });

  /// The console log level. Null uses the `SallaPushLogLevel` Info.plist key or
  /// the `com.salla.push.LOG_LEVEL` meta-data, else [SallaPushLogLevel.warn].
  /// `SallaPush.debug.setLogLevel` overrides it.
  final SallaPushLogLevel? logLevel;

  /// The app version reported to SallaPush. Null reports
  /// `CFBundleShortVersionString` on iOS and `versionName` on Android.
  final String? appVersion;

  /// Whether a logout, and a login of another customer, first clear this
  /// device's tags, also on the server. Default true.
  final bool? clearTagsOnLogout;

  /// Whether SallaPush waits for `SallaPush.setConsentGiven(true)` before it
  /// sends anything or stores anything but the consent answer. Default false.
  final bool? requiresUserConsent;

  /// Whether a tap opens an https launch URL itself instead of only handing
  /// it to the click listeners. Default false.
  final bool? openLaunchUrls;

  /// Whether SallaPush clears the app icon's badge when the app opens. Null
  /// keeps each platform's default: on for iOS, off for Android. A value set
  /// here applies to both platforms.
  ///
  /// On iOS, the badge and SallaPush's count go to 0 every time the app
  /// becomes active, and a SallaPush notification shown while the app is in
  /// the foreground doesn't change the badge. On iOS 15, a badge set to 0
  /// also removes the app's delivered notifications, other SDKs' included.
  /// Off, the iOS badge counts the SallaPush notifications still in
  /// Notification Center: one shown in the foreground adds 1, opening one
  /// lowers it at once, and one cleared in Notification Center lowers it the
  /// next time the app becomes active or goes to the background.
  /// On Android, launchers count an app's notifications in the shade, so
  /// SallaPush removes its notifications that show on the badge when the app
  /// comes to the foreground, but not when the phone was unlocked with the
  /// app already on screen; off, the badge follows SallaPush's notifications
  /// in the shade.
  final bool? autoClearBadge;

  /// Whether SallaPush counts its notifications on the app icon's badge.
  /// Default true.
  ///
  /// On iOS, the Notification Service Extension adds 1 for each SallaPush
  /// notification, which needs the same App Group in the app and the
  /// extension; false: SallaPush never sets a number, except the 0 of
  /// [autoClearBadge], and a push's own badge applies. On Android, false
  /// creates SallaPush's notification channels without badges. Android fixes
  /// a channel's badges when the channel is created, so this applies to the
  /// channels SallaPush creates from then on.
  final bool? autoUpdateBadge;

  /// The options that apply on iOS only.
  final SallaPushIosConfig ios;
}

/// iOS options of [SallaPushConfig]. Ignored on Android.
final class SallaPushIosConfig {
  /// Creates iOS options.
  const SallaPushIosConfig({
    this.appGroupIdentifier,
    this.apnsEnvironment,
    this.registerForRemoteNotificationsOnInit,
  });

  /// The App Group shared with the Notification Service Extension, which
  /// reports the `received` events and counts the badge through it. Null
  /// uses the `SallaPushAppGroup` Info.plist key; a blank value means no App
  /// Group.
  final String? appGroupIdentifier;

  /// The APNs environment of this build. Default
  /// [SallaPushApnsEnvironment.automatic].
  final SallaPushApnsEnvironment? apnsEnvironment;

  /// Whether SallaPush registers for remote notifications when it starts,
  /// unless consent is withheld. Default true. Without it, call
  /// `SallaPush.notifications.registerForRemoteNotifications()`, or no push
  /// token arrives.
  final bool? registerForRemoteNotificationsOnInit;
}
