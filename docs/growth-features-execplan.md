# Growth Features ExecPlan

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This repository includes `/Users/peyton/.codex/worktrees/3573/sunclub/AGENTS.md`, and this document must be maintained in accordance with the ExecPlan requirements described there and in `/Users/peyton/.agents/PLANS.md`.

## Purpose / Big Picture

After this change, Sunclub is no longer only a manual log-and-streak app. A user can log from Apple Watch, see richer UV guidance, share branded streak and milestone cards, unlock achievements, join local seasonal challenges, scan sunscreen bottles for SPF, export a skin health report, opt into HealthKit writes, keep lightweight friend accountability snapshots, and see Sunclub on widgets and Live Activities throughout the day. The observable result is that the same underlying habit data appears across iPhone, widgets, Live Activities, Apple Watch, HealthKit, share sheets, and exported reports without introducing any account system or server.

## Progress

- [x] (2026-04-09 14:05Z) Audited the current iPhone app architecture, widget surface, CloudKit sync model, migration plan, notification stack, and Tuist target setup.
- [x] (2026-04-09 14:12Z) Verified that the current SDK exposes `HKQuantityTypeIdentifierUVExposure`, so HealthKit support can use a real Apple data type instead of a placeholder.
- [x] (2026-04-09 14:16Z) Wrote this ExecPlan and fixed the implementation sequence around one shared persistence layer first.
- [x] (2026-04-09 15:42Z) Added the shared growth-feature persistence layer and analytics/services surface, using app-group backed JSON storage for growth settings and friend snapshots rather than a SwiftData schema bump.
- [x] (2026-04-09 16:28Z) Implemented the iPhone UI and export flows for achievements, challenges, streak cards, friends, reports, product scanning, and UV briefing.
- [x] (2026-04-09 16:54Z) Extended notifications, HealthKit, widgets, Live Activities, and widget snapshots to consume the new shared state.
- [x] (2026-04-09 17:18Z) Added watchOS app and watch complication/widget targets, with WatchConnectivity-based snapshot mirroring and wrist logging routed through the existing quick-log path.
- [x] (2026-04-09 15:03Z) Verified `just generate` and `just test-unit` from the repo root after the target and feature changes.
- [x] (2026-04-09 15:57Z) Verified `just lint` from the repo root after fixing the only new serious SwiftLint issue.
- [ ] (2026-04-09 15:49Z) Repeated watch-scheme `xcodebuild` attempts still stall without surfacing compile or packaging output, so packaged watch build verification remains an explicit local limitation.

## Surprises & Discoveries

- Observation: The repository already ships a larger widget suite, app intents, WeatherKit-based UV state, app-group snapshot storage, and CloudKit revision sync. The new work should extend those surfaces rather than recreate them.
  Evidence: `/Users/peyton/.codex/worktrees/3573/sunclub/app/Sunclub/WidgetExtension/Sources/SunclubWidgets.swift`, `/Users/peyton/.codex/worktrees/3573/sunclub/app/Sunclub/Sources/Intents/LogSunscreenIntent.swift`, and `/Users/peyton/.codex/worktrees/3573/sunclub/app/Sunclub/Sources/Services/CloudSyncCoordinator.swift` already implement those foundations.

- Observation: The HealthKit SDK available in this environment includes `uvExposure`, which is a better fit than inventing an unsupported custom category sample.
  Evidence: `HKQuantityTypeIdentifierUVExposure` is present in the iPhoneOS 26.5 HealthKit headers under `HKTypeIdentifiers.h`.

- Observation: The generated watch schemes and targets exist and the workspace regenerates cleanly, but local `xcodebuild` invocations for `SunclubWatch` and `SunclubWatchExtension` stall without emitting compiler diagnostics or a final build result, even with signing disabled and serial jobs.
  Evidence: `xcodebuild -workspace app/Sunclub.xcworkspace -list` shows the watch schemes, `just generate` succeeds, and repeated `xcodebuild ... CODE_SIGNING_ALLOWED=NO build` runs stay resident at 0% CPU without printing `BUILD FAILED` or `BUILD SUCCEEDED`.

## Decision Log

- Decision: Implement the ten requested features as one cohesive “growth layer” on top of the existing app instead of ten isolated feature branches inside the codebase.
  Rationale: The requested work shares the same inputs and outputs: daily logs, streak math, UV data, reminders, exports, and external surfaces. One shared model and analytics layer reduces duplicated state and keeps widgets, watch, reports, and share cards consistent.
  Date/Author: 2026-04-09 / Codex

