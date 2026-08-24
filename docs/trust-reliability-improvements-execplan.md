# Make Sunclub Logging, Reminders, UV Guidance, and Progress Trustworthy

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document follows the ExecPlan requirements in `/Users/peyton/.agents/PLANS.md`.

## Purpose / Big Picture

Sunclub should never tell a person that sunscreen was logged when the durable history write failed, silently lose reminders because too many requests were scheduled, or present a precise UV number without a real place and sufficiently recent weather data. After this work, a person can enter an exact application time and an honest sunscreen profile, see one clear next action, receive reliable and actionable reminders, understand the source and freshness of UV guidance, and review progress that starts when their habit starts rather than counting earlier days as failures.

The same behavior must hold across the iPhone app, widgets, Watch, App Intents, custom URL automation, local backup, and private CloudKit history. The shipping product must remain free, local-first, account-free, dependency-free, accessible, and careful not to make medical or exact burn-time claims. Public accountability sharing stays disabled until it is intentionally restored as a visible product feature; App Store and website privacy statements must describe the build that is actually shipped.

## Progress

- [x] (2026-08-11 02:19Z) Audited the live Simulator, current `origin/master`, public storefront, notification planner, persistence paths, UV fallback, accessibility behavior, and analytics semantics.
- [x] (2026-08-11 02:19Z) Fast-forwarded clean local `master` to `origin/master` at `3e011f1318e678fe728f6b17d6f3e6036bcc0216` and created `codex/trust-reliability-improvements`.
- [x] (2026-08-11 02:19Z) Created this ExecPlan before source edits.
- [x] (2026-08-11 04:15Z) Implemented truthful application-history mutations and retryable failure presentation across in-app, widget, Watch, Shortcut, and URL entry points.
- [x] (2026-08-11 04:15Z) Rebuilt notification scheduling around repeating fixed requests, seven-day verified-UV windows, a sixty-request owned cap, complete scheduling reports, and test/reapply/snooze actions.
- [x] (2026-08-11 04:15Z) Replaced location-free numeric UV fallback with selected-city or live-location Apple Weather data, a two-hour freshness limit, explicit unavailable states, and protection-window presentation.
- [x] (2026-08-11 04:15Z) Disabled dormant public accountability transport and aligned the privacy manifest, website, App Store metadata, and review package with Data Not Collected.
- [x] (2026-08-11 04:15Z) Added exact application time, future-time rejection, one optional sunscreen profile, consistent covered-area defaults, and a backwards-compatible V4-to-V5 settings migration.
- [x] (2026-08-11 04:15Z) Rendered and dispatched the existing contextual Home action across Home, the center action, widgets, Watch, and automation, while simplifying duplicated Today content.
- [x] (2026-08-11 04:15Z) Hardened CloudKit batch quarantine, logical revision ordering, preference restore, and rollback-safe one-batch history deletion.
- [x] (2026-08-11 04:15Z) Converted shared typography and layout behavior to support accessibility sizes, contextual action labels, non-color status, increased contrast, dark mode, and Reduce Motion.
- [x] (2026-08-11 04:15Z) Made progress eligibility begin at first meaningful history for existing users and added compact, non-punitive local insights.
- [x] (2026-08-11 07:15Z) Completed generation, focused and full tests, Python/web/lint gates, eighteen Simulator visual captures, draft storefront validation, and a cache-disabled unsigned production archive plus entitlement validation.
- [x] (2026-08-23) Updated current UV behavior: Apple Weather forecasts remain fresh in the cache for up to eight hours, last-known Apple Weather values can be shown for up to 24 hours with their age, and an explicitly labeled on-device local estimate is shown when no Apple Weather value is usable. The estimate uses available latitude, season, and time, or generic season and time without location.

## Surprises & Discoveries

- Observation: The default plan can enqueue approximately ninety requests before weekly, streak, extreme-UV, or reapply requests are considered.
  Evidence: `NotificationManager.scheduleDailyReminders` creates sixty dated daily requests and `scheduleUVBriefings` creates thirty dated requests while UV briefings default to enabled. Several notification additions use `try?`, and the health snapshot does not count all categories.

- Observation: The in-app application mutation path can report success after the revision write failed.
  Evidence: `AppState.recordApplication` returns `true` after `upsertRecord`, while `upsertRecord` discards `SunclubHistoryService.applyDayChange` errors with `try?`. `ManualLogView` then haptics, schedules reminders, and leaves the screen.

