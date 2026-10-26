# Contributing to the SallaPush React Native SDK

Thank you for helping improve the SallaPush React Native SDK.

## Issues

- **Bugs and feature requests:** open an issue at
  https://github.com/SallaApp/mobile-push-sdk/issues/new/choose. Say which SDK version, platform and OS
  version you use, what you expected and what happened, and include the SallaPush log codes you saw.
- **Never paste** tokens, keys or customer data. Log codes are enough, and SallaPush never logs secrets.
- **Security problems:** don't open an issue. Report them privately, as [SECURITY.md](SECURITY.md) explains.
- **App ids:** Contact the Salla team for your app id.

## Pull requests

- For a large change, open an issue first, so that we can agree on the approach before you write the code.
- Keep each pull request to one change. Update its tests and docs, and add a line under `## [Unreleased]` in
  [CHANGELOG.md](CHANGELOG.md).
- Run `scripts/verify.sh` before you push. A maintainer reviews your pull request, and may land it as a commit of
  their own that credits you as a co-author (`Co-authored-by`).
- By contributing, you agree that your contribution is licensed under this repository's [MIT License](LICENSE). No
  contributor license agreement or sign-off is needed.

Everyone taking part in this project follows the [Code of Conduct](CODE_OF_CONDUCT.md). Maintainers release versions
as [RELEASING.md](RELEASING.md) describes.

## Prerequisites

- **Node 24**, the version in `.nvmrc`, with Corepack for the Yarn release the repository pins: run `corepack enable`
  once.
- **Xcode 26**, CocoaPods, and an iPhone simulator with iOS 16 or later.
- **JDK 17** and **the Android SDK**, in `ANDROID_HOME`, else `~/Library/Android/sdk`, and an emulator with API 33 or
  later for the smoke tests.
- **SwiftLint 0.63.2**, **shellcheck 0.11.0** (or Docker), `python3`, `git`, and `gh`, logged in, for
  `scripts/bump-native.sh`.

The example app is a bare React Native app in `example/`, a Yarn workspace: [example/README.md](example/README.md)
says how to configure and run it. Never commit a credential: the example's own values go in the files git ignores.

## Commands

From the `react-native` folder:

| Command | What it does |
|---|---|
| `yarn install` | Installs the dependencies of the package and the example |
| `yarn lint`, `yarn typecheck` | ESLint with Prettier; TypeScript for the library, the Expo plugin and the example |
| `yarn test`, `yarn test:scripts` | The Jest tests; the scripts' own tests |
| `yarn build` | Builds `lib/` and `plugin/build/` |
| `yarn example start`, `yarn example ios`, `yarn example android` | Runs the example app |
| `node scripts/dump-api.mjs --write` | Writes the public API to `api/sallapush-react-native.api` |
| `scripts/verify.sh [step…]` | Every check a pull request needs, in order, or the steps named; its header lists them |

CI runs `verify.sh`'s portable steps, `android` and `ios` for every pull request that changes this folder or its
workflows ([.github/workflows/react-native-ci.yml](../.github/workflows/react-native-ci.yml)); `swiftlint`, `smoke`
and `consumer` run on a Mac before each release.

## What needs care

- **The public API** is `api/sallapush-react-native.api`, and `tool/api-parity/mapping.json` maps every native symbol.
  New API goes into `src/NativeRNSallaPush.ts`, its Jest mock and both native layers, with tests: Jest, JUnit with
  Robolectric, and XCTest in the example's `SallaPushExampleTests` target. Then run
  `node scripts/dump-api.mjs --write`, and update the README and the docs.
- **The README's and the docs' code blocks** are copies of code the checks build. A hidden marker before each block
  names its source, such as `<!-- snippet:example/src/start.ts#click-listener -->`: change the source first, then copy
  it into every block that shows it.
- **The native pins** are listed once, in `SP_PINS` of `scripts/common.sh`, and `scripts/bump-native.sh` sets them all.
- **The Expo plugin's fixtures** are byte copies of Expo's templates: add the next SDK's files beside them.
- **Dependencies and tools are pinned:** the native SDKs, each workflow action to a commit, Yarn, and the tool versions
  of `scripts/common.sh`.
