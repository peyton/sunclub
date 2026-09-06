# Widget And Control Suite ExecPlan

This ExecPlan is the living record for Sunclub's full widget and Control Center surface. It replaces the earlier single-action widget plan. The sections `Progress`, `Decision Log`, and `Outcomes & Retrospective` should stay current as the suite evolves.

## Purpose / Big Picture

Sunclub's product loop is stronger when the user can see daily state before opening the app. The goal of this work is a low-text widget suite that makes today's status, streak momentum, weekly/monthly stats, and calendar history glanceable across every iPhone Home Screen and Lock Screen family, plus a small Control Center action set for the fastest common routes.

## Progress

- [x] (2026-04-02) Audited the existing widget, app routing, manual log flow, and test seams.
- [x] (2026-04-02) Switched the detached worktree onto local branch `codex/widget-suite` from `origin/master` instead of creating a no-op merge commit.
- [x] (2026-04-02) Added a shared widget-support layer with snapshot, store, builder, and widget routes compiled into both the app target and widget extension target.
- [x] (2026-04-02) Added an explicit app group for shared widget snapshot data without moving the live SwiftData store.
- [x] (2026-04-02) Updated app-side state mutations and foreground refresh paths to rewrite widget snapshots and reload widget timelines.
- [x] (2026-04-02) Reworked the widget extension into a multi-widget bundle covering Home Screen, Lock Screen, and Control Center surfaces.
- [x] (2026-04-02) Added unit coverage for snapshot rollover behavior and widget deep-link routes.
- [x] (2026-04-12) Reworked `Log Today` into an icon-led layout with compact copy and added medium, large, and extra-large Home Screen variants.
- [x] (2026-04-12) Added presentation unit coverage for every `Log Today` family and UI coverage for the logged-state widget update route.
- [x] (2026-04-12) Ran the unit, lint, and UI validation suites to completion.
- [x] (2026-04-24) Reworked the widget suite around at-a-glance status and trend value: `Today`, `Streak`, `Stats`, `History` gallery names; simpler stat hierarchy; Today reapply-due copy; and a large History flagship calendar.
- [x] (2026-04-24) Added `todaySPFLevel` to the app-group snapshot with legacy decode defaults and added presentation coverage for Today, History, current-week counts.
- [x] (2026-05-18) Split app-owned widget/control logging from user-run Shortcuts with non-discoverable widget intents and a `SunclubAutomationInvocation.widget` runtime path.
- [x] (2026-05-18) Made the Today widget tap contract explicit in presentation state: open days log in place, reapply-due days log reapply in place, setup opens summary, and logged days open edit.
- [x] (2026-05-18) Expanded Today widget button/link labels to the full rendered surface so iOS 26 Home Screen taps do not fall through to app navigation outside the visible content.
- [x] (2026-05-18) Reproduced the stuck Home Screen Today widget in Simulator and traced it to WidgetKit archive failures from 2400x2400 bitmap widget artwork.
- [x] (2026-05-18) Removed oversized bitmap backgrounds/motifs from the widget render tree and kept Home Screen AppIntent buttons on only the visible action affordance.
- [x] (2026-05-18) Verified Today small and medium Home Screen previews render real content in Simulator instead of the gray loading skeleton.
- [x] (2026-05-18) Uploaded a current widget contact sheet to ChatGPT image generation and implemented the compact status-chip redesign guidance across Today, Stats, and History widgets.
- [x] (2026-05-20) Made the whole interactive Today widget surface run the widget-only log or reapply intent, with nested action pills rendered as passive labels under that whole-surface button.
- [x] (2026-05-20) Removed the Today `accessoryInline` family because Apple's iOS 18 interactive-widget button support covers Home Screen families plus accessory circular and rectangular, not inline.
- [x] (2026-05-21) Simplified the Today widget to a single `Log Sunscreen` intent button that becomes a non-opening checkmark state after today's log exists.
- [ ] Manually verify all supported widget families and Control Center controls in Simulator.

## Decision Log

