# Outside Log and Follow-Through ExecPlan

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds. This repository does not check in `PLANS.md`, so this document follows the shared execution-plan guidance from `/Users/peyton/.agents/PLANS.md`.

This plan builds on the already-completed feature work documented in `docs/widget-log-today-execplan.md`, `docs/smarter-reminders-execplan.md`, `docs/spf-notes-insights-execplan.md`, and `docs/uv-aware-home-card-reminders-execplan.md`. Those documents explain how the current widget, reminder, review, and UV seams were introduced. This document must stay self-contained, so the key facts are repeated below.

## Purpose / Big Picture

Sunclub already lets a user log sunscreen from Home, reminders, and widgets, but the current product still loses momentum in the middle and at the edges of the loop. After this change, a user can trigger `Log Sunscreen` from outside the app through an App Intent, open the app and immediately recover missed logging for today or yesterday from Home, get smarter manual defaults based on past SPF and notes, check in when they actually reapplied, see whether reminders are healthy or broken, accept reminder-time coaching based on their real habits, opt into live WeatherKit UV data with a safe fallback, and read a slightly richer monthly review without leaving the current app shape.

The change matters because it improves the core retention loop instead of adding new product surface area. A user should be able to prove the change works by running the app, checking Home and Settings, triggering the new shortcut and reminder paths, and observing new unit, migration, and UI tests that fail before the implementation and pass after it.

## Progress

- [x] (2026-04-02 11:48Z) Audited the current app state, persistence schema, reminders, widgets, onboarding, Home, manual log, history, weekly review, and test seams.
- [x] (2026-04-02 11:56Z) Read the existing related ExecPlans so this pass extends the shipped directions instead of forking them.
- [x] (2026-04-02 12:07Z) Added this combined ExecPlan before any feature edits so the work has one tracked design and verification record.
- [x] (2026-04-02 12:21Z) Merged `origin/master` into the worktree, reconciled the newer backup harness and tooling changes, and kept the feature work on top of the merged base.
- [x] (2026-04-02 13:04Z) Froze the current SwiftData schema as immutable `SunclubSchemaV2`, added `SunclubSchemaV3`, and migrated new reapply and settings fields with migration-test coverage.
- [x] (2026-04-02 13:42Z) Added shared data models and app-state helpers for manual-log defaults, reminder coaching, notification health, reapply tracking, monthly review insights, and UV source state.
- [x] (2026-04-02 13:58Z) Added a `Log Sunscreen` App Intent and App Shortcut that reuse the shared quick-log behavior.
- [x] (2026-04-02 14:27Z) Updated Home, manual log, settings, and history/month review surfaces to expose recovery actions, smarter defaults, reminder coaching, notification health, live UV controls, and reapply completion state.
- [x] (2026-04-02 15:05Z) Added and updated unit tests, migration tests, and UI tests that cover the new storage, analytics, routing, outside-app entry points, and visible UI.
- [x] (2026-04-02 15:02Z) Regenerated the Tuist workspace and ran the repo validation commands from the repository root, including the aggregate `just ci` path.

## Surprises & Discoveries

- Observation: `SunclubSchemaV2` is currently not frozen. It points at the live `DailyRecord` and `Settings` models, so any persisted-field change would silently mutate the historical schema definition unless it is fixed first.
  Evidence: `app/Sunclub/Sources/Models/SunclubSchema.swift` defines `SunclubSchemaV2.models` as `[DailyRecord.self, Settings.self]` without nested immutable model types.
- Observation: The widget feature currently relies on a URL deep link rather than shared persistence or an intent-based action path.
  Evidence: `app/Sunclub/WidgetExtension/Sources/SunclubLogTodayWidget.swift` uses `widgetURL(SunclubWidgetDeepLink.logTodayURL)`, and `app/Sunclub/Sources/Shared/SunclubDeepLink.swift` immediately records success when handling `sunclub://widget/log-today`.
- Observation: Notification health is not represented anywhere in persisted state or app state today. The app requests authorization during onboarding and schedules reminders, but it never audits current authorization or pending-request health after that.
  Evidence: reminder scheduling lives in `app/Sunclub/Sources/Services/NotificationManager.swift`, while `SettingsView.swift` and `HomeView.swift` have no notification-status surface.
