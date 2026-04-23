# Timeline View Polish And Smooth Scrolling

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document follows the ExecPlan requirements in `/Users/peyton/.agents/PLANS.md`.

## Purpose / Big Picture

Sunclub's timeline is the main daily surface. After this change, a user can scroll the day strip smoothly, see the selected day expand like Apple's Cycle Tracking day markers, follow a sun-to-day pointer instead of a black selected-day bubble, and read a single day detail section whose title matches the selected day. Future days show `UV Forecast`; today and past days show `Log` and combine forecast context with log highlights in one section.

The behavior can be seen by launching `SunclubDev`, completing onboarding, and scrolling the horizontal timeline strip. The selected chip should grow without shifting the layout, the black weekday bubble should be gone, and selecting yesterday/today/tomorrow should switch the section title correctly.

## Progress

- [x] (2026-04-23T20:42:13Z) Captured the current timeline screenshot and inspected the Apple Cycle Tracking reference.
- [x] (2026-04-23T20:42:13Z) Reviewed `TimelineHomeView`, `SunDayStrip`, `TimelineLogSection`, and `TimelineHighlightsSection`.
- [x] (2026-04-23T20:42:13Z) Identified repeated AppState-derived work in the timeline body and broad environment reads in child sections.
- [x] (2026-04-23T20:51:00Z) Refactored timeline presentation data so the body computes day-strip sets, selected summary, forecast, and primary action once per render.
- [x] (2026-04-23T20:54:00Z) Redesigned the day strip selection treatment and removed the black selected weekday bubble.
- [x] (2026-04-23T20:50:00Z) Combined log, highlights, and forecast content for today/past while preserving future forecast behavior.
- [x] (2026-04-23T20:50:00Z) Updated UI tests for the new section title rules.
- [x] (2026-04-23T20:54:00Z) Built, relaunched, and captured screenshots on the review simulator.

## Surprises & Discoveries

- Observation: `TimelineHomeView` creates `Set(appState.recordedDays)` and `Set(appState.currentStreakDays)` directly in the body while also reading several computed AppState presentations.
  Evidence: `TimelineHomeView` passes these expressions directly into `SunDayStrip`, and `AppState.recordedDays`, `currentStreakDays`, `daysWithExtras`, and `dailyDetailsForTimeline` are computed from the record collection.

- Observation: The current selected-day marker is a black capsule plus triangle in `SelectedDayPointer`.
  Evidence: `SunDayStrip.swift` renders `SelectedDayPointer(letter:)` only when `state.isSelected`.

- Observation: The current timeline screenshot shows `April 18` with a black selected weekday bubble and the section title `UV Forecast` even though April 18 is not a future date.
  Evidence: Simulator screenshot `/var/folders/fd/s0n4flj93kbczt_202g4l_wc0000gn/T/screenshot_optimized_ab422b71-cb0d-4813-8cc7-6fbe78ffa779.jpg`.

## Decision Log

- Decision: Keep the timeline implementation in SwiftUI and use smaller value-type presentation structs rather than adding persistent caches to `AppState`.
  Rationale: The issue is most visible during view interaction. Computing one local presentation per render reduces duplicate work without introducing cache invalidation bugs in shared app state.
  Date/Author: 2026-04-23 / Codex

- Decision: Treat the selected day as the centered strip item, and draw the pointer treatment inside the strip column rather than building cross-view geometry.
  Rationale: `SunDayStrip` already keeps the selected day centered with `scrollPosition(anchor: .center)`, so a centered local line visually connects to the sun icon without adding preference-key geometry or scroll offset tracking.
  Date/Author: 2026-04-23 / Codex

## Outcomes & Retrospective

Completed. `TimelineHomeView` now builds one main-actor presentation snapshot per render and passes precomputed timeline data into the strip and log section. `SunDayStrip` receives the visible days, keeps fixed column sizing, enlarges the selected chip, and uses a warm pointer line instead of the old black selected weekday bubble. `TimelineLogSection` now owns the combined day context: future dates show `UV Forecast`, while today and past dates show `Log` with forecast rows, day-part status, and the streak highlight in one section.

Build verification passed with the simulator build command in this plan. The review simulator was relaunched with `SunclubDev`, and the final screenshot shows `Today, April 23`, an enlarged selected chip, a pointer line behind the selected weekday initial, and the `Log` section title with integrated UV rows.

## Context and Orientation

