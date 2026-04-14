# Accessibility Scorecard ExecPlan

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Sunclub should be able to truthfully indicate full support for every applicable App Store Accessibility Nutrition Label on iPhone and iPad. A user should be able to complete the app's common tasks with VoiceOver, Voice Control, Larger Text, Dark Interface, Differentiate Without Color Alone, Sufficient Contrast, and Reduced Motion. Captions and Audio Descriptions are not currently applicable unless Sunclub adds time-based audio or video content.

This pass audits the SwiftUI app surfaces under `app/`, fixes concrete deficits, adds coverage for future regressions, and records project rules in `AGENTS.md` so future app changes preserve the scorecard.

## Progress

- [x] (2026-04-13 01:36Z) Reviewed Apple's current Accessibility Nutrition Labels overview and criteria pages.
- [x] (2026-04-13 01:36Z) Created this ExecPlan before starting accessibility source edits.
- [x] (2026-04-13 01:58Z) Audited common app tasks and identified deficits in SwiftUI views, theme components, and UI tests.
- [x] (2026-04-13 03:05Z) Remediated deficits for semantic labels, Voice Control names, Dynamic Type, non-color cues, contrast, and reduced motion.
- [x] (2026-04-13 03:16Z) Added tests that exercise the accessibility scorecard criteria where repo automation can prove them.
- [x] (2026-04-13 03:21Z) Updated `AGENTS.md` with mandatory future-change accessibility rules for every app change under `app/`.
- [x] (2026-04-13 03:22Z) Ran validation and recorded the outcomes.

## Source Criteria

Apple's App Store Connect documentation says Accessibility Nutrition Labels help users understand whether an app supports features such as VoiceOver and Larger Text for common tasks. The criteria relevant to Sunclub are:

- VoiceOver: anything a sighted user can tap, click, drag, or see as important should be perceivable and operable with VoiceOver.
- Voice Control: visible names, labels, and hints must let users navigate and interact by voice.
- Larger Text: text should scale to 200% or more for common tasks without clipping, truncating important meaning, or blocking actions.
- Dark Interface: common tasks should stay dark in Dark Mode without bright flashes or large bright areas.
- Differentiate Without Color Alone: status, selection, and values must not rely only on color.
- Sufficient Contrast: foreground text, icons, controls, states, and surfaces need sufficient contrast in light and dark modes, including with higher-contrast settings.
- Reduced Motion: problematic motion triggers should be removed, disabled, or replaced when Reduce Motion is enabled.
- Captions and Audio Descriptions: applicable only when the app presents time-based audio or video content.

## Surprises & Discoveries

- Several icon-only or decorative visual elements were either unlabeled or exposed as noise to assistive technology. The pass added explicit labels, values, hints, identifiers, selected traits, and decorative hiding where needed.
- Selection and status were often readable visually by color, but not always by shape, text, or VoiceOver value. SPF choices, reapply intervals, UV bars, monthly consistency cells, progress rows, and status cards now expose non-color cues.
- A few reusable tokens assumed light-mode foregrounds such as white-on-accent. The shared palette now provides adaptive colors and `onAccent` so colored fills remain legible in light mode, dark mode, and high contrast.
- Motion was scattered across screen-local animations. Shared `SunMotion` helpers now keep standard animation behavior while collapsing or suppressing problematic motion when Reduce Motion is enabled.
- Dynamic Type regressions were mostly caused by truncation helpers, fixed-width grids, and inline dense controls. The pass removed important line limits and makes dense grids switch to single-column layouts at accessibility text sizes.

## Decision Log

- Decision: Treat Captions and Audio Descriptions as not applicable for this scorecard unless the app adds media playback to common tasks.
  Rationale: Sunclub currently has no app video or audio playback surface in `app/Sunclub/Sources/Views`, so there is no time-based media to caption or describe.
  Date/Author: 2026-04-13 / Codex
- Decision: Prefer test-only environment overrides over production accessibility toggles.
  Rationale: Production should follow iOS system accessibility settings. UI tests need deterministic coverage for Larger Text, Reduce Motion, Differentiate Without Color, Increase Contrast, and Dark Interface without changing simulator global state.
  Date/Author: 2026-04-13 / Codex
- Decision: Add regression tests that scan source for banned accessibility patterns.
  Rationale: Some scorecard criteria are broad and visual, but the most common local regressions are fixed text truncation, hard-coded light foregrounds, and animations that bypass Reduce Motion. Source scans catch those cheaply before UI tests run.
  Date/Author: 2026-04-13 / Codex

## Outcomes & Retrospective

Completed. Sunclub now has app-wide adaptive dark mode colors, deterministic accessibility UI-test overrides, and a scorecard regression suite for the applicable App Store Accessibility Nutrition Label criteria.

Changed areas:

