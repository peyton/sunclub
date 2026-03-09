# SunscreenTrack

## Overview

SunscreenTrack is an offline, camera-first iOS app built with **Swift 6**, **SwiftUI**, and **SwiftData** that helps you track sunscreen application each day.

Core flow:

- Set your bottle’s expected barcode during onboarding.
- Capture training photos from the camera only and train the on-device object model.
- Verify daily via barcode scan, selfie, or live video feature-print matching.
- Receive local notifications in the morning and a weekly on-device summary.

## How it works

- **No network, no accounts, no analytics**
  - All processing and storage is local.
  - Vision and AVKit/AVFoundation are used only on-device.
- **Camera-only input**
  - No photo library APIs or selectors are used.
  - The app requests only camera permission (`NSCameraUsageDescription`).
- **Local notifications only**
  - Daily reminders and weekly reports are scheduled locally with `UNUserNotificationCenter`.
  - Weekly report scheduling uses `BGAppRefreshTask` for best-effort primary report delivery.
- **SwiftData storage**
  - `DailyRecord`, `TrainingAsset`, and `Settings` are stored in local SwiftData models.

## Project structure

- `sun-day/SunscreenTrackApp.swift` — App entrypoint and dependency bootstrapping.
- `sun-day/Shared` — app routing and root shell (`AppRoute`, `AppStateContainer`, `RootView`).
- `sun-day/Models` — SwiftData models.
- `sun-day/Services` — camera coordinators, Vision feature-print service, notifications, calendar analytics, permissions, phrase rotation.
- `sun-day/Views` — onboarding, home, barcode, selfie, live video verify, training, calendar, weekly report views.
- `sun-dayTests` — unit tests for day status, streak, and phrase rotation.
- `sun-dayUITests` — default boilerplate UI test target.

## Build/run

1. Open `sun-day.xcodeproj` in Xcode.
2. Select a simulator or device running iOS 18.0+.
3. Build and run.

The app requires:

- Camera permission (for barcode, selfie, and training capture)
- Notification permission (for reminders and weekly reports)

## Privacy note

- Barcode and object recognition happen entirely on-device.
- Feature prints are serialized locally and stored with SwiftData only.
- No images are sent to servers or cloud storage.
- No third-party SDKs are used.

## Assumptions documented in code

- Default daily reminder: **08:00** local time.
- Default weekly report reminder: **Sunday 18:00** local time.
- Video verification threshold uses a fixed distance threshold and consecutive-frame debounce (2+ seconds equivalent).
- `SunscreenTrack` module name is set in the project so unit tests import `@testable import SunscreenTrack`.