- Observation: Sunclub already computes the correct contextual Home action but does not render or dispatch it.
  Evidence: `AppState.homeDailyPlanPresentation` prioritizes logging, backfill, reapply, recovery, reminder repair, details, and progress. `TimelineHomeView` copies the value into presentation state without presenting a corresponding action.

- Observation: The current “Choose a city instead” onboarding control does not choose a city, and the numeric local UV fallback uses only month and hour.
  Evidence: the onboarding action advances with live UV disabled; `UVIndexService` then calls `SunclubUVEstimator` without coordinates and labels the result as locally estimated.

- Observation: The public product currently makes conflicting privacy statements.
  Evidence: the production build enables public accountability transport and checked-in metadata/privacy copy describes associated data, while the current App Store privacy label says “Data Not Collected.”

- Observation: `ModelContext.transaction` rollback restores persisted rows but does not automatically restore already-mutated in-memory projection objects.
  Evidence: the injected pre-commit failure test initially left the current `Settings` projection changed after the transaction threw. The history service now rolls back and rebuilds projections from durable revisions before returning the failure.

- Observation: Restoring transport bookkeeping can create a publish loop even when the user-owned preferences are valid.
  Evidence: the first restorable accountability envelope included `lastPublishedAt` and subscription-install timestamps. Applying it changed the payload again and republished. The versioned projection now excludes those device-specific fields while preserving relationship credentials and user choices.

- Observation: A fresh UV value can become stale while a passive surface remains visible without launching the app.
  Evidence: the first shared widget snapshot contained only numeric values. The snapshot and Live Activity state now carry `uvValidUntil`; widgets, Watch, and Live Activities gate display and refresh timing on that expiry.

- Observation: Freezing only the top-level V4 schema was insufficient once current nested revision structures gained new fields.
  Evidence: V4 fixtures began compiling against V5 batch and revision shapes. V4 now owns immutable nested settings, batch, daily-revision, settings-revision, and cloud-state definitions, and migration tests open that exact prior shape.

- Observation: Passing accessibility tests did not by itself expose every large-text layout problem.
  Evidence: Real captures showed the original floating bottom bar covering History and Settings content and weekday abbreviations wrapping letter by letter. The final layout reserves space below the navigation stack, uses a labeled two-row accessibility grid, and presents single-letter visual weekdays with full spoken labels.

- Observation: Exact future-time rejection made a legacy conflict test depend on the time of day.
  Evidence: Just after midnight, its hard-coded 9:00 AM log was correctly rejected before the remote revision was inserted. The fixture now injects a same-day noon clock, and both its focused rerun and the complete 372-test suite pass.

- Observation: The optional local Xcode compile-cache service can fail during a production archive without a source or build error.
  Evidence: the first archive attempts repeatedly timed out connecting to the local CAS service. Running the same Release archive with compile caching disabled succeeded, after which the normal archive validator ad-hoc signed the app and verified the requested release entitlements.

## Decision Log

- Decision: Keep all user-visible success side effects behind a successful durable revision-history mutation.
  Rationale: haptics, navigation, notifications, widgets, and Live Activities are acknowledgements of a saved fact and must not run when that fact was not stored.
  Date/Author: 2026-08-11 / Codex

- Decision: Use repeating calendar triggers for copy that does not vary by date, a seven-day rolling window for weather-derived requests, and a hard cap of sixty Sunclub-owned pending requests.
  Rationale: the operating system keeps at most sixty-four pending local notifications. A sixty-request ceiling leaves room for immediate reapply and test requests while preserving deterministic scheduling.
  Date/Author: 2026-08-11 / Codex

- Decision: Do not display the current month/hour UV heuristic as a numeric UV reading.
  Rationale: without a real coordinate and recent weather response, the number is too easy to interpret as current environmental data. The app will show unavailable state and general non-numeric safety guidance instead.
  Date/Author: 2026-08-11 / Codex

- Decision: Supersede the 2026-08-11 unavailable-only UV fallback with a clearly labeled on-device local estimate when no Apple Weather value is usable.
  Rationale: a bounded, explicitly non-Apple estimate preserves a user-visible planning signal without presenting it as verified environmental data. It uses available latitude, season, and time; without location it uses generic season and time. Apple Weather values remain separately attributed.
  Date/Author: 2026-08-23 / Codex

