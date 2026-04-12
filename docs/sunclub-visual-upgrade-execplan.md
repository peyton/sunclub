# Sunclub Visual Upgrade ExecPlan

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

The repository instruction references `~/.agent/PLANS.md`, but that file is not present on this machine. The compatible plan guide is `/Users/peyton/.agents/PLANS.md`, and this document follows that format.

## Purpose / Big Picture

Sunclub already helps people log sunscreen quickly, but its current interface depends mostly on simple cards and SF Symbols. This pass makes the app feel more distinctive and polished by adding a project-local visual asset pack, richer sunscreen-specific illustrations, warmer textured surfaces, improved streak and success moments, and more intentional widgets and share cards. A user should notice the upgrade immediately on onboarding, Home, Manual Log, Product Scanner, Weekly Summary, History, Achievements, Friends, Skin Health Report, widgets, and generated share cards, without any change to their data or logging flow.

## Progress

- [x] (2026-04-12 05:36Z) Inspected the current asset catalog, main SwiftUI screens, widget code, share-card renderer, Just recipes, and project layout.
- [x] (2026-04-12 05:36Z) Confirmed the requested work does not require a SwiftData schema change because it is visual-only and does not add persisted fields.
- [x] (2026-04-12 05:36Z) Added this ExecPlan before changing app source or assets.
- [x] (2026-04-12 06:04Z) Generated deterministic project-local visual assets and added them to `app/Sunclub/Resources/Assets.xcassets`.
- [x] (2026-04-12 06:15Z) Added a central asset lookup layer in `app/Sunclub/Sources/Shared/AppTheme.swift`.
- [x] (2026-04-12 06:34Z) Applied visual upgrades to app screens while preserving existing navigation and accessibility identifiers.
- [x] (2026-04-12 06:43Z) Applied visual upgrades to widgets, Live Activity, and generated share artifacts.
- [x] (2026-04-12 06:52Z) Ran generation and verification commands and recorded outcomes here.

## Surprises & Discoveries

- Observation: `app/Sunclub/Resources/Assets.xcassets` currently contains only `AccentColor` and the app icon variants.
  Evidence: `find app/Sunclub/Resources/Assets.xcassets -maxdepth 3 -type f` lists only those entries.
- Observation: The built-in bitmap image-generation tool referenced by the local `imagegen` skill is not available in this session.
  Evidence: the available tools include shell, Xcode, Hugging Face, Cloudflare, Vercel, and app connectors, but no `image_gen` namespace. To keep the work self-contained, this implementation will generate deterministic raster/vector-like assets locally with repo scripts and system frameworks instead of depending on remote image generation.

## Decision Log

- Decision: Implement the asset pack with deterministic project-local image generation rather than remote AI-generated files.
  Rationale: The user asked to implement now, the repo forbids undeclared runtime dependencies, and deterministic generated assets can be reproduced from a clean checkout without requiring an external model or API token.
  Date/Author: 2026-04-12 / Codex
- Decision: Keep the visual pass free of persisted model changes.
  Rationale: The requested improvements are UI, widget, and share-rendering changes. Avoiding persistence changes prevents unnecessary migration risk.
  Date/Author: 2026-04-12 / Codex

## Outcomes & Retrospective

Sunclub now has a branded visual asset pack, central asset enum, extended color ramp, textured background system, glass card treatment, animated success/streak motifs, richer onboarding artwork, premium scanner framing, upgraded lower-frequency screen art, widget texture backgrounds, Live Activity polish, and share-card artwork that matches the in-app badge language.

The implementation stayed visual-only. No SwiftData schema, public API, or habit-loop behavior changed.

Verification passed with `just ci`, including project generation, lint, Python tests, unit tests, UI tests, Release build, and Tuist preview upload. A prior full UI-test run on a custom simulator exited with an xcodebuild 65 runner crash even though the individual test list mostly passed; the reported crashed test was rerun directly and passed before the final default `just ci` passed all UI tests.

## Context and Orientation

Sunclub is an iOS app under `app/Sunclub`. The app uses SwiftUI views in `app/Sunclub/Sources/Views`, shared styling in `app/Sunclub/Sources/Shared/AppTheme.swift`, WidgetKit code in `app/Sunclub/WidgetExtension/Sources`, and generated share-card drawing in `app/Sunclub/Sources/Services/SunclubShareArtifactService.swift`. Assets live in `app/Sunclub/Resources/Assets.xcassets` and are included by the Tuist project through the `Resources/**` glob in `app/Sunclub/Project.swift`.

The term "asset catalog" means the Xcode folder with `.imageset` and `.colorset` directories that are compiled into the app bundle. The term "decorative image" means an image that improves the look of a screen but should be hidden from VoiceOver because it does not add information beyond nearby text.

## Plan of Work

First, add a small repo-local asset generator under `scripts/` and expose it through `just` so a clean checkout can recreate the new image assets. The generator will create the requested texture, hero, illustration, motif, badge, widget, and share-card image sets using AppKit/CoreGraphics so there are no new dependencies.

