# UI simplicity verification

Status: implementation and local verification complete. Exact-head full CI is recorded in the pull request before merge.

## Local verification

Xcode 26.6.0, iPhone 17 Pro simulator on iOS 26.5; compile cache disabled. UI tests run serially. Expected-failure reruns disable verbose sysdiagnose collection, not test assertions or result bundles. Compatibility tests use an iPhone SE (3rd generation), iOS 18.6, and a separate test build with `IPHONEOS_DEPLOYMENT_TARGET=18.0`; the ordinary test bundle targets the current SDK. The app's shipped deployment settings are unchanged.

| Check                             | Result                                              |
| --------------------------------- | --------------------------------------------------- |
| Full unit suite                   | 516 passed, 0 failures (September 5)                |
| Python suite                      | 279 passed, 0 failures (September 5)                |
| Website build and validation      | Passed                                              |
| CI lint                           | Passed; 0 errors, 54 SwiftLint warnings             |
| Final full UI suite               | 79 passed, 0 failures (September 5)                 |
| Final focused UI suite            | 10 passed, 0 failures (September 5)                 |
| iOS 18.6 compatibility UI suite   | 14 passed, 0 failures (September 5)                 |
| Development and Production builds | Both passed                                         |
| Source review                     | Clear; no unresolved important or blocking findings |
| Exact-head full CI                | Required before merge; evidence in the pull request |

## Screenshots

Real simulator captures; test fixtures and capture dates differ. Compare layout, not numerical totals.

| Insights before                                                 | Insights after                                                  |
| --------------------------------------------------------------- | --------------------------------------------------------------- |
| ![Previous Insights](assets/ui-simplicity/insights-before.webp) | ![Seven-day Insights](assets/ui-simplicity/insights-after.webp) |

- [Today saved receipt](assets/ui-simplicity/today-receipt.webp)
- [Insights in dark mode](assets/ui-simplicity/insights-dark.webp)
- [Insights at accessibility text size](assets/ui-simplicity/insights-accessibility.webp)
- [Today on iPhone SE, iOS 18.6](assets/ui-simplicity/today-narrow.webp)
- [Accessible Insights on iPhone SE, iOS 18.6](assets/ui-simplicity/insights-narrow-accessibility.webp)
- The website's logging and Shortcuts previews also use new simulator captures.

## Acceptance coverage

Today logs the current local day with a single action and guarded Undo/Edit. History alone selects dates. Insights contains a read-only seven-day summary and current streak. Three native tabs retain independent stacks; iOS 26 uses native back navigation and older systems retain a stack-scoped edge fallback.

| #   | Additional acceptance item                                    | Regression evidence                                                 |
| --- | ------------------------------------------------------------- | ------------------------------------------------------------------- |
| 1   | Clearing SPF persists                                         | ManualLogSimplicityTests                                            |
| 2   | Editor date is fixed                                          | ManualLogSimplicityTests; History UI flows                          |
| 3   | Long notes preserve coverage without truncation               | ManualLogSimplicityTests                                            |
| 4   | Ordinary `Areas:` prose survives                              | ManualLogSimplicityTests                                            |
| 5   | Older records do not acquire invented coverage                | ManualLogSimplicityTests                                            |
| 6   | Coverage is optional                                          | ManualLogSimplicityTests; shared editor                             |
| 7   | Suggestions hide metadata; explicit reuse updates fields      | ManualLogSimplicityTests; smart-reuse UI flow                       |
| 8   | Unchanged Save has no success/reminder effects                | ManualLogSimplicityTests; RecoverySimplicityTests                   |
| 9   | Reapplication rows are informational; one Edit log action     | History grouped-application UI flow                                 |
| 10  | Stale Delete Undo cannot replace newer logs                   | ManualLogSimplicityTests; RecoverySimplicityTests                   |
| 11  | One shared editor                                             | Manual Log, History, notification and URL UI flows                  |
| 12  | Resolve route context before presenting the editor            | QuietGlassNavigationTests; route UI flows                           |
| 13  | Health reflects actual write authorization and late responses | HealthKitAuthorizationTests; RecoverySimplicityTests                |
| 14  | Location switch says Use current location                     | SettingsSimplicityTests; Settings UI                                |
| 15  | One Reminders destination; diagnostics under Troubleshoot     | AutomationSettingsRouteTests; Settings UI                           |
| 16  | Location is optional during onboarding                        | Onboarding and city-selection UI flows                              |
| 17  | Save and notification onboarding failures remain distinct     | OnboardingPresentationTests; hosted failure Retry/Continue UI tests |
| 18  | Last logged uses the latest application                       | SettingsSimplicityTests                                             |
| 19  | Failed conflict Undo leaves conflict unresolved               | RecoverySimplicityTests                                             |
| 20  | Recovery errors are observable and retryable                  | RecoverySimplicityTests; SettingsRecoverySimplicityTests            |
| 21  | Catalog matches shipped Intent names                          | SettingsSimplicityTests                                             |
| 22  | No fake shortcut setup or Ask Before Running setting          | SettingsSimplicityTests; catalog inspection                         |
| 23  | Sample write URLs are copy-only                               | SettingsSimplicityTests; catalog inspection                         |
| 24  | Settings has permissions and one catalog destination          | Route tests; Settings/catalog UI                                    |
| 25  | Support consolidates help and contact destinations            | Route tests; Support inspection                                     |
| 26  | Export backup matches exported data                           | Backup round-trip UI flow                                           |
| 27  | Onboarding ends at Today, including legacy invite entry       | Onboarding and invite UI flows                                      |

