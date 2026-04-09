# Home-Exit Reminders ExecPlan

This ExecPlan records the leave-home reminder feature from design through verification. The sections `Progress`, `Decision Log`, and `Outcomes & Retrospective` capture the implementation state that lands in the repo.

## Purpose / Big Picture

Sunclub already supports smarter scheduled reminders, streak-risk nudges, and UV-aware reapply behavior, but the morning reminder still relies only on time. This feature adds an optional Home-based trigger so the app can remind someone right when they first leave home for the day while keeping the existing scheduled reminder as the fallback.

## Progress

- [x] (2026-04-09) Audited the current reminder stack, notification routing, UV location access, settings UI, schema rules, and lifecycle hooks.
- [x] (2026-04-09) Added leave-home reminder settings to the encoded smart-reminder payload with backward-compatible decoding defaults.
- [x] (2026-04-09) Added a shared location manager, local-only leave-home state store, and a monitor that handles Home region enter and exit events.
- [x] (2026-04-09) Wired `AppState`, `NotificationManager`, `SunclubApp`, and `SettingsView` so Home-based reminders, daily fallback suppression, and permission guidance stay consistent.
- [x] (2026-04-09) Added unit coverage for reminder payload decoding, app-state presentation and mutations, and first-exit trigger behavior.
- [x] (2026-04-09) Ran `just test-unit` and `just test-ui` from the repo root after implementation and warning cleanup.

## Decision Log

- Decision: Keep Home configuration inside the existing encoded `smartReminderSettingsData` payload instead of adding new top-level SwiftData fields.
  Rationale: This avoids a schema version bump for a preference-only change and preserves existing backup and revision-history behavior.
  Date/Author: 2026-04-09 / Codex
- Decision: Store same-day leave-home delivery tokens in device-local `UserDefaults`, not SwiftData.
  Rationale: These tokens are operational state, not user history. They should suppress duplicate reminders on the current device without polluting sync, backup, or revision history.
  Date/Author: 2026-04-09 / Codex
- Decision: Keep the weekday and weekend scheduled reminder as the fallback path.
  Rationale: The feature should improve timing precision for opted-in users without creating a dead zone on days when the user stays home or background location is unavailable.
  Date/Author: 2026-04-09 / Codex

## Context and Orientation

Reminder preferences live in `app/Sunclub/Sources/Models/SmartReminderSettings.swift`, notification scheduling lives in `app/Sunclub/Sources/Services/NotificationManager.swift`, lifecycle refresh hooks live in `app/Sunclub/Sources/SunclubApp.swift`, and the user-facing reminder controls live in `app/Sunclub/Sources/Views/SettingsView.swift`.

Live UV already uses location, but only through foreground `When In Use` access. Leave-home reminders add a second location path with background region monitoring and an `Always` permission requirement.

## Plan of Work

1. Extend the smart-reminder payload with an optional Home-based reminder config and keep legacy decode behavior safe.
2. Add a shared location manager and Home-exit monitor that can save Home, monitor a region, and fire one reminder on the first exit of the day.
3. Suppress the same day’s scheduled daily reminder when the leave-home trigger fires, but leave the normal schedule intact as the fallback on non-trigger days.
4. Surface the feature in Settings with explicit permission states, Home setup and reset actions, and a clear optional opt-in flow.
5. Add focused unit and UI coverage, then run the repo validation commands from the root.

## Validation and Acceptance

1. A saved Home plus `Always` permission enables one immediate reminder on the first home exit of the local day when today is still unlogged.
2. The normal weekday or weekend reminder still fires on days when no leave-home trigger occurs before the configured reminder time.
3. If the leave-home reminder fires first, the scheduled daily reminder for that same day is suppressed.
4. Older reminder payloads decode cleanly with leave-home reminders disabled by default.
5. Settings shows understandable states for Home missing, background permission needed, permission denied, and armed monitoring.

## Outcomes & Retrospective

- Outcome: The feature adds an optional Home-based morning trigger without changing the app’s manual-first or offline-first product shape.
- Outcome: The implementation keeps persisted product settings in SwiftData and keeps per-day delivery suppression device-local.
- Verification: `just test-unit` passed with 92 tests and `just test-ui` passed with 30 tests on 2026-04-09.