The timeline home screen is `app/Sunclub/Sources/Views/TimelineHomeView.swift`. It owns the header, selected date headline, `SunDayStrip`, day detail sections, and bottom action bar. Shared visual tokens live in `app/Sunclub/Sources/Shared/AppTheme.swift`.

The horizontal date selector is `app/Sunclub/Sources/Shared/SunDayStrip.swift`. It renders a horizontally scrolling row of dates, centers the selected day, and currently uses `SelectedDayPointer` to draw the black selected weekday marker. The word "chip" in this plan means the circular or capsule day marker below each weekday letter.

The current day detail rows are in `app/Sunclub/Sources/Views/Components/TimelineLogSection.swift`. The separate highlights cards are in `app/Sunclub/Sources/Views/Components/TimelineHighlightsSection.swift`. `AppState`, in `app/Sunclub/Sources/Services/AppState.swift`, computes record days, streak days, daily details, UV forecast days, and selected-day summaries.

## Plan of Work

First, introduce a small `TimelineHomePresentation` value in `TimelineHomeView.swift`. It will hold the selected-day summary, recorded day set, streak day set, extras day set, per-day details, elevated UV days, current streak, longest streak, UV forecast, weather attribution, current primary action, and CTA labels. The view will build this value once and pass it to child views.

Second, update `SunDayStrip.swift` so it receives a precomputed visible day range and no longer builds the range on every body pass. Replace `SelectedDayPointer` with a warm sun-colored pointer line behind the selected weekday letter. Enlarge the selected day chip using fixed column sizing so the scroll layout does not jump.

Third, replace the separate timeline log/highlights rendering in `TimelineHomeView` with one `TimelineLogSection` call. `TimelineLogSection` will show `UV Forecast` only for future days. For today and past days it will show `Log`, the existing forecast rows, the day-part log highlights, and the streak highlight in one vertical group.

Fourth, update UI tests around timeline section titles. Today should assert `Log`; future should assert `UV Forecast`.

## Concrete Steps

Run commands from `/Users/peyton/.codex/worktrees/2dc9/sunclub`.

Edit:

- `app/Sunclub/Sources/Views/TimelineHomeView.swift`
- `app/Sunclub/Sources/Shared/SunDayStrip.swift`
- `app/Sunclub/Sources/Views/Components/TimelineLogSection.swift`
- `app/Sunclub/UITests/SunclubUITests.swift`

Build with:

    SUNCLUB_FLAVOR=dev SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 SUNCLUB_TUIST_SHARE=0 bash scripts/tooling/build.sh --configuration Debug --destination 'id=61FACDF7-C039-408B-AC7A-9B4EDA48306E' --derived-data-path '/Users/peyton/.codex/worktrees/2dc9/sunclub/.DerivedData/run' --result-bundle-path '/Users/peyton/.codex/worktrees/2dc9/sunclub/.build/run.xcresult' --skip-generate --skip-share

Relaunch with:

    xcrun simctl install 61FACDF7-C039-408B-AC7A-9B4EDA48306E .DerivedData/run/Build/Products/Debug-iphonesimulator/SunclubDev.app
    xcrun simctl launch 61FACDF7-C039-408B-AC7A-9B4EDA48306E app.peyton.sunclub.dev

## Validation and Acceptance

Acceptance is met when the simulator build succeeds, the review simulator shows the updated timeline, the selected chip enlarges when scrolling/selecting days, the black selected weekday bubble is gone, and non-future days show `Log` instead of `UV Forecast`. A future day still shows `UV Forecast` and the `Back to Today` action.

The targeted UI test expectations should align with these title rules. If the full UI test suite is too slow for the interactive loop, at minimum build and capture screenshots for today and a future date.

## Idempotence and Recovery

All edits are source-only. The build command can be repeated. The simulator install command overwrites the existing dev app on the target simulator. If a build fails, keep the source changes, read the first compiler error, fix it, and rerun the same build command.

## Artifacts and Notes

- Current timeline screenshot before this change: `/var/folders/fd/s0n4flj93kbczt_202g4l_wc0000gn/T/screenshot_optimized_ab422b71-cb0d-4813-8cc7-6fbe78ffa779.jpg`.
- Final timeline screenshot after this change: `/tmp/sunclub-timeline-polish-after-4.png`.

## Interfaces and Dependencies

No external dependencies are introduced. The implementation uses existing SwiftUI views, `AppState` data, `TimelineDayLogSummary`, `SunclubUVForecast`, `SunclubWeatherAttribution`, and existing palette/type tokens.
