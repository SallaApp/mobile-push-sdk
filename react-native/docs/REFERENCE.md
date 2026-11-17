# SallaPush React Native SDK: API reference

The package's API, its static configuration and the Expo plugin's options. The [README](../README.md) shows the setup
and the usage, and [Troubleshooting](TROUBLESHOOTING.md) the common problems.

## Contents

1. [Static configuration](#static-configuration)
2. [Expo plugin options](#expo-plugin-options)
3. [Forwarding FCM messages](#forwarding-fcm-messages)
4. [API](#api)
5. [Events](#events)
6. [Foreground display](#foreground-display)
7. [Badges](#badges)
8. [Log codes](#log-codes)
9. [Compatibility](#compatibility)

## Static configuration

The app configures SallaPush with Info.plist keys on iOS and `<meta-data>` inside `<application>` on Android, which
the Expo plugin writes from its options. Every key but the log level, the App Group, the icon and the channel takes
effect only together with the app id: an app that calls `initialize` passes those settings to it instead.

| Purpose | iOS Info.plist key | Android meta-data | Default |
|---|---|---|---|
| The app id: SallaPush starts at launch | `SallaPushAppId` (String) | `com.salla.push.APP_ID` | None: SallaPush starts when JavaScript calls `initialize` |
| Require consent | `SallaPushRequiresUserConsent` (Boolean) | `com.salla.push.REQUIRES_USER_CONSENT` | `false` |
| Open https launch URLs on tap | `SallaPushOpenLaunchURLs` (Boolean) | `com.salla.push.OPEN_LAUNCH_URLS` | `false` |
| Delete the device's tags on logout and account switch | `SallaPushClearTagsOnLogout` (Boolean) | `com.salla.push.CLEAR_TAGS_ON_LOGOUT` | `true` |
| The app version SallaPush reports | `SallaPushAppVersion` (String) | `com.salla.push.APP_VERSION` | `CFBundleShortVersionString`; `versionName` |
| Clear the badge when the app opens | `SallaPushAutoClearBadge` (Boolean) | `com.salla.push.AUTO_CLEAR_BADGE` | `true` on iOS, `false` on Android |
| Count SallaPush notifications on the badge | `SallaPushAutoUpdateBadge` (Boolean) | `com.salla.push.AUTO_UPDATE_BADGE` | `true` |
| Register for remote notifications at start | `SallaPushRegisterForRemoteNotificationsOnInit` (Boolean) | – | `true` |
| The APNs environment: `automatic`, `sandbox` or `production` | `SallaPushAPNsEnvironment` (String) | – | `automatic` |
| The log level | `SallaPushLogLevel` | `com.salla.push.LOG_LEVEL` | `warn` |
| The App Group, in the app and the extension | `SallaPushAppGroup` | – | None |
| The notification icon | – | `com.salla.push.default_notification_icon` (`android:resource`) | Firebase's default icon, else SallaPush's bell (`display.default_icon`) |
| The default channel | – | `com.salla.push.default_channel_id`, `com.salla.push.default_channel_name` | Firebase's default channel (`com.google.firebase.messaging.default_notification_channel_id`) when it exists, else SallaPush's own channel |

- **iOS booleans** are `<true/>` or `<false/>`, or the strings `true`, `false`, `YES`, `NO`, `1` and `0`, as values
  from build settings arrive. A string from an undefined build setting is empty, and counts as absent.
- **Android text values** that look like numbers, such as a version `2.10`, go in a string resource,
  `android:value="@string/…"`: a literal one arrives as a number. The Expo plugin does that for its text options.
- **A value the package can't use** is ignored, with a `[SallaPush] Ignored …` console error.

## Expo plugin options

Every option is optional. An unknown option or a wrong type fails prebuild, naming the option.

| `ios` option | What it sets | Default |
|---|---|---|
| `appId` | `SallaPushAppId`. Prebuild checks it: 1 to 64 letters, digits, `_` or `-`. | None: SallaPush starts when JavaScript calls `initialize`, and prebuild warns |
| `requiresUserConsent` | `SallaPushRequiresUserConsent` | `false` |
| `mode` | The `aps-environment` entitlement, written only when the app has none: `development` or `production` | `development` |
| `appGroup` | The App Group of the app and the extension, and `SallaPushAppGroup` in both Info.plist files | None |
| `openLaunchUrls` | `SallaPushOpenLaunchURLs` | `false` |
| `clearTagsOnLogout` | `SallaPushClearTagsOnLogout` | `true` |
| `autoClearBadge` | `SallaPushAutoClearBadge` | `true` |
| `autoUpdateBadge` | `SallaPushAutoUpdateBadge` | `true` |
| `registerForRemoteNotificationsOnInit` | `SallaPushRegisterForRemoteNotificationsOnInit` | `true` |
| `apnsEnvironment` | `SallaPushAPNsEnvironment` | `automatic` |
| `appVersion` | `SallaPushAppVersion` | The app's version |
| `logLevel` | `SallaPushLogLevel`: `off`, `error`, `warn`, `info`, `debug` or `verbose` | `warn` |
| `notificationServiceExtension` | Adds the Notification Service Extension `SallaPushNotificationService` | `true` |
| `developmentTeam` | The extension's Apple team | `ios.appleTeamId` |

| `android` option | What it sets | Default |
|---|---|---|
| `appId` | `com.salla.push.APP_ID`, checked as on iOS | None: SallaPush starts when JavaScript calls `initialize`, and prebuild warns |
| `requiresUserConsent` | `com.salla.push.REQUIRES_USER_CONSENT` | `false` |
| `smallIcon` | The notification icon: a 96 × 96 white-on-transparent PNG, such as `./assets/notification-icon.png`, or a drawable of the app, such as `@drawable/ic_notification` | None: prebuild warns |
| `defaultChannelId`, `defaultChannelName` | `com.salla.push.default_channel_id` and `default_channel_name` | Firebase's default channel when it exists, else SallaPush's own channel |
| `openLaunchUrls` | `com.salla.push.OPEN_LAUNCH_URLS` | `false` |
| `clearTagsOnLogout` | `com.salla.push.CLEAR_TAGS_ON_LOGOUT` | `true` |
| `autoClearBadge` | `com.salla.push.AUTO_CLEAR_BADGE` | `false` |
| `autoUpdateBadge` | `com.salla.push.AUTO_UPDATE_BADGE` | `true` |
| `appVersion` | `com.salla.push.APP_VERSION` | The app's version |
| `logLevel` | `com.salla.push.LOG_LEVEL` | `warn` |
| `fcmForwarding` | The [forwarding service](#forwarding-fcm-messages): `auto`, `none`, or the package name of the app's FCM library, as prebuild's error names it | `auto`: generated when the app depends on an FCM library the plugin knows |

- **Development builds only,** on the New Architecture: `newArchEnabled: false` fails prebuild.
- **The extension** needs `ios.bundleIdentifier`; its own is `<bundle id>.SallaPushNotificationService`. Turning it off
  doesn't remove one that an earlier prebuild added: run `npx expo prebuild --clean`.
- **Another config plugin that adds a Notification Service Extension:** an app has one, so set
  `ios.notificationServiceExtension` to `false`, and call SallaPush first in that extension, with `SallaPushCore` and
  `SallaPushExtension` in its Podfile target and the App Group in its Info.plist.
- **Every prebuild gives the same result.** The plugin's lines in `AppDelegate.swift` and the Podfile sit between
  `@generated` comments. When it can't find where a change goes, as in a customized `AppDelegate`, prebuild fails with
  the lines to add by hand.

## Forwarding FCM messages

Android hands each FCM message to one service: the one with the highest priority in the merged manifest. With another
library that declares an FCM service, add a service that hands each message to SallaPush first, then to that library,
at priority 1. The Expo plugin generates it for the libraries of `android.fcmForwarding`; for any other, set
`android.fcmForwarding` to `none`, and add the service through a config plugin of your own, since prebuild regenerates
`android/`. In a bare app, put the class next to `MainActivity.kt`, in your app's package, and extend the other
library's FCM service, which `OtherLibraryMessagingService` stands for:

<!-- unchecked: OtherLibraryMessagingService stands for the other library's FCM service; the Expo plugin renders this class from plugin/templates/SallaPushMessagingService.kt.tmpl, and scripts/verify.sh consumer compiles it -->
```kotlin
import com.google.firebase.messaging.RemoteMessage
import com.salla.push.SallaPush

class SallaPushMessagingService : OtherLibraryMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        if (SallaPush.Notifications.handleFirebaseMessage(applicationContext, remoteMessage)) return
        super.onMessageReceived(remoteMessage)
    }

    override fun onNewToken(token: String) {
        SallaPush.Notifications.onNewToken(applicationContext, token)
        super.onNewToken(token)
    }
}
```

<!-- unchecked: the declaration of the service above, inside <application>; the Expo plugin writes it with the full class name, and scripts/verify.sh consumer builds it -->
```xml
<service android:name=".SallaPushMessagingService" android:exported="false">
  <intent-filter android:priority="1">
    <action android:name="com.google.firebase.MESSAGING_EVENT" />
  </intent-filter>
</service>
```

`handleFirebaseMessage` returns `false` at once for a message that isn't SallaPush's. If your app already declares a
`com.google.firebase.MESSAGING_EVENT` service, put the SallaPush lines first in it and give it priority 1, rather than
adding a second one.

## API

Everything is imported from `@salla.sa/mobile-push-react-native`, by name.

- **Getters and requests return a `Promise`;** every other call returns at once.
- **Calls never throw.** An invalid argument is logged and ignored. One of the wrong type is dropped, with one
  `console.warn` per method and argument, and a dropped request resolves `false`.
- **Calls made before SallaPush is initialized,** or while consent is withheld, wait, and run in order.
- **Platform-only members** resolve `null` or `false`, or do nothing, on the other platform.

### SallaPush

| Member | Behaviour |
|---|---|
| `initialize(appId: string, config?: SallaPushConfig): void` | Starts SallaPush with an app id known only at run time. Prefer the static app id: without it, a tap that starts the app doesn't open its launch URL, and an Android process that FCM starts for a message doesn't apply the user's opt-out. After a start from the static app id, an `initialize` with that app id changes nothing, its options included, and logs an error naming the static keys to use; another app id switches to it. An invalid first app id turns SallaPush off until the next launch (`init.invalid_app_id`). |
| `isInitialized(): Promise<boolean>` | Whether SallaPush is running |
| `getAppId(): Promise<string \| null>` | The app id SallaPush runs with |
| `getSdkVersion(): Promise<string>` | The native SDK's version on this platform |
| `setConsentRequired(required: boolean): void` | Not saved: call it before `initialize`, at every launch. With a static app id, set the static key instead. |
| `setConsentGiven(given: boolean): void` | Saved. `false`, while consent is required, withdraws consent: the device is opted out, its tags are deleted and it is unlinked. |
| `login(externalId: string, identityToken: string): void` | Links the device to the customer: their id as Salla knows it, such as `"42"`, 1 to 128 characters, and the customer token your app received at sign-in, without `Bearer `, at most 4,096 characters. The token is kept in memory only: call `login` after sign-in, at each launch while the customer is signed in, and when your app refreshes the token. A refused token is a `'loginFailure'` event. |
| `logout(): void` | Unlinks the device, also offline. Call it after sign-out, before another customer's `login`, and at each app launch while nobody is signed in: on iOS, a reinstall keeps the earlier install's customer linked until then. It sends nothing when the device isn't linked. |
| `User`, `Notifications`, `Debug` | Below |

`SallaPushConfig`, the options of `initialize`. An option left out keeps the default, or the static key's value:

<!-- snippet:example/src/readmeSnippets/configuration.ts#initialize -->
```ts
SallaPush.initialize(appId, {
  logLevel: SallaPushLogLevel.Info,
  ios: { appGroupIdentifier: 'group.com.example.shop' },
});
```

| Option | Default |
|---|---|
| `logLevel?: SallaPushLogLevel` | `warn` |
| `appVersion?: string` | `CFBundleShortVersionString`; `versionName` |
| `clearTagsOnLogout?: boolean` | `true` |
| `requiresUserConsent?: boolean` | `false` |
| `openLaunchUrls?: boolean` | `false`. With it on, SallaPush opens https launch URLs itself, and the click listener mustn't open `result.url` again. |
| `autoClearBadge?: boolean` | Left out, each platform's own: `true` on iOS, `false` on Android. Given, it applies to both. |
| `autoUpdateBadge?: boolean` | `true` |
| `ios?.appGroupIdentifier?: string` | `SallaPushAppGroup` |
| `ios?.apnsEnvironment?: SallaPushAPNsEnvironment` | `automatic`: from the provisioning profile |
| `ios?.registerForRemoteNotificationsOnInit?: boolean` | `true`. Set it to `false` only if the app registers at every launch itself. |

### SallaPush.User

| Member | Behaviour |
|---|---|
| `getExternalId(): Promise<string \| null>` | The id of the last `login`; `null` for a guest |
| `isLoggedIn(): Promise<boolean>` | Whether the last call was `login` |
| `addTag(key: string, value: string): void` | Keys are trimmed and lowercased, then must be 1 to 64 characters of `a-z`, `0-9` and `_` (`tags.invalid_key`). Values are cut at 255 characters (`tags.value_truncated`); an empty value removes the tag. At most 100 tags (`tags.limit`). |
| `addTags(tags: Record<string, string>): void` | The same, for each entry |
| `removeTag(key: string): void`, `removeTags(keys: string[]): void` | Remove tags |
| `getTags(): Promise<Record<string, string>>` | The tags, with your latest changes; right after a cold start, only this launch's |
| `setLanguage(language: string \| null): void` | A language code such as `ar`; `null` means the device language |
| `addEventListener('change', listener)` | Login changes: `{ previous, current }`, each `{ externalId, isLoggedIn }` |
| `addEventListener('loginFailure', listener)` | Each refusal of the current login: `tokenRejected` or `invalidRequest`. Don't call `login` again from it. |
| `removeEventListener(event, listener): void` | |
| `pushSubscription` | Below |

### SallaPush.User.pushSubscription

| Member | Behaviour |
|---|---|
| `getId(): Promise<string \| null>` | The SallaPush device id; `null` until the device is registered |
| `getToken(): Promise<string \| null>` | The APNs token, in lowercase hexadecimal, or the FCM token. It is private: never send it to analytics or third parties. |
| `getOptedIn(): Promise<boolean>` | Notifications allowed, not opted out, and a token |
| `optIn(): void` | Clears an opt-out, and shows the permission prompt while it can still show |
| `optOut(): void` | Stops SallaPush notifications on this device |
| `addEventListener('change', listener)` | `{ previous, current }`, each `{ id, token, optedIn }` ([Events](#events)) |
| `removeEventListener('change', listener): void` | |

### SallaPush.Notifications

| Member | Behaviour |
|---|---|
| `getPermission(): Promise<boolean>` | Whether notifications are allowed: on iOS, authorized, provisional or ephemeral |
| `canRequestPermission(): Promise<boolean>` | Whether the system can still show the prompt |
| `getPermissionStatus(): Promise<SallaPushIOSPermissionStatus \| null>` | iOS: `notDetermined`, `denied`, `authorized`, `provisional` or `ephemeral`. `null` on Android. |
| `requestPermission(fallbackToSettings?: boolean): Promise<boolean>` | Shows the prompt, and resolves whether notifications are allowed. With `true`, it opens the app's notification settings once the prompt no longer shows. On Android, while the app isn't in the foreground, it resolves the current state without a prompt. |
| `registerForProvisionalAuthorization(): Promise<boolean>` | iOS: quiet notifications, without a prompt. `false` on Android. |
| `refreshPermission(): void` | Reads the permission again, after the app asked for it itself |
| `registerForRemoteNotifications(): void` | iOS, with `registerForRemoteNotificationsOnInit` off. Does nothing on Android. |
| `forwardApnsToken(apnsToken: string): void` | iOS: the APNs token another SDK holds, as hexadecimal text. Does nothing on Android. |
| `clearAll(): void` | Removes SallaPush's delivered notifications; other notifications stay. On iOS, with `autoUpdateBadge` on, it also sets the badge to 0. |
| `removeNotification(androidNotificationId: number): void` | Android: removes one SallaPush notification, by `notification.androidNotificationId`. Does nothing on iOS. |
| `isSallaPushNotification(payload: Record<string, unknown>): Promise<boolean>` | Whether a payload another library received, an FCM data map or an APNs `userInfo`, is SallaPush's |
| `trackOpened(additionalData: Record<string, unknown> \| null): Promise<boolean>` | Android: records `opened` for a SallaPush notification that another SDK showed, from the custom data that SDK gives for it, and resolves whether it was SallaPush's. `false` on iOS. |
| `addEventListener('click', listener)` | Every tap on a SallaPush notification ([Events](#events)) |
| `addEventListener('foregroundWillDisplay', listener)` | [Foreground display](#foreground-display) |
| `addEventListener('permissionChange', listener)` | Changes between allowed and not allowed |
| `removeEventListener(event, listener): void` | |

### SallaPush.Debug

| Member | Behaviour |
|---|---|
| `getLogLevel(): Promise<SallaPushLogLevel>` | The console level |
| `setLogLevel(level: SallaPushLogLevel): void` | Sets the console level; it wins over the static key |
| `setLogHandler(level, handler \| null): void` | One handler for the app, which a new one replaces and `null` removes. It gets the entries at `level` or more severe, whatever the console level, on the JavaScript thread; the first handler also gets up to 100 earlier warnings and errors. On iOS, it replaces a handler set from native code. |

<!-- snippet:example/src/readmeSnippets/configuration.ts#log-handler -->
```ts
SallaPush.Debug.setLogHandler(SallaPushLogLevel.Error, (entry) => {
  telemetry.report('sallapush', entry.code, entry.message, entry.metadata);
});
```

### Types

`SallaPushNotification`:

| Member | Value |
|---|---|
| `notificationId: string \| null` | The SallaPush message id |
| `title`, `subtitle`, `body: string \| null` | The text |
| `imageUrl: string \| null` | The image, https only |
| `launchUrl: string \| null` | The launch URL, as the sender set it: check its scheme and host before you open it |
| `additionalData: Readonly<Record<string, unknown>>` | Your data |
| `rawPayload: Readonly<Record<string, unknown>>` | The payload as received: the APNs `userInfo`, or the FCM data map |
| `source: SallaPushPayloadSource` | The payload's format: `native` or `compat` |
| `sound: string \| null` | The sound |
| `badge: number \| null`, `threadId: string \| null` | iOS only; `null` on Android |
| `androidNotificationId: number \| null`, `collapseId: string \| null`, `channelId: string \| null` | Android only; `null` on iOS |
| `getString(key)`, `getInt(key)`, `getBool(key)` | A top-level `additionalData` value, from either format (`"id": "42"` or `"id": 42`), or `null` |
| `getNumber(key)` | iOS only; `null` on Android |
| `display(): void` | Shows a held foreground notification ([Foreground display](#foreground-display)) |

| Type | Members |
|---|---|
| `SallaPushClickEvent` | `notification`, and `result`: `actionId`, the action button tapped (iOS; `null` for a tap on the notification itself, and on Android), and `url`, the launch URL |
| `SallaPushWillDisplayEvent` | `notification`, `isPrevented`, `preventDefault()` |
| `SallaPushSubscriptionChangedState` | `previous` and `current`, each a `SallaPushSubscriptionState`: `id`, `token`, `optedIn` |
| `SallaPushUserChangedState` | `previous` and `current`, each a `SallaPushUserState`: `externalId`, `isLoggedIn` |
| `SallaPushLogEntry` | `level`, `category`, `code`, `message`, `metadata` and `timestamp`, in milliseconds since the epoch |
| `SallaPushEventSubscription` | `remove()`, which removes the listener; a second call does nothing |
| `SallaPushPluginProps` | The Expo plugin's options |

The enumerations are objects of string constants, with a type of the same name:

| Enumeration | Values |
|---|---|
| `SallaPushLogLevel` | `Off` (`'off'`), `Error`, `Warn`, `Info`, `Debug`, `Verbose` |
| `SallaPushLoginFailure` | `TokenRejected` (`'tokenRejected'`), `InvalidRequest` (`'invalidRequest'`) |
| `SallaPushPayloadSource` | `Native` (`'native'`), `Compat` (`'compat'`) |
| `SallaPushAPNsEnvironment` | `Automatic` (`'automatic'`), `Sandbox`, `Production` |
| `SallaPushIOSPermissionStatus` | `NotDetermined` (`'notDetermined'`), `Denied`, `Authorized`, `Provisional`, `Ephemeral` |

## Events

- **Adding and removing.** `addEventListener` returns a subscription, whose `remove()` removes the listener, as
  `removeEventListener(event, listener)` with the same function does. The same function added twice for one event is
  added once.
- **Order.** Listeners run on the JavaScript thread, in the order they were added. A listener that throws is reported
  with `console.error`, and the others still run.
- **Taps before a listener.** Up to 10 taps made before the first click listener wait, for 5 minutes, and arrive a
  moment after it is added, once, at every click listener added by then: add the click listener at app start.
- **Subscription changes.** Each listener gets the current state once, with `previous` equal to `current`, once the
  device is registered, then every change of the device id, the push token and the opted-in state.
- **User and permission changes** don't replay the current state. There is no login success event.

<!-- snippet:example/src/readmeSnippets/notifications.tsx#remove-listener -->
```ts
const onChange = (granted: boolean) => settingsScreen.showPermission(granted);
SallaPush.Notifications.addEventListener('permissionChange', onChange);
// Later, the same function removes it:
SallaPush.Notifications.removeEventListener('permissionChange', onChange);
```

## Foreground display

Without a `'foregroundWillDisplay'` listener, SallaPush shows its notifications in the foreground itself. A listener can
hold each one back, here on a chat screen, and the effect's cleanup removes it:

<!-- snippet:example/src/readmeSnippets/notifications.tsx#will-display -->
```tsx
useEffect(() => {
  const subscription = SallaPush.Notifications.addEventListener(
    'foregroundWillDisplay',
    (event) => {
      if (event.notification.getString('chat_id') === chatId) {
        event.preventDefault(); // before any await: it counts only while the listener runs
      }
    }
  );
  return () => subscription.remove();
}, [chatId]);
```

- **While a listener exists,** SallaPush holds each foreground notification, and shows it once the listeners have
  returned, unless one called `event.preventDefault()`, before any `await`.
- **`event.notification.display()`** shows a prevented notification later, once, within 10 minutes. Before
  `event.preventDefault()`, and on any other notification, it does nothing.
- **On iOS, a notification shown this way is SallaPush's local copy,** without the image, the action buttons, the
  interruption level, the relevance score and the collapse id. Android shows the real notification. So listen only
  where your app decides per notification, and remove the listener when the screen goes.
- **While the user is opted out,** SallaPush shows no notification, and runs no listener.
- **In an app with several React Native instances,** listen in one only.

## Badges

| | iOS | Android |
|---|---|---|
| How it counts | The Notification Service Extension adds 1 for each SallaPush notification. It needs the same App Group in the app and the extension, and the app opened once with this version. iOS doesn't run the extension while the app's alerts are off. | The launcher counts the app's notifications in the shade. Pixel shows a dot, Samsung and Xiaomi a number when the user picks numbers. |
| `autoClearBadge` | On by default: the badge goes back to 0 whenever the app becomes active. Off: the badge counts the SallaPush notifications still in Notification Center. | Off by default: the badge follows SallaPush's notifications in the shade. On: SallaPush removes them from the shade when the app comes to the foreground. |
| `autoUpdateBadge: false` | SallaPush sets no number but `autoClearBadge`'s 0, and a push's own `badge` applies | SallaPush's channels are created without badges; a channel created earlier keeps them (`badge.channel_badges_on`) |
| `clearAll()` | Removes SallaPush's notifications, and sets the badge to 0 while `autoUpdateBadge` is on | Removes SallaPush's notifications, which lowers the badge |

- **One badge per app.** On iOS the icon shows the last number written, by SallaPush, another SDK, a push or your app:
  clear the badge with `autoClearBadge` or `clearAll()`, not with another library's badge call.
- **iOS 15:** setting the badge to 0 also removes the app's delivered notifications, so the default `autoClearBadge`
  removes them at almost every open: `autoClearBadge: false` keeps them.
- **With consent required and not given,** SallaPush neither counts nor clears.

## Log codes

Every SallaPush log entry has a stable code, such as `register.ok`: match on it, never on the message. The native docs
list them all, with their levels
([iOS](https://github.com/SallaApp/mobile-push-ios-sdk/blob/1.1.0/docs/LOGGING.md#log-code-reference),
[Android](https://github.com/SallaApp/mobile-push-android-sdk/blob/1.1.0/docs/LOGGING.md#log-code-reference)). The
consoles are the unified log on iOS, subsystem `com.salla.push`, and Logcat on Android, tag `SallaPush`.

The package's own lines start with `[SallaPush]`:

| Level | When |
|---|---|
| Error | A setup problem: `SallaPushRN.start()` wasn't called; `initialize` repeated the static app id with options; `setConsentRequired(true)` came after a static start without the consent key; a static key with a value it can't use; an APNs token that isn't hexadecimal |
| Warning | `display()` with a handle that is unknown or expired |
| Info | A call that works on the other platform only, once per process |

In JavaScript, the package warns once per method and argument about a mistyped call, and reports a listener that threw
with `console.error`.

## Compatibility

- **Native SDKs:** SallaPush iOS 1.1.0 and SallaPush Android 1.1.0.
- **React Native** 0.81 or later, on the New Architecture only. **Expo** SDK 54 or later, in development builds.
- **iOS** 15.0 or later (React Native itself needs 15.1, and Expo SDK 56 and later 16.4), Xcode 16 or later. The pods
  build as static libraries and as static or dynamic frameworks.
- **Android** minSdk 23 (React Native itself needs 24), compileSdk 34 or later, JDK 17. Minified release builds need no
  R8 rule of your own.
- **Package managers:** npm 11 and 12, and Yarn 4. pnpm, Yarn 1 and Bun install it the same way, but aren't verified
  yet.