Second, extend `AppTheme.swift` with a central `SunclubVisualAsset` enum, asset-backed SwiftUI helpers, a richer palette, shared glass card styling, animated motif views, and screen-level decorative components. This keeps raw asset names out of feature views.

Third, update the core SwiftUI screens. Welcome and notification onboarding get custom hero illustrations. Home gets a richer streak hero, UV treatment, and visual feature tiles. Manual Log and Product Scanner get SPF bottle/scanner art and a premium scan frame. Weekly Summary, History, Achievements, Friends, and Skin Health Report get stronger illustrated empty or intro states and refined card treatments. Existing user-facing copy, routes, and accessibility identifiers should remain stable unless the copy is directly improved.

Fourth, update widgets, Live Activity, and generated share cards. Widget backgrounds should use the new texture assets. Live Activity should use the expanded UV color ramp and a compact protected-state motif. Share-card rendering should draw a more intentional Sunclub backdrop and badge treatments so exported images match the app.

Finally, run `just generate`, `just test-unit`, `just test-ui`, and `just ci` as practical. If a simulator or signing issue blocks a command, record the exact failure and run the nearest narrower command that still validates the edited surface.

## Concrete Steps

Work from `/Users/peyton/.codex/worktrees/7cc7/sunclub`.

1. Create or update the asset-generation script under `scripts/` and expose it through `just visual-assets`.
2. Run `just visual-assets` and verify that `app/Sunclub/Resources/Assets.xcassets` contains the requested image sets.
3. Edit `app/Sunclub/Sources/Shared/AppTheme.swift` to add the central asset enum, palette additions, glass card helpers, and reusable motif/illustration views.
4. Edit the SwiftUI screens in `app/Sunclub/Sources/Views` for the visual upgrades while preserving existing navigation behavior.
5. Edit `app/Sunclub/WidgetExtension/Sources/SunclubWidgets.swift` and `app/Sunclub/WidgetExtension/Sources/SunclubLiveActivityWidget.swift` for widget and Live Activity polish.
6. Edit `app/Sunclub/Sources/Services/SunclubShareArtifactService.swift` so share artifacts use the new visual language.
7. Run verification commands and update this document.

## Validation and Acceptance

Run these commands from `/Users/peyton/.codex/worktrees/7cc7/sunclub`:

    just visual-assets
    just generate
    just test-unit
    just test-ui
    just ci

Acceptance is visual and functional. Onboarding should show custom sunscreen-themed hero artwork. Home should show a richer textured background, improved streak hero, more expressive UV card, and polished feature cards. Manual Log and Product Scanner should show sunscreen/scanner-specific illustrations. Weekly Summary, History, Achievements, Friends, Skin Health Report, widgets, Live Activity, and share-card exports should no longer feel like generic symbol-only surfaces. Tests should pass, or any environment-specific blocker should be documented with the exact failing command.

## Idempotence and Recovery

The asset generator must be safe to rerun and should overwrite only the generated asset sets it owns. No user data or SwiftData stores are touched. If generation produces an invalid asset, delete the affected `.imageset` directory and rerun `just visual-assets`. If project generation fails, run `just generate` again after fixing the malformed asset or Swift compile error.

## Artifacts and Notes

- `just visual-assets`: passed; regenerated the owned image sets in the app asset catalog.
- `just generate`: passed.
- `just test-unit`: passed; 144 tests, 0 failures.
- `TEST_SIMULATOR_NAME="Sunclub Visual Test iPhone 17 Pro" just test-ui`: individual UI tests completed, but xcodebuild exited 65 after a runner crash report for `testHighUVReapplyReminderNoteUsesStrongerCopy`.
- Direct rerun of `SunclubUITests/testHighUVReapplyReminderNoteUsesStrongerCopy`: passed; 1 test, 0 failures.
- `TEST_SIMULATOR_NAME="Sunclub Visual CI Test iPhone 17 Pro" just ci`: failed early because the tooling config test expects the repo-default simulator name and the environment override intentionally changed it.
- `just ci`: passed; lint reported only existing warning-level SwiftLint findings, Python tests passed with 52 tests, unit tests passed with 144 tests, UI tests passed with 40 tests, and the Release build succeeded.

## Interfaces and Dependencies

No third-party dependency is added. The asset generator uses macOS AppKit/CoreGraphics through Swift, which is available on the developer machine used to build this iOS project. The main new app-facing interface is:

    enum SunclubVisualAsset: String, CaseIterable {
        case backgroundSunGrainLight = "BackgroundSunGrainLight"
        ...
    }

SwiftUI views should access images through this enum or helper views, not by scattering raw string literals.

Revision note: 2026-04-12 05:36Z. Created the plan after auditing the current app assets and UI surfaces so the large visual pass is restartable from the repository alone.

Revision note: 2026-04-12 06:52Z. Completed implementation and recorded verification. The final acceptance command was `just ci`.