- Observation: The current UV service is fully synchronous and heuristic-only, which means live UV data must be introduced behind a new asynchronous service boundary instead of being bolted onto the current `fetchUVIndex()` shape.
  Evidence: `app/Sunclub/Sources/Services/UVIndexService.swift` computes the index from time and season and has no async or location-aware API.
- Observation: Merging `origin/master` introduced a newer backup test harness plus shell-style defaults in `scripts/tooling/sunclub.env`, and the Python config parser did not yet resolve `${VAR:-default}` expressions.
  Evidence: `just ci` initially failed in `tests/test_tooling_config.py` with `CONFIG.app_workspace == '${APP_WORKSPACE:-app/Sunclub.xcworkspace}'` until the parser was updated to resolve shell-default syntax.
- Observation: The monthly review cards were rendering correctly on screen, but XCTest could not reliably locate the inner value node by accessibility identifier in the aggregate UI run.
  Evidence: a simulator screenshot of the `UITEST_ROUTE=history` plus `UITEST_SEED_HISTORY=monthlyReview` path showed the cards visibly present, while `testHistoryShowsMonthlyReviewInsights` failed until the test asserted the visible card labels instead.

## Decision Log

- Decision: Keep this feature pass local-first and additive. The app will still function fully offline, and WeatherKit will be treated as an optional source of truth layered behind the existing heuristic.
  Rationale: The repo and app spec both emphasize offline usefulness and no required server dependency. A failed weather request or denied location permission cannot block the Home UV card or reminder flow.
  Date/Author: 2026-04-02 / Codex
- Decision: Track reapply completion on the existing daily record instead of introducing a separate persistent model for each reapplication event.
  Rationale: The request asks for a lightweight check-in that makes the reminder loop meaningful. A count plus last check-in time is enough for Home status, review insights, and future reminder behavior without expanding the data model into a mini event log.
  Date/Author: 2026-04-02 / Codex
- Decision: Surface reminder coaching as recommendations in Settings rather than silently mutating the saved reminder times.
  Rationale: Coaching should be grounded in the user’s real behavior, but reminder time changes are still user preferences. Showing recommendations with one-tap acceptance preserves trust and keeps the feature testable.
  Date/Author: 2026-04-02 / Codex
- Decision: Treat notification health as two user-visible states: denied permission and stale scheduling.
  Rationale: These are the highest-value failure modes for the current app loop. Denied permissions need a route to system settings, while stale scheduling needs a local repair path that resubmits reminders.
  Date/Author: 2026-04-02 / Codex

## Outcomes & Retrospective

Shipped:

- A shared quick-log path now powers the widget deep link and a new `Log Sunscreen` App Intent/App Shortcut so logging is available in one tap from outside the app.
- `DailyRecord` now tracks lightweight reapply completion state, `Settings` persists live-UV preference and reminder-health bookkeeping, and `SunclubSchemaV3` migrates older stores safely.
- Home now exposes `Log Today`, `Backfill Yesterday`, reapply follow-through, and notification-health recovery states directly instead of burying the recovery loop in History or Settings.
- Manual log now prefills from recent behavior, including last-used SPF, a same-as-last-time chip, and recent reusable note snippets.
- Settings now surfaces reminder coaching recommendations, notification-health repair actions, and live WeatherKit UV opt-in with graceful heuristic fallback.
- History month stats now include best weekday, hardest weekday, and most common SPF.

Verification:

- `just generate`
- `just test-unit`
- `xcodebuild test -workspace app/Sunclub.xcworkspace -scheme Sunclub -configuration Debug -destination 'id=9D98F000-212A-4DB7-871C-842973549F32' -derivedDataPath .DerivedData/ui-focused -only-testing:SunclubUITests/SunclubUITests/testSettingsShowsReminderCoachingAndNotificationHealth`
- `xcodebuild test -workspace app/Sunclub.xcworkspace -scheme Sunclub -configuration Debug -destination 'id=9D98F000-212A-4DB7-871C-842973549F32' -derivedDataPath .DerivedData/ui-focused -only-testing:SunclubUITests/SunclubUITests/testHistoryShowsMonthlyReviewInsights`
- `just ci`

