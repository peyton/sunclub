# Recover TestFlight Data Loss

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document follows `/Users/peyton/.agents/PLANS.md`. It is self-contained so a contributor can restart this recovery effort from this file and the current repository tree.

## Purpose / Big Picture

Some TestFlight users updated from v1.0.18 to v1.0.26 and opened Sunclub to onboarding with default settings. The goal is to make a future app update recover those users automatically when the old local store is still on device, and to prevent empty default local state from overwriting meaningful CloudKit history. A user should be able to install the fixed update, open the app, keep completed onboarding, see recovered settings and daily records, and have the recovered history queued for iCloud sync when sync is enabled.

The demonstrable behavior is covered by unit tests that seed a legacy Application Support `default.store`, open an empty app-group store, run launch recovery, and assert records, settings, import history, idempotence, and CloudKit publishability. Additional tests prove empty default seeds are local-only and cannot win over meaningful settings history.

## Progress

- [x] (2026-04-14 09:42Z) Confirmed the root cause from release artifacts: v1.0.18 final signed app lacked app-group and CloudKit entitlements while v1.0.26 carried them.
- [x] (2026-04-14 10:05Z) Added a store-location layer in `app/Sunclub/Sources/Models/SunclubSchema.swift` that exposes the current shared store and the legacy Application Support store.
- [x] (2026-04-14 10:15Z) Added `app/Sunclub/Sources/Services/SunclubStoreRecoveryService.swift` and wired launch recovery through `AppState` before onboarding state is evaluated.
- [x] (2026-04-14 10:22Z) Hardened `SunclubHistoryService` projection so empty/default bootstrap settings revisions are local-only and synthetic default settings revisions cannot beat meaningful history.
- [x] (2026-04-14 10:27Z) Added unit coverage in `app/Sunclub/Tests/StoreRecoveryTests.swift` and `app/Sunclub/Tests/MigrationTests.swift` for legacy recovery, idempotence, CloudKit default-seed safety, and empty versus non-empty migration behavior.
- [x] (2026-04-14 10:32Z) Ran `just test-unit`; all 213 unit tests passed.
- [x] (2026-04-14 10:35Z) Added the AGENTS data-preservation release gate.
- [x] (2026-04-14 10:37Z) Ran `just ci-lint`; lint exited successfully with warning-level SwiftLint findings only.
- [x] (2026-04-14 10:38Z) Ran `just cloudkit-doctor`, `just cloudkit-export-schema`, and `just cloudkit-validate-schema`; all exited successfully for `iCloud.app.peyton.sunclub` development.
- [x] (2026-04-14 10:38Z) Tightened fingerprint idempotence and reran `just test-unit` and `just ci-lint`; both exited successfully.
- [x] (2026-04-14 10:40Z) Committed, pushed branch `codex/recover-testflight-data-loss`, and opened non-draft PR `https://github.com/peyton/sunclub/pull/108` against `master`.

## Surprises & Discoveries

- Observation: v1.0.18 had the right capabilities in its provisioning profile but not in the final signed app.
  Evidence: inspecting the v1.0.18 IPA showed only `application-identifier`, `beta-reports-active`, `com.apple.developer.team-identifier`, and `get-task-allow` in runtime entitlements.

- Observation: v1.0.26 restored the app-group and CloudKit runtime entitlements.
  Evidence: release diagnostics for run `24383578595` showed `group.app.peyton.sunclub`, `iCloud.app.peyton.sunclub`, CloudKit services, and production push entitlements.

- Observation: the generated Xcode project snapshots `Sources/**` file membership. A new Swift file under that glob was not compiled until the workspace was regenerated.
  Evidence: the first `just test-unit` build failed with `Cannot find type 'SunclubStoreRecoveryService' in scope`; running `just generate` regenerated `app/Sunclub/Sunclub.xcodeproj` and included the new file.

## Decision Log

- Decision: recover from the legacy Application Support store instead of copying it over the app-group store.
  Rationale: merge-based recovery preserves any data already written in the current app-group store and remains safe if a user launched v1.0.26 before installing the fix.
  Date/Author: 2026-04-14 / Codex.

