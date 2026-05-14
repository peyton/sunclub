# Restore iCloud History After Reinstall

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This repository follows `/Users/peyton/.agents/PLANS.md`; this document must be maintained in accordance with that file.

## Purpose / Big Picture

When a user deletes Sunclub and reinstalls it on a device that was previously syncing with iCloud, the app should check the user's private CloudKit database before treating the new empty local store as final. After this change, a reinstall with existing iCloud history restores that history and opens the normal app. A reinstall with no remote history falls through to onboarding. A network, entitlement, or iCloud account failure shows a retry path instead of silently presenting an empty database as if restore had succeeded.

## Progress

- [x] (2026-05-14 00:00Z) Audited the existing revision-history sync path, launch bootstrap order, and TestFlight release rules.
- [x] (2026-05-14 01:45Z) Implement restore-first CloudKit startup and the initial iCloud restore gate.
- [x] (2026-05-14 01:50Z) Add unit regressions for fresh-install restore, empty-store fallback, sync failure UI state, and send-failure recovery policy.
- [x] (2026-05-14 02:00Z) Run the local verification commands from the repo root.
- [ ] Push a PR, monitor CI, merge when green, and cut a verified TestFlight build.

## Surprises & Discoveries

- Observation: Sunclub already keeps the empty bootstrap history batch local-only when settings are default and there are no records.
  Evidence: `SunclubHistoryService.bootstrapIfNeeded()` creates `.migrationSeed` with `isLocalOnly` when the projected store is empty.
- Observation: `CloudSyncCoordinator.configureEngineIfNeeded()` queued `saveZone` before the first fetch.
  Evidence: the old startup path configured `CKSyncEngine`, immediately added `pendingDatabaseChanges: [.saveZone(...)]`, then called `sendChanges` before `fetchChanges`.
- Observation: local Tuist cache upload/auth failures do not block the unit suite.
  Evidence: `just test-unit` reported Tuist 401 warnings for quarantined-test/build-result upload, but ran all tests and ended with `Test Succeeded`.

## Decision Log

- Decision: keep custom revision-history sync and keep SwiftData CloudKit mirroring disabled.
  Rationale: Sunclub relies on explicit revision batches, undo, import sessions, and local-only recovery state that automatic SwiftData mirroring would hide.
  Date/Author: 2026-05-14 / Codex
- Decision: treat default empty migration seeds as non-meaningful data for restore and publication decisions.
  Rationale: a fresh reinstall needs a local SwiftData store to launch, but that synthetic store must not win over real iCloud history or be uploaded as user history.
  Date/Author: 2026-05-14 / Codex
- Decision: show the iCloud restore gate only for fresh production launches where sync is enabled and the local store is effectively empty.
  Rationale: existing users should not see a blocking interstitial during normal app launches, and tests/previews should remain deterministic.
  Date/Author: 2026-05-14 / Codex

## Outcomes & Retrospective

Implemented restore-first launch sync for effectively empty local stores. The live coordinator now fetches CloudKit changes before saving the local zone or sending local batches, filters synthetic empty migration seeds out of publishable batches, and returns a startup result consumed by `AppState`. Remote batches, daily record revisions, and settings revisions rebuild projections before onboarding routing decides the app surface.

The launch gate now shows a compact "Checking iCloud" screen only for production-like launches with iCloud sync enabled and an effectively empty local store. Restore success routes into the app, no remote history falls through to onboarding, and startup failure exposes retry and "Continue on This Phone".

The failure recovery path now requeues the custom zone and the failed record when CloudKit reports zone-not-found or unknown-item send failures, then fetches remote state. Server-record conflicts fetch remote state instead of silently leaving the app empty.

Verification from the repo root passed:

    SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 TEST_XCODEBUILD_MAX_ATTEMPTS=1 just test-unit
    just ci-lint
    just test-python
    just cloudkit-doctor
    just cloudkit-export-schema
    just cloudkit-validate-schema

## Context and Orientation

Sunclub stores user-facing settings and daily sunscreen logs in SwiftData under `app/Sunclub/Sources/Models`. The app does not use SwiftData's automatic CloudKit mirroring; every `ModelConfiguration` in `SunclubModelContainerFactory` deliberately uses `cloudKitDatabase: .none`. Instead, `SunclubHistoryService` in `app/Sunclub/Sources/Services/SunclubHistoryService.swift` writes durable change batches and revision rows, then rebuilds projected `Settings` and `DailyRecord` models from those revisions.

`CloudSyncCoordinator` in `app/Sunclub/Sources/Services/CloudSyncCoordinator.swift` serializes those batches and revisions into CloudKit records in the user's private database. `CKSyncEngine` is Apple's stateful helper for tracking pending CloudKit sends and fetch tokens. The coordinator owns the engine, provides CloudKit records for local pending changes, applies fetched records back into `SunclubHistoryService`, and persists sync diagnostics.

