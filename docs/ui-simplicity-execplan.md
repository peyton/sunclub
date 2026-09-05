# UI simplicity implementation

Implementation record; verification is tracked in [UI simplicity verification](ui-simplicity-verification.md).

## Goal and constraints

- Today logs; History browses dates; Settings holds preferences.
- One-tap log/reapply with safe Undo and optional Edit; seven-day read-only Insights plus streak.
- Retain Health, automation, backup, recovery, persisted schemas, CloudKit history, signing, public routes and permissions.
- Native Liquid Glass and existing design tokens; app-owned icons use existing SVG assets.
- No dependencies. Shared mutation/revision services own writes. Effects require changed receipts.
- Preserve accessibility: named controls, Dynamic Type, contrast, non-color cues, Reduce Motion.
- Tests first, focused regression verification, full exact-head CI, one PR, normal merge only after checks and review.
- Baseline: origin/master e45376c1279d368a7f50f2366b716b5362f6c4b1; worktree codex/ui-simplicity-pass.

## Task 1: Logging and History editor

Owner: editor worker. Edit only ManualLogView.swift, HistoryRecordEditorView.swift, HistoryView.swift, SunManualLogFields.swift, SunManualLogInput.swift, ManualLogSuggestions.swift and new focused test files. Do not edit AppState, RootView, AppRoute, existing monolithic test files, project files, or UI test files; report required integration changes.

- Consolidate Manual Log and History editors into one fixed-date form with time, optional SPF/coverage/notes, Save and Cancel. ManualLogView may remain a compatibility wrapper accepting AppLogContext.
- Explicit edit semantics must persist clearing SPF/notes. Use saveManualRecord, not an additive application request, for editing.
- Pick dates in History, not the editor; no stale-field overwrite from changing dates. Resolve clock/time bounds from appState.referenceDate.
- Reserve coverage metadata capacity within existing 280-character serialized note limit. Preserve all valid selected areas; do not silently truncate existing draft text. If a draft exceeds capacity after changing coverage, show an actionable validation error and require correction before Save.
- Recognize only complete valid Areas metadata; preserve ordinary prose with that prefix. No persisted schema change.
- Preserve missing historical coverage as unspecified. Coverage optional in every editor.
- Suggestions display prose only; explicit reuse updates SPF, prose and coverage consistently. One-tap defaults must never copy free-form notes.
- No-op saves dismiss without extra success effects or reminder rescheduling.
- Reapplication rows informational, one explicit Edit log action; time editor accurately labeled First application where appropriate.
- Delete Undo validates the deletion target is still current, and never overwrites a replacement log. Recovery worker adds result-returning AppState.undoChange and safe undo-if-current API; coordinate via controller.
- Remove old header/status/explainer boxes, Backfill jargon, always-false isCurrentStreak and never-mutated feedback state. Use tokens and at least 44-point interactive targets.
- Add behavioral regression tests for clears, fixed context, long-note metadata, ordinary Areas prose, optional areas, reuse, no-op and stale Undo. Do not add source-text assertions.

## Task 2: Settings, onboarding and auxiliary copy

Owner: settings worker. Edit Settings*.swift, OnboardingView.swift, ReapplyCheckInView.swift, AutomationView.swift, PrivacyView.swift, SupportView.swift and new focused test files. Do not edit AppState, RootView, AppRoute, Intents, docs/web, existing monolithic tests or UI tests; report integration needs.

