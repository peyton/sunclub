# Timeline Date Safety

## Why

Timeline logging now uses an explicit logging context (`date`, `dayPart`, `source`) to avoid accidental writes to the wrong day.

## Behavior

- Future days remain viewable in debug and UI-test sessions, but writes are blocked at write time.
- All timeline and manual-log writes normalize to the local start-of-day for the selected target date.
- Midnight no longer causes an implicit "today" fallback that can backfill the following day.
- Morning, evening, and night are explicit states in timeline and manual log actions.

## Compatibility

- Existing `manualLog` routes still work without payload context.
- When no payload is provided, route handling falls back to the currently selected timeline day.
