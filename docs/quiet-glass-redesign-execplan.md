# Quiet Glass redesign

## Purpose

Make Today a calm place to check UV and log sunscreen. Keep History and Settings one tap away through a native three-tab bar. Preserve existing records, recovery, reminders, accessibility, and public automation routes.

## Progress

- [x] (2026-09-04) Fast-forward master to 8228f3a and bootstrap isolated worktree.
- [x] (2026-09-04) Confirm approved Quiet Sun design with restrained Liquid Glass; reject photographic direction.
- [x] (2026-09-04) Implement shared navigation, vector icons, Today, History, and Settings/form simplification.
- [x] (2026-09-04) Update navigation and accessibility tests and product documentation.
- [x] (2026-09-04) Verify local tests and simulator visuals; independent source review has no remaining actionable findings.
- [ ] Open PR, pass full CI on exact head, and merge.

## Context and Orientation

The app is native SwiftUI. AppRouter in app/Sunclub/Sources/Shared/AppRoute.swift owns independent navigation paths. RootView.swift displays them. TimelineHomeView.swift, HistoryView.swift, and SettingsView.swift are the main screens. AppDesignSystem.swift and AppTheme.swift own semantic colors, typography, and compatible native glass controls. SunclubMutationService and existing revision services own durable writes; this work must not alter them.

## Plan of Work

First replace four destinations plus a separate logging action tab with Today, History, and Settings. Move weeklySummary to a History detail destination while keeping its public route. Delete the unused custom tab bar and contextual action adapter.

Next refine Today around a procedural UV ring, truthful logged status, and a visible Log sunscreen button. Keep source and unavailable-state information, forecast access, browsing other days, and actionable recovery/reminder failures. History starts with a week strip and selected-day records; a labeled calendar control retains month browsing. Remove duplicate promotional cards and metrics. Settings uses grouped rows; manual logging keeps the established defaults, validation, and save flow.

Finally update tests to exercise the new hierarchy without weakening common-task coverage. Verify large text, light/dark appearance, navigation, editing, undo, reminders, and public route compatibility before merging.

## Concrete Steps

Run commands from the feature checkout. This Mac uses Xcode 26.6 per command without changing the system-wide Xcode selection:

    DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer just test-python
    DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer just ci-lint
    DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer just test-unit
    DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer just test-ui-smoke
    gh workflow run ci.yml --ref codex/quiet-glass-redesign

Full CI, including all UI tests and both application builds, must pass on the PR head. Inspect review status and conflicts before a normal merge. Do not merge with skipped or superseded evidence.

## Validation and Acceptance

On launch, Today shows real UV state, a readable log status, and the primary logging action. All three tabs have visible labels and SVG-backed icons. History can navigate dates, edit/backfill records, delete with confirmation, and undo. Weekly insights remains reachable from History and its existing external route. Settings still exposes all existing controls, backup, privacy, and automation information. Larger Text and dark appearance must not obscure the primary action.

## Idempotence and Recovery

No persisted models, store locations, entitlements, or public URL names change. Existing worktrees are untouched. Retry failed checks after scoped corrections; do not erase local user data or bypass test gates.

## Interfaces and Dependencies

Use SwiftUI TabView and existing glass compatibility helpers, with the system appearance on older iOS. Bundle pinned Lucide SVG icon sources and licenses without adding a package dependency. SunIcon provides template Image values for the redesigned screens. Retain AppRoute.weeklySummary as a History detail.

## Decision Log

2026-09-04: Three native destinations replace action/navigation mixing. Logging belongs in Today; weekly insights belongs with History. This reduces duplicated routing and preserves discoverability.

2026-09-04: Keep a plain ivory/slate canvas and reserve glass for controls. No photographic backgrounds or generated raster icons are introduced.

## Surprises & Discoveries

Latest master already removed several unused screens and extracted presentation logic. The redesign builds on those changes rather than restoring deleted feature implementations.

Native glass uses white primary labels even when the fallback style selects a dark foreground. Visual inspection caught a dark-mode contrast mismatch not represented by the original token test; primary glass now uses an explicit, contrast-tested blue tint.

SwiftUI structural accessibility identifiers could replace contained History button identifiers. Explicit containment preserves the public test surface and keeps each action independently named.

## Artifacts and Notes

Approved design: large UV ring, navy rounded text, warm ivory canvas, blue logging action; History uses compact dates and grouped rows. The implementation must use actual app state, never the mockup's example times or protection guarantees.

## Outcomes & Retrospective

Implementation and local verification complete. Python tests: 279 passed. Unit tests: 444 passed, including the native-glass white-label contrast regression. UI smoke tests: 13 passed. Local CI lint passes with no errors. Initial smoke failures identified accessibility containment and offscreen-state query issues; both were corrected without weakening status or reachability assertions. A simulator-service interruption required a clean rerun, which passed. Visual QA passed after recapture. Full exact-head CI and merge remain; their immutable evidence belongs in the PR.

Revision: initial implementation plan records the approved design and compatibility gates.
