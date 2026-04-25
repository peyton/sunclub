# Sunclub

iOS sunscreen tracking app with AI validation.

## Build & Run

```text
just bootstrap
just download-model
just generate
open app/Sunclub.xcworkspace
```

Scheme: **Sunclub** | Destination: iPhone simulator (iOS 18+). No manual SPM or CocoaPods steps needed.

## Test Commands

| Surface           | Command                 |
| ----------------- | ----------------------- |
| Unit tests        | `just test-unit`        |
| UI tests          | `just test-ui`          |
| All tests         | `just test`             |
| CI validation     | `just ci`               |
| Lint              | `just lint`             |
| Format            | `just fmt`              |
| Python eval tests | `just test-python`      |
| Benchmark         | `just benchmark-strict` |

## Verification Rules

- For changes touching GitHub Actions, CI scripts, workflow files, or PR merge behavior, run the closest local CI-equivalent command before calling the fix ready.
- Prefer `just ci-lint`, `just ci`, or the specific underlying repo script that matches the failing GitHub job.
- Do not report a CI fix as ready unless the relevant GitHub workflow is expected to pass from the current branch state.

## Data Preservation Release Gate

Every app update must preserve user data stored locally and in CloudKit. Treat data preservation as a release gate for any change that touches signing, entitlements, app groups, store paths, SwiftData schema, revision history, backup import, or CloudKit sync.

- Test app-group entitlement and store-location transitions whenever signing, entitlements, app-group IDs, container IDs, store URLs, SwiftData container setup, or release export behavior changes. At minimum, cover the update path from no app-group entitlement using the Application Support `default.store` to a later build with the app-group entitlement using the shared app-group `default.store`.
- Never assume a provisioning profile proves runtime capabilities. For TestFlight or CloudKit-affecting releases, inspect the final exported IPA entitlements from the release artifact with `codesign -d --entitlements :- Payload/Sunclub.app` or the checked release diagnostics before trusting CloudKit, push, or app-group behavior.
- Route every SwiftData `ModelContainer` creation path through `SunclubModelContainerFactory` so migrations, store-location recovery, and CloudKit `.none` configuration stay consistent. This app uses manual `CKSyncEngine`; do not enable SwiftData CloudKit mirroring accidentally.
- Empty/default local bootstrap state must never overwrite meaningful local or CloudKit history. Mark synthetic empty migration seeds local-only, do not queue them for CloudKit, and ignore synthetic default `migrationSeed` or default `conflictAutoMerge` settings revisions whenever meaningful settings history exists.
- Persisted model or history changes must include migration or projection tests that open prior shipped stores and prove non-empty users keep publishable history while empty stores remain local-only.
- Recovery and import paths must be idempotent and non-destructive: never delete current days during recovery, never overwrite current settings with less complete defaults, and always prefer `hasCompletedOnboarding: true` over `false`.

## Accessibility Scorecard Rules

Every future change under `app/` must preserve a perfect App Store Accessibility Nutrition Label scorecard for the app's common tasks. Treat the scorecard as a release gate, not a nice-to-have.

- Supported criteria must remain true for VoiceOver, Voice Control, Larger Text, Dark Interface, Differentiate Without Color Alone, Sufficient Contrast, and Reduced Motion.
- Captions and Audio Descriptions are currently not applicable because the app has no time-based audio or video content. If media playback is added, captions and audio descriptions become required before shipping.
- All interactive controls need visible, specific accessible names. Icon-only controls need explicit labels and, when useful, hints. Use stable accessibility identifiers for UI-testable flows.
- VoiceOver users must be able to perceive and operate every common task. Decorative images and symbols should be `accessibilityHidden(true)`; meaningful custom visuals need labels and values.
- Voice Control names should match visible text where practical. Do not hide primary actions behind unlabeled gestures.
- Text must support Dynamic Type through accessibility sizes without clipping essential content, overlapping controls, or blocking primary actions. Do not use `minimumScaleFactor` or fixed `lineLimit` for essential app copy.
- Do not encode status, selection, risk, or progress with color alone. Pair color with text, symbols, selection traits, labels, or values.
- Text, icons, controls, focusable states, and semantic colors must keep sufficient contrast in light mode, dark mode, and increased-contrast contexts. Use `AppPalette` tokens such as `onAccent` instead of low-contrast foregrounds on accent fills.
- Motion must honor Reduce Motion. Use `SunMotion` for SwiftUI animations, and suppress or replace decorative looping effects when `accessibilityReduceMotion` is true.
- UI or behavior changes in `app/` should add or update unit/UI/integration tests for any affected scorecard criterion. Prefer the existing `UITEST_FORCE_*` launch arguments for deterministic accessibility coverage.

