# Local Backup ExecPlan

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Sunclub is intentionally local-first, but today that also means a reinstall or device switch wipes a user's history. This change adds a local export/import backup flow in Settings so a user can save one backup file, move it however they want, and restore their reminder settings plus sunscreen history later without creating an account or introducing a server.

The restore path must also respect SwiftData schema migration. A backup that contains an older on-disk database must be unpacked into a temporary store and opened through `app/Sunclub/Sources/Models/SunclubSchema.swift`, not read through ad-hoc JSON transforms, so the same migration plan that protects normal upgrades also protects imports.

## Progress

- [x] (2026-04-02 11:34Z) Audited the app entry points, `SettingsView`, `AppState`, and the existing SwiftData migration factory to identify the correct integration seam.
- [x] (2026-04-02 11:39Z) Chose a single-file backup format that embeds raw SwiftData store files in JSON so export/import can stay dependency-free while still restoring through SwiftData migration.
- [x] (2026-04-02 10:40Z) Implemented `SunclubBackupDocument` and `SunclubBackupService`, then wired `AppState` to export and import through the migration-aware restore path.
- [x] (2026-04-02 10:41Z) Added the Settings backup section, user-facing status/error handling, and UITest-only export/import harness controls driven by launch-argument file URLs.
- [x] (2026-04-02 10:42Z) Added unit tests for current-schema round-trip restore and legacy-schema backup migration, plus UI tests for the Settings backup surface and harness flow.
- [x] (2026-04-02 10:50Z) Ran `just test-unit`, `just test-ui`, and `just lint`, then recorded the verification outcomes and the simulator-override constraint below.

## Surprises & Discoveries

- Observation: The app already has a trustworthy migration seam in `SunclubModelContainerFactory.makeDiskBackedContainer(url:)`.
  Evidence: `app/Sunclub/Sources/Models/SunclubSchema.swift` routes all disk-backed current-schema opens through `SunclubMigrationPlan`.
- Observation: Exporting the live SQLite store directly would require discovering SwiftData's automatic shared-store path, which is avoidable.
  Evidence: `SunclubApp` currently creates the shared container with `groupContainer: .automatic`, but the app does not keep or expose the resulting file URL.
- Observation: The repository test scripts source `scripts/tooling/sunclub.env` in a way that overwrote any caller-provided simulator name, which made `just test-unit` and `just test-ui` collide with another active Sunclub worktree in this Codex session.
  Evidence: `scripts/tooling/test_ios.sh` resolves the simulator from `TEST_SIMULATOR_NAME`, and `scripts/tooling/sunclub.env` originally assigned fixed values instead of honoring pre-set environment overrides.

## Decision Log

- Decision: Export a single JSON backup file that contains raw store file bytes, instead of exporting a snapshot-only JSON model dump.
  Rationale: A raw-store backup can be written back to disk and reopened through SwiftData, which keeps schema migration behavior identical between normal upgrades and backup imports while avoiding extra packaging dependencies such as ZIP libraries.
  Date/Author: 2026-04-02 / Codex
- Decision: Restore by migrating a temporary store and then copying its current-schema data into the live context, instead of swapping the live store files in place.
  Rationale: The app already keeps `Settings` and `DailyRecord` in memory through `AppState`. Copying migrated data into the current context avoids container teardown, app relaunch requirements, and direct manipulation of SwiftData's live shared-store location.
  Date/Author: 2026-04-02 / Codex
- Decision: Use UITest harness buttons for export/import verification rather than automating the system document picker.
  Rationale: The feature still uses `fileExporter` and `fileImporter` in production, but the deterministic path for automated UI tests is to call the same core backup code against file URLs supplied by launch arguments.
  Date/Author: 2026-04-02 / Codex

## Outcomes & Retrospective

Implemented a local-first backup flow that exports one JSON document containing raw SwiftData store files and restores by unpacking that store into a temporary migrated container before copying the current-schema data into the live context. The user-facing entry points live in Settings, the core logic lives in `SunclubBackupService`, and the UI test harness reuses the production import/export code paths with deterministic file URLs.

Verification completed with repository entry points:

    TEST_SIMULATOR_NAME='Sunclub UI Test iPhone 17 Pro' TEST_DERIVED_DATA='.DerivedData/test-unit-alt' just test-unit
    TEST_SIMULATOR_NAME='Sunclub UI Test iPhone 17 Pro' TEST_DERIVED_DATA='.DerivedData/test-ui-alt' just test-ui
    just lint

All three commands passed. The simulator-name override was needed only because this Codex machine already had another Sunclub worktree actively running tests against the default shared simulator name; the repository now honors explicit environment overrides so the standard scripts can be redirected without changing their default behavior.

## Context and Orientation

The app target lives under `app/Sunclub/`. The current persistence model is small: `app/Sunclub/Sources/Models/DailyRecord.swift` stores one sunscreen entry per day, and `app/Sunclub/Sources/Models/Settings.swift` stores onboarding and reminder preferences. `app/Sunclub/Sources/Models/SunclubSchema.swift` defines the explicit SwiftData schema versions and the `SunclubMigrationPlan` that migrates the store from `V1` to `V2`.

