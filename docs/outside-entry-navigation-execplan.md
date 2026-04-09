# Outside Entry Navigation And Branding ExecPlan

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds. This repository does not check in `PLANS.md`, so this document follows the shared execution-plan guidance from `/Users/peyton/.agents/PLANS.md`.

## Purpose / Big Picture

Sunclub already supports outside-app entry from widgets, App Intents, and notifications, but the current route handling has a user-visible failure: several destinations render a custom back button that can become inert when the screen is opened programmatically. After this change, a user can tap a widget, tap a reminder, or launch the app from a Home Screen quick action and still return cleanly to Home with the visible back affordance. The widget and control surfaces should also advertise Sunclub clearly instead of looking like generic streak or stats widgets.

The change matters because outside-app entry is only valuable if the user can safely orient themselves once the app opens. A user should be able to prove the change works by launching the affected routes, tapping the custom back button, and seeing Home reappear every time. They should also be able to long-press the app icon and see a `Log Today` quick action.

## Progress

- [x] (2026-04-09 10:26Z) Audited the current routing stack, custom-header back actions, widget route handoff, notification route handoff, App Intent entry points, and existing test coverage.
- [x] (2026-04-09 10:26Z) Added this ExecPlan before code edits so the navigation bug, quick-action choice, and verification steps live in one tracked document.
- [x] (2026-04-09 10:39Z) Replaced fragile `dismiss()`-based back behavior on route-backed screens with deterministic router-driven popping, while preserving sheet dismissal for the history editor when it is presented modally.
- [x] (2026-04-09 10:41Z) Added a Home Screen quick action for `Log Today` and wired it into the same external-route handoff path used by widgets, App Intents, and notification entry.
- [x] (2026-04-09 10:42Z) Updated widget and control labels so Sunclub branding is explicit across gallery metadata and compact rendered copy where space allows.
- [x] (2026-04-09 10:50Z) Added regression tests for route-backed back buttons and the quick-action route, then ran the relevant repo validation commands successfully.

## Surprises & Discoveries

- Observation: The affected screens do not use the system navigation bar back button. They hide the navigation bar and render `SunLightHeader`, whose back affordance is wired manually per screen.
  Evidence: `ManualLogView.swift`, `WeeklyReportView.swift`, `HistoryView.swift`, `SettingsView.swift`, `RecoveryView.swift`, and `ReapplyCheckInView.swift` all call `SunLightHeader(... onBack: { dismiss() })` while also applying `.toolbar(.hidden, for: .navigationBar)`.
- Observation: Outside-app route pushes are intentionally single-depth today. `AppRouter.open(_:)` replaces the whole path with `[route]` instead of appending.
  Evidence: `app/Sunclub/Sources/Shared/AppRoute.swift` sets `path = [route]` for all non-root destinations.
- Observation: Widget route intents already persist pending navigation in shared storage, but that storage is typed as `SunclubWidgetRoute`, which is too narrow for notifications and Home Screen quick actions.
  Evidence: `SunclubWidgetSnapshotStore` stores `SunclubWidgetRoute.rawValue` under `sunclub.widget.pending-route`, and `OpenSunclubRouteIntent` writes to that store.
- Observation: Running `just ci` through a PTY in Codex made the simulator runner appear hung even though the underlying tests passed when invoked through the repo recipes non-interactively.
  Evidence: `just test-unit`, `just test-ui`, `just lint`, `just test-python`, and `just ci-build` all completed successfully, while PTY-backed `just ci` attempts stalled around the simulator run after a stale prior UI test process and after attaching via an interactive session.

## Decision Log

- Decision: Fix the broken back button at the router boundary instead of trying to rescue `dismiss()` in every programmatic entry case.
  Rationale: The app already owns navigation state explicitly in `AppRouter.path`. Popping that state is deterministic, testable, and independent of how SwiftUI chooses to populate the environment dismiss action.
  Date/Author: 2026-04-09 / Codex
- Decision: Reuse one shared pending-route store for widgets, notifications, and the new Home Screen quick action.
  Rationale: Outside-app entry should funnel through one handoff seam so cold-launch, warm-launch, and extension-driven routes do not each invent their own pending-state mechanism.
  Date/Author: 2026-04-09 / Codex
- Decision: Make the app icon quick action open the manual log screen instead of silently writing a log entry.
  Rationale: A Home Screen quick action should be fast but still allow SPF and note entry. Sunclub already has an inline log App Intent for one-tap external logging, so the app icon action can prioritize clarity and editability.
  Date/Author: 2026-04-09 / Codex

