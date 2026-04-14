# Make Sunclub a clearer daily routine

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds. It follows the requirements in `/Users/peyton/.agents/PLANS.md`.

## Purpose / Big Picture

Sunclub already has the foundations of a daily sunscreen habit app: local-first logging, streaks, reminders, widgets, App Intents, backups, iCloud sync, and recovery. The product risk is that the surface area can feel larger than the daily habit itself. After this work, Home should make the next useful action obvious, logging should remain fast, and error or recovery states should be understandable before they interrupt the routine. A user should be able to open the app each morning, understand whether today is done, log or reapply quickly, and trust that their history is preserved.

## Progress

- [x] (2026-04-14 16:03Z) Read project rules, the app spec, core app entry points, Home, Settings, History, Manual Log, Automation, AppState, model files, and existing tests.
- [x] (2026-04-14 16:03Z) Drafted the initial staff-level proposal list below.
- [x] (2026-04-14 16:10Z) Attempted to ask local Claude Code for the requested review; the CLI is installed but quota-blocked in this environment.
- [x] (2026-04-14 16:19Z) Used an independent Codex reviewer subagent as the fallback review source; it provided 55 additional proposals.
- [x] (2026-04-14 16:22Z) Reviewed the fallback subagent proposals and selected a small Home daily-plan plus reapply-reminder implementation batch.
- [x] (2026-04-14 16:42Z) Implemented the selected batch in app code, tests, and adjacent docs. Added `HomeDailyPlanPresentation`, rendered it on Home, made the Home footer use the daily-plan action while preserving existing UI-test accessibility identifiers, and changed reapply check-ins to schedule the next interval before sunset.
- [x] (2026-04-14 16:56Z) Ran verification. `just lint`, `just test-python`, `git diff --check`, and `xcrun --sdk iphonesimulator swiftc -parse ...` passed. `just test-unit` and a generic simulator build both stalled in Xcode build-service setup before compiler diagnostics; both runs were bounded and terminated.
- [x] (2026-04-14 17:18Z) After the user restored Claude Code availability, retried Claude. Full repo-inspection prompts timed out without output, but a self-contained read-only Claude review returned 10 current-diff risks, 50 additional proposals, and 20 ranked follow-ups.
- [x] (2026-04-14 17:18Z) Continued the low-risk implementation pass: Home plan now prioritizes recovery and notification repair, Settings shows the next actual reminder fire time, manual and automation logs share SPF/note normalization, malformed automation URLs fail before writes, Recovery conflict cards show changed fields, History has a delete-undo banner, Scanner has manual fallback and confirmation copy, and automation docs were updated.
- [x] (2026-04-14 18:10Z) Asked Claude Code for a focused no-tools triage of the remaining candidates. Claude ranked tests, History context actions, stronger delete confirmation, Settings notification-health status, reduced-motion success, read-only status/time-since automation, and CSV/JSON export as safe-no-schema work; it cautioned on notification snooze and any persisted interval/preferences work.
- [x] (2026-04-14 18:18Z) Implemented the next safe continuation: added a read-only "time since last sunscreen" automation action, URL route, x-callback fields, App Intent, App Shortcut, in-app catalog row, docs, and runtime tests; added Settings notification status for healthy and quiet states; added History context-menu and VoiceOver custom actions plus more specific delete confirmation copy; extended UI tests for Settings notification status and scanner manual fallback.
- [x] (2026-04-14 18:34Z) Re-ran verification. `just lint`, `just test-python`, `git diff --check`, `rumdl check docs/daily-routine-audit-execplan.md`, targeted Swift parse checks, and direct `swiftc -typecheck` across app sources passed. A bounded `SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 TEST_XCODEBUILD_MAX_ATTEMPTS=1 just test-unit` run again stalled in Xcode build-service setup and was terminated by timeout before the XCTest runner started.

## Surprises & Discoveries

