# Sunclub App

Sunclub is an offline iOS app for maintaining a daily sunscreen habit. The app uses an on-device FastVLM model to detect whether the live camera sees sunscreen and logs the day when the model answers `YES`.

## Flow

1. `Welcome`
   - Intro screen with the Sunclub mark and `Get Started`.
2. `Enable Notifications`
   - Requests local notification permission.
   - Onboarding completes whether permission is allowed or denied.
3. `Home Dashboard`
   - Shows the greeting, current streak card, `Verify Now`, and a gear button for Settings.
4. `Verify - Camera`
   - Uses the rear camera and `SunscreenDetectionCoordinator`.
   - Sends frames to `FastVLMService` with the fixed sunscreen prompt.
   - Logs the day after two consecutive `YES` answers.
5. `Verify Success`
   - Confirms the verification and shows the updated streak.
6. `Weekly Summary`
   - Shows the real `appliedCount / 7` result for the past week.
7. `Settings`
   - `Notification Time` updates the daily reminder time.
   - `Manage Subscription` hands off to Apple subscription management when available.

## What Still Works

- Daily verification stays fully on-device and records a `DailyRecord`.
- Reminder scheduling still uses `UNUserNotificationCenter` and the existing weekly background refresh path.
- Streaks and weekly summaries still come from local `CalendarAnalytics`.
- All data remains local. There are no accounts, uploads, or analytics SDKs.

## Project Structure

- `Sunclub/Shared`
  - app routing, previews, root navigation, and app-wide UI shell/theme
- `Sunclub/Views`
  - onboarding, home, camera verification, summary, and settings flow
- `Sunclub/Services`
  - FastVLM inference, camera capture, notifications, subscriptions, and analytics
- `Sunclub/Models`
  - `Settings`, `DailyRecord`, and `VerificationMethod`
- `FastVLM`
  - restored framework source and downloaded model assets
- `SunclubTests`
  - analytics, parser, reminder persistence, and verification-success state tests
- `SunclubUITests`
  - flow tests that use `UITEST_MODE` and canned camera/model behavior instead of real camera/notification permissions

## Build and Run

1. From the repo root, run `mise install`.
2. Run `just download-model`.
3. Run `just generate`.
4. Run `just run` to build the debug app, install it on the default simulator, and launch it.
5. If you prefer Xcode, open `app/Sunclub.xcworkspace` after generating the project.
6. Build and run the `Sunclub` scheme.

## Just Targets

- `just check-model`
- `just generate`
- `just build`
- `just run`
- `just test-unit`
- `just test-ui`
- `just test`
- `just ci`

`just check-model` verifies that `app/FastVLM/model/config.json` exists and exits with guidance if it does not. `just download-model` runs `scripts/get_pretrained_mlx_model.sh` directly, and `just prepare-model` remains a compatibility alias for the same check.

## Notes

- FastVLM runs entirely on-device. No camera frames leave the device.
- Daily reminders and the `Verify Now` action route directly to the camera verification screen.
- `Manage Subscription` is a system handoff, not an in-app billing screen.
- UITests use `UITEST_MODE` and bypass real camera/model and notification permissions so the flow can be exercised end to end in automation.
