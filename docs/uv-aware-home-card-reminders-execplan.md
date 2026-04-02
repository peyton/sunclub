# UV-Aware Home Card and Reminders ExecPlan

This ExecPlan is the working record for adding UV-aware status on Home plus stronger reapply reminder behavior. The sections `Progress`, `Decision Log`, and `Outcomes & Retrospective` will be updated as implementation and verification land.

## Purpose / Big Picture

Sunclub already carries a stubbed UV index service, but Home and reminder scheduling still behave as if every day has the same exposure risk. This change makes the main dashboard acknowledge elevated UV days and lets reapply reminders get more urgent when the day’s UV level warrants it, without changing the app’s manual-first product shape.

## Progress

- [x] (2026-04-02) Audited the existing seams in `UVIndexService`, `AppState`, `HomeView`, `NotificationManager`, and the current unit/UI tests.
- [x] (2026-04-02) Added this ExecPlan before implementation so the feature has a tracked design and verification record.
- [x] (2026-04-02) Threaded cached UV state through `AppState` and exposed testable presentation models for Home and reapply reminders.
- [x] (2026-04-02) Updated Home and success UI to surface elevated UV messaging without disrupting the current layout.
- [x] (2026-04-02) Updated reminder scheduling so high-UV days produce stronger reapply nudges.
- [x] (2026-04-02) Added unit tests and UI tests for the new behavior, including UITest launch overrides for UV and reminder settings.
- [x] (2026-04-02) Regenerated the Tuist workspace with `just generate`.
- [x] (2026-04-02) Verified the unit suite once on the feature branch before the simulator became unstable.
- [ ] Re-establish a stable simulator run for a final clean pass of `just test-ui` and a post-edit repeat of `just test-unit`.

## Decision Log

- Decision: Keep UV awareness local and heuristic-based through the existing `UVIndexService` instead of introducing network-backed weather dependencies.
  Rationale: The repo explicitly avoids new external dependencies, and the current service already establishes the intended product boundary.
  Date/Author: 2026-04-02 / Codex
- Decision: Centralize UV-aware copy and reminder intensity in `AppState` presentation models instead of duplicating logic across `HomeView` and `NotificationManager`.
  Rationale: The feature needs both UI and scheduling changes, and one shared source of truth keeps tests smaller and behavior consistent.
  Date/Author: 2026-04-02 / Codex

## Context and Orientation

The app code lives in `app/Sunclub/Sources/`. The current UV stub lives in `Services/UVIndexService.swift`. Home UI is in `Views/HomeView.swift`, reminder scheduling is in `Services/NotificationManager.swift`, and shared state lives in `Services/AppState.swift`. Unit tests live in `app/Sunclub/Tests/`, and UI tests live in `app/Sunclub/UITests/`.

## Plan of Work

1. Add cached UV state plus a small home-card presentation model and a reapply reminder plan to `AppState`.
2. Render the UV-aware card state on Home and reflect stronger reminder guidance in the success flow.
3. Change reminder scheduling to use the reapply plan instead of only the raw settings interval.
4. Add deterministic unit and UI coverage, including test-only launch hooks for UV state when needed.
5. Regenerate the Tuist project and run the targeted validation commands from the repo root.

## Validation and Acceptance

1. Home shows an elevated-UV message on high-risk days without breaking the current streak/history/manual-log flow.
2. Reapply reminder scheduling uses stronger timing and copy on elevated-UV days while preserving the user’s configured base setting.
3. Unit tests cover the UV presentation and reminder plan rules.
4. UI tests cover the visible elevated-UV state on Home and at least one reminder-facing UI surface.

## Outcomes & Retrospective

- Outcome: The feature landed as scoped. Home now surfaces elevated UV state, and reminder planning shortens interval plus strengthens copy on elevated-UV days without mutating the saved base preference.
- Outcome: UITest-only launch arguments now allow deterministic UV and reminder-state setup for UI coverage without introducing production-only seams.
- Verification: `just generate` succeeded. `just test-unit` passed once after the feature logic landed. After later accessibility-only UI adjustments, repeated `xcodebuild` and `just test-ui` attempts were blocked by simulator runner failures (`Mach error -308`, `ipc/mig server died`) and the scheme's `tuist inspect test` post-action made direct `xcodebuild` runs hard to use as a final clean signal.
- Follow-up: If simulator stability remains noisy in this repo, the next cleanup should be on the dedicated test device lifecycle or the scheme post-actions, not on the UV feature itself.