- Decision: Use Apple frameworks already available to the app for city geocoding and weather; add no external dependency.
  Rationale: this preserves the repository’s self-contained architecture and privacy posture.
  Date/Author: 2026-08-11 / Codex

- Decision: Store the selected UV place and one optional sunscreen profile in versioned `Settings`, publish them through revision history and backup, and migrate existing users to nil values.
  Rationale: these are user-owned preferences that must survive app updates, reinstall restore, and device changes. A schema migration is required by repository policy for persisted fields.
  Date/Author: 2026-08-11 / Codex

- Decision: Disable public accountability transport in the production flavor rather than merely changing the storefront declaration.
  Rationale: the visible production route set intentionally hides social features and the current product specification calls them non-goals. Shipping dormant collection capability creates needless privacy ambiguity.
  Date/Author: 2026-08-11 / Codex

- Decision: Preserve the existing product-page design system and improve hierarchy within it rather than restyling the application.
  Rationale: the audit found a strong visual foundation; the problems are truth, action priority, information duplication, and accessibility scaling.
  Date/Author: 2026-08-11 / Codex

- Decision: Make `HomeDailyPlanAction` the contextual action contract for every surface that can express the next useful action.
  Rationale: sharing the existing decision model prevents Home, widgets, Watch, notifications, and automation from drifting into separate definitions of what the user should do next.
  Date/Author: 2026-08-11 / Codex

- Decision: Order new revisions by a monotonic logical value, with server-received time, source time, and stable identifiers used only as deterministic fallbacks.
  Rationale: device clocks are not a trustworthy conflict clock. Preserving source time for display while separating it from projection order makes merges deterministic under clock skew.
  Date/Author: 2026-08-11 / Codex

- Decision: Restore accountability relationship and invite credentials because cross-device recovery of those relationships is an explicit requirement, but exclude device-specific publish and subscription bookkeeping.
  Rationale: omitting the relationship credentials would make the restored connection unusable. Local backup copy now clearly warns that the JSON contains private connection data and must be stored securely; no URL callback credential exists in the restorable automation preferences.
  Date/Author: 2026-08-11 / Codex

- Decision: Keep the App Store update local and validation-ready rather than mutating the live storefront during implementation.
  Rationale: final contact values, privacy questionnaire confirmation, medical-device status, screenshot upload, and submission are account-owned release actions. The repository now fails strict validation until those explicit confirmations are supplied.
  Date/Author: 2026-08-11 / Codex

## Outcomes & Retrospective

The ten improvements are implemented as one cohesive trust and usability pass. Durable mutations now determine whether a surface may acknowledge success. Notification scheduling is bounded and observable. UV values are verified, place-backed, and time-bounded. Exact-time logging, reusable label-backed product details, contextual actions, neutral eligibility, deterministic sync ordering, recoverable preferences, atomic deletion, and accessibility-size layouts share the same underlying models across the app and its extensions.

The V5 migration keeps V4 definitions immutable, assigns deterministic logical order to prior revision groups, and seeds selected place and sunscreen profile as absent. The complete unit suite passed 372 tests and Python passed 199 tests. The full UI result recorded 63 passing tests and one Simulator-runner termination with no assertion failure; that terminated route then passed 1/1 in isolation, covering all 64 cases. Development CI build, the cache-disabled unsigned production archive, app/widgets/Watch linking, website validation, draft App Store metadata validation, and review-package generation succeeded. Lint completed with 47 warnings and zero serious findings. Eighteen current iPhone 17 Pro Max captures cover standard and accessibility text in light, dark, and increased-contrast appearances; the final contact sheet is `.build/trust-reliability-review/contact-sheet.png` and the labeled review page is `.build/trust-reliability-review/contact-sheet.html`.

Intentional omissions are narrow: Sunclub does not calculate burn time, promise Focus bypass, enable public accountability transport, add a third-party service, or submit a new App Store version from this implementation branch. Strict App Store validation correctly remains blocked until real review contact values are supplied and the App Privacy and not-a-medical-device confirmations are completed in App Store Connect.

## Context and Orientation

Sunclub is a Swift 6 SwiftUI application generated with Tuist from `app/Sunclub/Project.swift`. `AppState` in `app/Sunclub/Sources/Services/AppState.swift` is the main-actor observable source of truth used by screens. Durable user history is represented as revisions by `SunclubHistoryService`; projected `DailyRecord` and `Settings` SwiftData models are rebuilt from those revisions. Every model-container path must remain routed through `SunclubModelContainerFactory` in `app/Sunclub/Sources/Models/SunclubSchema.swift`, which also owns immutable prior schemas and migrations.

