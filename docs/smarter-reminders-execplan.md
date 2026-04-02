# Smarter Reminders ExecPlan

This ExecPlan is a living record of the smarter reminder work. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` will capture the implementation and verification that lands.

## Purpose / Big Picture

Sunclub should move beyond a single daily reminder time. The reminder system needs separate weekday and weekend schedules, better behavior when the user travels or changes time zones, and an optional streak-risk nudge that catches the user before a streak lapses at the end of the day.

## Progress

- [x] (2026-04-02 07:34Z) Audited the current reminder model, settings UI, notification scheduler, and test coverage to identify the exact surfaces involved.
- [x] (2026-04-02 07:34Z) Added this ExecPlan before implementation so the reminder refactor has a tracked record.
- [x] (2026-04-02 07:39Z) Added a persisted smart-reminder configuration plus a pure planner for weekday/weekend time selection, timezone handling, and streak-risk nudge timing.
- [x] (2026-04-02 07:43Z) Wired `AppState`, `NotificationManager`, and `SunclubApp` so reminder scheduling reacts to settings changes, check-ins, app activation, and time-zone/significant-time changes.
- [x] (2026-04-02 07:50Z) Refactored `SettingsView.swift` to expose separate weekday/weekend times, travel handling, streak-risk nudges, and the existing reapply reminder controls.
- [x] (2026-04-02 07:52Z) Added unit/UI coverage, regenerated the Tuist workspace, and verified the feature on the stable iOS 26.4 simulator runtime.

## Surprises & Discoveries

- Observation: The current reminder system is centralized enough that one feature can be implemented without broad routing or storage changes.
  Evidence: the active reminder surfaces are concentrated in `app/Sunclub/Sources/Models/Settings.swift`, `app/Sunclub/Sources/Services/AppState.swift`, `app/Sunclub/Sources/Services/NotificationManager.swift`, and `app/Sunclub/Sources/Views/SettingsView.swift`.
- Observation: The repo’s simulator resolver needed to prefer the Xcode SDK runtime instead of the latest installed runtime to keep the test entrypoints stable.
  Evidence: `scripts/resolve_simulator.py` originally selected the max available runtime version and repeatedly landed on an unstable iOS 26.5 device; after changing it to prefer the active Xcode SDK version, `just test-unit` resolved the stable 26.4 simulator.
- Observation: The repo test entrypoints still need unrestricted simulator access in the Codex sandbox even though the resolver now picks the right runtime.
  Evidence: sandboxed runs failed at `xcrun simctl list runtimes available --json`, while unrestricted `just test-unit` and `just test-ui` both completed successfully on simulator `9D98F000-212A-4DB7-871C-842973549F32`.

## Decision Log

- Decision: Use a single encoded smart-reminder payload on `Settings` instead of scattering several new top-level SwiftData properties across the model.
  Rationale: This keeps schema expansion small, preserves a straightforward fallback from the legacy one-time reminder fields, and gives the planner room to evolve without repeated model churn.
  Date/Author: 2026-04-02 / Codex

## Outcomes & Retrospective

Sunclub now stores a richer reminder policy without scattering new top-level persistence fields across SwiftData. Weekday and weekend schedules live in one encoded payload with backward-compatible defaults sourced from the legacy daily reminder fields. The reminder planner centralizes day-kind selection, timezone-aware trigger calculation, and streak-risk nudge timing so the scheduler and tests both operate from the same rules.

The runtime now reschedules intelligently. Settings changes still rebuild the main reminder queue, while daily logging and record deletion only refresh the streak-risk reminder. App activation, significant clock changes, and timezone changes all reschedule reminders so travel behavior stays consistent with the user’s selected mode.

## Context and Orientation

The iOS app is Tuist-managed under `app/`. Reminder state is stored in `app/Sunclub/Sources/Models/Settings.swift`, app-level mutations live in `app/Sunclub/Sources/Services/AppState.swift`, notification requests are built in `app/Sunclub/Sources/Services/NotificationManager.swift`, and the user-facing controls live in `app/Sunclub/Sources/Views/SettingsView.swift`. Existing tests live in `app/Sunclub/Tests/` and `app/Sunclub/UITests/`.

## Plan of Work

The implementation will follow four steps:

1. Add a smart-reminder model and planner layer with backward-compatible defaults.
2. Update app state, notification scheduling, and lifecycle hooks to use that layer.
3. Refactor settings UI to expose weekday/weekend reminders, timezone handling, and streak-risk nudges.
4. Verify the behavior with unit tests, UI tests, Tuist generation, and iOS test runs.

## Concrete Steps

Planned verification commands from the repository root:

    just generate
    just test-unit
    just test-ui

Executed verification:

    just generate
    just test-unit  # requires unrestricted simulator access in the Codex sandbox
    just test-ui  # requires unrestricted simulator access in the Codex sandbox
    xcodebuild test -workspace /Users/peyton/.codex/worktrees/629a/sunclub/app/Sunclub.xcworkspace -scheme Sunclub -configuration Debug -destination 'id=9D98F000-212A-4DB7-871C-842973549F32' -derivedDataPath /Users/peyton/.codex/worktrees/629a/sunclub/.DerivedData/test-26_4 -resultBundlePath /Users/peyton/.codex/worktrees/629a/sunclub/.build/test-unit-26_4.xcresult '-only-testing:SunclubTests' -parallel-testing-enabled NO -maximum-parallel-testing-workers 1
    xcodebuild test -workspace /Users/peyton/.codex/worktrees/629a/sunclub/app/Sunclub.xcworkspace -scheme Sunclub -configuration Debug -destination 'id=9D98F000-212A-4DB7-871C-842973549F32' -derivedDataPath /Users/peyton/.codex/worktrees/629a/sunclub/.DerivedData/test-ui-26_4 -resultBundlePath /Users/peyton/.codex/worktrees/629a/sunclub/.build/test-ui-26_4.xcresult '-only-testing:SunclubUITests/SunclubUITests' -parallel-testing-enabled NO -maximum-parallel-testing-workers 1

Final repo checks:

    Review the generated Tuist workspace and confirm the new reminder model and tests are included without any manual project editing.

## Validation and Acceptance

Acceptance is behavior-focused:

1. Settings exposes independent weekday and weekend reminder times.
2. Daily reminders honor the correct schedule for each day.
3. Travel handling can either follow the current local timezone or stay anchored to the saved timezone.
4. Streak-risk nudges only schedule when the user has an active streak and has not yet secured the relevant day.
5. The existing reapply reminder flow still works.
6. Unit tests and UI tests cover the new behavior and the Tuist-generated workspace still builds the app and test targets.

## Idempotence and Recovery

The smarter reminder flow should stay idempotent under repeated app launches and repeated scheduling calls. If a future change corrupts reminder scheduling, the safe recovery path is to inspect the encoded reminder payload, regenerate the workspace, and rerun the reminder-related unit and UI tests.

## Artifacts and Notes

Expected primary files touched:

    app/Sunclub/Sources/Models/Settings.swift
    app/Sunclub/Sources/Models/SmartReminderSettings.swift
    app/Sunclub/Sources/Services/AppState.swift
    app/Sunclub/Sources/Services/NotificationManager.swift
    app/Sunclub/Sources/Services/ReminderPlanner.swift
    app/Sunclub/Sources/Views/SettingsView.swift
    app/Sunclub/Tests/
    app/Sunclub/UITests/

## Interfaces and Dependencies

At completion:

- `Settings` will expose a backward-compatible smart reminder payload.
- `AppState` will be responsible for mutating reminder preferences and triggering reschedules when local state changes.
- `NotificationManager` will schedule weekday/weekend reminder requests plus the optional streak-risk nudge.
- `SunclubApp` will reschedule reminders when the app becomes active or the device clock/timezone changes.