- Decision: open the legacy store copy through `SunclubModelContainerFactory.makeDiskBackedContainer(url:)`.
  Rationale: this forces all historical SwiftData migrations to run before recovery reads settings, records, or revision history.
  Date/Author: 2026-04-14 / Codex.

- Decision: record recovery as a durable import session whose source description contains a fingerprint of the legacy store files.
  Rationale: the same Application Support store can remain on disk after recovery; the fingerprint makes the launch recovery idempotent without deleting the source and without blocking a distinct legacy store snapshot from being evaluated.
  Date/Author: 2026-04-14 / Codex.

- Decision: synthesize a single recovery batch instead of replaying every legacy history batch.
  Rationale: the recovery problem is same-app data preservation, not arbitrary backup import replay. One recovery batch minimizes conflict surface while preserving projected domain state.
  Date/Author: 2026-04-14 / Codex.

- Decision: ignore only synthetic default settings revisions from `migrationSeed` and default `conflictAutoMerge`, not normal user changes.
  Rationale: a real user can intentionally choose default-looking values. Only internal bootstrap or polluted auto-merge revisions should be suppressed when meaningful history exists.
  Date/Author: 2026-04-14 / Codex.

## Outcomes & Retrospective

The implementation now has passing unit coverage for the exact entitlement-transition failure mode: an old meaningful Application Support store is recovered into a new app-group store without deleting current data, and the recovery import is publishable when iCloud sync is enabled. Projection hardening also prevents newer synthetic default settings from overriding older meaningful settings.

Repository validation passed with `just test-unit` and `just ci-lint`. CloudKit development access and schema validation also passed. The branch was committed, pushed, and opened as non-draft PR `https://github.com/peyton/sunclub/pull/108`.

## Context and Orientation

Sunclub stores app data with SwiftData. SwiftData is Apple’s object persistence framework; in this app, models such as `Settings` and `DailyRecord` are stored in a SQLite-backed `default.store`. The app uses `app/Sunclub/Sources/Models/SunclubSchema.swift` to define every shipped schema version and to create the live `ModelContainer`, which is the SwiftData object that opens the store.

The important store-location behavior is in `SunclubModelContainerFactory` inside `app/Sunclub/Sources/Models/SunclubSchema.swift`. Before this change, the factory chose the app-group store when `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)` returned a URL, and fell back to the app sandbox Application Support directory otherwise. The v1.0.18 TestFlight app did not have a runtime app-group entitlement, so `containerURL` failed and users wrote to the Application Support `default.store`. The v1.0.26 app had the app-group entitlement, so it opened a different, empty app-group `default.store`.

Sunclub also has manual CloudKit sync implemented by `app/Sunclub/Sources/Services/CloudSyncCoordinator.swift` and `app/Sunclub/Sources/Services/SunclubHistoryService.swift`. CloudKit is Apple’s iCloud database. This app does not use SwiftData CloudKit mirroring; every SwiftData store configuration must keep `cloudKitDatabase: .none`. `SunclubHistoryService` owns revision history, projected settings, projected daily records, import sessions, and the pending batches that `CloudSyncCoordinator` uploads.

The main launch coordinator is `app/Sunclub/Sources/Services/AppState.swift`. It opens the live container, bootstraps revision history, refreshes settings and records, decides whether onboarding is complete, and starts CloudKit sync.

## Plan of Work

First, extend `SunclubSchema.swift` with a small store-location layer. The layer must expose the current shared store URL using the existing app-group-first behavior and must also expose the legacy Application Support `default.store` even when the app group is available. Existing container creation continues to use the current shared store and continues to set `cloudKitDatabase: .none`.

Second, add `SunclubStoreRecoveryService` under `app/Sunclub/Sources/Services/`. On launch, after the live container opens and before app state is refreshed for onboarding, the service checks whether the current store is app-group backed and whether a separate Application Support store exists. If so, it copies the legacy store files to a temporary directory, opens the copy through the model-container factory, verifies that the imported store has meaningful settings or records, and asks `SunclubHistoryService` to merge the projected domain state.

The merge is non-destructive. It inserts imported daily records only for days missing from the current store. It recovers settings fields only when the current field is still default or less complete, and `hasCompletedOnboarding: true` always wins over `false`. It records a `legacyStoreRecovery` batch and a `SunclubImportSession` source description containing a SHA-256 fingerprint of the legacy store files, so rerunning launch recovery skips the same source.

