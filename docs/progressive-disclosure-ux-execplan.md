# Progressive Disclosure UX Refactor

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

The local instructions referenced `~/.agent/PLANS.md`, but that path does not exist on this machine. The closest available plan guide is `/Users/peyton/.agents/PLANS.md`, and this document follows that format.

## Purpose / Big Picture

Sunclub already supports many helpful sunscreen habit features, but the first screen exposes too many of them before a casual user has completed the basic loop. After this change, a user who only wants to log sunscreen and see progress should see Today, streak, and recent progress first. Deeper features such as scanner, friends, reports, UV controls, backup, iCloud, HealthKit, and recovery remain available, but they are revealed through clearer sections, contextual prompts, or explicit exploration.

The result should be visible by launching the app in UI test mode after onboarding. Home should lead with the daily log state and streak, Manual Log should make SPF and notes optional, Weekly Summary and History should use neutral progress language, and Settings should group advanced controls behind task-oriented sections.

## Progress

- [x] (2026-04-12 01:18Z) Read the provided audit plan, inspected the existing SwiftUI screens, and confirmed the worktree was clean.
- [x] (2026-04-12 01:47Z) Refactored routing and Home presentation so core progress appears before advanced discovery.
- [x] (2026-04-12 01:55Z) Refactored Manual Log and Product Scanner so SPF scanning and details are optional, user-confirmed helpers.
- [x] (2026-04-12 02:06Z) Refactored Weekly Summary, History, Recovery, Friends, and Settings copy/layout for progressive disclosure.
- [x] (2026-04-12 02:15Z) Updated UI and unit tests for the changed navigation and disclosure surfaces.
- [x] (2026-04-12 02:26Z) Ran `just test-unit` and `just test-ui`; both passed.
- [x] (2026-04-12 02:38Z) Ran `just lint`; it completed successfully with 20 non-serious SwiftLint warnings.

## Surprises & Discoveries

- Observation: The referenced `~/.agent/PLANS.md` file is missing, but `/Users/peyton/.agents/PLANS.md` exists and contains the ExecPlan rules.
  Evidence: `sed -n '1,260p' ~/.agent/PLANS.md` failed with "No such file or directory"; `sed -n '1,260p' /Users/peyton/.agents/PLANS.md` succeeded.
- Observation: Home currently renders the advanced growth grid before the streak card, which conflicts with the requested core-loop-first hierarchy.
  Evidence: `HomeView.body` orders `uvBriefingCard`, `achievementCelebrationCard`, `growthLinksGrid`, then `streakCard`.
- Observation: Widget log-today deep links can race with Home launch appearance.
  Evidence: The initial UI verification for `testWidgetLogTodaySuccessOffersAddDetails` did not show the add-details action until Home stopped clearing `verificationSuccessPresentation` on appear.
- Observation: History monthly insights were technically present but not discoverable enough when placed after the calendar.
  Evidence: The full UI test reached the History screen but needed the `Show Patterns` control above the calendar to make the collapsed insight entry visible.

## Decision Log

- Decision: Keep all advanced features and move them behind local disclosure or task sections instead of deleting routes or data.
  Rationale: The user explicitly asked to preserve feature availability while improving progressive disclosure.
  Date/Author: 2026-04-12 / Codex
- Decision: Use local SwiftUI state for Home exploration instead of adding persisted settings.
  Rationale: The audit requested lightweight disclosure and did not require preference persistence; local state avoids schema churn.
  Date/Author: 2026-04-12 / Codex

## Outcomes & Retrospective

The progressive disclosure pass is implemented without deleting feature areas. Home now leads with Today and streak/progress, keeps UV compact by default, shows one contextual suggestion, and collapses Achievements, Accountability, Health Report, and SPF Scanner behind Explore. Manual Log accepts a valid one-tap log without SPF or notes, and optional details now include explicit SPF empty/clear states plus Scan SPF. Product Scanner requires confirmation before applying a detected SPF to today's log.

