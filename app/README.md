# Sunclub App

Sunclub is an iPhone-only iOS app for maintaining a daily sunscreen habit. Manual logging is always available, and bottle scanning stays behind an internal feature flag that is disabled by default.

## Flow

1. `Welcome`
   - Intro screen with the Sunclub mark and `Get Started`.
2. `Enable Notifications`
   - Requests local notification permission.
   - Onboarding completes whether permission is allowed or denied.
3. `Home Dashboard`
   - Shows the greeting, current streak card, manual logging, and a gear button for Settings.
4. `Verify - Camera`
   - Available only when bottle scan is enabled.
   - Uses the rear camera and `SunscreenDetectionCoordinator`.
   - Requests the FastVLM model on demand the first time camera verification is needed.
   - Sends frames to `FastVLMService` with the fixed sunscreen prompt after the model is ready.
   - Logs the day after two consecutive `YES` answers.
5. `Verify Success`
   - Confirms the verification and shows the updated streak.
6. `Weekly Summary`
   - Shows the real `appliedCount / 7` result for the past week.
7. `Settings`
   - `Notification Time` updates the daily reminder time.
   - Reapply reminder settings stay local to the device.

## What Still Works

- Daily verification stays fully on-device and records a `DailyRecord`.
- Reminder scheduling still uses `UNUserNotificationCenter` and the existing weekly background refresh path.
- Streaks and weekly summaries still come from local `CalendarAnalytics`.
- All data remains local after the one-time verification model download. There are no accounts, uploads, or analytics SDKs.

## Project Structure

- `Sunclub/Shared`
  - app routing, previews, root navigation, and app-wide UI shell/theme
- `Sunclub/Views`
  - onboarding, home, manual logging, camera verification, summary, and settings flow
- `Sunclub/Services`
  - FastVLM inference, model download, camera capture, notifications, and analytics
- `Sunclub/Models`
  - `Settings`, `DailyRecord`, and `VerificationMethod`
- `FastVLM`
  - framework source and model resolution helpers
- `SunclubTests`
  - analytics, parser, reminder persistence, and model-download tests
- `SunclubUITests`
  - flow tests that use `UITEST_MODE` and deterministic routes instead of real camera/notification permissions
- `../tests`
  - repo-level Python validation coverage for App Store metadata and submission tooling

## Build and Run

1. From the repo root, run `just bootstrap`.
2. Run `just generate`.
3. Run `just run` to build the debug app, install it on the dedicated run simulator, and launch it.
4. Bottle scan is disabled by default. To test camera verification locally, add the `FEATURE_ENABLE_BOTTLE_SCAN` launch argument and run `just download-model` before launching.
5. If you prefer Xcode, open `app/Sunclub.xcworkspace` after generating the project.
6. Build and run the `Sunclub` scheme.

## Just Targets

- `just bootstrap`
- `just icons`
- `just generate`
- `just build`
- `just run`
- `just clean-build`
- `just clean-generated`
- `just clean-model`
- `just clean`
- `just lint`
- `just fmt`
- `just test-unit`
- `just test-ui`
- `just test-python`
- `just test`
- `just ci-lint`
- `just ci-python`
- `just ci-build`
- `just appstore-validate`
- `just appstore-screenshots`
- `just appstore-archive`
- `just ci`

`just download-model` stages the FastVLM files into `app/Generated/FastVLMODR/model` so local debug builds can exercise the same asset layout used for On-Demand Resources. The main generate, build, run, and test flows no longer require that staging step.

`just clean-build` removes build artifacts and the generated workspace, `just clean-generated` also removes generated eval outputs plus repo-local caches and environments such as `.venv`, `.mise`, `.cache`, `.config`, `.state`, and `__pycache__`, `just clean-model` also clears the staged FastVLM model, and `just clean` runs the full cleanup chain.

## Notes

- FastVLM runs entirely on-device after the model download completes. No camera frames leave the device.
- Daily reminders route to the currently enabled check-in flow. With the default config, that is manual logging.
- UITests use `UITEST_MODE` and route launch arguments such as `UITEST_ROUTE=verifyCamera` so the flow can be exercised end to end in automation and screenshot capture.
