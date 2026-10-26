# SallaPush Flutter SDK: troubleshooting

Each problem with what you see, its cause and its fix. Set the log level to `verbose` first, with the
`SallaPushLogLevel` Info.plist key and the `com.salla.push.LOG_LEVEL` meta-data, and filter the console on
`SallaPush`: the [log codes](REFERENCE.md#log-codes) say what each line means.

Other docs: [README](../README.md) · [Setup guide](SETUP.md) · [API reference](REFERENCE.md)

## Build and install

| You see | Cause | Fix |
|---|---|---|
| Gradle: `Could not find com.salla:mobile-push` | The repositories your build uses don't list `mavenCentral()`, for example settings with `repositoriesMode` set to `PREFER_SETTINGS` | Add `mavenCentral()` to those repositories. |
| Gradle fails because a project declares a repository | `repositoriesMode` is `FAIL_ON_PROJECT_REPOS`: Flutter's own Gradle plugin adds a repository to every project | Use `PREFER_SETTINGS`, with `google()` and `mavenCentral()` in the settings, or leave the mode unset. |
| Manifest merger: `no value for <sallaPushAppId> is provided` | The manifest's `${sallaPushAppId}` has no value | Define `manifestPlaceholders["sallaPushAppId"]` in `defaultConfig` or in each flavor. |
| Manifest merger: `no value for <applicationName> is provided` | A Groovy `manifestPlaceholders = [...]` replaced Flutter's own placeholders | Add to the map instead: `manifestPlaceholders += [sallaPushAppId: "…"]`. |
| A release build crashes at every start: `Failed to create an instance of class androidx.work.impl.WorkDatabase…` | R8 removed the constructor of WorkManager's database class, because the build ignores the libraries' consumer rules | Keep the consumer rules, or add `-keep class * extends androidx.room.RoomDatabase { <init>(); }` to `android/app/proguard-rules.pro`. |
| `pod install`: `Unable to find a specification for SallaPush` or `SallaPushCore` | CocoaPods mode without the Podfile's git lines; or Swift Package Manager is off by mistake, through the `FLUTTER_SWIFT_PACKAGE_MANAGER` variable or the machine's `flutter config` | Add the lines of [CocoaPods mode](SETUP.md#ios-cocoapods-mode), or set `enable-swift-package-manager: true` in `pubspec.yaml` and unset the variable. |
| Duplicate SallaPush classes, two SDK instances at run time, or a module redefinition error | The SallaPush pods were added while Swift Package Manager is on, so SallaPush came twice | Remove the SallaPush pods from the Podfile, or turn Swift Package Manager off for the whole project. |
| `pod install`: `Unable to find compatibility version string for object version 70`, or `unknown ISA PBXFileSystemSynchronizedRootGroup` | Xcode added the extension as a synchronized folder, in a project format that the app's CocoaPods can't read | Convert the folder to a group, and set the Project Format to Xcode 15.3-compatible ([extension](SETUP.md#ios-notification-service-extension)). |
| Xcode: `Cycle inside Runner; building could produce unreliable results` | **Embed Foundation Extensions** runs after **Thin Binary** | Move **Embed Foundation Extensions** above **Thin Binary** in the `Runner` target's Build Phases. |

## iOS

| You see | Cause | Fix |
|---|---|---|
| No `init.started`: `isInitialized` is `false` | `SALLAPUSH_APP_ID` isn't defined for that build configuration, so `SallaPushAppId` is empty | Define it for every configuration and flavor. |
| `token.registration_failed` | The Push Notifications capability is missing from the target or its provisioning profile, or the simulator can't get tokens | Add the capability, with a profile that has it. Use an iOS 16 or later simulator on a Mac with Apple silicon or a T2 chip, or a device. |
| `token.missing` | Nothing asked iOS for a token: `registerForRemoteNotificationsOnInit` is off; or consent isn't given; or another SDK takes the token | Leave the option on, or call `registerForRemoteNotifications()` at every launch. Record consent. Forward the other SDK's token with `forwardApnsToken` ([Other push SDKs](SETUP.md#other-push-sdks)). |
| `init.no_delegate`, or the tap that launched the app never reaches `onClick` | `SallaPushFlutter.start()` is missing, or another delegate replaced the app delegate; or the first `onClick` listener came late | Call `SallaPushFlutter.start()` first in `didFinishLaunchingWithOptions`, and listen to `onClick` in `main()`, before `runApp`. |
| SallaPush gets no taps and no foreground notifications | Your `AppDelegate` overrides `willPresent` or `didReceive` without answering SallaPush first or calling `super`; or a delegate set after `start()` doesn't hand the calls on | Answer SallaPush first, as [Other push SDKs](SETUP.md#other-push-sdks) shows, or call `super`. |
| With another push plugin, a SallaPush notification shows twice, or shows for an opted-out user | The other plugin completes SallaPush's notifications too | Add the `AppDelegate` methods of [Other push SDKs](SETUP.md#other-push-sdks). |
| `register.ok`, but no notification arrives | The device isn't opted in, or the build's APNs environment isn't the one its signing uses | Check `pushSubscription.optedIn`. Development builds use the APNs sandbox, TestFlight and App Store builds production: set `SallaPushAPNsEnvironment` only for unusual signing. |
| A foreground notification shows without its image or action buttons | An `onWillDisplay` listener exists, so iOS shows SallaPush's local copy | Listen to `onWillDisplay` only where a screen decides, and cancel when it goes. |
| No image, `nse.attachment_failed`, or `config.no_app_group` | The extension isn't there, can't download the image, or has no App Group | Add the [extension](SETUP.md#ios-notification-service-extension) with the same App Group on both targets. Images must be https, at most 10 MB. |
| The badge doesn't go up, or always shows 1 | The extension doesn't count: it is missing, doesn't call SallaPush, or doesn't share the App Group; or the app's alerts are off in Settings | Add the extension and the App Group, and open the app once. `nse.badge_skipped`, at info level in the extension's log, says why. |

## Android

| You see | Cause | Fix |
|---|---|---|
| `token.firebase_missing` | No default Firebase app: no `google-services.json` or no Google services plugin, or Firebase is created only from Dart | Add both ([Firebase](SETUP.md#android-firebase)). |
| `token.auto_init_disabled` | Firebase's auto-init is off | Turn it on, or hand `onNewToken` to SallaPush. |
| `fcm.forwarding_hint`, or `register.ok` but SallaPush notifications never show | Another library's service receives the push messages | Add the [forwarding service](SETUP.md#other-push-sdks), or put the SallaPush lines first in the service your app has. |
| `notif.suppressed` | Notifications are off, the channel is blocked, or the user opted out; the message says which | Ask for the permission, let the user turn the channel back on, or call `optIn()`. |
| The notification shows a bell, with `display.default_icon` | No usable small icon in the meta-data | Add a white-on-transparent drawable as `com.salla.push.default_notification_icon`. |
| The badge stays after the app opens | `autoClearBadge` is off, the Android default: the badge follows SallaPush's notifications in the shade | Expected. To remove them when the app opens, set `com.salla.push.AUTO_CLEAR_BADGE` or `autoClearBadge` to `true`, or call `clearAll()`. |
| SallaPush's notifications leave the shade when the app opens | `autoClearBadge` is on | Expected. To keep them, leave `autoClearBadge` unset or set it to `false`. |
| `badge.channel_badges_on`: notifications still count with `autoUpdateBadge` off | The channel existed with badges before: Android lets only the user change it | Create your own channel without badges, and name it in `com.salla.push.default_channel_id`. |

## Identity, consent and configuration

| You see | Cause | Fix |
|---|---|---|
| `login.rejected`, and `onLoginFailure` gives `tokenRejected` | The identity token expired, belongs to another customer, or has a `Bearer ` prefix | Pass the customer's current token and their id. Call `login` again when your app refreshes the token or at the next launch, not from the listener. |
| `identity.token_needed` | No `login` came in this launch while the customer is signed in | Call `login` at each app launch while the customer is signed in. |
| `init.invalid_app_id` | The app id isn't 1 to 64 letters, digits, `_` and `-` | Fix the app id: SallaPush is off until the next launch. |
| `register.dormant` | The app id isn't known | Check your app id. |
| `consent.waiting`: nothing registers | Consent is required and not given | Record the answer with `setConsentGiven(true)`. |
| `[SallaPush]` error: `initialize ignored its options` | SallaPush started at launch with this app id, and `initialize` repeated it with options | Set each option with the static key the line names, and drop the `initialize` call. |
| `[SallaPush]` error: `setConsentRequired(true) came after SallaPush started at launch` | Consent was required only from Dart, after the start at launch | Set the static consent key. |
| `getTags()`, `pushSubscription.id` or `externalId` are empty right after launch | SallaPush loads its saved state after launch | Read them in `pushSubscription.onChange`. |

## Dart

| You see | Cause | Fix |
|---|---|---|
| `MissingPluginException`, or `PlatformException(channel-error, …)` | The plugin's native code isn't in the running app: on the web, a desktop, a unit test, or after adding the plugin without rebuilding | Rebuild the app: a hot restart doesn't load native code. In widget tests, put SallaPush behind an interface of your own, and fake that. |
| Foreground notifications don't show after a hot restart | The old isolate's will-display listener still holds them | Do a full restart. |
| `preventDefault()` in an `await for` loop doesn't keep a notification hidden | The event reached the loop after SallaPush decided | Use `listen()`, and call `preventDefault()` before any `await`. |
| `[SallaPush] display() did nothing…` | `display()` came twice, too late, or for a notification that wasn't prevented | Call `event.preventDefault()` first, and `display()` once, within 10 minutes. |
