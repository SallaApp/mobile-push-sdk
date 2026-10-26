# Contributing to the SallaPush Flutter SDK

Thank you for helping improve the SallaPush Flutter SDK.

The SDK is the `flutter/` folder of this repository: run the commands below in that folder.

## Issues

- **Bugs and feature requests:** open an issue at https://github.com/SallaApp/mobile-push-sdk/issues/new/choose,
  with the SDK, platform and OS versions, what you expected, what happened, and the SallaPush log codes you saw. Never
  paste tokens, keys or customer data: the log codes are enough.
- **Security problems:** don't open an issue. Report them privately, as [SECURITY.md](SECURITY.md) explains.
- **App ids:** Contact the Salla team for your app id.

## Pull requests

Pull requests are welcome.

- For a large change, open an issue first, so that we can agree on the approach before you write the code.
- Keep each pull request to one change. Update its tests and docs, and add a line under `## [Unreleased]` in
  [CHANGELOG.md](CHANGELOG.md).
- Run the checks below before you push.
- A maintainer reviews your pull request. A maintainer may land it as a commit of their own that credits you as a
  co-author (`Co-authored-by`), and then close the pull request with a link to that commit.
- By contributing, you agree that your contribution is licensed under this repository's [MIT License](LICENSE). No
  contributor license agreement or sign-off is needed.

Everyone taking part in this project follows the [Code of Conduct](CODE_OF_CONDUCT.md).

## Set up

On a Mac:

- **Flutter 3.47.7,** the version the plugin is developed with, and **Flutter 3.44.9,** the oldest it supports, each
  in a folder of its own, so that an existing Flutter install stays as it is:

  <!-- unchecked: the install commands of the development Flutter versions -->
  ```bash
  mkdir -p "$HOME/.sallapush-tools"
  git clone --depth 1 --branch 3.47.7 https://github.com/flutter/flutter.git "$HOME/.sallapush-tools/flutter"
  git clone --depth 1 --branch 3.44.9 https://github.com/flutter/flutter.git "$HOME/.sallapush-tools/flutter-3.44.9"
  export FLUTTER="$HOME/.sallapush-tools/flutter/bin/flutter"
  export FLUTTER_MIN="$HOME/.sallapush-tools/flutter-3.44.9/bin/flutter"
  "$FLUTTER" --version    # the first run fills this install's own cache
  "$FLUTTER" precache --ios --android
  "$FLUTTER_MIN" --version
  ```

  - **Never run `flutter config`** with them: it writes `~/.config/flutter/settings`, which every Flutter install on
    the Mac shares. Settings for one project go in its `pubspec.yaml`.
  - **Don't add them to `PATH`** in a shell profile. Set `FLUTTER`, and `FLUTTER_MIN` for the `min-sdk` step, when
    you run the scripts; without `FLUTTER`, they take `flutter` from `PATH`, as CI does.
  - When `"$FLUTTER" --version` can't name the version, clone the same tag again without `--depth`: Flutter reads its
    version from git tags.
- **Xcode 26** (16 at least), with an iPhone simulator runtime.
- **CocoaPods,** whose `xcodeproj` gem `scripts/add-nse-target.rb` uses.
- **JDK 17,** through `JAVA_HOME` for `./gradlew`.
- **The Android SDK** with platform 36, an emulator image and the command-line tools, which hold `apkanalyzer`, in
  `ANDROID_HOME` or in Android Studio's default `~/Library/Android/sdk`.
- **SwiftLint 0.63.2,** the native iOS SDK's version.
- **shellcheck 0.11.0,** or Docker, which runs its pinned image.
- **`python3`, `git` and `gh`.** `gh`, logged in (`gh auth login`), is needed only by `scripts/bump-native.sh`.
- **applesimutils,** optional: the `smoke` step uses it to allow notifications on the simulator.
- **The example app** takes its app ids and Firebase file from ignored files ([example/README.md](example/README.md)).
  Never commit them: the `tree` step fails on credential files, tokens, private keys and personal paths.

## Checks

`scripts/verify.sh` runs every check, in this order, and stops at the first failure. `scripts/verify.sh <step>...`
runs the steps you name.