## Outcomes & Retrospective

Implemented the route fix at the navigation seam instead of layering one-off back-button workarounds on each view. `AppRouter` now has an explicit one-step pop operation, route-backed custom headers call it directly, and the shared back button exposes a stable accessibility identifier for UI coverage. The history editor keeps a dual-mode close path so sheet presentation still dismisses modally while route presentation pops back to Home.

Unified outside-app entry around shared pending `AppRoute` persistence. Widgets, notifications, App Intent route launches, and the new Home Screen quick action all now feed the same handoff store, and `SunclubApp` consumes that route consistently on foreground entry. This removed the old gap where notifications could select a route before a live router closure was attached.

Added a static `Log Today` Home Screen quick action and refreshed widget/control branding so gallery labels and compact content explicitly identify Sunclub instead of looking generic. Regression coverage now checks router popping, pending-route persistence, quick-action mapping, and UI back-navigation from widget- and notification-style entry paths.

Verification completed with passing results for:

- `just generate`
- `just lint`
- `just test-python`
- `just test-unit`
- `just test-ui`
- `just ci-build`

## Context and Orientation

The app entry point is `app/Sunclub/Sources/SunclubApp.swift`. It owns the shared `AppState`, the `AppRouter`, UI-test launch-argument handling, and the foreground refresh path that currently consumes pending widget routes.

Navigation state lives in `app/Sunclub/Sources/Shared/AppRoute.swift`. An `AppRoute` is a named destination such as `manualLog`, `weeklySummary`, or `history`. `AppRouter.path` is the SwiftUI `NavigationStack` path. Because `open(_:)` currently replaces the path instead of appending, every pushed route is effectively a one-screen layer above Home.

Shared widget snapshot and route handoff code lives in `app/Sunclub/Sources/WidgetSupport/SunclubWidgetSupport.swift`. The widget extension and the app both compile this file, so it is the safest place for a shared pending-route store.

The outside-app route surfaces live in three places. Widget URLs and route parsing live in `app/Sunclub/Sources/Shared/SunclubDeepLink.swift` and `app/Sunclub/Sources/Services/SunclubDeepLinkHandler.swift`. Notification routing lives in `app/Sunclub/Sources/Services/NotificationManager.swift`. App Intents and widget/control intents live in `app/Sunclub/Sources/Intents/LogSunscreenIntent.swift`. The widget and control UI copy lives in `app/Sunclub/WidgetExtension/Sources/SunclubWidgets.swift`.

The screens affected by the broken back button are route-backed screens with a custom header. Those screens include `ManualLogView`, `WeeklyReportView`, `HistoryView`, `SettingsView`, `RecoveryView`, and `ReapplyCheckInView`. They hide the system navigation bar and draw their own `SunLightHeader`, so the custom back button must explicitly mutate `AppRouter.path` if the screen was opened as a route.

## Plan of Work

The first milestone is route hygiene. Add an explicit pop operation to `AppRouter`, use it from every route-backed custom header, and give the shared header back button a stable accessibility identifier so UI tests can tap it directly. For the one editor screen that sometimes appears as a sheet and sometimes as a route, keep `dismiss()` for sheet presentation and use the router only for route-backed invocation.

The second milestone is outside-app entry unification. Broaden the shared pending-route store from widget-only routes to full `AppRoute` values. Update widget intents to persist `AppRoute` instead of `SunclubWidgetRoute`, set the notification manager’s default route handler to persist routes when no live router is attached yet, and add a Home Screen quick-action handler that writes the same pending route before the app scene becomes active.

The third milestone is user-facing branding and regression coverage. Add a static `Log Today` Home Screen quick action to `app/Sunclub/Info.plist`, wire App Delegate and Scene Delegate quick-action callbacks to the shared route handoff, and update widget/control display names, descriptions, and compact copy so `Sunclub` is visible where space allows. Then extend unit and UI tests to cover route-backed back navigation, widget-driven route launch, and quick-action launch.

## Concrete Steps

From the repository root, implement and verify in this order:

1. Update route state and custom-header usage in:

       app/Sunclub/Sources/Shared/AppRoute.swift
       app/Sunclub/Sources/Shared/AppTheme.swift
       app/Sunclub/Sources/Views/ManualLogView.swift
       app/Sunclub/Sources/Views/WeeklyReportView.swift
       app/Sunclub/Sources/Views/HistoryView.swift
       app/Sunclub/Sources/Views/SettingsView.swift
       app/Sunclub/Sources/Views/RecoveryView.swift
       app/Sunclub/Sources/Views/ReapplyCheckInView.swift

