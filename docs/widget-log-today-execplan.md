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
- [x] (2026-04-24) Reworked the widget suite around at-a-glance status and trend value: `Today`, `Streak`, `Stats`, `History`, and `Buddies` gallery names; simpler stat hierarchy; Today reapply-due copy; and a large History flagship calendar.
- [x] (2026-04-24) Added `todaySPFLevel` to the app-group snapshot with legacy decode defaults and added presentation coverage for Today, History, current-week counts, and Buddies empty/active states.
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
  Rationale: Gallery labels now read `Today`, `Streak`, `Stats`, `History`, and `Buddies` without repeating `Sunclub`; internal identifiers remain stable for existing widgets and route handling.
  Date/Author: 2026-04-24 / Codex

- Decision: Add optional `todaySPFLevel` only to the widget snapshot JSON.
  Rationale: Today widgets should say `SPF 50 logged` only when the value is known for the current day. Legacy snapshot payloads decode this field as `nil`, so no SwiftData migration is needed.
  Date/Author: 2026-04-24 / Codex

- Decision: Make medium Today the default habit widget and large History the flagship trend widget.
  Rationale: Medium Today answers "Am I protected today?" with status, streak, this-week progress, and week dots. Large History leans into the product-specific calendar language with month title, grid, and week/streak/month summary row.
  Date/Author: 2026-04-24 / Codex

## Context And Orientation

The Tuist target wiring lives in [app/Sunclub/Project.swift](/Users/peyton/.codex/worktrees/d7ea/sunclub/app/Sunclub/Project.swift). Shared widget snapshot and route logic lives in [app/Sunclub/Sources/WidgetSupport/SunclubWidgetSupport.swift](/Users/peyton/.codex/worktrees/d7ea/sunclub/app/Sunclub/Sources/WidgetSupport/SunclubWidgetSupport.swift). App state sync lives in [app/Sunclub/Sources/Services/AppState.swift](/Users/peyton/.codex/worktrees/d7ea/sunclub/app/Sunclub/Sources/Services/AppState.swift). Widget and control surfaces live in [app/Sunclub/WidgetExtension/Sources/SunclubWidgets.swift](/Users/peyton/.codex/worktrees/d7ea/sunclub/app/Sunclub/WidgetExtension/Sources/SunclubWidgets.swift). App routes and deep-link parsing live in [app/Sunclub/Sources/Shared/SunclubDeepLink.swift](/Users/peyton/.codex/worktrees/d7ea/sunclub/app/Sunclub/Sources/Shared/SunclubDeepLink.swift).

## Scope

Supported widget families:

- `Today`: `systemSmall`, `systemMedium`, `systemLarge`, `systemExtraLarge`, `accessoryInline`, `accessoryCircular`, `accessoryRectangular`
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
4. Use `LogSunscreenIntent` for in-place logging and route-based intents/deep links for navigation-only widget and control surfaces.
5. Verify snapshot math, route parsing, app routing, and repo-level build/test/lint flows.

## Validation And Acceptance

1. Every iPhone Home Screen and Lock Screen family listed above is exposed by the widget bundle.
2. `Today` logs in place only when the current day is still open.
3. When today is already logged, the Today widget shows useful completion/streak state and routes into the app instead of re-logging.
4. Stats and History widgets derive current-day state from stored dates plus current time, not stale strings.
5. Control Center exposes `Today`, `Stats`, and `History`.
6. Unit tests cover snapshot rollover math and new widget/control deep-link routes.
7. Repo validation commands pass from the repo root.

## Outcomes & Retrospective

- Outcome: Shared snapshot-backed widget suite implemented with Home Screen, Lock Screen, and Control Center coverage.
- Outcome: `Log Today` now uses an icon-led compact small layout, expands into metrics/history on larger Home Screen sizes, and keeps Lock Screen copy short enough for accessory families.
- Outcome: The 2026-04-24 polish pass made the public suite `Today`, `Streak`, `Stats`, `History`, and `Buddies`; Today now has open/protected/reapply-due states; Stats/Streak are one-stat-forward; and large History is the flagship calendar surface.
- Verification:
  - `just generate` passed
  - `just test-unit` passed: 273 tests, 0 failures
  - `just lint` passed with non-serious existing SwiftLint warnings
  - `just ci-build` passed
- Follow-up:
  - Manually add each widget/control in Simulator and confirm the visible state and tap behavior match the supported-family matrix above. WidgetKit Simulator was attempted on 2026-04-24 against the freshly built extension, but it did not create an inspectable window in this desktop session.
