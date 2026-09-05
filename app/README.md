# Sunclub App

## Source Availability and License

Sunclub is source-available, not open source. Copyright (c) 2026 Peyton
Randolph. All rights reserved.

This app is distributed under the repo-root PolyForm Strict License 1.0.0. No
source redistribution, binary redistribution, sublicensing, public fork
distribution, App Store or other marketplace publication, or modified or
derivative work is licensed. No trademark rights are granted.

Sunclub is an iPhone-only iOS app for maintaining a daily sunscreen habit through quick manual check-ins, streak tracking, weekly summaries, widget status surfaces, and reminder settings.

## Flow

1. `Home / Lock Screen / Control Center`
   - `Log Today` logs in place when the day is still open.
   - Logged-state widgets switch to status and navigation instead of re-logging.
   - `Streak`, `Stats`, and `Calendar` widgets summarize current progress with low-text layouts.
   - Control Center exposes `Log Today`, `Summary`, and `History`.
   - Apple Shortcuts and URL actions expose supported non-destructive reads and writes.
2. `Welcome`
   - Intro screen with the Sunclub mark, core habit value props, and `Get Started`.
3. `Enable Notifications`
   - Requests local notification permission.
   - Onboarding completes whether permission is allowed or denied.
4. `Home Dashboard`
   - Shows the relative selected date, horizontal timeline, UV forecast blocks, manual logging, product scanner, and a gear button for Settings.
5. `Verify Success`
   - Confirms the verification and shows the updated streak.
6. `Weekly Summary`
   - Shows the real `appliedCount / 7` result for the past week.
   - Surfaces the most-used logged SPF and recent notes when that metadata exists.
7. `Settings`
   - `Notification Time` updates the daily reminder time.
   - Reapply reminders, iCloud sync state, local backup controls, and `Recovery & Changes` live here.
   - Automation controls let users manage Shortcut writes, URL opens, URL writes, and callback details.
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
- The container factory selects and recovers the local store location; widgets read a compact mirrored snapshot from app-group `UserDefaults`.
- The automation runtime backs Apple Shortcuts, Control Center actions, widgets, custom URL scheme actions, and x-callback-url callers. The public contract lives in `../docs/app-automation.md`.
- Sunclub still has no app-owned accounts or analytics SDKs. Public Activity sharing transport remains disabled in production while that feature is outside the visible app.

## Development

From the repository root:

```sh
just bootstrap
just run
```

`just run` builds SunclubDev in Debug, installs it on the run simulator and
launches it. `just build` builds without launching. Both automatically regenerate
when project inputs change. For Xcode editing, use `just generate` and open
`app/Sunclub.xcworkspace`.

See the [architecture map and feature recipe](../docs/architecture.md),
[commands](../docs/commands.md), and mandatory
[data, accessibility and automation gates](../docs/release-gates.md).

SunclubDev installs beside the production Sunclub/TestFlight app. Production
archive/export uses `just appstore-archive`; signing and upload require successful
full CI on the exact SHA. Release and App Review details are in
[TestFlight](../docs/testflight-release.md) and
[App Store submission](../docs/app-store-submission.md).
