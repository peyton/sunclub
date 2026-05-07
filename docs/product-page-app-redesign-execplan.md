# Product Page App Redesign

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document follows the ExecPlan requirements in `/Users/peyton/.agents/PLANS.md`.

## Purpose / Big Picture

Sunclub's iPhone, Watch, widget, and automation surfaces should feel like the attached product page: warm sunlit backgrounds, deep navy type, amber UV accents, blue primary actions, translucent white cards, and dense but calm product utility. After this change, a user opening the app should see the same product promise as the page: log sunscreen, read UV context, understand reapply timing, review history, and reach automation, privacy, support, and documentation paths without moving between unrelated visual systems.

The work is visual and product-surface focused. It must not change SwiftData models, CloudKit sync semantics, entitlement behavior, or destructive data flows. It may rework copy, screen hierarchy, reusable components, and navigation affordances where doing so makes the app match the product page.

## Progress

- [x] (2026-05-06T22:43Z) Created this ExecPlan before source edits.
- [x] (2026-05-06T23:06Z) Audited the current screen set and identified shared components to add or replace.
- [x] (2026-05-06T23:42Z) Updated the reusable design system and compatibility wrappers.
- [x] (2026-05-07T00:18Z) Rebuilt Home around Today, UV context, sunscreen log, exposure/forecast, history, and bottom app navigation affordances.
- [x] (2026-05-07T00:46Z) Reworked Manual Log, History, Settings, Automation, onboarding, Watch, and adjacent copy into the same product-page visual language.
- [x] (2026-05-07T00:58Z) Updated docs/tests that encode design-system rules.
- [x] (2026-05-07T00:57Z) Captured simulator screenshots for Home, Manual Log, History, Settings, and Automation on the iPhone 17 Pro simulator.
- [x] (2026-05-07T01:10Z) Ran final generation, lint, Python, unit, focused UI, and full simulator UI verification.
- [ ] Push the branch, open a PR, monitor required GitHub checks, merge to `master`, then cut the requested TestFlight build from `master`.

## Surprises & Discoveries

- Observation: The worktree started detached at `origin/master` with a pre-existing dirty `mise.lock`.
  Evidence: `git status --short --branch` showed `## HEAD (no branch)` and `M mise.lock`; this redesign will avoid staging that unrelated change unless it becomes required.

- Observation: Prior Sunclub UI work already removed the legacy `HomeView` and made `TimelineHomeView` the only Home surface.
  Evidence: `docs/soft-rounded-design-system-execplan.md` states the active home screen is `app/Sunclub/Sources/Views/TimelineHomeView.swift`, and `DesignSystemAdoptionTests` enforces that `HomeView.swift` stays removed.

- Observation: The selected Xcode 26.5 release candidate could not target the installed iOS simulator runtimes.
  Evidence: `xcodebuild -showdestinations` under `/Applications/Xcode-26.5.0-Release.Candidate.app` reported no available iOS simulators because the SDK expected runtime build `23F73` while the installed iOS 26.5 runtimes were `23F5043g` and `23F5054h`.

- Observation: Xcode 26.4 can build and run the redesign on the existing simulator.
  Evidence: Direct `xcodebuild build` with `DEVELOPER_DIR=/Applications/Xcode-26.4.0.app/Contents/Developer`, destination `87F739DB-5349-4C54-A5C6-3D687406566A`, and compile caching disabled succeeded and produced fresh screenshots under `.build/product-redesign-screenshots/`.

- Observation: The local Tuist compile cache daemon refused connections during verification.
  Evidence: Successful simulator builds used `SUNCLUB_SKIP_LOCAL_TUIST_CACHE=1` or explicit `COMPILATION_CACHE_ENABLE_CACHING=NO COMPILATION_CACHE_ENABLE_PLUGIN=NO` settings.

