# iCloud Sync, Recovery, and Undoable History ExecPlan

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds. This repository does not check in `PLANS.md`, so this document follows the shared execution-plan guidance from `/Users/peyton/.agents/PLANS.md`.

## Purpose / Big Picture

Sunclub already had a local backup path, but the live store still behaved like a mutable snapshot: edits replaced projected state directly, imports were hard to reason about, and there was no durable way to review, undo, or safely sync history across devices. This change moves the app to a revision-backed local store with projected current models, adds default-on iCloud sync through CloudKit private-database records, keeps local export/import available, and exposes a recovery UI so imports, merges, and history edits stay recoverable instead of destructive.

The change matters because streaks are one of the core product loops. The implementation has to preserve the visible streak timeline during merges and recovery work, keep old local backup migration working, and avoid accidentally deleting or rolling back the user's iCloud history when they import a local backup.

## Progress

- [x] (2026-04-02 15:23Z) Merged `origin/master` into the worktree before the CloudKit and persistence changes.
- [x] (2026-04-02 15:36Z) Added `SunclubSchemaV4`, revision/history models, sync/recovery models, and a V3 -> V4 migration that seeds revision history plus the default-on sync preference.
- [x] (2026-04-02 15:53Z) Reworked `AppState` and `SunclubHistoryService` so durable writes flow through change batches, projected-state rebuilds, undo/redo helpers, import sessions, and conflict review.
- [x] (2026-04-02 16:08Z) Added `CloudSyncCoordinator` with a test `NoopCloudSyncCoordinator`, local-only import publishing rules, and batch-level CloudKit serialization.
- [x] (2026-04-02 16:19Z) Updated Settings, Home, History, and a new `RecoveryView` so iCloud sync, imported backups, conflicts, and undoable changes are visible in the product UI.
- [x] (2026-04-02 16:34Z) Added CloudKit repo-local helper scripts, Tuist-driven container configuration, updated product docs, and expanded unit plus UI coverage for sync and recovery flows.
- [x] (2026-04-02 14:24Z) Re-ran generation, unit tests, UI tests, and lint on the final code state; `cloudkit-validate-schema` remains externally blocked until a local CloudKit schema export and management token are present.
- [x] (2026-04-02 17:42Z) Added a CloudKit doctor flow, aligned the Tuist signing team with the repo `TEAM_ID`, and documented the remaining Apple-side manual container creation step after confirming `cktool` does not create containers from this CLI.

## Surprises & Discoveries

- Observation: backup import had already been converted away from destructive live-store replacement, but imported projected rows could still lose to tie-timestamp ordering and appear not to become the visible current state.
  Evidence: the history-service import path needed a monotonic batch creation date so imported revisions always sort after the restore-point batch they intentionally supersede.
- Observation: once history writes became uniformly batch-driven, streak-risk reminder refreshes also became uniformly post-mutation, which changed one older unit-test expectation for deleting a non-today day.
  Evidence: `testDeleteNonTodayRecordDoesNotCancelReapplyReminder` now sees one refresh after the original log and one after the delete batch instead of relying on the earlier inconsistent behavior.
- Observation: the repo did not yet have any CloudKit automation seam, so container, environment, and schema-file defaults needed to live in repo-local scripts instead of hidden local notes.
  Evidence: before this change there was no `scripts/cloudkit/` directory and no `just` targets for `cktool`.
- Observation: enabling app-level iCloud/CloudKit capabilities also changed SwiftData's default store behavior, even though sync is implemented manually with `CKSyncEngine`.
  Evidence: once the entitlements and container settings were added, migration tests started failing until every `ModelConfiguration` in `SunclubModelContainerFactory` and the legacy test fixtures explicitly set `cloudKitDatabase: .none`.
- Observation: the repo had drifted to two different Apple teams: Tuist generated the app for `AE5E5HVG56` while all release and CloudKit tooling defaulted to `3VDQ4656LX`.
  Evidence: `Project.swift` hardcoded `AE5E5HVG56`, but `scripts/tooling/sunclub.env`, App Store export options, and the CloudKit token all targeted `3VDQ4656LX`.
