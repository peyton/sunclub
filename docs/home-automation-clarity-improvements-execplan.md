# Home and Automation Clarity Improvements

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This plan follows the instructions in `~/.agents/PLANS.md`. It is self-contained so a contributor can continue from this file and the current working tree alone.

## Purpose / Big Picture

Sunclub already tracks sunscreen habits, supports automation, and protects user data. This improvement batch makes the common daily path easier to understand at a glance and makes existing automation capabilities easier to discover without adding dependencies or changing persisted data. After the change, a user can open Home and immediately see logged details, reminder context, reapply guidance, and UV source information; they can also open Automation and see clearer URL examples plus the Shortcut-only file actions that already exist.

## Progress

- [x] (2026-04-14 13:46Z) Invoked `claude -p` as requested; the non-bare commands stalled and the bare check reported the CLI is not logged in.
- [x] (2026-04-14 13:46Z) Audited `HomeView`, `AutomationView`, `AppState`, App Intents, and existing tests.
- [x] (2026-04-14 14:15Z) Added Home presentation metadata and visible metadata rows.
- [x] (2026-04-14 14:15Z) Improved the UV forecast card with source, generated time, numeric bars, and clearer accessibility.
- [x] (2026-04-14 14:15Z) Improved Automation catalog URL coverage and Shortcut-only action disclosure.
- [x] (2026-04-14 14:15Z) Added App Shortcut entries for report and streak card creation.
- [x] (2026-04-14 14:15Z) Updated docs and added regression tests.
- [x] (2026-04-14 14:18Z) Removed Tuist inspect post-actions from the generated app schemes by declaring explicit schemes in the Tuist manifest.
- [x] (2026-04-14 14:21Z) Ran focused validation commands and recorded outcomes.

## Surprises & Discoveries

- Observation: `claude --bare -p` cannot use the current machine login state.
  Evidence: The command returned `Not logged in · Please run /login`.
- Observation: The app already has App Intents for exporting backups, creating skin health reports, and creating streak cards, but the in-app Automation catalog lists them only as rows and does not clarify that they are Shortcut-only file actions.
  Evidence: `app/Sunclub/Sources/Intents/LogSunscreenIntent.swift` defines `ExportSunclubBackupIntent`, `CreateSkinHealthReportIntent`, and `CreateStreakCardIntent`; `AutomationView` URL examples cover only URL-deep-link actions.
- Observation: `just test-unit` initially stalled at an Xcode `SchemeScriptAction` after building because the generated shared scheme had Tuist inspect post-actions hardcoded to `/Users/peyton/.local/share/mise/installs/tuist/4.180.0/tuist`.
  Evidence: `app/Sunclub/Sunclub.xcodeproj/xcshareddata/xcschemes/Sunclub.xcscheme` contained `tuist inspect build` and `tuist inspect test`; the xcodebuild log stopped at `/bin/sh -c .../SchemeScriptAction-*.sh`.
- Observation: After explicit schemes removed those post-actions, `just test-unit` compiled the app and test bundle, then stalled in simulator launch and reported `Mach error -308` only after the run was intentionally terminated.
  Evidence: The log reached `CleanupCompileCache`; the later launch report showed `Failed to launch app with identifier: app.peyton.sunclub` and `NSMachErrorDomain Code=-308`.

## Decision Log

- Decision: Do not add or modify persisted SwiftData fields.
  Rationale: The requested improvement batch can be delivered through derived presentation state, SwiftUI rendering, docs, and tests, which avoids migration risk and preserves the data-preservation release gate.
  Date/Author: 2026-04-14 / Codex.
- Decision: Treat Claude Code output as unavailable and continue with repo-grounded judgment.
  Rationale: The user asked to invoke `claude -p`; the invocation happened, but the CLI was not usable in this environment. Blocking further would not improve the code.
  Date/Author: 2026-04-14 / Codex.
- Decision: Focus on improvements that reinforce existing product identity and automation posture instead of inventing unrelated features.
  Rationale: The codebase already has many large product features. Small clarity improvements are safer and more reviewable.
  Date/Author: 2026-04-14 / Codex.
- Decision: Declare explicit Tuist schemes for the production and development app targets.
  Rationale: The generated default app scheme used local absolute Tuist inspect post-actions, which made repo-local test commands fragile and violated the clean-checkout tooling rule. Explicit schemes keep the standard app schemes while omitting those post-actions.
  Date/Author: 2026-04-14 / Codex.

## Outcomes & Retrospective

Implemented a focused improvement batch with no new dependencies and no persisted model changes. Home now derives and renders compact metadata for logged state, SPF, notes, reminder/reapply context, streak risk, peak UV, and forecast source. The UV forecast card now shows source and update time, displays numeric UV values on bars, auto-expands elevated UV detail, and exposes richer accessibility text.

Automation now separates Shortcut-only file actions from URL examples, covers more existing URL actions, disables unsafe placeholder test links, and keeps row identity stable. Existing skin report and streak card intents are also exposed as App Shortcuts.

