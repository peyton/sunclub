# iCloud Cross-Device Sync Runtime Fix

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This repository follows `/Users/peyton/.agents/PLANS.md`; this document must be maintained in accordance with that file.

## Purpose / Big Picture

Sunclub already stores history locally and syncs that history to the user's private iCloud database through `CKSyncEngine`. After this fix, an install running on macOS and an install running on iOS should both participate in the same CloudKit sync flow even when the macOS runtime cannot resolve the shared app-group container. A user can see the fix working by updating one device, syncing, then observing the same history appear on the other device, and by running the unit and migration tests added here.

## Progress

- [x] (2026-04-09 12:22Z) Audited the existing CloudKit, SwiftData, and migration wiring in `app/Sunclub/Sources/Services/AppState.swift`, `app/Sunclub/Sources/Services/CloudSyncCoordinator.swift`, and `app/Sunclub/Sources/Models/SunclubSchema.swift`.
- [x] (2026-04-09 12:25Z) Identified the likely root cause: `AppState` silently swaps in `NoopCloudSyncCoordinator` when `RuntimeEnvironment.hasAppGroupContainer` is false, even though `SunclubModelContainerFactory` already falls back to `Application Support` when the app-group container is unavailable.
- [x] (2026-04-09 12:29Z) Added `RuntimeEnvironmentSnapshot`, preview detection, and an `AppState.defaultCloudSyncCoordinator` helper so production runtime keeps live CloudKit sync even when `hasAppGroupContainer` is false.
- [x] (2026-04-09 12:31Z) Added `SunclubTests` regressions that prove production runtime still uses live CloudKit sync without an app-group container, and that preview/test runtimes still use `NoopCloudSyncCoordinator`.
- [x] (2026-04-09 12:33Z) Ran `just test-unit`; the suite passed with 87 tests, including `MigrationTests` and the new cloud-sync runtime regressions.
- [x] (2026-04-09 12:35Z) Ran `just lint`; fixed the new ExecPlan’s Markdown block style so lint could pass cleanly.

## Surprises & Discoveries

- Observation: the local persistence layer already treats the app-group container as optional.
  Evidence: `SunclubModelContainerFactory.sharedStoreURL()` in `app/Sunclub/Sources/Models/SunclubSchema.swift` first asks for the app-group container and then falls back to `.applicationSupportDirectory`.
- Observation: the current sync policy does not match that storage behavior.
  Evidence: `AppState.init` in `app/Sunclub/Sources/Services/AppState.swift` currently switches to `NoopCloudSyncCoordinator` whenever `RuntimeEnvironment.hasAppGroupContainer` is false.

## Decision Log

- Decision: treat missing app-group storage as a widget/storage concern, not as a reason to disable CloudKit sync.
  Rationale: the app already has a safe fallback store location, and manual CloudKit sync in `CloudSyncCoordinator` does not depend on the app-group URL lookup.
  Date/Author: 2026-04-09 / Codex
- Decision: keep previews and tests on the noop coordinator.
  Rationale: previews and XCTest should stay deterministic and should not attempt live CloudKit traffic.
  Date/Author: 2026-04-09 / Codex

## Outcomes & Retrospective

The bug fix stayed focused on runtime policy instead of persistence shape. No schema change was needed because the existing migration path already preserved `CloudSyncPreference` and other sync metadata correctly; the break was that some production installs never started the real CloudKit coordinator. The resulting code now keeps live sync enabled for real runtime even when the app-group container is unavailable, while previews and tests remain deterministic on the noop path. The unit suite and migration suite passed after the change, which means update-time store migration behavior remained intact.

## Context and Orientation

The user-visible sync surface is owned by `app/Sunclub/Sources/Services/AppState.swift`. That file chooses which cloud-sync coordinator to use and starts the coordinator at launch. The real sync engine lives in `app/Sunclub/Sources/Services/CloudSyncCoordinator.swift`; it serializes change batches and revisions into CloudKit records and reads them back into the local revision history. The persisted SwiftData store and all migration stages live in `app/Sunclub/Sources/Models/SunclubSchema.swift`. Migration regression coverage lives in `app/Sunclub/Tests/MigrationTests.swift`, and general app-state unit coverage lives in `app/Sunclub/Tests/SunclubTests.swift`.