- Decision: Keep the live SwiftData store in the app sandbox and mirror only a compact snapshot into an app-group `UserDefaults` payload.
  Rationale: The widget suite needs read access to current streak/calendar state, but moving the live store into an app group would create unnecessary migration and integrity risk. A small mirrored snapshot keeps the persistence architecture stable while still letting widgets stay current.
  Date/Author: 2026-04-02 / Codex

- Decision: Use terse, status-first copy rules across widgets instead of explanatory sentences.
  Rationale: The user explicitly asked to reduce text. Small and accessory surfaces now favor numerals and state words such as `Logged`, `6d streak`, `5/7`, and `Today open`, while medium and large surfaces get at most one supporting line.
  Date/Author: 2026-04-02 / Codex

- Decision: Keep `Log Today` as the only in-place logging action. Logged-state widgets and the other widgets route into the app.
  Rationale: The app should keep one deterministic logging path. `Log Today` can stay fast when the day is open, while logged-state, summary, and history surfaces become status/navigation surfaces instead of duplicate write paths.
  Date/Author: 2026-04-02 / Codex

- Decision: Schedule timelines to refresh at the next local midnight.
  Rationale: Today's open/logged state and streak continuity can roll over without an app launch, so time-derived widget state should be recomputed at day boundaries.
  Date/Author: 2026-04-02 / Codex

- Decision: Use short public gallery/control labels while keeping widget kind strings, widget routes, and deep links stable.
  Rationale: Gallery labels now read `Today`, `Streak`, `Stats`, `History` without repeating `Sunclub`; internal identifiers remain stable for existing widgets and route handling.
  Date/Author: 2026-04-24 / Codex

- Decision: Add optional `todaySPFLevel` only to the widget snapshot JSON.
  Rationale: Today widgets should say `SPF 50 logged` only when the value is known for the current day. Legacy snapshot payloads decode this field as `nil`, so no SwiftData migration is needed.
  Date/Author: 2026-04-24 / Codex

- Decision: Make medium Today the default habit widget and large History the flagship trend widget.
  Rationale: Medium Today answers "Am I protected today?" with status, streak, this-week progress, and week dots. Large History leans into the product-specific calendar language with month title, grid, and week/streak/month summary row.
  Date/Author: 2026-04-24 / Codex

- Decision: Treat widget and Control Center buttons as app-owned widget invocations instead of user-run Shortcut invocations.
  Rationale: The user's widget should remain one tap even when they have disabled arbitrary Shortcut writes. The runtime still goes through `SunclubAutomationRuntime` and `SunclubHistoryService`, so revision history, default SPF/area reuse, widget snapshot refresh, and duplicate-day upsert behavior stay shared with the rest of automation.
  Date/Author: 2026-05-18 / Codex

- Decision: Put the widget tap behavior behind `SunclubLogTodayWidgetPresentation.tapAction`.
  Rationale: A pure presentation decision is unit-testable and avoids drift between visible action copy and the actual SwiftUI `Button` or `Link` wrapper. It also keeps stale snapshot data out of default resolution; the widget uses the snapshot only to choose which action to run, and the action reads current storage at execution time.
  Date/Author: 2026-05-18 / Codex

- Decision: Keep `Log Today` Home Screen widget artwork vector/procedural.
  Rationale: iOS 26 WidgetKit rejected the Today widget archive when the SwiftUI tree contained 2400x2400 bitmap texture and motif images, leaving the Home Screen on the gray loading skeleton. Procedural gradients, paths, circles, and SF Symbols keep the visual language without exceeding WidgetKit archive image limits.
  Date/Author: 2026-05-18 / Codex

- Decision: Wrap the whole interactive Today widget surface in `Button(intent:)`.
  Rationale: The requested one-click widget should log from any tap on the rendered Today surface, not only from the action pill. The prior archive failure was traced to oversized bitmap artwork, which is no longer in the widget tree. Nested action pills now render as passive labels when the whole surface owns the AppIntent, while setup and logged states still route into the app with `Link`.
  Date/Author: 2026-05-20 / Codex

- Decision: Do not ship `accessoryInline` for the Today widget.
  Rationale: On iOS 18, WidgetKit's documented interactive-button families include Home Screen families plus accessory circular and rectangular on iPhone and iPad. Inline accessory widgets are too constrained for the required in-place logging contract, so Today stays available only in families that can run the widget-only AppIntent.
  Date/Author: 2026-05-20 / Codex

