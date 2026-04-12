# Sunclub App

Sunclub is an iPhone-only iOS app for maintaining a daily sunscreen habit through quick manual check-ins, streak tracking, weekly summaries, widget status surfaces, and reminder settings.

## Flow

1. `Home / Lock Screen / Control Center`
   - `Log Today` logs in place when the day is still open.
   - Logged-state widgets switch to status and navigation instead of re-logging.
   - `Streak`, `Stats`, and `Calendar` widgets summarize current progress with low-text layouts.
   - Control Center exposes `Log Today`, `Summary`, and `History`.
2. `Welcome`
   - Intro screen with the Sunclub mark and `Get Started`.
3. `Enable Notifications`
   - Requests local notification permission.
   - Onboarding completes whether permission is allowed or denied.
4. `Home Dashboard`
   - Shows the greeting, current streak card, manual logging, product scanner, and a gear button for Settings.
5. `Verify Success`
   - Confirms the verification and shows the updated streak.
6. `Weekly Summary`
   - Shows the real `appliedCount / 7` result for the past week.
   - Surfaces the most-used logged SPF and recent notes when that metadata exists.
7. `Settings`
   - `Notification Time` updates the daily reminder time.
   - Reapply reminders, iCloud sync state, local backup controls, and `Recovery & Changes` live here.
8. `Recovery & Changes`
   - Lists undoable change batches, imported backups, and any auto-merged conflicts that still need review.
   - Lets the user undo or redo recent changes, restore the pre-import state, and explicitly publish imported local backups to iCloud.

## What Still Works

- Daily logging records a `DailyRecord`.
- Scanned SPF values stay available as separate manual-log options, and fresh logs preselect the most recent logged SPF.
- Reminder scheduling still uses `UNUserNotificationCenter` and the existing weekly background refresh path.
- Streaks and weekly summaries still come from local `CalendarAnalytics`.
- Optional SPF and notes metadata now feed a lightweight recap inside `Weekly Summary` and day detail in `History`.
- The projected app state still works fully offline, but revision history now syncs through the user's private iCloud database by default.
- Local backup export/import still works without an account migration step. Import changes only the local device until the user explicitly publishes the imported batches to iCloud.
- The live SwiftData store stays in the app sandbox; widgets read a compact mirrored snapshot from an app-group `UserDefaults` store.
- Sunclub still has no app-owned accounts or analytics SDKs. The only sync path is the user's private iCloud database.

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
3. Run `just run` to build the `SunclubDev` debug app, install it on the dedicated run simulator, and launch it.
4. If you prefer Xcode, open `app/Sunclub.xcworkspace` after generating the project.
5. Build and run the `SunclubDev` scheme for local development or the `Sunclub` scheme for release work.

## Release Modes

- `SunclubDev` is the default local flavor and installs side by side with TestFlight.
- `Sunclub` is the production/TestFlight flavor used by `just appstore-archive`.
- `just release-tag 1.2.3` creates and pushes the `v1.2.3` tag that triggers the TestFlight GitHub Actions workflow.

## Just Targets

- `just bootstrap`
- `just icons`
- `just generate`
- `just build`
- `just run`
- `just cloudkit-save-token`
- `just cloudkit-export-schema`
- `just cloudkit-validate-schema`
- `just cloudkit-import-schema`
- `just cloudkit-reset-dev`
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
- `just release-tag 1.2.3`
- `just ci`

`just clean-build` removes build artifacts and the generated workspace, `just clean-generated` also removes repo-local caches and environments such as `.venv`, `.mise`, `.cache`, `.config`, `.state`, and `__pycache__`, and `just clean` runs the full cleanup chain.

## Notes

- Daily reminders route directly to manual logging.
- The widget `Log Today` action routes into the same success flow used by manual logging.
- Settings and history edits now write revision batches so changes stay undoable and streaks are recomputed from the projected day timeline.
- Backup imports stay local-first. Use `Recovery & Changes` if you need to undo an import or publish it to iCloud afterward.
- The CloudKit helper scripts use repo-local defaults from `scripts/tooling/sunclub.env` and write exported schemas to `.state/cloudkit/` unless `CLOUDKIT_SCHEMA_FILE` overrides the path.
- The widget suite now covers all iPhone Home Screen and Lock Screen families supported by the app:
  - `Log Today`: `systemSmall`, `accessoryInline`, `accessoryCircular`, `accessoryRectangular`
  - `Streak`: `systemSmall`, `systemMedium`, `accessoryCircular`, `accessoryRectangular`
  - `Stats`: `systemMedium`, `systemLarge`, `accessoryInline`, `accessoryRectangular`
  - `Calendar`: `systemMedium`, `systemLarge`, `accessoryInline`, `accessoryRectangular`
- Widgets and controls route through shared widget routes for summary, history, and manual-update surfaces.
- The widget `Log Today` action routes into the same success flow used by manual logging.
- Settings and history edits now write revision batches so changes stay undoable and streaks are recomputed from the projected day timeline.
- Backup imports stay local-first. Use `Recovery & Changes` if you need to undo an import or publish it to iCloud afterward.
- The live SwiftData store stays in the app sandbox; widgets read a compact mirrored snapshot from an app-group `UserDefaults` store.
- The CloudKit helper scripts use repo-local defaults from `scripts/tooling/sunclub.env` and write exported schemas to `.state/cloudkit/` unless `CLOUDKIT_SCHEMA_FILE` overrides the path.
- UITests use `UITEST_MODE` and route launch arguments such as `UITEST_ROUTE=manualLog` so the flow can be exercised end to end in automation and screenshot capture.
- Normal build commands regenerate the workspace before building so resolved version metadata reaches the Tuist-generated project.
