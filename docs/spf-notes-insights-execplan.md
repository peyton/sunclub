# SPF And Notes Insights ExecPlan

This ExecPlan is a living record of the SPF and notes insights feature. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must stay current as implementation and verification move forward. This repo does not check in `PLANS.md`, so this document follows the shared execution-plan guidance from `/Users/peyton/.agents/PLANS.md`.

## Purpose / Big Picture

Sunclub already stores optional SPF and notes data on each manual log, but the app currently hides most of that information after it is saved. After this change, a user can open `Weekly Summary` and immediately see the SPF level they log most often plus a short list of recent notes from their check-ins. The result should feel like a lightweight habit recap, not a new workflow: the manual logging loop stays the same, and the new value appears only in review surfaces.

## Progress

- [x] (2026-04-02 07:36Z) Audited the existing storage and UI surfaces in `app/Sunclub/Sources/Models/DailyRecord.swift`, `app/Sunclub/Sources/Views/ManualLogView.swift`, `app/Sunclub/Sources/Views/WeeklyReportView.swift`, `app/Sunclub/Sources/Views/HistoryView.swift`, and the current test targets.
- [x] (2026-04-02 07:36Z) Added this ExecPlan before code edits so the work has a tracked implementation record.
- [x] (2026-04-02 07:46Z) Added `app/Sunclub/Sources/Services/SunscreenUsageInsights.swift` plus `DailyRecord.trimmedNotes` so the app can summarize the most-used SPF and newest non-empty notes.
- [x] (2026-04-02 07:46Z) Moved SPF and notes persistence into `AppState.recordVerificationSuccess(...)` and updated `WeeklyReportView` and `HistoryView` to surface the saved metadata without changing the logging flow.
- [x] (2026-04-02 07:46Z) Added deterministic UI-test seeding, unit tests, and a UI test for the weekly insights surface.
- [x] (2026-04-02 07:46Z) Regenerated the Tuist workspace with `just generate`.
- [x] (2026-04-02 07:46Z) Ran `just test-unit` successfully; 35 tests passed.
- [ ] Run `just test-ui` to completion. Completed: the UI test target builds and the suite was retried after opening Simulator. Remaining: the simulator test runner still fails to launch with `NSMachErrorDomain -308` before any UI case executes.

## Surprises & Discoveries

- Observation: `ManualLogView` currently records success first and then mutates SPF and notes directly on the fetched `DailyRecord`.
  Evidence: `app/Sunclub/Sources/Views/ManualLogView.swift` calls `recordVerificationSuccess(...)` and then sets `appState.record(for: Date())?.spfLevel` and `notes`.
- Observation: The new UI test target compiles, installs dependencies, and reaches the simulator launch phase, but the runner process dies before executing any test case.
  Evidence: repeated `just test-ui` runs now fail with `SunclubUITests-Runner encountered an error` and `NSMachErrorDomain Code=-308`.

## Decision Log

- Decision: Surface the new data in `Weekly Summary` instead of creating a separate analytics screen.
  Rationale: The product spec already positions weekly summary as the lightweight review surface, so this keeps the feature inside an existing habit loop instead of expanding navigation.
  Date/Author: 2026-04-02 / Codex
- Decision: Keep the insight model simple: one most-used SPF summary and a recent-notes list.
  Rationale: The request explicitly asks for SPF patterns and recent notes, and the app spec still prefers simple, legible progress UI over deep analytics.
  Date/Author: 2026-04-02 / Codex
- Decision: Move SPF and notes persistence into `AppState.recordVerificationSuccess(...)` instead of continuing the view-level post-save mutation.
  Rationale: This keeps the saved metadata on the same persistence path as the daily success record, reduces ad hoc state mutation in `ManualLogView`, and makes the behavior easy to test.
  Date/Author: 2026-04-02 / Codex

## Outcomes & Retrospective

The feature now exists in the product code. `Weekly Summary` can answer “what SPF did I use most often?” and can show recent non-empty notes from prior logs. `History` day detail also surfaces a saved note when one exists, so the stored metadata is visible in both aggregate and per-day review flows.

The persistence path is cleaner than before because `ManualLogView` now sends optional SPF and notes through `AppState.recordVerificationSuccess(...)` instead of mutating a fetched record after success logging. Unit coverage was extended around the new analytics helper and the updated success-recording path, and `just test-unit` passed with 35 tests total.

The remaining gap is environmental verification of the UI suite. The new UI test was added and the UI target builds, but the simulator runner repeatedly dies before launch with `NSMachErrorDomain -308` in this environment, even after opening Simulator and retrying the suite.

## Context and Orientation

The iOS app is generated with Tuist from the manifests in `app/`. The app target lives in `app/Sunclub/`, with model types under `app/Sunclub/Sources/Models/`, state and pure business logic under `app/Sunclub/Sources/Services/`, and SwiftUI screens under `app/Sunclub/Sources/Views/`.

The stored sunscreen log row is `DailyRecord` in `app/Sunclub/Sources/Models/DailyRecord.swift`. Each record already persists an optional `spfLevel` and optional `notes` string. Shared app state is `AppState` in `app/Sunclub/Sources/Services/AppState.swift`; this is the source of truth that loads records from SwiftData and feeds the views. The current weekly summary screen is `app/Sunclub/Sources/Views/WeeklyReportView.swift`, and the history calendar detail screen is `app/Sunclub/Sources/Views/HistoryView.swift`.