- Settings rows: Sunscreen, Reminders, UV & Weather, Apple Health, iCloud & Backup, Shortcuts, Privacy, Support. Short descriptive status only where useful.
- Consolidate daily, reapply and leave-home reminder controls on one Reminders page; diagnostics behind Troubleshoot. Keep existing preference storage.
- Add local SettingsDetail sunscreen and health destinations. Controller supplies AppRoute.settingsSunscreen, .settingsHealth and root/automation mappings. Legacy reminder routes resolve to reminders; healthWeather remains UV & Weather with contextual Health access if needed.
- Health toggle must reconcile with persisted authorization outcome; controller owns AppState changes if required. Rename Weather location switch Use current location; retain manual city and fallback behavior.
- Welcome -> optional reminders -> Today. Defer location/city to Settings/contextual setup. Preserve initial iCloud restore gate and onboarding persistence. Distinguish save failure from notification failure with accurate Retry/Continue.
- Onboarding always finishes at Today after importing legacy pending invites; do not delete social identities or data.
- Reapply Last logged uses latest application. Preserve logging with reminders disabled.
- Catalog names must match shipped intents. Remove misleading plus/setup cards and static Ask Before Running pseudo-setting.
- Write examples are copy-only, never Test/Run sample writes. Preserve real public URL actions and four permission controls.
- Settings has permissions and one catalog link, not the entire duplicate catalog. Keep advanced URL/callback examples collapsed in catalog.
- Consolidate help/docs/contact under Support; keep Privacy, remove duplicate Email/Feedback action and billing wording. Rename Export history to Export backup.
- Remove private dead profileDetail and stale surface-specific copy. Add behavior tests where appropriate; no tests that simply grep source copy.

## Task 3: Recovery results and safe Undo

Owner: recovery worker. Edit AppState.swift, SunclubRecoveryCoordinator.swift, SunclubHistoryService.swift and history helpers, RecoveryView.swift and new focused test files. Do not edit other screens, RootView/AppRoute, UI tests or existing monolithic tests.

- AppState publish/restore/undo/redo must expose explicit success/failure instead of try? swallowing. Preserve existing callers via discardable results or compatible wrappers.
- Recovery failures show accurate pending/error states and retry; conflict marked resolved only after successful undo. Publishing text must not claim iCloud unchanged.
- Add safe undo-if-current semantics for ephemeral History/Today Undo receipts: verify affected day revision/projection still corresponds to target batch; fail non-destructively if changed. Preserve explicit historical recovery undo semantics and all revisions.
- Coordinate API names/signatures with controller and editor worker before adoption. Return mutation batch/receipt result usable for Today receipt and History banner.
- No-op changes must not schedule follow-up effects. Review AppState.saveManualRecord and log facade for this contract.
- Health authorization state reconciliation needed by settings worker: inspect updateHealth and report necessary changes or make bounded correction here.
- Prior shipped-store/projection tests: non-empty history preserved, stale Undo cannot replace newer writes, failure cannot dismiss conflict, import/restore/undo/redo errors observable, no-op emits no effects. No schema changes.

## Task 4: Today, Insights and navigation

Owner: controller. Remove Today timeline/scrubber/past/future branches and gestures; anchor reads/writes to current local day through midnight and foreground. Compact UV/status/action; concise copy; hide inactive reminders/missing metadata; keep provenance and errors.

One-tap primary action uses shared default resolver and existing log/reapply services; receipt has Undo/Edit, duplicate submissions guarded. Insights read-only last seven days plus streak, unboxed, no 30-day score, typical time, UV-rate, advice, day-editor interactions or floating History button. Accessibility list fallback.

Native tab stacks keep context. Reproduce Insights back bug, use native back on supported systems and production/test-parity legacy edge fallback. Resolve editor route payload before SwiftUI render, preserve App Intent/URL compatibility and add new Settings route mappings.

## Task 5: Integration, documentation, review and delivery

- Update affected unit/UI tests, route/automation mappings, app requirements, architecture, automation docs and web copy. Remove only obsolete camera-verification/social requirements and unreachable private UI code.
- Run focused RED/GREEN tests; lint/Python, unit, full UI, both build configurations, accessibility and visual comparisons. Native navigation reproduction required; screenshots alone not evidence.
- Review each patch for spec and quality, then whole-branch review. Fix blocking findings.
- PR includes all 27 user checklist outcomes and exact test evidence. Merge only current-head full CI, protections and review green; no bypass or release.

## Baseline audit

- Fresh baseline captures: quiet-glass worktree .build/quiet-glass-qa/audit-{today,history,insights,insights-accessibility,settings,log-editor}.png.
- The old edge fallback differed between production and UITEST_MODE. Baseline navigation tests passed, so the exact reported Insights failure was not reproduced. Replacement navigation paths have explicit regressions; see the verification record.
- Source audit found notes metadata truncation/prefix stripping, stale edit state, failed recovery error swallowing, misleading automation write tests and duplicated settings/editor surfaces.
