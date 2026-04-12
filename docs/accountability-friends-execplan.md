# Accountability Friends And Widgets ExecPlan

This ExecPlan is the living record for the optional accountability friend layer. Keep `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` current as implementation proceeds.

## Purpose / Big Picture

Sunclub should make accountability easy to find after the user has started building a sunscreen habit, without turning first-open onboarding into a social setup flow. After this work, a user can activate accountability later, add friends by nearby phone exchange, Messages/share sheet, or backup code, see minimal friend status, poke a friend to apply sunscreen, and add a Home Screen or Lock Screen widget for friend accountability.

## Progress

- [x] (2026-04-12) Audited existing friends, share, widget, deep-link, notification, CloudKit, and growth-state code.
- [x] (2026-04-12) Chose CloudKit Direct for optional direct friend status and pokes, with Messages/share-sheet fallback.
- [x] (2026-04-12) Added backward-compatible accountability growth state, invite codecs, and fake-backed service seams.
- [x] (2026-04-12) Added CloudKit public-database profile, invite response, poke, and subscription flows.
- [x] (2026-04-12) Added nearby friend exchange with MultipeerConnectivity.
- [x] (2026-04-12) Replaced the accountability UI, added later onboarding, and added the Home nudge after 3 logged days.
- [x] (2026-04-12) Added accountability widget coverage for all requested families.
- [x] (2026-04-12) Added unit/UI tests and ran repo validation.

## Surprises & Discoveries

- Observation: Sunclub already has local friend snapshots, share telemetry, deep links, app-group widget snapshots, and CloudKit private sync.
  Evidence: `FriendsView`, `SunclubGrowthSettings.friends`, `SunclubWidgetSnapshotStore`, and `CloudSyncCoordinator`.

- Observation: Friend accountability state can stay outside SwiftData.
  Evidence: Existing growth settings already persist friends and share preferences through app-group JSON.

- Observation: SwiftUI can collapse child accessibility identifiers when a parent container also carries an identifier.
  Evidence: The Home accountability nudge initially exposed the parent identifier for child buttons in UI tests; removing the parent identifier restored stable `Setup` and `Dismiss` button lookup.

- Observation: User upgrade safety depends on JSON decoding defaults, not a SwiftData migration stage, for this feature.
  Evidence: No SwiftData models changed. Tests cover older `SunclubGrowthSettings` payloads, partial accountability payloads, legacy widget snapshots, and partial accountability widget summaries.

## Decision Log

- Decision: Store accountability activation, profile ID, invite metadata, friend connection metadata, and poke history inside growth JSON rather than SwiftData.
  Rationale: The feature is optional, lightweight, and already adjacent to the existing growth/friends layer. Keeping it in JSON avoids a SwiftData schema bump.
  Date/Author: 2026-04-12 / Codex

- Decision: Use CloudKit public database only for minimal direct friend records and pokes.
  Rationale: The app already has iCloud capability and remote notification mode, and the user selected CloudKit Direct. No custom backend is introduced.
  Date/Author: 2026-04-12 / Codex

- Decision: Treat nearby phone exchange as an explicit in-app flow, not ambient background discovery.
  Rationale: MultipeerConnectivity can provide an AirDrop-like exchange while both users have the flow open, without requiring private AirDrop APIs.
  Date/Author: 2026-04-12 / Codex

## Context And Orientation

The central app state lives in `app/Sunclub/Sources/Services/AppState.swift`. Existing growth models live in `app/Sunclub/Sources/Models/GrowthFeatures.swift`, and the current friend-code codec lives in `app/Sunclub/Sources/Services/SunclubGrowthAnalytics.swift`. The existing accountability UI is `app/Sunclub/Sources/Views/FriendsView.swift`. Deep links live in `app/Sunclub/Sources/Shared/SunclubDeepLink.swift`; widget support lives in `app/Sunclub/Sources/WidgetSupport/SunclubWidgetSupport.swift`; widget rendering lives in `app/Sunclub/WidgetExtension/Sources/SunclubWidgets.swift`.

## Plan Of Work

1. Add accountability models and codecs with backward-compatible growth settings decoding.
2. Add a testable accountability service protocol plus CloudKit and noop/fake implementations.
3. Wire AppState to activate accountability, publish local status, import invite links/codes, refresh friends, and send/receive pokes.
4. Add MultipeerConnectivity nearby exchange and required local-network plist keys.
5. Replace FriendsView with a clear optional hub and add a later onboarding route.
6. Extend deep links, AppDelegate remote notification handling, and widget routes.
7. Add accountability snapshot/presentation support and widget families.
8. Add unit/UI tests and run validation from a clean checkout.

## Migration And Upgrade Safety

No SwiftData schema version bump is required because this feature does not add, remove, or rename any SwiftData model fields. Accountability state is stored in the existing growth JSON settings layer, and widget accountability state is stored in the existing app-group widget snapshot payload.

Upgrade behavior:

1. Older `SunclubGrowthSettings` JSON without `accountability` decodes with accountability inactive, no pending invites, no connections, and the existing local friend snapshots preserved.
2. Partial accountability payloads decode with stable defaults for new optional fields, so users upgrading from an intermediate build keep usable settings.
3. Older widget snapshots without an accountability summary decode with an empty summary, so existing widgets continue rendering.
4. Partial accountability widget summaries decode with zero counts and no friend/poke details instead of failing the widget timeline.
5. Invite tokens are generated only from explicit action paths, not while SwiftUI renders, so merely opening upgraded views does not mutate persisted state.

## Validation And Acceptance

1. First-open onboarding remains unchanged. Covered by UI test.
2. After 3 logged days, Home shows a dismissible accountability nudge until activated or dismissed. Covered by UI test.
3. The accountability hub clearly exposes Nearby, Send Invite, Paste Code, invite link, backup code, and friend poke actions. Covered by UI test.
4. Invite links/codes import friends, and direct CloudKit refresh/poke paths have fake-backed tests. Covered by unit tests.
5. Widgets support `systemSmall`, `systemMedium`, `systemLarge`, `systemExtraLarge`, `accessoryInline`, `accessoryCircular`, and `accessoryRectangular`. Covered by unit tests.
6. `just generate` passed.
7. `just test-unit` passed: 144 tests, 0 failures.
8. `just lint` passed. It still reports existing non-serious SwiftLint warnings in unrelated files.
9. `just test-ui` passed: 40 tests, 0 failures.
10. `just build` passed.
11. `just cloudkit-export-schema` passed and exported `.state/cloudkit/sunclub-cloudkit-schema.json`.
12. `just cloudkit-validate-schema` passed against `iCloud.app.peyton.sunclub` development schema.

## Outcomes & Retrospective

- Accountability is now an optional second-stage feature: first-open onboarding remains focused on the core sunscreen habit, while Home can surface a later setup nudge after three logged days.
- Friend discovery now supports nearby phone exchange, Messages/share sheet invites, and paste/import backup codes, with clear invite link and backup code surfaces.
- Direct friend status and pokes use CloudKit public records with fake-backed tests and share-sheet fallback paths.
- Upgrade safety is covered without a SwiftData migration by defaulting the extended JSON payloads and preserving existing local friend snapshots.
