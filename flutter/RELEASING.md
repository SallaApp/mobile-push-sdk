# Releasing the SallaPush Flutter SDK

A release is a version on pub.dev and a tag on this repository: `flutter-` and the version, such as `flutter-1.1.0`.
Apps install it from pub.dev ([README](README.md#installation)), or with a git dependency on the tag, and pub records
what they got in each app's `pubspec.lock`. pub.dev never replaces a published version, and a pushed tag is never moved
or deleted: a fix is a new version.

The package, [`mobile_push`](https://pub.dev/packages/mobile_push) on pub.dev, is the `flutter/` folder of this
repository: run the commands below in that folder.

Other docs: [README](README.md) · [Setup guide](docs/SETUP.md) · [Contributing](CONTRIBUTING.md) ·
[Changelog](CHANGELOG.md)

## Contents

1. [Versions](#versions)
2. [Prepare the release](#prepare-the-release)
3. [Release](#release)
4. [After the release](#after-the-release)
5. [Updating the native SDKs](#updating-the-native-sdks)
6. [The device checklist](#the-device-checklist)

## Versions

The plugin follows [Semantic Versioning](https://semver.org/), and pins the native SDKs to exact versions:

- **A patch,** such as `1.1.1`, for fixes, and for a native version that fixes SallaPush without changing its API.
- **A minor,** such as `1.2.0`, for new Dart API, such as a member that wraps new native API.
- **A major,** such as `2.0.0`, for a breaking change of the Dart API.

`SallaPush.sdkVersion` returns the native SDK's version at run time; the plugin's version is the one in
`pubspec.yaml`.

## Prepare the release

In a pull request to `master`:

1. **Set the version** wherever the current one is named. `git grep -nF <current version>` lists every place:
   - `version` in `pubspec.yaml`;
   - `s.version` in `ios/mobile_push.podspec`;
   - the README: the versions table and the `ref` of its git install block.

   The test fixtures of `test/tool/check_readme_snippets_test.dart` keep theirs, and so does Flutter's own
   `flutter-plugin-loader` version in `example/android/settings.gradle.kts`.
2. **Write the CHANGELOG entry:** rename `## [Unreleased]` to `## [<version>] - <date>`, with the release date, and add
   a new, empty `## [Unreleased]` above it. `scripts/bump-native.sh` adds its lines there later.
3. **Run the device checklist** below when the release changes the native pins or the bridge code: the Pigeon schema,
   or the native code under `ios/` and `android/`.
4. **Run the full verification,** every step of `scripts/verify.sh` with `FLUTTER_MIN`, on the pull request's head
   commit, and put its `summary.tsv` in the pull request ([CONTRIBUTING.md](CONTRIBUTING.md#checks)).

## Release

1. **Merge** the pull request into `master`.
2. **Verify the merge commit** with every step of `scripts/verify.sh`, `FLUTTER_MIN` included, on a Mac
   ([CONTRIBUTING.md](CONTRIBUTING.md#checks)).
3. **Check the version** of the merge commit: the pubspec, the podspec and the CHANGELOG heading name it.

   <!-- unchecked: shell commands of the release -->
   ```bash
   version=<version>
   grep -qx "version: $version" pubspec.yaml &&
     grep -Eq "s\.version += '$version'" ios/mobile_push.podspec &&
     grep -q "^## \[$version\] - " CHANGELOG.md &&
     echo "the release commit names $version"
   ```

4. **Tag the merge commit** with `flutter-<version>`, and push only that tag. A maintainer does this:

   <!-- unchecked: shell commands of the release -->
   ```bash
   git tag -a flutter-<version> -m "mobile_push <version>" <merge commit>
   git push origin flutter-<version>
   ```

5. **Publish.** The tag starts `.github/workflows/flutter-publish.yml`. Each of its two jobs waits for a reviewer of the
   `release` environment, so a reviewer approves both. The first checks that the tag is a commit of `master` and that
   the pubspec, the podspec and the CHANGELOG name its version, checks the archive (`scripts/verify.sh pub`), and
   publishes the version to pub.dev through pub.dev's automated publishing. Once it has passed, the second creates the
   GitHub Release with the version's CHANGELOG entry. A version that pub.dev already has isn't published again: the
   first job then publishes nothing, and the second still creates the GitHub Release. pub.dev never takes a version
   twice: a mistake in a published version is fixed by a new version.

   The package's first version on pub.dev is 1.1.0, its first public release. It is published by hand, because automated
   publishing is set up on a package that exists. While the first job of the workflow run that its tag started waits for
   its reviewer, a maintainer who is an admin of the verified publisher `salla.sa` on pub.dev runs, in the `flutter/`
   folder of a clean checkout of the tag, with Flutter 3.47.7:

   <!-- unchecked: shell commands of the release -->
   ```bash
   git checkout flutter-<version>
   scripts/verify.sh pub
   flutter pub publish
   ```

   Then, on the package's admin page on pub.dev, they transfer the package to the publisher `salla.sa`, so that it
   doesn't stay under their own account, and turn on automated publishing from GitHub Actions for the repository
   `SallaApp/mobile-push-sdk`, with the tag pattern `flutter-{{version}}` and the environment `release`. Last, a
   reviewer approves the waiting first job, which finds the version on pub.dev and publishes nothing, and then the
   second job, which creates the GitHub Release.

## After the release

1. **Install the release in a fresh app,** as the README shows: a new `flutter create` app,
   `flutter pub add mobile_push`, and the README's iOS and Android setup. Then `flutter build apk --debug` and
   `flutter build ios --simulator --no-codesign`. This proves that the release installs the way apps install it, from
   pub.dev, which `scripts/verify.sh consumer` can't do before the release exists. Record the result in the release's
   pull request.
2. **Update the apps** to the new release. In CocoaPods mode, or with the Notification Service Extension's package
   added through Xcode, they also move to the native versions of the README's versions table.

## Updating the native SDKs

When SallaPush iOS or Android releases a new version:

1. **Run `scripts/bump-native.sh <version>`,** or `--ios <version>` and `--android <version>` for one platform. It needs
   `gh`, logged in (`gh auth login`), and `python3`. It checks the versions, fetches the native API files at the new
   tags into `tool/api-parity/`, rewrites every pin (the podspec, `Package.swift`, `docs/snippets/Podfile`, the
   example's Swift package reference, the Gradle dependency, the parity mapping, and the versions and links in the
   README and the docs), adds the CHANGELOG line under `## [Unreleased]`, `### Changed`, and runs the pin and parity
   checks. A platform already at its version is left as it is, and out of the CHANGELOG line. It never commits, pushes
   or prints a credential.
2. **Map every new native symbol** in `tool/api-parity/mapping.json`: `scripts/verify.sh parity` names each one, and
   each removed one.
3. **Wrap the new API,** with its tests and docs ([Adding or changing API](CONTRIBUTING.md#adding-or-changing-api)).
   For a native version that only fixes SallaPush, steps 1 and 2 are the whole change: a patch release.
4. **Verify,** run the device checklist, and open the pull request. CI checks that every pin agrees (`pins`), that
   every native symbol is mapped (`parity`), and that the README and the docs name the pins (`snippets`).

## The device checklist

Run it on one iPhone and one Android 13 or later phone, with real app ids, in the example app
([example/README.md](example/README.md)) or the app being released, at the `verbose` log level. Record the result of
each item in the pull request.

1. **Registration.** `register.ok` appears in the logs, and `pushSubscription.id` and `token` are set.
2. **Notifications without a will-display listener.** A foreground notification shows, with its image through the
   Notification Service Extension on iOS. A background notification shows, and a tap on it reaches `onClick`, with
   its `url`.
3. **Cold-start tap.** Kill the app, and tap a notification: the tap reaches `onClick` once. On iOS, in a UIScene app,
   such as one from Flutter 3.47's template. On Android, also after the app's process was killed again within 5
   minutes, before Dart ran.
4. **Launch URL.** With `SallaPushOpenLaunchURLs` or `com.salla.push.OPEN_LAUNCH_URLS` on, a tap opens an https launch
   URL.
5. **Will-display listener.** One that prevents: nothing shows, and a later `display()` shows the notification. One
   that doesn't: the notification shows; on iOS as SallaPush's local copy, without image or action buttons.
6. **Opt-out on Android.** After `optOut()`, with the app killed, a notification doesn't show.
7. **Identity.** A `login` with a valid token raises no `onLoginFailure`; a bad token gives `tokenRejected`; `logout()`
   unlinks.
8. **Consent.** With the static consent key on, nothing registers until `setConsentGiven(true)`.
9. **Permission.** The prompt, and `requestPermission(fallbackToSettings: true)` after a permanent denial, on Android 13
   or later.
10. **Badges.** On iOS, with the Notification Service Extension and the App Group, two notifications that arrive while
    the app is in the background show 2 on the app icon, and opening the app sets it to 0; with
    `SallaPushAutoUpdateBadge` set to `NO`, the icon shows the push's own badge instead. On Android 8.0 or later,
    opening the app keeps SallaPush's notifications in the shade; with `com.salla.push.AUTO_CLEAR_BADGE` set to
    `true`, opening the app removes them.
11. **Other push SDKs.** With another push plugin in the app, and the setup guide's `AppDelegate` methods and
    forwarding service: SallaPush's notifications show once on both platforms, none shows for an opted-out user, a tap
    reaches `onClick`, and the other plugin still gets its own messages.
