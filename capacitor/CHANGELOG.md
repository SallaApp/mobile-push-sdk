# Changelog

All notable changes to the SallaPush Capacitor SDK. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.1.0] - 2026-11-18

The first public release of the SallaPush Capacitor SDK, for the mobile apps of Salla stores.

### Added

- The `@salla.sa/mobile-push-capacitor` package on npm, for Capacitor 8 apps on iOS and Android.
- Customer login and logout, the notification permission, click and foreground listeners, tags, the push
  subscription, consent, logging and the app icon badge. The README shows the setup and each task, and
  `docs/REFERENCE.md` the API in detail.
- The MIT License.

### Changed

- SallaPush iOS 1.1.0 and SallaPush Android 1.1.0.

### Security

- The Android plugin builds with the Kotlin Gradle plugin 2.4.21 by default, which fixes CVE-2026-53914 (unsafe
  deserialization of the KAPT build cache). The plugin uses no KAPT, and an app's `kotlin_version` still wins.

## [1.0.0] - 2026-10-19

Versions before 1.1.0 were not public releases: use 1.1.0 or later.