Third, harden `SunclubHistoryService` so an empty/default bootstrap state cannot be uploaded to CloudKit and cannot win settings projection. Empty bootstrap means the current store has default `Settings` and no daily records. In that case, migration or bootstrap seed batches are marked `isLocalOnly`. When projecting settings or resolving settings conflicts, filter synthetic default `migrationSeed` revisions and synthetic default `conflictAutoMerge` revisions whenever meaningful settings history exists.

Fourth, add tests that fail against the prior behavior. Seed a legacy Application Support store with completed onboarding, customized settings, and records. Open an empty app-group store, run recovery, and assert onboarding, settings, records, import history, CloudKit publishability, idempotence, and non-overwrite behavior. Add projection tests for empty seeds, polluted conflict auto-merges, and real user changes to default-looking values. Add migration tests for empty V3-to-current local-only seeds and non-empty V3-to-current publishable seeds.

Finally, document the release gate in `AGENTS.md`, run validation, commit, push, and create a non-draft PR.

## Concrete Steps

Work from `/Users/peyton/.codex/worktrees/7fc7/sunclub`.

Create the branch:

    git switch -c codex/recover-testflight-data-loss

Regenerate the workspace after adding new Swift source files:

    just generate

Run unit tests:

    just test-unit

Expected successful transcript:

    Test Suite 'All tests' passed
    Executed 213 tests, with 0 failures
    ** TEST SUCCEEDED **

Run lint:

    just ci-lint

Run CloudKit checks if credentials are available:

    just cloudkit-doctor
    just cloudkit-export-schema
    just cloudkit-validate-schema

Commit and create the PR:

    git add AGENTS.md docs/testflight-data-recovery-execplan.md app/Sunclub
    git commit -m "fix: recover legacy store after TestFlight entitlement repair"
    git push -u origin codex/recover-testflight-data-loss
    gh pr create --base master --head codex/recover-testflight-data-loss --title "fix: recover legacy store after TestFlight entitlement repair" --body "<verification summary>"

## Validation and Acceptance

The primary acceptance is the unit suite. `StoreRecoveryTests.testLegacyApplicationSupportStoreRecoveryRestoresSettingsAndRecordsThenPublishes` proves a meaningful Application Support store recovers into an empty app-group store and produces a publishable recovery batch. `StoreRecoveryTests.testLegacyApplicationSupportStoreRecoveryIsIdempotent` proves the same legacy store is not imported twice. `StoreRecoveryTests.testLegacyApplicationSupportStoreRecoveryDoesNotOverwriteCurrentRecordsOrSettings` proves recovery never deletes current data or overwrites current settings with less complete imported values.

CloudKit safety is accepted when `StoreRecoveryTests.testEmptyBootstrapCreatesLocalOnlyMigrationSeed` and `MigrationTests.testMigrationFromEmptyV3StoreCreatesLocalOnlyDefaultSeed` prove empty/default stores produce local-only bootstrap history. `StoreRecoveryTests.testNewerDefaultMigrationSeedDoesNotOverrideMeaningfulRemoteSettings` and `StoreRecoveryTests.testPollutedDefaultConflictMergeDoesNotOverrideMeaningfulRemoteSettings` prove meaningful settings history wins over synthetic defaults. `StoreRecoveryTests.testNormalUserChangeToDefaultSettingsStillProjects` proves legitimate user changes to default-looking values are preserved.

Migration compatibility is accepted when the existing V1, V2, and V3 migration tests continue to pass and when the non-empty V3 migration test still creates publishable history.

Lint acceptance is `just ci-lint` exiting with status 0. CloudKit acceptance, when credentials are available, is all three CloudKit commands exiting with status 0.

## Idempotence and Recovery

Launch recovery is safe to run repeatedly. It does not move or delete the legacy Application Support store. It copies the legacy store files to a temporary directory before opening them, which avoids mutating the original store during migration. The import session source description includes a fingerprint of the legacy store files; if the same legacy data is seen again, recovery returns without inserting another batch.

Recovery is additive. Current daily records are never deleted. An imported day is inserted only if the current projected record list does not already have that day. Current settings are retained unless they are default or less complete than imported settings. Completed onboarding is sticky: true wins over false.

