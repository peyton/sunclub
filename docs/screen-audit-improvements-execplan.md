# iOS and Watch Screen Audit Improvements

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This repository stores its agent planning rules outside the checkout at `~/.agents/PLANS.md`; this document follows those rules and is self-contained for the Sunclub workspace.

## Purpose / Big Picture

Sunclub should make sunscreen logging faster, reduce repeated information on each screen, and keep the most important action or status near the top. After this change, a user can open the iOS app and immediately see today's logging state and next action, then move through History, Weekly Summary, Settings, Automation, Accountability, Reports, Scanner, and Recovery without duplicated summaries competing for attention. On Apple Watch, the user should be able to log sunscreen without scrolling.

The work is deliberately a focused product polish pass rather than a redesign. It keeps the existing visual identity, persistence model, automation routes, and data sync behavior unchanged.

## Progress

- [x] (2026-04-14 11:38Z) Read repository instructions, planning rules, project structure, SwiftUI screen files, watch app view, and build entry points.
- [x] (2026-04-14 12:00Z) Audited iOS routes and watch logging in the simulator, including Home, Manual Log, Weekly Summary, History, Settings, Achievements, Accountability, Skin Health Report, Product Scanner, Automation, Reapply Check-In, Recovery, and the 40 mm watch app.
- [x] (2026-04-14 12:04Z) Implemented more than thirty focused improvements or fixes across iOS screens and the watch app.
- [x] (2026-04-14 12:17Z) Preserved existing UI and unit test coverage; no new test target was needed because existing route, accessibility, watch-sync, and scorecard tests cover the touched behavior.
- [x] (2026-04-14 12:17Z) Ran local build, unit tests, UI tests, and lint; see validation notes below.

## Surprises & Discoveries

- Observation: The watch app currently places the single logging button after header, status, UV, and reapply cards inside a `ScrollView`, which means small watches can require scrolling before logging.
  Evidence: `app/Sunclub/WatchApp/Sources/SunclubWatchHomeView.swift` renders `header`, `statusCard`, `uvCard`, `reapplyCard`, then the logging button.
- Observation: Several screens repeat the same metric in adjacent cards. Weekly Summary shows longest streak in the main postcard and again in the metric row. History shows selected-day status in the content card and again in the footer. Home shows a weekly/history hint inside the streak card and then a separate History card below.
  Evidence: `WeeklyReportView.weeklyPostcard`, `WeeklyReportView.streakContextRow`, `HistoryView.dayDetailCard`, `HistoryView.historyActionFooter`, and `HomeView.streakCard` contain these repeats.
- Observation: The watch notification permission prompt blocked first launch and required scrolling on the 40 mm watch simulator.
  Evidence: The first watch launch screenshot showed the system notification sheet before the app content; after deferring the request, the rebuilt watch app opened directly to the log action.
- Observation: Sorting locked achievements by title put long-horizon badges above one-step badges.
  Evidence: Simulator screenshot showed 100-Day Shield before 7-Day Shield; the final route screenshot shows one-step badges first.

## Decision Log

- Decision: Preserve the current SwiftUI architecture and make small view-level changes instead of replacing screens or adding dependencies.
  Rationale: The app already has a consistent design system, routing, test harnesses, and accessibility conventions. Small changes reduce data-preservation and automation risk.
  Date/Author: 2026-04-14 / Codex
- Decision: Treat the watch logging button as the highest-priority watch content and move it above secondary context while keeping secondary cards available below.
  Rationale: The user explicitly requested that applying sunscreen on watch not require scrolling. Logging is the primary watch task.
  Date/Author: 2026-04-14 / Codex
- Decision: Defer watch notification permission until a reapply notification is actually scheduled.
  Rationale: A permission prompt on app launch competes with the primary watch logging task, especially on small watch screens.
  Date/Author: 2026-04-14 / Codex

## Outcomes & Retrospective

Implemented a cohesive screen-audit pass with no new dependencies and no persisted model changes. The watch app now exposes Log Sunscreen immediately on the 40 mm simulator and no longer requests notification permission on first launch unless a reapply notification needs scheduling. iOS screens now put the most important current action or next decision higher, reduce repeated summary content, and keep lower-priority exploration, history, or decorative content lower.

## Context and Orientation

Sunclub is a SwiftUI iOS app generated with Tuist from `app/Sunclub/Project.swift`. The main iOS target is `Sunclub`, the watch app target is `SunclubWatch`, and the generated workspace is `app/Sunclub.xcworkspace`. Common commands are exposed through the root `justfile`, including `just generate`, `just test-unit`, `just test-ui`, and `just ci`.

