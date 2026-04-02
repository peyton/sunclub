# History Edit and Backfill ExecPlan

This ExecPlan is a living record of the history edit/backfill feature. The sections `Progress`, `Decision Log`, and `Validation` capture the implementation and verification work that landed.

## Purpose / Big Picture

Sunclub's history calendar should do more than inspect or delete old days. A user should be able to pick a past day, correct the saved manual details for that day, or backfill a missed day without leaving the history flow.

## Progress

- [x] (2026-04-02 07:00Z) Audited the history, manual-log, app-state, and test targets to find the smallest write path that could serve both today's log flow and history corrections.
- [x] (2026-04-02 07:00Z) Added this ExecPlan so the feature has a tracked record in `docs/`.
- [x] (2026-04-02 07:12Z) Extended `AppState` with a shared upsert path plus explicit history-save behavior that can overwrite or clear SPF and notes on an existing day.
- [x] (2026-04-02 07:21Z) Reworked `HistoryView` so selected days offer `Edit Entry` or `Backfill Day`, with a reusable manual-log form inside a history-owned sheet.
- [x] (2026-04-02 07:27Z) Added unit coverage for backfill and edit semantics plus UI-test launch seeding and end-to-end history edit/backfill UI tests.

## Decision Log

- Decision: Keep history correction inside `HistoryView` with a sheet instead of routing through the home-only manual log screen.
  Rationale: The requested behavior is contextual to a selected calendar day, and a sheet preserves that context while keeping routing unchanged.
  Date/Author: 2026-04-02 / Codex
- Decision: Reuse the SPF and notes fields through a shared component while keeping the success-screen flow exclusive to today's manual log.
  Rationale: The controls should stay visually consistent, but backfilling a past day should not trigger today's reinforcement flow or reminder side effects.
  Date/Author: 2026-04-02 / Codex
- Decision: Allow history edits to clear SPF and notes, while preserving the existing "today re-log" behavior that only overwrites optional values when new ones are provided.
  Rationale: History correction needs true editing semantics, but the current manual-log flow already has tests that expect optional values to survive a second save when the user leaves them blank.
  Date/Author: 2026-04-02 / Codex

## Validation

Intended validation commands from the repository root:

    just generate
    just test-unit
    just test-ui

Acceptance checks:

1. Selecting an already-logged day in History offers an edit action instead of delete-only recovery.
2. Selecting a missed day offers a backfill action and creates a record for the selected past day.
3. Editing a history record can change or clear SPF and notes without duplicating the day.
4. Today's manual log flow still records one row for today and routes to the success screen.