If a test or generation command fails halfway, rerun `just generate` and then the failing command. Generated Xcode project changes are deterministic from `Project.swift` and the source tree.

## Artifacts and Notes

Root-cause artifact inspection:

    v1.0.18 final app entitlements:
    application-identifier
    beta-reports-active
    com.apple.developer.team-identifier
    get-task-allow

    v1.0.26 final app entitlements:
    com.apple.security.application-groups = group.app.peyton.sunclub
    com.apple.developer.icloud-container-identifiers = iCloud.app.peyton.sunclub
    com.apple.developer.icloud-services = CloudKit
    aps-environment = production

Initial compile failure and fix:

    Testing failed:
        Cannot find type 'SunclubStoreRecoveryService' in scope

    just generate
    Project generated.

Unit-test evidence:

    Test Suite 'StoreRecoveryTests' passed
        Executed 9 tests, with 0 failures
    Test Suite 'All tests' passed
        Executed 213 tests, with 0 failures
    ** TEST SUCCEEDED **

Lint and CloudKit evidence:

    just ci-lint
    Done linting! Found 30 violations, 0 serious in 114 files.

    just cloudkit-doctor
    CloudKit management API can export schema for iCloud.app.peyton.sunclub (development).

    just cloudkit-export-schema
    Exported CloudKit schema to .state/cloudkit/sunclub-cloudkit-schema.json

    just cloudkit-validate-schema
    Schema is valid.

## Interfaces and Dependencies

`app/Sunclub/Sources/Models/SunclubSchema.swift` defines:

    struct SunclubStoreLocation: Sendable {
        let currentStoreURL: URL
        let legacyApplicationSupportStoreURL: URL
        let isUsingAppGroupContainer: Bool
    }

    struct SunclubStoreLocator: Sendable {
        func resolveStoreLocation(fileManager: FileManager = .default) throws -> SunclubStoreLocation
    }

    enum SunclubModelContainerFactory {
        static let sharedStoreFilename = "default.store"
        @MainActor static func makeSharedContainer(fileManager: FileManager = .default) throws -> ModelContainer
        @MainActor static func makeSharedContainer(storeLocation: SunclubStoreLocation) throws -> ModelContainer
        @MainActor static func makeDiskBackedContainer(url: URL) throws -> ModelContainer
        static func sharedStoreLocation(fileManager: FileManager = .default) throws -> SunclubStoreLocation
    }

`app/Sunclub/Sources/Services/SunclubStoreRecoveryService.swift` defines:

    struct SunclubStoreRecoveryResult: Sendable {
        let importSessionID: UUID
        let recoveredRecordCount: Int
        let sourceDescription: String
    }

    @MainActor
    struct SunclubStoreRecoveryService {
        func recoverLegacyApplicationSupportStoreIfNeeded(
            into context: ModelContext,
            historyService: SunclubHistoryService
        ) throws -> SunclubStoreRecoveryResult?
    }

`app/Sunclub/Sources/Services/SunclubHistoryService.swift` exposes recovery helpers used by the launch service:

    func hasImportSession(sourceDescriptionPrefix: String) throws -> Bool
    func recoverLegacyDomainData(
        from importedContext: ModelContext,
        sourceDescription: String
    ) throws -> SunclubImportResult?

The implementation uses only Apple frameworks already present in the app: SwiftData for local persistence, Foundation for file handling, CryptoKit for SHA-256 fingerprints, and the existing manual CloudKit sync path for publishing recovered batches.

## Revision Note

2026-04-14 / Codex: Created this ExecPlan after implementing the recovery path and passing unit tests. The remaining tasks were lint, optional CloudKit validation, commit, push, and PR creation.

2026-04-14 / Codex: Updated validation status after `just ci-lint` and all requested CloudKit commands passed. The remaining task is PR creation.

2026-04-14 / Codex: Tightened launch-recovery idempotence to skip only the same fingerprinted legacy source, not every future legacy source with the same generic prefix. This keeps the fingerprint as the durable idempotence key.

2026-04-14 / Codex: Recorded PR `https://github.com/peyton/sunclub/pull/108` after creating the non-draft PR against `master`.
