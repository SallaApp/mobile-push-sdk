# SallaPush Flutter SDK: API reference

The static configuration, the Dart API, the events, the errors and the log codes. The [README](../README.md)
shows how to set up and use the SDK.

Other docs: [README](../README.md) · [Setup guide](SETUP.md) · [Troubleshooting](TROUBLESHOOTING.md)

## Contents

1. [Static configuration](#static-configuration)
2. [SallaPush](#sallapush)
3. [SallaPushConfig](#sallapushconfig)
4. [SallaPush.user](#sallapushuser)
5. [SallaPush.user.pushSubscription](#sallapushuserpushsubscription)
6. [SallaPush.notifications](#sallapushnotifications)
7. [SallaPush.debug](#sallapushdebug)
8. [SallaPushNotification](#sallapushnotification)
9. [Events and states](#events-and-states)
10. [Platform-only members](#platform-only-members)
11. [Errors](#errors)
12. [Log codes](#log-codes)

## Static configuration

SallaPush starts at launch, before Dart runs, from the app id key. The keys marked *with the app id* apply only to
that start: an app that calls `initialize` sets the same options in [`SallaPushConfig`](#sallapushconfig). The others
apply however SallaPush starts, and a value set in `SallaPushConfig` wins over them.

### iOS: Info.plist

| Key | Type | Option | Applies | Default |
|---|---|---|---|---|
| `SallaPushAppId` | String | the app id: SallaPush starts at launch | – | none: no start at launch |
| `SallaPushRequiresUserConsent` | Boolean | `requiresUserConsent` | with the app id | `NO` |
| `SallaPushOpenLaunchURLs` | Boolean | `openLaunchUrls` | with the app id | `NO` |
| `SallaPushClearTagsOnLogout` | Boolean | `clearTagsOnLogout` | with the app id | `YES` |
| `SallaPushAppVersion` | String | `appVersion` | with the app id | `CFBundleShortVersionString` |
| `SallaPushAutoClearBadge` | Boolean | `autoClearBadge` | with the app id | `YES` |
| `SallaPushAutoUpdateBadge` | Boolean | `autoUpdateBadge` | with the app id | `YES` |
| `SallaPushRegisterForRemoteNotificationsOnInit` | Boolean | `ios.registerForRemoteNotificationsOnInit` | with the app id | `YES` |
| `SallaPushAPNsEnvironment` | String: `automatic`, `sandbox` or `production` | `ios.apnsEnvironment` | with the app id | `automatic` |
| `SallaPushLogLevel` | String: `off`, `error`, `warn`, `info`, `debug` or `verbose` | the console's level | always | `warn` |
| `SallaPushAppGroup` | String, in the app and the extension | `ios.appGroupIdentifier` | always | none |
| `SallaPushLogFullIdentifiers` | Boolean, in debug builds only | the full push token and customer id in the status lines `status.launch` and `status.changed` | always | `NO` |

### Android: manifest meta-data

Inside `<application>` in the app's `AndroidManifest.xml`:

| Name | Value | Option | Applies | Default |
|---|---|---|---|---|
| `com.salla.push.APP_ID` | the app id | SallaPush starts with the app's process | – | none: no start |
| `com.salla.push.REQUIRES_USER_CONSENT` | a boolean | `requiresUserConsent` | with the app id | `false` |
| `com.salla.push.OPEN_LAUNCH_URLS` | a boolean | `openLaunchUrls` | with the app id | `false` |
| `com.salla.push.CLEAR_TAGS_ON_LOGOUT` | a boolean | `clearTagsOnLogout` | with the app id | `true` |
| `com.salla.push.APP_VERSION` | text | `appVersion` | with the app id | the app's `versionName` |
| `com.salla.push.AUTO_CLEAR_BADGE` | a boolean | `autoClearBadge` | with the app id | `false` |
| `com.salla.push.AUTO_UPDATE_BADGE` | a boolean | `autoUpdateBadge` | with the app id | `true` |
| `com.salla.push.LOG_LEVEL` | `off`, `error`, `warn`, `info`, `debug` or `verbose` | the Logcat level | always | `warn` |
| `com.salla.push.default_notification_icon` | `android:resource`: a white-on-transparent drawable | the small icon | always | Firebase's default icon, else SallaPush's bell, with `display.default_icon` |
| `com.salla.push.default_channel_id`, `com.salla.push.default_channel_name` | text, or a string resource for the name | the default notification channel | always | Firebase's default channel (`com.google.firebase.messaging.default_notification_channel_id`) when it exists, else SallaPush's own channel |

### Values

- **For each build:** set the key to a build setting, such as `$(SALLAPUSH_APP_ID)`, defined in each configuration's
  xcconfig; on Android, to a placeholder, such as `${sallaPushAppId}`, defined in `manifestPlaceholders` for each
  flavor or build type. In a Groovy build file, add to the map with `+=`: `=` replaces Flutter's own placeholders.
- **Text** is trimmed, and empty text counts as absent: an undefined build setting expands to `""`.
- **Booleans:** iOS takes `<true/>` and `<false/>`, or the text `YES`, `NO`, `true`, `false`, `1` or `0`, in any case;
  Android takes `true`, `false`, `yes`, `no`, `1` or `0`, in any case. Anything else is ignored, with a `[SallaPush]`
  error.
- **Android numbers:** Android reads a decimal or long number in `android:value`, such as the version `2.1`, as a
  floating-point number, which is ignored, with a `[SallaPush]` error: put it in a string resource, and reference it
  with `android:resource`.

## SallaPush

Each call goes to the native SDK, in call order. Its future completes normally for every SallaPush-level problem, such
as an invalid argument: SallaPush logs it and ignores it, or keeps the call until it can run it ([Errors](#errors)).

| Member | Notes |
|---|---|
| `static Future<void> initialize(String appId, {SallaPushConfig config = const SallaPushConfig()})` | For app ids known only at run time ([Setup guide](SETUP.md#initializing-from-dart)). The app id SallaPush already runs with changes nothing, its options included; another one switches SallaPush to it. An invalid first app id, one that isn't 1 to 64 letters, digits, `_` and `-`, turns SallaPush off until the next launch. |
| `static Future<bool> get isInitialized` | True once a valid app id started SallaPush. |
| `static Future<String?> get appId` | The app id SallaPush runs with. |
| `static Future<String> get sdkVersion` | The version of the native SDK on this platform. |
| `static Future<void> setConsentRequired(bool required)` | For apps that call `initialize`: before it, at every launch, since it isn't saved. Apps that start at launch use the static consent key. |
| `static Future<void> setConsentGiven(bool given)` | Saved. While consent is required, SallaPush sends nothing until `true`; `false` withdraws consent that was given: the device is opted out, its tags are deleted and the customer is unlinked. |
| `static Future<void> login({required String externalId, required String identityToken})` | Links this device to the customer: `externalId` is the customer's Salla id, and `identityToken` the customer's token that your app received at sign-in, without a `Bearer ` prefix. Call it at sign-in, at each app launch while signed in, and whenever your app refreshes the token: SallaPush keeps it in memory only. Call `logout()` before another customer's `login`. |
| `static Future<void> logout()` | Unlinks the customer: the device stays registered as a guest. Works offline and without a token. Call it after the customer signs out, and at each app launch while nobody is signed in: on iOS, after a reinstall, it unlinks the customer of the earlier install. It sends nothing when the device isn't linked. |
| `static final SallaPushUser user`, `SallaPushNotifications notifications`, `SallaPushDebug debug` | The namespaces below. |

## SallaPushConfig

The options of `initialize`. A `null` field keeps the native default.

| Field | Default | Meaning |
|---|---|---|
| `logLevel` | the static key, else `warn` | The console's level. |
| `appVersion` | `CFBundleShortVersionString`; `versionName` | The app version reported for this device. |
| `clearTagsOnLogout` | `true` | A logout, and a login of another customer, first delete this device's tags. |
| `requiresUserConsent` | `false` | SallaPush waits for `setConsentGiven(true)`. |
| `openLaunchUrls` | `false` | A tap opens an https launch URL natively; don't open `event.result.url` again then. |
| `autoClearBadge` | iOS `true`, Android `false` | Clears the badge when the app opens: on iOS it sets the badge to 0; on Android it removes SallaPush's notifications that show on the badge from the shade. `null` keeps each platform's default; a value applies to both platforms ([Badges](../README.md#badges)). |
| `autoUpdateBadge` | `true` | SallaPush counts its notifications on the badge: on iOS through the extension and the App Group; on Android, `false` creates SallaPush's notification channels without badges. |
| `ios.appGroupIdentifier` | the `SallaPushAppGroup` key | The App Group shared with the extension. |
| `ios.apnsEnvironment` | `automatic` | Read from the provisioning profile: development builds and the simulator use the sandbox. Set it only for unusual signing. |
| `ios.registerForRemoteNotificationsOnInit` | `true` | Turn it off only if the app calls `notifications.registerForRemoteNotifications()` itself at every launch. |

The `ios` options are ignored on Android.

## SallaPush.user

| Member | Notes |
|---|---|
| `SallaPushSubscription get pushSubscription` | [Below](#sallapushuserpushsubscription). |
| `Future<String?> get externalId` | The id of the last `login`; `null` for a guest. |
| `Future<bool> get isLoggedIn` | True after `login`, until `logout`. |
| `Future<void> addTag(String key, String value)`, `addTags(Map<String, String> tags)` | Adds or replaces tags. Keys are trimmed and lowercased, then 1 to 64 characters of `a-z`, `0-9` and `_`. Values are cut at 255 characters, and an empty value removes the tag. A device holds at most 100 tags. Invalid tags are logged (`tags.invalid_key`) and dropped. |
| `Future<void> removeTag(String key)`, `removeTags(List<String> keys)` | |
| `Future<Map<String, String>> getTags()` | The device's tags, with the changes not sent yet. |
| `Future<void> setLanguage(String? language)` | The language reported for this device, such as `ar`; `null` reports the device's language. |
| `Stream<SallaPushUserChangedState> get onChange` | Changes of `externalId` or `isLoggedIn`. |
| `Stream<SallaPushLoginFailure> get onLoginFailure` | Each refused login: `tokenRejected` or `invalidRequest`. On `tokenRejected`, call `login` when your app next refreshes the token, or at the next launch, not from the listener. |

## SallaPush.user.pushSubscription

| Member | Notes |
|---|---|
| `Future<String?> get id` | The SallaPush device id; `null` until the device is registered. |
| `Future<String?> get token` | The device's push token, on iOS the APNs token as hexadecimal text. Don't send it to analytics or third parties. |
| `Future<bool> get optedIn` | True when notifications are allowed, the user didn't opt out, and a push token exists. |
| `Future<void> optIn()` | Clears an earlier `optOut()`, and shows the permission prompt while it can still show. |
| `Future<void> optOut()` | Stops SallaPush notifications to this device until `optIn()`. |
| `Stream<SallaPushSubscriptionChangedState> get onChange` | Changes of the id, the token or the opt-in ([Events and states](#events-and-states)). |

## SallaPush.notifications

| Member | Notes |
|---|---|
| `Future<bool> get permission` | Whether the app may show notifications. |
| `Future<bool> canRequestPermission()` | Whether the system prompt can still show. |
| `Future<SallaPushIosPermissionStatus?> get permissionStatus` | iOS only: the authorization status. |
| `Future<bool> requestPermission({bool fallbackToSettings = false})` | Shows the system prompt, and completes with whether notifications are allowed. `fallbackToSettings: true` opens the app's notification settings when the prompt can no longer show. Android prompts only on Android 13 and later, with the app in the foreground. |
| `Future<bool> registerForProvisionalAuthorization()` | iOS only: allows quiet notifications without a prompt, and completes with whether they are allowed. |
| `Future<void> refreshPermission()` | Reads the permission again, for apps that ask for it in their own way. |
| `Future<void> registerForRemoteNotifications()` | iOS only, for apps that turn `ios.registerForRemoteNotificationsOnInit` off. |
| `Future<void> forwardApnsToken(String apnsToken)` | iOS only: hands SallaPush the APNs token that another SDK holds, as hexadecimal text ([Other push SDKs](SETUP.md#other-push-sdks)). |
| `Future<void> clearAll()` | Removes SallaPush's delivered notifications; on iOS, while `autoUpdateBadge` is on, it also sets the badge to 0. |
| `Future<void> removeNotification(int androidNotificationId)` | Android only: removes the SallaPush notification with this `androidNotificationId`. |
| `Future<bool> isSallaPushNotification(Map<String, Object?> payload)` | Whether a payload, such as the data of another SDK's message, is SallaPush's. |
| `Future<bool> trackOpened(Map<String, Object?>? additionalData)` | Android only: records the tap on a SallaPush notification that another SDK showed. Pass that SDK's additional data; it completes with whether the notification was SallaPush's. |
| `Stream<SallaPushClickEvent> get onClick` | Every tap on a SallaPush notification ([Events and states](#events-and-states)). |
| `Stream<SallaPushWillDisplayEvent> get onWillDisplay` | Foreground notifications, held for your decision ([Foreground notifications](#foreground-notifications)). |
| `Stream<bool> get onPermissionChange` | Changes between allowed and not allowed. |

## SallaPush.debug

| Member | Notes |
|---|---|
| `Future<SallaPushLogLevel> get logLevel` | The console's level in effect. |
| `Future<void> setLogLevel(SallaPushLogLevel level)` | Sets the console's level until the app ends, over `SallaPushConfig.logLevel` and the static keys. |
| `Future<void> setLogHandler(SallaPushLogLevel level, void Function(SallaPushLogEntry entry)? handler)` | One handler for the app, which receives the entries at `level` or more severe: a new one replaces the previous one, and `null` removes it. The first handler set in a process also gets up to 100 earlier warnings and errors. |

## SallaPushNotification

A notification as SallaPush parsed it: immutable, with no public constructor.

| Member | Type | Notes |
|---|---|---|
| `notificationId` | `String?` | The SallaPush message id. |
| `title`, `subtitle`, `body`, `sound` | `String?` | |
| `imageUrl` | `String?` | The https image URL. |
| `launchUrl` | `String?` | The launch URL, exactly as sent. |
| `additionalData` | `Map<String, Object?>` | Your data, read-only. Read it with the typed getters. |
| `rawPayload` | `Map<String, Object?>` | The push as received, read-only. |
| `source` | `SallaPushPayloadSource` | The payload's format: `native` or `compat`. |
| `badge`, `threadId` | `int?`, `String?` | iOS only. |
| `androidNotificationId`, `collapseId`, `channelId` | `int?`, `String?`, `String?` | Android only. |
| `getString(key)`, `getInt(key)`, `getBool(key)` | `String?`, `int?`, `bool?` | A top-level `additionalData` value, from text or a JSON value, as the native SDKs read it; `null` when it is absent or can't be converted. |
| `getNumber(key)` | `num?` | iOS only; `null` on Android. |
| `display()` | `Future<void>` | Shows a foreground notification that an `onWillDisplay` listener prevented, once, within 10 minutes ([Foreground notifications](#foreground-notifications)). |

## Events and states

- **Streams.** Every stream is a broadcast stream, and each getter returns the same stream. A listener that throws
  doesn't stop the others.
- **Taps.** While no `onClick` listener exists, SallaPush keeps taps, up to 10, for 5 minutes, and hands them to the
  listeners subscribed when the first one subscribes: listen in `main()`, before `runApp`.
- **Push subscription.** Each `pushSubscription.onChange` listener added while the device is registered first gets the
  current state once, with `previous` equal to `current`.
- **User and permission.** `user.onChange` and `onPermissionChange` report changes only.
- **Hot restart.** A will-display listener of the old isolate keeps holding foreground notifications until the new
  isolate listens again: do a full restart instead.

| Type | Members |
|---|---|
| `SallaPushClickEvent` | `notification`; `result`, a `SallaPushClickResult` |
| `SallaPushClickResult` | `actionId`: the tapped action button on iOS, `null` for a tap on the notification itself and on Android; `url`: the launch URL |
| `SallaPushWillDisplayEvent` | `notification`; `isPrevented`; `preventDefault()` |
| `SallaPushSubscriptionState` | `id`, `token`, `optedIn` |
| `SallaPushSubscriptionChangedState` | `previous`, `current` |
| `SallaPushUserState` | `externalId`, `isLoggedIn` |
| `SallaPushUserChangedState` | `previous`, `current` |
| `SallaPushLogEntry` | `level`, `category`, `code`, `message`, `metadata` (read-only), `timestamp` (UTC) |

| Enum | Values |
|---|---|
| `SallaPushLogLevel` | `off`, `error`, `warn` (the default), `info`, `debug`, `verbose` |
| `SallaPushLoginFailure` | `tokenRejected`: the identity token was refused; `invalidRequest`: the login was refused as invalid, and isn't sent again |
| `SallaPushPayloadSource` | `native`: SallaPush's own format; `compat`: the compatible format, which another push SDK in the app can also show |
| `SallaPushApnsEnvironment` | `automatic`, `sandbox`, `production` (iOS) |
| `SallaPushIosPermissionStatus` | `notDetermined`, `denied`, `authorized`, `provisional`, `ephemeral` (iOS) |

### Foreground notifications

While an `onWillDisplay` listener exists, SallaPush holds each foreground notification and offers it to the listeners.
It shows the notification once they have returned, unless one called `event.preventDefault()`.

- **Call `preventDefault()` before any `await`,** and use `listen()`, not `await for`: an event that reaches a listener
  late can't keep its notification hidden. Don't pause the subscription.
- **Listen in one Flutter engine only:** with listeners in several, a notification shows unless every engine prevents
  it.
- **`notification.display()`** shows a prevented notification later, once, within 10 minutes.
- **On iOS, the notification shown is SallaPush's local copy:** it keeps the title, subtitle, body, sound, thread id
  and data, but has no image, no action buttons, no interruption level and no relevance score, and a later push with
  the same collapse id doesn't replace it. Without a listener, iOS shows the original, so listen only where a screen
  decides, and cancel when it goes.

## Platform-only members

They exist on both platforms. On the other one they answer at once, and print one `[SallaPush]` info line per member
per process.

| Member | Works on | On the other platform |
|---|---|---|
| `notifications.permissionStatus` | iOS | `null` |
| `notifications.registerForProvisionalAuthorization()` | iOS | `false` |
| `notifications.registerForRemoteNotifications()` | iOS | does nothing |
| `notifications.forwardApnsToken(apnsToken)` | iOS | does nothing |
| `notifications.removeNotification(androidNotificationId)` | Android | does nothing |
| `notifications.trackOpened(additionalData)` | Android | `false` |

## Errors

| Situation | What happens |
|---|---|
| An invalid argument, such as an empty tag key or identity token | SallaPush logs it (`api.invalid_argument`, `tags.invalid_key`, …) and ignores it. The future completes normally. |
| A call before SallaPush started, or while consent is withheld | SallaPush keeps it, up to 100 calls, and runs it later. The future completes normally. |
| A refused login | An `onLoginFailure` event. |
| A static key that can't be read | Ignored, with a `[SallaPush]` error ([Values](#values)). |
| A platform-only call on the other platform | A neutral value ([Platform-only members](#platform-only-members)). |
| The plugin is missing: on the web or a desktop, or in a unit test without a fake | Calls fail with a `PlatformException` whose code is `channel-error`, and the streams never emit. |

## Log codes

SallaPush logs to the unified log on iOS, under the subsystem `com.salla.push`, which Xcode's console shows, and to
Logcat on Android, under the tag `SallaPush`. `SallaPush.debug.setLogLevel` wins over `SallaPushConfig.logLevel`,
which wins over the static keys. Every entry has a stable `code`, which never changes between releases: match on it,
not on the message. The codes you'll see most:

| Code | Level | Meaning |
|---|---|---|
| `init.started` | info | SallaPush started with the app id. |
| `init.invalid_app_id` | error | The app id is invalid: SallaPush stays off until the next launch. |
| `init.no_delegate` | warn | iOS: no notification-center delegate is set: call `SallaPushFlutter.start()` first. |
| `consent.waiting` | info | Waiting for `setConsentGiven(true)`. |
| `token.received` | info | The push token reached SallaPush. |
| `token.unchanged` | debug | The same token again. |
| `token.missing` | warn | No token 30 seconds after the app came to the foreground; the message names the likely cause. |
| `token.registration_failed` | warn | iOS couldn't register for remote notifications. |
| `token.firebase_missing` | warn | Android: the app has no default Firebase app ([Firebase](SETUP.md#android-firebase)). |
| `register.ok` | info | The device is registered. |
| `register.dormant` | error | The registration waits 24 hours, for example for an app id that isn't known: check it. |
| `login.ok` | info | The customer is linked. |
| `login.skipped_same` | debug | Already linked to this customer: nothing to send. |
| `login.rejected` | warn | The identity token was refused: `onLoginFailure` gives `tokenRejected`. |
| `logout.skipped` | debug | Not linked: nothing to unlink. |
| `identity.token_needed` | warn | The link waits for the app's next `login` call. |
| `api.invalid_argument` | warn | A call was ignored because of an argument; the message says why. |
| `tags.invalid_key` | warn | A tag key is invalid, and the tag was dropped. |
| `notif.suppressed` | debug | Android: a notification wasn't shown: notifications off, the channel blocked, or the user opted out. |
| `display.default_icon` | warn | Android: no usable small icon in the meta-data. |
| `fcm.forwarding_hint` | info | Android: another service receives the push messages, and none reached SallaPush ([Other push SDKs](SETUP.md#other-push-sdks)). |
| `config.no_app_group` | info | iOS: no App Group, so the extension can't count the badge. |
| `nse.attachment_failed` | warn | iOS: the extension couldn't attach the image. |

Every code, with its level and meaning:
[iOS](https://github.com/SallaApp/mobile-push-ios-sdk/blob/1.0.4/docs/LOGGING.md#log-code-reference),
[Android](https://github.com/SallaApp/mobile-push-android-sdk/blob/1.0.4/docs/LOGGING.md#log-code-reference).

### The plugin's own lines

The plugin writes its own lines to the same consoles, prefixed `[SallaPush]`, without a code. They never reach the log
handler. Setup problems are errors; reminders and platform-only calls are info:

| Line | Level | Fix |
|---|---|---|
| `SallaPushFlutter.start() was not called from AppDelegate.…` | error | Call `SallaPushFlutter.start()` first in `didFinishLaunchingWithOptions`. |
| `<class> is already the notification-center delegate.…` | error | Make that delegate hand the calls to the `FlutterAppDelegate`, or to `SallaPush.Notifications.willPresent` and `didReceive` first. |
| `<class> overrides <method>.…` | info | Answer SallaPush's notifications first in your override, as [Other push SDKs](SETUP.md#other-push-sdks) shows, or call `super`. |
| `SallaPush already started at launch with this app id, so initialize ignored its options.…` | error | Set each option with the static key the line names. |
| `setConsentRequired(true) came after SallaPush started at launch without requiring consent.…` | error | Require consent with the static key. |
| `Info.plist key <key> …`, `Manifest meta-data <name> …` | error | Fix the key's value ([Values](#values)). |
| `SallaPush.<member> works on <platform> only…` | info | Nothing: a [platform-only member](#platform-only-members) answered with a neutral value. |
| `display() did nothing…` | info | Show a prevented notification once, within 10 minutes. |