## Always-Automatable Rules

Every future user-facing feature must preserve Sunclub's always-automatable posture. Before a feature is considered ready, document and test its automation surface.

- Add an App Intent for the feature, or document why it is destructive, permission-only, camera-based, file-picker-based, or review-heavy enough to open foreground UI instead.
- Add a custom URL/x-callback route for non-destructive reads and writes, or document the foreground route users and callers should open.
- Add Settings visibility for any automation knob, privacy toggle, or sensitive callback behavior.
- Route outside-app writes through the shared automation runtime and revision-history services; do not add ad hoc direct-write shortcuts.
- Update `docs/app-automation.md`, app product docs, website copy under `web/`, and tests whenever an automation surface changes.
- Keep Universal Links deferred unless the release plan explicitly includes Associated Domains signing and `apple-app-site-association` verification.

## Project Layout

```text
app/          iOS Apps, Swift source, iOS tests, UI tests
evals/        Benchmark suite and eval harness
scripts/      All project-level scripts.
tests/        Other tests and test runners
docs/         One place for all documentation on the app, evals, scripts, and tests.
```

## Architecture Conventions

- **Models** → `app/Sunclub/Models/` — SwiftData `@Model` types
- **Persistence Versioning** → `app/Sunclub/Sources/Models/SunclubSchema.swift` — all SwiftData `VersionedSchema`, migration stages, and `ModelContainer` factory wiring live here
- **Services** → `app/Sunclub/Services/` — coordinators, matchers, managers
- **Views** → `app/Sunclub/Views/` — one file per screen
- **Theme** → `app/Sunclub/Shared/AppTheme.swift` — all UI tokens live here
- Singletons: `VisionFeaturePrintService.shared`, `NotificationManager.shared`
- Observable state: `AppState` is the single source of truth, injected via `@Environment`

### SwiftData Migration Rules

- Treat every persisted SwiftData field change as a schema version bump. Add a new `VersionedSchema` entry in `app/Sunclub/Sources/Models/SunclubSchema.swift` and keep older schema definitions immutable.
- When freezing an older schema, annotate it with the shipped commit or release it matches so migration tests have a concrete source of truth.
- Route every `ModelContainer` creation path through `SunclubModelContainerFactory`; do not create ad-hoc containers that skip the migration plan.
- Keep data fixes that must happen once per upgrade inside the migration stage, not scattered across unrelated runtime code.

## Documentation Rules

- **All specs, design docs, and investigation notes go in `docs/`** as Markdown files.
- All documentation about tools goes in `docs/` as Markdown files.
- Persisted-data changes should add or update a migration note/ExecPlan in `docs/` when the migration behavior or rollout assumptions are non-trivial.
- Keep docs terse — spec fields, not prose
- DO NOT reference Linear ticket IDs (e.g. `PER-44`) in doc filenames or headers
- Existing specs: `SPEC.md` (benchmark), `app/SPEC.md` (product), `docs/subscription-screen-spec.md`

## Commit & PR Conventions

- Prefix: `PER-XX:` for ticketed work, `feat:`/`fix:`/`chore:` for unlinked
- One PR per task — never combine unrelated changes
- PR body should include verification steps

## Code Style