The final aggregate `just ci` run passed, which means lint, Python tests, iOS unit tests, iOS UI tests, and the release build all completed successfully on the merged branch. The only intentional omission is deeper per-reapply event history; this pass keeps reapply tracking lightweight with a count and last completion time, which was sufficient for the requested follow-through loop.

## Context and Orientation

The iOS app is generated with Tuist from manifests in `app/`. The main target definition is `app/Sunclub/Project.swift`, and the workspace manifest is `app/Workspace.swift`. App launch and UI-test launch-argument handling live in `app/Sunclub/Sources/SunclubApp.swift`.

App-level state is owned by `app/Sunclub/Sources/Services/AppState.swift`. The local persistence layer uses SwiftData, Apple’s object graph and persistence framework, with model types in `app/Sunclub/Sources/Models/` and the versioned schema plus migration plan in `app/Sunclub/Sources/Models/SunclubSchema.swift`. A “schema version” is the frozen record of what persisted fields existed at a specific shipped point in time. Because this repository stores user history locally, every persisted-field change must create a new schema version and migration stage.

The current daily record is `DailyRecord` in `app/Sunclub/Sources/Models/DailyRecord.swift`. It already stores one row per calendar day plus optional SPF and notes. The current settings model is `Settings` in `app/Sunclub/Sources/Models/Settings.swift`, with smart-reminder configuration encoded through `app/Sunclub/Sources/Models/SmartReminderSettings.swift`.

Notification scheduling lives in `app/Sunclub/Sources/Services/NotificationManager.swift`, and reminder timing logic lives in `app/Sunclub/Sources/Services/ReminderPlanner.swift`. The current UV stub is `app/Sunclub/Sources/Services/UVIndexService.swift`. Weekly review and history analytics currently live in `app/Sunclub/Sources/Services/CalendarAnalytics.swift` and `app/Sunclub/Sources/Services/SunscreenUsageInsights.swift`.

The main screens affected here are `app/Sunclub/Sources/Views/HomeView.swift`, `app/Sunclub/Sources/Views/ManualLogView.swift`, `app/Sunclub/Sources/Views/SettingsView.swift`, `app/Sunclub/Sources/Views/HistoryView.swift`, and `app/Sunclub/Sources/Views/WeeklyReportView.swift`. Shared routes live in `app/Sunclub/Sources/Shared/AppRoute.swift`. Widget code lives under `app/Sunclub/WidgetExtension/Sources/`.

Unit tests live in `app/Sunclub/Tests/`. UI tests live in `app/Sunclub/UITests/`. The existing test harness already supports launch arguments such as `UITEST_MODE`, `UITEST_ROUTE=...`, `UITEST_URL=...`, seeded history, and seeded UV state. This feature should extend those seams rather than introducing a second test-only configuration path.

## Plan of Work

The first milestone is persistence safety and shared logic. Freeze the current live persisted models into an immutable `SunclubSchemaV2` definition, then introduce `SunclubSchemaV3` as the runtime schema. Add only the new persisted fields needed for this feature: the daily record must gain lightweight reapply-completion state, and settings must gain the minimum new fields for reminder-health bookkeeping and live-UV preference. The migration stage from V2 to V3 must preserve existing records and seed sensible defaults for the new properties. Add a migration test that opens a V2 store, migrates it, and proves the new fields are populated correctly.

The second milestone is analytics and app-state support. Add pure helper types that compute manual-log defaults from existing records, compute reminder-time coaching suggestions from recent weekday and weekend log times, compute richer monthly review insights for the selected month, and describe notification-health state in plain language. Update `AppState` so views can request these presentations without embedding business logic in SwiftUI bodies. The new `AppState` responsibilities must include recording a reapply check-in, computing whether today or yesterday needs recovery, refreshing notification health, and refreshing UV readings asynchronously with a source label that distinguishes live WeatherKit data from heuristic fallback.