- Shared theme colors, control sizes, foreground tokens, decorative accessibility behavior, and Reduce Motion-aware animation helpers in `app/Sunclub/Sources/Shared/AppTheme.swift`.
- Test-only runtime overrides for Dark Interface, Larger Text, Reduced Motion, Differentiate Without Color Alone, and Sufficient Contrast in `app/Sunclub/Sources/Shared/RuntimeEnvironment.swift` and `app/Sunclub/Sources/SunclubApp.swift`.
- Screen-level fixes across home, history, settings, friends, achievements, reports, scanner, onboarding, recovery, and verification success surfaces.
- Unit tests for contrast and scorecard invariants in `app/Sunclub/Tests`.
- UI tests for dark-mode core screens and an accessibility scorecard route covering representative common tasks in `app/Sunclub/UITests/SunclubUITests.swift`.
- Future-change rules in `AGENTS.md`.

Captions and Audio Descriptions remain not applicable because Sunclub does not present time-based audio or video content. `AGENTS.md` now makes those criteria mandatory if media playback is introduced later.

## Context and Orientation

Sunclub is an iOS SwiftUI app under `app/Sunclub`. Common visual components and color tokens live in `app/Sunclub/Sources/Shared/AppTheme.swift`. Root app wiring and test launch configuration live in `app/Sunclub/Sources/SunclubApp.swift` and `app/Sunclub/Sources/Shared/RuntimeEnvironment.swift`. Screens live in `app/Sunclub/Sources/Views`. Unit tests live in `app/Sunclub/Tests`, and UI tests live in `app/Sunclub/UITests/SunclubUITests.swift`.

## Plan of Work

First, inspect common tasks and UI code for fixed-size text, unlabeled icon buttons, decorative images exposed to assistive technology, color-only status cues, hard-coded contrast risks, and motion that should honor Reduce Motion.

Second, add shared accessibility primitives where they reduce duplication. Keep changes source-only, SwiftUI-native, and aligned with existing design tokens. Do not introduce third-party dependencies or persisted model changes.

Third, add deterministic UI-test overrides for applicable system accessibility settings and exercise representative common tasks with dark mode, high contrast, grayscale-friendly cues, reduced motion, and accessibility-sized text. Add unit tests for scorecard invariants that can be proven without a simulator.

Fourth, update `AGENTS.md` so future app changes under `app/` must preserve this scorecard and include the relevant accessibility verification.

Finally, run `just generate`, focused tests, full unit/UI tests, `just lint`, and `just ci-build` as practical. Record exact outcomes here.

## Concrete Steps

Work from `/Users/peyton/.codex/worktrees/1744/sunclub`.

1. Audit SwiftUI views, shared components, and UI tests with `rg` and targeted file reads.
2. Patch shared theme/runtime helpers and the screen-level deficits found by the audit.
3. Add unit and UI tests covering scorecard support.
4. Update `AGENTS.md` with the perfect accessibility scorecard rules for app changes.
5. Run validation commands and update this plan with outcomes.

## Validation and Acceptance

Run these commands from `/Users/peyton/.codex/worktrees/1744/sunclub`:

    just generate
    just test-unit
    just test-ui
    just lint
    just ci-build

Acceptance means the app's common tasks can be completed with VoiceOver and Voice Control semantics, accessibility text sizes do not block core actions, dark and high-contrast modes remain legible, status information is not color-only, problematic motion is suppressed when requested, and the repo records this as a future-change requirement.

## Idempotence and Recovery

The changes should be source-only. If a simulator setting or UI test run becomes unstable, prefer test-only app environment overrides and isolated simulator names rather than mutating global simulator state. If a remediation causes layout regressions, keep the semantic accessibility behavior and refine the layout locally.

## Artifacts and Notes

Validation completed from `/Users/peyton/.codex/worktrees/1744/sunclub`:

    just generate
    just test-unit
    TEST_SIMULATOR_NAME='Sunclub 1744 Accessibility iPhone 17 Pro' just test-ui
    just lint
    just ci-build
    git diff --check

Results:

- Unit tests: 175 tests, 0 failures.
- UI tests: 51 tests, 0 failures.
- Lint: passed with the repo's existing non-serious SwiftLint warnings still present.
- Release CI build: succeeded.
- Whitespace diff check: passed.

## Interfaces and Dependencies

No third-party dependencies are expected. New app-facing test hooks should live behind `RuntimeEnvironment.isUITesting`. Shared visual or accessibility helpers should live in `AppTheme.swift` or adjacent shared files only when they are used by multiple screens.

Revision note: 2026-04-13 01:36Z. Created the scorecard plan after reading Apple's current App Store accessibility criteria.
Revision note: 2026-04-13 03:22Z. Recorded completed audit, remediation, tests, and validation outcomes.