`NotificationManager` in `app/Sunclub/Sources/Services/NotificationManager.swift` creates daily, UV, weekly, streak, extreme-UV, and reapply local notifications. “Pending” means requests registered with `UNUserNotificationCenter` but not yet delivered. The system retains only a finite number, so Sunclub must budget across categories rather than let each scheduler enqueue independently. `NotificationHealth` interprets authorization and pending requests for Settings and Home repair UI.

`UVIndexService` in `app/Sunclub/Sources/Services/UVIndexService.swift` combines location and WeatherKit data. `UVSupport.swift` defines source, availability, freshness, and protection-window presentation models. A selected city is a user-chosen display name plus latitude and longitude resolved with Apple geocoding. Apple Weather forecasts are fresh in cache for up to eight hours; a last-known Apple Weather value may remain visible for up to 24 hours with its age shown. If neither is usable, the app presents a clearly labeled on-device local estimate based on available latitude, season, and time, or generic season and time without location. WeatherKit requests occur only while the main app is active, are cache- and budget-gated, and may start automatically on launch or foreground activation as well as after a user refresh or settings action. A “protection window” is the first through last forecast hour in which UV Index is at least three; it is guidance to use shade, clothing, and sunscreen, not a promise of safe exposure outside the window.

`ManualLogView` edits the existing `DailyRecord.verifiedAt` timestamp, SPF, covered-area metadata, and note. Exact time therefore does not require a `DailyRecord` schema change. The new optional sunscreen profile does require settings fields: a user-entered display name, SPF, and water-resistance duration of nil, forty, or eighty minutes. Swimming, sweating, and towel-drying remain user-entered context that may prompt an earlier reminder but must not calculate an exact protection duration.

`TimelineHomeView`, `SunDayStrip`, and `SunAppTabBar` render the main daily loop. `HomeDailyPlanAction` already identifies the next action. The implementation must render that model rather than create a second decision engine. `CalendarAnalytics` derives status, weekly completion, and streaks from history; it needs an eligibility start date so days before onboarding or the first record remain neutral.

CloudKit synchronization is implemented by the custom sync engine and revision-history services under `app/Sunclub/Sources/Services`. SwiftData CloudKit mirroring must remain disabled. Remote records are immutable history events. A malformed event must be reported and skipped without preventing valid events in the same fetched batch from applying. Ordering used for conflict projection must be deterministic and independent of wall-clock skew by preferring logical revision order and server metadata while preserving old-record decoding.

The shared design system is `app/Sunclub/Sources/Shared/AppDesignSystem.swift` with product-page wrappers in `AppTheme.swift`. Screens must use semantic fonts and `@ScaledMetric` where a numeric layout token must grow with Dynamic Type. Existing accessibility identifiers are compatibility interfaces for UI tests and automation and should be preserved unless a new identifier is added alongside them.

## Plan of Work

### Milestone 1: Make core writes and reminders truthful

Change in-app record mutations so the durable revision write is the operation that can fail. `AppState.recordApplication`, reapply/edit helpers, and the private upsert/delete path will return a typed result or throw. Callers will show a concise retryable error and remain on the current screen. Only a successful result may trigger success haptics, route changes, reminder rescheduling, Live Activity updates, widget reloads, or analytics. Outside-app automation already uses throwing history operations; align its errors and tests rather than add a second persistence path.

Refactor notification scheduling around one planner-owned request budget. Static daily reminders use repeating `UNCalendarNotificationTrigger` requests. Weather-derived UV briefing and extreme-UV requests cover only the next seven days. Weekly and streak requests remain one request each. Existing Sunclub-owned pending requests are replaced idempotently; immediate reapply and test requests are excluded from the rolling replacement until their purpose is complete. Introduce `NotificationSchedulingReport` with requested, scheduled, failed, and pending counts per category plus an overall status. Record a successful schedule timestamp only when all required requests were accepted. Settings gets working test-notification and copy-diagnostics controls, and repair actions navigate directly to the relevant in-app or system control.

Register reapply notification actions for `Reapplied now` and `Snooze 30 min`. Route the first through the shared automation runtime and durable revision history without opening the app when the system permits. Route snooze through a single bounded local request. Both actions must refresh widgets and Live Activity only after successful state mutation.