`AppState` in `app/Sunclub/Sources/Services/AppState.swift` bootstraps the history service, chooses a live or noop cloud coordinator, starts sync on launch, and exposes the state consumed by SwiftUI. `RootView` in `app/Sunclub/Sources/Shared/RootView.swift` currently decides whether to show onboarding solely from `settings.hasCompletedOnboarding`; this bug fix adds one more gate for the first iCloud restore check.

## Plan of Work

First, add a small result type to `CloudSyncControlling.start()` so launch code can tell whether startup restored remote data, found no remote data, skipped because sync is disabled, or failed. Update the noop coordinator and test coordinators to return that result.

Next, teach `SunclubHistoryService` to identify an effectively empty local store. A store is effectively empty when it has no projected records, default settings, and only synthetic default migration history. Add a publishable-batch helper that filters those synthetic batches out before CloudKit queuing.

Then, change `CloudSyncCoordinator` startup so a fresh empty store calls `fetchChanges` before queuing `saveZone` or sending local changes. If the fetch restores meaningful history, rebuild projections, refresh the app, and return `restoredRemoteHistory`. If no remote history arrives, create the zone as needed and return `noRemoteHistory`. Keep manual `syncNow()` on the normal send-then-fetch path, but use the same publishable-batch filter. Add a small engine-driver seam so tests can assert operation order without live CloudKit.

Finally, add `InitialICloudRestoreState` to `AppState` and a compact `InitialICloudRestoreView` in `RootView`. The view shows "Checking iCloud" while startup restore is active and offers retry or continue only when startup restore fails. Do not show this gate for normal existing local stores, tests, previews, or disabled sync.

## Concrete Steps

Run all commands from `/Users/peyton/.codex/worktrees/a634/sunclub`.

1. Create the branch `codex/fix-icloud-reinstall-restore` from `origin/master`.
2. Edit `CloudSyncCoordinator.swift`, `SunclubHistoryService.swift`, `AppState.swift`, `RootView.swift`, and the unit tests.
3. Run:

       just test-unit
       just ci-lint
       just test-python
       just cloudkit-doctor
       just cloudkit-export-schema
       just cloudkit-validate-schema

4. Commit only the hotfix files, leaving unrelated `mise.lock` drift unstaged.
5. Push, open a PR, monitor checks, merge when green, then use a clean temporary worktree to run `just release-testflight 2.0.3` unless a newer tag exists.

## Validation and Acceptance

Acceptance is met when unit tests prove that a fresh empty install fetches iCloud before sending, remote settings and daily record revisions restore the projected app state, synthetic empty bootstrap history is not publishable, no remote history falls through to onboarding, and CloudKit startup failure exposes retry/continue state.

Release acceptance is met only after the merged commit has a successful TestFlight workflow, the build is available to the Internal tester group, and the downloaded workflow artifact proves the final exported IPA has production CloudKit, push, app-group, HealthKit, WeatherKit, and `get-task-allow=false` entitlements where expected.

## Idempotence and Recovery

The local tests use in-memory SwiftData stores and fake sync drivers, so they are safe to repeat. The CloudKit schema commands read and write ignored local state under `.state/cloudkit`. If TestFlight tag creation fails before upload, do not move the pushed tag; use the next patch version for the next attempt. Keep unrelated dirty files, especially `mise.lock`, out of the commit unless the task intentionally changes them.

## Artifacts and Notes

Important evidence to preserve after implementation:

    Test Case '-[SunclubTests.SunclubTests testFreshInstallFetchesICloudBeforeSendingEmptyBootstrap]' passed
    Test Case '-[SunclubTests.SunclubTests testFreshInstallRestoresRemoteSettingsAndRecords]' passed
    Test Case '-[SunclubTests.SunclubTests testInitialICloudRestoreFailureCanRetryOrContinueLocally]' passed
    Test Case '-[SunclubTests.SunclubTests testZoneMissingSendFailureRequeuesZoneAndRecordBeforeFetch]' passed
    Test Case '-[SunclubTests.SunclubTests testUnknownItemSendFailureRequeuesZoneAndRecordBeforeFetch]' passed

## Interfaces and Dependencies

In `CloudSyncCoordinator.swift`, define:

    enum CloudSyncStartResult: Equatable {
        case restoredRemoteHistory
        case noRemoteHistory
        case skippedDisabled
        case failed(String)
    }

Update `CloudSyncControlling.start()` to return `CloudSyncStartResult`.

In `AppState.swift`, define:

    enum InitialICloudRestoreState: Equatable {
        case notNeeded
        case checking
        case restored
        case noRemoteHistory
        case failed(String)
        case continuedLocally
    }

Expose `retryInitialICloudRestore()` and `continueWithoutInitialICloudRestore()` on `AppState`.

Revision note: created on 2026-05-14 to guide and record the iCloud reinstall-restore hotfix requested after a real reinstall produced an empty local database.
