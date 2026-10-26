# SallaPush React Native SDK

Push notifications for the React Native and Expo apps of Salla stores. Its TypeScript API calls the native SallaPush
SDKs, and an Expo config plugin does the native setup.

[![npm](https://img.shields.io/npm/v/@salla.sa/mobile-push-react-native?color=004956)](https://www.npmjs.com/package/@salla.sa/mobile-push-react-native) [![Expo config plugin](https://img.shields.io/badge/Expo-config%20plugin-004956?logo=expo&logoColor=white)](#expo) [![License: MIT](https://img.shields.io/github/license/SallaApp/mobile-push-sdk?color=004956)](https://github.com/SallaApp/mobile-push-sdk/blob/master/react-native/LICENSE) [![CI](https://img.shields.io/github/actions/workflow/status/SallaApp/mobile-push-sdk/ci.yml?branch=master&label=CI)](https://github.com/SallaApp/mobile-push-sdk/actions/workflows/ci.yml)

[Quick start](#quick-start) ·
[API reference](https://github.com/SallaApp/mobile-push-sdk/blob/master/react-native/docs/REFERENCE.md) ·
[Troubleshooting](https://github.com/SallaApp/mobile-push-sdk/blob/master/react-native/docs/TROUBLESHOOTING.md) ·
[Example app](#example-app) ·
[Changelog](https://github.com/SallaApp/mobile-push-sdk/blob/master/react-native/CHANGELOG.md)

> **SallaPush is for the mobile apps of Salla stores.** Contact the Salla team for your app id.

- **Version:** 1.0.0. It wraps SallaPush iOS 1.0.4 and SallaPush Android 1.0.4. See
  [CHANGELOG.md](https://github.com/SallaApp/mobile-push-sdk/blob/master/react-native/CHANGELOG.md).
- **Also for:** [iOS](https://github.com/SallaApp/mobile-push-ios-sdk) · [Android](https://github.com/SallaApp/mobile-push-android-sdk) · [Flutter](https://github.com/SallaApp/mobile-push-sdk/tree/master/flutter) · [Capacitor](https://github.com/SallaApp/mobile-push-sdk/tree/master/capacitor)

**Contents:** [Requirements](#requirements) · [Installation](#installation) · [Platform setup](#platform-setup) ·
[Quick start](#quick-start) · [Usage](#usage) · [Other push SDKs](#sallapush-and-other-push-sdks) ·
[Example app](#example-app) · [Troubleshooting](#troubleshooting) · [Support](#support) ·
[Contributing](#contributing) · [License](#license)

## Requirements

| Wrapper | SallaPush iOS | SallaPush Android | Framework | iOS | Android |
|---|---|---|---|---|---|
| React Native 1.0.0 | 1.0.4 | 1.0.4 | React Native 0.81 or later, New Architecture only; Expo SDK 54 or later, in development builds (not Expo Go) | 15.0 (React Native itself needs 15.1), Xcode 16 or later | minSdk 23 (React Native itself needs 24), compileSdk 34 or later, JDK 17 |

You also need a SallaPush app id for iOS and one for Android.

## Installation

```sh
npx expo install @salla.sa/mobile-push-react-native   # an Expo app
npm install @salla.sa/mobile-push-react-native        # a bare React Native app (or: yarn add, pnpm add, bun add)
```

- **Expo:** add the [config plugin](#expo). At prebuild, it adds the SallaPush pods and does the native setup.
- **Android:** nothing to add. Gradle gets SallaPush Android from Maven Central.
- **iOS, in a bare app:** add these lines to `ios/Podfile`, inside your app's target, after `use_native_modules!`, then
  run `pod install`. Without them, `pod install` fails: "Unable to find a specification for SallaPush".

<!-- snippet:example/ios/Podfile#app-pods -->
```ruby
pod 'SallaPushCore', :git => 'https://github.com/SallaApp/mobile-push-ios-sdk.git', :tag => '1.0.4'
pod 'SallaPush', :git => 'https://github.com/SallaApp/mobile-push-ios-sdk.git', :tag => '1.0.4'
```

**From GitHub:** each release's GitHub Release also has the package, as npm serves it:

```sh
npm install https://github.com/SallaApp/mobile-push-sdk/releases/download/react-native-1.0.0/salla.sa-mobile-push-react-native-1.0.0.tgz
```

npm 12 then needs `allow-remote=root` in the app's `.npmrc`.

**Updating:** install the new version the same way. Then run `npx expo prebuild` in an Expo app, or, in a bare app, set
every SallaPush `:tag` in your Podfile, the extension's included, to the [versions table](#requirements)'s SallaPush iOS
version, and run `pod install`.

## Platform setup

In an Expo app, the config plugin does the native setup: follow [Expo](#expo). In a bare app, follow
[iOS](#ios-bare-react-native) and [Android](#android-bare-react-native).

### Expo

**1. Add the config plugin** to your app config, with your app ids, and set `android.googleServicesFile` to your app's
`google-services.json`: Android receives pushes through Firebase Cloud Messaging.

<!-- unchecked: an app.json excerpt; plugin/__tests__ check every option, and scripts/verify.sh consumer prebuilds and builds Expo apps with them -->
```json
{
  "expo": {
    "ios": { "bundleIdentifier": "com.example.shop" },
    "android": { "package": "com.example.shop", "googleServicesFile": "./google-services.json" },
    "plugins": [
      ["@salla.sa/mobile-push-react-native", {
        "ios": { "appId": "00000000-0000-4000-8000-000000000001", "appGroup": "group.com.example.shop" },
        "android": { "appId": "00000000-0000-4000-8000-000000000002", "smallIcon": "./assets/notification-icon.png" }
      }]
    ]
  }
}
```

**2. Build:** run `npx expo prebuild`, then `npx expo run:ios` or `npx expo run:android`, or build with EAS Build.
Expo Go can't load SallaPush's native code: use a development build.

`ios.appGroup` is the App Group that the badge count and `received` need; `android.smallIcon` is the notification icon,
a 96 × 96 white-on-transparent PNG or `@drawable/<name>`. Every option is optional
([plugin options](https://github.com/SallaApp/mobile-push-sdk/blob/master/react-native/docs/REFERENCE.md#expo-plugin-options)).

### iOS (bare React Native)

**1. Capabilities.** In your app target, under **Signing & Capabilities**, add **Push Notifications** and
**Background Modes → Remote notifications**.

**2. The app id,** in the app's Info.plist, from the build setting `SALLAPUSH_APP_ID`, which you define for every build
configuration (in an xcconfig file, or as a user-defined setting): undefined, it is empty, and SallaPush doesn't start.

<!-- snippet:example/ios/SallaPushExample/Info.plist#app-id -->
```xml
<key>SallaPushAppId</key>
<string>$(SALLAPUSH_APP_ID)</string>
```

**3. The AppDelegate.** In `AppDelegate.swift`, add `import SallaPush` and `import SallaPushReactNative`, call
`SallaPushRN.start()` as the first statement of `application(_:didFinishLaunchingWithOptions:)`, and add these methods:

<!-- snippet:example/ios/SallaPushExample/AppDelegate.swift#forwarding -->
```swift
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
  SallaPush.Notifications.didRegisterForRemoteNotifications(deviceToken: deviceToken)
}

func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
  SallaPush.Notifications.didFailToRegisterForRemoteNotifications(error: error)
}

func application(
  _ application: UIApplication,
  didReceiveRemoteNotification userInfo: [AnyHashable: Any],
  fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
) {
  SallaPush.Notifications.didReceiveRemoteNotification(userInfo)
  completionHandler(.noData)
}
```

Only your own `UNUserNotificationCenter.current().delegate` line, if any, goes above `SallaPushRN.start()`: a later
start loses the tap that launched the app, and a delegate set after it replaces SallaPush's.

**4. The Notification Service Extension** shows images, reports `received` and counts the [badge](#badges). Add a
Notification Service Extension target, `SallaPushNotificationService`, with a deployment target no higher than the
app's, and give it these pods at the top level of the Podfile, then run `pod install`:

<!-- snippet:example/ios/Podfile#nse-pods -->
```ruby
target 'SallaPushNotificationService' do
  pod 'SallaPushCore', :git => 'https://github.com/SallaApp/mobile-push-ios-sdk.git', :tag => '1.0.4'
  pod 'SallaPushExtension', :git => 'https://github.com/SallaApp/mobile-push-ios-sdk.git', :tag => '1.0.4'
end
```

Replace its `NotificationService.swift` with:

<!-- snippet:example/ios/SallaPushNotificationService/NotificationService.swift -->
```swift
import SallaPushExtension
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    private var sallaPushService: SallaPushServiceExtension?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        if SallaPushServiceExtension.isSallaPushNotification(request) {
            // Reads the App Group from this extension's Info.plist key SallaPushAppGroup.
            sallaPushService = SallaPushServiceExtension()
            sallaPushService?.didReceive(request, withContentHandler: contentHandler)
            return
        }
        // Not a SallaPush notification: hand it to your other SDKs here, or deliver it unchanged.
        contentHandler(request.content)
    }

    override func serviceExtensionTimeWillExpire() {
        sallaPushService?.serviceExtensionTimeWillExpire()
    }
}
```

`didReceive` returns `false` and doesn't handle the notification when it isn't a SallaPush notification.

**5. An App Group,** which the badge count and `received` need: the same group in both targets' App Groups capability,
and `SallaPushAppGroup`, set to `$(SALLAPUSH_APP_GROUP)`, in both Info.plist files, with the setting defined for both
targets like `SALLAPUSH_APP_ID`.

### Android (bare React Native)

**1. Firebase.** Android receives pushes through Firebase Cloud Messaging: put your app's `google-services.json` in
`android/app`, and apply the Google services Gradle plugin, unless your app already does: this line inside
`buildscript { dependencies { … } }` of `android/build.gradle`, and `apply plugin: "com.google.gms.google-services"` at
the top of `android/app/build.gradle`.

<!-- snippet:example/android/build.gradle#google-services -->
```groovy
classpath("com.google.gms:google-services:4.5.0")
```

**2. The app id and the notification icon,** inside `<application>` in `android/app/src/main/AndroidManifest.xml`,
with `manifestPlaceholders["sallaPushAppId"] = "<your app id>"` in `defaultConfig` of `android/app/build.gradle`. Use
your own icon, white on transparent:

<!-- snippet:example/android/app/src/main/AndroidManifest.xml#meta-data -->
```xml
<meta-data android:name="com.salla.push.APP_ID" android:value="${sallaPushAppId}" />
<meta-data
  android:name="com.salla.push.default_notification_icon"
  android:resource="@drawable/ic_stat_sallapush" />
```

**3. Another FCM library** in the app takes every FCM message, and SallaPush shows nothing: add a
[forwarding service](https://github.com/SallaApp/mobile-push-sdk/blob/master/react-native/docs/REFERENCE.md#forwarding-fcm-messages).

## Quick start

In `index.js`, before `AppRegistry.registerComponent`, import `{ SallaPush }` from
`'@salla.sa/mobile-push-react-native'` (the package has named exports only), and listen for taps there, so that the tap
that launched the app arrives too. In an Expo app, this goes in the file that `main` names, before
`registerRootComponent(App)`; with Expo Router, in a module that your own entry file imports before `expo-router/entry`.
`route` stands for your app's navigation.

<!-- snippet:example/src/start.ts#click-listener -->
```ts
SallaPush.Notifications.addEventListener('click', (event) => {
  route(event.notification);
});
```

Then ask for permission where it fits, in an async function such as a button's handler, with
`await SallaPush.Notifications.requestPermission(true)`. SallaPush never shows the system prompt on its own.

With the static app id, SallaPush starts natively at launch. An app that knows its app id only at run time calls
`SallaPush.initialize(appId)` instead
([initialize](https://github.com/SallaApp/mobile-push-sdk/blob/master/react-native/docs/REFERENCE.md#sallapush)).

**Check that it works:** with the [log level](#logging) at `verbose` in a debug build, run the app on a device and allow
notifications. The logs, in Xcode's console filtered on `SallaPush` or in `adb logcat -s SallaPush`, show `init.started`,
then `token.received` and `register.ok` once the device is registered, and `getPermission()` resolves `true`.

## Usage

### Login and logout

Call `login` with the customer's id as Salla knows it, such as `"42"`, and the customer token your app received at
sign-in, without a `Bearer ` prefix. Call it at each app launch too, while the customer is signed in, and `logout()`
while nobody is: on iOS, a reinstall keeps the earlier install's customer linked until then.

<!-- snippet:example/src/session.ts#login-logout -->
```ts
// After the customer signs in:
SallaPush.login(externalId, identityToken);
// After the customer signs out:
SallaPush.logout();
```

### Notification permission

`requestPermission(true)` shows the prompt, and opens the app's notification settings once the prompt no longer shows.
`getPermission()`, `canRequestPermission()` and a `'permissionChange'` listener follow the state; on iOS,
`registerForProvisionalAuthorization()` asks for quiet notifications, without a prompt.

### Notification taps and deep links

The click listener gets every tap on a SallaPush notification: `event.notification`, the launch URL in
`event.result.url`, and on iOS the tapped action button in `event.result.actionId`. Route with the typed getters,
`getString`, `getInt` and `getBool`, as the example's
[route](https://github.com/SallaApp/mobile-push-sdk/blob/master/react-native/example/src/start.ts) does, not with raw
payload keys.

- **Cold starts:** the tap that launched the app can arrive before your navigation is ready: keep the destination, and
  open it in React Navigation's `onReady`, or from an effect in Expo Router's root layout.
- **Launch URLs:** SallaPush opens https launch URLs itself only with `openLaunchUrls` on; your click listener then
  mustn't open `result.url` again.
- **Other events:** login changes and refused logins (`SallaPush.User`'s `'change'` and `'loginFailure'`), and
  subscription changes
  ([Events](https://github.com/SallaApp/mobile-push-sdk/blob/master/react-native/docs/REFERENCE.md#events)). A
  subscription's `remove()` stops its listener.

### Foreground notifications

Without a `'foregroundWillDisplay'` listener, SallaPush shows its notifications in the foreground itself. A listener
can hold one back with `event.preventDefault()`, called before any `await`, and show it later, once, within 10 minutes,
with `event.notification.display()`. On iOS, a notification shown while a listener exists is SallaPush's local copy,
without its image and action buttons: listen only on screens that decide per notification, such as a chat
([example](https://github.com/SallaApp/mobile-push-sdk/blob/master/react-native/docs/REFERENCE.md#foreground-display)).

### Tags and language

`SallaPush.User.addTag('cart_items', '3')` and `addTags({ … })` set tags, `removeTag` and `removeTags` remove them, and
`getTags()` resolves them. Keys are lowercased, at most 64 characters of `a-z`, `0-9` and `_`; values are cut at 255
characters; a device holds at most 100 tags. A logout and an account switch delete the device's tags
(`clearTagsOnLogout`): set tags after `login`. `SallaPush.User.setLanguage(code)` sets the customer's language, such as
`ar`; `null` means the device language.

### Push subscription

`SallaPush.User.pushSubscription.optOut()` turns SallaPush notifications off on this device, and `optIn()` back on,
with the permission prompt while it can still show. A `'change'` listener gets `{ previous, current }` once the device
is registered, then each change: read the state there, not from the getters right after a cold start. The push token
is private: don't send it to analytics.

### Consent

If your app needs the user's consent first (PDPL), require it at every launch: with the static app id, set
`SallaPushRequiresUserConsent` to `YES` and `com.salla.push.REQUIRES_USER_CONSENT` to `true` (Expo: `requiresUserConsent`
in `ios` and `android`); with `initialize`, call `SallaPush.setConsentRequired(true)` before it. Pass the user's choice
to `SallaPush.setConsentGiven(…)`: until then, SallaPush sends nothing, and withdrawing consent opts the device out,
deletes its tags and unlinks it.

### Logging

The default level is `warn`: `SallaPush.Debug.setLogLevel(…)` changes it, as `SallaPushLogLevel` (Info.plist),
`com.salla.push.LOG_LEVEL` (manifest) and the Expo plugin's `logLevel` do. `SallaPush.Debug.setLogHandler(…)` forwards
entries to your telemetry
([Debug](https://github.com/SallaApp/mobile-push-sdk/blob/master/react-native/docs/REFERENCE.md#sallapushdebug)). Every
entry has a stable `code`, which the native docs list
([iOS](https://github.com/SallaApp/mobile-push-ios-sdk/blob/1.0.4/docs/LOGGING.md#log-code-reference),
[Android](https://github.com/SallaApp/mobile-push-android-sdk/blob/1.0.4/docs/LOGGING.md#log-code-reference)): match on
it, not on the message. SallaPush never logs secrets or identity tokens; keep the level at `warn` in release builds.

### Badges

The app icon's badge shows SallaPush's notifications. On iOS, each one adds 1, which needs the extension and the App
Group, and the badge goes back to 0 when the app opens. On Android, the launcher counts the notifications in the shade,
so the badge drops when they are opened, swiped away or removed with `clearAll()`; by default, opening the app
removes nothing. `SallaPush.Notifications.clearAll()` removes SallaPush's notifications, and on iOS sets the badge to 0
while `autoUpdateBadge` is on (on iOS 15, only when no other SDK's notification is delivered).

| Setting | Info.plist | Manifest meta-data | Default |
|---|---|---|---|
| `autoClearBadge`: clear the badge when the app opens | `SallaPushAutoClearBadge` | `com.salla.push.AUTO_CLEAR_BADGE` | `true` on iOS, `false` on Android |
| `autoUpdateBadge`: count SallaPush notifications | `SallaPushAutoUpdateBadge` | `com.salla.push.AUTO_UPDATE_BADGE` | `true` |

Set the keys with the static app id, or the Expo plugin's `ios` and `android` options of the same names, such as
`"android": { "autoClearBadge": true }`. With `initialize`, pass them there, as `{ autoClearBadge: true }`: a setting
given applies to both platforms, and one left out keeps each platform's default. On Android, `autoClearBadge` removes
SallaPush's notifications from the shade when the app comes to the foreground
([Badges](https://github.com/SallaApp/mobile-push-sdk/blob/master/react-native/docs/REFERENCE.md#badges)).

## SallaPush and other push SDKs

SallaPush never swizzles, and handles only its own notifications: for any other, its calls return `false` and do
nothing, so other push SDKs keep working beside it, and handing SallaPush their notifications is always safe.

- **iOS:** SallaPush keeps the notification-center delegate set before `SallaPushRN.start()`, and hands it every
  notification and tap that isn't SallaPush's. In a Notification Service Extension that another SDK shares, call
  SallaPush first. When another SDK takes the APNs token, also pass it to `SallaPush.Notifications.forwardApnsToken` in
  JavaScript, as hexadecimal text.
- **Android:** each FCM message goes to one service, so with another FCM library, a service of the app hands each
  message to SallaPush first
  ([forwarding service](https://github.com/SallaApp/mobile-push-sdk/blob/master/react-native/docs/REFERENCE.md#forwarding-fcm-messages)).
  The Expo plugin generates it for the libraries it knows (`android.fcmForwarding`).
- **JavaScript:** another library's message handlers get SallaPush's messages too: skip each one for which
  `await SallaPush.Notifications.isSallaPushNotification(message.data)` is `true`.

## Example app

[example](https://github.com/SallaApp/mobile-push-sdk/tree/master/react-native/example) is a bare React Native 0.87 app
with the quick start, the bare iOS and Android setup, and a screen that makes every API call and logs every event. Set
your app ids as [its README](https://github.com/SallaApp/mobile-push-sdk/blob/master/react-native/example/README.md)
says, then run `yarn install`, `yarn example start` and `yarn example ios` (or `android`) in the `react-native` folder.

## Troubleshooting

| Problem or log code | Fix |
|---|---|
| `TurboModuleRegistry.getEnforcing(...): 'RNSallaPush' could not be found` | Rebuild the app after installing the package; on iOS run `pod install` first. Expo Go can't run SallaPush: use a development build. |
| `token.firebase_missing`, or no notification on Android | Add your app's `google-services.json` (Expo: `android.googleServicesFile`), and with another FCM library, the [forwarding service](https://github.com/SallaApp/mobile-push-sdk/blob/master/react-native/docs/REFERENCE.md#forwarding-fcm-messages). |
| The tap that launched the app never reaches the click listener | Call `SallaPushRN.start()` first in `didFinishLaunchingWithOptions`, and add the click listener in `index.js` ([Quick start](#quick-start)). |

[docs/TROUBLESHOOTING.md](https://github.com/SallaApp/mobile-push-sdk/blob/master/react-native/docs/TROUBLESHOOTING.md)
has more.

## Support

- **SDK bugs and feature requests:**
  [open an issue](https://github.com/SallaApp/mobile-push-sdk/issues/new/choose) with the SDK, React
  Native, Expo and OS versions and the SallaPush log codes you saw. Never paste tokens, keys or customer data.
- **App ids:** Contact the Salla team for your app id.

## Contributing

Pull requests are welcome. Read
[CONTRIBUTING.md](https://github.com/SallaApp/mobile-push-sdk/blob/master/react-native/CONTRIBUTING.md) first. Everyone
taking part follows the
[Code of Conduct](https://github.com/SallaApp/mobile-push-sdk/blob/master/react-native/CODE_OF_CONDUCT.md).

## License

The SallaPush React Native SDK is available under the
[MIT License](https://github.com/SallaApp/mobile-push-sdk/blob/master/react-native/LICENSE).
