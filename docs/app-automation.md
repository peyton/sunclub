# Sunclub App Automation

## Policy

- Default posture: maximum automation for non-destructive writes.
- Universal Links: deferred for this release. Do not add Associated Domains or `apple-app-site-association`.
- Direct writes: allowed for logging, reapply, reminders, supported toggles, and export-only history files. Prototype sharing links remain parseable for older Shortcuts but route to Settings in this release.
- UI-only actions: destructive, review-heavy, permission-only, camera, and file-picker flows open Sunclub instead of running in the background.
- Storage: automation preferences use the app-group growth settings store and are mirrored into the versioned private settings envelope for backup and private iCloud restore.

## Settings Knobs

- `shortcutWritesEnabled`: blocks user-run Shortcut/App Intent writes when off. App-owned widget and Control Center buttons use the widget invocation path below.
- `urlOpenActionsEnabled`: blocks URL routes that open app screens when off.
- `urlWriteActionsEnabled`: blocks URL and x-callback writes when off.
- `callbackResultDetailsEnabled`: removes action-specific callback fields when off.
- Location: Settings -> Shortcuts. This page contains the four permission controls and one link to the catalog.
- Website: `/docs/automation/`.

## App Intents

- `Log Sunscreen`: optional SPF and notes.
- `Save Sunscreen Log`: today or a selected date/time, optional SPF and notes.
- `Log Reapply`: increments today's reapply count.
- `Get Sunclub Status`: returns today logged state, weekly logged count, reapply status, and message.
- `Time Since Last Sunscreen`: returns minutes since the last log or reapply.
- `Open Sunclub`: opens a supported app route, including Sunscreen and Apple Health settings.
- `Set Sunclub Reminder`: updates weekday or weekend reminder time.
- `Set Sunclub Reapply Reminder`: turns reapply reminders on or off and can update the interval.
- `Set Sunclub Toggle`: updates travel timezone, daily UV briefing, extreme UV alert, iCloud sync, or the Apple Health preference. Health authorization is managed in foreground Settings.
- `Export Sunclub Backup`: returns an `IntentFile`.
- `Export Sunclub History`: returns a PDF `IntentFile`.
- `Create Logged Days Card`: returns a shareable image `IntentFile`.
- Widget and Control Center buttons use a non-discoverable adaptive logging intent. The first action logs sunscreen; later actions log a reapplication in place, including when reapply reminders are off or no reminder is due. These app-owned actions do not open Sunclub or inherit user Shortcut toggles. User-run Shortcuts still expose Log Reapply separately.
- Notification actions use the same runtime: `Reapplied now` performs a durable reapply write, while `Snooze 30 min` schedules one bounded local reminder.

## App Shortcuts

- Discoverable shortcuts include Log Sunscreen, Log Reapply, Get Sunclub Status, Time Since Last Sunscreen, Open Shortcuts, Export Backup, and Export Sunclub History.
- File-producing App Intents return files through Shortcuts and are shown separately from URL examples in the in-app Shortcuts catalog.
- Catalog action names come from the shipped App Intent titles. App Shortcut tile labels may be shorter, such as `Open Shortcuts` for `Open Sunclub`.
- Advanced direct URL and callback examples start collapsed. Write examples offer Copy only; Test is available only for read/open examples. Public writes remain available to authorized callers.
- The catalog links back to the four permission controls. It does not install Shortcuts or provide an Ask Before Running setting; execution confirmation belongs to the Shortcuts app.

## URL Scheme

- Production scheme: `sunclub`.
- Development scheme: `sunclub-dev`.
- Direct host: `sunclub://automation/...`.
- x-callback host: `sunclub://x-callback-url/...`.
- Legacy widget host: `sunclub://widget/...`.

## Direct URL Actions

- `log-today?spf=50&notes=Beach%20bag`
- `save-log?date=YYYY-MM-DD&time=HH:mm&part=morning|afternoon|evening|night&spf=50&notes=Morning`
- `reapply`
- `status`
- `time-since-last-application`
- `set-reminder?kind=weekday|weekend&time=HH:mm`
- `set-reapply?enabled=true&interval=120`
- `set-toggle?name=travelTimeZone|dailyUVBriefing|extremeUVAlert|iCloudSync|healthKit&enabled=true`
- `open?route=home|log|reapply|summary|history|settings|settings-sunscreen|settings-health|automation|uv-forecast|privacy|support|recovery`

The app has Today, History, and Settings tabs. Today acts on the current local day; date browsing and editing live in History. The existing `summary` URL and `weeklySummary` app route open read-only seven-day Insights inside History; Back returns to History.

Foreground Settings destinations:

| Public route         | Open Sunclub choice | App destination              |
| -------------------- | ------------------- | ---------------------------- |
| `settings-sunscreen` | Sunscreen           | `AppRoute.settingsSunscreen` |
| `settings-health`    | Apple Health        | `AppRoute.settingsHealth`    |

