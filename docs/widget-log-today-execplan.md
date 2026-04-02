# Widget Log Today ExecPlan

This ExecPlan is the working record for adding a Home Screen and Lock Screen widget that gives Sunclub a one-tap `Log Today` entrypoint. The sections `Progress`, `Decision Log`, and `Outcomes & Retrospective` will be updated as implementation and verification land.

## Purpose / Big Picture

Sunclub already has a low-friction manual flow inside the app, but the product can get even closer to its "one obvious action" rule by exposing that action before the user even opens Home. This change adds a widget extension with a single tappable `Log Today` action that opens Sunclub, records today immediately, and lands on the existing success state instead of introducing another surface or alternate logging flow.

## Progress

- [x] (2026-04-02) Audited the current Tuist project, app routing, manual logging flow, and unit/UI test seams.
- [x] (2026-04-02) Added this ExecPlan before implementation so the widget work has a tracked design and verification record.
- [ ] Add a shared deep-link action model that both the app and widget extension can use.
- [ ] Add a WidgetKit extension target in Tuist with Home Screen and Lock Screen families.
- [ ] Route the widget action into the existing app-side manual success path.
- [ ] Add unit coverage for deep-link parsing/handling and UI coverage for the widget-triggered app flow.
- [ ] Regenerate the Tuist workspace and run the relevant validation commands from the repo root.

## Decision Log

- Decision: Implement the widget action as a deep link that opens Sunclub and immediately records today, rather than an in-widget background write to the SwiftData store.
  Rationale: The user asked for a one-tap widget action, not a background persistence architecture change. Reusing the existing in-app success path is the smallest coherent solution, preserves reminder behavior, avoids store-sharing and migration risk, and is much easier to verify with the repo's current UI-test setup.
  Date/Author: 2026-04-02 / Codex

## Context and Orientation

The app project lives in `app/Sunclub/Project.swift`. App entry and launch handling live in `app/Sunclub/Sources/SunclubApp.swift`. Routing types live in `app/Sunclub/Sources/Shared/`. The existing manual success path lives in `app/Sunclub/Sources/Services/AppState.swift` and `app/Sunclub/Sources/Views/ManualLogView.swift`. Unit tests live in `app/Sunclub/Tests/`, and UI tests live in `app/Sunclub/UITests/`.

## Plan of Work

1. Add a shared widget deep-link type and app-side handler for `Log Today`.
2. Register a URL scheme on the app and route widget taps through the existing success flow.
3. Add a WidgetKit extension target with one Home Screen widget and one Lock Screen accessory family, both exposing the same single tap action.
4. Add deterministic unit and UI coverage for the widget-triggered logging path.
5. Regenerate the Tuist project and run the targeted validation commands.

## Validation and Acceptance

1. A Home Screen widget is available and presents one obvious `Log Today` action.
2. A Lock Screen widget is available and routes to the same action.
3. Tapping either widget path records today's manual entry through the existing app flow and shows the success screen when onboarding is already complete.
4. Unit tests cover deep-link parsing and action handling.
5. UI tests cover the app behavior when launched through the widget action path.

## Outcomes & Retrospective

- Outcome: Pending implementation.
- Verification: Pending implementation.
- Follow-up: None yet.