Secondary flows now use plainer, task-oriented structure: Weekly Summary says "Last 7 days" and offers Backfill; History has a legend, selected-day guidance, undo-aware delete copy, and collapsible monthly patterns; Recovery has empty and grouped states; Settings is split into Reminders, Progress, Data & Sync, and Advanced; Friends is framed as optional accountability with import validation.

Validation passed with `just test-unit`, `just test-ui`, and `just lint`. No schema migration or new dependency was needed.

## Context and Orientation

The main iOS app is under `app/Sunclub/Sources`. `RootView.swift` owns the single `NavigationStack` and routes to views using `AppRoute` and `AppRouter` in `Shared/AppRoute.swift`. Home is implemented in `Views/HomeView.swift`; it currently shows the daily card, full UV forecast, achievement celebration, a grid of advanced features, the streak card, secondary recovery actions, and History. Manual logging uses `Views/ManualLogView.swift` plus reusable fields in `Shared/SunManualLogFields.swift`. Weekly summary, history editing, settings, recovery, friends, and scanner each have their own SwiftUI files in `Views`.

Progressive disclosure means the default screen should focus on the user's immediate task and only reveal less common features when the user asks for them or when context makes them urgent.

## Plan of Work

First, update routing so app code can push a route onto the existing navigation stack when a user moves from one deeper screen to another. Keep the existing replace behavior for Home entry points and deep links. Then change `AppState.homeRecoveryActions` so Home does not duplicate the primary `Log Today` button and does not ask a brand-new user to backfill yesterday.

Next, reorganize Home. The body should read as header, today, streak/progress, optional compact UV detail, one contextual celebration, urgent secondary actions, History, and collapsed Explore. The footer should show `Log Today` for open days. Once today is logged, the primary footer should become progress or reapply oriented, with editing today's entry as a secondary action.

Then, make Manual Log faster by presenting SPF and notes as optional details with an explicit empty SPF state. Add a Scan SPF entry that routes to Product Scanner. Product Scanner should still scan and remember SPF values, but applying a scan to today's log should require a confirmation button before routing back to Manual Log.

Finally, update secondary screens: Weekly Summary uses "Last 7 days" and neutral not-logged copy with backfill entry points; History gains a legend, an empty-state hint, undo-aware delete copy, and collapsed monthly insights; Settings is grouped into Reminders, Progress, Data & Sync, and Advanced sections; Recovery gets an empty state; Friends import gets validation; achievements and sharing copy become plainer.

## Concrete Steps

Work from `/Users/peyton/.codex/worktrees/f866/sunclub`. Edit files with `apply_patch`. After each major group, run targeted searches for old copy such as `More Sunclub`, `Skin's Weather Report`, `Days this week`, `Missed`, and `cannot be undone` to ensure the user-visible language changed.

## Validation and Acceptance

Run `just test-unit` after state or service changes. Run `just test-ui` after UI test updates. The expected outcome is that all tests pass, and the updated UI tests prove advanced features remain reachable through disclosure while the first-run Home emphasizes daily logging and streak progress.

## Idempotence and Recovery

All changes are source edits and can be repeated safely. No migration or destructive data operation is planned. If a test command fails because of simulator availability, capture the error and run the closest narrower command that can validate the edited surface.

## Artifacts and Notes

- `just test-unit`: passed, 127 tests, 0 failures.
- `just test-ui`: passed, 36 tests, 0 failures.
- `just lint`: completed successfully; SwiftLint reported 20 warnings and 0 serious violations.
- Focused UI checks for History monthly insights and widget log success were run before the final full UI pass while stabilizing test coverage.

## Interfaces and Dependencies

No external dependencies will be added. The only interface change planned is extending `AppRouter` in `app/Sunclub/Sources/Shared/AppRoute.swift` with push-style navigation while retaining existing `open(_:)` replacement semantics for deep links and root-level transitions.
