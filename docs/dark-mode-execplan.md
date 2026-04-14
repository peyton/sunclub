# Dark Mode ExecPlan and Audit

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

The repository instruction references `~/.agent/PLANS.md`, but that file is not present on this machine. The compatible plan guide is `/Users/peyton/.agents/PLANS.md`, and this document follows that format.

## Purpose / Big Picture

Sunclub currently presents every app screen on a bright sunscreen-themed canvas. After this change, users who run iOS in Dark Appearance should get a deliberate warm night palette with readable text, visible card boundaries, usable controls, and the same navigation and logging flows. The work is visual-only: no persisted SwiftData model changes are needed.

## Progress

- [x] (2026-04-13 00:56Z) Inspected the shared theme, root app shell, main SwiftUI screens, UI test harness, unit test target, and existing visual-upgrade plan.
- [x] (2026-04-13 00:56Z) Confirmed the requested work does not require a SwiftData schema bump because no persisted fields or model relationships change.
- [x] (2026-04-13 00:56Z) Added this ExecPlan before changing app source.
- [x] (2026-04-13 01:05Z) Added adaptive colors, card surfaces, and a UI-test-only dark appearance hook.
- [x] (2026-04-13 01:10Z) Replaced bright white card/control fills on Home, Settings, History, Manual Log, Achievements, Friends, Recovery, Weekly Summary, Product Scanner, and Skin Health Report with semantic surfaces.
- [x] (2026-04-13 01:13Z) Added unit coverage for dark palette contrast and UI coverage for key dark-mode flows.
- [x] (2026-04-13 01:26Z) Ran generation, unit, UI, lint, and build validation and recorded outcomes here.

## Surprises & Discoveries

- Observation: The app already has dark visual assets and a `SunDarkBackdrop`, but all app screens use `SunLightScreen`, and `SunLightScreen` always installs the light backdrop.
  Evidence: `rg "SunDarkScreen|SunLightScreen" app/Sunclub/Sources` shows no screen uses `SunDarkScreen`, while all major screens instantiate `SunLightScreen`.
- Observation: Most screen text already goes through `AppPalette.ink` and `AppPalette.softInk`, so a central adaptive palette can fix most contrast without rewriting every view.
  Evidence: `rg "foregroundStyle\\(AppPalette\\.(ink|softInk)" app/Sunclub/Sources/Views` returns hits across Home, Settings, History, Manual Log, Achievements, Friends, Recovery, Weekly Summary, Product Scanner, and Skin Health Report.
- Observation: The default UI-test simulator was shared with another worktree, causing CoreSimulator launch interruptions during a full UI run.
  Evidence: The first `just test-ui` attempt retried and then hit simulator connection errors while another `xcodebuild` process was using the same default simulator. Rerunning with `TEST_SIMULATOR_NAME='Sunclub 1744 Dark UI iPhone 17 Pro'` isolated this worktree and passed all UI tests.

## Decision Log

- Decision: Implement dark mode through semantic theme primitives instead of screen-specific color-scheme branches.
  Rationale: Sunclub's screens already share `AppPalette`, `SunLightScreen`, `SunStatusCard`, `SunSecondaryButtonStyle`, and `sunGlassCard`. Making those primitives adaptive keeps the change cohesive and reduces the chance of one screen drifting from another.
  Date/Author: 2026-04-13 / Codex
- Decision: Add a `UITEST_FORCE_DARK_MODE` launch argument for UI tests only.
  Rationale: The app should follow the system appearance in production. UI tests need deterministic dark-mode coverage without depending on simulator global settings.
  Date/Author: 2026-04-13 / Codex

## Outcomes & Retrospective

Completed. Sunclub now follows the system dark appearance through adaptive `AppPalette` tokens and the existing dark backdrop. The implementation keeps production behavior system-driven and adds only UI-test launch arguments for deterministic light or dark appearance overrides.

The usability audit found the main risk was hard-coded translucent white surfaces that stayed bright in dark appearance. Those fills and strokes now route through semantic card, control, editor, and stroke colors. Text contrast is covered by unit tests that resolve colors in light and dark trait collections, while UI tests launch representative dark routes and assert important controls remain available.

No SwiftData schema bump or migration is needed because the change is visual-only.

## Context and Orientation

Sunclub is an iOS SwiftUI app under `app/Sunclub`. Shared colors, backgrounds, cards, buttons, decorative image helpers, and reusable visual components live in `app/Sunclub/Sources/Shared/AppTheme.swift`. The root SwiftUI wiring lives in `app/Sunclub/Sources/SunclubApp.swift` and `app/Sunclub/Sources/Shared/RootView.swift`. Screens live in `app/Sunclub/Sources/Views`. Unit tests live in `app/Sunclub/Tests`, and UI tests live in `app/Sunclub/UITests/SunclubUITests.swift`.