- Decision: Keep the product local-first by using on-device rendering, SwiftData persistence, app-group snapshots, and CloudKit/private-share mechanics only where the platform already provides them.
  Rationale: The user explicitly requested no accounts, no servers, and no new external dependencies. This keeps the new features aligned with the existing product identity.
  Date/Author: 2026-04-09 / Codex

- Decision: Keep the new growth state outside the existing SwiftData schema and store it as compact app-group JSON blobs through `SunclubGrowthFeatureStore`.
  Rationale: The shipped feature set needs lightweight settings, presented-achievement tracking, and friend snapshots, but it does not require relational queries or legacy-store migration. Avoiding a schema bump kept the change smaller, preserved the existing persisted-model contract, and still satisfied the local-first requirement.
  Date/Author: 2026-04-09 / Codex

- Decision: Sync watch state through `WatchConnectivity` plus the existing widget snapshot store instead of trying to open the iPhone persistence layer directly from watchOS.
  Rationale: The iPhone app already derives a compact `SunclubWidgetSnapshot` and writes it to the app-group container. Mirroring that snapshot to the watch keeps the wrist surface lightweight, avoids watch-side SwiftData/container coupling, and reuses the existing quick-log path on the phone.
  Date/Author: 2026-04-09 / Codex

## Outcomes & Retrospective

- Outcome: The ten requested growth features were implemented across the iPhone app, widget extension, live activity surface, HealthKit integration, export/share flows, and new watch targets.
- Verification result: `just generate`, `just lint`, and `just test-unit` pass from the repo root after the changes. The watch targets generate and are wired into the workspace, but direct packaged watch `xcodebuild` verification remains unresolved locally because the build process stalls without a terminal success or failure result.
- Risk to watch: the remaining uncertainty is packaging/runtime validation for the generated watch schemes, not the iPhone feature layer.

## Context and Orientation

The iPhone app target is defined in `/Users/peyton/.codex/worktrees/3573/sunclub/app/Sunclub/Project.swift`. The root scene and navigation live in `/Users/peyton/.codex/worktrees/3573/sunclub/app/Sunclub/Sources/SunclubApp.swift`, `/Users/peyton/.codex/worktrees/3573/sunclub/app/Sunclub/Sources/Shared/RootView.swift`, and `/Users/peyton/.codex/worktrees/3573/sunclub/app/Sunclub/Sources/Shared/AppRoute.swift`. The central observable application state lives in `/Users/peyton/.codex/worktrees/3573/sunclub/app/Sunclub/Sources/Services/AppState.swift`. Persisted models and migration wiring live in `/Users/peyton/.codex/worktrees/3573/sunclub/app/Sunclub/Sources/Models/`, especially `Settings.swift`, `DailyRecord.swift`, `ChangeHistoryModels.swift`, and `SunclubSchema.swift`. Widget state mirroring lives in `/Users/peyton/.codex/worktrees/3573/sunclub/app/Sunclub/Sources/WidgetSupport/SunclubWidgetSupport.swift`, and the widget extension lives in `/Users/peyton/.codex/worktrees/3573/sunclub/app/Sunclub/WidgetExtension/Sources/`.

In this repository, “revision history” means the app stores day-level and settings-level changes as explicit batch and revision records so CloudKit sync, undo, recovery, and migrations remain deterministic. “Snapshot” means a compact derived payload written into the app-group container for widgets or other external targets to read quickly without opening the main SwiftData store directly.

## Plan of Work

First, add a shared growth-feature state layer that persists compact settings, presented achievements, and lightweight friend snapshots across relaunches without expanding the existing SwiftData schema. Keep it app-group backed so the iPhone app, widgets, and watch mirroring can all consume the same derived state safely.

Second, add a shared analytics layer that derives milestone unlocks, challenge progress, annual or custom-range report summaries, share-card content, friend status snapshots, and richer UV briefing data from the existing `DailyRecord` timeline and the current UV service. This layer must be usable from the iPhone app, widgets, Live Activities, watch targets, and export services.

Third, extend the iPhone app routes and views. The Home screen should gain a UV briefing card and quick access into the new growth surfaces. Add dedicated screens or sections for achievements, seasonal challenges, friend accountability, and a report/share hub. Add share-sheet wrappers that export branded streak cards, achievement cards, challenge completion cards, and a skin health PDF or image report generated entirely on-device.

Fourth, add the sunscreen product scanner using Apple Vision text recognition. The scanner should parse visible SPF numbers and likely expiry dates from a captured frame or still image, then pre-fill the existing manual log flow instead of creating a second logging path. The scan result should remain editable before save.