The third milestone is feature UI. Update `ManualLogView` and any shared log-field component so a fresh manual entry preselects the most recently used SPF, offers a “same as last time” action, and shows a short list of reusable note chips pulled from recent distinct notes. Update `HomeView` so open-day recovery is visible without going through History: when today is not logged, show `Log Today`; when yesterday is missing, show `Backfill Yesterday`; when a reapply reminder matters, show lightweight reapply status and one-tap completion. Update `SettingsView` to show reminder coaching recommendations, notification health with repair actions, and optional live-UV controls. Update `HistoryView` month stats so the monthly section shows best weekday, hardest weekday, and most common SPF for the displayed month while keeping the current lightweight tone.

The fourth milestone is outside-app entrypoints. Add a `Log Sunscreen` App Intent plus an `AppShortcutsProvider` so the action is available as a system shortcut outside the app. The intent must reuse the same daily-recording behavior as the current widget deep link, including reapply reminder scheduling and streak presentation state, without creating a second persistence path. If the intent needs a foreground path for correctness, it should still remain a one-tap outside-app entry. The existing widget deep link may stay in place unless converting it to the shared intent is clearly smaller and does not expand risk.

The fifth milestone is verification. Extend unit coverage around the new analytics, app-state mutations, reminder coaching, notification health, live-UV fallback behavior, and App Intent execution. Extend UI-test launch seeding for the new Home, Settings, and History states. Add UI tests that prove Home recovery actions appear, manual defaults appear, the monthly review shows the new patterns, and the settings surfaces show coaching and notification-health states. Regenerate the Tuist workspace and run the relevant repo commands from the repository root.

## Concrete Steps

From the repository root, implement and verify in this order:

1. Freeze the schema and add migration support in:

       app/Sunclub/Sources/Models/DailyRecord.swift
       app/Sunclub/Sources/Models/Settings.swift
       app/Sunclub/Sources/Models/SunclubSchema.swift
       app/Sunclub/Tests/MigrationTests.swift

2. Add pure helper types and app-state support in:

       app/Sunclub/Sources/Services/AppState.swift
       app/Sunclub/Sources/Services/CalendarAnalytics.swift
       app/Sunclub/Sources/Services/SunscreenUsageInsights.swift
       app/Sunclub/Sources/Services/ReminderPlanner.swift
       app/Sunclub/Sources/Services/NotificationManager.swift
       app/Sunclub/Sources/Services/UVIndexService.swift
       app/Sunclub/Sources/Services/...

3. Update views and routing in:

       app/Sunclub/Sources/Shared/AppRoute.swift
       app/Sunclub/Sources/Shared/RootView.swift
       app/Sunclub/Sources/Shared/SunManualLogFields.swift
       app/Sunclub/Sources/Views/HomeView.swift
       app/Sunclub/Sources/Views/ManualLogView.swift
       app/Sunclub/Sources/Views/SettingsView.swift
       app/Sunclub/Sources/Views/HistoryView.swift
       app/Sunclub/Sources/Views/WeeklyReportView.swift

4. Add the App Intent and any shared shortcut plumbing in app and, if needed, widget sources.

5. Extend tests in:

       app/Sunclub/Tests/
       app/Sunclub/UITests/SunclubUITests.swift

6. Regenerate and verify with:

       just generate
       just test-unit
       just test-ui
       just ci-build

As work proceeds, this section must be updated with the exact commands actually executed and the key observed results.

Actual verification commands run:

    just generate
    just test-unit
    xcodebuild test -workspace app/Sunclub.xcworkspace -scheme Sunclub -configuration Debug -destination 'id=9D98F000-212A-4DB7-871C-842973549F32' -derivedDataPath .DerivedData/ui-focused -only-testing:SunclubUITests/SunclubUITests/testSettingsShowsReminderCoachingAndNotificationHealth
    xcodebuild test -workspace app/Sunclub.xcworkspace -scheme Sunclub -configuration Debug -destination 'id=9D98F000-212A-4DB7-871C-842973549F32' -derivedDataPath .DerivedData/ui-focused -only-testing:SunclubUITests/SunclubUITests/testHistoryShowsMonthlyReviewInsights
    just ci

Observed results:

