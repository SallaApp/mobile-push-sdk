# Changelog

All notable changes to the SallaPush Flutter SDK. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Security

- The Kotlin Gradle plugin of the Android plugin's own build and of the example app moves from 2.4.0 to 2.4.21,
  which fixes CVE-2026-53914 (unsafe deserialization of the KAPT build cache). The plugin uses no KAPT, and apps keep
  building it with their own Kotlin version.

## [1.1.0] - 2026-11-17

The first public release of the SallaPush Flutter SDK, for the mobile apps of Salla stores.

### Added

- The `mobile_push` plugin on pub.dev, for iOS and Android apps on Flutter 3.44 or later.
- Customer login and logout, the notification permission, click and foreground listeners, tags, the push
  subscription, consent, logging and the app icon badge. The README shows the setup and each task, and
  `docs/REFERENCE.md` the API in detail.
- The MIT License.

### Changed

- SallaPush iOS 1.1.0 and SallaPush Android 1.1.0.

## [1.0.0] - 2026-10-19

Versions before 1.1.0 were not public releases: use 1.1.0 or later.
