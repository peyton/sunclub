# Sunclub App

Sunclub is an iPhone-only iOS app for maintaining a daily sunscreen habit through quick manual check-ins, streak tracking, weekly summaries, and reminder settings.

## Flow

1. `Welcome`
   - Intro screen with the Sunclub mark and `Get Started`.
2. `Enable Notifications`
   - Requests local notification permission.
   - Onboarding completes whether permission is allowed or denied.
3. `Home Dashboard`
   - Shows the greeting, current streak card, manual logging, and a gear button for Settings.
4. `Verify Success`
   - Confirms the verification and shows the updated streak.
5. `Weekly Summary`
   - Shows the real `appliedCount / 7` result for the past week.
   - Surfaces the most-used logged SPF and recent notes when that metadata exists.
6. `Settings`
   - `Notification Time` updates the daily reminder time.
   - Reapply reminder settings stay local to the device.

## What Still Works

- Daily logging records a `DailyRecord`.
- Reminder scheduling still uses `UNUserNotificationCenter` and the existing weekly background refresh path.
- Streaks and weekly summaries still come from local `CalendarAnalytics`.
- Optional SPF and notes metadata now feed a lightweight recap inside `Weekly Summary` and day detail in `History`.
- All data remains local on device. There are no accounts, uploads, or analytics SDKs.

## Project Structure

- `Sunclub/Shared`
  - app routing, previews, root navigation, and app-wide UI shell/theme
- `Sunclub/Views`
  - onboarding, home, manual logging, summary, and settings flow
- `Sunclub/Services`
  - notifications, persistence helpers, analytics, and supporting services
- `Sunclub/Models`
  - `Settings`, `DailyRecord`, and `VerificationMethod`
- `SunclubTests`
  - analytics, reminder persistence, normalization, and model tests
- `SunclubUITests`
  - flow tests that use `UITEST_MODE` and deterministic routes
- `../tests`
  - repo-level Python validation coverage for App Store metadata and submission tooling

## Build and Run

1. From the repo root, run `just bootstrap`.
2. Run `just generate`.
3. Run `just run` to build the debug app, install it on the dedicated run simulator, and launch it.
4. If you prefer Xcode, open `app/Sunclub.xcworkspace` after generating the project.
5. Build and run the `Sunclub` scheme.

## Just Targets

- `just bootstrap`
- `just icons`
- `just generate`
- `just build`
- `just run`
- `just clean-build`
- `just clean-generated`
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

`just clean-build` removes build artifacts and the generated workspace, `just clean-generated` also removes repo-local caches and environments such as `.venv`, `.mise`, `.cache`, `.config`, `.state`, and `__pycache__`, and `just clean` runs the full cleanup chain.

## Notes

- Daily reminders route directly to manual logging.
- UITests use `UITEST_MODE` and route launch arguments such as `UITEST_ROUTE=manualLog` so the flow can be exercised end to end in automation and screenshot capture.