- `just test-unit` passed with 67 tests and 0 failures.
- The focused UI reruns passed after fixing the reminder-coaching seed and monthly-review XCTest assertions.
- `just ci` passed end to end, including lint, Python tests, unit tests, UI tests, and `ci-build`.

## Validation and Acceptance

The change is complete when all of the following are true:

1. A system shortcut based on a new App Intent can log sunscreen from outside the app in one user action and reuses the same daily-record path as the current app flow.
2. A fresh manual log preselects the last-used SPF, offers a same-as-last-time action, and exposes reusable note snippets derived from existing logs.
3. Reapply reminders now have a completion loop: the app can record that the user reapplied and can surface that state on the same day.
4. Home surfaces direct recovery actions for an open today and a missing yesterday instead of requiring History navigation first.
5. Settings can recommend better weekday and weekend reminder times based on the user’s actual local logging times and lets the user accept the recommendation explicitly.
6. Settings or Home clearly show when notifications are denied or when reminder scheduling is stale, and the UI offers a repair path that either opens system settings or refreshes reminders.
7. UV status uses WeatherKit when the user opts in and live data plus location are available, but gracefully falls back to the heuristic path when they are not.
8. The monthly review surface shows best weekday, hardest weekday, and most common SPF for the displayed month.
9. The migration test proves a V2 store upgrades cleanly to V3 with preserved existing data and correct defaults for new fields.
10. Unit tests and UI tests cover the new behavior and pass through the repo’s supported commands.

## Idempotence and Recovery

`just generate` is safe to rerun. The migration test must create and delete its own temporary store so repeated runs do not contaminate one another. New analytics and reminder-health helpers must remain pure or cache-safe so repeated app activation does not duplicate state or create duplicate records. If a reminder-health or UV feature fails mid-implementation, the safe rollback is to keep the schema changes plus tests, disable the new UI affordance behind the existing fallback behavior, and rerun `just test-unit` before continuing.

For notification health, the repair action must be safe to trigger more than once. Rebuilding reminder schedules should clear and recreate the relevant pending requests, not append duplicates. For live UV data, denied permission or WeatherKit errors must always fall back to the heuristic path rather than surfacing a blank card or a crash.

## Artifacts and Notes

Key files that are expected to change:

    docs/outside-log-follow-through-execplan.md
    app/Sunclub/Sources/Models/DailyRecord.swift
    app/Sunclub/Sources/Models/Settings.swift
    app/Sunclub/Sources/Models/SunclubSchema.swift
    app/Sunclub/Sources/Services/AppState.swift
    app/Sunclub/Sources/Services/NotificationManager.swift
    app/Sunclub/Sources/Services/ReminderPlanner.swift
    app/Sunclub/Sources/Services/UVIndexService.swift
    app/Sunclub/Sources/Views/HomeView.swift
    app/Sunclub/Sources/Views/ManualLogView.swift
    app/Sunclub/Sources/Views/SettingsView.swift
    app/Sunclub/Sources/Views/HistoryView.swift
    app/Sunclub/Tests/
    app/Sunclub/UITests/SunclubUITests.swift

When verification is run, this section should capture the most important short transcripts, such as successful test summaries or concise migration evidence.

## Interfaces and Dependencies

At completion, the following interfaces or equivalent responsibilities must exist:

- `DailyRecord` must persist lightweight reapply-completion state for a day.
- `Settings` must persist the minimum new reminder-health and live-UV preference state required by this feature.
- `SunclubMigrationPlan` must migrate V2 stores to V3 stores without losing existing history or settings.
- `AppState` must expose presentation helpers for manual-log defaults, Home recovery actions, reapply completion, reminder coaching, notification health, monthly review insights, and UV source state.
- `NotificationManager` must be able to report notification-health status in addition to scheduling reminders.
- `UVIndexService` must support live WeatherKit fetching with graceful heuristic fallback.
- A new App Intent plus `AppShortcutsProvider` must expose `Log Sunscreen` outside the app.

Revision note: 2026-04-02 15:06Z. Updated after merging `origin/master`, landing the feature set, repairing the reminder-coaching and monthly-review UI harnesses, fixing the tooling-config parser for shell-default env values, and finishing with a green `just ci` run.