- Swift 6, strict concurrency (`@MainActor`, `nonisolated`, `Sendable`)
- 4-space indent
- Custom errors: enum conforming to `LocalizedError`
- UI tests use `UITEST_MODE` launch arg to bypass camera/notifications
- Linting/formatting managed by [hk](https://hk.jdx.dev/) — see `hk.pkl`
- Python: `ruff` for linting and formatting
- Shell: `shellcheck` + `shfmt`
- Markdown/JSON/YAML: `prettier`
- Swift: `swiftlint` (macOS only)

## Things to Avoid

- Don't add external dependencies — the app is intentionally self-contained
- Don't change matching thresholds without running the benchmark
- Don't change persisted SwiftData models without bumping the schema version and adding/updating a migration test that opens the previous shipped store
- Don't bypass `UITEST_MODE` in UI tests — they must work without real camera/notifications
- Don't put documentation anywhere other than `docs/`

## Recent Learnings

- TestFlight artifact entitlements must be inspected from the final exported IPA, not inferred from the provisioning profile or the checked-in `.entitlements` file. v1.0.24 exported from an unsigned archive with a provisioning profile that contained CloudKit, APS, HealthKit, WeatherKit, and app-group capabilities, but the signed app kept only base entitlements and crashed on `CKContainer(identifier:)`. Keep CloudKit runtime entitlement guards in place, preserve `.build/release-diagnostics` in `release-testflight.yml`, and inspect `Sunclub.entitlements.plist` from the downloaded workflow artifact before trusting a TestFlight build. The release workflow should ad-hoc sign unsigned archives with resolved release entitlements and then fail before upload if the exported IPA is missing required CloudKit, push, or app-group entitlements.
- Before CloudKit-affecting releases, run `just cloudkit-doctor`, then `just cloudkit-export-schema` and `just cloudkit-validate-schema` when the schema file is absent or stale. These commands prove CloudKit team/container/schema access, but they do not prove the final IPA was signed with CloudKit entitlements; final IPA `codesign -d --entitlements :- Payload/Sunclub.app` remains the release source of truth.
- Keep the `release-testflight.yml` launch-safety unit-test step bounded with a `timeout-minutes` value. A stuck pre-archive release gate produces no IPA artifact to inspect and blocks the next corrected TestFlight build.
- Swift compile caching is enabled by default for CI and release workflows. Any macOS GitHub Actions job running `just test-unit`, `just test-ui`, `just ci-build`, or release archive/test commands must prepare Tuist with `scripts/tooling/prepare_ci_workspace.sh`, run builds through `tuist xcodebuild`, and keep `timeout-minutes` on the Xcode step. If GitHub has no live logs for an in-progress iOS step, inspect job metadata with `gh run view <run-id> --json jobs` and cancel superseded stuck runs after pushing the fix.
- Generated watch app, watch extension, watch container, and watch widget `Info.plist` values must explicitly mirror the companion app with `CFBundleShortVersionString=$(MARKETING_VERSION)` and `CFBundleVersion=$(SUNCLUB_BUILD_NUMBER)`. Do not rely on Tuist defaults here; WatchKit `ValidateEmbeddedBinary` fails release and CI builds when an embedded watch app reports `1.0` while the companion app reports `1.0.0`.
- App Store Connect rejects embedded watch apps when the watch app bundle carries iOS-only Info.plist keys, lacks compiled watch icon assets, or is signed with the WatchKit stub identifier `com.apple.WK`. Keep the watch app plist minimal, keep `WatchApp/Resources/Assets.xcassets/AppIcon.appiconset` in the target resources, and keep release IPA validation checking the watch app code-signing identifier, `CFBundleIconName`, compiled `Assets.car`, and plist key denylist before upload.
- Hidden SwiftUI navigation bars need both the visible `screen.back` button and the app-owned left-edge drag fallback in `RootView`. Do not rely only on UIKit `interactivePopGestureRecognizer`; CI simulator runs on Xcode 26 failed `testSettingsEdgeSwipeReturnsHome` and `testRecoveryUndoRestoresTodayAndStreak` even though button back navigation still worked.
- Keep the historical CI and release stability notes in `docs/ci-release-stability.md` current whenever touching `.github/workflows/ci.yml`, `.github/workflows/release-testflight.yml`, release tooling, or watch target generation.
