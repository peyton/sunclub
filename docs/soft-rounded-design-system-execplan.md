# Soft Rounded Design System

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document follows the ExecPlan requirements in `/Users/peyton/.agents/PLANS.md`.

## Purpose / Big Picture

Sunclub's daily app surface should feel soft, rounded, calm, and consistent across iPhone and Apple Watch. After this change, the active Home screen will match the provided reference more closely: a simple brand header, a clean timeline, one clear applied-status card, a prominent capsule logging action, and lighter weekly/accountability actions. The same typography, spacing, colors, radius, and button/card treatments will be shared by the rest of the app so users do not move between unrelated visual styles.

The work is visual and structural only. It must not add new features, change SwiftData models, change CloudKit behavior, or alter logging semantics.

## Progress

- [x] (2026-04-25T00:00Z) Created this ExecPlan before source edits.
- [x] (2026-04-25T00:45Z) Added cross-platform design-system tokens and components.
- [x] (2026-04-25T01:00Z) Removed the legacy `HomeView` path and updated UI-test launch helpers.
- [x] (2026-04-25T02:15Z) Redesigned the active `TimelineHomeView` around the requested simplified home layout.
- [x] (2026-04-25T03:45Z) Migrated iOS screens, shared timeline/manual-log components, and the Watch app screen to shared styling primitives.
- [x] (2026-04-25T04:15Z) Added style guard tests and updated `DESIGN.md`.
- [x] (2026-04-25T05:25Z) Ran generation, tests, builds, and practical visual inspection.

## Surprises & Discoveries

- Observation: The default post-onboarding Home route is `TimelineHomeView`; `HomeView` is legacy and only reachable through the UI-test argument `UITEST_USE_LEGACY_HOME`.
  Evidence: `RootView` branches on `RuntimeEnvironment.shouldUseLegacyHome`, which is true only in UI testing when that argument is present.

- Observation: Existing shared visual primitives live in `app/Sunclub/Sources/Shared/AppTheme.swift`, but the Watch app target does not compile that whole theme file.
  Evidence: `app/Sunclub/Project.swift` includes selected shared files in watch target sources, not `Sources/Shared/AppTheme.swift`.

- Observation: Removing legacy `HomeView.swift` also removed `HomeGreetingFormatter`, which only served the legacy home greeting and its unit test.
  Evidence: `SunclubTests.swift` still referenced `HomeGreetingFormatter` after the file deletion; the formatter test was removed with the legacy surface.

- Observation: Existing app screens contained many direct `.font(.system(...))`, numeric `RoundedRectangle(cornerRadius:)`, raw warning colors, and a few raw shadows.
  Evidence: A source scan before the guard-test pass found these across `Views`, `SunManualLogFields`, and `SunDayStrip`; they now route through `AppFont`, `AppRadius`, `AppColor`, and `AppShadow`.

## Decision Log

- Decision: Add a new `AppDesignSystem.swift` and keep compatibility wrappers in `AppTheme.swift`.
  Rationale: The requested components should be available to both iOS and Watch. Keeping existing names as wrappers avoids a risky all-at-once rewrite of every screen while still making the new tokens authoritative.
  Date/Author: 2026-04-25 / Codex

- Decision: Delete legacy `HomeView` rather than restyle it.
  Rationale: The user explicitly chose to remove the legacy home. Keeping two homes would duplicate design-system migration work and preserve a path that is no longer product-relevant.
  Date/Author: 2026-04-25 / Codex

## Outcomes & Retrospective

Implementation is complete. The app now has a shared soft-rounded design system, the legacy `HomeView` route is gone, and the default Home surface is the simplified timeline home. iOS screens, shared timeline/manual-log components, and the Watch home screen now consume the shared typography, color, radius, spacing, shadow, card, badge, stat, capsule, and button primitives.

Validation passed for generation, unit tests, UI tests, lint, CI build, and the requested 40 mm Watch build. The final iPhone small-screen inspection showed the Home card, stat cards, primary log action, and footer pills without clipping or overlap. The Watch 40 mm screenshot showed the primary watch log action visible above secondary content.

## Context and Orientation

The iOS app source lives under `app/Sunclub/Sources`. The active home screen is `app/Sunclub/Sources/Views/TimelineHomeView.swift`. The horizontal timeline is `app/Sunclub/Sources/Shared/SunDayStrip.swift`. The bottom home actions are in `app/Sunclub/Sources/Views/Components/TimelineFooterBar.swift`, and the day log section is in `app/Sunclub/Sources/Views/Components/TimelineLogSection.swift`.

Existing iOS visual helpers live in `app/Sunclub/Sources/Shared/AppTheme.swift`. That file currently defines palette, typography, radius, screen backgrounds, button styles, card helpers, brand mark helpers, and visual-asset helpers. This pass will add `app/Sunclub/Sources/Shared/AppDesignSystem.swift` as the new cross-platform source of truth, then make `AppTheme.swift` use or wrap those primitives for existing iOS call sites.

The Watch app screen is `app/Sunclub/WatchApp/Sources/SunclubWatchHomeView.swift`. It must keep the primary log action visible near the top on small watches.

