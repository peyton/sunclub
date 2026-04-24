# Native Wellness Polish Pass

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document follows the ExecPlan requirements in `/Users/peyton/.agents/PLANS.md`.

## Purpose / Big Picture

Sunclub already has a warm, low-pressure sunscreen tracking direction. This pass makes the app feel more like a finished native iOS wellness app by tightening hierarchy, spacing, card styling, button treatments, and logged-versus-not-logged states. A user should land on Home and immediately understand whether they still need sunscreen today, then move through manual logging, success, weekly progress, history, backfill, onboarding, and reapply flows with calmer, more consistent components.

This is a visual and interaction polish pass only. It does not change SwiftData models, CloudKit sync, app groups, signing, or release automation.

## Progress

- [x] (2026-04-24T09:40:57Z) Read the local SwiftUI UI-pattern skill, the repo ExecPlan guide, current Sunclub visual plans, and the priority SwiftUI surfaces.
- [x] (2026-04-24T09:40:57Z) Confirmed the default post-onboarding Home route is `TimelineHomeView`, while `HomeView` remains the legacy home behind `RuntimeEnvironment.shouldUseLegacyHome`.
- [x] (2026-04-24T09:40:57Z) Confirmed this pass can stay visual-only and does not require a SwiftData schema migration.
- [x] (2026-04-24T10:22:17Z) Added shared polish primitives in `app/Sunclub/Sources/Shared/AppTheme.swift`.
- [x] (2026-04-24T10:22:17Z) Applied the shared primitives to the first priority screens: Home, Manual Log, Success, History/Backfill, Reapply, Weekly Summary, and Onboarding.
- [x] (2026-04-24T10:22:17Z) Extended the same visual language across Settings, Automation, Recovery, Friends, Reports, Product Scanner, and Year in Review.
- [x] (2026-04-24T10:22:17Z) Preserved existing UI-test identifiers and restored the manual-log details disclosure after the first UI run exposed regressions.
- [x] (2026-04-24T10:22:17Z) Ran generation, lint, unit, and UI validation commands and recorded evidence here.

## Surprises & Discoveries

- Observation: A previous visual upgrade already added deterministic app assets and the `SunclubVisualAsset` enum.
  Evidence: `docs/sunclub-visual-upgrade-execplan.md` records the asset pack and `AppTheme.swift` already exposes `SunclubVisualAsset`.

- Observation: A timeline polish pass was completed on 2026-04-23, so this pass should preserve the new smooth day strip and log section behavior instead of replacing it.
  Evidence: `docs/timeline-view-polish-execplan.md` records the `TimelineHomeView`, `SunDayStrip`, and `TimelineLogSection` changes.

- Observation: App source tests reject `.minimumScaleFactor(`, fixed `.lineLimit(`, direct SwiftUI animation presets, and low-contrast white foreground styles.
  Evidence: `app/Sunclub/Tests/AccessibilityScorecardTests.swift` scans `app/Sunclub/Sources` for these snippets.

- Observation: `home.todayStatus` is treated by existing UI tests as a logged-only home status, not a generic Today status label.
  Evidence: The first `just test-ui` run failed `testDisabledURLWritesRouteToManualLogWithoutMutatingHistory` until the new Timeline hero used `home.todayStatus` only for logged Today and `timeline.todayStatus` otherwise.

- Observation: The manual-log optional details disclosure is part of the tested smart-reuse and accessibility flows.
  Evidence: The first `just test-ui` run failed `testManualLogShowsSmartReuseSuggestions` and `testAccessibilityScorecardCoreTasksRemainUsable` when the details fields were always expanded without `manualLog.detailsToggle`.

## Decision Log

- Decision: Treat this pass as component-first, then screen-by-screen.
  Rationale: The biggest user-visible issue is inconsistency across cards, buttons, type, and small status affordances. Updating shared primitives first improves many surfaces while keeping individual screen edits smaller.
  Date/Author: 2026-04-24 / Codex

