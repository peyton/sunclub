# Sunclub App Automation

## Policy

- Default posture: maximum automation for non-destructive writes.
- Universal Links: deferred for this release. Do not add Associated Domains or `apple-app-site-association`.
- Direct writes: allowed for logging, reapply, reminders, supported toggles, and export-only history files. Prototype sharing links remain parseable for older Shortcuts but route to Settings in this release.
- UI-only actions: destructive, review-heavy, permission-only, camera, and file-picker flows open Sunclub instead of running in the background.
- Storage: automation preferences live in the Codable growth settings store, not SwiftData.

## Settings Knobs

- `shortcutWritesEnabled`: blocks App Intent writes when off.
- `urlOpenActionsEnabled`: blocks URL routes that open app screens when off.
- `urlWriteActionsEnabled`: blocks URL and x-callback writes when off.
- `callbackResultDetailsEnabled`: removes action-specific callback fields when off.
- Location: Settings -> Connect Shortcuts.
- Website: `/docs/automation/`.

## App Intents

- `Log Sunscreen`: optional SPF and notes.
- `Save Sunscreen Log`: today or a selected date/time, optional SPF and notes.
- `Log Reapply`: increments today's reapply count.
- `Get Sunclub Status`: returns today logged state, weekly logged count, reapply status, and message.
- `Time Since Last Sunscreen`: returns minutes since the last log or reapply.
- `Open Sunclub`: opens a supported app route.
- `Set Sunclub Reminder`: updates weekday or weekend reminder time.
- `Set Sunclub Reapply Reminder`: turns reapply reminders on or off and can update the interval.
- `Set Sunclub Toggle`: updates travel timezone, daily UV briefing, extreme UV alert, iCloud sync, or Apple Health availability settings.
- `Export Sunclub Backup`: returns an `IntentFile`.
- `Export Sunclub History`: returns a PDF `IntentFile`.

## App Shortcuts

- Discoverable shortcuts include Log Sunscreen, Log Reapply, Get Sunclub Status, Time Since Last Sunscreen, Open Shortcuts, Export Backup, and Export Sunclub History.
- File-producing App Intents return files through Shortcuts and are shown separately from URL examples in the in-app Shortcuts catalog.
- The in-app catalog includes only deterministic P0 examples.

## URL Scheme

- Production scheme: `sunclub`.
- Development scheme: `sunclub-dev`.
- Direct host: `sunclub://automation/...`.
- x-callback host: `sunclub://x-callback-url/...`.
- Legacy hosts kept: `sunclub://widget/...`, `sunclub://accountability/...`. Accountability links are compatibility-only and route to Settings.

## Direct URL Actions

- `log-today?spf=50&notes=Beach%20bag`
- `save-log?date=YYYY-MM-DD&time=HH:mm&part=morning|afternoon|evening|night&spf=50&notes=Morning`
- `reapply`
- `status`
- `time-since-last-application`
- `set-reminder?kind=weekday|weekend&time=HH:mm`
- `set-reapply?enabled=true&interval=120`
- `set-toggle?name=travelTimeZone|dailyUVBriefing|extremeUVAlert|iCloudSync|healthKit&enabled=true`
- `open?route=home|log|reapply|summary|history|settings|automation|uv-forecast|privacy|support|recovery`

Compatibility routes are normalized before display: `achievements` opens Insights, `friends` opens Settings, `health-report` opens History, and `product-scanner` opens Log Sunscreen.

URL validation is strict for typed fields. Malformed dates, times, day parts, non-numeric SPF values, invalid routes, invalid reminder kinds, invalid toggles, invalid booleans, and invalid UUIDs fail parsing before any write runs. Valid SPF values are normalized to `1...100`. Notes are trimmed and capped at 280 characters.

Future dates are always view-only. `log-today` and `save-log` reject future targets at write time with an explicit error.

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
- `fileName`
- `fileType`

## Excluded Direct Writes

- Delete log.
- Backup import.
- Recovery undo/redo.
- Conflict resolution.
- Camera scanning.
- File picking.
- Permission-only setup.
- Live UV enablement, because turning it on can prompt for location permission; automations should open Settings instead.

## Runtime Requirements

- Outside-app writes go through `SunclubAutomationRuntime`.
- Logging, save-log, and reapply write through `SunclubHistoryService`.
- Outside-app writes must refresh projected state and widget snapshots.
- Duplicate same-day logs update the existing day rather than adding another visible day.
- Timeline/manual logging uses an explicit `{date, dayPart, source}` context and does not silently fall back to wall-clock `Date()`.
- Day parts are morning 5 AM-12 PM, afternoon 12-6 PM, evening 6-9 PM, and night 9 PM-5 AM.
- Optional SPF and notes behavior must match the manual log flows, including SPF clamping and the 280-character note limit.

## Testing Requirements

- Unit: parser round-trips every supported direct and x-callback action.
- Unit: malformed automation links fail before creating requests or mutating app state.
- Unit: callback success and error payloads encode correctly.
- Unit: settings toggles block URL and Shortcut writes while preserving open-only routing rules.
- Unit: automation logging uses revision history and refreshes widget snapshots.
- Unit: old growth settings payloads decode with default automation preferences.
- Unit: file-producing intents return expected file metadata.
- UI: Settings exposes Shortcuts controls, copy buttons, and test buttons.
- UI: `sunclub-dev://x-callback-url/open?route=automation` opens Shortcuts.
- UI: URL write disable blocks mutation and routes to foreground UI.
- UI: Shortcuts remains usable under Dynamic Type, dark mode, increased contrast, Reduce Motion, and Differentiate Without Color.
- Web: `/docs/automation/` is required by the static site validator and sitemap.

## Future Feature Checklist

- App Intent: add one, or document why the feature is UI-only.
- URL/x-callback: add a direct route, or document why the feature must open UI.
- Settings: expose user-visible automation knobs when the feature writes or returns sensitive data.
- Tests: add parser, runtime, intent, UI, or web coverage matching the surface.
- Docs: update this file, website automation docs, and adjacent product docs.
