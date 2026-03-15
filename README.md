# Sunclub

Sunclub is an offline iOS app for daily sunscreen verification. The current app follows a 9-screen flow based on the latest mockups while keeping the real on-device barcode scan, bottle-model training, live verification, streak tracking, weekly summary, and reminder scheduling behavior.

## Flow

1. `Welcome`
   - Intro screen with the Sunclub mark and `Get Started`.
2. `Scan Barcode`
   - Uses the rear camera and `BarcodeScannerCoordinator`.
   - The first valid barcode is saved as the expected bottle barcode.
3. `Train Photos`
   - Uses the rear camera and `TrainingCoordinator`.
   - Captures exactly 5 photos to build the on-device bottle model.
4. `Enable Notifications`
   - Requests local notification permission.
   - Onboarding completes whether permission is allowed or denied.
5. `Home Dashboard`
   - Shows the greeting, current streak card, `Verify Now`, and a gear button for Settings.
6. `Verify - Camera`
   - Uses `VideoVerificationCoordinator`.
   - Automatically verifies when the trained bottle model is recognized for the required duration.
7. `Verify Success`
   - Confirms the verification and shows the updated streak.
8. `Weekly Summary`
   - Shows the real `appliedCount / 7` result for the past week.
9. `Settings`
   - `Notification Time` updates the daily reminder time.
   - `Retrain Bottle Model` clears the saved training features and reopens the training flow.
   - `Manage Subscription` hands off to Apple subscription management when available.

## What Still Works

- Barcode capture stays on-device and persists the expected bottle barcode in SwiftData.
- Bottle training still stores local feature-print data in `TrainingAsset`.
- Daily verification still uses the live camera matcher and records a `DailyRecord`.
- Streaks and weekly summaries still come from local `CalendarAnalytics`.
- Reminder scheduling still uses `UNUserNotificationCenter` and the existing weekly background refresh path.
- All data remains local. There are no accounts, uploads, or analytics SDKs.

## Project Structure

- `app/Sunclub/Shared`
  - app routing, root navigation, and the mockup-driven screen shell/theme
- `app/Sunclub/Views`
  - the 9-screen product flow
- `app/Sunclub/Services`
  - barcode scan, training capture, live verification, notifications, and analytics
- `app/Sunclub/Models`
  - `Settings`, `DailyRecord`, and `TrainingAsset`
- `app/SunclubTests`
  - analytics, reminder persistence, retraining, and verification-success state tests
- `app/SunclubUITests`
  - flow tests that use UITEST-only demo actions instead of real camera/notification permissions

## Build and Run

1. Open [`/Users/peyton/.codex/worktrees/0845/sunclub/app/Sunclub.xcodeproj`](/Users/peyton/.codex/worktrees/0845/sunclub/app/Sunclub.xcodeproj) in Xcode.
2. Select an iPhone simulator or device running iOS 18.0+.
3. Build and run the `Sunclub` scheme.

## Notes

- `Manage Subscription` is a system handoff, not an in-app billing screen.
- UITests use `UITEST_MODE` and bypass real camera and notification permissions so the new flow can be exercised end to end in automation.
