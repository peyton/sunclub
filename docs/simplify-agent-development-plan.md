# Simplify Sunclub for agent development

## Approved scope

- Keep Tuist, existing features, platform targets, public automation contracts,
  persisted model identities/schema/store locations, signing and recovery gates.
- Delete proven unused code; retire dedicated act and Xcode Cloud support.
- One PR, ordered commits: tooling, CI, shared app behavior, cleanup/documentation.
- Baseline: 222 Python tests; master CI full UI step 35m19s, unit step 4m44s,
  development build 2m21s, production build 3m15s (run 33447161155).

## Task 1: Build tooling

- Keep just as public API. Bootstrap only installs locked tools/dependencies.
- Build/run default to SunclubDev Debug simulator and share derived data.
- Build/test/generate/screenshots/archive share explicit Xcode preparation.
- Fingerprint manifests, source/resource membership, tools and generation inputs.
- Explicit optional local cache setup; CI configures cache once per macOS job.
- Remove redundant build wrapper and unsupported-host code.
- Preserve bounded simulator retries, cache-off overrides, signing diagnostics.
- Test headless startup, generation invalidation, filters, and failures.

## Task 2: CI

- One local composite setup action for all workflows.
- Independent lint/Python/unit/UI/build jobs; device matrix retains both flavors.
- PR iOS changes: unit, UI smoke, both builds. Known docs/web-only PRs skip iOS;
  unknown paths or failed detection run iOS. Master/manual runs are always full.
- Smoke class contains existing onboarding, log, edit/backfill, undo, backup,
  reapply, UV, widget, URL permissions, swipe, accessibility and dark-mode tests.
- Required CI gate explicitly evaluates all expected jobs, including skips.
- After gate verification replace five required contexts with CI, preserving
  every other branch rule. Exact release SHA must have successful full CI.
- Preserve timeouts, cancellation, failed-test artifacts and release permissions.

## Task 3: App architecture

- AppState becomes observable state/composition/coordination. Extract cohesive
  logging/settings, UV, reminder, recovery, accountability responsibilities.
- One dependency bundle with production/test factories, clock and existing
  protocol injection. Services consume explicit inputs, not whole AppState.
- Share app/automation log/edit/backfill/reapply/reminder mutation logic using
  existing revision-history services, receipts, validation and field preservation.
- Keep authorization at automation boundary; successful changes alone trigger
  effects. Preserve per-surface effects and no-op/error behavior.
- Presentation calculations become pure helpers. Split large tests by behavior
  with common fixtures. Keep all migration, restore and automation regressions.

## Task 4: Cleanup and documentation

- Split large views into cohesive sections without changing visuals/navigation.
- Consolidate duplicated design tokens; delete only unreachable code/assets.
- Preserve persisted compatibility types and legacy route redirects.
- Named shared Tuist source groups, no additional module/framework targets.
- Short actionable AGENTS entrypoint with linked architecture, commands,
  feature recipe and historical troubleshooting under docs/.
- Adapt source-inspection tests to architectural contracts across files.

## Verification

- Python/tooling tests, full Swift unit/UI tests, lint, both device builds.
- Cold bootstrap/build/run, production archive/export and signed IPA inspection.
- Existing prior-store migration/recovery/reinstall/import/CloudKit ordering tests.
- Full GitHub CI on final refactor SHA before merge, regardless of PR defaults.
- Record timing, evidence, blockers and review findings in the execution ledger.