- Observation: `HomeView`, `SettingsView`, `HistoryView`, and `AppState` are very large. They hold a lot of product behavior, which makes it easy for a small UX change to miss a related state.
  Evidence: `wc -l` shows `AppState.swift` at 2750 lines, `HomeView.swift` at 1242, `SettingsView.swift` at 1234, and `HistoryView.swift` at 1185.
- Observation: The app already has a strong accessibility release gate.
  Evidence: `app/Sunclub/Tests/AccessibilityScorecardTests.swift` rejects `.minimumScaleFactor(`, `.lineLimit(`, several direct animations, and low-contrast foregrounds.
- Observation: Home already has an "Up next" section for notification health, recovery, and sync recovery, plus a footer for the primary log/reapply action. The missing piece is a single routine-oriented daily plan that explains what to do next and why.
  Evidence: `HomeView.secondaryActionsSection`, `HomeView.footerActions`, and `AppState.todayCardPresentation` are separate presentation paths.
- Observation: The local Claude Code CLI cannot currently provide the requested review from this machine.
  Evidence: `/Users/peyton/.local/bin/claude --disallowedTools Edit,MultiEdit,Write -p ...` returned `You've hit your limit · resets 11am (America/Los_Angeles)`.
- Observation: Claude Code became available later, but direct repo inspection remained too slow for this turn.
  Evidence: A full read-only repo prompt ran for more than 11 minutes without output, and a narrower direct-inspection prompt timed out after 120 seconds. A self-contained prompt with the diff summary completed and produced review output.
- Observation: Xcode builds in this environment can stall before compiling Swift, even with compile caches disabled.
  Evidence: `SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 TEST_XCODEBUILD_MAX_ATTEMPTS=1 just test-unit` and a generic simulator `xcodebuild build` both stopped after `ExecuteExternalTool ... clang -v -E -dM ... WatchSimulator...` and produced no compiler diagnostics before the bounded timeout terminated them.

## Decision Log

- Decision: Use the existing SwiftUI, SwiftData, AppState, and test patterns instead of introducing new dependencies or a new architecture.
  Rationale: The repository explicitly avoids new external dependencies, and the app already has broad local-first infrastructure. A daily-routine improvement should consolidate behavior, not add a heavy subsystem.
  Date/Author: 2026-04-14 / Codex
- Decision: Treat a 100-plus-item proposal set as a ranked backlog, then implement a coherent high-impact batch instead of scattering shallow edits across every item.
  Rationale: The user asked for both broad audit coverage and implementation. Implementing all audit ideas at once would be risky for persistence, CloudKit, accessibility, and reviewability. A verified batch can still advance the goal while preserving the larger backlog.
  Date/Author: 2026-04-14 / Codex
- Decision: Because Claude Code is quota-blocked, use the available Codex reviewer subagent as a transparent fallback while preserving the attempted Claude command and error in this plan.
  Rationale: The user specifically requested a subagent review. The exact requested Claude review is not available in this environment right now; a read-only independent reviewer still adds a second pass over the codebase and proposal list.
  Date/Author: 2026-04-14 / Codex
- Decision: Preserve existing Home footer accessibility identifiers while making the footer model-driven.
  Rationale: Existing UI tests and automation refer to `home.logManually` and `home.loggedPrimaryAction`. Changing the action model should not break stable test and accessibility hooks.
  Date/Author: 2026-04-14 / Codex
- Decision: Do not implement Claude proposals that conflict with the app's stated product posture or release gates in this batch.
  Rationale: Claude suggested several high-effort or gimmick-prone ideas such as streak freezes, body coverage maps, A/B notification experiments, skin-type modeling, ambient-light heuristics, and new persisted product models. These need product design, privacy review, schema migrations, and medical-copy review before implementation; they are not safe "continue the batch" items.
  Date/Author: 2026-04-14 / Codex

## Outcomes & Retrospective