The iOS navigation root is `app/Sunclub/Sources/Shared/RootView.swift`, which shows `WelcomeView` until onboarding is complete and then `HomeView`. Screen views live in `app/Sunclub/Sources/Views/`. The shared manual log field component is `app/Sunclub/Sources/Shared/SunManualLogFields.swift`. The watch app screen is `app/Sunclub/WatchApp/Sources/SunclubWatchHomeView.swift`.

Important repository rules for this work are: do not change persisted SwiftData models without a schema migration, preserve accessibility scorecard requirements, preserve automation surfaces, avoid external dependencies, and keep documentation in `docs/`. This plan does not require persisted model changes or new dependencies.

## Plan of Work

First, audit the simulator screens using the generated workspace and `UITEST_MODE` where needed to bypass camera and notification prompts. Record the visible issues that can be fixed without changing data models or app identity.

Second, edit the SwiftUI views to reduce duplicated content, move primary information upward, improve empty states, and keep destructive or secondary details lower. The highest-priority watch edit is in `SunclubWatchHomeView`: put the log button directly under the header and compress the top status into a concise single-screen summary.

Third, add tests that assert the changed product behavior where the existing tests can cover it. For UI-only copy and ordering changes, favor targeted accessibility identifiers and existing unit tests rather than brittle pixel assertions. For the watch screen, add or update a lightweight unit test if the presentation can be extracted without introducing broad architecture.

Finally, regenerate/build if needed and run `just test-unit`. Run simulator inspection for iOS and watch. If UI tests are practical after the unit pass, run `just test-ui`; otherwise record the reason they were not run.

## Concrete Steps

From the repository root `/Users/peyton/.codex/worktrees/fbd4/sunclub`, run:

    just generate

Use Xcode build defaults or the generated workspace to build and launch:

    workspace: app/Sunclub.xcworkspace
    iOS scheme: Sunclub
    watch scheme: SunclubWatch

After editing, run:

    just test-unit

If the unit pass succeeds and time allows, run:

    just test-ui

## Validation and Acceptance

Acceptance requires all of the following:

The iOS simulator opens the app and the Home screen keeps today's state and the primary log/edit action ahead of weekly, history, and optional exploration content.

Every main screen in `app/Sunclub/Sources/Views/` has been checked in code and, where routeable in the simulator, visually inspected for top-priority ordering and obvious repeated information.

The watch simulator shows a logging action without requiring scrolling on a small watch size. Secondary details such as UV and reapply timing can remain below the fold.

At least thirty concrete improvements or fixes are listed in the final implementation summary and are represented by working tree changes.

Relevant tests pass, or any unrun/failed command is recorded with the blocker.

Validation completed:

    just generate
    xcodebuild build -workspace app/Sunclub.xcworkspace -scheme Sunclub -configuration Debug -destination 'id=07902F42-D089-4E6C-850D-D24E1873C99A' -derivedDataPath .DerivedData SWIFT_ENABLE_COMPILE_CACHE=NO COMPILATION_CACHE_ENABLE_CACHING=NO COMPILATION_CACHE_ENABLE_PLUGIN=NO COMPILATION_CACHE_ENABLE_DIAGNOSTIC_REMARKS=NO COMPILATION_CACHE_KEEP_CAS_DIRECTORY=NO COMPILATION_CACHE_REMOTE_SERVICE_PATH=
    just test-unit
    just test-ui
    just lint

Results: build succeeded; `just test-unit` passed 215 tests; `just test-ui` passed 55 tests; `just lint` passed after fixing one markdown trailing-blank issue in this ExecPlan. SwiftLint reported existing warning-level violations and no serious violations.

## Idempotence and Recovery

All edits are source-level SwiftUI or documentation changes and can be reapplied safely. `just generate` is idempotent for the generated workspace. Simulator erases are not required for the implementation; if a simulator launch becomes unstable, restart the simulator rather than deleting source files. Do not run destructive Git commands.

## Artifacts and Notes

Initial code audit evidence:

    SunclubWatchHomeView places the log button after header/status/UV/reapply inside a ScrollView.
    WeeklyReportView repeats longest streak in weeklyPostcard and streakContextRow.
    HistoryView repeats selected day status in dayDetailCard and historyActionFooter.
    SettingsView starts with six collapsed groups, which hides reminder times and sync status until the user expands groups.

Temporary simulator screenshots were captured and inspected during the route audit, then removed from the working tree because they were generated evidence rather than source artifacts.

## Interfaces and Dependencies

No new dependencies are required. Preserve the existing public interfaces unless a small private helper makes tests possible. If extracting watch presentation state, keep it in `app/Sunclub/WatchApp/Sources/SunclubWatchHomeView.swift` or shared widget support only if the iOS app already compiles that type. Do not add a new package.