The Tuist manifest now declares explicit `Sunclub` and `SunclubDev` schemes so regenerated app schemes omit the local absolute Tuist inspect post-actions that stalled `just test-unit`.

## Context and Orientation

The iOS app lives in `app/Sunclub`. Home UI is in `app/Sunclub/Sources/Views/HomeView.swift`. Derived Home state comes from `app/Sunclub/Sources/Services/AppState.swift`. Automation UI is in `app/Sunclub/Sources/Views/AutomationView.swift`. App Intents and App Shortcuts live in `app/Sunclub/Sources/Intents/LogSunscreenIntent.swift`. Automation documentation lives in `docs/app-automation.md`. Unit tests live in `app/Sunclub/Tests/SunclubTests.swift` and `app/Sunclub/Tests/AutomationTests.swift`. Tuist scheme generation is configured in `app/Sunclub/Project.swift`.

An App Intent is an iOS system-facing action that can run from Shortcuts, Siri, Spotlight, widgets, or controls. A URL action is a custom `sunclub://...` deep link handled by Sunclub. An x-callback-url action is a URL action that can call back to another app with success or error details.

## Plan of Work

First, extend `HomeTodayCardPresentation` with small metadata rows. These rows are derived from existing records, settings, reminders, and UV forecast data. They should show logged time, SPF status, notes status, reapply window, main reminder time, streak context, peak UV, and forecast source where relevant.

Second, render those rows in `HomeView.todayCard` using compact, accessible rows. Update the UV forecast card so it shows source and generated time, includes numeric UV values in the bar chart, uses clearer button labels, and provides a richer accessibility label.

Third, improve `AutomationView` by adding URL examples for supported URL actions that are currently omitted, adding a Shortcut-only file actions section for backup/report/streak-card intents, and making automation row identity stable.

Fourth, add App Shortcut entries for the existing report and streak card intents so these file-producing actions are more discoverable in Shortcuts. Update `docs/app-automation.md` to mention the added discoverability and catalog coverage.

Fifth, add unit tests for the new derived Home presentation behavior and automation URL/action coverage. Run focused tests and lint/build commands as practical.

## Concrete Steps

Work from `/Users/peyton/.codex/worktrees/5dc0/sunclub`.

1. Edit `app/Sunclub/Sources/Services/AppState.swift` to add `HomeTodayMetadataRow`, metadata derivation helpers, and a testing setter for UV forecast if needed.
2. Edit `app/Sunclub/Sources/Views/HomeView.swift` to render metadata and UV details.
3. Edit `app/Sunclub/Sources/Views/AutomationView.swift` to add examples and Shortcut-only disclosure.
4. Edit `app/Sunclub/Sources/Intents/LogSunscreenIntent.swift` to add App Shortcut entries for existing file-producing intents.
5. Edit `docs/app-automation.md` and unit tests.
6. Run focused validation such as `just test-unit` if practical, or narrower xcodebuild test invocations if the full suite is too slow.

## Validation and Acceptance

Acceptance means:

- Home shows derived daily metadata without requiring a persisted schema change.
- UV forecast copy includes source and generated time and remains accessible.
- Automation catalog covers the existing URL action set more completely and clearly names Shortcut-only file actions.
- Shortcuts can surface report and streak-card creation through App Shortcuts.
- Unit tests prove the new Home metadata and automation catalog action coverage.
- Existing test commands still run from the repo root.

## Idempotence and Recovery

All changes are source, documentation, or tests. Re-running tests is safe. If a Swift compile error appears, fix the named file and rerun the same focused test command. No data migration, destructive command, signing mutation, or runtime dependency installation is part of this plan.

## Artifacts and Notes

Claude invocation evidence:

    claude --bare -p ...
    Not logged in · Please run /login

Validation evidence:

    just generate
    Success. Project generated.

    just web-check
    Static site validation passed for web.

    git diff --check
    No output.

    just test-unit
    The first run stalled at the generated Tuist inspect scheme post-action. After declaring explicit schemes, the command compiled the app and test bundle through `CleanupCompileCache`, then stalled in simulator launch and surfaced `Mach error -308` when terminated. No Swift compile diagnostics or XCTest assertion failures were observed before the simulator launch failure.

    bash scripts/tooling/build.sh --configuration Debug --destination 'generic/platform=iOS Simulator' --derived-data-path .DerivedData/build-verify --result-bundle-path .build/build-verify.xcresult --skip-share
    This non-launching Xcode build also became idle in Xcode 26 beta `SWBBuildService` before producing a result bundle and was terminated as an environment stall.

## Interfaces and Dependencies

No external dependencies are introduced. New Home metadata uses plain Swift structs in `AppState.swift`. SwiftUI rendering uses existing `AppPalette`, `SunMotion`, and card styling helpers. App Shortcut additions reuse existing App Intent types and do not add new intent actions.

Revision note: 2026-04-14 13:46Z. Created the plan after Claude Code was unavailable and after auditing the existing Home, Automation, and App Intents surfaces.

Revision note: 2026-04-14 14:21Z. Completed the implementation, documented the Tuist scheme fix, and recorded validation results including simulator/Xcode build-service stalls.
