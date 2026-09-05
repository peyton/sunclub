# Quiet Glass design QA

## Target and capture

- Source: approved Quiet Sun refinement; Today and History generated references, not photographic option 2.
- Source directory: `/Users/peyton/.codex/generated_images/01a02d0a-6dc9-7b93-a9c5-21e352c3eaf7/`.
- Today: `exec-9c8ad545-c74e-42a1-a6ba-194139f20f3e.png`.
- History: `exec-5b270fa2-4d64-4578-b2a7-7e186e379037.png`.
- Implementation: native Sunclub, iPhone 17 Pro, iOS 26.5, Xcode 26.6.
- Evidence directory: `.build/quiet-glass-qa/` in the feature checkout; local captures are intentionally untracked.
- Source pixels: 853 × 1844 each. Implementation pixels: 1206 × 2622, 402 × 874 points at 3× density. CSS viewport: not applicable to native SwiftUI.
- Normalization: aspect-fit each full screen into a 402 × 874-point panel; paired output is 1680 × 1840 pixels. iOS status/home chrome is system-owned; the reference omits the status bar.
- State: September 4, logged Today; History selects the same day with two saved application timestamps. Fixture UV, reminder preference, covered areas, locale week start, counts, and saved times differ from the mock and are retained truthfully.

## Comparisons

- Full view: `today-comparison-first.png`, `today-comparison-final.png`, `history-comparison-final.png` place source and native capture in the same image.
- Supporting screens: `settings-final.png`, `manual-final.png`, `today-dark-final.png`, `today-accessibility-final.png`. The earlier `today-dark.png` records the pre-fix contrast failure.
- Larger Text scrolled checkpoints: `scorecard/0CBC551E-913C-4F68-82C3-0A1C70D93773.png` (primary action) and `scorecard/88E3F32D-8AFF-469B-86CF-3E6E58025214.png` (logged summary), exported from the passing smoke test and visually inspected.
- Focus: inspect the full-resolution paired images at the header, primary action, week strip, application rows, and tab bar. Text and SVG strokes are readable at their normalized scale; no separate crops are required for these sparse screens.
- Primary interactions: Today logging, reapplication, History editing/backfill/undo, weekly insights, Settings navigation/back, backup, and URL/widget routes are covered by simulator UI tests. Larger Text uses the scorecard launch overrides.
- Browser console: not applicable; this is the native app, not a web prototype.

## Findings and iteration history

| Priority | Earlier finding                                                                                | Correction                                                                                                       | Post-fix evidence                                  |
| -------- | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| P2       | History calendar control was an oversized oval.                                                | Use a labeled 44-point circular SVG control.                                                                     | `history-comparison-final.png`                     |
| P2       | Settings root used a black native title with different spacing.                                | Reuse the rounded, leading-aligned shared header; retain native detail navigation.                               | `settings-final.png`                               |
| P2       | Tab bar Settings icon used sliders instead of a cog.                                           | Bundle the matching library SVG cog.                                                                             | `today-comparison-final.png`                       |
| P2       | Logged primary action edited the original record instead of adding a reapplication.            | Separate Log reapplication from the tappable saved entry; allow recording with reminders off.                    | Reapplication unit regression; UI regression       |
| P2       | Selected-week counts linked to an ambiguously dated rolling report.                            | Keep counts passive and label the separate report link Last 7 days.                                              | `history-comparison-final.png`                     |
| P2       | A fixed monthly cutoff was described as actual sunset and could contradict an accepted snooze. | Use neutral Check your sunscreen copy without claiming sunset or pending-notification state.                     | Presentation regression tests                      |
| P1       | Native glass rendered white labels on the pale dark-mode primary tint.                         | Use the same contrast-tested deep blue and white pair in both appearances; tint native primary glass explicitly. | `today-dark-final.png`; white/blue contrast 6.16:1 |
| P1       | Structural History accessibility identifiers replaced child action identifiers.                | Add explicit containment boundaries, preserving child names and identifiers.                                     | All 13 UI smoke tests passed                       |

## Required fidelity surfaces

- Typography: native SF Rounded hierarchy, large leading titles, compact secondary copy, and a scaled numeric UV value. Essential text wraps. Accessibility sizes remove the fixed gauge ring and allow vertical scrolling.
- Spacing: quiet single-column canvas, central UV focus, full-width logging action, compact native three-tab navigation. History retains explicit edit/delete actions and real notes, so its content is taller than the illustrative mock.
- Colors: ivory/slate backgrounds, navy/light text, accessible blue actions, and semantic UV colors with text labels. All UV text levels and primary color pairs have contrast tests. Revised native dark glass rendering confirms white labels on deep blue.
- Assets: pinned Lucide SVG template assets, bundled license, no package dependency or raster icons. Existing logos remain untouched. The UV ring is a live data visualization, not decorative art. Native glass rendering intentionally replaces the mock's painted highlights.
- Copy: real UV provenance and unavailable/stale states are retained. No invented application times, covered areas, notification promises, or protection guarantees. Weekly insights explicitly describes its rolling seven-day scope.

## Acceptance

- [x] Open and compare source and rendered native screens together.
- [x] Correct header, calendar, icon, and action semantics.
- [x] Verify revised dark-mode primary contrast visually.
- [x] Pass updated common-task accessibility and navigation UI checks: 13 smoke tests, zero failures.
- [x] Inspect final Larger Text scrolling and controls.

No actionable P0/P1/P2 visual findings remain. Full exact-head CI remains a separate merge gate; native VoiceOver/Voice Control usage was checked through accessible control semantics and automated common-task coverage, not a manual assistive-technology session.

final result: passed
