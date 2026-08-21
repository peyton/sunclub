# Native Liquid Glass

## Status

- Implementation: complete locally on `feat/native-liquid-glass`.
- Local verification: complete with the bounded environment-only exceptions recorded below.
- PR, CI, merge, TestFlight, and exported-IPA entitlement verification: not performed.

## Platform Matrix

| Surface | iOS 26+ | iOS 18.6-25 |
| --- | --- | --- |
| Main-app cards and status surfaces | Neutral regular native glass | Existing fill, stroke, and shadow |
| Tappable cards | Interactive native glass | Existing button/card treatment |
| Primary actions | Native prominent glass | Existing `SunPrimaryButtonStyle` visuals |
| Secondary and icon actions | Native regular glass | Existing secondary/icon visuals |
| Related floating controls | Grouped native glass container | Existing independent controls |
| Fixed footers | Safe-area inset; content scrolls beneath glass | Existing opaque gradient footer |
| Onboarding and safe camera overlays | Glass where live content stays legible | Existing treatment |
| Widget and Watch targets | Unchanged | Unchanged |

## Rules

- Route app-screen materials through `AppTheme.swift` compatibility helpers.
- Keep regular glass neutral; reserve prominent glass for primary actions.
- Mark a glass card interactive only when the whole card is tappable.
- Group related floating controls with `SunGlassEffectContainer`.
- Guard native APIs with iOS availability and non-widget/non-Watch branches.
- Preserve visible copy, actions, routes, accessibility metadata, and stable identifiers.

## Scope Exclusions

- No persisted model, SwiftData schema, store path, CloudKit, entitlement, or signing changes.
- No automation route, App Intent, URL callback, widget behavior, or Watch UI changes.
- No PR, merge, release, TestFlight, or production entitlement action in this task.

## Accessibility Checks

- Preserve VoiceOver names, hints, values, traits, and UI-test identifiers.
- Preserve Voice Control names and complete button/card hit areas.
- Preserve Dynamic Type layouts through accessibility sizes without essential-copy scaling or clipping.
- Preserve dark mode, increased contrast, and status cues that do not rely on color alone.
- Preserve Reduce Motion behavior by leaving `SunMotion` and motion policy unchanged.
- Keep camera overlay glass limited to safe controls with readable foreground contrast.

## Verification Evidence

All Xcode commands use `/Applications/Xcode-26.6.0.app/Contents/Developer`; simulator retries are bounded to one.

- RED — focused adoption contract: 3 tests executed, 54 expected assertion failures, exit 65. The failures named missing card, action, footer, and grouped-control adoption.
- GREEN — latest focused design-system and accessibility unit tests: 15 tests executed, 0 failures.
- Router/contextual-action unit tests: 3 tests executed, 0 failures.
- Focused UI evidence: `testAccessibilityScorecardCoreTasksRemainUsable` and `testNativeTabAndNavigationChromeHideForSettingsDetail` passed. The class-filtered harness over-selected unrelated UI tests and was interrupted; the exact-filter rerun passed the navigation test, then Xcode stalled in `simctl diagnose --timeout=600` after test execution and was bounded with `TERM`. No UI assertion failure was reported.
- Generate: passed; workspace and project generated in 1.142 seconds.
- Lint: passed with 0 serious SwiftLint violations; the repository's warning-only findings remain.
- Required skip-cache Python command: 196 passed, 3 failed because the inherited `SUNCLUB_SKIP_LOCAL_TUIST_CACHE=1` suppressed the local-cache calls those tooling tests expected. Clean control: 199 passed in 6.82 seconds.
- Compile-cache-disabled Xcode 26.6 device builds: `SunclubDev` passed and production `Sunclub` passed on the final source state; widget and Watch targets compiled in both builds.
- Required full `just ci`: lint passed, then Python reported 194 passed and 5 tooling-test failures because the inherited skip-cache and compile-cache-recovery flags contradicted tests of default behavior. The command stopped before iOS tests.
- Clean `CI=1` full-CI control: lint and all 199 Python tests passed; the unit build then repeatedly reported local CAS `Connection refused (errno: 61)` and was interrupted after one bounded attempt. Its orphaned Xcode process was terminated; it did not report an XCTest assertion failure.
- Tuist reported non-blocking 401 warnings for quarantine lookup and build/test-result upload on successful local tests.