- Decision: Keep the first implementation pass focused on visual hierarchy and existing routes, not new feature behavior.
  Rationale: The user requested polish and a small design system. Changing data behavior, reminder logic, persistence, or release tooling would increase risk without improving the visual goal.
  Date/Author: 2026-04-24 / Codex

- Decision: Preserve the current timeline day strip as the timeline below the new Today status card.
  Rationale: The day strip was just polished and already carries detailed calendar state. The requested Home redesign can add a stronger status card above it without discarding that work.
  Date/Author: 2026-04-24 / Codex

- Decision: Keep Manual Log's details disclosure, but place it inside the new quick-entry card.
  Rationale: The disclosure keeps the default path simple while preserving smart SPF/note reuse, accessibility traversal, and the established `manualLog.detailsToggle` automation surface.
  Date/Author: 2026-04-24 / Codex

## Outcomes & Retrospective

Implemented a broad first polish pass without changing persistence, sync, signing, or release behavior. The app now has shared card, title, metric pill, week progress, text-button, and empty-state primitives. Home leads with a Today status card, protection ring, weekly row, and metrics before the timeline. Manual Log, Success, Reapply, Weekly Summary, History, Backfill, Onboarding, Settings, Automation, Recovery, Friends, Reports, Product Scanner, and Year in Review now use calmer hierarchy, warmer cards, fewer heavy orange CTAs, and more specific copy.

The first UI run found two compatibility regressions: the Today hero reused a logged-only identifier for unlogged state, and Manual Log removed the optional details disclosure expected by smart-reuse and accessibility tests. Both were fixed, and the clean rerun passed.

## Context and Orientation

The default Home screen is `app/Sunclub/Sources/Views/TimelineHomeView.swift`. It renders the brand header, selected date headline, horizontal day strip, attention banners, day log section, and bottom footer. The older `app/Sunclub/Sources/Views/HomeView.swift` is still present for a legacy runtime path.

Shared visual tokens and components live in `app/Sunclub/Sources/Shared/AppTheme.swift`. This file already defines `AppPalette`, `AppTypography`, `AppRadius`, `SunLightScreen`, `SunPrimaryButtonStyle`, `SunSecondaryButtonStyle`, `SunStatusCard`, asset helper views, and the `.sunGlassCard(...)` view modifier.

Manual logging is `app/Sunclub/Sources/Views/ManualLogView.swift` with reusable SPF and notes fields in `app/Sunclub/Sources/Shared/SunManualLogFields.swift`. The success screen is `app/Sunclub/Sources/Views/VerificationSuccessView.swift`. The history calendar and backfill editor are both in `app/Sunclub/Sources/Views/HistoryView.swift`. Reapply check-in is `app/Sunclub/Sources/Views/ReapplyCheckInView.swift`. Weekly summary is `app/Sunclub/Sources/Views/WeeklyReportView.swift`. Onboarding is `app/Sunclub/Sources/Views/OnboardingView.swift`.

The term "card" means a rounded rectangular container for one focused piece of content. In this pass, cards should use a 16 to 20 point radius, a warm beige 1 point stroke, a soft shadow, and about 16 points of internal padding. The term "primary action" means the one most important action on a screen; it should use orange. Green should be limited to logged or protected success states. Red should be limited to actual warnings or destructive situations.

## Plan of Work

First, update `AppTheme.swift` with reusable polish primitives. The work should tune the palette and typography toward the requested warm cream background, flat orange primary actions, softer cards, and clearer body text. Add small components named `SunclubCard`, `SunScreenTitleBlock`, `SunMetricPill`, `SunWeekProgressRow`, and `SunEmptyStateView` so screen code can use one consistent vocabulary.

Second, update `TimelineHomeView.swift` to put a Today status card above the timeline strip. The card should show the selected or current date, a clear status such as "Not yet logged" or "Protected today", a large sun/protection ring, a plain-language detail, a weekly row, and small metrics. The existing day strip should remain below it as the timeline.

Third, update `ManualLogView.swift`, `SunManualLogFields.swift`, and `VerificationSuccessView.swift`. Manual Log should feel like a quick entry sheet with a stronger status header, card-like day-part/SPF/notes treatment, and a subordinate scan row. The success screen should be less sparse by adding streak and next-reminder context plus a calmer text-link style edit action.

