# SallaPush example

A bare React Native 0.87 app (New Architecture) that runs `@salla.sa/mobile-push-react-native` from this repository. It
shows SallaPush's state on the device, makes every API call, decides about foreground notifications, and logs every
event.

## What it shows

- **Status:** whether SallaPush started, and with which app id; the device id, whether it is opted in, and the last 6
  characters of the push token, which is private; the permission, with iOS's status; the customer; the tags; the
  console log level. The status is read again after every event and with Refresh. Without an app id, a "Not
  configured" banner says so.
- **Actions:** log in with an external id and an identity token, and log out; add and remove a tag; set the language;
  opt in and out; request the permission, optionally opening the settings after a denial; ask for provisional
  authorization and register for remote notifications (iOS); refresh the permission; clear the delivered notifications,
  or remove one by its id (Android); the consent switches; the log level. Each call is written to the event log.
- **Foreground notifications:**
  - Off: no listener, so SallaPush shows the original itself.
  - Show: a listener that doesn't prevent. On iOS the notification is then shown as SallaPush's local copy, without the
    image, action buttons or interruption level.
  - Hold: a listener that prevents, and a Display button for each notification it held (within 10 minutes).
- **Event log:** taps, with their URL and action id, and where they route; foreground decisions; permission, customer
  and subscription changes; login failures; SallaPush's log entries at the chosen level.

The code of the README and the docs comes from here:

- `index.js` adds the click listener of `src/start.ts` at app start, and the Customer section signs in and out with
  `src/session.ts`.
- `src/readmeSnippets/` holds the docs' other snippets. They compile against stand-in types (`yarn typecheck` checks
  them) and never run.

## Configure it

SallaPush starts natively at launch, from the app id in the app's static configuration, one for each platform.
Contact the Salla team for your app id. Every file below is ignored by git.

### iOS

Copy `ios/Config/SallaPush.local.xcconfig.example` to `ios/Config/SallaPush.local.xcconfig` and set:

| Setting | Value |
|---|---|
| `SALLAPUSH_APP_ID` | your iOS app id |
| `SALLAPUSH_EXAMPLE_BUNDLE_ID` | your app's bundle id; the Notification Service Extension's is `<bundle id>.SallaPushNotificationService` |
| `DEVELOPMENT_TEAM` | your Apple team, to run on a device |
| `SALLAPUSH_APP_GROUP` | optional: an App Group for the app and the extension |

With an App Group, also add the App Groups capability with that group to the SallaPushExample and
SallaPushNotificationService targets in Xcode, and keep that change local: the committed entitlements have no group,
since an empty one breaks device signing.

The Podfile installs SallaPush from `SallaApp/mobile-push-ios-sdk` with git, over HTTPS.

### Android

Set these Gradle properties in `android/sallapush.properties`, or in `~/.gradle/gradle.properties`,
`ORG_GRADLE_PROJECT_<name>` or `-P<name>=`, which win over the file:

| Property | Value |
|---|---|
| `sallapushAppId` | your Android app id |
| `sallapushApplicationId` | your app's application id (default `sa.salla.sallapush.example`) |

Put your app's `google-services.json` in `android/app/`. Without it the app still builds, and SallaPush
logs `token.firebase_missing`. Gradle downloads the SallaPush Android SDK from Maven Central.

## Run it

From the `react-native` folder:

```sh
yarn install
yarn example start
yarn example ios # or: yarn example android
```

With the app id `example_smoke`, the app runs `src/selfTest.ts`, this repository's own API check; never copy it into
an app.