2. Unify pending external-route storage and quick-action handling in:

       app/Sunclub/Sources/WidgetSupport/SunclubWidgetSupport.swift
       app/Sunclub/Sources/Services/NotificationManager.swift
       app/Sunclub/Sources/Services/SunclubHomeScreenQuickAction.swift
       app/Sunclub/Sources/SunclubApp.swift
       app/Sunclub/Info.plist

3. Update widget and control branding copy in:

       app/Sunclub/WidgetExtension/Sources/SunclubWidgets.swift

4. Extend regression coverage in:

       app/Sunclub/Tests/SunclubTests.swift
       app/Sunclub/Tests/SunclubWidgetTests.swift
       app/Sunclub/UITests/SunclubUITests.swift

5. Run the relevant repo commands from the repository root and record the actual results here.

## Validation and Acceptance

The change is complete when all of the following are true:

1. A route-backed screen opened from a widget, notification, or quick action returns to Home when the visible custom back button is tapped.
2. Cold-launch and warm-launch outside-app routes can still reach the intended destination.
3. Long-pressing the app icon exposes a `Log Today` quick action that opens Sunclub into the manual log flow.
4. Widget and control names in the gallery explicitly mention Sunclub, and the compact rendered copy includes Sunclub branding where there is enough room to show it without breaking layout.
5. Unit tests and UI tests cover the new route-popping and quick-action behavior, and the relevant repo commands pass from the repository root.

## Idempotence and Recovery

The router and pending-route changes are safe to rerun because they only mutate in-memory navigation state or overwrite a single pending-route value in shared defaults. The new Home Screen quick action is additive in `Info.plist`; if it needs to be rolled back, removing that dictionary entry and the handler code returns the app to the prior behavior without touching persisted user data. If a route handoff is triggered before the app is ready, the shared pending-route store provides a safe retry path because the next foreground refresh will consume the stored route once.

## Artifacts and Notes

Expected changed files:

    docs/outside-entry-navigation-execplan.md
    app/Sunclub/Sources/Shared/AppRoute.swift
    app/Sunclub/Sources/Shared/AppTheme.swift
    app/Sunclub/Sources/WidgetSupport/SunclubWidgetSupport.swift
    app/Sunclub/Sources/Services/NotificationManager.swift
    app/Sunclub/Sources/Services/SunclubHomeScreenQuickAction.swift
    app/Sunclub/Sources/SunclubApp.swift
    app/Sunclub/Info.plist
    app/Sunclub/WidgetExtension/Sources/SunclubWidgets.swift
    app/Sunclub/Tests/SunclubTests.swift
    app/Sunclub/Tests/SunclubWidgetTests.swift
    app/Sunclub/UITests/SunclubUITests.swift

Verification summary:

- `just generate` regenerated the checked-in workspace/project so the new quick-action service source file was included in the Xcode graph.
- `just lint` passed. Existing SwiftLint warnings remained warnings only; no new lint failures were introduced.
- `just test-python` passed with 40 tests.
- `just test-unit` passed with 88 tests.
- `just test-ui` passed with 32 tests, including `testWidgetManualLogRouteBackButtonReturnsHome`, `testWeeklySummaryBackButtonReturnsHome`, and `testLogTodayQuickActionOpensManualLogAndReturnsHome`.
- `just ci-build` passed with `** BUILD SUCCEEDED **` for the release iOS build.

## Interfaces and Dependencies

At completion, the following interfaces or equivalent responsibilities must exist:

- `AppRouter` must expose a deterministic one-step back operation for route-backed screens.
- `SunLightHeader` must expose a stable accessibility identifier for its back button so UI tests can tap it.
- `SunclubWidgetSnapshotStore` or an equivalent shared handoff store must persist pending `AppRoute` values across widget, notification, and quick-action entry.
- `NotificationManager` must preserve notification-selected routes even when no live router closure is attached yet.
- A Home Screen quick-action handler must map the `Log Today` quick action to `AppRoute.manualLog`.

Revision note: 2026-04-09 10:26Z. Created this ExecPlan after auditing the navigation bug, custom-header usage, widget route handoff, notification route handling, and the current lack of Home Screen quick actions.