- Observation: The new Settings quick-access navigation initially returned from Sharing and Recovery to Home instead of Settings during accessibility traversal.
  Evidence: `testAccessibilityScorecardCoreTasksRemainUsable` failed after tapping Sharing, Back, then scanning Settings sections. Changing those rows from route replacement to stack pushes kept Back within Settings and the focused test passed.

- Observation: The complete UI suite passed, but Tuist still crashed while trying to upload unauthenticated run metadata after the Xcode result was already successful.
  Evidence: `just test-ui` executed 55 tests with 0 failures in 657 seconds, then the repo wrapper printed `Warning: tuist xcodebuild exited with Trace/BPT trap after a successful Xcode result; treating as success`.

## Decision Log

- Decision: Treat the attached product page and generated concept sheet as the visual source of truth over older soft-rounded rules.
  Rationale: The user explicitly said to overwrite existing design rules where they conflict with the attached image. Existing components will be adapted rather than bypassed so future changes remain centralized.
  Date/Author: 2026-05-06 / Codex

- Decision: Preserve core Home identifiers such as `home.logManually`, `home.todayStatus`, `home.historyCard`, and `home.streakCard`, but replace the old footer Sharing affordance with a Settings tab.
  Rationale: The attached product page shows Today, History, a central log action, Insights, and Settings in the bottom bar. Friend sharing remains available from Settings quick access instead of occupying the primary product-page footer.
  Date/Author: 2026-05-06 / Codex

## Outcomes & Retrospective

Implemented the product-page visual system across the app's primary surfaces. Home now uses a Today-first UV card, logged sunscreen row, sun exposure chart, hourly forecast strip, and product-page bottom navigation. Manual Log now exposes SPF presets and covered areas immediately, with area metadata persisted through the existing notes field instead of a SwiftData schema change. History, Settings, Automation, onboarding copy, and Watch glance UI were restyled around the same navy, amber, blue, and translucent-card system.

Local source verification passed with `just generate`, `just lint`, `just test-python`, `just test-unit`, focused UI reruns for the changed accessibility/manual-log paths, and the full 55-test UI simulator suite. Remote PR checks, merge, and the requested TestFlight release from `master` remain the final lifecycle steps.

## Context and Orientation

Sunclub is a SwiftUI iOS app under `app/Sunclub`. Shared design tokens live in `app/Sunclub/Sources/Shared/AppDesignSystem.swift`; iOS compatibility wrappers, app backgrounds, reusable cards, headers, logo, assets, and helper components live in `app/Sunclub/Sources/Shared/AppTheme.swift`. Screens live in `app/Sunclub/Sources/Views`, Home is `app/Sunclub/Sources/Views/TimelineHomeView.swift`, and the Home footer is `app/Sunclub/Sources/Views/Components/TimelineFooterBar.swift`.

The Watch app screen is `app/Sunclub/WatchApp/Sources/SunclubWatchHomeView.swift`. Widgets and Live Activity code live under `app/Sunclub/WidgetExtension/Sources`. The Watch extension compiles `AppDesignSystem.swift` but not all of `AppTheme.swift`, so cross-platform tokens must remain safe for watchOS.

The attached product page shows these product priorities: Today-first logging, a large UV index card, a clear logged sunscreen row, sun exposure/forecast context, bottom navigation, simple manual logging, a calendar history summary, Shortcuts automation, private iCloud history, support, docs, and Apple Watch/widget glance surfaces.

## Plan of Work

First, update `AppDesignSystem.swift` and `AppTheme.swift` to match the product page. Use deep navy primary text, softer secondary text, warm paper backgrounds, amber sun/UV accents, blue primary action fill, translucent white cards, tighter shadows, and component primitives for feature icons, information rows, hero metric cards, UV index cards, mini bar charts, hourly forecast strips, and bottom navigation items. Keep compatibility names such as `SunclubCard`, `SunLightHeader`, and `SunStatusCard` so existing screens can migrate incrementally.

