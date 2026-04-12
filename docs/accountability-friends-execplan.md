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
- [x] (2026-04-12) Audited accountability usability and poke delivery; found Home surfacing, notification route/category, CloudKit upsert, APS entitlement, and friend-row affordance issues.
- [x] (2026-04-12) Added varied one-tap poke messaging, status-aware incoming notifications, Home accountability card, less-prominent removal, direct-poke widget deep links, and focused regression tests.

## Surprises & Discoveries

- Observation: Sunclub already has local friend snapshots, share telemetry, deep links, app-group widget snapshots, and CloudKit private sync.
  Evidence: `FriendsView`, `SunclubGrowthSettings.friends`, `SunclubWidgetSnapshotStore`, and `CloudSyncCoordinator`.

- Observation: Friend accountability state can stay outside SwiftData.
  Evidence: Existing growth settings already persist friends and share preferences through app-group JSON.

- Observation: SwiftUI can collapse child accessibility identifiers when a parent container also carries an identifier.
  Evidence: The Home accountability nudge initially exposed the parent identifier for child buttons in UI tests; removing the parent identifier restored stable `Setup` and `Dismiss` button lookup.

- Observation: User upgrade safety depends on JSON decoding defaults, not a SwiftData migration stage, for this feature.
  Evidence: No SwiftData models changed. Tests cover older `SunclubGrowthSettings` payloads, partial accountability payloads, legacy widget snapshots, and partial accountability widget summaries.

- Observation: Direct poke delivery needs the app to process CloudKit events and emit the final local notification.
  Evidence: Query-subscription alert bodies are static, while `AppState.handleIncomingPoke` can inspect whether the recipient has already logged today and pass differentiated copy to `NotificationManager`.

- Observation: Users with friends should not have to expand Explore to use accountability.
  Evidence: The previous Home accountability entry was only a feature tile inside the collapsed Explore grid unless the setup nudge was visible.

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

- Decision: Keep friend-to-friend messaging one tap and vary copy automatically.
  Rationale: Custom typed messages add friction to the habit loop. Status-aware copy gives the poke personality while keeping the interaction fast.
  Date/Author: 2026-04-12 / Codex

- Decision: Make CloudKit poke subscriptions silent/content-available and use local accountability notifications for final poke copy.
  Rationale: The recipient app can choose copy based on local logged-today state and route the tap to Accountability instead of Manual Log.
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
6. New widget accountability fields default to no direct poke target and no latest-poke text when older snapshots decode.

## Usability And Bug-Fix Pass

1. Active accountability appears directly below Today on Home.
2. Active users with no friends get a front-and-center add-friend card.
3. Existing three-log setup nudge remains only for users who have not opted in.
4. Home exposes one-tap poke for the top open friend.
5. Home shows open/logged counts and a compact friend strip.
6. Home surfaces recent poke activity.
7. Foreground refresh checks remote accountability events.
8. Explore remains a secondary feature entry.
9. Friends screen shows existing friends before add/import controls.
10. Add-friend controls collapse behind "Add another friend" after friends exist.
11. Remove is hidden in an overflow menu.
12. Remove requires confirmation.
13. Primary friend messaging remains one tap with "Poke".
14. Message fallback moved into overflow.
15. Poke copy has more than 20 open/logged variants.
16. Recent poke copy avoids immediate repeats.
17. Outgoing poke copy uses the friend status snapshot.
18. Incoming notification copy uses the recipient's local logged-today state.
19. Legacy/non-direct friends show a fresh-invite-needed message.
20. Accountability notifications route to Accountability.
21. Poke notifications use a dedicated category.
22. CloudKit poke subscription alert copy is silent/content-available.
23. Stable CloudKit profile/invite records fetch before saving to avoid create-only conflicts.
24. Accountability widgets show friend status, cheekier copy, latest poke text, and direct-poke deep links when safe.

## Validation And Acceptance

1. First-open onboarding remains unchanged. Covered by UI test.
2. After 3 logged days, Home shows a dismissible accountability nudge until activated or dismissed. Covered by UI test.
3. The accountability hub clearly exposes Nearby, Send Invite, Paste Code, invite link, backup code, and friend poke actions. Covered by UI test.
4. Invite links/codes import friends, and direct CloudKit refresh/poke paths have fake-backed tests. Covered by unit tests.
5. Widgets support `systemSmall`, `systemMedium`, `systemLarge`, `systemExtraLarge`, `accessoryInline`, `accessoryCircular`, and `accessoryRectangular`. Covered by unit tests.
6. Active accountability with friends appears front-and-center on Home. Covered by UI test.
7. Direct and incoming pokes use varied, status-aware copy and route to Accountability. Covered by unit tests.
8. CloudKit profile saves fetch existing records before saving. Covered by unit test through a fake accountability database.
9. App background remote-notification mode has a matching APS entitlement. Covered by Python metadata test.
10. `just generate` passed.
11. `TEST_SIMULATOR_NAME='Sunclub ca9a Unit iPhone 17 Pro' just test-unit` passed: 150 tests, 0 failures.
12. `just test-python` passed: 53 tests, 0 failures.
13. `just lint` passed after final edits. It still reports existing non-serious SwiftLint warnings, including one new AppState function-length warning from the accountability foreground refresh path.
14. `TEST_SIMULATOR_NAME='Sunclub ca9a UI iPhone 17 Pro' just test-ui` executed all 42 UI tests; 41 passed and 1 failed on a test-side `home.accountabilityFriendStrip` element-type assertion after the product card and setup case were already discoverable.
15. The `home.accountabilityFriendStrip` assertion was patched to query the identifier across XCTest element types. Subsequent full and focused UI reruns built successfully but failed before test execution with CoreSimulator Mach `-308` while launching `app.peyton.sunclub.dev.UITests.xctrunner`; sibling worktree `xcodebuild test` jobs were active at the same time.
16. Earlier implementation validation also covered `just build`, `just cloudkit-export-schema`, and `just cloudkit-validate-schema` against the development container.

## Outcomes & Retrospective

- Accountability is now an optional second-stage feature: first-open onboarding remains focused on the core sunscreen habit, while Home can surface a later setup nudge after three logged days.
- Friend discovery now supports nearby phone exchange, Messages/share sheet invites, and paste/import backup codes, with clear invite link and backup code surfaces.
- Direct friend status and pokes use CloudKit public records with fake-backed tests and share-sheet fallback paths.
- Direct pokes now use varied cheeky copy, incoming notifications differentiate open vs already-logged recipients, and notification taps open Accountability.
- Friends are surfaced on Home for opted-in users, and friend removal is no longer a prominent row action.
- Upgrade safety is covered without a SwiftData migration by defaulting the extended JSON payloads and preserving existing local friend snapshots.