Commands:

```text
DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer SUNCLUB_SKIP_LOCAL_TUIST_CACHE=1 SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 TEST_XCODEBUILD_MAX_ATTEMPTS=1 TEST_XCODEBUILD_ARGS='-parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -only-testing:SunclubTests/DesignSystemAdoptionTests/testMainAppButtonsRouteThroughLiquidGlassCompatibilityHelpers -only-testing:SunclubTests/DesignSystemAdoptionTests/testMainAppCardCallSitesUseLiquidGlassCompatibilitySurface -only-testing:SunclubTests/DesignSystemAdoptionTests/testFixedFootersAndRelatedControlsUseNativeGlassContainers' just test-unit

DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer SUNCLUB_SKIP_LOCAL_TUIST_CACHE=1 SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 TEST_XCODEBUILD_MAX_ATTEMPTS=1 TEST_XCODEBUILD_ARGS='-parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -only-testing:SunclubTests/DesignSystemAdoptionTests -only-testing:SunclubTests/AccessibilityScorecardTests' just test-unit

DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer SUNCLUB_SKIP_LOCAL_TUIST_CACHE=1 SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 TEST_XCODEBUILD_MAX_ATTEMPTS=1 TEST_XCODEBUILD_ARGS='-parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -only-testing:SunclubTests/SunclubTests/testAppRouterKeepsPushedRoutesInsideSelectedTab -only-testing:SunclubTests/SunclubTests/testAppRouterPreservesFourIndependentTabStacks -only-testing:SunclubTests/SunclubTests/testContextualTabActionUsesDailyPlanCompactAndExpandedCopy' just test-unit

DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer SUNCLUB_SKIP_LOCAL_TUIST_CACHE=1 just generate
SUNCLUB_SKIP_LOCAL_TUIST_CACHE=1 just lint
SUNCLUB_SKIP_LOCAL_TUIST_CACHE=1 just test-python
DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer SUNCLUB_SKIP_LOCAL_TUIST_CACHE=1 SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 SUNCLUB_FLAVOR=dev just build
DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer SUNCLUB_SKIP_LOCAL_TUIST_CACHE=1 SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 SUNCLUB_FLAVOR=prod just build
DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer SUNCLUB_SKIP_LOCAL_TUIST_CACHE=1 SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 TEST_XCODEBUILD_MAX_ATTEMPTS=1 just ci

just test-python
CI=1 DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer TEST_XCODEBUILD_MAX_ATTEMPTS=1 just ci
```

## Task 4 Handoff

- PR URL: pending.
- CI run and required-check results: pending.
- Merge commit: pending.
- Release/TestFlight evidence: pending.

## v2.1.0 Release and Entitlement Checklist

- [ ] Start from the reviewed, merged commit and confirm version `2.1.0` is still the intended next release.
- [ ] Run `just release-preflight` and the CloudKit doctor/export/validation gates.
- [ ] Confirm required PR checks pass from the release source revision.
- [ ] Run the TestFlight workflow; preserve and download `.build/release-diagnostics` and the exported IPA.
- [ ] Inspect `Payload/Sunclub.app` from the final IPA with `codesign -d --entitlements :- Payload/Sunclub.app`.
- [ ] Confirm production application/team identifiers, `aps-environment`, CloudKit container `iCloud.app.peyton.sunclub`, `com.apple.developer.icloud-services = CloudKit`, and app group `group.app.peyton.sunclub`.
- [ ] Confirm HealthKit and WeatherKit entitlements are present and `get-task-allow` is false.
- [ ] Confirm embedded widget and Watch identifiers, app-group entitlement, signatures, plist constraints, icon assets, and companion versions pass release diagnostics.
- [ ] Confirm the TestFlight build finishes processing and is assigned to the intended internal tester group.
- [ ] Smoke test upgrade data preservation, CloudKit startup/sync, app-group store recovery, the four native tabs, settings back navigation, camera overlays, and accessibility common tasks.

Revision note: created 2026-08-21 for the app-wide native Liquid Glass migration. External release events remain intentionally unclaimed.