Second, rebuild Home. Keep `TimelineHomeView` as the only Home screen, but make it read like the product page's phone mock: top Today/date header, large UV context card, logged/open sunscreen row, sun exposure mini chart, hourly forecast strip, week/history/streak summary, and a bottom bar with Today, History, central log action, Insights, and Settings. Preserve existing route behavior where it does not conflict with the product-page visual contract.

Third, apply the same system to the rest of the app. Manual Log should use form rows and area/product details that feel like the product page's logging mock. History should use segmented controls, calendar cards, and summary rows. Settings and Automation should use grouped rows with blue/amber feature icons. Onboarding, success, reapply, weekly report, scanner, skin report, year review, recovery, friends, achievements, Watch, and widgets should use the same palette, component shapes, and copy tone.

Fourth, update docs and tests that intentionally encode older design choices. Keep accessibility rules intact: no `minimumScaleFactor`, no fixed `lineLimit` for essential copy, no direct animations that ignore Reduce Motion, and no low-contrast text on accent fills.

Finally, run the repo's generation and verification commands, install/run the app in Simulator, capture screenshots for realistic device sizes, push a branch, open a PR, monitor GitHub checks, and merge only when required checks pass or an explicit external blocker remains.

## Concrete Steps

Run commands from `/Users/peyton/.codex/worktrees/5158/sunclub`.

1. Edit `app/Sunclub/Sources/Shared/AppDesignSystem.swift`.
2. Edit `app/Sunclub/Sources/Shared/AppTheme.swift`.
3. Edit `app/Sunclub/Sources/Views/TimelineHomeView.swift` and `app/Sunclub/Sources/Views/Components/TimelineFooterBar.swift`.
4. Edit the representative screen files under `app/Sunclub/Sources/Views` and shared manual-log/timeline components as needed.
5. Edit `app/Sunclub/WatchApp/Sources/SunclubWatchHomeView.swift` and widget presentation files where the product-page glance language applies.
6. Update `DESIGN.md`, `docs/product-page-app-redesign-execplan.md`, and tests that intentionally assert the old token constants.
7. Run `just generate`, targeted unit tests, lint, UI or build checks, and simulator screenshot inspection.
8. Push `codex/product-page-app-redesign`, open a PR, monitor checks, and merge after green.

## Validation and Acceptance

Acceptance is met when the app builds, relevant tests pass or environment-specific blockers are recorded exactly, and simulator screenshots show the Home, Manual Log, History, Settings/Automation, Watch, and widget surfaces using the same product-page language without clipped, overlapping, or unreadable content.

Preferred validation commands are:

    just generate
    SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 just test-unit
    just lint
    SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 just ci-build
    TEST_SIMULATOR_NAME='Sunclub Product Redesign iPhone 17 Pro' SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 just test-ui

If the local Xcode build service stalls, use a narrower build or simulator screenshot path, record the exact failure, and rely on GitHub Actions for the final required-check result.

## Idempotence and Recovery

The redesign is source-only and does not touch data stores or migrations. If generation fails, fix the source membership or Tuist manifest and rerun `just generate`. If UI tests fail because copy changed, update tests only where assertions are tied to presentation and not behavior. Do not stage the pre-existing `mise.lock` diff unless it is intentionally fixed as part of this branch.

## Artifacts and Notes

- Generated design concept used for implementation direction: `/Users/peyton/.codex/generated_images/019dff6e-8cba-7751-812e-8760ef7a226d/ig_0437477499ddd25f0169fbc26092988193b403d935f41ef4c7.png`.

## Interfaces and Dependencies

No new third-party dependencies are planned. The redesign should extend local SwiftUI components. New or updated reusable interfaces may include product-page variants of:

    AppText
    AppCard
    PrimaryButton
    SecondaryPillButton
    StatusBadge
    StatCard
    SunFeatureIcon
    SunInfoRow
    SunUVIndexCard
    SunMiniBarChart
    SunForecastStrip
    SunBottomNavigationBar