| Step | What it checks |
|---|---|
| `format` | `dart format` changes nothing |
| `analyze` | `pub get` and `flutter analyze`, in the plugin and in the example |
| `test` | The Dart unit tests, covering at least 90 % of the lines of `lib/src`, and the example's widget tests |
| `pigeon` | The committed generated code is what `scripts/generate-pigeon.sh` generates |
| `api` | The public Dart API is `api/mobile_push.api` |
| `parity` | Every native symbol has a decision in `tool/api-parity/mapping.json` |
| `snippets` | The README and `docs/` show the code that the checks build, and name the native pins |
| `pins` | Every native version pin agrees (`scripts/bump-native.sh --check`) |
| `tree` | What a commit takes, in `flutter/` and in the package's workflows at the repository's root: no secret, credential file, personal path, Apple team id or ticket key; the required files; the scripts executable; every workflow action pinned; every Swift file of the example in a target of its Xcode project; the example's Dart SDK bound is the plugin's |
| `shell` | `bash -n`, shellcheck 0.11.0 and `scripts/self-test.sh` |
| `pub` | `flutter pub publish --dry-run` finds nothing to warn about, and the archive holds the package, its example, the license, the README and the changelog, without this repository's own tooling and docs (`.pubignore`) |
| `swiftlint` | SwiftLint 0.63.2, strict |
| `android` | The plugin's unit tests and Android lint; the example's release build, shrunk by R8 with no rule of its own; its merged manifest: the init provider after Firebase's and androidx.startup's, SallaPush's service at −450; and that build on an emulator, which must start and run for 15 s without a crash |
| `ios` | The example and its extension, with Swift Package Manager; the plugin's XCTest suite on a simulator |
| `ios-pods` | A fresh app with Swift Package Manager off: the README's `AppDelegate` with the setup guide's methods for other push SDKs, `docs/snippets/Podfile`, and an extension that links `SallaPushExtension` through CocoaPods |
| `ios-mixed` | A fresh app with Swift Package Manager on and a CocoaPods-only plugin: SallaPush comes through Swift Package Manager, and no SallaPush pod is installed |
| `min-sdk` | With `FLUTTER_MIN`, in a worktree of `HEAD`: `pub get`, `analyze`, `test`, and the example's builds for both platforms |
| `smoke` | The example's integration tests on a simulator and an emulator, with a made-up app id: they reach SallaPush's production service, which refuses it |
| `consumer` | A fresh app that installs `HEAD` from git, in place of the release that the README adds from pub.dev, and applies only what the README shows; it builds for both platforms |

- **CI runs most of them** on every push to `master`, and on every pull request that changes `flutter/` or its
  workflows, `.github/workflows/flutter-ci.yml` and `flutter-publish.yml`, on GitHub-hosted runners: the first eleven
  on Linux, `analyze` and `test` with both Flutter versions; `android` without its emulator run
  (`VERIFY_ANDROID_NO_EMULATOR`); and `swiftlint`, `ios` and `ios-pods` on macOS. The repository's `Testing Ready` check
  (`.github/workflows/ci.yml`) passes only when all of them passed. The native jobs resolve the native SDKs from their
  public repositories and Maven Central.
- **The others run on a Mac before a release:** `ios-mixed`, `min-sdk` with Flutter 3.44, `smoke` with a booted
  simulator and a running emulator, `consumer`, and `android` with a running emulator.
- **`pub`, `min-sdk` and `consumer` take the committed `HEAD`,** so they need a clean tree.
- **A skipped smoke case is reported as skipped,** never as passed, with its reason: for example the permission case,
  which would show the system prompt unless the permission was granted beforehand. `smoke` grants it on the emulator
  when there is room for two copies of the app, and notes it in the summary when there isn't.

The environment of the script:

