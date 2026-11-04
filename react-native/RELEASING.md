# Releasing the SallaPush React Native SDK

How versions work, and how a maintainer releases one. To contribute, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Versions

The package follows [Semantic Versioning](https://semver.org), and pins exact versions of the native SDKs. A release
is a version on npm, published from a git tag of this repository: `react-native-` and the version, without a `v`, such
as `react-native-1.1.0` or `react-native-1.2.0-beta.1`. A pushed tag never moves and is never deleted, and npm never
takes a version twice: a defect in a release is fixed by the next version.

## Making a release

1. **Prepare it in a pull request,** and merge it to `master`. Set `version` in `package.json`, and in the README the
   version line, the React Native row of the versions table and the version in the GitHub install line, twice;
   `git grep -nF <previous version>` lists every place. Rename `## [Unreleased]` in the CHANGELOG to the version and
   its date, such as `## [1.2.0] - 2026-11-20`, below a new, empty `## [Unreleased]`.
2. **Verify it.** In a fresh clone of the merged commit, on a Mac, run `scripts/verify.sh` in the `react-native`
   folder: every step must pass, `consumer` included. A release that changes the native pins or the bridge code also
   passes the [device checklist](#the-device-checklist).
3. **Tag the merged commit, and push only the tag:**
   `git tag -a react-native-<version> -m "@salla.sa/mobile-push-react-native <version>"`, then
   `git push origin react-native-<version>`, in that clone. The tag runs
   [.github/workflows/react-native-publish.yml](../.github/workflows/react-native-publish.yml). It checks that the
   tag is on `master` at the version of `package.json` and the CHANGELOG, runs the checks and packs the package; then,
   in the protected environment `release`, it publishes the package to npm with trusted publishing, and
   creates the GitHub Release `react-native-<version>` from the version's CHANGELOG entry, with the package attached.
4. **Check the published version** in a fresh app: install it with npm, with Yarn and from the GitHub Release, then
   prebuild and build an Expo app with the config plugin.

**The first version on npm** is published by hand, since npm adds a trusted publisher only to a package that exists.
After step 2, in that clone's `react-native` folder, check the package's files with `npm publish --dry-run`, and run
`npm publish --access public`; both build the package afresh first. On npmjs.com, add the trusted publisher (the
repository `SallaApp/mobile-push-sdk`, the workflow `react-native-publish.yml` and the environment `release`), require
two-factor authentication and disallow tokens. Then push the tag: for a version npm has already, the workflow checks
that npm's files are the tag's, and creates the GitHub Release.

## Updating the native SDKs

1. Run `scripts/bump-native.sh <version>`, or `--ios <version> --android <version>`. It fetches the native API files
   at the new tags, sets every pin, adds the CHANGELOG line, and runs the API parity check.
2. Map each native symbol the parity check names in `tool/api-parity/mapping.json`, wrap the new API with its tests,
   and update the README and the docs where the native behaviour changed.
3. Release as above. When the native API didn't change, the release is a patch.

## The device checklist

On an iPhone and an Android 13 or later phone, with a real app id and verbose logs, in the example app or an Expo
development build:

- `register.ok`, with a device id and a token.
- Foreground and background notifications, with their images on iOS, and taps on them, the one that launches the app
  included, also after the Android process was killed.
- A `'foregroundWillDisplay'` listener that prevents a notification, then `display()`; and with `openLaunchUrls` on,
  an https launch URL that opens.
- On Android, after `optOut()` and with the app killed, no notification shows.
- `login` with a valid token, a bad token's `'loginFailure'` with `tokenRejected`, and `logout()`; consent; the
  permission prompt, and `requestPermission(true)` after a permanent denial.
- With another push SDK in the app, each SDK gets its own notifications and taps, once.
- The badge: on iOS, three notifications with the app killed show 3, and opening the app shows 0; on Android, opening
  the app leaves SallaPush's notifications in the shade, and with `autoClearBadge` on removes them.