## Plan of Work

First, add `AppDesignSystem.swift` with semantic colors, rounded typography, radius, spacing, shadow, and the required components: `AppText`, `AppCard`, `PrimaryButton`, `SecondaryPillButton`, `StatusBadge`, `DayCapsule`, and `StatCard`. Wire the file into iOS, widget, watch app, watch extension, and watch widget targets as needed by `app/Sunclub/Project.swift`.

Second, update `AppTheme.swift` so existing `AppPalette`, `AppTypography`, `AppRadius`, `SunPrimaryButtonStyle`, `SunSecondaryButtonStyle`, `SunclubCard`, `SunMetricPill`, `SunWeekProgressRow`, `SunLightHeader`, `SunStatusCard`, and `.sunGlassCard(...)` consume the new tokens. Existing screens can keep compiling while the visible style becomes softer and more rounded.

Third, remove `HomeView.swift`, remove `RuntimeEnvironment.shouldUseLegacyHome`, and simplify `RootView` so `.home` and the post-onboarding root always use `TimelineHomeView`. Update UI test helpers that previously forced the legacy argument.

Fourth, redesign `TimelineHomeView`, `SunDayStrip`, `TimelineFooterBar`, and `TimelineLogSection` around the reference layout. The logged-today card title must be `Applied`; the subtitle must be `Optional: add SPF or a note`; the done state must use `StatusBadge`; and the two metrics must use `StatCard`. Non-logged, past, and future states must use truthful short alternatives.

Fifth, migrate representative app surfaces to the new components and typography: Manual Log, Weekly, History, Settings, Recovery, Friends/Accountability, Automation, Reapply, Verification Success, Onboarding, Achievements, Scanner, Skin Health Report, Year in Review, and shared manual-log fields. Use scoped edits that preserve routes, copy intent, accessibility identifiers, and logging behavior.

Sixth, update `SunclubWatchHomeView` to use the same rounded typography, color tokens, cards, and button treatment while keeping the logging button above secondary information.

Finally, add or update style guard tests and documentation, then run validation.

## Concrete Steps

Run commands from `/Users/peyton/.codex/worktrees/44ff/sunclub`.

1. Edit `app/Sunclub/Sources/Shared/AppDesignSystem.swift`.
2. Edit `app/Sunclub/Sources/Shared/AppTheme.swift`.
3. Edit `app/Sunclub/Project.swift`.
4. Delete `app/Sunclub/Sources/Views/HomeView.swift`.
5. Edit `app/Sunclub/Sources/Shared/RuntimeEnvironment.swift`, `app/Sunclub/Sources/Shared/RootView.swift`, and `app/Sunclub/UITests/SunclubUITests.swift`.
6. Edit the active Home and representative screen files named in the Plan of Work.
7. Edit `app/Sunclub/WatchApp/Sources/SunclubWatchHomeView.swift`.
8. Edit `DESIGN.md` and relevant tests.

## Validation and Acceptance

Run:

    just generate
    SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 just test-unit
    SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 just test-ui
    just lint
    SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 just ci-build
    xcodebuild -workspace app/Sunclub.xcworkspace -scheme SunclubWatch -destination 'platform=watchOS Simulator,name=Apple Watch SE 3 (40mm)' CODE_SIGNING_ALLOWED=NO build

Acceptance is met when the app builds, unit/UI tests pass or any environment-specific blocker is recorded exactly, and visual inspection confirms that the iPhone Home screen and 40 mm Watch screen have no clipped or overlapping primary content.

## Idempotence and Recovery

The work is source-only and does not touch user data. If build generation fails, fix the Tuist manifest or source membership and rerun `just generate`. If a style guard test is too broad, narrow the allowlist to intentional design-system files rather than weakening the rule for all screens.

## Artifacts and Notes

- `just generate` passed. Tuist emitted only the existing remote-cache auth warning.
- `SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 just test-unit` passed with 282 tests.
- `SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 just test-ui` passed with 54 tests.
- `just lint` passed. SwiftLint reported warning-level output only: 35 violations, 0 serious.
- `SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 just ci-build` passed. Tuist share/upload failed because the local session is not logged in; the repo script treats that as a warning after the local build artifact succeeds.
- `xcodebuild -workspace app/Sunclub.xcworkspace -scheme SunclubWatch -destination 'platform=watchOS Simulator,name=Apple Watch SE 3 (40mm)' CODE_SIGNING_ALLOWED=NO build` passed. Xcode reported non-fatal local CAS cache connection warnings and continued.
- Visual screenshots inspected: `/tmp/sunclub-home-iphone-17e-updated3.png` and `/tmp/sunclub-watch-40mm.png`.

## Interfaces and Dependencies

No third-party dependencies are introduced. Public app behavior stays the same. The new local interface is:

    enum AppColor
    enum AppSpacing
    enum AppShadow
    struct AppText
    struct AppCard
    struct PrimaryButton
    struct SecondaryPillButton
    struct StatusBadge
    struct DayCapsule
    struct StatCard

These types are SwiftUI-only and must compile for iOS and watchOS.