The completed batches make Home describe a single "Plan for today" and use the same derived presentation to choose the footer's primary action. The model now covers the common routine states plus recovery review and notification repair. Reapply check-ins schedule the next interval reminder when there is enough daylight left; after sunset they cancel cleanly. Manual, URL, Shortcut, and history writes share SPF and note normalization. Recovery, History, Scanner, Settings, and automation docs now explain more of the important edge states without adding dependencies or changing persisted schema. The broad backlog remains intentionally open for later schema, CloudKit, backup-preview, Dynamic Type UI, and view-splitting batches.

## Independent Reviewer Fallback Review

Claude Code could not run because of the local quota error recorded above. A read-only Codex reviewer subagent inspected the plan, Home, AppState, Manual Log, shared manual log fields, History, Settings, Recovery, automation/deep-link services, reminder code, and representative tests.

The reviewer marked these Codex proposals as highest value: Home next-action clarity, competing CTA cleanup, low-UV logging copy, post-log next-state copy, add-details prompts, notification health clarity and tests, reminder schedule previews and DST tests, missed-today/yesterday recovery prompts, delete undo, backup/import summaries, conflict field details, data safety, Home priority tests, manual-log behavior tests, reapply scheduling tests, note limits, scanner permission fallback, HealthKit non-blocking failures, calendar accessibility values, Dynamic Type and widget tests, App Intent and URL contract tests, and container-factory release gates.

The reviewer marked these as useful but partly covered: progressive disclosure, first-run copy, optional social suppression, local-only import banners, view splitting, scanner confirmation, weekly/monthly summary polish, visual regression coverage, widget/watch copy alignment. The reviewer marked these as lower priority for the first batch: Home reminder coaching, "mostly indoors" logging copy, edit-last-log shortcuts, history search, and Settings search. The reviewer marked persisted skip/dismissal semantics and HealthKit feedback as risky unless designed with persistence and release gates.

The reviewer provided 55 additional proposals:

1. Add a pure Home next-action presentation outside `HomeView` so Home action priority is unit-testable.
2. Give the next-action model explicit reasons such as not logged, needs details, reapply available, notification repair, import review, conflict review, and backfill.
3. Make the Home footer render from that model instead of independently checking today's record.
4. Add a unit test proving sync conflict beats optional social/accountability prompts.
5. Add a unit test proving notification-denied never hides manual logging.
6. Add a unit test proving already logged plus reapply disabled routes to weekly summary.
7. Add a unit test proving already logged plus reapply enabled routes to reapply check-in.
8. Add a first-run Home state that suppresses backfill and accountability until at least three logged days.
9. Add "Last saved at" copy on the logged Home card using `verifiedAt`.
10. Make "Edit Today's Log" show only after today is logged and keep it visually secondary.
11. Reschedule the next reapply reminder after `recordReapplication` instead of canceling and stranding users outside for the rest of the day.
12. Add a setting-level explanation that reapply reminders are interval reminders, not medical advice.
13. Add a test for reapply after first check-in scheduling the next interval before sunset.
14. Add a test for reapply after sunset canceling cleanly with user-visible explanation.
15. Add Home copy for "reapply reminders off" after today is logged.
16. Add Settings preview of the actual next daily reminder date, not only weekday/weekend time.
17. Add a notification-health case for authorization allowed but stale reapply reminders only.
18. Add a notification-health case for provisional or ephemeral authorization copy.
19. Add "Refresh Reminders" success feedback in Settings and Home.
20. Add reminder schedule tests for DST spring-forward and fall-back with explicit calendars.
21. Normalize manual and automation SPF inputs to the same allowed range.
22. Add tests for `spf=0`, negative SPF, and huge SPF across URL and Shortcut automation.
23. Add visible "SPF optional" success copy when no SPF was saved.
24. Add a note-character limit to `SunManualLogFields` and enforce the same limit in automation.
25. Add normalized case-insensitive note-snippet dedupe in `ManualLogSuggestionEngine`.
26. Add a clear-note test for Manual Log and History editor because optional-field replacement differs by flow.
27. Add a "Clear note" affordance when a note exists.
28. Add keyboard submit/dismiss behavior tests for the multiline note field.
29. Add UI tests for optional-details collapsed and expanded states.
30. Add scanner result confidence language based on OCR source.
31. Add a backup import dry-run summary before applying imported projected state.
32. Add tests proving backup import does not delete current non-imported days without a clear restore point.
33. Add Recovery conflict rows that show field names changed, not only the conflict summary.
34. Add Recovery filtering between "Needs review" and "Recent updates."
35. Add a direct "Undo last change" Home banner only for destructive History delete.
36. Add a delete undo snackbar or toast in History using existing change-batch undo.
37. Add tests proving undo after delete restores SPF, notes, reapply count, and timestamp.
38. Add import-session count and detail to Settings Data & Sync before "Send to iCloud."
39. Add an iCloud paused state on Home only when pending local changes exist.
40. Add a data-safety test that all import/recovery buttons remain accessible with large text.
41. Split presentation-only Home helpers out of `AppState` without changing persistence.
42. Split `HomeView` subviews into local files after the next-action model lands.
43. Extract Settings backup/iCloud sections into small views with explicit bindings.
44. Extract `HistoryRecordEditorView` from `HistoryView.swift`.
45. Add a test guard against direct `ModelContainer` creation outside `SunclubModelContainerFactory`.
46. Add a test that `finishDurableChange` does not queue nil or no-op batches to CloudKit.
47. Add a test for widget snapshot refresh after History edit, delete, undo, and reapply.
48. Add a test for watch log when onboarding is incomplete and when today already exists.
49. Add a test that URL open actions blocked by preferences route to Automation without mutating navigation unexpectedly.
50. Add a test that malformed automation links with invalid action names fail parseably.
51. Add "what changed since last visit" copy only for meaningful recovery/import states.
52. Add accessible values for Home metadata pills so VoiceOver reads title and value together.
53. Add Voice Control-friendly visible labels for icon-only Home and Settings actions where practical.
54. Add Dynamic Type UI coverage for Product Scanner denied, no-result, and result states.
55. Add a concise "daily routine" product contract test: launch seeded app, see exactly one primary Home CTA, log, success, return Home, see logged state and one next CTA.

