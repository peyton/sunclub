# App Store 3.0.4 review

Reviewed November 12, 2026. The package presents Sunclub as a simple sunscreen
tracker: log from Today, reapply, add optional details, check UV, and review the
routine. Full listing text is in the [review package](app-store-review-package.md).
All screenshot history and selections are example fixtures, not personal records.

## Binary evidence

- Version **3.0.4**, build **20261112.101.2**, source
  `2e03320b36542aa09c4a9adc2d2c3a4d662dc611`.
- [Full CI on the exact binary source](https://github.com/peyton/sunclub/actions/runs/43297637690)
  passed, including **92/92 UI tests with no UI skips**. Hosted unit tests passed
  645 checks; the 15 source-audit checks skipped by the runner passed locally.
- [Release attempt 2](https://github.com/peyton/sunclub/actions/runs/43306776361/attempts/2)
  exported and uploaded this build. Its pre-upload checks passed signed
  entitlements, nested identifiers/signatures, and embedded Watch diagnostics.
- App Store Connect subsequently showed the processed binary as **Validated**.
  Recorded metadata and entitlements:
  `.build/appstore-submission-3.0.4/processed-build-verification.json`.

The release runner lost network access after upload, preventing retention of the
exported IPA and raw diagnostics. Pre-upload validation logs and Apple's processed
build metadata are the evidence; a downloaded final IPA was not independently
inspected. The store preparation does not change the validated binary.

## Screenshot critique

Product Design review accepts the final captures below. Text and controls are
readable, primary actions are complete, and no collision or unintended clipping
remains in the selected images.

| Set        | Accepted assets                                                                                                               | Dimensions  |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------- | ----------- |
| iPhone     | Five composed images in `.build/appstore-screenshots/`; originals in `raw/`                                                   | 1320 × 2868 |
| iPad       | Five native images in `.build/appstore-submission-3.0.4/ipad/`                                                                | 2064 × 2752 |
| Duo closed | `daily-ritual-closed.png`, `reapply-time-closed.png`, `routine-history-closed.png` in `.build/appstore-submission-3.0.4/duo/` | 1398 × 2034 |
| Duo open   | `routine-history-open.png` in the same Duo directory                                                                          | 2007 × 2853 |
| Watch      | `.build/appstore-submission-3.0.4/watch/watch-log-sunscreen.png`                                                              | 422 × 514   |

The five phone/iPad subjects are `daily-ritual`, `reapply-time`, `log-spf`,
`uv-forecast`, and `routine-history`.

- **Today and reapplication:** The main logging action is prominent. The logged
  state explains the last application and next reapplication without extra steps.
- **Optional details:** The final phone capture uses a clean manual log with
  Details expanded, SPF 50 and Face selected. Time, SPF, coverage, the entire
  Notes field, and Save are visible. Earlier collapsed and crowded captures were
  rejected. The expanded iPad editor also shows all fields and Save.
- **UV:** Fresh isolated captures show current UV, peak, and hourly values.
  The caption promises current UV and the hourly forecast, both visible.
- **Insights:** Five logged days, seven activity markers, and the streak read
  clearly on phone, iPad, and both Duo displays.
- **Watch:** Ready to log, UV 0 · Low, and the entire Log sunscreen button fit
  cleanly. Only this Watch image is selected.

The composed phone header is simply “SUNCLUB.” Native content retains its actual
layout. The bounded iPad column and short Insights screen leave intentional space
below complete content; extra decoration would not improve the task.

## Listing and remaining limits

The public App Store, marketing, support, and privacy pages were checked against
the prepared listing. Copy accurately describes optional log details and private
iCloud sync, including its default-on behavior where supported. The package
preserves iPhone/iPad/Watch support and uses the live store's 9+ age rating.
App Store Connect privacy and medical-device declarations were checked separately.

These are simulator captures, not a claim of physical-device certification.
Interactive Duo fold, rotation, draft preservation, and accessibility evidence
remain in the [usability audit](duo-usability-audit.md).

Media and provenance under `.build/` are local, ignored artifacts. The final
selected-file SHA-256 inventory and strict preflight evidence belong in
`.build/duo-audit/release-v3.0.4-attempt2-logs/store-final-preflight-evidence.json`.
The submission checkpoint must bind that inventory to the uploaded previews and
the exact processed build. Screenshot acceptance here does not assert App Review
submission or approval. The requested release policy is automatic after approval.
