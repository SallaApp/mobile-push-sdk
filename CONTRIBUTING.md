# Contributing to the SallaPush Flutter, React Native and Capacitor SDKs

Thank you for helping improve the SallaPush SDKs.

This repository holds three packages, each in a folder of its own, with its own checks, changelog and releases. The
CONTRIBUTING.md of each package says how to set it up, run its checks and change its API:

| Package | Folder | Contributing | Releasing |
|---|---|---|---|
| Flutter | `flutter/` | [flutter/CONTRIBUTING.md](flutter/CONTRIBUTING.md) | [flutter/RELEASING.md](flutter/RELEASING.md) |
| React Native | `react-native/` | [react-native/CONTRIBUTING.md](react-native/CONTRIBUTING.md) | [react-native/RELEASING.md](react-native/RELEASING.md) |
| Capacitor | `capacitor/` | [capacitor/CONTRIBUTING.md](capacitor/CONTRIBUTING.md) | [capacitor/RELEASING.md](capacitor/RELEASING.md) |

## Issues

- **Bugs and feature requests:** open an issue at https://github.com/SallaApp/mobile-push-sdk/issues/new/choose and
  choose the package. Give the SDK version, the platform and OS version, what you expected, what happened, and the
  SallaPush log codes you saw. Never paste tokens, keys or customer data: the log codes are enough.
- **Security problems:** don't open an issue. Report them privately, as [SECURITY.md](SECURITY.md) explains.
- **App ids:** Contact the Salla team for your app id.

## Pull requests

Pull requests are welcome.

- For a large change, open an issue first, so that we can agree on the approach before you write the code.
- Keep each pull request to one change. Update its tests and docs, and add a line under `## [Unreleased]` in the
  CHANGELOG.md of each package it changes.
- Name the branch like `feature/PROJ-123-retry-registration` (`feature`, `bugfix`, `hotfix` or `test`, then a ticket
  key and number), and title the pull request like `fix(mobile): retry a failed registration`. The checks
  `Validate branch name` and `Validate PR title` ([.github/workflows/lint-pr.yml](.github/workflows/lint-pr.yml)) say
  what they accept.
- Run the checks of each package you change before you push: its `scripts/verify.sh`, as its CONTRIBUTING.md explains.
  For a change to the files at the repository's root, `.github` included, run `react-native/scripts/verify.sh tree`.
- A maintainer reviews your pull request, and may land it as a commit of their own that credits you as a co-author
  (`Co-authored-by`).
- By contributing, you agree that your contribution is licensed under this repository's [MIT License](LICENSE). No
  contributor license agreement or sign-off is needed.

Everyone taking part in this project follows the [Code of Conduct](CODE_OF_CONDUCT.md).
