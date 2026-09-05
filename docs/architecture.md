# Architecture and feature recipe

## Ownership

| Area                                                        | Owner                                                      |
| ----------------------------------------------------------- | ---------------------------------------------------------- |
| Observable app state and coordination                       | `app/Sunclub/Sources/Services/AppState.swift`              |
| Production/test dependencies and clock                      | `Services/SunclubAppDependencies.swift`                    |
| Durable log, edit, backfill, reapply and reminder mutations | `Services/SunclubMutationService.swift`                    |
| Foreground log validation and timestamp policy              | `Services/SunclubLogRequestResolver.swift`                 |
| Revisions, projections and rollback                         | `Services/SunclubHistoryService.swift` and history helpers |
| UV refresh and stale-response rejection                     | `Services/SunclubUVCoordinator.swift`                      |
| Reminder health, permission and scheduling                  | `Services/SunclubReminderCoordinator.swift`                |
| Restore, recovery, import and export coordination           | `Services/SunclubRecoveryCoordinator.swift`                |
| Activity sharing policy and transport coordination          | `Services/SunclubAccountabilityCoordinator.swift`          |
| Pure screen calculations                                    | `Views/Presentation/`                                      |
| Shared styling and product screen wrappers                  | `Shared/AppDesignSystem.swift`, `Shared/AppTheme.swift`    |
| Persistence schema and container factory                    | `Models/SunclubSchema.swift`                               |
| Outside-app authorization and execution                     | `Services/SunclubAutomationRuntime.swift`                  |
| Navigation and legacy redirects                             | `Shared/AppRoute.swift`, `Shared/RootView.swift`           |
| Target assembly and shared source groups                    | `app/Sunclub/Project.swift`                                |

Paths without a prefix are relative to `app/Sunclub/Sources/`.

AppState coordinates observable state and foreground effects. Services accept the
specific values/protocols they need. The mutation service delegates transactions
to revision history and returns the existing change batch; a nil batch is an
unchanged write. Only a successful changed batch triggers follow-up effects.
Foreground effects include HealthKit, Live Activity, reminders, widget snapshots
and CloudKit queue updates. Automation keeps its permission check before mutation
and performs its own supported follow-up effects afterward.

Persisted types are compatibility boundaries. Keep older schema definitions
immutable and use the container factory for previews, tests and production.
CloudKit uses manual CKSyncEngine; do not enable SwiftData mirroring.

## Screens and tests

- Home: `TimelineHomeView`; status, scrub gesture and display values in
  `Views/Components/Timeline*`. Legacy route aliases still resolve through RootView.
- Settings: one transient state owner in `SettingsView`; navigation, reminders,
  health/weather and data sections in adjacent `Settings*.swift` files.
- History: list/calendar in `HistoryView`; editor in `HistoryRecordEditorView`.
- Unit tests: behavior-named classes with common `SunclubTestCase` fixtures.
  Mutation tests assert persistence, receipts, no-ops, failures and effects;
  source checks cover architectural contracts across related files.
- UI: `SunclubSmokeUITests` contains the 13 PR scenarios. `SunclubUITests` contains
  the remaining scenarios. Both inherit `SunclubUITestCase`; full runs select the
  target so neither class can be omitted accidentally.

## Add or change a feature

1. Read the relevant [release gate](release-gates.md), public
   [automation contract](app-automation.md) and product spec.
2. Put durable behavior in a focused service. Reuse mutation/history services;
   use explicit inputs, existing protocols and the injected clock.
3. Wire AppState coordination and any applicable automation entrypoint to the
   same behavior. Keep permission checks outside shared persistence. Gate effects
   on changed receipts and test failure/no-op paths.
4. Put display calculations beside the screen as pure helpers. Keep design tokens,
   accessibility identifiers, Dynamic Type and Reduce Motion intact.
5. Wire routes through AppRoute, RootView, App Intents and URL parsing together.
   Update Settings visibility, `docs/app-automation.md`, product docs and web copy
   when public automation changes.
6. Add tests to the responsibility-specific class. Persisted changes need a schema
   bump and tests opening the prior shipped store. Do not edit the generated project;
   source membership invalidates generation automatically.
7. Run focused checks, then the [candidate validation](commands.md) required by the
   changed surface. Refactor/release candidates require full exact-SHA GitHub CI.

## Build and CI

`just` is the public interface. `scripts/tooling/common.sh` owns environment setup,
Xcode preparation, generation fingerprinting and Tuist invocation. Environment
setup has no Xcode side effects. Signing and export remain separate release code.
The local setup action pins tools and Xcode once per GitHub job. CI policy lives in
`scripts/tooling/ci_policy.py`; the final `CI` job checks every expected result.

See [commands](commands.md), [CI stability](ci-release-stability.md), and
[historical troubleshooting](development-troubleshooting.md).