## Data and compatibility

- No persisted schema, store path, CloudKit container, backup format, signing or entitlement changes.
- Existing public App Intents and URL routes remain; consolidated destinations redirect.
- Recovery changes include prior shipped V3-store projection coverage, local-only empty bootstrap, transaction rollback, retry and replacement-revision checks.
- No production CloudKit writes, release tags, TestFlight upload or App Review submission in this task.

## Evidence and limitations

- Behavior-first regressions reproduced note/coverage loss, stale receipt Undo, partial recovery writes, swallowed operation failures, late Health enablement, missing first-log reapply scheduling, insufficient error-text contrast and reused editor identity before their fixes.
- Follow-up UI failures reproduced the missing Today UV button trait, overwritten Troubleshoot child identifiers and its 28-point touch target. The forecast result bundle confirms Back succeeded but the next edge swipe did not return to Today; a separate injected-clock test reproduced Forecast retaining its launch day after midnight. Both forecast regressions now pass.
- The full UI run then reproduced a 200-point horizontal gauge drag activating Forecast. A UV-local tap-only primitive button style fixes it without swallowing vertical scrolling; the original horizontal regression, vertical scrolling at accessibility size, taps and return navigation pass. The final accessibility element owns an explicit default activation action.
- Final gauge accessibility activation and one-step Back were exercised through the native accessibility interface on iOS 18.6. Forced accessibility modes and simulator AX checks are not a claim of physical-device Voice Control speech or hardware keyboard testing.
- Hosted notification-center failures reproduced onboarding disappearing after setup was saved. A nonpersisted presentation hold now preserves Retry/Continue; attempt identity rejects late completion after navigation. Both hosted failure flows and seven navigation-state regressions pass.
- Home-exit tests failed at 23:59 because their real-time “future” helper returned the already-past 23:59:00. They now use an injected clock and fixed local noon; the monitor's production clock remains `Date.init` and its cutoff is unchanged.
- Baseline Insights button and edge-swipe tests passed; the exact reported pre-change failure was not reproduced. Source review did find production/test differences in the old fallback. The replacement is verified by shared-path navigation tests rather than an unsupported root-cause claim.
- Current-date logging is tested across midnight in the same time zone. A source review identified pre-existing time-zone/store-key coupling across independent service calendars. This pass does not change calendar or persisted-key semantics; a comprehensive time-zone migration requires separate data-preservation work.
- Browser checks covered `/`, `/docs/getting-started/`, `/docs/automation/` and `/support/` at 320, 390 and 430 pixels: no overflow, broken images or console warnings/errors. The Shortcuts screenshot is a real simulator capture.
- Exact-head full CI results are recorded in the pull request before merge; local result bundles and command logs are retained in the task worktree's `.build/` directory.
