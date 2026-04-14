# Watch App Release Hardening ExecPlan

This ExecPlan tracks the watch app release gate. It focuses on packaging, WatchConnectivity behavior, and simulator evidence because no physical Apple Watch is available before App Store submission.

## Purpose / Big Picture

Sunclub's watch app must ship inside the iPhone app, mirror the phone's latest snapshot, support one-tap wrist logging, and keep the complication aligned with the same daily status. The release goal is to remove known packaging gaps and make phone-watch communication resilient to activation, reachability, and queued-delivery timing.

## Progress

- [x] (2026-04-14) Confirmed the pre-hardening iPhone simulator build only built `SunclubDev` and `SunclubDevWidgetsExtension`; the built app bundle had no `Watch/` content.
- [x] (2026-04-14) Wired the iPhone app target directly to the watch app target, which Tuist accepts and emits an `Embed Watch Content` phase for the built app artifact.
- [x] (2026-04-14) Hardened iPhone-to-watch snapshot pushes on activation and reachability changes.
- [x] (2026-04-14) Hardened watch-side refresh to use cached application context when the phone is not reachable.
- [x] (2026-04-14) Hardened wrist logging so failed reachable sends fall back to queued `transferUserInfo` delivery.
- [x] (2026-04-14) Added unit and metadata regression tests for watch payloads and Tuist watch packaging dependencies.
- [x] (2026-04-14) Regenerated the workspace and confirmed the generated app target dependency graph includes the watch app and watch extension.
- [x] (2026-04-14) Built the iPhone simulator app and inspected the built app bundle for watch content.
- [x] (2026-04-14) Built the watch widget extension target separately so complication code cannot silently rot outside the app scheme graph.
- [x] (2026-04-14) Ran unit tests, Python metadata tests, watch widget build, diff whitespace check, and lint.
- [x] (2026-04-14) Manually ran the iPhone and watch apps in paired simulators and verified snapshot refresh plus wrist logging.

## Decision Log

- Decision: Keep the watch app snapshot-only and phone-owned for writes.
  Rationale: The phone already owns SwiftData, CloudKit, widgets, and quick logging. Watch-side persistence remains a compact app-group snapshot to avoid a second data model before release.
  Date/Author: 2026-04-14 / Codex

- Decision: Queue wrist logs with `transferUserInfo` whenever a reachable `sendMessage` fails or the phone is unavailable.
  Rationale: Reachability can change between the button tap and message delivery. Queuing keeps the user's action durable until the iPhone app can process it.
  Date/Author: 2026-04-14 / Codex

- Decision: Treat the built iPhone app bundle as the packaging source of truth.
  Rationale: Generated watch schemes are not enough for App Store release. The app artifact must include watch content under its embedded watch path.
  Date/Author: 2026-04-14 / Codex

## Validation And Acceptance

1. `Sunclub` and `SunclubDev` app target graphs build the watch app and watch extension through the iPhone app scheme.
2. The built iPhone app artifact contains watch content under `Watch/`, not only iOS app extensions.
3. The watch app loads a cached snapshot when the iPhone is unreachable.
4. The watch app refreshes immediately when the iPhone becomes reachable.
5. Tapping `Log Sunscreen` on watch sends a live message when reachable and queues a log when delivery fails.
6. iPhone activation and reachability changes push the latest widget snapshot to the watch.
7. Unit and metadata tests cover payload round trips, malformed payloads, success/error replies, and Tuist packaging dependencies.
8. The watch widget extension target builds as a separate release check. The Tuist manifest currently cannot make the legacy `watch2App` target embed the watch WidgetKit extension without invalid target relationships, so the shippable artifact source of truth is the watch app plus WatchKit extension.

## Outcomes & Retrospective

- Fixed a release-blocking packaging gap where the iPhone app artifact did not include embedded watch content.
- Fixed a WatchKit install blocker by moving `WKAppBundleIdentifier` under `NSExtension.NSExtensionAttributes`.
- Hardened phone-to-watch delivery by pushing snapshots on activation and reachability, with application context, complication user info, and live messages when reachable.
- Hardened watch-to-phone logging by using live `sendMessage` when reachable and queued `transferUserInfo` when the phone is unavailable or delivery fails.
- Routed reachable wrist logs through the running iPhone `AppState` before falling back to the standalone SwiftData path, so foreground phone state and the watch reply stay aligned.
- Verified on a paired iPhone 17 / Apple Watch Ultra 3 simulator pair running iOS/watchOS 26.5: clean install, watch received the unlogged phone snapshot, tapping `Log Sunscreen` on watch sent a request with a reply handler, the phone accepted and replied, the phone app group snapshot recorded a one-day streak and today in `recordedDays`, and the watch refreshed to `Protected today`.
- Physical Apple Watch behavior remains untested because no device is available. The simulator also required explicit watch-app install after iPhone install, so final release confidence still depends on inspecting the archived/exported app artifact for embedded watch content before upload.
