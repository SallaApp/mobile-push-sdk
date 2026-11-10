# SallaPush Flutter SDK

Push notifications for the Flutter apps of Salla stores.

[![pub package](https://img.shields.io/pub/v/mobile_push?color=004956)](https://pub.dev/packages/mobile_push) [![pub points](https://img.shields.io/pub/points/mobile_push?color=004956)](https://pub.dev/packages/mobile_push/score) [![License: MIT](https://img.shields.io/github/license/SallaApp/mobile-push-sdk?color=004956)](LICENSE) [![CI](https://img.shields.io/github/actions/workflow/status/SallaApp/mobile-push-sdk/ci.yml?branch=master&label=CI)](https://github.com/SallaApp/mobile-push-sdk/actions/workflows/ci.yml)

> **SallaPush is for the mobile apps of Salla stores.** Contact the Salla team for your app id.

- **Also for:** [iOS](https://github.com/SallaApp/mobile-push-ios-sdk) ·
  [Android](https://github.com/SallaApp/mobile-push-android-sdk) ·
  [React Native](https://github.com/SallaApp/mobile-push-sdk/tree/master/react-native) ·
  [Capacitor](https://github.com/SallaApp/mobile-push-sdk/tree/master/capacitor)

**Contents:** [Requirements](#requirements) · [Installation](#installation) · [Platform setup](#platform-setup) ·
[Quick start](#quick-start) · [Usage](#usage) · [Other push SDKs](#sallapush-and-other-push-sdks) ·
[Troubleshooting](#troubleshooting) · [Setup guide](docs/SETUP.md) · [API reference](docs/REFERENCE.md)

## Requirements

| Wrapper | SallaPush iOS | SallaPush Android | Framework | iOS | Android |
|---|---|---|---|---|---|
| Flutter 1.1.0 | 1.0.4 | 1.1.0 | Flutter 3.44 or later, Dart 3.12 or later | 15.0, Xcode 16 or later | minSdk 23, compileSdk 34 or later, JDK 17 |

- A SallaPush app id for iOS and one for Android. SallaPush runs on iOS, and on Android with Google Play services.

## Installation

<!-- unchecked: pub's own command; scripts/verify.sh consumer installs HEAD from git in its place -->
```bash
flutter pub add mobile_push
```

- **iOS:** Flutter integrates the plugin with Swift Package Manager, its default since 3.44, which brings SallaPush
  iOS: add nothing, and never add the SallaPush pods, which would link SallaPush twice. Apps that turn Swift Package
  Manager off for the whole project add the pods ([CocoaPods mode](docs/SETUP.md#ios-cocoapods-mode)).
- **Android:** the plugin brings SallaPush Android from Maven Central, which Flutter apps already use: add nothing.
- **From git,** as a fallback, a dependency on a release tag works over HTTPS:

  <!-- unchecked: a git dependency on a release tag; scripts/verify.sh consumer installs HEAD from git the same way -->
  ```yaml
  dependencies:
    mobile_push:
      git:
        url: https://github.com/SallaApp/mobile-push-sdk.git
        path: flutter
        ref: flutter-1.1.0
  ```

Commit `pubspec.lock`, and update with `flutter pub upgrade mobile_push`. When a release pins another SallaPush
iOS version, also move the Podfile's tags in CocoaPods mode, and the version rule of the extension's package.

## Platform setup

### iOS

**1. Deployment target and capabilities.** The `Runner` project needs iOS 15.0 or later: apps created with Flutter
3.44 to 3.46 start at 13.0. In the `Runner` target, under **Signing & Capabilities**, add **Push Notifications** and
**Background Modes → Remote notifications**.

**2. The app id,** in the `SallaPushAppId` key of `ios/Runner/Info.plist`, from a build setting:

<!-- snippet:example/ios/Runner/Info.plist#app-id -->
```xml
<key>SallaPushAppId</key>
<string>$(SALLAPUSH_APP_ID)</string>
```

Define it in `ios/Flutter/Debug.xcconfig` and `Release.xcconfig`, or for each flavor. An undefined setting leaves the
key empty, and SallaPush then doesn't start at launch:

<!-- snippet:docs/snippets/app-id.xcconfig -->
```text
SALLAPUSH_APP_ID = 00000000-0000-4000-8000-000000000001
```

**3. The AppDelegate.** `SallaPushFlutter.start()` comes first in `application(_:didFinishLaunchingWithOptions:)`, as
in the example's `AppDelegate.swift`, Flutter 3.47's template with that line:

<!-- snippet:example/ios/Runner/AppDelegate.swift#appdelegate -->
```swift
import Flutter
import UIKit
import mobile_push

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    SallaPushFlutter.start()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
```

It starts SallaPush and hands it the push calls. Never set another `UNUserNotificationCenter` delegate after it, unless
that one hands the calls on. An older `AppDelegate` keeps it before `GeneratedPluginRegistrant.register(with: self)`.

**4. The Notification Service Extension,** recommended: it shows images and counts the [badge](#badges). Add a
Notification Service Extension target, `SallaPushNotificationService`, that links `SallaPushExtension`, never
`SallaPush`, with the example's
[NotificationService.swift](example/ios/SallaPushNotificationService/NotificationService.swift). In the `Runner`
target's **Build Phases**, drag **Embed Foundation Extensions** above **Thin Binary**, or every build fails with
`Cycle inside Runner`. Give both targets the same App Group, in the **App Groups** capability and in their
`SallaPushAppGroup` Info.plist key ([all the steps](docs/SETUP.md#ios-notification-service-extension)).

### Android

**1. Firebase.** SallaPush receives its notifications through Firebase Cloud Messaging: put your app's
`google-services.json` in `android/app/`, apply the Google services Gradle plugin, and leave Firebase's auto-init on
([Firebase](docs/SETUP.md#android-firebase)).

**2. The app id and the notification icon,** inside `<application>` in `android/app/src/main/AndroidManifest.xml`:

<!-- snippet:example/android/app/src/main/AndroidManifest.xml#meta-data -->
```xml
<meta-data android:name="com.salla.push.APP_ID" android:value="${sallaPushAppId}" />
<meta-data android:name="com.salla.push.default_notification_icon" android:resource="@drawable/ic_stat_sallapush" />
```

The placeholder gets its value in `defaultConfig` of `android/app/build.gradle.kts` (in Groovy, with `+=`: `=` would
replace Flutter's own placeholder):

<!-- snippet:docs/snippets/build.gradle.kts#app-id -->
```kotlin
manifestPlaceholders["sallaPushAppId"] = "00000000-0000-4000-8000-000000000002"
```

The small icon, white on transparent, goes in `android/app/src/main/res/drawable/`, such as the example's
[ic_stat_sallapush.xml](example/android/app/src/main/res/drawable/ic_stat_sallapush.xml).

## Quick start

With the app id keys and `SallaPushFlutter.start()`, SallaPush starts at launch: Dart needs no init call.

The Dart API comes from one import:

<!-- snippet:example/lib/readme_snippets/app_snippets.dart#import -->
```dart
import 'package:mobile_push/mobile_push.dart';
```

**1. Listen for taps** in `main()`, before `runApp`, so that the tap that launched the app reaches you too. `route` is
your [navigation](#notification-taps-and-deep-links):

<!-- snippet:example/lib/readme_snippets/app_snippets.dart#click-listener -->
```dart
SallaPush.notifications.onClick.listen(
  (SallaPushClickEvent event) => route(event.notification),
);
```

That tap arrives before the first frame: route it once your router exists, as
[the tap that launched the app](docs/SETUP.md#the-tap-that-launched-the-app) shows.

**2. Ask for permission** from a screen, where it fits your app. SallaPush never shows the system prompt on its own:

<!-- snippet:example/lib/readme_snippets/app_snippets.dart#request-permission -->
```dart
final bool granted = await SallaPush.notifications.requestPermission(
  fallbackToSettings: true,
);
```

An app that knows its app id only at run time leaves the app id keys out, and calls `SallaPush.initialize(appId)`
first ([Initializing from Dart](docs/SETUP.md#initializing-from-dart)).

**Verify it works.** In debug builds only, set the log level to `verbose`: the meta-data `com.salla.push.LOG_LEVEL`
in `android/app/src/debug/AndroidManifest.xml`, and on iOS the Info.plist key `SallaPushLogLevel` =
`$(SALLAPUSH_LOG_LEVEL)`, with `SALLAPUSH_LOG_LEVEL = verbose` in `ios/Flutter/Debug.xcconfig` only. Run the app on a
device, and filter the console on `SallaPush`: expect `init.started`, then `token.received` and `register.ok` at the
first launch (a reinstalled iOS app keeps its registration, and logs no `register.ok`), and `login.ok` after a
[login](#login-and-logout). A `[SallaPush]` error names a setup problem.

## Usage

Every call returns a `Future`, and every event comes on a broadcast `Stream`
([API reference](docs/REFERENCE.md)).

### Login and logout

<!-- snippet:example/lib/readme_snippets/app_snippets.dart#login-logout -->
```dart
Future<void> customerDidSignIn(String customerId, String customerToken) async {
  await SallaPush.login(externalId: customerId, identityToken: customerToken);
}

Future<void> customerDidSignOut() async {
  await SallaPush.logout();
}
```

At each app launch, before any tag call, call `login` while the customer is signed in, or `logout()` while nobody is
signed in: on iOS, after a reinstall, the logout unlinks the customer of the earlier install.

### Notification permission

`requestPermission` completes with whether notifications are allowed, and `fallbackToSettings: true` opens the app's
settings once the prompt no longer shows. Android shows the prompt only on Android 13 and later, with the app in the
foreground. `permission` is the current answer, and `onPermissionChange` reports changes.

### Notification taps and deep links

`onClick` gets every tap on a SallaPush notification: `event.notification`, and `event.result` with the launch URL,
`url`, and on iOS the tapped action button, `actionId`. Route with the typed getters, which read numbers and text
alike:

<!-- snippet:example/lib/readme_snippets/app_snippets.dart#route -->
```dart
void route(SallaPushNotification notification) {
  final int? productId = notification.getString('type') == 'product'
      ? notification.getInt('id')
      : null;
  final String? url = notification.launchUrl;
  if (productId != null) {
    router.showProduct(productId);
  } else if (url != null) {
    router.openUrl(url);
  }
}
```

- **Taps before the first listener** wait, up to 10, for 5 minutes.
- **Launch URLs** open natively only with `SallaPushOpenLaunchURLs`, `com.salla.push.OPEN_LAUNCH_URLS` or
  `SallaPushConfig.openLaunchUrls`, and only https ones; then `route` opens only the others. A launch URL is whatever
  the sender set: check its host before you open it.

### Foreground notifications

Without an `onWillDisplay` listener, SallaPush shows its notifications in the foreground. A listener decides for each
one, and `cancel()` hands the decision back to SallaPush:

<!-- snippet:example/lib/readme_snippets/app_snippets.dart#chat-listener -->
```dart
// While a chat screen shows, its chat's notifications stay hidden.
final chatListener = SallaPush.notifications.onWillDisplay.listen((event) {
  if (event.notification.getString('chat_id') == chatId) {
    event.preventDefault(); // Before any await.
  }
});
// When the chat screen goes:
await chatListener.cancel();
```

Use `listen()`, not `await for`; `event.notification.display()` shows a held notification later, once, within 10
minutes. On iOS, a notification shown while a listener exists is SallaPush's local copy, without its image and action
buttons: listen only where a screen decides.

### Tags and language

<!-- snippet:example/lib/readme_snippets/app_snippets.dart#tags -->
```dart
await SallaPush.user.addTags(<String, String>{
  'cart_items': '$items',
  'total_cart_amount': '$total',
});
```

- `addTag` adds one tag, `removeTag` and `removeTags` remove tags, and `getTags()` reads them. Keys are lowercased,
  then 1 to 64 characters of `a-z`, `0-9` and `_`; values are cut at 255 characters; a device holds at most 100 tags.
- A logout and an account switch delete the device's tags (`clearTagsOnLogout`): set tags after `login`.
- `SallaPush.user.setLanguage('ar')` sets the customer's language; `null` means the device's.

### Push subscription

`SallaPush.user.pushSubscription.optOut()` turns SallaPush notifications off on this device, and `optIn()` turns them
back on, with the permission prompt while it can still show. A listener gets the device id and the opted-in state once
the device is registered, then every change:

<!-- snippet:example/lib/readme_snippets/app_snippets.dart#subscription-listener -->
```dart
SallaPush.user.pushSubscription.onChange.listen((state) {
  settings.showDevice(state.current.id, optedIn: state.current.optedIn);
});
```

Read the state there: right after launch, the getters show only this launch's calls. Don't send
`pushSubscription.token` to analytics or third parties.

### Consent

If your app needs the user's consent first, set the Info.plist key `SallaPushRequiresUserConsent` to `YES` and the
meta-data `com.salla.push.REQUIRES_USER_CONSENT` to `true`; an app that calls `initialize` calls
`SallaPush.setConsentRequired(true)` before it instead. Then pass each answer to `SallaPush.setConsentGiven(…)`. Until
consent is given, SallaPush sends nothing; withdrawing it opts the device out, deletes its tags and unlinks the
customer.

### Logging

The default level is `warn`, and `SallaPush.debug.setLogLevel(SallaPushLogLevel.verbose)` changes it from Dart. A log
handler forwards entries to your telemetry:

<!-- snippet:example/lib/readme_snippets/app_snippets.dart#log-handler -->
```dart
await SallaPush.debug.setLogHandler(SallaPushLogLevel.error, (entry) {
  telemetry.report('sallapush', entry.code, entry.message, entry.metadata);
});
```

Every entry has a stable `code`: match on it, not on the message ([log codes](docs/REFERENCE.md#log-codes)). Keep the
console level at `warn` in release builds, and don't forward info entries to third parties.

### Badges

- **iOS:** each SallaPush notification adds 1 to the app icon's badge, and the badge goes back to 0 when the app
  opens. Counting needs the [Notification Service Extension](#ios) and the App Group.
- **Android:** the launcher counts the notifications in the shade, so the badge drops as SallaPush's notifications
  are opened or swiped away. Opening the app removes nothing by default.
- `SallaPush.notifications.clearAll()` removes SallaPush's notifications, and on iOS, while `autoUpdateBadge` is on,
  sets the badge to 0 (on iOS 15, only when no other SDK's notification is delivered).

Two settings change this: these keys, or `SallaPushConfig` in an app that calls `initialize`, where a value applies to
both platforms. Unset, each platform keeps its default:

| Setting | Info.plist | Manifest meta-data | Default |
|---|---|---|---|
| `autoClearBadge`: clear the badge when the app opens | `SallaPushAutoClearBadge` | `com.salla.push.AUTO_CLEAR_BADGE` | `true` on iOS, `false` on Android |
| `autoUpdateBadge`: count SallaPush notifications | `SallaPushAutoUpdateBadge` | `com.salla.push.AUTO_UPDATE_BADGE` | `true` |

On Android, `autoClearBadge` removes SallaPush's notifications from the shade when the app comes to the foreground.
`autoUpdateBadge: false` stops the count, and on iOS a push's own badge applies.

## SallaPush and other push SDKs

SallaPush never swizzles, and handles only its own notifications: its calls return `nil` or `false` for the others, so
the order in which your app hands notifications on doesn't matter to SallaPush. Only code that takes every
notification, SallaPush's too, comes after it.

- **iOS:** when another plugin also handles notifications, add three methods to your `AppDelegate`. They answer
  SallaPush before `super`, which hands every notification to the other plugins. When another SDK takes the APNs
  token, pass it to `SallaPush.notifications.forwardApnsToken`, as hexadecimal text.
- **Android:** Android hands each push message to one service only: when another library also receives them, add a
  service of your own that hands each message and token to SallaPush too.
- **A shared Notification Service Extension** calls SallaPush first.

[Other push SDKs](docs/SETUP.md#other-push-sdks) has the code.

## Example app

[example](example) shows every part of the plugin: SallaPush's status, every action, the foreground modes and an event
log. Set your app ids as [example/README.md](example/README.md) says, then run `flutter run` in `example/`.

## Troubleshooting

| Problem or log code | Fix |
|---|---|
| `pod install`: `Unable to find a specification for SallaPush`, or duplicate SallaPush classes | In CocoaPods mode, add the [Podfile lines](docs/SETUP.md#ios-cocoapods-mode). With Swift Package Manager on, remove the SallaPush pods. |
| No `init.started` on iOS | Define `SALLAPUSH_APP_ID` for every build configuration: an undefined setting leaves `SallaPushAppId` empty. |
| The tap that launched the app never reaches `onClick` | Call `SallaPushFlutter.start()` first in `didFinishLaunchingWithOptions`, and listen before `runApp`. |
| `token.firebase_missing`, `fcm.forwarding_hint`, or no notification on Android | Add `google-services.json` and the Google services plugin; with another push library, add the [service](docs/SETUP.md#other-push-sdks). |
| `login.rejected` | Pass the customer's current token, without a `Bearer ` prefix, and their id as `externalId`. |

[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) has the rest.

## Support

- **SDK bugs and feature requests:**
  [open an issue](https://github.com/SallaApp/mobile-push-sdk/issues/new/choose) with the SDK, Flutter and OS
  versions and the SallaPush log codes you saw. Never paste tokens, keys or customer data.
- **App ids:** Contact the Salla team for your app id.

## Contributing

Pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) first. Everyone taking part follows the
[Code of Conduct](CODE_OF_CONDUCT.md).

## License

The SallaPush Flutter SDK is available under the [MIT License](LICENSE).