`app/Sunclub/Sources/Services/AppState.swift` is the single observable app state object. It owns the live `ModelContext`, keeps `settings` and `records` in memory, and is already injected into every SwiftUI screen. `app/Sunclub/Sources/Views/SettingsView.swift` is the correct user-visible surface for maintenance tasks such as reminder editing, so backup actions belong there. Existing migration coverage lives in `app/Sunclub/Tests/MigrationTests.swift`, and UI coverage for Settings lives in `app/Sunclub/UITests/SunclubUITests.swift`.

In this repository, “backup import migration” means this exact behavior: write the backup's embedded SQLite files into a temporary directory, open that store with `SunclubModelContainerFactory.makeDiskBackedContainer(url:)`, let `SunclubMigrationPlan` update any legacy schema rows, then copy the migrated `Settings` and `DailyRecord` data into the live app context.

## Plan of Work

Add a new backup service in `app/Sunclub/Sources/Services/` that can do four things. First, capture a snapshot of the current `Settings` row and every `DailyRecord` row from a `ModelContext`. Second, materialize that snapshot into a temporary disk-backed SwiftData store at a known filename such as `Sunclub.store`. Third, read the resulting store files into a codable backup payload and expose them through a `FileDocument` so `SettingsView` can hand them to `fileExporter`. Fourth, decode a backup file, write its store files back to a temporary directory, reopen that store through `SunclubModelContainerFactory.makeDiskBackedContainer(url:)`, and apply the migrated snapshot into the live `ModelContext`.

Extend `AppState` with small wrapper methods that call this service. Export should return the backup `FileDocument`. Import should overwrite the live `Settings` values and `DailyRecord` rows with the migrated snapshot, refresh in-memory state, reschedule reminder notifications, and clear any ephemeral reminder state that cannot be reconstructed from persisted history alone.

Update `SettingsView` with a new backup section that explains the local-only behavior, offers `Export Backup` and `Import Backup` buttons, and reports success or failure in a user-visible status line. Production export/import should use SwiftUI's `fileExporter` and `fileImporter`. When `RuntimeEnvironment.isUITesting` is true and specific launch arguments provide file URLs, show small harness buttons that call the same export/import methods directly against those URLs so UI tests can validate restore behavior without navigating the system document picker.

Add test coverage in two layers. Unit tests should prove current-schema export/import round-trips data and that importing a backup built from a real `SunclubSchemaV1` store migrates to current values before touching the live context. UI tests should verify the backup controls appear in Settings and that importing a legacy backup through the harness updates the visible reminder summary and record count.

## Concrete Steps

Work from the repository root at `/Users/peyton/.codex/worktrees/dfa0/sunclub`.

1. Implement the backup service and document types, then wire `AppState` to expose `exportBackupDocument()`, `exportBackup(to:)`, and `importBackup(from:)`.
2. Update `SettingsView` to present the new backup section, status text, and UITest harness controls guarded by launch arguments.
3. Add or update specs and tests.
4. Run:

    just test-unit
    just test-ui

Expected success after implementation:

    $ just test-unit
    ...
    Test Suite 'All tests' passed

    $ just test-ui
    ...
    Test Suite 'All tests' passed

## Validation and Acceptance

Acceptance is behavioral:

1. From Settings, the user can export one backup file without signing in or leaving the app's local-first model.
2. Importing that file into a clean install restores reminder settings and sunscreen history.
3. Importing a backup that contains a `V1` SwiftData store succeeds because the temporary restore container opens through `SunclubMigrationPlan`, and the restored live data matches current `V2` expectations.
4. `just test-unit` passes with new regression coverage for current-schema round-trip restore and legacy-schema backup migration.
5. `just test-ui` passes with coverage for the Settings backup surface and the UITest harness restore path.

## Idempotence and Recovery

The backup export path is additive: exporting repeatedly only creates new backup files. Import is intentionally destructive for local app data, so the UI must say that the selected backup replaces current on-device history and settings. The implementation should decode and migrate the backup in a temporary directory first; if decoding or migration fails, the live context must remain unchanged. Temporary directories created during export/import must be deleted on success and best-effort deleted on failure.

## Artifacts and Notes

Expected user-visible strings after implementation:

    Export Backup
    Import Backup
    Import replaces current on-device history and reminder settings.

Expected regression scenario:

    Seed a real `SunclubSchemaV1` store -> package its `Sunclub.store*` files into a backup JSON file ->
    import through the new backup service -> assert `smartReminderSettingsData` is populated and
    `methodRawValue == VerificationMethod.manual.rawValue`.

## Interfaces and Dependencies

Define these repository-local interfaces:

- In `app/Sunclub/Sources/Services/SunclubBackupService.swift`, add a service that can export and import backup files for a `ModelContext`.
- In `app/Sunclub/Sources/Services/SunclubBackupDocument.swift`, define the `FileDocument` and codable payload types that serialize the raw store files.
- In `app/Sunclub/Sources/Services/AppState.swift`, add methods that wrap the service for Settings and UITest usage.

Do not add third-party dependencies. Use Foundation, SwiftData, SwiftUI, and Uniform Type Identifiers only.

Revision note: created this ExecPlan on 2026-04-02 to guide the first implementation of local export/import backups with migration-aware restore.