Fifth, extend system integrations. HealthKit should request permission only when enabled, then save a UV exposure sample whenever the user logs sunscreen so the event appears in Apple Health with Sunclub as the source. Notifications should add a morning UV briefing and an opt-in extreme UV alert. Widget snapshots should include the extra fields needed for richer widgets and Live Activities. Add ActivityKit support for a high-UV daytime activity showing current UV state and the reapply timer. Expand App Intents only where they unlock external logging or routing cleanly.

Sixth, add a watchOS surface in the Tuist project. The watch app should show today’s status and streak, allow one-tap logging, and expose a complication-style widget. The watch surface should not invent a second persistence model; it should mirror the existing widget snapshot from the iPhone via `WatchConnectivity` and reuse the existing quick-log path.

## Concrete Steps

From `/Users/peyton/.codex/worktrees/3573/sunclub`, implement and verify in this order:

1. Add the new shared model and storage files under `app/Sunclub/Sources/Models/` and `app/Sunclub/Sources/Services/`, centered on `GrowthFeatures.swift`, `UVSupport.swift`, `SunclubGrowthAnalytics.swift`, and `SunclubGrowthFeatureStore.swift`.
2. Add the new SwiftUI views under `app/Sunclub/Sources/Views/` and route them through `AppRoute`, `RootView`, `HomeView`, and settings.
3. Extend `NotificationManager.swift`, `UVIndexService.swift`, HealthKit services, widget support, and the new ActivityKit helpers.
4. Update `app/Sunclub/Project.swift` and add watch app, watch widget, entitlements, and snapshot-sync sources as needed.
5. Run:
   `just generate`
   `just test-unit`
   `just lint`
   If the watch target or widgets require a scheme-specific build, run the matching `xcodebuild` invocation from the repo root as evidence and record any unresolved packaging blockers explicitly.

## Validation and Acceptance

Acceptance is behavioral:

1. Growth-feature state persists locally with safe defaults across relaunches without disturbing the existing SwiftData store.
2. The Home screen shows a richer UV daily briefing, and the app can schedule a morning UV notification and an extreme UV alert when enabled.
3. Logging sunscreen can now produce a HealthKit write, update achievements and challenges, refresh share/report data, and keep widgets current.
4. The user can export at least one branded streak card and one skin health report entirely on-device.
5. The user can open an achievements or challenges surface and see derived milestone state from existing history.
6. The user can scan a sunscreen label, get SPF prefill, and still edit before save.
7. The user can add a lightweight friend/accountability snapshot locally and see it in a friends view.
8. Widgets and Live Activities expose the new ambient logging or UV state.
9. A watch app target is generated and offers glanceable status plus one-tap logging from the wrist; packaged build verification is still required because local `xcodebuild` hangs before producing a result.
10. Repo validation commands run from the root without requiring undeclared global dependencies.

## Idempotence and Recovery

All schema and model changes must remain additive and migration-backed so they are safe to re-run from a clean checkout. Regenerating the workspace with `just generate` must recreate any target wiring. If a migration or target generation step fails, fix the manifest or migration code and rerun the same command; do not patch generated artifacts without also updating the source manifest. If HealthKit, notifications, or watch entitlements cause build-time capability issues, keep the core iPhone app buildable while adjusting the entitlement or target wiring in source control.

## Artifacts and Notes

Important evidence to preserve as this plan progresses:

- The names of the new shared files: `GrowthFeatures.swift`, `UVSupport.swift`, `SunclubGrowthAnalytics.swift`, `SunclubGrowthFeatureStore.swift`, `SunclubHealthKitService.swift`, `SunclubLiveActivityCoordinator.swift`, `SunclubProductScannerService.swift`, `SunclubShareArtifactService.swift`, `SunclubUVBriefingService.swift`, and `SunclubWatchSyncCoordinator.swift`.
- The names of the new UI files: `AchievementsView.swift`, `FriendsView.swift`, `ProductScannerView.swift`, `SkinHealthReportView.swift`, `SunclubLiveActivityWidget.swift`, `SunclubWatchApp.swift`, `SunclubWatchHomeView.swift`, and `SunclubWatchWidgets.swift`.
- The exact verification commands that passed from the repo root: `just generate`, `just lint`, and `just test-unit`.
- The unresolved watch-target verification note: workspace generation succeeds, but direct packaged watch builds still stall locally without emitting a conclusive result.

Revision note: Created on 2026-04-09 to implement the user-requested ten-feature growth pass after auditing the current app, widget, sync, and migration architecture.