Dark Appearance means the iOS system color scheme where user-interface elements should use dark backgrounds and light foreground text. A semantic surface means a named color such as `AppPalette.cardFill` that resolves differently in light and dark mode, instead of a hard-coded `Color.white.opacity(...)` fill.

## Plan of Work

First, update `AppTheme.swift` so existing color names such as `ink`, `softInk`, `warmGlow`, `muted`, and `streakBackground` resolve appropriately in both light and dark appearance. Add semantic colors for card fills, control fills, strokes, and editor fields. Update `SunBackdrop` to choose the existing dark backdrop automatically when the environment color scheme is dark.

Second, update common components in `AppTheme.swift`, including secondary buttons, status cards, asset hero cards, locked badge medallions, and `sunGlassCard`, to use the semantic surfaces. Then update screen-local card helpers and remaining bright controls in the main screens so cards do not stay white in dark mode.

Third, add a small test hook in `RuntimeEnvironment` and `SunclubApp` so UI tests can force `.preferredColorScheme(.dark)` only when `UITEST_FORCE_DARK_MODE` is present. Add a unit test that resolves palette colors under a dark trait collection and verifies body and secondary text contrast against card and canvas surfaces. Add a UI test that launches Home in dark mode, opens several representative screens, and verifies important controls remain present.

Finally, run `just generate`, `just test-unit`, `just test-ui`, and `just ci-build` as practical. If simulator availability blocks UI verification, record the exact failure and run the nearest narrower command that still proves the new coverage compiles and runs.

## Concrete Steps

Work from `/Users/peyton/.codex/worktrees/1744/sunclub`.

1. Edit `app/Sunclub/Sources/Shared/AppTheme.swift` to add adaptive `UIColor`-backed SwiftUI colors and semantic surface tokens.
2. Edit `app/Sunclub/Sources/Shared/RuntimeEnvironment.swift` and `app/Sunclub/Sources/SunclubApp.swift` to wire the test-only dark appearance launch argument.
3. Edit the SwiftUI screens in `app/Sunclub/Sources/Views` and `app/Sunclub/Sources/Shared/SunManualLogFields.swift` to replace hard-coded white or black card/control surfaces with the new semantic surfaces.
4. Add dark-mode palette unit tests under `app/Sunclub/Tests`.
5. Add a dark-mode UI flow test under `app/Sunclub/UITests/SunclubUITests.swift`.
6. Run validation commands and update this plan with the outcomes.

## Validation and Acceptance

Run these commands from `/Users/peyton/.codex/worktrees/1744/sunclub`:

    just generate
    just test-unit
    just test-ui
    just ci-build

Acceptance is functional and visual. In dark appearance, Home, Settings, Manual Log, History, Weekly Summary, Achievements, Friends, Product Scanner, Recovery, and Skin Health Report should use the dark textured background, readable light foreground text, and dark card/control surfaces. The new unit test should prove color contrast for core palette roles. The new UI test should exercise representative dark-mode navigation and fail if key controls disappear.

## Idempotence and Recovery

The changes are source-only and can be applied repeatedly through normal Git workflows. No generated assets, user data, SwiftData stores, or external services are touched. If a dark surface looks wrong on one screen, update the semantic token or the screen-local fill that uses it, rerun the focused test, and then rerun the broader suite.

## Artifacts and Notes

- `just generate`: passed.
- `just test-unit`: passed, 171 tests, 0 failures.
- `TEST_SIMULATOR_NAME='Sunclub 1744 Dark UI iPhone 17 Pro' just test-ui`: passed, 50 tests, 0 failures. This isolated simulator was used after the default simulator was busy with another worktree.
- `just lint`: passed with the repo's existing non-fatal SwiftLint warnings.
- `just ci-build`: passed Release iOS build for `SunclubDev`.

## Interfaces and Dependencies

No third-party dependency is added. `AppTheme.swift` may import UIKit to construct dynamic `Color` values from `UIColor` because this target is an iOS app. The public app-facing surface at the end of the change should include:

    enum AppPalette {
        static let ink: Color
        static let softInk: Color
        static let cardFill: Color
        static let elevatedCardFill: Color
        static let controlFill: Color
        static let editorFill: Color
        static let cardStroke: Color
        static let hairlineStroke: Color
    }

The UI test hook should be:

    RuntimeEnvironment.preferredColorSchemeOverride

It returns `.dark` only for UI tests launched with `UITEST_FORCE_DARK_MODE`, `.light` only for UI tests launched with `UITEST_FORCE_LIGHT_MODE`, and `nil` otherwise.

Revision note: 2026-04-13 00:56Z. Created the plan after auditing shared theme usage and identifying the central adaptive-color path.

Revision note: 2026-04-13 01:26Z. Recorded the completed dark-mode implementation and validation outcomes.
