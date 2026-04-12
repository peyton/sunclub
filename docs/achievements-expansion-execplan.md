# Expand Achievements and Improve Progress UI

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

The repository instruction references `~/.agent/PLANS.md`, but that file is not present on this machine. The compatible plan guide was found at `/Users/peyton/.agents/PLANS.md`, and this document follows that format.

## Purpose / Big Picture

Sunclub currently has a small achievement set that mainly rewards streaks. After this change, the Achievements screen rewards a wider range of sunscreen habits: morning logs, weekend consistency, SPF variety, notes, reapply behavior, high-UV protection, live UV setup, home reminders, product scanning, and sharing or friend activity. A user can open Achievements and immediately see a higher-contrast progress meter with the exact percent, count, and remaining work for each badge.

## Progress

- [x] (2026-04-12 00:23Z) Confirmed the current achievement model lives in `app/Sunclub/Sources/Models/GrowthFeatures.swift`, analytics in `app/Sunclub/Sources/Services/SunclubGrowthAnalytics.swift`, and the list UI in `app/Sunclub/Sources/Views/AchievementsView.swift`.
- [x] (2026-04-12 00:23Z) Confirmed that SwiftData schema changes are unnecessary because achievement event telemetry can live in the existing app-group `SunclubGrowthSettings` JSON.
- [x] (2026-04-12 00:23Z) Add the 10 new achievement identifiers, metadata, and telemetry-compatible settings decoding.
- [x] (2026-04-12 00:23Z) Extend analytics to compute each new achievement from records, settings, growth settings, and telemetry.
- [x] (2026-04-12 00:23Z) Record share and product-scan telemetry through AppState and existing share/scanner UI entry points.
- [x] (2026-04-12 00:23Z) Replace low-contrast `ProgressView` rows with high-contrast achievement and challenge cards.
- [x] (2026-04-12 00:23Z) Add unit and UI tests for the new achievements, telemetry compatibility, and visible progress UI.
- [x] (2026-04-12 00:43Z) Ran `just generate`, `just test-unit`, `just test-ui`, and `just lint`; all required commands completed successfully.

## Surprises & Discoveries

- Observation: The requested `~/.agent/PLANS.md` path does not exist, but `/Users/peyton/.agents/PLANS.md` does.
  Evidence: `sed -n '1,260p' ~/.agent/PLANS.md` failed with “No such file or directory”; `find /Users/peyton -maxdepth 3 -name PLANS.md` found `/Users/peyton/.agents/PLANS.md`.
- Observation: The working tree already contains an unrelated modification to `mise.lock`.
  Evidence: `git status --short` showed `M mise.lock` before this work began.

## Decision Log

- Decision: Do not bump the SwiftData schema for this feature.
  Rationale: No `@Model` persisted fields are changing. App-group growth settings already store achievements-related presentation state and friend snapshots, so lightweight share/product telemetry belongs there with a Codable default for older JSON.
  Date/Author: 2026-04-12 / Codex
- Decision: Count a share action when the user taps a Sunclub share entry point and the app prepares the share sheet.
  Rationale: The existing `ActivityShareSheet` does not report iOS share completion, and wiring completion callbacks would add more scope than the achievement needs.
  Date/Author: 2026-04-12 / Codex
- Decision: Treat location-related achievement progress as setup state, not location history.
  Rationale: The planned `homeBase` badge can be computed from the existing leave-home reminder configuration without storing where sunscreen was applied.
  Date/Author: 2026-04-12 / Codex

## Outcomes & Retrospective

Implemented 10 new achievements, growth telemetry with backward-compatible settings decoding, a high-contrast achievements progress UI, share/scanner telemetry entry points, focused unit coverage, and a deterministic UI test route. All 18 achievements render through analytics and share-card coverage, the 10 new achievements unlock from minimal fixtures and remain locked below target, older growth settings JSON keeps existing fields while defaulting telemetry to zero, and telemetry can unlock `bottleDetective` and `socialSpark`.

`just lint` initially failed because the expanded analytics function exceeded the SwiftLint body-length rule. The analytics code was split into a short orchestration function plus focused progress/detail helpers, then unit tests and lint were rerun successfully.

## Context and Orientation