| Variable | Meaning |
|---|---|
| `FLUTTER` | The `flutter` binary; `flutter` on `PATH` when unset. `dart` is the one next to it. |
| `FLUTTER_MIN` | The `flutter` binary of Flutter 3.44, for `min-sdk` |
| `VERIFY_LOG_DIR` | A folder for a log of each step and `summary.tsv`, the run's summary. Use one for each commit: the summary names its commit, and runs of another commit are refused |
| `VERIFY_SIMULATOR_UDID` | The simulator of `ios` and `smoke`; else a booted iPhone, else the newest |
| `VERIFY_EMULATOR_SERIAL` | The emulator of `android` and `smoke`; else the only running one |
| `VERIFY_ANDROID_NO_EMULATOR` | `1`: `android` runs every check but the release build's run on an emulator, and needs no emulator; its summary says so. CI sets it |
| `VERIFY_IOS_SDK_CHECKOUT` | A clone of the iOS SDK in a folder named `mobile-push-ios-sdk`, with the pinned tag checked out (`git checkout <tag>`) and no changes, for a Mac that can't fetch it: every Swift Package Manager build then uses it in place of the remote package, and the step's summary says so. A clone at another commit, or with changed or untracked files, is refused |
| `SMOKE_HOT_RESTART` | `1`: `smoke` also checks a hot restart on both devices |
| `SWIFTLINT`, `SHELLCHECK` | The binaries; else from `PATH`, and shellcheck from its pinned Docker image |
| `ANDROID_HOME` | The Android SDK; else `~/Library/Android/sdk` |

<!-- unchecked: an example run of the checks -->
```bash
FLUTTER="$HOME/.sallapush-tools/flutter/bin/flutter" \
FLUTTER_MIN="$HOME/.sallapush-tools/flutter-3.44.9/bin/flutter" \
VERIFY_LOG_DIR="$PWD/build/verify/$(git rev-parse --short HEAD)" \
scripts/verify.sh
```

Don't edit a script while it runs: bash reads scripts as it goes. `scripts/self-test.sh` proves that the scripts still
catch what they exist to catch; run it, through the `shell` step, when you change one.

## Generated and checked files

- **The bridge.** Change `pigeons/messages.dart`, then run `scripts/generate-pigeon.sh` and commit the three files it
  writes: `lib/src/messages.g.dart`, `Messages.g.swift` and `Messages.g.kt`. Asynchronous host methods use
  `@asyncCallback`, which gives native's completion forms; never `@async`.
- **The public API.** After an intended change of the Dart API, run `dart run tool/dump_api.dart --write` and commit
  `api/mobile_push.api` with the change, so that every API change shows in review. The tool reads analyzer's
  syntax tree, so `pubspec.yaml` keeps analyzer below its next minor version: raise that cap only after
  `dart run tool/dump_api.dart --check`, `flutter test test/tool` and `flutter analyze` pass with both Flutter versions.
- **The parity mapping.** `tool/api-parity/mapping.json` gives every native symbol a status: `W` wrapped, `I` or `A`
  wrapped for iOS or Android only, `N` used natively, or `X` not wrapped, with the Dart symbols, and a reason for `N`
  and `X`. `dart run tool/check_api_parity.dart` names every symbol without one.
- **The README and the docs.** Their code blocks are copies of code that the checks build: the example app, and
  `docs/snippets/`. Change that code first, then copy it; `dart run tool/check_readme_snippets.dart` names the first
  line that differs. Each block follows one marker line: `<!-- snippet:<path> -->` for a whole file,
  `<!-- snippet:<path>#<name> -->` for the lines between a `snippet:<name>` and an `end-snippet` comment line of that
  file, or `<!-- unchecked: <reason> -->`. A region may be split in parts, which the check joins in order: that keeps
  the example's test hooks out of the README's `AppDelegate`.
- **The native pins.** `scripts/bump-native.sh` keeps them; `NATIVE_PINS` in `scripts/common.sh` lists every place that
  names a native version, the links to the native docs included ([RELEASING.md](RELEASING.md#updating-the-native-sdks)).

## Adding or changing API

The plugin wraps the native SallaPush SDKs and adds no push logic of its own, so a change of SallaPush's behaviour
belongs in them, and reaches this plugin with a native version.

1. **Start from native semantics.** Read the native API and docs at the pinned tags: the Dart member does what the
   native one does, and nothing more.
2. **Update the mapping,** `tool/api-parity/mapping.json`.
3. **Update the bridge,** `pigeons/messages.dart`, and generate it.
4. **Write the native and the Dart code, with tests on every layer:** the Dart unit tests in `test/`, over
   `FakeChannels`; the Android tests in `android/src/test/`; the iOS tests in `example/ios/RunnerTests/`, where each new
   file is also added to the Xcode project (the `tree` step checks it); and the smoke test, when it needs a device. A
   member that works on one platform only exists on both: on the other one, it answers with a neutral value and one
   console line per process.
5. **Update the API dump and the docs:** the README, `docs/SETUP.md`, `docs/REFERENCE.md`, and the CHANGELOG under
   `## [Unreleased]`.