- Observation: the installed `cktool` CLI can validate management-token team access and schema operations, but it does not expose a create-container or list-containers command.
  Evidence: `xcrun cktool --help` lists schema, record, token, and team commands only; Apple’s account help still documents iCloud container creation in Certificates, IDs & Profiles with Account Holder/Admin permissions.

## Decision Log

- Decision: use a revision-backed store plus projected `DailyRecord` and `Settings` rows instead of replacing the app with SwiftData automatic CloudKit mirroring.
  Rationale: this feature needs an app-controlled sync toggle, explicit publish-after-import behavior, undoable merges, and recovery screens that mirror CloudKit metadata. Automatic mirroring would hide too much of that state.
  Date/Author: 2026-04-02 / Codex
- Decision: keep local backup import local-only by default and require a separate publish step before imported batches can be sent to iCloud.
  Rationale: importing a file is a recovery action, not proof that the user wants to overwrite or delete their synced history on other devices.
  Date/Author: 2026-04-02 / Codex
- Decision: recompute streak values from the projected record timeline after each rebuild, even if that lowers an old cached `longestStreak`.
  Rationale: once imports, undo, restore, and conflict auto-merges all become first-class history operations, the derived streak must reflect the visible projected timeline instead of preserving stale counters.
  Date/Author: 2026-04-02 / Codex
- Decision: put CloudKit automation under `scripts/cloudkit/` and expose it through `just` rather than relying on ad-hoc `xcrun cktool ...` snippets.
  Rationale: the repo instructions prefer repo-local entry points, and the container/environment/schema defaults belong in one maintained place.
  Date/Author: 2026-04-02 / Codex

## Outcomes & Retrospective

Shipped:

- `SunclubSchemaV4` now persists change batches, record and settings revisions, sync preference/state, diagnostics, import sessions, and conflict items while still projecting `DailyRecord` and `Settings` for the UI.
- `AppState` now writes durable user actions through revision batches, recomputes streaks from projected history, and exposes sync, publish, restore, undo, redo, and conflict-review actions to the UI.
- Backup import stays migration-aware and local-first. Imported changes show up as recoverable local batches until the user explicitly publishes them to iCloud.
- Settings now includes default-on iCloud sync controls, visible sync status, pending imported-change actions, and a route into `Recovery & Changes`.
- Home and History now surface pending imported changes or auto-merged conflicts without requiring the user to guess that a hidden merge occurred.
- The repo now includes `scripts/cloudkit/*.sh` helpers plus `just cloudkit-*` targets for saving tokens, exporting schemas, validating schemas, importing schemas, and resetting the development schema.
- The repo now also includes `just cloudkit-doctor` and `just cloudkit-ensure-container`, which validate the management token, confirm the configured team matches Xcode signing, run a signed provisioning build, and point directly to Apple’s official container/App ID setup flow if the signed app still lacks CloudKit entitlements.

Verification:

- `just generate` passed on 2026-04-02 after the final Tuist/entitlement/config changes.
- `just test-unit` passed on 2026-04-02 with 73 tests passing, including the new migration, backup, sync-toggle, conflict, undo, and streak recomputation coverage.
- `just test-ui` passed on 2026-04-02 with 29 tests passing, including the new iCloud toggle, import publish/restore, conflict review, and recovery undo flows.
- `just lint` passed on 2026-04-02 after splitting the import path in `SunclubHistoryService` and fixing a ShellCheck string-literal warning in the new CloudKit helpers.
- `just cloudkit-validate-schema` is currently blocked in a clean checkout until a management token is saved and a schema file exists locally. The observed failure was: schema file missing at `.state/cloudkit/sunclub-cloudkit-schema.json`, and `just cloudkit-export-schema` then failed because `cktool` had no management token available.
- After saving a management token, `cktool get-teams` succeeded for team `3VDQ4656LX`, which confirms the token type and team-level management permissions are correct. The remaining failure is container-side: `cktool export-schema` still returns `authorization-failed`, and a signed provisioning build on `3VDQ4656LX` currently strips the CloudKit entitlements from the app, which means the App ID on that team still lacks the `iCloud.app.peyton.sunclub` assignment.
