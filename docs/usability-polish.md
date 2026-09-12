# Usability polish

Focus: accurate application times, obvious editing, fewer distractions, and the
cream/amber palette of the shipped icon. Existing identities, schemas, routes,
platforms, recovery and synchronization remain intact.

## Findings and changes

The live Simulator audit captured Today, the editor and History before changes.
Visual findings below refer to those steps; validation findings were reproduced
with unit tests or traced through the save path. Screenshots are local evidence
under `.build/polish-audit/`.

| #   | Surface         | Finding and change                                                                                                             |
| --- | --------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| 1   | Shared palette  | Peach surfaces and reddish controls mismatched the icon; use cream and readable amber tones.                                   |
| 2   | Dark appearance | Cocoa surfaces diverged from the dark icon; use neutral charcoal with warm accents.                                            |
| 3   | Empty Today     | Correcting an earlier application required first logging now; expose Log earlier.                                              |
| 4   | Today           | The displayed time was inert; tapping it opens the shared editor.                                                              |
| 5   | History         | Application rows were inert; each row now opens editing with a chevron.                                                        |
| 6   | Editor          | Latest reapplication time was read-only; expose its saved time beside the first application.                                   |
| 7   | Editor          | A first application could be moved after reapplication; reject invalid ordering before any field saves.                        |
| 8   | Manual save     | A timestamp from another day was accepted; reject it.                                                                          |
| 9   | Reapplication   | A timestamp could be attached to another day; reject it in the shared mutation service.                                        |
| 10  | Reapplication   | A time before the first application was accepted; reject it.                                                                   |
| 11  | Reapplication   | Backdating a reapplication moved the latest time backward; retain the maximum timestamp.                                       |
| 12  | Editor          | An open draft could overwrite newer data; compare captured identity and projection before saving.                              |
| 13  | Editor          | Saving after deletion could recreate a log; reject deleted or replaced edit targets.                                           |
| 14  | Editor          | Time and detail corrections need one durable outcome; save them in one revision, preserving counts and verification metadata.  |
| 15  | Editor          | Cancel or sheet dismissal could lose changes; confirm discard and block dirty swipe dismissal.                                 |
| 16  | Editor          | Save was a small floating text-sized target; make it full-width and at least 44 points high.                                   |
| 17  | Editor          | Optional fields overwhelmed a time correction; put them behind Details.                                                        |
| 18  | Editor          | Repeated optional labels and a duplicate SPF-selection sentence added noise; remove them while retaining selection cues.       |
| 19  | Editor          | An always-visible character budget distracted from notes; show it only near the limit.                                         |
| 20  | Editor          | Note suggestions could replace typed text; show them only for empty notes and omit reuse suggestions when editing a saved log. |
| 21  | Editor          | Notes had no explicit keyboard dismissal control; add keyboard Done.                                                           |
| 22  | SPF sheet       | Common SPF changes required repeated stepper taps; add 15/30/50 shortcuts while retaining precise adjustment.                  |
| 23  | SPF sheet       | Default-setting implementation details cluttered the form; remove the explanatory paragraph.                                   |
| 24  | History         | An unconfirmed departure hid the applied checkmark; an actual application takes precedence.                                    |
| 25  | Check-in        | Quick relative times could cross midnight and fail after tapping; disable choices outside the current day.                     |
| 26  | Reapply         | A duplicate relative timestamp crowded the count and drifted from the injected clock; retain the absolute latest-time summary. |
| 27  | Editor          | Dates omitted the year when editing older history; include it.                                                                 |
| 28  | Large text      | Side-by-side timestamp labels broke into narrow fragments; stack labels above pickers at accessibility sizes.                  |

Custom SPF values remain visible as selected chips. Earlier reapplication times
that were never persisted are still reported as unavailable; this pass does not
invent them or change the schema. New controls use the existing foreground
manual-log/History routes. No new background automation action is introduced.

## Verification

Regression coverage includes wrong-day timestamps, invalid ordering, stale/deleted
drafts, atomic field preservation, latest-time retention, unchanged saves and
failed-save rollback. UI coverage exercises direct time/row editing, both time
pickers, the Details disclosure, discard protection, and Log earlier.

The normal accessibility, unit, Python and exact-source GitHub CI gates apply.
Physical-device HealthKit and background notification delivery cannot be proved
by Simulator screenshots; the existing successful-save effects are retained.