The reviewer recommended the first implementation batch be the Home next-action slice: add a derived Home presentation model, render Home footer and priority from the model, test conflict/import review, notification repair, log today, logged reapply, logged progress, and backfill, and avoid persisted dismissals, skip semantics, schema changes, and broad view splitting.

## Claude Code Review

After the user restored Claude Code access, Codex retried Claude. Full direct repo-inspection prompts did not return usable output in time, so Claude was given a self-contained current-diff summary and asked for a read-only staff review.

Claude's useful current-diff notes were:

1. Confirm whether `ChangeHistoryModels` changes are computed-only before assuming no schema migration is needed.
2. Keep conflict-field display read-only and idempotent.
3. Be careful that reapply rescheduling cannot leave orphaned or missing notifications if scheduling is interrupted.
4. Surface note truncation consistently across manual, Shortcut, and URL writes.
5. Make malformed automation URL failures explicit and covered by tests.
6. Keep scanner fallback out of camera-permission flows so UI tests do not hang.
7. Ensure provisional-notification copy is only shown for provisional or ephemeral authorization.
8. Be careful with locale-aware note dedupe.
9. Do not make Home presentation derivation trigger sync or mutation side effects.
10. Treat destructive History actions as data-preservation-sensitive flows.

Claude also provided these 50 additional proposals. Codex reviewed them and treated schema, medical, privacy, and gimmick-prone ideas as future backlog rather than immediate implementation targets:

1. Add a "last applied" timestamp badge to the Home daily-plan card.
2. Surface UV index from WeatherKit inline on Home with a severity dot.
3. Add an App Intent for "time since last application."
4. Expose a read-only status URL with x-callback details.
5. Add a watch complication showing minutes until reapply.
6. Add a body coverage map for applied zones.
7. Add an opt-in streak freeze.
8. Add a morning missed-yesterday interstitial with one-tap backfill.
9. Add an App Intent for logging yesterday.
10. Persist preferred SPF and prefill manual log.
11. Add favorite sunscreen products.
12. Add product-expiry tracking from scanner results.
13. Add CloudKit sharing for family monitoring.
14. Add an hourly UV forecast detail sheet behind the daily plan.
15. Add long-press context menus on History calendar days.
16. Add bulk delete in History with one undo point.
17. Add a VoiceOver custom rotor for History days.
18. Add a Reduce Motion-safe success alternative.
19. Add notification-copy experimentation.
20. Add a "snooze 10 min" reapply notification action.
21. Surface notification-health status in Settings.
22. Add HealthKit export for UV-exposure minutes if entitlement exists.
23. Add travel mode for high-altitude or tropical UV.
24. Add barcode fallback with an offline known-product list.
25. Surface scanner confidence with "verify SPF" warning.
26. Add App Intent for setting reapply interval.
27. Add a local "morning routine" automation trigger after first log.
28. Add an explicit CloudKit opt-out confirmation.
29. Show CloudKit sync-last-succeeded timestamp.
30. Add "Sync Now" with fetch-then-send feedback.
31. Add side-by-side local versus cloud conflict values.
32. Add a data-health diagnostic screen.
33. Persist skin type to tune suggestions.
34. Add yearly summary.
35. Add CSV/JSON history export.
36. Add a shareable streak card with alt text.
37. Add proactive "in the sun" heuristics.
38. Add lock-screen Live Activity for reapply countdown.
39. Add Apple Watch Ultra action-button mapping.
40. Donate Siri interactions for habitual log time.
41. Add configurable follow-up notification after first log.
42. Add pre-delete confirmation naming the date/product.
43. Add backup restore diff before commit.
44. Add Home accessibility-label assertion tests.
45. Add Dynamic Type snapshot tests for Settings.
46. Add increased-contrast palette branch.
47. Add App Shortcut phrase "I put on sunscreen."
48. Add configurable widget intent for product-specific logging.
49. Add background prefetch for tomorrow's UV forecast.
50. Add a "why this interval?" explanation for reapply timing.

Claude ranked the next low/medium-risk work as: preferred SPF prefill, reapply snooze action, Siri interaction donation, Settings notification-health status, History VoiceOver rotor, stronger pre-delete confirmation, Dynamic Type Settings test, Home accessibility-label tests, favorite products, CSV/JSON export, read-only status URL, time-since-last-application intent, set-reapply-interval intent, inline WeatherKit UV, Reduce Motion success alternative, scanner confidence, Live Activity countdown, CloudKit last-success timestamp, History long-press actions, and bulk delete. Codex accepted the generally useful testing and clarity items, rejected notification A/B, streak freeze, skin type, body map, ambient heuristics, and family monitoring for this batch, and implemented the safe overlapping items already present in the current diff.

Claude's later no-tools triage ranked the safest remaining work as Dynamic Type tests, Home accessibility tests, History context menus and VoiceOver affordances, stronger delete confirmation, Settings notification-health status, reduced-motion success alternative, read-only status URL/x-callback, App Intent for time since last application, and CSV/JSON export. It flagged set-reapply interval and notification snooze as caution items unless the existing fields and no-persistence implementation are confirmed. The app already had status URL/x-callback and set-reapply App Intent coverage, so Codex implemented the missing low-risk overlap: dedicated time-since-last-application automation plus Settings/History clarity.

## Selected Implementation Batch

This turn implements the safest subset of the reviewer recommendation. The code adds `HomeDailyPlanPresentation` as a derived presentation model in `AppState`, renders a "Plan for today" card on Home, drives the Home footer primary action from that model, and adds unit tests for log-today, add-details, backfill-yesterday, reapply, and completed-day states. It also implements the reviewer proposal to reschedule the next reapply reminder after a reapply when there is enough daylight left, with a test for the before-sunset path and a test for the after-sunset cancellation path.

