# mobile_push example

A Flutter app that shows every part of `mobile_push` on iOS and Android:

- **Status:** whether SallaPush runs, its app id and native SDK version, the push subscription (device id, opt-in,
  the last 6 characters of the token), the permission (and its iOS status), the logged-in customer and the tags.
  It is read again after each event and with the refresh button. Without an app id, a "Not configured" banner says
  so.
- **Actions:** log in and out, tags and language, opt in and out, the permission request (with the fallback to the
  settings), provisional authorization and remote-notification registration (iOS), refreshing the permission,
  clearing the notifications, removing one by its id (Android), consent, and the console and event-log levels.
- **Foreground notifications:** _Off_ registers no will-display listener, so SallaPush shows each notification as
  it was sent. _Show_ listens and lets each one show; on iOS that is SallaPush's local copy, without the image or
  the action buttons. _Hold_ keeps each one hidden, with a Display button that shows it, once, within 10 minutes.
- **Events:** taps, foreground notifications, permission, user and push subscription changes, refused logins, and
  SallaPush's log entries at the chosen level.

The app's native setup is the one the SDK's README and [setup guide](../docs/SETUP.md) describe: the
`SallaPushFlutter.start()` line in `ios/Runner/AppDelegate.swift`, the Info.plist keys, the push entitlement and the
remote-notification background mode, the `SallaPushNotificationService` Notification Service Extension, and the
Android meta-data and notification icon.

## Before you run it

Contact the Salla team for your app id. Without an app id, the app still runs and shows the "Not configured" banner.

### iOS

Copy `ios/Flutter/SallaPush.xcconfig.example` to `ios/Flutter/SallaPush.xcconfig`, which git ignores, and set:

| Setting | Value |
|---|---|
| `SALLAPUSH_APP_ID` | the app id, for example `00000000-0000-4000-8000-000000000001` |
| `SALLAPUSH_EXAMPLE_BUNDLE_ID` | the app's bundle id; the extension's is this one plus `.SallaPushNotificationService` |
| `DEVELOPMENT_TEAM` | your Apple team, for runs on a device |
| `SALLAPUSH_APP_GROUP` | optional, see below |

Notifications with images need a device: the simulator never runs the Notification Service Extension.

**App Group (optional).** It lets the extension count SallaPush notifications on the app icon's badge. Set
`SALLAPUSH_APP_GROUP` to the group, then in Xcode add the App Groups capability with that group to the `Runner` and
`SallaPushNotificationService` targets. Keep those entitlement changes local: the committed entitlements have no
group, since an empty one breaks device signing.

### Android

Set these Gradle properties in `android/sallapush.properties`, which git ignores, in `~/.gradle/gradle.properties`,
or as `ORG_GRADLE_PROJECT_<name>` environment variables:

| Property | Value |
|---|---|
| `sallapushAppId` | the app id, for example `00000000-0000-4000-8000-000000000002` |
| `sallapushApplicationId` | optional: the application id; default `sa.salla.sallapush.flutter.example` |

Put the app's `google-services.json` in `android/app/`, where git ignores it. Without it the app still builds, and
SallaPush logs `token.firebase_missing`: there is no push token.

## Run

```sh
flutter run
```

The example keeps its customer session in memory, so a login on the screen lasts until the app ends. To start
signed in, as an app does at every launch, pass the customer:

```sh
flutter run --dart-define=SALLAPUSH_CUSTOMER_ID=<customer id> --dart-define=SALLAPUSH_CUSTOMER_TOKEN=<identity token>
```

`flutter test` runs the widget tests, which fake the native side on the plugin's channels.

## What's example code only

- `lib/readme_snippets/` holds the Dart snippets of the README and the setup guide that the app never runs: the
  quick start's click listener and permission request, login and logout, routing with the typed getters, tags, the
  push subscription listener, a chat screen's foreground listener, the log handler, the launching tap and
  initializing from Dart. `ios/Runner/ReadmeSnippets.swift` and `android/app/src/main/kotlin/…/ReadmeSnippets.kt` do
  the same for their native code: the `AppDelegate` methods and the messaging service for other push SDKs.
- The extension's build configurations are based on the app's `Flutter/Debug.xcconfig` and `Release.xcconfig`, for
  the example's own settings of `SallaPush.xcconfig`. An app bases its extension on `Flutter/Generated.xcconfig`
  instead ([Setup guide](../docs/SETUP.md#ios-notification-service-extension)): once an app has a Podfile, its files
  bring the app's pods along.
- `ios/Runner/TestHooks.swift` and the method channel in `MainActivity.kt` are for this repository's own tests. The
  README's `AppDelegate` snippet leaves out the line that registers the iOS one. An app never needs them.
