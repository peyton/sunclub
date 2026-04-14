# App Store Readiness Improvements

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This repository does not contain `.agent/PLANS.md`; the local plan template was found at `/Users/peyton/.agents/PLANS.md`. This document follows that template and is self-contained for future contributors.

## Purpose / Big Picture

Sunclub is being prepared for App Store review. This pass improves the first-run and daily-use experience without changing the persisted SwiftData schema. After the work, users should see clearer scanning, logging, settings, and reminder behavior, while the app does less unnecessary work in common paths. The changes are intentionally small and reviewable because this is a release hardening pass, not a redesign.

## Progress

- [x] (2026-04-14 03:58Z) Audited the repository layout, release scripts, key SwiftUI views, accessibility tests, scanner service, and AppState time-dependent code.
- [x] (2026-04-14 03:58Z) Selected a release-safe scope that avoids persisted schema changes and external dependencies.
- [x] (2026-04-14 04:15Z) Improved scanner parsing correctness for SPF labels and expiration labels.
- [x] (2026-04-14 04:15Z) Improved scanner efficiency by avoiding repeated regular expression compilation and reducing oversized OCR payloads.
- [x] (2026-04-14 04:15Z) Improved scanner usability by preventing stale scan results, disabling conflicting actions while scans are active, and making denied camera access clearer.
- [x] (2026-04-14 04:15Z) Improved manual log usability by surfacing the already-computed usual SPF suggestion and allowing multi-line notes.
- [x] (2026-04-14 04:15Z) Improved AppState consistency by using the injected clock for time-sensitive behavior instead of direct `Date()` calls where the app already owns a clock.
- [x] (2026-04-14 04:15Z) Added focused unit tests for parser correctness, suggestion presentation data, and deterministic app-state time behavior.
- [x] (2026-04-14 04:15Z) Ran the relevant repo commands and fixed the one test-calendar mismatch discovered during verification.

## Surprises & Discoveries

- Observation: `SunclubProductScannerService.detectedExpiration(in:)` uses a helper that returns the first capture group, so a label like `EXP 05/2027` can collapse to only `05` instead of preserving the useful full date text.
  Evidence: `firstMatch(for:in:)` returns `match.range(at: 1)` whenever a pattern has captures.
- Observation: The scanner compiles each regular expression inside nested loops for every OCR line.
  Evidence: `firstMatch(for:in:)` calls `NSRegularExpression(pattern:)` on each pattern and line.
- Observation: `ManualLogSuggestionState.defaultSPF` is computed but not displayed in `SunManualLogFields`.
  Evidence: `ManualLogSuggestionEngine.suggestions` fills `defaultSPF`, while `SunManualLogFields` only renders `sameAsLastTime`, presets, scanned SPF levels, and notes.
- Observation: `AppState` accepts an injected `clock` but several time-sensitive methods still call `Date()` directly.
  Evidence: `markAppliedToday`, `currentStreak`, `last7DaysReport`, `monthlyReviewInsights`, `syncWidgetSnapshot`, and related helpers call `Date()` rather than `currentDate()`.

## Decision Log

- Decision: Keep this pass additive and avoid SwiftData schema changes.
  Rationale: App Store readiness work should reduce release risk. Persisted model changes require a schema bump and migration tests, which would make the pass larger than needed.
  Date/Author: 2026-04-14 / Codex.
- Decision: Focus scanner improvements on deterministic parsing and UI flow rather than introducing a new OCR or image-processing dependency.
  Rationale: The project instructions say not to add external dependencies, and Vision already exists in the app.
  Date/Author: 2026-04-14 / Codex.
- Decision: Use the existing AppState clock rather than adding a new time service.
  Rationale: The dependency already exists, is testable, and matches the repo's conservative architecture.
  Date/Author: 2026-04-14 / Codex.

## Outcomes & Retrospective

Implemented a release-hardening pass across scanner, manual logging, and time-sensitive app state without changing persisted SwiftData schema or adding dependencies.

Concrete outcomes:

