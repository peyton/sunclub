# Sunclub App Spec

## Product

Sunclub is a local-first iOS sunscreen tracker with Apple Watch, widgets, Control Center actions, Shortcuts, optional reminders and Apple Health integration. Default-on private iCloud sync, backup import/export and revision history preserve the user's data.

The main loop is: open Today, log sunscreen or a reapplication, and return to the day. History owns date browsing and editing. Settings owns preferences.

## Principles and scope

- One primary action per screen, using existing native navigation, Liquid Glass controls, design tokens and bundled SVG icons.
- Logging works offline without an account, notification permission or location permission.
- Status reports recorded facts and UV provenance; a sunscreen log does not certify protection.
- Optional fields remain optional. Do not invent missing SPF, coverage or notes.
- Preserve existing platform targets, public automation routes, permission gates, persisted identities, signing identifiers and recovery behavior.
- No camera validation, bottle training, social onboarding, household sharing, subscription or purchase flow is required.
- Compatibility sharing identities, invites, connections and history remain stored and restorable. Removing their old navigation does not authorize deleting data or breaking older callers.

## Setup

1. Welcome offers Get Started.
2. Optional reminders offer Enable reminders and Not now.
3. Successful setup ends at Today, including after importing pending legacy invites.

Persist onboarding completion before scheduling notifications. Save failures keep setup open with accurate retry actions. Notification scheduling failure must say setup was saved and offer Retry reminders or Continue to Today. Continuing must not claim partially scheduled reminders were disabled.

Location and city selection are deferred to Settings or contextual UV setup. Notification denial does not block logging.

The initial iCloud restore gate remains before onboarding for an effectively empty production store. Fetch before publishing default state, rebuild projections on success, and expose retry/continue on restore failure. A returning user's meaningful history and completed onboarding must not be replaced by empty defaults.

## Today

- Show the current local date, compact UV context, truthful log status and one primary action: Log sunscreen, then Log reapplication after the first log.
- Anchor reads and writes to the current local day across midnight and foreground transitions.
- Show actual UV source and freshness, cached/local estimates and unavailable states. Keep the hourly forecast accessible.
- A successful changed receipt provides concise confirmation with Undo and optional Edit; duplicate submissions are guarded.
- Safe receipt Undo refuses to overwrite newer edits or replacement records. Failures remain visible and actionable.
- Keep optional editing available without making it a prerequisite for a quick log.
- Hide inactive reminder details and missing metadata. Reapply logging remains available when reminder notifications are off.
- Date scrubbers, past/future day detail and horizontal date gestures belong outside Today.
- Keep Today, History and Settings as native tabs with their own navigation context.

## History and log editing

- History starts with week selection and grouped records for the selected day. Keep the full calendar and read-only Insights reachable.
- Pick the date in History, then open one fixed-date editor for a new or existing log. Future dates remain read-only.
- The shared editor contains time, optional SPF, optional coverage, optional notes, Save and Cancel. Label the first application time accurately when reapplications exist.
- Explicit edits can clear SPF and notes. Clearing is different from an additive application with omitted metadata.
- Coverage metadata and prose share the existing 280-character serialized note limit. Preserve complete valid coverage and existing draft text; show an actionable validation error instead of silently truncating.
- Only complete valid Areas metadata is interpreted as coverage. Ordinary prose beginning with Areas remains prose.
- Historical logs with no coverage keep it unspecified. Explicit suggestion reuse updates SPF, prose and coverage together; suggestions display prose only.
- New one-tap logs prefer recent recorded SPF, then saved sunscreen profile SPF. Reuse only valid structured coverage from prior logs; never copy free-form notes automatically.
- Successful no-op saves may dismiss without extra success effects or reminder rescheduling.
- Reapplication rows are informational, with one explicit Edit log action.
- Delete requires the existing confirmation. Receipt Undo must not replace a newly created record for that day.

## Insights

- Open from History and return to History with native Back or the supported gesture.
- Show read-only activity for the last seven days including today, plus streak.
- Keep the view unboxed and easy to scan, with an accessible list alternative.
- Do not require a 30-day score, typical application time, UV-rate analysis, advice, SPF/note recaps, day-editor interactions or a floating History button.
- Preserve the public summary and achievement compatibility destinations by routing them here.

## Settings

The top level contains eight destinations:

| Destination     | Responsibility                                                                                                                                                |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Sunscreen       | Save, edit or remove the existing sunscreen profile: name, SPF and water-resistance label. Reuse the current profile persistence API.                         |
| Reminders       | Daily weekday/weekend times, travel timezone, evening reminder, reapply interval and leave-home controls together. Diagnostic tools stay behind Troubleshoot. |
| UV & Weather    | Use current location, saved city selection/removal, UV status and fallback behavior, daily briefing and extreme alerts.                                       |
| Apple Health    | Optional Health integration; display the persisted authorization outcome and reconcile delayed authorization with the user's current choice.                  |
| iCloud & Backup | Sync preference/status, Export backup, Import backup, pending imports and Recovery & Changes.                                                                 |
| Shortcuts       | Four automation permissions and one catalog link.                                                                                                             |
| Privacy         | Data practices, backup export and confirmed history deletion.                                                                                                 |
| Support         | Help, documentation and one email/feedback contact action.                                                                                                    |