The continuation batch adds Home recovery/notification priority, manual and automation input normalization, note count and clear affordances, strict automation URL validation, next-reminder preview in Settings, conflict changed-field display, History delete undo, richer History calendar accessibility, Scanner manual fallback and confirmation copy, and adjacent automation docs. The second continuation adds dedicated time-since-last-application automation, visible Settings notification status, History context actions, stronger delete confirmation, and UI coverage for the new scanner and Settings affordances. These batches intentionally do not add persisted prompt dismissals, "skip" semantics, schema changes, backup import previews, notification snooze state, medical heuristics, or broad view splitting.

## Context and Orientation

The iOS app lives under `app/Sunclub/Sources`. `SunclubApp.swift` creates the SwiftData `ModelContainer`, owns `AppState`, injects `AppRouter`, applies UI-test accessibility overrides, and handles incoming URLs. `RootView.swift` owns the `NavigationStack` and maps `AppRoute` cases to screens. `AppState.swift` is the main observable application state and service coordinator; it reads and writes projected history through `SunclubHistoryService`, schedules reminders through `NotificationManager`, publishes widget snapshots, coordinates CloudKit, and exposes presentation values used by views. `HomeView.swift` is the main daily dashboard. `ManualLogView.swift` records or updates today's sunscreen log. `HistoryView.swift` shows and edits calendar history. `SettingsView.swift` groups reminder, data, automation, advanced, and support settings. `AutomationView.swift` documents App Intent and URL automation surfaces.

The existing product identity is a local-first daily sunscreen tracker. The app should not become a generic wellness dashboard. "Daily routine" means the user can quickly answer: what is today's sunscreen status, what should I do now, and what needs attention before I close the app.

## Initial Codex Proposal List

The following proposals are intentionally broad. Each item is phrased as a necessary feature, improvement, or fix to make Sunclub more reliable, more understandable, or more likely to become a daily habit without gimmicks.