### Milestone 2: Make UV, onboarding, privacy, and log data accurate

Add a selected-place value to versioned settings and a small city-search sheet powered by `MKLocalSearch`. The onboarding secondary location action presents that sheet instead of advancing. The user may explicitly continue without location; that choice produces an unavailable UV state, not a numeric estimate. `UVIndexService` accepts live coordinates or the saved selected place, keeps a last-known WeatherKit reading for two hours, and returns a source/freshness state. Home, UV detail, Watch, widgets, and briefings display unavailable or stale states consistently. Derive the protection window from real hourly forecast entries at UV Index three or higher and expose the source and last-updated time.

Add the optional sunscreen profile to the current SwiftData settings schema, its revision payload, backup payload, and widget/watch snapshot where needed. Freeze the prior schema, add the next version and migration stage, and add a migration test opening a prior shipped store. Existing users migrate with no profile and no selected place. Update Manual Log to edit exact date and time, reject a future timestamp, show the saved profile or neutral SPF wording, and resolve prior SPF and structured covered areas consistently. Free-form notes must not become automatic defaults.

Set the production accountability transport flag to false. Remove or neutralize production metadata and public copy that says dormant public sharing collects data, while retaining private CloudKit sync disclosures. Update App Store metadata with accurate release notes and feature copy for Watch, widgets, Shortcuts, Live Activities, and private sync. Keep compatibility code and old routes only where existing installs or automation require them, but they must not activate public transport.

### Milestone 3: Put the right action and information first

Render one compact `HomeDailyPlanPresentation` card at the top of Today and dispatch every existing `HomeDailyPlanAction`. Make the center tab control use the same action and a visible, contextual label at accessibility sizes; the generic add action is only the fallback. Keep existing deep links and accessibility identifiers working. Remove repeated Home UV/log summaries so the first viewport contains the next action, one compact UV summary, and selected-day state. The day strip shows weekday and date number, uses one primary status marker, and exposes all meaning in text and accessibility values rather than color alone.

Update analytics APIs to accept an eligibility start date equal to the earliest of onboarding completion date and first meaningful record when available; because older settings do not store onboarding completion time, older users fall back to their first record and a user with no records starts today. Pre-eligibility days return a neutral untracked state and do not enter week or month denominators. Show current streak once, personal-best feedback only after a successful log, and compact thirty-day consistency, typical first-application time, high-UV logging rate when real UV data exists, and one factual next step. Avoid punitive words, medical scoring, and pressure-based streak recovery.

Replace fixed screen typography with design-system semantic styles and scale numeric spacing/icon values with Dynamic Type. At accessibility sizes, the bottom action becomes a labeled control that does not overlap tabs, essential copy wraps, and the day strip remains operable. Preserve Reduce Motion and increased-contrast behavior.

### Milestone 4: Harden recovery and destructive operations

Decode fetched CloudKit revisions one record at a time. Apply all valid revisions, retain a structured list of skipped record identifiers and errors, and show sync health as degraded until a later successful retry resolves each skipped record. Do not let a final refresh clear the error from a partially failed batch.

Extend the revision envelope with backward-compatible logical ordering metadata. New local revisions increment the greatest observed logical value; remote merge compares logical order first and deterministic identifiers second. Preserve source timestamps for display only. Old revisions without the field derive a stable fallback order from existing revision identifiers and CloudKit server metadata. Add skew tests where remote wall clocks are both ahead of and behind local time.

Include user-owned app-group automation, privacy, and accountability preferences in local backup and private CloudKit restore payloads, with a versioned optional section so old backups continue to decode. Restore these preferences only after meaningful local/remote history selection, and never replace a more complete current setting with a default. Implement delete-all history as one history-service batch mutation and projection rebuild; on failure, retain the original projected history and keep the confirmation UI visible with a retryable error.

### Milestone 5: Verify the complete product story

Update unit, migration, widget, Watch, UI, Python metadata, web, and documentation tests alongside behavior. Generate the Tuist workspace, then run the repo’s canonical commands from the repository root. Use compile-cache-off recovery only if the normal path hits the documented Xcode 26 cache issue. Build and run the app in `UITEST_MODE` for deterministic permissions, then capture Home, Manual Log, History, Insights, Settings Notifications, city selection, UV unavailable, and failure states at a current iPhone size. Repeat the common screens at an accessibility content size in light, dark, and increased-contrast modes and assemble a reviewable contact sheet under `.build/`.