Use short status descriptions only when useful. Save failures keep drafts and existing data available for retry. Legacy reminder destinations resolve to the single Reminders page; the legacy health/weather destination continues to show UV & Weather.

## Reminders, UV and Health

- Daily reminders support separate weekday and weekend times, anchored or travel-local timezone handling, and an optional evening reminder for an unlogged day.
- Leave-home reminders stay optional, support saving/resetting Home and explain required background location access. Preserve the scheduled daily fallback.
- Reapplication tracking is independent of notification preferences. Last logged uses the latest application timestamp. Snooze appears only when reminders are enabled.
- Reapply intervals use the saved preference and existing estimated-sunset scheduling rules; UI must not equate an estimate with a confirmed pending notification.
- Keep daily UV briefing, extreme alerts, source/freshness labels, saved-city weather, cached forecasts and local estimates.
- Location-denied users retain logging and normal scheduled reminders.
- Health remains optional and retains existing sample behavior. Foreground authorization and the saved preference determine the visible control state.
- Daily notification routes open logging; weekly routes open Insights. Keep existing notification actions and bounded snooze behavior.

## Automation

The public contract is [App Automation](../docs/app-automation.md).

- Preserve supported App Intent writes, status reads, foreground opens, file exports, widget and Control Center actions.
- Support production `sunclub` and development `sunclub-dev` schemes, direct automation URLs and x-callback-url requests.
- Open Sunclub offers Sunscreen and Apple Health settings. Public route values are `settings-sunscreen` and `settings-health`; opening them does not save a profile or request permission.
- Keep four independent controls: Shortcut writes, URL opens, URL writes and callback result details.
- URL write denial does not block permitted foreground opens. URL-open denial still blocks new settings destinations. User Shortcut write controls do not disable app-owned widget actions.
- The catalog uses shipped intent names, not invented action names or installation controls. Advanced URL/callback examples start collapsed; writes are copy-only, while read/open examples may offer Test.
- Execution confirmation belongs to Apple Shortcuts. Sunclub does not expose a static Ask Before Running pseudo-setting.
- Outside-app writes use the shared automation and revision-history services, and report success only after persistence succeeds. Failure does not publish success effects.
- Keep old widget/accountability hosts and compatibility route values. Legacy friends opens Settings, health-report opens History, product-scanner opens logging, and achievements opens Insights.
- Destructive, review-heavy, file-picker and permission setup flows open foreground UI. Legacy camera routes do not restore a camera-validation requirement.
- Universal Links remain deferred; do not add Associated Domains or an apple-app-site-association file.

## Widgets, Watch and controls

- Preserve all shipped targets, families, routes and signing identifiers.
- Keep Home Screen and Lock Screen widgets glanceable. Log Today completes in place when the day is open; logged state routes into the existing review/update flow.
- Mirror lightweight snapshots instead of opening the live SwiftData store from a widget.
- Refresh at local midnight; stale previous-day reapply timers must not appear on Today widgets or Watch.
- Keep Control Center logging, Summary and History actions and Apple Watch behavior.

## Data, backup and recovery

- Daily records and settings remain local-first projections of immutable revision history. SwiftData containers use SunclubModelContainerFactory.
- Keep private CloudKit history, default-on sync where supported, local pause/resume, offline usage and backup import/export.
- Empty startup state must never replace meaningful local or remote history. Completed onboarding wins over incomplete defaults during recovery.
- Backup import restores the phone first. Publishing imported changes to iCloud is an explicit action; import must not automatically publish deletions or rollbacks.
- Recovery & Changes shows imports, conflicts and supported undo/redo operations without changing older revisions in place.
- Publish, restore, undo and redo expose success/failure. Failed actions remain retryable; failed undo must not mark a conflict resolved.
- Undo Import restores pre-import preferences, including empty/default values, while preserving identifiable later edits and device-only preferences. If older or remote history cannot distinguish the changes safely, leave everything unchanged and explain the failure. Undo stays local, including after explicitly publishing the import.
- Ephemeral receipt Undo checks that the affected revision/projection is still current. Explicit historical recovery remains available separately.
- No-op changes do not schedule extra effects. Preserve streak continuity through projection and conflict handling.
- Preserve old supported stores, schema migrations, private settings envelopes and compatibility identities. Persisted-field changes require a new immutable versioned schema and prior-store migration coverage.

## Accessibility and verification

Preserve VoiceOver, Voice Control, Dynamic Type through accessibility sizes, Dark Interface, Differentiate Without Color, contrast and Reduce Motion. Use named controls, non-color status cues, at least 44-point interaction targets and SunMotion. UI tests keep UITEST_MODE and deterministic UITEST_FORCE_* overrides.

Use behavioral regressions for writes, clears, routing, failure handling, permission gates and stale Undo. Verify native Back and gestures, not only screenshots. Keep test and production navigation behavior aligned.

Release candidates require the repository's data, accessibility and automation gates, plus full CI on the exact candidate SHA. Signing, store and sync changes retain their additional release evidence requirements.

## Success criteria

- A new user can reach Today after optional reminders without location or camera setup.
- A returning user can log or reapply in one primary action, then optionally edit or safely undo.
- History supports date selection and corrections without stale-field overwrites; Insights explains the last seven days without extra editing controls.
- Settings makes Sunscreen, reminders, UV, Health, backup, automation, privacy and help easy to find.
- Existing automation callers, private data, backups and recovery remain usable.