In this repository, an "app-group container" is the shared filesystem directory looked up through `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`. It is useful for shared local storage, especially widgets, but it is not the CloudKit database itself. A "noop coordinator" means the fake implementation in `NoopCloudSyncCoordinator` that never talks to CloudKit and only mutates local status fields.

## Plan of Work

Add a small runtime snapshot type in `app/Sunclub/Sources/Shared/RuntimeEnvironment.swift` so `AppState` can reason about the current runtime in a testable way. Extend the runtime environment with an explicit SwiftUI-preview check. In `app/Sunclub/Sources/Services/AppState.swift`, replace the current `hasAppGroupContainer` gate with a helper that chooses `NoopCloudSyncCoordinator` only for tests and previews. Keep startup behavior aligned with that same runtime snapshot so the app starts live sync only in real runtime.

Add unit coverage in `app/Sunclub/Tests/SunclubTests.swift` that calls the coordinator-selection helper with `hasAppGroupContainer = false` and a non-test, non-preview runtime, then asserts that `CloudSyncCoordinator` is chosen. Add the complementary regression that preview and test runtimes still choose `NoopCloudSyncCoordinator`. Keep existing migration coverage intact and rerun it through `just test-unit`; if any migration-specific gap appears, add or update `app/Sunclub/Tests/MigrationTests.swift`.

## Concrete Steps

From `/Users/peyton/.codex/worktrees/7157/sunclub`:

1. Edit `app/Sunclub/Sources/Shared/RuntimeEnvironment.swift` to add preview detection and a testable runtime snapshot value.
2. Edit `app/Sunclub/Sources/Services/AppState.swift` to centralize default coordinator selection and remove the app-group gate from production sync.
3. Add regression tests in `app/Sunclub/Tests/SunclubTests.swift`.
4. Run:
   `just test-unit`

Expected success signal:

```text
2026-04-09 ... test-unit ...
Test Suite 'SunclubTests' passed ...
Test Suite 'MigrationTests' passed ...
** TEST SUCCEEDED **
```

## Validation and Acceptance

Acceptance is met when a production runtime chooses `CloudSyncCoordinator` even if `hasAppGroupContainer` is false, when preview and test runtimes still use `NoopCloudSyncCoordinator`, and when the existing migration tests still pass against the updated code. The fix is only complete once `just test-unit` passes, `just lint` passes, and the new regression names make the runtime policy obvious to a future reader.

## Idempotence and Recovery

The code changes are additive and safe to rerun. The tests create their own in-memory or temporary stores. If the runtime-policy change causes an unexpected preview or test failure, the safe recovery path is to keep the new runtime snapshot type, restore the noop behavior only for preview and XCTest runtimes, and rerun `just test-unit` before proceeding.

## Artifacts and Notes

The key evidence to preserve is the unit-test output showing the new coordinator-selection regression names and the migration suite passing after the policy change.

```text
Test Case '-[SunclubTests.SunclubTests testAppStateStartsInjectedCloudSyncCoordinatorWhenProductionRuntimeLacksAppGroupContainer]' passed
Test Case '-[SunclubTests.SunclubTests testDefaultCloudSyncCoordinatorUsesLiveSyncWhenAppGroupContainerIsUnavailableInProductionRuntime]' passed
Test Case '-[SunclubTests.SunclubTests testDefaultCloudSyncCoordinatorUsesNoopSyncForTestsAndPreviews]' passed
Test Suite 'MigrationTests' passed
** TEST SUCCEEDED **
```

## Interfaces and Dependencies

`RuntimeEnvironment` must expose a stable way to ask whether the app is running tests, running SwiftUI previews, or has an app-group container available. `AppState` must expose one internal helper that returns the default `CloudSyncControlling` implementation for a given `SunclubHistoryService` and runtime snapshot so `SunclubTests` can assert the selection policy directly. The existing CloudKit types in `CloudSyncCoordinator.swift` remain unchanged; no new external dependencies are required.

Revision note: created on 2026-04-09 after tracing cross-device sync failure to the runtime coordinator-selection policy, and updated the same day after implementation and verification to record the completed runtime-policy fix and passing test/lint results.