- Scanner OCR analysis is now testable without Vision by calling `SunclubProductScannerService.analyze(recognizedText:)`.
- Scanner SPF parsing handles common label variants including `SPF-50+`, `SPF: 30`, `sun protection factor 45`, `50 SPF`, and sunscreen-only labels.
- Scanner expiration parsing preserves useful full strings for numeric, year-first, slash, and month-name labels.
- Scanner regexes are precompiled once instead of rebuilt per OCR line.
- Scanner recognized text is normalized, de-duplicated, and capped before display.
- Product scanner UI downsamples oversized images before preview and scanning.
- Product scanner UI disables competing scan actions while a scan is active.
- Product scanner UI clears the photo picker item after image loading so the same photo can be selected again.
- Product scanner UI prevents stale async scan results from overwriting newer scan results.
- Product scanner UI hides the camera action when camera permission is denied while keeping photo import reachable.
- Product scanner UI exposes stable accessibility identifiers for scan progress, recognized text, use-result, and result sections.
- Manual log fields now surface the existing usual SPF suggestion when it is useful.
- Manual log note entry now supports vertical multi-line input.
- AppState now uses its injected clock for today logs, reapplication, streaks, weekly reports, monthly insights, reminder/recovery behavior, and widget snapshots.
- Unit tests cover scanner parsing, expiration handling, recognized text limits, usual SPF suggestions, and injected-clock behavior.

Verification:

- `just test-unit` passed: 180 tests, 0 failures.
- `just test-ui` passed: 51 tests, 0 failures.
- `just appstore-validate` passed with warnings that review contact remains marked not ready and App Store Connect privacy completion is still false.
- `just lint` passed. SwiftLint reported 16 non-failing warnings in pre-existing files outside this pass.
- `git diff --check` passed.

Remaining release gates:

- Fill in the App Store review contact before submission.
- Complete and mark the App Store Connect App Privacy questionnaire.
- Decide whether to clean up the existing SwiftLint warnings before final archive; they are not new from this pass and do not currently fail lint.

## Context and Orientation

The iOS app lives under `app/Sunclub`. SwiftUI views are in `app/Sunclub/Sources/Views`, shared UI components are in `app/Sunclub/Sources/Shared`, services are in `app/Sunclub/Sources/Services`, and tests are in `app/Sunclub/Tests` plus `app/Sunclub/UITests`. Project commands are exposed through the repository root `justfile`; relevant commands include `just test-unit`, `just test-ui`, `just test-python`, `just lint`, `just ci`, and `just appstore-validate`.

`AppState` is the main observable state object injected into SwiftUI views. It owns loaded history records, settings, UV status, reminder state, growth features, and widget snapshot syncing. It already accepts a `clock` closure in its initializer, so deterministic time-sensitive behavior should use `currentDate()` instead of direct `Date()` calls inside `AppState`.

`SunclubProductScannerService` uses Apple's Vision framework to recognize text in sunscreen label images. Vision returns text lines, and the service extracts SPF and expiration information from those lines. A regular expression is a text pattern matcher. Recompiling regex patterns for every line is unnecessary work, and returning the wrong capture group can produce wrong user-visible dates.

`SunManualLogFields` is the reusable SPF and notes editor used by manual logging and history editing. It already receives `ManualLogSuggestionState`, which includes recent SPF, note, and scanned SPF suggestions.

## Plan of Work

First, update `app/Sunclub/Sources/Services/SunclubProductScannerService.swift` so OCR analysis is separated from Vision image capture. Add a small, testable analyzer function that takes recognized text lines and returns `SunclubProductScanResult`. Precompile SPF and expiration regexes once, normalize OCR lines by trimming and collapsing whitespace, de-duplicate repeated lines, cap the recognized text shown in the UI, support common label variants such as `SPF-50`, `SPF: 30`, `sun protection factor 50`, `EXP 05/2027`, `Expires 05/27`, and `EXP 2027-05`, and preserve the full expiration string instead of returning only one capture group.

Second, update `app/Sunclub/Sources/Views/ProductScannerView.swift` so a new scan cannot be overwritten by an older scan result. Add a scan request token, disable camera and photo actions while scanning, clear the photo picker item after loading so the same image can be selected again, and use the scanner service's normalized result. Keep camera-denied fallback obvious and keep accessibility identifiers for UI tests.

