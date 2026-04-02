# Manual-Only Simplification ExecPlan

This ExecPlan is a living record of the manual-only product simplification. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` capture the implementation and verification work that landed.

## Purpose / Big Picture

Sunclub now builds and ships as a manual-only sunscreen tracker. A clean checkout should regenerate the workspace, run the iOS test suites, run the Python validation checks, and validate App Store metadata without any model staging, camera-specific setup, or extra package resolution beyond the app itself.

## Progress

- [x] (2026-04-02 05:16Z) Audited the repo paths that were still carrying the legacy scan pipeline through project generation, runtime routing, metadata, docs, and tooling.
- [x] (2026-04-02 05:16Z) Added this ExecPlan at implementation start so the removal work had a tracked record.
- [x] (2026-04-02 05:44Z) Simplified the Tuist workspace so the generated graph contains only the app and its test targets.
- [x] (2026-04-02 05:57Z) Removed the live scan runtime, feature-flag plumbing, camera permission, and download flow so the app always routes to manual logging.
- [x] (2026-04-02 06:07Z) Collapsed verification state to a manual-only model and added migration logic that rewrites legacy stored method values during refresh.
- [x] (2026-04-02 06:15Z) Removed repo-level model and evaluation tooling, updated App Store metadata and validation, and rewrote the shared docs to match the manual-only product.
- [x] (2026-04-02 06:36Z) Regenerated the workspace and ran the targeted validation commands from the repo root.

## Surprises & Discoveries

- Observation: The removed scan flow was not isolated to one target; it had spread into notifications, screenshot routing, App Store review copy, and Python tooling.
  Evidence: repo-wide search during the audit found references across `app/Sunclub/Sources/Services/NotificationManager.swift`, `scripts/appstore/metadata.json`, `tests/test_appstore_metadata_validator.py`, `justfile`, `pyproject.toml`, and the old evaluation tree.
- Observation: The generated project graph cleaned up immediately once the extra target and package manifest entries were removed.
  Evidence: subsequent `xcodebuild` test logs showed only `Sunclub`, `SunclubTests`, and `SunclubUITests` in the dependency graph.
- Observation: UI tests required running outside the sandbox because simulator runtime discovery failed under sandboxed `simctl`.
  Evidence: `just test-ui` failed in the sandbox while probing simulator runtimes, then passed when rerun with simulator access outside the sandbox.

## Decision Log

- Decision: Remove the live scan experience entirely instead of hiding it behind a dormant switch.
  Rationale: The requested goal was faster and simpler builds, and the cleanest path was to remove the feature path that forced the extra target, packages, docs, and runtime services.
  Date/Author: 2026-04-02 / Codex
- Decision: Preserve stored daily history by normalizing legacy method values to manual during app-state refresh instead of resetting user data.
  Rationale: This keeps old records readable while eliminating unsupported product state from the active app model.
  Date/Author: 2026-04-02 / Codex
- Decision: Remove the old evaluation tree and related helper commands instead of leaving dead repo surfaces behind.
  Rationale: The requested scope was whole-repo removal, and the removed tooling no longer matched the product.
  Date/Author: 2026-04-02 / Codex

## Outcomes & Retrospective

The generated workspace is now app-only, with no extra model target in the graph. The product flow is manual-only from onboarding through reminders, home actions, success presentation, settings copy, and screenshot routes. Legacy records still survive because stored method values are rewritten to the supported manual value during refresh before the UI consumes them.

Repo tooling is correspondingly smaller. The root task runner no longer advertises download or evaluation commands, Python bootstrap only syncs the remaining development dependencies, App Store validation expects the reduced route set and no camera privacy string, and the shared docs describe the current product rather than the removed scan workflow.

## Context and Orientation

The iOS project lives under `app/`. Tuist manifests live in `app/Sunclub/Project.swift`, `app/Workspace.swift`, `app/Tuist.swift`, and `app/Tuist/Package.swift`. The app code lives in `app/Sunclub/Sources/`, with routing in `Shared/AppRoute.swift`, root navigation in `Shared/RootView.swift`, state in `Services/AppState.swift`, and reminder behavior in `Services/NotificationManager.swift`.

Repo automation starts at the root `justfile`. App Store metadata and screenshot automation live in `scripts/appstore/`. Shared docs live in `README.md`, `app/README.md`, `app/SPEC.md`, and `docs/`.

## Plan of Work

The implementation followed four steps:

1. Remove the extra project target and package references from the generated workspace.
2. Simplify the app to a single manual check-in path and delete the unused runtime services and views.
3. Update persistence, tooling, docs, metadata, and tests to match the reduced product.
4. Regenerate and rerun the relevant repo-level verification commands.

## Concrete Steps

Completed verification commands from the repository root:

    just bootstrap
    just generate
    just test-unit
    just test-ui
    just test-python
    just appstore-validate

Final repo check:

    Run a repo-wide search for the removed framework, package, flag, and legacy route identifiers and confirm there are no matches.

Expected final state:

    `just generate` finishes with only the app and test targets in the project graph.
    `just test-unit`, `just test-ui`, and `just test-python` pass.
    `just appstore-validate` passes against the manual-only metadata manifest.
    The final `rg` finds no matches.

## Validation and Acceptance

Acceptance is build- and behavior-focused:

1. The generated project graph no longer includes the removed model target or its related package inputs.
2. Launching the app takes the user through onboarding into Home, and Home offers only manual logging as the primary action.
3. Tapping the manual log button still records today and reaches the success screen.
4. Daily reminder routing opens manual logging, and weekly reminders still open the weekly summary.
5. Existing stored daily rows with the legacy method value are normalized to manual without losing the record.
6. Repo-level tooling no longer advertises model download, evaluation, or packaging flows that no longer exist.

## Idempotence and Recovery

The simplification is intended to be idempotent. Re-running workspace generation, tests, or metadata validation after these deletions should not require staged assets or generated side paths. If a future command reintroduces an unexpected legacy reference, the safe recovery path is to search for the remaining symbol or route name, remove it, regenerate the workspace if needed, and rerun the affected command.

## Artifacts and Notes

Representative files touched by the simplification:

    app/Tuist/Package.swift
    app/Sunclub/Project.swift
    app/Workspace.swift
    app/Sunclub/Sources/SunclubApp.swift
    app/Sunclub/Sources/Services/AppState.swift
    app/Sunclub/Sources/Services/NotificationManager.swift
    justfile
    pyproject.toml
    scripts/appstore/metadata.json

## Interfaces and Dependencies

At completion:

- `app/Tuist/Package.swift` still defines the package, but its dependency list is empty.
- `app/Sunclub/Sources/Shared/AppRoute.swift` defines only the manual-only route set used by the product and screenshot tooling.
- `app/Sunclub/Sources/Models/VerificationMethod.swift` defines only the manual case and still exposes `title`, `displayName`, and `symbolName`.
- `app/Sunclub/Sources/Services/AppState.swift` normalizes persisted legacy method values before records are consumed elsewhere.
- `scripts/appstore/validate_metadata.py` accepts only the reduced route set and no longer expects download-specific review metadata.
- `scripts/tooling/bootstrap.sh` and `pyproject.toml` depend only on the repo’s remaining development tooling.
