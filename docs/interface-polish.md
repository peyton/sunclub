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

Unit coverage: SPFEditTests, TodayQuietGlassPresentationTests,
UVForecastSimplicityTests, SunclubWidgetTests. UI coverage includes focused SPF,
forecast accessibility/navigation, and onboarding recovery scenarios. Candidate
screenshots and command logs are retained in `.build/polish-evidence/` locally;
CI test bundles are the durable execution evidence linked from the PR.

The initial Simulator observation established Today/Forecast repetition and
Settings icon duplication; its installed-build provenance was not established.
Candidate captures must therefore be treated as candidate verification, not an
exact-build visual regression comparison with that initial observation.
