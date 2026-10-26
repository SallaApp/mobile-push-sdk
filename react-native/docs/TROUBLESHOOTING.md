# SallaPush React Native SDK: troubleshooting

Common problems and their fixes. Turn on verbose logs first ([Logging](../README.md#logging)): the log codes below are
SallaPush's own, and the native docs list every one
([iOS](https://github.com/SallaApp/mobile-push-ios-sdk/blob/1.0.4/docs/LOGGING.md#log-code-reference),
[Android](https://github.com/SallaApp/mobile-push-android-sdk/blob/1.0.4/docs/LOGGING.md#log-code-reference)).

Back to the [README](../README.md). The API: [Reference](REFERENCE.md)

## Installing and building

| You see | Fix |
|---|---|
| `pod install`: "Unable to find a specification for SallaPush" | Add the [Podfile lines](../README.md#installation) to the app's target, and the extension's pods to its target. In Expo, run `npx expo prebuild`. |
| `pod install`, after an update: `CocoaPods could not find compatible versions for pod "SallaPush"` | Set every SallaPush `:tag` of the Podfile, the extension's included, to the SallaPush iOS version of the [versions table](../README.md#requirements). In Expo, run `npx expo prebuild`. |
| `bundle exec pod install`: "unknown ISA `PBXFileSystemSynchronizedRootGroup`" | Xcode added the extension as a synchronized folder: right-click `SallaPushNotificationService` → **Convert to Group**, and set the project's **Project Format** back to **Xcode 15.3-compatible**. |
| Gradle: `Could not find com.salla:mobile-push` | Add `mavenCentral()` to the repositories your build uses. |
| The manifest merger: `requires a placeholder substitution but no value for <sallaPushAppId> is provided` | Define `manifestPlaceholders["sallaPushAppId"]` in `defaultConfig`, or write the app id in the manifest. |
| `TurboModuleRegistry.getEnforcing(...): 'RNSallaPush' could not be found` | Run `pod install`, then rebuild the app, with the New Architecture on. Expo Go can't load SallaPush: use a development build. In Jest, mock the package ([In unit tests](#in-unit-tests)). |
| The Expo plugin: "… adds its own Notification Service Extension, and an app has only one" | Set `ios.notificationServiceExtension` to `false`, and call SallaPush first in the other extension. |
| The Expo plugin: "the app has both …, and only one FCM service gets the messages" | Set `android.fcmForwarding` to the library that receives FCM in your app. |

## iOS

| You see | Fix |
|---|---|
| No `init.started` at launch, and `isInitialized()` resolves `false` | `SallaPushAppId` is empty: define `SALLAPUSH_APP_ID` for every build configuration, or write the app id in the Info.plist. |
| No `token.received`, or `token.missing` | Add the Push Notifications capability and the AppDelegate's [forwarding methods](../README.md#ios-bare-react-native). If another SDK holds the token, pass it to `forwardApnsToken`. |
| `token.registration_failed` | The message ends with iOS's reason. "not supported in the simulator": use a device, or a simulator with iOS 16 or later on a Mac with Apple silicon or a T2 chip. "no valid "aps-environment" entitlement": add the Push Notifications capability. |
| `init.no_delegate`, or the tap that launched the app never reaches the click listener | Call `SallaPushRN.start()` first in `didFinishLaunchingWithOptions`, and add the click listener in `index.js`. |
| No tap reaches the click listener | A notification-center delegate set after `SallaPushRN.start()` replaced SallaPush's: set yours before it. |
| No images, or no `received` for notifications that arrived in the background | Add the [Notification Service Extension](../README.md#ios-bare-react-native) and the App Group. Images must be https, at most 10 MB. |
| The badge doesn't go up, or always shows 1 | The extension must call SallaPush first, with the same App Group as the app, and the app must have been opened once. |
| `register.ok`, but no notification arrives | Check `getOptedIn()`. Development builds use the APNs sandbox, and TestFlight and App Store builds production. |

## Android

| You see | Fix |
|---|---|
| `token.firebase_missing` | Add your app's `google-services.json` and the Google services Gradle plugin (Expo: `android.googleServicesFile`). |
| `register.ok`, but SallaPush notifications never show (`fcm.forwarding_hint`) | Another FCM service receives the messages: add the [forwarding service](REFERENCE.md#forwarding-fcm-messages). In Expo, with a library the plugin doesn't know, set `android.fcmForwarding` to `none` and add the service through a config plugin of your own. |
| `notif.suppressed` | The message says why: notifications are off, the channel is blocked, or the user opted out. |
| `display.default_icon` | Add a white-on-transparent drawable as `com.salla.push.default_notification_icon` (Expo: `android.smallIcon`). |
| The badge stays after the app opens | Expected: `autoClearBadge` is off by default on Android. Turn it on (`com.salla.push.AUTO_CLEAR_BADGE`, the Expo plugin's `android.autoClearBadge`, or `autoClearBadge` in `initialize`), or call `SallaPush.Notifications.clearAll()`. |
| `badge.channel_badges_on` | The channel existed with badges: create your own with `setShowBadge(false)`, and name it in `com.salla.push.default_channel_id` (Expo: `android.defaultChannelId`). |

## Login, consent and the app id

| You see | Fix |
|---|---|
| `identity.token_needed` | Call `login` at each app launch while the customer is signed in: SallaPush keeps the token in memory only. |
| `login.rejected`, and a `'loginFailure'` event with `tokenRejected` | Pass the raw token, without `Bearer `, and its customer's id (`"42"`). Call `login` again once your app has a current token, never from the `'loginFailure'` listener. |
| Nothing registers: no `register.ok`, and `getId()` stays `null` | Consent is required and not given (`consent.waiting`): call `setConsentGiven(true)` once the user agrees. |
| `init.invalid_app_id`, or `register.dormant` with `unknown_app` | Check the app id: 1 to 64 letters, digits, `_` or `-`. After `register.dormant`, SallaPush tries again after 24 hours. |
| `[SallaPush] initialize ignored …`, or `[SallaPush] setConsentRequired(true) came after …` | SallaPush already started from the static app id: put those settings in the static keys the message names, and drop the call. |

## JavaScript

| You see | Fix |
|---|---|
| `Cannot read property 'Notifications' of undefined`, or "has no default export" | Import by name: `import { SallaPush } from '@salla.sa/mobile-push-react-native'`. |
| `getId()` is `null`, or `getOptedIn()` `false`, right after launch | Read the subscription in its `'change'` listener, which gets the state once the device is registered. |
| A tap's launch URL opens twice | With `openLaunchUrls` on, SallaPush opens it: don't open `result.url` from the click listener. |
| A promise rejects with `E_SALLAPUSH_INTERNAL` | Open an issue, with the message and the SDK version. |

## In unit tests

Jest has no native module: mock the package, with the members your code calls.

<!-- unchecked: an app's Jest test or setup file; list the members your code calls -->
```ts
jest.mock('@salla.sa/mobile-push-react-native', () => ({
  SallaPush: {
    login: jest.fn(),
    logout: jest.fn(),
    User: { addTag: jest.fn() },
    Notifications: {
      requestPermission: jest.fn(async () => false),
      addEventListener: jest.fn(() => ({ remove: jest.fn() })),
    },
  },
}));
```