- Decision: Keep the redesigned widget copy to one status chip, one primary value, one compact detail line, and one visible action where applicable.
  Rationale: The ChatGPT image-generation pass over the current widget contact sheet identified overflow from duplicate metadata, long status phrases, decorative space, and excessive padding. The implementation uses shorter titles such as `Log today`, `July`, and `4/7`, reduces widget padding, and gives accessory `Log today` / `Reapply` states in-place AppIntent actions instead of app-opening routes.
  Date/Author: 2026-05-18 / Codex

- Decision: Reduce the Today widget to one visible action and one completion state.
  Rationale: The requested widget should be a single `Log Sunscreen` button and should never open the app on tap. After the widget-only log intent writes today's record and refreshes snapshots, the Today widget renders only a checkmark.
  Date/Author: 2026-05-21 / Codex

## Context And Orientation

The Tuist target wiring lives in [app/Sunclub/Project.swift](/Users/peyton/.codex/worktrees/d7ea/sunclub/app/Sunclub/Project.swift). Shared widget snapshot and route logic lives in [app/Sunclub/Sources/WidgetSupport/SunclubWidgetSupport.swift](/Users/peyton/.codex/worktrees/d7ea/sunclub/app/Sunclub/Sources/WidgetSupport/SunclubWidgetSupport.swift). App state sync lives in [app/Sunclub/Sources/Services/AppState.swift](/Users/peyton/.codex/worktrees/d7ea/sunclub/app/Sunclub/Sources/Services/AppState.swift). Widget and control surfaces live in [app/Sunclub/WidgetExtension/Sources/SunclubWidgets.swift](/Users/peyton/.codex/worktrees/d7ea/sunclub/app/Sunclub/WidgetExtension/Sources/SunclubWidgets.swift). App routes and deep-link parsing live in [app/Sunclub/Sources/Shared/SunclubDeepLink.swift](/Users/peyton/.codex/worktrees/d7ea/sunclub/app/Sunclub/Sources/Shared/SunclubDeepLink.swift).

## Scope

Supported widget families:

- `Today`: `systemSmall`, `systemMedium`, `systemLarge`, `systemExtraLarge`, `accessoryCircular`, `accessoryRectangular`
- `Streak`: `systemSmall`, `systemMedium`, `accessoryCircular`, `accessoryRectangular`
- `Stats`: `systemMedium`, `systemLarge`, `accessoryInline`, `accessoryRectangular`
- `History`: `systemMedium`, `systemLarge`, `accessoryInline`, `accessoryRectangular`

Supported Control Center controls:

- `Today`
- `Stats`
- `History`

Out of scope:

- iPad-specific widget behavior beyond the shared `systemExtraLarge` layout
- Moving the main database into the app group
- New dedicated summary/history screens created only for widgets

## Plan Of Work

1. Keep widget-support types shared between the app and widget extension.
2. Persist a compact snapshot mirror into shared `UserDefaults` and refresh it whenever onboarding or records change.
3. Render Home Screen and Lock Screen layouts from that snapshot with low-text, state-forward designs.
4. Use non-discoverable widget intents for app-owned in-place logging, keep `LogSunscreenIntent` and `LogReapplyIntent` for user-run Shortcuts, and use route-based intents/deep links for navigation-only widget and control surfaces.
5. Verify snapshot math, route parsing, app routing, and repo-level build/test/lint flows.

## Validation And Acceptance

1. Every iPhone Home Screen and Lock Screen family listed above is exposed by the widget bundle.
2. `Today` logs in place from the whole rendered widget surface when the current day is still open.
3. When today is already logged, the Today widget shows only a checkmark and does not open Sunclub.
4. Reapply remains available through app and Shortcut surfaces, not through the Today widget.
5. Stats and History widgets derive current-day state from stored dates plus current time, not stale strings.
6. Control Center exposes `Today`, `Stats`, and `History`.
7. Unit tests cover snapshot rollover math, widget tap actions, runtime invocation permissions, and widget/control deep-link routes.
8. Repo validation commands pass from the repo root.