Fourth, update `HistoryView.swift` and the nested `HistoryRecordEditorView`. History should give the calendar stronger central weight, use a cleaner legend, and show the month summary as a bottom-style card with applied/open/rate metrics. Backfill should start with a status card for the selected date and present SPF suggestions as tappable chips.

Fifth, update `ReapplyCheckInView.swift`, `WeeklyReportView.swift`, and `OnboardingView.swift`. Reapply should present an instant two-choice decision. Weekly Summary should keep the large fraction while adding a plain-language summary and making History secondary. Onboarding and notification permission should use the requested calmer copy.

If time permits after the first priority screens, extend the same primitives to Settings, Automation, Recovery, Achievements, Friends, Skin Health Report, Product Scanner, Year in Review, and widgets. If not, leave this plan with clear remaining tasks for those lower-priority surfaces.

## Concrete Steps

Run commands from `/Users/peyton/.codex/worktrees/8af9/sunclub`.

Edit:

- `app/Sunclub/Sources/Shared/AppTheme.swift`
- `app/Sunclub/Sources/Views/TimelineHomeView.swift`
- `app/Sunclub/Sources/Views/ManualLogView.swift`
- `app/Sunclub/Sources/Shared/SunManualLogFields.swift`
- `app/Sunclub/Sources/Views/VerificationSuccessView.swift`
- `app/Sunclub/Sources/Views/HistoryView.swift`
- `app/Sunclub/Sources/Views/ReapplyCheckInView.swift`
- `app/Sunclub/Sources/Views/WeeklyReportView.swift`
- `app/Sunclub/Sources/Views/OnboardingView.swift`
- Focused tests under `app/Sunclub/Tests` if reusable presentation behavior changes.

Validation commands should start with:

    just generate
    just test-unit
    just lint

If local Xcode or simulator tooling stalls, record the exact command and blocker, then run the nearest smaller build or test command that still validates the edited surfaces.

## Validation and Acceptance

Acceptance is visual and functional. Home should immediately answer whether the user needs sunscreen today, show the large status card, keep the weekly/timeline context, and preserve existing Home route identifiers used by UI tests. Manual Log should still save and navigate to Success. Success should still return Home and allow details editing when available. History should still allow day selection, editing, deletion, and backfill. Reapply should still log reapplication and return Home. Onboarding should still support both notification opt-in and skip.

Unit and lint checks should pass, or any remaining blocker should be recorded with exact command output. Because this pass touches `app/`, the accessibility scorecard constraints remain a release gate: no fixed essential text truncation, no color-only states, and no direct animations that ignore Reduce Motion.

## Idempotence and Recovery

All edits are source and documentation changes. No user data, SwiftData stores, CloudKit containers, app group paths, signing files, or release workflows are touched. If a Swift compile error occurs, read the first compiler error, fix only the relevant source, and rerun the same command. If a visual change makes a UI test identifier unavailable, preserve the identifier on the new equivalent element rather than changing tests to ignore the missing workflow.

## Artifacts and Notes

- `just generate` passed.
- `SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 just test-unit` passed: 273 tests, 0 failures.
- `SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 just test-ui` passed on the clean rerun: 60 tests, 0 failures.
- `just lint` passed. SwiftLint still reports the repo's existing warning-only set, ending with `Found 36 violations, 0 serious in 130 files`.

## Interfaces and Dependencies

No new third-party dependency is introduced. New shared SwiftUI components should be value-type views in `AppTheme.swift`:

    struct SunclubCard<Content: View>: View
    struct SunScreenTitleBlock: View
    struct SunMetricPill: View
    struct SunWeekProgressRow: View
    struct SunEmptyStateView: View

These components use existing `AppPalette`, `AppTypography`, `AppRadius`, `SunMotion`, and `SunclubVisualAsset` values. They must not introduce global mutable state.

Revision note: 2026-04-24T09:40:57Z. Created the plan after auditing current visual primitives, default routing, existing UI plans, and accessibility constraints.
