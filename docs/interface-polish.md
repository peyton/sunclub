# Interface polish verification

The Apricot Morning design, stored identities, widget families, automation routes,
and onboarding sequence remain intact. Each numbered item is a user-visible
acceptance criterion, not a count of edited files.

## Today

1. Weather provenance has one aligned footer rather than two competing blocks.
2. Provider labels say Apple Weather, with no visible “Cached” terminology.
3. Freshness appears once; saved forecasts say “Last available forecast.”
4. Apple Weather attribution and Data Sources remain available in readable type.
5. The status/action/footer spacing uses shared tokens.
6. The UV value outranks severity and logging status in the type hierarchy.
7. SPF and covered areas are separate; SPF has a disclosure chevron.
8. SPF opens a focused editor; a missing value offers Add SPF.
9. Use for future logs is explicit and initially off.
10. Secondary actions and the attribution link retain 44-point minimum targets.

## Forecast

11. Apple Weather attribution appears once, at the bottom.
12. A concise freshness line replaces the verbose quality card.
13. The numeric UV value is larger than its severity label.
14. Location and date share consistent alignment and spacing.
15. Hourly values use readable body typography rather than oversized metrics.
16. Rows adapt for accessibility text rather than forcing fixed-width columns.
17. Sections and rows use shared spacing tokens.
18. Current UV and forecast-only peak UV have distinct labels.
19. All available hours for the day appear chronologically, with a current-hour cue.
20. The protection window appears once and only for the displayed day.

## Widgets

21. Medium calendar uses a split layout; large calendar fills the available area.
22. Weekday headings honor the calendar's first weekday.
23. Month geometry supports four, five, and six weeks.
24. Today, logged, upcoming, and adjacent-month states have non-color cues.
25. Large history surfaces use dated marks and existing totals; Logged Days and
    Lock Screen rectangles retain seven days.

## Settings and onboarding

26. Sunscreen uses the pinned Lucide bottle; UV & Weather retains its sun.
27. Apple Health uses heart-pulse; Privacy retains its shield.
28. Onboarding uses balanced hero, feature, and supporting-copy sizes.
29. Onboarding actions use consistent button widths and shared spacing.
30. Short windows and accessibility text put onboarding actions in the scroll flow.

## Data and behavior checks

SPF updates compare the captured record identity and snapshot, then write only
SPF through revision history. Cancel does not write. Stale edits fail without
clobbering newer content. A successful log write is not replayed when saving the
future default fails. The existing sunscreen profile stores the future SPF while
preserving product metadata. When absent, the editor explains that it creates a
profile named Sunscreen; there is no separate persisted default-SPF field.

## Evidence and coverage

Baseline app captures were rebuilt from `e91eb3693a57029566f48dd41e3dae9a842f3337`.
Candidate captures use this branch's compiled app. Both use deterministic test
fixtures; displayed system clock times can differ. The initial unknown-build
Simulator observation is excluded from the comparisons below.

| Fixes | Before and after evidence | Behavior verification |
| --- | --- | --- |
| 1–6 | [Today before](interface-polish-evidence/baseline-today-logged.png), [Today after](interface-polish-evidence/candidate-today-logged.png), [unlogged](interface-polish-evidence/candidate-today-unlogged.png) | TodayQuietGlassPresentationTests; forecast navigation UI tests |
| 7–10 | Same Today pair; [focused SPF editor](interface-polish-evidence/candidate-spf-editor.png) | SPFEditTests; SunclubSPFEditUITests cancel/save and future-default flows |
| 11–17 | [Forecast before](interface-polish-evidence/baseline-forecast.png), [after](interface-polish-evidence/candidate-forecast.png), [iPad accessibility](interface-polish-evidence/candidate-ipad-forecast-accessibility.png) | Forecast accessibility test reaches bottom attribution; adaptive row/type inspection |
| 18–20 | Same forecast pair | UVForecastSimplicityTests covers entire-day hours, current marker, freshness and stale-data attribution; SunclubUVTests covers fallback sources |
| 21 | [Medium before](interface-polish-evidence/baseline-calendar-medium-6weeks.png), [after](interface-polish-evidence/calendar-medium-6weeks.png); [large before](interface-polish-evidence/baseline-calendar-large-6weeks.png), [after](interface-polish-evidence/calendar-large-6weeks.png) | Both family layouts rendered; medium sidebar and all six rows verified |
| 22–24 | Same calendar pairs; [four weeks](interface-polish-evidence/calendar-medium-4weeks.png), [five weeks](interface-polish-evidence/calendar-medium-5weeks.png) | SunclubWidgetTests checks locale week starts, month boundaries and day states; checkmarks, outlines, dashes and adjacent-month italics inspected |
| 25 | [Large history dark](interface-polish-evidence/stats-large-dark.png), [seven-day view](interface-polish-evidence/week-medium.png) | Weekly/monthly totals and dated marks rendered; existing widget route/intent tests retained |
| 26–27 | [Settings before](interface-polish-evidence/baseline-settings.png), [after](interface-polish-evidence/candidate-settings.png) | Bottle/heart-pulse inspected; sun/shield assets unchanged |
| 28–29 | [Welcome before](interface-polish-evidence/baseline-welcome.png), [after](interface-polish-evidence/candidate-welcome.png); [reminders before](interface-polish-evidence/baseline-reminders.png), [after](interface-polish-evidence/candidate-reminders.png); [location before](interface-polish-evidence/baseline-location.png), [after](interface-polish-evidence/candidate-location.png) | Full-width action labels inspected across all three screens; onboarding flow tests retained |
| 30 | [Small iPhone](interface-polish-evidence/candidate-compact-welcome.png), [dark accessibility](interface-polish-evidence/candidate-onboarding-accessibility.png), [iPad](interface-polish-evidence/candidate-ipad-welcome.png) | SunclubOnboardingFailureUITests verifies large-text errors and Continue remain actionable; Reduce Motion and semantic accessibility labels retained |

Widget images use faithful SwiftUI rendering of the actual baseline/candidate
view bodies at small/medium/large point sizes, plus a standalone screen host.
They establish layout behavior, not Springboard tinting or WidgetKit-hosted
interaction. [Render provenance](interface-polish-evidence/widget-render-manifest.json)
records dimensions, fixtures and adaptations. Widget identities/routes are
covered separately by existing integration tests.

Full command results and exact-head hosted CI links are recorded in the PR.
Local logs and additional state captures remain in `.build/polish-evidence/`.