Third, update `app/Sunclub/Sources/Shared/SunManualLogFields.swift` so the default SPF suggestion is visible when useful, not just computed. Keep presets and scanned SPF chips, but add a small "Usual SPF" chip when there is a recent SPF value that is not already selected and not already duplicated by the same-as-last-time chip. Change the notes field to a vertical text field so longer notes do not become awkward to edit.

Fourth, update `app/Sunclub/Sources/Services/AppState.swift` so time-sensitive logic inside `AppState` uses the injected `currentDate()` clock consistently. This includes today's log writes, current streak calculation, weekly and monthly summaries, default backfill timestamps, reminder and recovery presentation logic, and widget snapshot timestamps.

Fifth, add or extend tests under `app/Sunclub/Tests`. Unit tests should cover scanner analyzer parsing and limits, manual log suggestion state behavior, and injected-clock behavior. Existing UI tests should not need broad changes because the user-facing flow remains the same.

## Concrete Steps

Work from the repository root `/Users/peyton/.codex/worktrees/d4b6/sunclub`.

Edit these files:

- `app/Sunclub/Sources/Services/SunclubProductScannerService.swift`
- `app/Sunclub/Sources/Views/ProductScannerView.swift`
- `app/Sunclub/Sources/Shared/SunManualLogFields.swift`
- `app/Sunclub/Sources/Services/AppState.swift`
- `app/Sunclub/Tests/ImprovementTests.swift`

After edits, run:

    just test-unit
    just test-ui
    just appstore-validate
    just lint

If `just test-unit` is too broad or fails because of simulator availability, run the closest generated Xcode unit-test command reported by `scripts/tooling/test_ios.sh --suite unit` and capture the failure. Do not report the app ready until relevant failures are fixed or clearly documented as an environment blocker.

## Validation and Acceptance

The scanner is accepted when unit tests prove these behaviors: `SPF-50`, `SPF: 30`, `sun protection factor 45`, and `50 SPF` all parse to the intended SPF; expiration strings such as `EXP 05/2027`, `Expires 05/27`, `EXP 2027-05`, and `EXP JAN 2027` preserve useful date text; duplicate OCR lines are collapsed; and the recognized text list is capped.

The manual log fields are accepted when unit tests prove that a recent SPF can appear as `defaultSPF` even when the most recent reusable record only has a note, and the view exposes a stable accessibility identifier for the usual-SPF chip.

The AppState clock cleanup is accepted when unit tests prove that `recordVerificationSuccess`, `currentStreak`, `last7DaysReport`, and widget snapshot generation use the injected clock in a controlled test.

The release pass is accepted when the relevant tests and validation commands complete successfully, or when any remaining failure is documented with the exact command and reason.

## Idempotence and Recovery

The edits are source-only and can be safely repeated. No data migration is introduced. If scanner parsing changes produce unexpected results, revert only the scanner service and its tests. If AppState clock changes break a test, inspect whether the test assumes wall-clock `Date()` or the AppState `clock`; prefer the injected clock when the behavior belongs to AppState.

## Artifacts and Notes

Important evidence discovered during audit:

    firstMatch(for:in:) currently returns the first capture group whenever a regex has captures.
    ManualLogSuggestionState.defaultSPF is populated by ManualLogSuggestionEngine but not rendered by SunManualLogFields.
    AppState has currentDate but still calls Date() in several AppState-owned time decisions.

## Interfaces and Dependencies

Do not add external dependencies. Continue using Swift, SwiftUI, Vision, SwiftData, and existing project helpers.

`SunclubProductScannerService` should expose an internal static function with this shape so unit tests can bypass Vision:

    static func analyze(recognizedText lines: [String]) -> SunclubProductScanResult

`ProductScannerView` should keep routing through `AppRouter` and keep scanner calls asynchronous.

`SunManualLogFields` should keep the existing initializer signature so current call sites continue compiling.

`AppState` should keep the existing initializer `clock: @escaping () -> Date` and use it through the existing `currentDate` property.