## Outcomes & Retrospective

- Outcome: Shared snapshot-backed widget suite implemented with Home Screen, Lock Screen, and Control Center coverage.
- Outcome: `Log Today` now uses an icon-led compact small layout, expands into metrics/history on larger Home Screen sizes, and keeps Lock Screen copy short enough for accessory families.
- Outcome: The 2026-04-24 polish pass made the public suite `Today`, `Streak`, `Stats`, `History`; Today now has open/protected/reapply-due states; Stats/Streak are one-stat-forward; and large History is the flagship calendar surface.
- Outcome: The 2026-05-18 widget action fix made Home Screen Today taps complete in place through widget-only intents, preserved shared automation runtime writes, and widened the tappable surface for iOS 26 widget hosts.
- Outcome: The 2026-05-18 stuck-widget fix removed the 2400x2400 bitmap artwork from the widget source and moved AppIntent buttons off the root Today widget surface.
- Outcome: The 2026-05-18 compact redesign reduces Today/Stats/History text density and padding, shortens History metric copy, and keeps Lock Screen open/reapply Today widgets as in-place widget actions instead of app launches.
- Outcome: The 2026-05-20 Today widget pass made the whole open/reapply widget surface run the widget-only AppIntent, kept setup/logged states as whole-surface app links, and stopped advertising the non-interactive inline Today family for iOS 18.
- Outcome: The 2026-05-21 Today widget simplification replaced status chips, metrics, edit links, and reapply UI with a single `Log Sunscreen` intent button and a non-opening checkmark state.
- Root cause evidence:
  - `.build/widget-verification/after-widget-gallery-placeholder.jpg` captured the Simulator widget gallery stuck on the gray loading skeleton.
  - `.build/widget-verification/before-image-too-large-log.txt` captured `WidgetArchiver.ArchivingError.imageTooLarge(size: (2400.0, 2400.0))` and `timelineReloadFailed` for Today small, medium, and large widget archives.
- Simulator verification for the stuck-widget fix:
  - `.build/widget-verification/after-widget-gallery-small-fixed.jpg` shows the Today small preview rendering real content.
  - `.build/widget-verification/after-widget-gallery-medium-fixed.jpg` shows the Today medium preview rendering real content.
  - `.build/widget-verification/after-home-small-medium-widget-fixed.jpg` shows small and medium Today widgets added to the Home Screen without the gray loading skeleton.
  - `.build/widget-verification/after-widget-success-log.txt` captured successful Today small and medium archive requests after removing bitmap artwork.
  - `.build/widget-verification/after-widget-open-route.jpg` captured the setup/route state opening the app from the visible widget affordance.
- Verification recorded during the 2026-04-24 polish pass:
  - `just generate` passed
  - `just test-unit` passed: 273 tests, 0 failures
  - `just lint` passed with non-serious existing SwiftLint warnings
  - `just ci-build` passed
- Verification for the 2026-05-18 widget action fix:
  - `git diff --check` passed
  - `just test-python` passed: 196 tests
  - `just generate` passed
  - `SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 TEST_XCODEBUILD_MAX_ATTEMPTS=1 just test-unit` passed: 327 tests
  - `just lint` passed with non-serious existing SwiftLint warnings
  - `SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 just ci-build` passed; the repo wrapper treated the known post-success Tuist trace trap as success after `Build Succeeded`
  - `MISE_CONFIG_DIR=.config/mise MISE_TRUSTED_CONFIG_PATHS=$PWD MISE_YES=1 mise --locked exec -- just --version` passed with `just 1.51.0`
  - `SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 just run` built, installed, and launched the dev app on an iOS 26.5 simulator; the unsigned local dev install reached the expected iCloud entitlement guard, so real widget/app-group behavior remains a signed-build CI/TestFlight verification item
- Follow-up:
  - Manually add each widget/control in Simulator and confirm the visible state and tap behavior match the supported-family matrix above. WidgetKit Simulator was attempted on 2026-04-24 against the freshly built extension, but it did not create an inspectable window in this desktop session.
