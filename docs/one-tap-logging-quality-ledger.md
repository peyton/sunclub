# One-Tap Logging Quality Ledger

## ExecPlan

Goal: one-tap sunscreen logging should reuse the previous reusable SPF and structured covered-area metadata everywhere it can run outside the foreground app, while foreground manual logging preselects the last SPF without overwriting existing records or explicit scanner/automation inputs.

Status: in progress for PR `codex/widget-one-tap-spf-reuse`.

Scope:

- Centralize reusable log defaults in `SunManualLogDefaultResolver`.
- Wire widget/deep-link, watch, shortcut, Control Center/App Intent, and standalone quick-log paths to the shared resolver.
- Keep free-form notes out of one-tap defaults unless the current caller explicitly supplies notes.
- Keep SwiftData schema unchanged.
- Keep unrelated `mise.lock` drift unstaged.

Advisory feedback:

- Browser ChatGPT Pro Extended review on 2026-05-12 flagged the contract `explicit input > existing persisted value > last-log default > app/product default`, the nil-versus-empty notes edge case, stale extension state, and existing-record isolation.
- A generated visual QA concept board was used as a visual checklist for the four user-facing surfaces: Today widget, watch log, Shortcuts/Control Center, and Manual Log. It reinforced readable SPF confirmation, no copied free-form note, and an SPF-prefilled Manual Log.

Verification plan:

- Unit: one-tap resolver, widget/deep-link, watch, shortcut/runtime, explicit overrides, existing-record preservation, widget snapshot SPF.
- UI: Manual Log from Home, History backfill, product-scanner/manual prefill override.
- Repo: `just test-unit`, `just test-ui`, `just lint`, `just ci-build`, `git diff --check`, and full `just ci` if local Xcode remains stable.
- Remote: PR checks, merge, post-merge master CI, release tag workflow, artifact download, IPA entitlement diagnostics, Internal TestFlight group assignment.

## Ledger

