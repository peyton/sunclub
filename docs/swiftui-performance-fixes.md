# SwiftUI Performance Fixes

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document follows the ExecPlan requirements in `/Users/peyton/.agents/PLANS.md`.

## Purpose / Big Picture

Sunclub's main app screens should stay responsive when users open history-heavy screens, adjust report ranges, browse achievements, expand settings, or scan a large sunscreen photo. This change fixes five code-reviewed SwiftUI performance findings by moving expensive scanner work away from the main actor and by computing view presentation data once per render instead of repeatedly from broad app state.

The behavior is internal but observable: large photo scans should not block interaction while image preparation and Vision OCR run, and record-heavy screens should do less repeated analytics work during the same body pass. A developer can verify the change by running the normal iOS unit tests and a simulator build from the repository root.

## Progress

- [x] (2026-04-14T13:04:41Z) Read the SwiftUI performance audit skill and plan requirements.
- [x] (2026-04-14T13:04:41Z) Confirmed the working tree was clean before edits.
- [x] (2026-04-14T13:11:55Z) Implemented scanner background image preparation and OCR.
- [x] (2026-04-14T13:11:55Z) Refactored Skin Health Report, Achievements, History, and Settings to avoid repeated derived work.
- [x] (2026-04-14T13:11:55Z) Ran targeted verification and recorded results.

## Surprises & Discoveries

- Observation: `SunclubProductScannerService.scan(image:)` is declared `async` but performs `VNImageRequestHandler.perform` synchronously inside the function.
  Evidence: `app/Sunclub/Sources/Services/SunclubProductScannerService.swift` lines 38-52 create a Vision request and call `handler.perform([request])` with no suspension point before the heavy work.

## Decision Log

- Decision: Use screen-local presentation structs for the view derivation fixes rather than adding persistent caches to `AppState`.
  Rationale: The findings are about repeated work inside one SwiftUI body pass. Local presentation values remove duplicate scans and sorts without introducing invalidation lifecycle bugs or stale shared cache state.
  Date/Author: 2026-04-14 / Codex

- Decision: Keep the scanner preview as a prepared `UIImage`, but produce it in a detached user-initiated task.
  Rationale: SwiftUI still needs a `UIImage` to render the selected preview, but decoding, resizing, and Vision work do not need to run on the main actor.
  Date/Author: 2026-04-14 / Codex

## Outcomes & Retrospective

All five findings were addressed with source-local changes. Product scanning now prepares the imported image and runs Vision OCR from detached user-initiated work, while publishing only state updates back to SwiftUI. The report, achievements, history, and settings screens now build one presentation or derived value per body pass and pass it into child builders.

`just test-unit` passed with 215 tests and 0 failures.

## Context and Orientation

The SwiftUI screens live in `app/Sunclub/Sources/Views/`. Shared view chrome and design tokens live in `app/Sunclub/Sources/Shared/`. `AppState`, in `app/Sunclub/Sources/Services/AppState.swift`, is a main-actor observable object that exposes loaded records, settings, achievements, and derived presentation values to the views.

The scanner screen is `app/Sunclub/Sources/Views/ProductScannerView.swift`. It currently receives photo data or camera images, creates a `UIImage`, resizes it, then calls `SunclubProductScannerService.scan(image:)`. `SunclubProductScannerService` lives in `app/Sunclub/Sources/Services/SunclubProductScannerService.swift` and uses Vision text recognition.

The Skin Health Report screen is `app/Sunclub/Sources/Views/SkinHealthReportView.swift`. It calls `appState.skinHealthReportSummary(for:)`, which delegates to `SunclubGrowthAnalytics.reportSummary` in `app/Sunclub/Sources/Services/SunclubGrowthAnalytics.swift`.

The Achievements screen is `app/Sunclub/Sources/Views/AchievementsView.swift`. It reads `appState.achievements` and `appState.seasonalChallenges`, which are computed arrays derived from the complete record history and growth settings.

The History screen is `app/Sunclub/Sources/Views/HistoryView.swift`. It renders a calendar grid and selected-day detail from records, current streak days, monthly insights, and date status calculations.

The Settings screen is `app/Sunclub/Sources/Views/SettingsView.swift`. Its reminder coaching section reads `appState.reminderCoachingSuggestions`, which analyzes recent records and reminder settings.

## Plan of Work

First, add scanner preparation helpers to `SunclubProductScannerService`. The helpers should support data-backed photo picker images using ImageIO thumbnail creation and camera-backed images using the existing renderer resize path. Then change `ProductScannerView` to call those helpers from a detached task and update SwiftUI state only after the prepared preview and scan result are available.

Second, update `SkinHealthReportView` so `body` computes one summary for the current interval and passes it to cards. The cards should not read the `summary` computed property repeatedly.

Third, update `AchievementsView` with an `AchievementsPresentation` value containing sorted achievements, sorted challenges, count text, and next-badge detail. The view should build the presentation once and pass it down.

Fourth, update `HistoryView` with a `HistoryPresentation` value containing normalized record dates, record sets, current streak days, month days, and month stats. Calendar grid, selected-day detail, stats, and footer should use that value instead of repeatedly asking `AppState` to rebuild the same sets.

Fifth, update `SettingsView` to store `appState.reminderCoachingSuggestions` in one local value before checking and iterating it.

## Concrete Steps

Run all commands from `/Users/peyton/.codex/worktrees/1077/sunclub`.

Edit these files:

- `app/Sunclub/Sources/Services/SunclubProductScannerService.swift`
- `app/Sunclub/Sources/Views/ProductScannerView.swift`
- `app/Sunclub/Sources/Views/SkinHealthReportView.swift`
- `app/Sunclub/Sources/Views/AchievementsView.swift`
- `app/Sunclub/Sources/Views/HistoryView.swift`
- `app/Sunclub/Sources/Views/SettingsView.swift`

After edits, run:

    just test-unit

If that is too slow or blocked by local simulator state, run the closest compile check available through the repo's standard iOS tooling and record the reason.

## Validation and Acceptance

Acceptance is met when the code compiles and unit tests pass. The scanner fix is accepted when `ProductScannerView` no longer performs photo decode, resize, or Vision OCR directly in the main-actor path. The derived-data fixes are accepted when each affected body pass computes its report, achievement list, calendar month data, or coaching suggestions once and passes the value into child builders.

For deeper performance validation outside this coding pass, profile these interactions in Instruments: import a large photo in Product Scanner, adjust the Skin Health date range, open Achievements with many records, and select days or change months in History.

## Idempotence and Recovery

The edits are source-only and can be reapplied safely from a clean checkout. If a verification command fails because of a local simulator or Xcode issue, leave the source changes intact, record the failure, and run the narrower command that gets closest to compile coverage.

## Artifacts and Notes

- `just test-unit` passed on 2026-04-14 with 215 tests and 0 failures.
- Test result bundle: `.build/test-unit.xcresult`.

## Interfaces and Dependencies

No new external dependencies are allowed. Use existing Apple frameworks already present in the project: UIKit, SwiftUI, Vision, and ImageIO. The scanner service should expose small static helper functions so the view can prepare images without knowing ImageIO details.