The existing unit tests live in `app/Sunclub/Tests/SunclubTests.swift`. The existing UI tests live in `app/Sunclub/UITests/SunclubUITests.swift`. `SunclubApp` in `app/Sunclub/Sources/SunclubApp.swift` already reads launch arguments such as `UITEST_MODE` and `UITEST_ROUTE=weeklySummary`, so the cleanest UI-test path is to extend that launch configuration with deterministic seeded records instead of trying to type long note strings through the simulator keyboard.

## Plan of Work

First, add a small pure analytics helper under `app/Sunclub/Sources/Services/` that accepts the current `DailyRecord` collection and returns a value type describing the most-used SPF and the newest non-empty notes. This helper should trim empty notes, sort note entries newest-first, and break SPF-count ties deterministically by recency so tests stay stable.

Next, add a thin `AppState` helper that exposes those insights from the already-loaded `records` array. While touching the manual logging flow, remove the view-level post-save mutation and let `recordVerificationSuccess` accept optional SPF and notes so the persistence path stays in one place.

Then update `app/Sunclub/Sources/Views/WeeklyReportView.swift` to render a compact insights section beneath the existing weekly chart. The section should preserve the screen’s current feel: short labels, one simple “Most used SPF” card, and a recent-notes list if any notes exist. If there is no SPF or note data yet, render a short placeholder message instead of an empty hole. If the current day-detail card in `HistoryView` can show notes with minimal extra complexity, include that note surface too.

Finally, extend the UI-test launch seeding in `SunclubApp` so weekly summary can be launched with known SPF and note data. Add unit tests for the analytics helper and for the revised success-recording path, add a UI test that verifies the weekly summary shows the seeded insight content, run `just generate`, `just test-unit`, and `just test-ui`, and update the user-facing docs that mention weekly summary behavior.

## Concrete Steps

From the repository root:

1. Create or update the analytics helper, app state, weekly summary view, and UI-test launch seeding in the app sources. Completed in:

       app/Sunclub/Sources/Services/SunscreenUsageInsights.swift
       app/Sunclub/Sources/Services/AppState.swift
       app/Sunclub/Sources/Views/WeeklyReportView.swift
       app/Sunclub/Sources/Views/HistoryView.swift
       app/Sunclub/Sources/SunclubApp.swift

2. Add or update unit and UI tests in `app/Sunclub/Tests/SunclubTests.swift` and `app/Sunclub/UITests/SunclubUITests.swift`.
3. Regenerate the workspace and run:

       just generate
       just test-unit
       just test-ui

Observed results in this run:

    `just generate` completed successfully and regenerated `Sunclub.xcworkspace`.
    `just test-unit` passed with 35 passing tests.
    `just test-ui` built the app and UI test target, but the simulator runner failed before test execution with `NSMachErrorDomain -308`.

## Validation and Acceptance

Acceptance is behavior-based:

1. Logging sunscreen with SPF and notes still completes the same success flow as before.
2. Opening `Weekly Summary` after records exist shows the most-used SPF level when at least one SPF was logged.
3. Opening `Weekly Summary` shows recent non-empty notes in newest-first order when notes exist.
4. When no SPF or notes were logged yet, `Weekly Summary` still renders cleanly and explains how to populate the insights.
5. The new unit tests fail before the code change and pass after it. This is satisfied in this run.
6. The UI test launches the app directly into weekly summary with seeded records and proves the insights are visible without manual typing. The test was authored for this path, but the current environment blocked execution because the simulator runner failed before launch.

## Idempotence and Recovery

The work is additive and should be safe to repeat. Re-running `just generate` or the test commands should not mutate persistent state because tests run with an in-memory SwiftData container. If UI-test seeding causes duplicate records during development, the safe fix is to ensure the seeding path only runs once per process launch and refreshes `AppState` after inserts.

## Artifacts and Notes

Expected key files:

    docs/spf-notes-insights-execplan.md
    app/Sunclub/Sources/Services/AppState.swift
    app/Sunclub/Sources/Services/<new insights helper>.swift
    app/Sunclub/Sources/Views/WeeklyReportView.swift
    app/Sunclub/Sources/SunclubApp.swift
    app/Sunclub/Tests/SunclubTests.swift
    app/Sunclub/UITests/SunclubUITests.swift

## Interfaces and Dependencies

At completion, the feature should expose:

- A pure analytics type under `app/Sunclub/Sources/Services/` that summarizes `DailyRecord` SPF usage and recent notes without depending on SwiftUI.
- An `AppState` helper that returns the analytics summary from the in-memory `records`.
- A `recordVerificationSuccess(...)` path that can persist optional SPF and notes together with the success record.
- A `WeeklyReportView` insights section with accessibility identifiers suitable for UI tests.
- A `SunclubApp` launch-configuration hook that seeds known records for UI tests without changing normal app behavior.

Revision note: 2026-04-02 07:46Z. Updated this plan after implementation to record the landed code paths, the successful `just generate` and `just test-unit` runs, and the outstanding simulator-runner failure affecting `just test-ui`.
