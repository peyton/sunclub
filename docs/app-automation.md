# Sunclub App Automation

## Policy

- Default posture: maximum automation for non-destructive writes.
- Universal Links: deferred for this release. Do not add Associated Domains or `apple-app-site-association`.
- Direct writes: allowed for logging, reapply, reminders, supported toggles, and friend invite import. Friend poke automation returns a Message-first foreground route while public accountability transport is disabled for first App Store review.
- UI-only actions: destructive, review-heavy, permission-only, camera, and file-picker flows open Sunclub instead of running in the background.
- Storage: automation preferences live in the Codable growth settings store, not SwiftData.

## Settings Knobs

- `shortcutWritesEnabled`: blocks App Intent writes when off.
- `urlOpenActionsEnabled`: blocks URL routes that open app screens when off.
- `urlWriteActionsEnabled`: blocks URL and x-callback writes when off.
- `callbackResultDetailsEnabled`: removes action-specific callback fields when off.
- Location: Settings -> Automation.
- Website: `/docs/automation/`.

## App Intents

- `Log Sunscreen`: optional SPF and notes.
- `Save Sunscreen Log`: today or a selected date/time, optional SPF and notes.
- `Log Reapply`: increments today's reapply count.
- `Get Sunclub Status`: returns today logged state, streak, weekly applied count, and message.
- `Time Since Last Sunscreen`: returns minutes since the last log or reapply.
- `Open Sunclub`: opens a supported app route.
- `Set Sunclub Reminder`: updates weekday or weekend reminder time.
- `Set Sunclub Reapply Reminder`: turns reapply reminders on or off and can update the interval.
- `Set Sunclub Toggle`: updates travel timezone, streak-risk, live UV, daily UV briefing, extreme UV alert, iCloud sync, or HealthKit.
- `Export Sunclub Backup`: returns an `IntentFile`.
- `Create Skin Health Report`: returns an `IntentFile`.
- `Create Streak Card`: returns an `IntentFile`.
- `Import Friend Invite`: imports a Sunclub friend invite code.
- `Poke Friend`: uses a friend `AppEntity` query. First-review builds do not send a direct CloudKit poke; they return a Friends route so the user can message locally.

## App Shortcuts

- Discoverable shortcuts include Log Sunscreen, Log Reapply, Get Sunclub Status, Time Since Last Sunscreen, Open Automation, Export Backup, Create Skin Health Report, and Create Streak Card.
- File-producing App Intents return files through Shortcuts and are shown separately from URL examples in the in-app Automation catalog.
- The in-app catalog intentionally disables the Test button for URL examples that need a real friend invite code or saved friend UUID.

## URL Scheme

- Production scheme: `sunclub`.
- Development scheme: `sunclub-dev`.
- Direct host: `sunclub://automation/...`.
- x-callback host: `sunclub://x-callback-url/...`.
- Legacy hosts kept: `sunclub://widget/...`, `sunclub://accountability/...`.

## Direct URL Actions

- `log-today?spf=50&notes=Beach%20bag`
- `save-log?date=YYYY-MM-DD&time=HH:mm&spf=50&notes=Morning`
- `reapply`
- `status`
- `time-since-last-application`
- `set-reminder?kind=weekday|weekend&time=HH:mm`
- `set-reapply?enabled=true&interval=120`
- `set-toggle?name=travelTimeZone|streakRisk|liveUV|dailyUVBriefing|extremeUVAlert|iCloudSync|healthKit&enabled=true`
- `import-friend?code=...`
- `poke-friend?id=<uuid>` opens Friends with `status=needs-message` while public accountability transport is disabled.
- `open?route=home|log|reapply|summary|history|settings|automation|achievements|friends|health-report|product-scanner|recovery`

URL validation is strict for typed fields. Malformed dates, times, non-numeric SPF values, invalid routes, invalid reminder kinds, invalid toggles, invalid booleans, and invalid UUIDs fail parsing before any write runs. Valid SPF values are normalized to `1...100`. Notes are trimmed and capped at 280 characters.

## x-callback-url

- Success callback: `x-success=<url>`.
- Error callback: `x-error=<url>`.
- Cancel callback: accepted for compatibility, not used by current actions.
- Success fields with details on: `action`, `status`, `message`, plus action fields when present.
- Error fields with details on: `action`, `errorCode`, `errorMessage`.
- Details off: success returns only `action` and `status`; error returns only `action` and `status`.
- UI-only success: `status=opened`.

## Callback Result Fields

- `currentStreak`
- `todayLogged`
- `weeklyApplied`
- `recordDate`
- `lastAppliedAt`
- `minutesSinceLastApplication`
- `friend`
- `fileName`
- `fileType`

## Excluded Direct Writes

- Delete log.
- Remove friend.
- Backup import.
- Recovery undo/redo.
- Conflict resolution.
- Camera scanning.
- File picking.
- Permission-only setup.

## Runtime Requirements

- Outside-app writes go through `SunclubAutomationRuntime`.
- Logging, save-log, and reapply write through `SunclubHistoryService`.
- Outside-app writes must refresh projected state and widget snapshots.
- Duplicate same-day logs update the existing day rather than adding another visible day.
- Optional SPF and notes behavior must match the manual log flows, including SPF clamping and the 280-character note limit.

## Testing Requirements

- Unit: parser round-trips every supported direct and x-callback action.
- Unit: malformed automation links fail before creating requests or mutating app state.
- Unit: callback success and error payloads encode correctly.
- Unit: settings toggles block URL and Shortcut writes while preserving open-only routing rules.
- Unit: automation logging uses revision history and refreshes widget snapshots.
- Unit: old growth settings payloads decode with default automation preferences.
- Unit: file-producing intents return expected file metadata.
- Unit: friend query, invite import, and Message-first poke paths work with seeded friends.
- UI: Settings exposes Automation controls, copy buttons, and test buttons.
- UI: `sunclub-dev://x-callback-url/open?route=automation` opens Automation.
- UI: URL write disable blocks mutation and routes to foreground UI.
- UI: Automation remains usable under Dynamic Type, dark mode, increased contrast, Reduce Motion, and Differentiate Without Color.
- Web: `/docs/automation/` is required by the static site validator and sitemap.

## Future Feature Checklist

- App Intent: add one, or document why the feature is UI-only.
- URL/x-callback: add a direct route, or document why the feature must open UI.
- Settings: expose user-visible automation knobs when the feature writes or returns sensitive data.
- Tests: add parser, runtime, intent, UI, or web coverage matching the surface.
- Docs: update this file, website automation docs, and adjacent product docs.
