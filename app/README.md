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
- `Sunclub/FastVLMRuntime`
  - vendored FastVLM runtime files from Apple’s sample app
- `Sunclub/FastVLMModel`
  - local model folder populated by `get_pretrained_mlx_model.sh`
- `SunclubTests`
  - analytics, parser, reminder persistence, and verification-success state tests
- `SunclubUITests`
  - flow tests that use `UITEST_MODE` and canned camera/model behavior instead of real camera/notification permissions

## Build and Run

1. Run `chmod +x get_pretrained_mlx_model.sh`.
2. Run `./get_pretrained_mlx_model.sh --model 0.5b --dest Sunclub/FastVLMModel/model`.
3. Open [`/Users/peyton/Projects/sunclub/app/Sunclub.xcodeproj`](/Users/peyton/Projects/sunclub/app/Sunclub.xcodeproj) in Xcode.
4. Select an iPhone simulator or device running iOS 18.2+.
5. Build and run the `Sunclub` scheme.

## Fastlane

Tooling is pinned at the repo root in [`/Users/peyton/Projects/sunclub/mise.toml`](/Users/peyton/Projects/sunclub/mise.toml).

1. From the repo root, run `mise install`.
2. Run Fastlane from [`/Users/peyton/Projects/sunclub/app`](/Users/peyton/Projects/sunclub/app):

- `mise exec -- fastlane prepareModelLane`
- `mise exec -- fastlane testsLane`
- `mise exec -- fastlane buildLane`

Release automation is also defined:

- `mise exec -- fastlane betaLane`
- `mise exec -- fastlane releaseLane`

`prepareModelLane` downloads the FastVLM `0.5B` model into `Sunclub/FastVLMModel/model` if it is missing. `betaLane` and `releaseLane` expect App Store Connect API key environment variables before upload:

- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_PATH` or `APP_STORE_CONNECT_API_KEY_CONTENT`

## Notes

- FastVLM runs entirely on-device. No camera frames leave the device.
- Daily reminders and the `Verify Now` action route directly to the camera verification screen.
- `Manage Subscription` is a system handoff, not an in-app billing screen.
- UITests use `UITEST_MODE` and bypass real camera/model and notification permissions so the flow can be exercised end to end in automation.