1. Add a single Home "daily plan" presentation that ranks the next best action across log today, reapply, add details, backfill yesterday, repair reminders, and review sync changes.
2. Replace scattered Home urgency copy with priority-based language so the app never presents two competing primary actions.
3. Make Home explicitly explain why "Log Today" is still useful when UV is low, cloudy, or live UV data is unavailable.
4. Add a quiet post-log state that says what happens next: reapply reminder, next scheduled daily reminder, or no further action today.
5. Add a "saved but incomplete" prompt after a no-SPF/no-note log so users can add details without feeling blocked.
6. Add a deterministic "today closes at midnight" explanation near streak-risk nudges.
7. Add a time-of-day Home greeting that never implies sunscreen is needed at night unless a streak is still open.
8. Make the Home streak card less dominant after a long streak if today is not logged; the next action should remain visually primary.
9. Add Home copy for first-day users that explains one log is enough; do not lead with optional automation, reports, or friends.
10. Hide or delay optional social/accountability prompts until the user has a stable logging pattern and has dismissed core recovery states.
11. Add a "why am I seeing this?" detail for notification repair banners.
12. Make notification-denied state route directly to the exact Settings section or explain that manual logging still works.
13. Add stale-notification tests that prove repair banners disappear after a successful schedule refresh.
14. Add a reminder schedule preview showing the next two actual fire times for weekday/weekend plus time-zone handling.
15. Add tests around daylight saving time and travel-time-zone reminder behavior.
16. Add a short "good reminder time" coaching result to Home only when enough historical data exists.
17. Add a recovery prompt for a missed today after the usual reminder time, not just yesterday backfill.
18. Add a "missed yesterday" backfill prompt only when the user has an active or recent habit, and suppress it after repeated dismissals.
19. Persist dismissals for Home recovery prompts so users are not nagged daily about a day they intentionally skipped.
20. Add "Skip yesterday" as a non-destructive dismissal that records no log and preserves data honesty.
21. Add an undo affordance after deleting a record in History.
22. Add a visible summary of the data that will change before importing a backup.
23. Add a local-only import banner on Home that clearly states iCloud will not be overwritten unless the user sends the import.
24. Add a conflict detail preview that highlights which fields changed: SPF, notes, reapply count, or timestamp.
25. Add a "data safety center" in Settings that combines backup export, import, iCloud status, and recent recovery items.
26. Split `AppState` into narrower presentation or domain helpers without changing persistence behavior.
27. Split `HomeView` into dedicated subviews for the today card, daily plan card, UV forecast, optional tools, and footer.
28. Split `SettingsView` into reminder, data, automation, advanced, and support subviews to reduce state coupling.
29. Split `HistoryView` calendar, selected-day detail, monthly insights, and editor types into smaller files.
30. Add tests for Home's next-action priority order so bug fixes do not create competing CTAs.
31. Add tests for manual logging trim behavior when a user clears a note while preserving SPF.
32. Add tests for same-day log updates preserving or replacing optional fields in the intended contexts.
33. Add tests for reapply scheduling when a log is updated later in the day.
34. Add a reapply state that shows the next reminder time after each reapply, not just the count.
35. Add a same-day "I am mostly indoors" note shortcut to logging, framed as a note rather than a medical recommendation.
36. Add more useful note snippets by deduplicating normalized text case-insensitively.
37. Add a maximum note length with visible remaining count and tests.
38. Add scanned-SPF confidence and source copy that makes the user confirm the scan rather than trusting OCR blindly.
39. Add a product-scanner fallback path that lets users type SPF when camera or OCR is unavailable.
40. Add a no-camera-permission scanner state that explains manual logging is still available.
41. Add HealthKit export status feedback after logging only when HealthKit is enabled.
42. Add a HealthKit failure state that does not block the daily log.
43. Add a weekly summary "best day to improve" that uses history but avoids shame-heavy wording.
44. Add a weekly backfill strip for missed days in the last seven days.
45. Add a monthly review that differentiates skipped days from future days and unlogged past days.
46. Add an "edit last log" shortcut on Weekly Summary for users who notice an error.
47. Add a history search/filter for notes or SPF level once enough records exist.
48. Add calendar accessibility values that include SPF and note presence on logged days.
49. Add large Dynamic Type UI tests for Home, Manual Log, Settings, and History with deterministic launch routes.
50. Add dark-mode visual regression screenshots for the primary daily loop.
51. Add reduced-motion checks for celebratory and decorative views.
52. Add widget snapshot tests for midnight rollover and already-logged states.
53. Add widget copy that matches the in-app daily plan language.
54. Add watch copy that mirrors the phone's "one log today" model and avoids feature drift.
55. Add App Intent result copy that tells the user whether the action logged, updated, or was blocked by preferences.
56. Add App Intent tests for disabling Shortcut writes while allowing open-only actions.
57. Add URL/x-callback tests for malformed dates, invalid SPF, and disabled callback details.
58. Add an automation catalog row that states which actions write data and which only open the app.
59. Add a Settings search or compact index when the number of settings sections grows further.
60. Add release-gate tests that ensure all SwiftData container creation still routes through `SunclubModelContainerFactory`.

## Plan of Work

First, ask local Claude Code to review the initial proposal list above in read-only mode. The prompt will ask Claude Code to inspect this repository, identify weak assumptions, mark which Codex proposals are high-value or low-value, and add at least 50 proposals of its own. The output will be saved into this file or an adjacent artifact.

Second, merge both proposal sets into a ranked backlog. The ranking criteria are daily routine value, functional correctness, data preservation risk, accessibility impact, and implementation size. The selected implementation batch prioritizes a Home daily plan presentation, tests for its priority order, and a reapply rescheduling fix without changing persistence.

Third, implement the selected batch by adding small presentation types and tests close to the existing `AppState` and `HomeView` patterns. Avoid changing SwiftData schema unless the chosen batch absolutely requires it. If persisted fields are needed, add a schema version and migration tests before changing models.