Update this ExecPlan at each milestone with observed test output, changed decisions, and remaining gaps. Do not call the work complete if a data-preservation, accessibility, notification-capacity, or release-metadata gate remains unverified.

## Concrete Steps

Run all commands from `/Users/peyton/ghq/github.com/peyton/sunclub`.

First inspect and generate the project:

    git status --short --branch
    just generate

During implementation, use focused tests through the pinned repository toolchain. Add precise test filters as new test names are introduced, then run:

    SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 TEST_XCODEBUILD_MAX_ATTEMPTS=1 just test-unit
    just test-python
    just lint

After integration, run the complete gates:

    just ci-lint
    just test-python
    SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 TEST_XCODEBUILD_MAX_ATTEMPTS=1 just test-unit
    SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 just ci-build
    SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 just test-ui
    just web-check
    just appstore-validate
    just appstore-review-package

If the release metadata or privacy manifest changes make strict validation possible with configured credentials, also run `just appstore-validate-strict`. If it requires unavailable App Store Connect access, record the exact external prerequisite and keep local metadata validation green.

The expected successful result is that each command exits zero. Unit and UI counts may increase as tests are added; record the final counts in `Outcomes & Retrospective`. Warning-only SwiftLint output is acceptable only if it matches the repository’s existing threshold and no newly touched line introduces a warning.

## Validation and Acceptance

Inject a `SunclubHistoryService` failure while saving from Manual Log and History. The editor remains visible, an accessible retry message appears, no success haptic or route change occurs, and no follow-up notification, widget, or Live Activity update is sent. Repeat through the shared outside-app mutation tests and expect a surfaced failure rather than a false success.

With every reminder feature enabled, inspect pending requests and observe at most sixty Sunclub-owned requests. Fixed reminders repeat, weather-derived requests cover no more than seven days, reapply and test requests can still be added, and the health report accounts for every request category. Tapping the test control produces one notification; `Reapplied now` writes one durable reapplication and `Snooze 30 min` creates one bounded request.

Complete onboarding by selecting a city and observe that Home names or describes the selected place, displays a WeatherKit source/update time, and derives a protection window only from hourly values at or above three. Continue without location and observe an unavailable state with non-numeric guidance. Advance the clock more than two hours without a successful refresh and observe that the cached number is no longer presented as current.

Create, edit, and backfill a log with an exact time. A future time is disabled or rejected with accessible copy. Save a sunscreen profile and observe its name, SPF, water-resistance label, and last structured covered areas on the next manual, widget, Watch, and Shortcut-supported log without copying the prior free-form note. Open a prior-version store and verify all prior records remain non-empty and the new optional fields are nil.

For each `HomeDailyPlanAction`, construct its existing tested state and verify the visible Home card and center action agree and route to the expected destination. At accessibility text sizes, the action label remains visible, tabs remain reachable, essential content wraps without clipping, and status meaning is available without color.

Fetch a CloudKit batch containing one malformed and one valid revision. The valid revision applies, the malformed identifier remains in degraded sync status, and a later corrected fetch clears that specific error. Merge revisions created on devices with clocks an hour ahead and behind and observe the same deterministic projection. Restore a versioned backup and observe opted-in user preferences return without overwriting more complete current settings. Force bulk deletion to fail and observe that all original history remains.

Create a new user with no records and observe no historical missed days. Add a first record and verify only eligible days enter week/month rates. Log a new personal best and observe one celebratory acknowledgement; normal opens do not repeat it. Insights show only metrics supported by real local history and real UV observations.

Finally, inspect the generated production configuration and App Store review package. Public accountability transport is disabled, dormant public-sharing collection language is absent, private iCloud behavior remains documented, and release notes no longer say “Initial release.”

## Idempotence and Recovery

Notification scheduling removes and recreates only identifiers owned by Sunclub and is safe to run repeatedly. Test and reapply requests use dedicated identifiers so a schedule refresh cannot accidentally duplicate them. Migration tests use temporary stores and never mutate a developer’s installed app data.

The settings migration is additive and optional. Never edit prior `VersionedSchema` declarations. If migration fails during development, fix the new migration stage and recreate only the temporary test store; do not delete production or Simulator data as a workaround. Every model-container path remains in `SunclubModelContainerFactory`.

