# Changelog

All notable changes to the SallaPush React Native SDK. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.1.0] - 2026-11-18

The first public release of the SallaPush React Native SDK, for the mobile apps of Salla stores.

### Added

- The `@salla.sa/mobile-push-react-native` package on npm, with an Expo config plugin, for React Native 0.81 or later on
  the New Architecture and Expo SDK 54 or later in development builds.
- Customer login and logout, the notification permission, click and foreground listeners, tags, the push
  subscription, consent, logging and the app icon badge. The README shows the setup and each task, and
  `docs/REFERENCE.md` the API in detail.
- The MIT License.

### Changed

- SallaPush iOS 1.1.0 and SallaPush Android 1.1.0.

### Security

- The Android library builds with the Kotlin Gradle plugin 2.4.21 by default, and the example app with 2.4.21,
  which fixes CVE-2026-53914 (unsafe deserialization of the KAPT build cache). The library uses no KAPT, and an app's
  `kotlinVersion` still wins.

## [1.0.0] - 2026-10-19

Versions before 1.1.0 were not public releases: use 1.1.0 or later.