Fourth, run the relevant tests. At minimum, run `just test-unit` for app behavior. If only docs or Python scripts are touched, run the corresponding smaller command. If UI code changes are substantial and the simulator is practical, run `just test-ui` or targeted UI verification.

## Concrete Steps

Work from `/Users/peyton/.codex/worktrees/238c/sunclub`.

Read the plan and current source:

    sed -n '1,260p' docs/daily-routine-audit-execplan.md
    rg -n "todayCardPresentation|homeRecoveryActions|footerActions|secondaryActionsSection" app/Sunclub/Sources

Ask Claude Code for a read-only review:

    /Users/peyton/.local/bin/claude -p "<prompt that references docs/daily-routine-audit-execplan.md and asks for review plus 50 proposals>"

Run tests after implementation:

    just test-unit

Observed verification for this implementation:

    just lint
    # Passed with warning-only SwiftLint output already present in the repo.

    just test-python
    # 134 passed.

    git diff --check
    # Passed.

    xcrun --sdk iphonesimulator swiftc -parse -target arm64-apple-ios18.0-simulator app/Sunclub/Sources/Services/AppState.swift app/Sunclub/Sources/Views/HomeView.swift app/Sunclub/Tests/SunclubTests.swift
    # Passed.

    SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 TEST_XCODEBUILD_MAX_ATTEMPTS=1 just test-unit
    # Timed out after 240 seconds in Xcode build-service setup before Swift compiler diagnostics.

    SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 TEST_XCODEBUILD_MAX_ATTEMPTS=1 just test-unit
    # Timed out again after 360 seconds in Xcode build-service setup before Swift compiler diagnostics.

    xcodebuild build -workspace app/Sunclub.xcworkspace -scheme Sunclub -configuration Debug -destination "generic/platform=iOS Simulator" -derivedDataPath .DerivedData/build-check CODE_SIGNING_ALLOWED=NO SWIFT_ENABLE_COMPILE_CACHE=NO COMPILATION_CACHE_ENABLE_CACHING=NO COMPILATION_CACHE_ENABLE_PLUGIN=NO
    # Timed out after 180 seconds in the same build-service setup phase.

    xcrun swiftc -typecheck -target arm64-apple-ios18.0-simulator -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" $(rg --files app/Sunclub/Sources | rg "\.swift$")
    # Passed.

## Validation and Acceptance

The broad audit is accepted when this document contains at least 50 Codex proposals, a second reviewer has reviewed those proposals in repository context, the second reviewer has added at least 50 proposals, and the combined list is reviewed into a ranked implementation batch. Claude Code was attempted first, was initially quota-blocked, then later provided a self-contained read-only review and follow-up triage after access was restored. The independent Codex reviewer fallback remains recorded because it informed the first Home daily-plan batch.

The implementation batch is accepted when the app has a clearer daily routine behavior that can be observed on Home, new or updated tests cover the changed priority logic, and relevant non-Xcode checks pass. Full Xcode unit execution remains blocked by the environment-level build-service stall documented above and should be rerun in a healthy Xcode environment.

## Idempotence and Recovery

The audit document can be updated repeatedly. Source changes should remain additive and testable. If a chosen implementation path proves too risky, leave the proposal in the backlog and choose the next smaller item with equivalent daily-routine value. Do not remove existing persistence, CloudKit, backup, automation, or accessibility gates while pursuing Home clarity.

## Artifacts and Notes

Claude Code output was partially collected after access was restored. Full direct repo-inspection prompts timed out without output, but self-contained read-only review and triage prompts completed; both are summarized above. Independent Codex reviewer output is also summarized above.

## Interfaces and Dependencies

Use the existing SwiftUI, Observation, SwiftData, and service types already in the app. Do not add external dependencies. New presentation values should be plain Swift structs in `AppState.swift` or a nearby service file. New UI should use `AppPalette`, `SunMotion`, `SunLightScreen`, `SunStatusCard`, and existing button styles so Dynamic Type, dark mode, reduced motion, and contrast tests remain valid.