CloudKit decode and bulk-delete changes are additive until tests prove the new path. Preserve the old revision decoder as a backward-compatible fallback. Do not reset the development CloudKit environment or delete real remote records during verification. Use mocks and temporary stores for failure, malformed-record, clock-skew, and rollback scenarios.

The production accountability flag and metadata changes are reversible by one explicit future feature decision, but do not re-enable them without restoring visible routes, updating privacy declarations, and validating the final IPA. Generated workspace and `.build/` artifacts are disposable; source files and docs are not. Keep unrelated worktree changes unstaged and never use destructive Git resets.

## Artifacts and Notes

The initial baseline is clean `origin/master` commit `3e011f1318e678fe728f6b17d6f3e6036bcc0216` on branch `codex/trust-reliability-improvements`. Store final Simulator captures and the contact sheet under `.build/trust-reliability-review/`; do not check generated review images into source control.

Final evidence: the notification budget tests enforce at most sixty owned requests and reserve two immediate slots; V4-to-V5 migration, backup, transaction rollback, malformed CloudKit batch, and clock-skew suites are included in the 372 passing unit tests. Review artifacts are `.build/trust-reliability-review/contact-sheet.html`, `.build/trust-reliability-review/contact-sheet.png`, and `docs/app-store-review-package.md`. The validated unsigned production archive is `.build/Sunclub.xcarchive` for marketing version 2.0.12.

## Interfaces and Dependencies

Use only Foundation, SwiftUI, SwiftData, CoreLocation, WeatherKit, UserNotifications, CloudKit, WidgetKit, ActivityKit, and other Apple frameworks already linked by the project. Add no package dependency.

Define a sendable `NotificationSchedulingReport` in the notification service layer. It contains per-category requested, scheduled, and failed counts, the final Sunclub-owned pending count, and a computed success state. `NotificationManaging.scheduleReminders(using:)` returns this report asynchronously; test doubles must return deterministic reports.

Make `AppState.recordApplication`, reapplication, edit, and deletion entry points expose a typed error or result. The UI-facing error must conform to `LocalizedError`; internal errors retain their underlying cause for diagnostics. A successful result carries the durable record identifier and final timestamp needed by follow-up services.

Add codable, sendable values for `SunclubSelectedUVPlace` and `SunclubSunscreenProfile`. The place contains a display name, latitude, and longitude. The profile contains a trimmed user-visible name, SPF constrained to the app’s supported range, and `SunclubSunscreenWaterResistance` with `none`, `fortyMinutes`, and `eightyMinutes`. Store them as optional encoded settings fields so prior users migrate to nil.

Extend the UV presentation model with availability, source, observed/fetched timestamp, and optional protection-window start/end. Do not use the heuristic estimator to populate a current numeric reading. Existing callers that cannot present the richer state receive unavailable or a verified cached/live reading, never a fabricated value.

Extend the revision envelope with an optional non-negative logical order and server-received date. New encoders write both when available; old decoders accept neither. Projection ordering compares logical order, then server-received date, then stable revision identifier. Source-device `createdAt` remains available for display and diagnostics but is not the deciding conflict clock.

Extend local and private-CloudKit backup payloads with an optional versioned preferences section containing automation permission choices, privacy choices, selected UV place, sunscreen profile, and accountability preferences. The automation payload contains choices only, not callback URLs or credentials. Preserve accountability relationship credentials so restored connections remain usable, omit device-specific transport bookkeeping, and warn that local backup files contain private connection data and require secure storage.

The existing `HomeDailyPlanAction` and `HomeDailyPlanPresentation` remain the single contextual-action interface. Add dispatch and rendering adapters rather than a parallel action enum.

Revision note (2026-08-11 04:15Z): Updated the living plan after implementation and focused integration review, recording the completed product behavior, V5 migration shape, rollback and passive-UV discoveries, deliberate relationship-restore policy, verified gates, and remaining final UI/visual and external storefront steps.

Revision note (2026-08-11 07:15Z): Closed the final verification milestone with exact unit/UI/Python/lint results, current visual-review artifacts, production archive evidence, the midnight fixture correction, and the remaining account-owned storefront confirmations.

Revision note (2026-08-23): The 2026-08-11 UV fallback decisions and verification steps above are historical facts, not current behavior. Current behavior is an eight-hour Apple Weather cache, a last-known Apple Weather display window of up to 24 hours with age shown, and a clearly labeled on-device local estimate when no Apple Weather value is usable. WeatherKit may refresh automatically while the foreground main app is active; it is not exclusively user-initiated.
