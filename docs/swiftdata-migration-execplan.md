# SwiftData Migration ExecPlan

This ExecPlan records the first explicit SwiftData migration path for Sunclub so future schema changes follow a repeatable versioning and test workflow.

## Purpose / Big Picture

Sunclub shipped without an explicit `VersionedSchema` or `SchemaMigrationPlan`, which meant the store shape from commit `22ff481b7d43d86600a0a720bf7e09d775e3099f` was only implicitly compatible with the current app. This change makes the persisted schema versioned, migrates the old store forward, and adds a regression test that writes a real `V1` store before opening it with the current app code.

## Progress

- [x] (2026-04-02) Audited the persisted model history and confirmed the released `V1` delta: `Settings.smartReminderSettingsData` was added after commit `22ff481b7d43d86600a0a720bf7e09d775e3099f`, and legacy records could still carry `methodRawValue == 0`.
- [x] (2026-04-02) Added `SunclubSchemaV1`, `SunclubSchemaV2`, and `SunclubMigrationPlan`, then routed app, preview, and test container creation through one migration-aware factory.
- [x] (2026-04-02) Added a unit regression test that seeds a real disk-backed `V1` store, opens it through the current migration plan, and verifies both the new settings payload and the normalized verification method.
- [x] (2026-04-02) Ran `just test-unit`; the new migration regression test and the rest of the unit suite passed.

## Decision Log

- Decision: Use a custom `V1 -> V2` migration stage instead of a lightweight-only stage.
  Rationale: The shape change is additive, but the old shipped data can also contain camera-era `methodRawValue` values that need normalization alongside the new `smartReminderSettingsData` payload.
  Date/Author: 2026-04-02 / Codex
- Decision: Keep container creation centralized in a single factory.
  Rationale: Migration support is only trustworthy if every runtime path, including previews and tests, opens the same current schema with the same migration plan.
  Date/Author: 2026-04-02 / Codex

## Validation

Intended validation command from the repository root:

    just test-unit

Acceptance checks:

1. A store written with the schema from commit `22ff481b7d43d86600a0a720bf7e09d775e3099f` opens through the current app without container creation failures.
2. Migrated `Settings` rows have a populated `smartReminderSettingsData` payload derived from the legacy reminder hour/minute fields.
3. Migrated `DailyRecord` rows normalize the removed camera-era raw value to `.manual`.
