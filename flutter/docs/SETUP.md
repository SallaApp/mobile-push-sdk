# SallaPush Flutter SDK: setup guide

The details behind the [README](../README.md#platform-setup)'s setup: CocoaPods mode, the Notification Service
Extension, Firebase on Android, other push SDKs, initializing from Dart, and the tap that launched the app.

Other docs: [README](../README.md) · [API reference](REFERENCE.md) · [Troubleshooting](TROUBLESHOOTING.md)

## Contents

1. [iOS: CocoaPods mode](#ios-cocoapods-mode)
2. [iOS: Notification Service Extension](#ios-notification-service-extension)
3. [Android: Firebase](#android-firebase)
4. [Other push SDKs](#other-push-sdks)
5. [Initializing from Dart](#initializing-from-dart)
6. [The tap that launched the app](#the-tap-that-launched-the-app)

## iOS: CocoaPods mode

Only for apps that turn Swift Package Manager off for the whole project, in the app's `pubspec.yaml`
([Flutter's guide](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers)):

<!-- unchecked: Flutter's setting, which scripts/verify.sh ios-pods applies to a fresh app -->
```yaml
flutter:
  config:
    enable-swift-package-manager: false
```

Flutter reads this setting from the `FLUTTER_SWIFT_PACKAGE_MANAGER` environment variable first, then from
`pubspec.yaml`, then from the machine's `flutter config`: keep it in `pubspec.yaml`, and leave the variable unset on
every machine and CI. Add-to-app modules always use CocoaPods.

The SallaPush pods come from git tags, so your Podfile declares them. In `ios/Podfile`, inside `target 'Runner' do`:

<!-- snippet:docs/snippets/Podfile#podfile-app -->
```ruby
pod 'SallaPushCore', :git => 'https://github.com/SallaApp/mobile-push-ios-sdk.git', :tag => '1.1.0'
pod 'SallaPush', :git => 'https://github.com/SallaApp/mobile-push-ios-sdk.git', :tag => '1.1.0'
```

and, for the [Notification Service Extension](#ios-notification-service-extension), at the end of the Podfile:

<!-- snippet:docs/snippets/Podfile#podfile-extension -->
```ruby
target 'SallaPushNotificationService' do
  use_frameworks!
  pod 'SallaPushCore', :git => 'https://github.com/SallaApp/mobile-push-ios-sdk.git', :tag => '1.1.0'
  pod 'SallaPushExtension', :git => 'https://github.com/SallaApp/mobile-push-ios-sdk.git', :tag => '1.1.0'
end
```

`pod install` fetches them over HTTPS, with no GitHub account. A Podfile that exists for other plugins is not CocoaPods
mode: with Swift Package Manager on, never add the SallaPush pods, or SallaPush is linked twice.

## iOS: Notification Service Extension

Recommended: the extension shows the notification's image and counts SallaPush notifications on the app icon's badge
([Badges](../README.md#badges)). If your app already has one, add `SallaPushExtension` to it and call SallaPush first
([A shared Notification Service Extension](#a-shared-notification-service-extension)). Otherwise:

1. In Xcode, choose **File → New → Target → Notification Service Extension**, in Swift, named
   `SallaPushNotificationService`, with a deployment target of 15.0 or later, and no higher than the app's. If
   `pod install` then fails, in an app with a Podfile, with `Unable to find compatibility version string for object
   version 70` or `unknown ISA PBXFileSystemSynchronizedRootGroup`, convert the folder (right-click
   `SallaPushNotificationService` → **Convert to Group**), and set the project's **Project Format** to **Xcode
   15.3-compatible** in its File inspector.
2. In the `Runner` target's **Build Phases**, drag **Embed Foundation Extensions** above **Thin Binary**. Xcode adds it
   last, after Flutter's **Thin Binary** script, and every build then fails with `Cycle inside Runner`.
3. Give the extension the app's version and build number, or App Store Connect warns at every upload:
   - in the extension target's **General** tab, set **Version** to `$(FLUTTER_BUILD_NAME)` and **Build** to
     `$(FLUTTER_BUILD_NUMBER)`;
   - in the Runner project's **Info** tab, under **Configurations**, base the extension on `Generated` in every
     configuration, never on `Debug` or `Release`, which bring the app's pods into the extension once it has a Podfile;
   - in CocoaPods mode, base it instead on a file of your own for each configuration, such as
     `ios/SallaPushNotificationService/Debug.xcconfig`, with the same lines for `release` and `profile`:

     <!-- unchecked: the extension's configuration files in CocoaPods mode; the steps were built by hand in a fresh app -->
     ```
     #include "../Flutter/Generated.xcconfig"
     #include? "../Pods/Target Support Files/Pods-SallaPushNotificationService/Pods-SallaPushNotificationService.debug.xcconfig"
     ```

4. Link `SallaPushExtension` to it, never `SallaPush`:
   - with Swift Package Manager: **File → Add Package Dependencies…**, the URL
     `https://github.com/SallaApp/mobile-push-ios-sdk.git`, the rule **Exact Version** for SallaPush iOS 1.1.0, and the
     product `SallaPushExtension`, added to the extension target only;
   - in [CocoaPods mode](#ios-cocoapods-mode): the extension's Podfile block.
5. Replace its `NotificationService.swift` with this one:

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

   `didReceive` returns `false`, and doesn't handle the notification, when it isn't a SallaPush notification.

6. Add the **App Groups** capability to both targets, with the same group, and put that group in the
   `SallaPushAppGroup` key of both Info.plist files: the extension needs it to count the badge.

The simulator doesn't run the extension: check images on a device.

## Android: Firebase

SallaPush receives its notifications through Firebase Cloud Messaging, so the app needs Firebase:

- Put your app's `google-services.json` in `android/app/`, and apply the Google services Gradle plugin. With Flutter's
  Kotlin build files, that is two lines, in the `plugins { … }` block of each file
  ([Firebase's guide](https://firebase.google.com/docs/android/setup#add-config-file) names the current version):

  <!-- unchecked: Firebase's own setup lines; the example applies the plugin only when its google-services.json exists -->
  ```kotlin
  // android/settings.gradle.kts
  id("com.google.gms.google-services") version "4.5.0" apply false

  // android/app/build.gradle.kts
  id("com.google.gms.google-services")
  ```

- A Firebase app created only from Dart, with `firebase_options.dart` and no `google-services.json`, gives SallaPush no
  token: it logs `token.firebase_missing`.
- Leave Firebase's auto-init on, the default.

## Other push SDKs

Answer SallaPush first: only code that takes every notification, SallaPush's too, comes after it, such as `super` in
the `AppDelegate` methods below.

### iOS

`SallaPushFlutter.start()`, first in `didFinishLaunchingWithOptions`, makes the app delegate the notification-center
delegate before another plugin can take it. When another plugin also answers notifications, add these three methods
to your `AppDelegate`, next to `SallaPushFlutter.start()`:

<!-- snippet:example/ios/Runner/ReadmeSnippets.swift#other-push-sdks -->
```swift
override func userNotificationCenter(
  _ center: UNUserNotificationCenter,
  willPresent notification: UNNotification,
  withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
) {
  if let options = SallaPush.Notifications.willPresent(notification) {
    completionHandler(options)
    return
  }
  super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
}

override func userNotificationCenter(
  _ center: UNUserNotificationCenter,
  didReceive response: UNNotificationResponse,
  withCompletionHandler completionHandler: @escaping () -> Void
) {
  if SallaPush.Notifications.didReceive(response) {
    completionHandler()
    return
  }
  super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
}

override func application(
  _ application: UIApplication,
  didReceiveRemoteNotification userInfo: [AnyHashable: Any],
  fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
) {
  SallaPush.Notifications.didReceiveRemoteNotification(userInfo)
  completionHandler(.noData)
}
```

- **The two notification-center methods** answer SallaPush's notifications before Flutter hands the call to the
  plugins, so that each one is completed once. The others go to `super`, and the other plugin gets them as before.
- **`didReceiveRemoteNotification`** hands SallaPush the background pushes that an SDK which swizzles the app delegate
  keeps from the plugins. It doesn't call `super`, since that SDK gets the call anyway. Leave it out when no SDK in
  your app swizzles.
- **When another SDK takes the APNs token,** pass it to `SallaPush.notifications.forwardApnsToken(token)`, as
  hexadecimal text, at start and whenever it changes.

### Android

Android hands each push message, and each new token, to one service only: the one with the highest priority in the
merged manifest. SallaPush's is at −450, so another library's service wins, and SallaPush then shows nothing. Use one
service of your own, at priority 1, which hands each message and token to SallaPush first. Put it next to
`MainActivity.kt`, as `AppMessagingService.kt`, with your app's `package` line:

<!-- snippet:example/android/app/src/main/kotlin/sa/salla/sallapush_flutter_example/ReadmeSnippets.kt#messaging-service -->
```kotlin
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.salla.push.SallaPush

class AppMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        if (SallaPush.Notifications.handleFirebaseMessage(applicationContext, message)) return
        // Not a SallaPush message: hand it to your other SDK here.
    }

    override fun onNewToken(token: String) {
        SallaPush.Notifications.onNewToken(applicationContext, token)
        // Hand the token to your other SDK here too.
    }
}
```

- **If the other library has a service class of its own,** extend it instead, and call `super` in both methods after
  the SallaPush line.
- **If your app already declares such a service,** put the SallaPush lines first in it rather than adding a second
  one: only one of the two would get the messages.

Declare it in `android/app/src/main/AndroidManifest.xml`, inside `<application>`:

<!-- unchecked: an app's own service; the example compiles the class but doesn't declare it -->
```xml
<service android:name=".AppMessagingService" android:exported="false">
    <intent-filter android:priority="1">
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>
```

SallaPush logs `fcm.forwarding_hint`, at info level, when another service gets the messages and none reaches
SallaPush. Another plugin may also hand SallaPush's messages to its own Dart handlers: skip them there when
`await SallaPush.notifications.isSallaPushNotification(data)` is true for the message's data.

### A shared Notification Service Extension

Keep one extension: add `SallaPushExtension` to it, and call SallaPush first, as in the
[extension's code](#ios-notification-service-extension). When
`SallaPushServiceExtension.isSallaPushNotification(request)` is false, hand the request to the other SDK in place of
`contentHandler(request.content)`.

## Initializing from Dart

An app that knows its app id only at run time leaves `SallaPushAppId` and `com.salla.push.APP_ID` out, and starts
SallaPush from Dart, with its options in a [`SallaPushConfig`](REFERENCE.md#sallapushconfig):

<!-- snippet:example/lib/readme_snippets/app_snippets.dart#initialize -->
```dart
// At every launch. Consent-gated apps require consent first.
if (requiresConsent) {
  await SallaPush.setConsentRequired(true);
}
await SallaPush.initialize(appId);
```

- **Keep `SallaPushFlutter.start()`** in the `AppDelegate`: without the app id key it doesn't start SallaPush, but it
  still hands SallaPush the push calls.
- **Most static keys apply only with the app id key** ([Static configuration](REFERENCE.md#static-configuration)):
  set their options in `SallaPushConfig`, and require consent with `setConsentRequired(true)`, before `initialize`, at
  every launch.
- **Until `initialize`,** a tap that launches the app doesn't open its launch URL, and on Android a process that a push
  starts without Dart shows SallaPush's notifications even after the user opted out.
- **An `initialize` with the app id that SallaPush started with at launch** changes nothing, its options included, and
  prints a `[SallaPush]` error that names their static keys. Another app id switches SallaPush to it. An invalid first
  app id turns SallaPush off until the next launch (`init.invalid_app_id`).

## The tap that launched the app

The tap that launched the app arrives before the first frame, while your `Navigator` or router doesn't exist yet. Keep
it until then:

<!-- snippet:example/lib/readme_snippets/app_snippets.dart#launch-tap -->
```dart
/// Routes SallaPush taps once the app can show a screen: the tap that
/// launched the app arrives before the first frame, when there is no
/// navigator yet.
final class NotificationTaps {
  /// Routes with [route].
  NotificationTaps(this.route);

  /// Shows the screen of a tapped notification.
  final void Function(SallaPushNotification notification) route;

  final List<SallaPushNotification> _pending = <SallaPushNotification>[];
  bool _ready = false;

  /// In main(), before runApp.
  void listen() {
    SallaPush.notifications.onClick.listen((SallaPushClickEvent event) {
      if (_ready) {
        route(event.notification);
      } else {
        _pending.add(event.notification);
      }
    });
  }

  /// In the root widget's initState.
  void routeAfterFirstFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ready = true;
      for (final SallaPushNotification notification in _pending) {
        route(notification);
      }
      _pending.clear();
    });
  }
}
```

Create one `NotificationTaps` with your [route function](../README.md#notification-taps-and-deep-links), call its
`listen()` in `main()`, before `runApp`, and its `routeAfterFirstFrame()` in your root widget's `initState`. An app with
a single `onClick` listener can instead start it once its router exists: taps made before the first listener wait, up
to 10, for 5 minutes.