Examples: `sunclub://automation/open?route=settings-sunscreen` and `sunclub://x-callback-url/open?route=settings-health&x-success=shortcuts://callback`. Both schemes and hosts accept both destinations. Opening these screens does not save a sunscreen profile or request Health authorization. Profile editing and permission setup remain foreground interactions. URL opens require `urlOpenActionsEnabled`; disabling URL or Shortcut writes does not block them. Existing callback result-detail preferences still apply.

The foreground reapply check-in remains available after today's first log even with reminders off. Recording and notification preferences are independent; snooze appears only when reapply reminders are enabled. Existing Log Reapply intents and URL actions continue through the shared mutation runtime.

Compatibility routes are normalized before display: `achievements` opens weekly insights inside History, `health-report` opens History, and `product-scanner` opens Log Sunscreen.

Legacy app destinations `settingsSunscreenReminders`, `settingsReapplyReminder` and `settingsNotifications` remain accepted and show the consolidated Reminders page. These AppRoute names are not additional public URL route values.

Widget status links open Today. The legacy `updateToday` widget route still opens the existing editor for callers that already use it.

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
- Widget and Control Center writes use `SunclubAutomationInvocation.widget`; user Shortcut writes use `SunclubAutomationInvocation.shortcut`; URL and x-callback writes use `SunclubAutomationInvocation.url`.
- Logging, save-log, and reapply write through `SunclubHistoryService`.
- Outside-app writes must refresh projected state and widget snapshots.
- Duplicate same-day logs update the existing day rather than adding another visible day.
- Foreground log editors use a fixed `{date, dayPart, source}` context; users select dates in History. Today stays anchored to the current local day through midnight and foreground transitions.
- Day parts are morning 5 AM-12 PM, afternoon 12-6 PM, evening 6-9 PM, and night 9 PM-5 AM.
- Optional SPF and notes behavior must match the manual log flows, including SPF clamping and the 280-character note limit.
- New one-tap logs prefer the most recent recorded SPF, then the saved sunscreen profile SPF. Structured covered areas come only from prior logs; free-form notes are never copied automatically.
- A successful response is returned only after the revision-history transaction commits. Failed writes leave existing data and follow-up reminders unchanged.
- No-op saves do not emit success effects or reschedule reminders. Ephemeral Undo validates its receipt against the current day before applying; an intervening edit or replacement must remain intact.

## Testing Requirements

- Unit: parser round-trips every supported direct and x-callback action.
- Unit: malformed automation links fail before creating requests or mutating app state.
- Unit: callback success and error payloads encode correctly.
- Unit: settings toggles block URL and Shortcut writes while preserving open-only routing rules.
- Unit: widget invocation adaptively logs the first sunscreen application and later reapplications in place, even when URL and Shortcut writes are disabled or reapply reminders are off or not due.
- Unit: automation logging uses revision history and refreshes widget snapshots.
- Unit: old growth settings payloads decode with default automation preferences.
- Unit: file-producing intents return expected file metadata.
- Unit: new Settings routes parse, preserve their destination through App Intent conversion and URL encoding, respect URL-open permissions, and do not mutate profile/Health data when opened.
- UI: Settings exposes four Shortcuts permissions and one catalog link; advanced examples start collapsed, write examples are copy-only, and read/open examples retain Test.
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

## Departure check-ins

Optional Home monitoring records the first qualifying departure from 06:00–19:59 as **Unconfirmed**, separately from applications. No log or streak is inferred. `Update Sunscreen Check-in` can confirm an actual application time, snooze 15 minutes, or dismiss today's check-in. Shortcut writes and URL writes retain their existing independent permission gates; app-owned notification/widget actions use the app-owned invocation.

- `sunclub://automation/open?route=departure-check-in` opens the time chooser.
- `sunclub://automation/confirm-check-in?id=<UUID>&applied-at=<ISO8601 timestamp>` confirms the selected time; omitting `id` selects today's unresolved event.
- `sunclub://automation/snooze-check-in?id=<UUID>` and `sunclub://automation/dismiss-check-in?id=<UUID>` update the check-in without logging sunscreen.
- The same actions support existing `x-callback-url` handling. Invalid IDs/times are rejected; stale/resolved events cannot overwrite a newer application.
- `sunclub://widget/open/departure-check-in` is the app-owned foreground time chooser. Small/accessory widgets open it; larger widgets and Live Activities also offer snooze and dismiss.

Confirmation commits application and check-in resolution together. Existing app, Watch, widget and automation logging also resolves an unconfirmed event in the same history batch. Undo restores both. Check-in snapshots and revisions survive backup, import/export, CloudKit and reinstall recovery; they never increase application totals.

Live Activities have an independent Settings switch, enabled by default. Foreground logging and supported Live Activity intents may start a session. Background departure detection relies on local notifications and widgets; it does not guarantee an automatic Live Activity launch. A snooze changes the reminder deadline, never the application timestamp. Reminder schedules repair automatically; legacy repair entrypoints remain compatible.
