# Improvements Batch (2026-04-09)

Ten fixes across bugs, crash safety, UX, accessibility, reliability, and performance.

## Bug Fixes

### 1. Duplicate `widgetSnapshotStore` parameter in AppState.init

**File:** `app/Sunclub/Sources/Services/AppState.swift`

The designated initializer declared `widgetSnapshotStore` twice. The second parameter shadowed the first. Removed the duplicate.

### 2. SunclubSchemaV3 missing frozen model definitions

**File:** `app/Sunclub/Sources/Models/SunclubSchema.swift`

V3 referenced top-level `DailyRecord.self` and `Settings.self` instead of defining frozen inner `@Model` classes like V1 and V2. This meant the schema declaration used current (V4-era) model shapes, which is incorrect for a versioned schema.

**Changes:**

- Added frozen `@Model` inner classes to `SunclubSchemaV3` matching the schema at that version
- Updated V2->V3 migration to use `SunclubSchemaV3.DailyRecord` and `SunclubSchemaV3.Settings`
- Updated `LegacyStoreFixture.seedCurrentV3Store` to use the frozen V3 types

### 3. UV heuristic assumes Northern Hemisphere

**File:** `app/Sunclub/Sources/Services/UVIndexService.swift`

`estimatedUVIndex(at:calendar:)` hardcoded month-to-UV mappings for the Northern Hemisphere. Southern Hemisphere users received inverted UV estimates (low in their summer, high in their winter).

**Changes:**

- Added `latitude: Double?` parameter to `estimatedUVIndex`
- When latitude is negative, months are shifted by 6 to invert the seasonal mapping
- `UVIndexService` stores `lastKnownLatitude` from successful WeatherKit fetches and passes it to the heuristic fallback

## Crash Safety

### 4. Force-unwraps in HistoryView.statsSection

**File:** `app/Sunclub/Sources/Views/HistoryView.swift`

Three force-unwraps (`!`) on Calendar date arithmetic in `statsSection`. Replaced with `??` fallbacks to prevent potential crashes on edge-case dates.

## UX

### 5. Delete record without confirmation

**File:** `app/Sunclub/Sources/Views/HistoryView.swift`

The "Delete" button in history day detail immediately deleted a record with no confirmation. Added a `.confirmationDialog` requiring explicit confirmation before destructive deletion.

## Accessibility

### 6. Missing accessibility label on greeting symbol

**File:** `app/Sunclub/Sources/Views/HomeView.swift`

The greeting symbol (`sun.max` / `moon.stars`) in the HomeView header had no `.accessibilityLabel`. VoiceOver users couldn't identify the icon. Added "Daytime" / "Nighttime" labels.

### 10. Missing accessibility identifiers on streak card content

**File:** `app/Sunclub/Sources/Views/HomeView.swift`

The "Day Streak" label and "Best: N" text inside the streak card lacked `.accessibilityIdentifier`s, making them difficult to target in UI tests. Added `home.dayStreakLabel` and `home.longestStreak`.

## Reliability

### 7. Silent `try? modelContext.save()` in AppState.save()

**File:** `app/Sunclub/Sources/Services/AppState.swift`

`save()` used `try?` which silently swallowed errors. Replaced with `do/catch` that logs failures via `os.Logger`.

### 8. `refresh()` catch block silently clears all data

**File:** `app/Sunclub/Sources/Services/AppState.swift`

On any error, `refresh()` blanked all records, making the UI show empty state. Now:

- Logs the error
- Sets `lastRefreshError` for UI consumption
- Only clears state if no prior data exists (preserves stale data over empty state)

## Performance

### 9. Duplicate `recordStartsForTesting()` calls in HistoryView

**File:** `app/Sunclub/Sources/Views/HistoryView.swift`

`appState.recordStartsForTesting()` was called once in `calendarGrid` and again in `statsSection`, fetching and processing all records twice per render. Refactored to compute once in `body` and pass to both sections.

## Tests

New test file: `app/Sunclub/Tests/ImprovementTests.swift`

- Migration tests for V2->V3 and V3->V4 with frozen types
- Full V1->V4 migration path test
- UV heuristic tests for Northern Hemisphere, Southern Hemisphere, nil latitude, and nighttime
- AppState `lastRefreshError` property tests