`SunclubAchievementID` is the enum of badge identifiers in `app/Sunclub/Sources/Models/GrowthFeatures.swift`. `SunclubAchievement` is the value displayed by the UI and shared through achievement cards. `SunclubGrowthAnalytics.achievements` converts persisted daily records, change history, and lightweight growth state into those values. `AppState.achievements` exposes the analytics result to SwiftUI. `AchievementsView` renders both achievement badges and seasonal challenges.

Daily sunscreen logs are stored as `DailyRecord` SwiftData models. The app also has `Settings`, which includes live UV and smart reminder preferences, and `SunclubGrowthSettings`, which is Codable JSON persisted by `SunclubGrowthFeatureStore` in app-group defaults. Adding Codable fields to `SunclubGrowthSettings` requires a compatibility initializer so older saved JSON still loads.

## Plan of Work

First, add a `SunclubGrowthTelemetry` struct to `GrowthFeatures.swift`, add it to `SunclubGrowthSettings`, and implement custom decoding that defaults missing telemetry to an empty struct. Then add the 10 new achievement enum cases with titles, symbols, and targets.

Second, extend `SunclubGrowthAnalytics.achievements` to accept `settings` and `growthSettings`. Compute each badge from local records and app state: early logs use `verifiedAt`, weekend pairs use Saturday plus the following Sunday, SPF variety uses distinct `spfLevel` values, notes use `trimmedNotes`, reapply relay uses the max per-day `reapplyCount`, high-UV hero uses the existing estimated midday UV helper, home base uses leave-home reminder setup, live signal uses `usesLiveUV`, bottle detective uses product scan telemetry, and social spark uses share telemetry or imported friends.

Third, add narrow AppState methods for share and scanner telemetry. Call them from `AchievementsView`, `SkinHealthReportView`, `FriendsView`, and `ProductScannerView` only after the relevant share artifact or SPF result is available.

Fourth, replace the low-contrast progress bars in `AchievementsView` with compact cards that include a visible dark track, bright fill, percent/count pill, and status label. Keep the view composed of small SwiftUI subviews and preserve share buttons for unlocked achievements and completed challenges.

Finally, add unit tests for analytics and settings decoding, update share-card rendering coverage, add a UI test for deterministic progress labels, run generation and verification commands, and update this plan with the results.

## Concrete Steps

Run all commands from `/Users/peyton/.codex/worktrees/562c/sunclub`.

After editing models and analytics, run:

    just generate
    just test-unit

After UI work and UI tests, run:

    just test-ui
    just lint

If `just test-ui` cannot complete because a simulator or Xcode runtime is unavailable, record the error here and still run `just test-unit` and `just lint`.

## Validation and Acceptance

The change is accepted when `SunclubAchievementID.allCases.count` is 18, unit tests show every new achievement can unlock from a minimal fixture and remain locked below target, old growth settings JSON decodes with existing fields preserved, and telemetry increments can unlock `bottleDetective` and `socialSpark`.

The Achievements UI is accepted when a UI test opens the deterministic Achievements route and finds an achievement card, a progress meter accessibility identifier, a visible count/percent label, and an unlocked status.

## Idempotence and Recovery

The changes are additive. Re-running `just generate` is expected to refresh generated project files. Re-running tests should not alter tracked source files. If a test command fails, fix the source or test failure and rerun the same command before moving on. Do not revert the pre-existing `mise.lock` change unless explicitly asked.

## Artifacts and Notes

- `just generate`: succeeded.
- `just test-unit`: succeeded after the analytics refactor; 122 tests, 0 failures.
- `just test-ui`: succeeded; 34 UI tests, 0 failures. The new `testAchievementsShowClearProgressMeters` test passed.
- `just lint`: succeeded. SwiftLint reported warnings only, including pre-existing warnings outside this feature and non-fatal complexity warnings for the expanded achievement switches.

## Interfaces and Dependencies

In `GrowthFeatures.swift`, define:

    struct SunclubGrowthTelemetry: Codable, Equatable, Sendable

It must include `shareActionCount`, `productScanUseCount`, `lastSharedAt`, and `lastProductScanUsedAt`, with defaults that represent no telemetry.

In `AppState.swift`, define:

    func recordShareActionStarted()
    func recordProductScanUsedForLog(spfLevel: Int?)

Both methods persist growth settings and call achievement synchronization so new badges can appear promptly.

No external dependencies should be added.