- [x] Q001 | Evidence: `SunclubDeepLinkHandler.handleWidgetLogToday` logged quick-log rows without SPF. | Fix: widget/deep-link path now resolves one-tap defaults through `AppState.oneTapLogInput`. | Verification: `testWidgetLogTodayDeepLinkReusesLastSPFAndCoveredAreas`.
- [x] Q002 | Evidence: widget one-tap path had no structured area reuse. | Fix: `SunManualLogResolvedDefaults.oneTapNotes` serializes only covered-area metadata. | Verification: widget deep-link regression checks `coveredAreas`.
- [x] Q003 | Evidence: adding area reuse could have copied prior free-form notes. | Fix: resolver derives notes only from `SunManualLogInput.coveredAreas(in:)`. | Verification: `testOneTapDefaultsDoNotCopyFreeFormNotesWithoutAreaMetadata`.
- [x] Q004 | Evidence: existing today records are valid user edits and should not be refreshed from yesterday. | Fix: `oneTapLogInput(for:)` returns `.empty` when the target day exists. | Verification: `testWidgetLogTodayDeepLinkPreservesExistingOptionalFields`.
- [x] Q005 | Evidence: widget snapshot displayed `todaySPFLevel`; reused SPF needed to flow into the snapshot. | Fix: one-tap write stores reused SPF before snapshot rebuild. | Verification: widget deep-link test asserts `todaySPFLevel == 50`.
- [x] Q006 | Evidence: watch logging used `recordApplication` without SPF/notes. | Fix: `recordWatchSunscreenLog` passes `oneTapLogInput`. | Verification: `testWatchLogRecordsQuickLogAndReturnsUpdatedSnapshot`.
- [x] Q007 | Evidence: watch reply snapshot could confirm logged state without SPF detail. | Fix: watch path stores reused SPF before returning widget snapshot. | Verification: watch test asserts `snapshot.todaySPFLevel == 45`.
- [x] Q008 | Evidence: watch one-tap could have overwritten existing optional fields if defaults were always supplied. | Fix: shared `oneTapLogInput` suppresses defaults for an existing day. | Verification: same AppState upsert contract as widget preservation test.
- [x] Q009 | Evidence: Shortcut `Log Sunscreen` used `SunclubAutomationRuntime.logToday` with only explicit parameters. | Fix: runtime now resolves defaults when the day is new. | Verification: `testLogTodayAutomationReusesPriorSPFAndCoveredAreasForNewRecords`.
- [x] Q010 | Evidence: Control Center actions need the same one-tap defaulting as Shortcuts without inheriting the user Shortcut write toggle. | Fix: app-owned widget/control buttons use `LogTodayWidgetIntent`, which delegates to `.logToday` through `SunclubAutomationInvocation.widget`. | Verification: `testWidgetInvocationLogsEvenWhenShortcutAndURLWritesAreDisabled`.
- [x] Q011 | Evidence: explicit SPF from automation must beat prior SPF. | Fix: `spfLevel ?? defaultInput.spfLevel` keeps explicit normalized SPF first. | Verification: `testLogTodayAutomationExplicitInputOverridesPriorDefaults`.
- [x] Q012 | Evidence: explicit notes from automation must beat prior structured defaults. | Fix: runtime resolves notes before applying default area notes. | Verification: explicit input override test asserts `notes == "Patio"`.
- [x] Q013 | Evidence: ChatGPT advisory flagged nil-versus-empty notes as a bug source. | Fix: `.logToday` now preserves raw note presence until default resolution. | Verification: `testLogTodayAutomationExplicitEmptyNotesSuppressDefaultCoveredAreas`.
- [x] Q014 | Evidence: URL automation can pass empty notes and should not regain default areas. | Fix: raw `notes` optional reaches `logToday` before normalization. | Verification: same empty-notes runtime regression.
- [x] Q015 | Evidence: standalone widget/extension quick action did not reuse defaults. | Fix: `SunclubQuickLogAction.performStandalone` resolves defaults from shared storage. | Verification: target metadata plus runtime resolver unit coverage.
- [x] Q016 | Evidence: standalone quick action could have overwritten existing optional fields if defaults were applied to updates. | Fix: it computes `.empty` when today's record already exists and preserves existing optional fields. | Verification: existing upsert update path remains unchanged and widget preservation test covers the contract.
- [x] Q017 | Evidence: `ManualLogView` new logs started with no selected SPF even when history had one. | Fix: initial state now selects `manualLogSuggestionState.defaultSPF`. | Verification: `testManualLogShowsSmartReuseSuggestions` checks SPF 50.
- [x] Q018 | Evidence: History backfill should also benefit from last-SPF prefill. | Fix: `ManualLogView` uses `targetDate` in the suggestion query. | Verification: `testHistoryCanBackfillMissedDay` checks prefilled SPF 30.
- [x] Q019 | Evidence: product-scanner/manual prefill must override history defaults. | Fix: existing `manualLogPrefill` branch still returns before default SPF assignment. | Verification: `testProductScannerPrefillOverridesUsualSPF`.
- [x] Q020 | Evidence: widget target compiles automation runtime and quick action but previously omitted the new resolver file. | Fix: `Project.swift` adds `ManualLogSuggestions.swift` to widget sources. | Verification: `test_widget_extension_compiles_manual_log_input_dependencies`.
- [x] Q021 | Evidence: defaulting rules were split across surfaces. | Fix: `SunManualLogDefaultResolver` centralizes reusable default resolution. | Verification: resolver unit tests plus all caller tests.
- [x] Q022 | Evidence: sorting the latest reusable record was duplicated in the suggestion engine. | Fix: `ManualLogSuggestionEngine.sortedRecords` is shared. | Verification: existing smart suggestion tests still use the same order.
- [x] Q023 | Evidence: last-SPF and last-area defaults need to ignore the target day. | Fix: resolver accepts `excluding day:`. | Verification: widget/history tests seed prior records and target today/backfill.
- [x] Q024 | Evidence: area metadata must stay structured and deterministic. | Fix: resolver uses `SunManualLogInput.notesWithCoveredAreas`. | Verification: unit test expects the canonical `Areas:` line.
- [x] Q025 | Evidence: prior note-only records should not synthesize covered areas. | Fix: resolver maps through `coveredAreas(in:)` only. | Verification: no-free-form-copy resolver test.
- [x] Q026 | Evidence: prior SPF-only records should still be reusable. | Fix: resolver independently picks latest SPF. | Verification: shortcut/widget tests assert SPF reuse.
- [x] Q027 | Evidence: prior areas-only records should be allowed even when SPF is absent. | Fix: resolver independently picks latest non-empty area set. | Verification: covered-area assertions do not depend on SPF in the parser.
- [x] Q028 | Evidence: explicit automation notes are normalized elsewhere in the runtime. | Fix: only `logToday` delays note normalization; `saveLog` keeps existing behavior. | Verification: `testAutomationNormalizesSPFAndNotesAcrossWriteActions`.
- [x] Q029 | Evidence: explicit automation SPF still needs clamping. | Fix: `performValidated` keeps `normalizedSPF` before `logToday`. | Verification: existing normalization test expects SPF 1 for negative input.
- [x] Q030 | Evidence: one-tap update messaging differs for new versus existing records. | Fix: runtime preserves `isUpdate` calculation before defaulting. | Verification: existing automation test still expects update message.
- [x] Q031 | Evidence: widget/deep-link path should keep success route behavior. | Fix: deep-link handler only adds defaults and still opens `.verifySuccess`. | Verification: widget deep-link tests assert router path.
- [x] Q032 | Evidence: widget/deep-link path should keep onboarding guard behavior. | Fix: no change to onboarding branch. | Verification: `testWidgetLogTodayDeepLinkDoesNotLogBeforeOnboarding`.
- [x] Q033 | Evidence: reapply reminder scheduling must survive defaulted widget logging. | Fix: deep-link handler still schedules after `recordVerificationSuccess`. | Verification: `testWidgetLogTodayDeepLinkSchedulesReapplyReminderWhenEnabled`.
- [x] Q034 | Evidence: watch logging must keep reapply scheduling. | Fix: `recordWatchSunscreenLog` defaulting occurs before unchanged reminder scheduling. | Verification: AppState watch path still reaches reminder branch.
- [x] Q035 | Evidence: HealthKit export is coupled to AppState record upserts. | Fix: defaulted logs still use `recordApplication`, preserving export hooks. | Verification: AppState upsert path remains unchanged.
- [x] Q036 | Evidence: historical UV capture is coupled to AppState record upserts. | Fix: defaulted logs still use `recordApplication`. | Verification: AppState upsert path remains unchanged.
- [x] Q037 | Evidence: revision history must capture outside-app writes. | Fix: automation still uses `applyDayChange` with `.manualLog`. | Verification: automation revision-history test remains in place.
- [x] Q038 | Evidence: widget reloads must continue after standalone quick action. | Fix: quick action keeps `WidgetCenter.shared.reloadAllTimelines()`. | Verification: code inspection plus widget snapshot store assertion.
- [x] Q039 | Evidence: manual log prefill should not save until the user taps save. | Fix: change only updates view state in `syncInitialStateIfNeeded`. | Verification: UI tests open manual log and then perform explicit save steps separately.
- [x] Q040 | Evidence: existing manual records should not be overwritten by default SPF. | Fix: existing-record branch still returns before default assignment. | Verification: existing record edit behavior covered by history tests.
- [x] Q041 | Evidence: scanner/manual prefill can be lost if SwiftUI builds the destination more than once. | Fix: prefill now clears on explicit save/cancel instead of during initial state sync. | Verification: `testProductScannerPrefillOverridesUsualSPF`.
- [x] Q042 | Evidence: selected covered areas need a safe default for new manual logs. | Fix: default SPF assignment is followed by existing default covered areas. | Verification: Manual Log save still requires non-empty selected areas.
- [x] Q043 | Evidence: Dynamic Type can expose overly specific UI-test assumptions. | Fix: UI assertions use accessibility values rather than coordinates. | Verification: new helper `waitForValueContaining`.
- [x] Q044 | Evidence: product scanner UI route can have async setup. | Fix: UI test waits for `manualLog.logToday`. | Verification: product scanner override UI test.
- [x] Q045 | Evidence: history backfill row text is exposed through a specific identifier. | Fix: UI test asserts `historyEditor.spfState`. | Verification: history backfill UI test.
- [x] Q046 | Evidence: prior `mise.lock` drift is unrelated. | Fix: ledger records explicit staging rule. | Verification: final staging will list files explicitly.
- [x] Q047 | Evidence: generated visual assets are owned by scripts. | Fix: no generated asset files were edited. | Verification: git status shows no asset churn.
- [x] Q048 | Evidence: SwiftData schema changes require migration. | Fix: implementation is runtime/view/test only; no model fields changed. | Verification: git diff has no schema version edits.
- [x] Q049 | Evidence: outside-app writes need automation documentation awareness. | Fix: no public route shape changed; behavior stays under existing `log-today`. | Verification: automation URL round-trip tests still cover route shape.
- [x] Q050 | Evidence: App Intent discoverability must remain intact while widget-only intents stay out of Shortcuts. | Fix: `LogSunscreenIntent` title and shortcut catalog stay unchanged, and widget-specific intents set `isDiscoverable = false`. | Verification: App shortcut catalog remains pointed at `LogSunscreenIntent`.
- [x] Q051 | Evidence: widget presentation should now be able to display reused SPF. | Fix: snapshot receives `todaySPFLevel` through stored record. | Verification: widget snapshot assertion.
- [x] Q052 | Evidence: current-day duplicate taps should update one record, not create duplicates. | Fix: upsert paths preserve existing-record update behavior. | Verification: existing widget and automation update tests assert one record.
- [x] Q053 | Evidence: repeated widget taps must not erase SPF. | Fix: existing-record default suppression plus non-replacing optional upsert. | Verification: widget preservation test.
- [x] Q054 | Evidence: repeated shortcut taps must not erase notes/SPF. | Fix: automation upsert uses `replaceOptionalFields: false`. | Verification: existing automation update test.
- [x] Q055 | Evidence: null SPF in a prior log should not block an older SPF from reuse. | Fix: resolver searches the sorted records for first non-nil SPF. | Verification: resolver structure plus suggestion engine tests.
- [x] Q056 | Evidence: null notes in a prior log should not block older covered areas. | Fix: resolver searches the sorted records for first non-empty area set. | Verification: resolver structure and covered-area tests.
- [x] Q057 | Evidence: stale widget timeline state should not determine write defaults or decide the stored SPF/areas. | Fix: widget taps execute the runtime from current storage at tap time, and presentation state only chooses log/reapply/open behavior. | Verification: `testWidgetInvocationLogsEvenWhenShortcutAndURLWritesAreDisabled` and tap-action presentation tests.
- [x] Q058 | Evidence: stale watch UI state should not determine phone-side write defaults. | Fix: phone handler resolves defaults at message handling time. | Verification: watch AppState test seeds storage before call.
- [x] Q059 | Evidence: scanner SPF can be higher than prior SPF. | Fix: scanner prefill branch wins before defaults. | Verification: product scanner UI test expects 70 instead of seeded 50.
- [x] Q060 | Evidence: backfilled manual entries can be older than latest history. | Fix: suggestion state excludes the target day but still uses global latest history. | Verification: history backfill UI test.
- [x] Q061 | Evidence: quick-log defaults must not alter current streak math. | Fix: only optional SPF/notes change; record day remains identical. | Verification: widget/automation tests assert current log count and streak paths.
- [x] Q062 | Evidence: longest-streak update is part of standalone quick action. | Fix: standalone action leaves streak update code intact. | Verification: quick-action code inspection and existing widget tests.
- [x] Q063 | Evidence: app-group shared container creation is fragile in extensions. | Fix: no new container path was added; quick action uses existing factory. | Verification: Project metadata and compile target tests.
- [x] Q064 | Evidence: widget extension source lists are brittle. | Fix: Python metadata test now checks the new resolver dependency. | Verification: `test_widget_extension_compiles_manual_log_input_dependencies`.
- [x] Q065 | Evidence: watch extension source lists should not receive iOS-only files unnecessarily. | Fix: no watch target source changes were made. | Verification: Project diff only changes widget target.
- [x] Q066 | Evidence: public route identifiers should remain stable. | Fix: no route enum changes. | Verification: automation catalog round-trip tests.
- [x] Q067 | Evidence: custom URL parsing should reject malformed SPF values. | Fix: existing parser guard remains unchanged. | Verification: malformed automation link tests.
- [x] Q068 | Evidence: notes over 280 chars should stay clamped. | Fix: runtime still calls `normalizedNotes` after default decision. | Verification: normalization test.
- [x] Q069 | Evidence: SPF below 1 should stay clamped. | Fix: runtime still calls `normalizedSPF`. | Verification: normalization test.
- [x] Q070 | Evidence: SPF above 100 should stay clamped. | Fix: no changes to normalization helper. | Verification: normalization test for save-log SPF 500.
- [x] Q071 | Evidence: records imported from backup may contain notes. | Fix: resolver requires explicit `Areas:` metadata, not arbitrary note text. | Verification: no-free-form-copy test.
- [x] Q072 | Evidence: old records without area metadata should remain valid. | Fix: no migration or reinterpretation was introduced. | Verification: schema unchanged and resolver ignores legacy note text.
- [x] Q073 | Evidence: manual note snippets should still show prior notes. | Fix: `ManualLogSuggestionEngine.suggestions` still builds `noteSnippets`. | Verification: existing smart suggestion UI test still taps note snippet.
- [x] Q074 | Evidence: manual same-as-last-time chip should still exist. | Fix: resolver extraction did not remove reuse suggestion state. | Verification: existing suggestion tests remain.
- [x] Q075 | Evidence: scanned SPF memory should remain separate from default SPF. | Fix: `scannedSPFLevels` remains an input to suggestion state. | Verification: existing scanned SPF tests.
- [x] Q076 | Evidence: product scanner route should still open Manual Log when no camera is used in UI tests. | Fix: no scanner routing changes. | Verification: `testProductScannerRouteOpensManualLog` plus new override test.
- [x] Q077 | Evidence: foreground manual logging should keep default areas. | Fix: default SPF assignment does not change `selectedAreas`. | Verification: Manual Log save button remains enabled by existing default areas.
- [x] Q078 | Evidence: existing records with explicit areas should display those areas. | Fix: existing-record branch still reads areas before returning. | Verification: existing manual-history edit tests.
- [x] Q079 | Evidence: manual prefill notes should not mix with prior covered areas. | Fix: manual prefill branch returns before default selection. | Verification: product scanner override test.
- [x] Q080 | Evidence: success presentation add-details behavior is tied to supplied SPF/notes. | Fix: widget with no defaults still supplies nil SPF/notes. | Verification: existing widget no-default test expects `canAddDetails == true`.
- [x] Q081 | Evidence: success presentation with default details should not ask for duplicate details. | Fix: defaulted widget calls pass SPF/area notes. | Verification: defaulted widget test verifies stored values.
- [x] Q082 | Evidence: Browser advisory flagged existing-record isolation. | Fix: caller-level `.empty` defaults for existing records. | Verification: preservation tests.
- [x] Q083 | Evidence: Browser advisory flagged stable last-log definition. | Fix: resolver uses the same verifiedAt/startOfDay ordering as manual suggestions. | Verification: shared sorted-record helper.
- [x] Q084 | Evidence: Browser advisory flagged legacy note inference. | Fix: structured parser only reads `Areas:` line. | Verification: no-free-form-copy test.
- [x] Q085 | Evidence: Browser advisory flagged extension cache staleness. | Fix: action handlers resolve from current model/widget stores at execution, and full-surface button labels prevent off-button taps from falling through to app navigation. | Verification: seed-immediately-before-action tests and `SunclubLogTodayWidgetPresentation.tapAction` assertions.
- [x] Q086 | Evidence: Browser advisory flagged repeated taps. | Fix: upsert logic remains one-record-per-day. | Verification: existing update tests.
- [x] Q087 | Evidence: Browser advisory flagged SPF normalization. | Fix: normalization remains central. | Verification: normalization tests.
- [x] Q088 | Evidence: generated visual checklist flagged readable SPF confirmation. | Fix: tests assert SPF appears in manual and snapshot surfaces. | Verification: UI label and snapshot assertions.
- [x] Q089 | Evidence: generated visual checklist flagged no free-form note copying. | Fix: one-tap notes are only the area line. | Verification: notes-removing-covered-areas assertions.
- [x] Q090 | Evidence: generated visual checklist flagged Manual Log SPF prefill. | Fix: Manual Log initial state reads default SPF. | Verification: Home and History UI assertions.
- [x] Q091 | Evidence: accessibility scorecard requires visible specific control labels. | Fix: new UI checks use stable accessibility identifiers instead of visual-only state. | Verification: UITest helpers target identifiers.
- [x] Q092 | Evidence: Dynamic Type can change exact label composition. | Fix: SPF row test uses contains-match for SPF number. | Verification: `waitForValueContaining`.
- [x] Q093 | Evidence: history editor state uses exact text. | Fix: test anchors the expected prefilled state. | Verification: `waitForLabel("SPF 30 selected", ...)`.
- [x] Q094 | Evidence: docs require a living ledger for this broad quality pass. | Fix: this document captures evidence, fix/status, and verification notes. | Verification: Python ledger test.
- [x] Q095 | Evidence: broad ledgers can decay below the requested item count. | Fix: `tests/test_quality_ledger.py` enforces at least 100 entries. | Verification: Python test.
- [x] Q096 | Evidence: broad ledgers can omit evidence/fix/verification fields. | Fix: Python test validates required fields in each ledger row. | Verification: Python test.
- [x] Q097 | Evidence: broad ledgers can leave unresolved placeholder markers. | Fix: Python test rejects unfinished rows. | Verification: Python test.
- [x] Q098 | Evidence: PR reviewers need to see the exact source set. | Fix: ledger links changes to concrete files/tests by name. | Verification: `git diff --stat` and PR body.
- [x] Q099 | Evidence: release workflows depend on clean worktrees. | Fix: release step will run from a clean post-merge worktree, not this dirty branch. | Verification: release-tag script requires clean status.
- [x] Q100 | Evidence: TestFlight trust depends on final IPA entitlements, not source entitlements. | Fix: release checklist includes artifact download and final diagnostics inspection. | Verification: `.github/workflows/release-testflight.yml` uploads `.build/release-diagnostics`.
- [x] Q101 | Evidence: Internal tester assignment is easy to miss after upload. | Fix: release workflow includes `scripts.appstore.testflight_groups --group Internal`. | Verification: tag workflow step and post-release log inspection.
- [x] Q102 | Evidence: latest tag may drift before release. | Fix: release plan requires refetching tags before choosing `v2.0.2`. | Verification: `git fetch --tags` before `just release-testflight`.
- [x] Q103 | Evidence: PR checks can differ from local tests. | Fix: PR lifecycle includes `gh pr checks` monitoring. | Verification: remote checks before merge.
- [x] Q104 | Evidence: master can fail after a green PR merge. | Fix: plan includes waiting for post-merge master CI. | Verification: `gh run list --branch master` after merge.
- [x] Q105 | Evidence: local Xcode can stall in this repo. | Fix: verification plan allows full `just ci` only if local Xcode is stable and records blockers. | Verification: command logs.
- [x] Q106 | Evidence: compile-cache issues have a documented recovery switch. | Fix: local iOS verification will use repo tooling and can set `SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1` if needed. | Verification: command environment and logs.
- [x] Q107 | Evidence: lint should catch docs/Python changes. | Fix: ledger and Python test are repo-formatted Markdown/Python. | Verification: `just lint`.
- [x] Q108 | Evidence: Python metadata tests should cover project source dependencies. | Fix: metadata test checks widget resolver dependency. | Verification: `just test-python`.
- [x] Q109 | Evidence: Swift tests should cover behavior, not just code shape. | Fix: added unit and UI behavior assertions. | Verification: `just test-unit` and `just test-ui`.
- [x] Q110 | Evidence: whitespace errors can break CI. | Fix: final verification includes `git diff --check`. | Verification: `git diff --check`.
