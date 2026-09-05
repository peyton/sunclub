# CI And Release Stability

## Current execution contract

- `.github/actions/setup/action.yml` installs locked tools, restores download/lint
  caches and optionally selects the single pinned Xcode and authenticates Tuist.
  It configures the Xcode cache once per macOS job.
- Lint and Python run independently of iOS work. iOS PR changes require unit
  tests, the 13 UI smoke scenarios, and both Release device flavors.
- Only recognized web/documentation-only PR changes may skip iOS. Unknown paths,
  empty comparisons and failed detection default to iOS validation.
- In `ci.yml`, every master push and manual dispatch runs full UI coverage. Run
  `gh workflow run ci.yml --ref BRANCH` for a release/refactor candidate.
- The final `CI` gate uses `always()` and checks every expected result; failed,
  cancelled and unexpected skipped jobs cannot pass it. Branch rules migrate
  from five direct job contexts to `CI` only after verifying the new gate.
- Production signing/upload requires successful full CI on the exact source SHA;
  PR smoke results are insufficient. Preserve final entitlement/watch validation.
- For signed validation after that full CI passes, run
  `gh workflow run release-testflight.yml --ref BRANCH`. Manual dispatch archives,
  signs, exports and validates only; it never uploads to TestFlight or changes
  tester groups. Its `sunclub-export-RUN_ID` artifact retains the archive, IPA and
  final signing/watch diagnostics. Tag pushes retain the existing upload flow.
- Superseded PR runs cancel. Xcode steps remain bounded, with failure artifacts
  and release diagnostics retained.

## History Check

Checked on 2026-04-14 with `gh run list` and `git log` across:

- `.github/workflows/ci.yml`
- `.github/workflows/release-testflight.yml`
- `app/Sunclub/Project.swift`
- `app/Sunclub/WatchApp/Resources/Assets.xcassets/AppIcon.appiconset`
- `scripts/tooling/test_ios.sh`
- `scripts/tooling/common.sh`
- `scripts/tooling/ci_build.sh`
- `scripts/appstore/archive-and-upload.sh`
- `tests/test_ios_metadata.py`
- `docs/testflight-release.md`
- `AGENTS.md`

Recent churn was high:

- Watch and project generation changed in `14ba81f`, `a00d38e`, and
  `5d93e0a`.
- App Store and TestFlight release signing changed in `bd703e2`, `f2267e9`,
  `0114419`, `1f4282e`, `0008185`, `002d584`, `0b9fb05`, and `0d19f6f`.
- Release metadata guard tests accumulated around `tests/test_ios_metadata.py`
  but did not cover embedded watch app plist/icon/signing invariants until the
  `v1.0.27` upload failure.
- Xcode build stability handling changed in `dad9575`, then release-only timeout
  guards were added in `0d19f6f`.
- Normal CI did not get those Xcode timeout guards until `7afbd71`.

GitHub run cross-check:

- `v1.0.26`, run `24383578595`, succeeded after the TestFlight launch-safety
  unit test received a timeout guard. That tag points to
  `0d19f6f`, before `a00d38e` embedded the watch app into the iOS app target.
- Master CI run `24386961134` for `5d93e0a` failed in `Build iOS` because
  WatchKit validation saw `SunclubWatch.app` at marketing version `1.0` while
  the companion app was `1.0.0`.
- Master CI run `24387310082` for `4ef874e` passed the build but stalled in
  `iOS Tests` after `Run unit tests` started. The job exposed no live logs for
  the in-progress step.
- Master CI run `24387713866` for `7afbd71` completed the bounded unit
  tests in about 3.5 minutes, then failed UI tests because the simulator did
  not trigger the UIKit interactive-pop gesture from the left edge.
- Master CI run `24389570894` for `a9122a3` passed all jobs after the app-owned
  edge-swipe fallback.
- TestFlight run `24390814892` for `v1.0.27` failed in App Store Connect
  validation. The exported IPA embedded `SunclubWatch.app` signed as
  `com.apple.WK`, carried iOS-only plist keys (`CFBundleURLTypes`,
  `SunclubAppGroupID`, `SunclubICloudContainerIdentifier`, `SunclubURLScheme`),
  and had no watch app icon metadata or compiled watch icon assets.

## Rules

- Do not cut a TestFlight tag until full CI for the exact `HEAD` commit
  succeeds (master push or manual candidate validation).
- Keep every GitHub Actions Xcode build or test step bounded with
  `timeout-minutes`. This includes TestFlight archive/upload, App Review
  screenshot capture, App Review archive/upload, and final review submission
  steps.
- Swift compile caching is enabled by default in GitHub Actions. Keep `timeout-minutes` on every
  macOS GitHub Actions job that runs `just test-unit`, `just test-ui`,
  `just ci-build`, screenshot capture, or release archive/test commands.
- Normal CI must keep building both app flavors when iOS-affecting files
  change. CI exposes the macOS build matrix directly as
  `Build iOS (Development)` and `Build iOS (Production)`; do not re-add a
  separate aggregate `Build iOS` job unless required-check naming deliberately
  changes. The CI classifier may skip iOS test and build jobs only when every
  changed path is recognized web/documentation work; ambiguous diffs run iOS.
- Run Xcode builds and archives through Tuist. Repo scripts should invoke
  `tuist xcodebuild` via `run_tuist_xcodebuild`, and GitHub macOS test/release
  jobs should run `scripts/tooling/prepare_ci_workspace.sh` before heavy Xcode
  steps so Tuist auth and the local cache service are ready. Exporting an
  existing `.xcarchive` is the exception: use plain `xcodebuild -exportArchive`
  because it does not need project generation or compile caching, and Tuist can
  terminate with a post-archive trace trap before producing the IPA.
- Keep release archive/export paths repo-root absolute. The archive helper runs
  from `app/`, so relative `.build` paths otherwise land under `app/.build`
  while diagnostics and workflow artifacts look under the repo root.
- Restore repo-local GitHub Actions caches before lint, Python, and Xcode work.
  Cache `.cache/uv`, `.cache/npm`, `.cache/hk`, and `.cache/swiftlint`;
  do not cache `.venv`, `.DerivedData` or `.build` because Tuist's Xcode cache owns
  compilation artifacts.
- `tuist share` is opt-in for local builds. GitHub keeps pull-request builds
  local-only and enables sharing only where the workflow explicitly sets
  `SUNCLUB_TUIST_SHARE=1`.
- Pin CI and release jobs to the same supported stable Xcode version through
  the setup action's `SUNCLUB_XCODE_VERSION` env value instead of relying on
  `latest`, which can move before Tuist, simulators, or App Store validation
  behavior is verified for Sunclub.
- When a workflow pins an Xcode version that `macos-latest` does not carry,
  pin the macOS runner label too. Xcode `26.4` currently requires
  `runs-on: macos-26` on GitHub-hosted runners.
- If an in-progress GitHub iOS job has no downloadable logs, inspect job step
  metadata with `gh run view <run-id> --json jobs` or
  `gh api /repos/peyton/sunclub/actions/jobs/<job-id>`.
- Cancel superseded stalled CI runs after pushing a fix so the newest commit can
  own the release gate.
- CI and release workflows enforce `mise --locked` execution, so changing
  pinned versions in `mise.toml` requires regenerating `mise.lock` before merge.
- Keep generated iOS, widget, single-target watch app, and watch widget
  `Info.plist` values aligned:
  - `CFBundleShortVersionString=$(MARKETING_VERSION)`
  - `CFBundleVersion=$(SUNCLUB_BUILD_NUMBER)`
- Do not rely on Tuist defaults for embedded watch metadata. WatchKit
  `ValidateEmbeddedBinary` requires the embedded watch app marketing version to
  exactly match the companion app.
- Keep the embedded watch app `Info.plist` App Store-safe. The watch app plist
  must keep `WKCompanionAppBundleIdentifier`, version fields, and the
  single-target runtime keys `SunclubAppGroupID`,
  `SunclubICloudContainerIdentifier`, `SunclubPublicAccountabilityTransportEnabled`,
  and `SunclubURLScheme`. It must not include `CFBundleURLTypes`. App Store
  Connect also rejects `CFBundleIconName` in the embedded watch app plist, so
  rely on compiled watch assets instead of that key.
- Keep `WatchApp/Resources/Assets.xcassets/AppIcon.appiconset` wired into the
  watch app resources. App Store Connect rejects embedded watch apps that do not
  export compiled icon assets.
- Keep release IPA validation checking the embedded watch app before upload:
  code-signing identifier equals `CFBundleIdentifier`, marketing version and
  build number match the companion app, compiled `Assets.car` exists, and the
  App Store-invalid plist keys are absent.
- Before the App Store export step, prepare App Store provisioning profiles for
  every archived `.app` and `.appex` bundle. The release script must
  enumerate the archive itself, create any missing App Store profiles through
  App Store Connect, install them locally for export, and preserve
  `.build/release-diagnostics/provisioning-profiles.json` for audit.
- Release entrypoints must set their production flavor and APS defaults before
  sourcing `scripts/tooling/common.sh`; the shared environment intentionally
  defaults normal local builds to the development flavor.
- Keep release-doctor coverage aligned with every production bundle ID emitted
  by `Project.swift`: main app, iOS widget, single-target watch app, and watch
  widget. A release can archive successfully and still fail profile preparation
  when a nested watch bundle ID was never registered.
- WeatherKit must be enabled as an Apple Developer App Service for both
  `app.peyton.sunclub` and `app.peyton.sunclub.dev`; a checked-in
  `com.apple.developer.weatherkit` entitlement alone does not grant runtime
  access. After enabling it, regenerate profiles and verify the entitlement in
  the installed development profile and final exported IPA.
- Keep provisioning reconciliation mapping
  `com.apple.developer.weatherkit` to both the App Store Connect `WEATHERKIT`
  capability and `WEATHER_KIT` App Service, and keep release doctor requiring
  both on the main App ID. Skip and replace any otherwise-active profile that
  lacks the WeatherKit entitlement.
- The App Store Connect API can create Bundle IDs and enable the App Groups
  capability, but the specific App Group assignment may still need the Apple
  Developer portal Configure/Assign step before the generated App Store profile
  includes `group.app.peyton.sunclub`.
- Treat an existing App Store profile as reusable only after decoding the
  profile content and proving it covers the archived bundle's profile-backed
  entitlements, including app groups. Stale profiles must be skipped and
  regenerated before export.
- Treat a provisioning profile entitlement value of `*` as satisfying archived
  list entitlements. App Store Connect can return `*` for profile-backed
  services such as `com.apple.developer.icloud-services` even when the signed
  archived app requests `CloudKit` explicitly.
- When borrowing certificates from existing profiles to create a replacement
  profile, query the profile certificates endpoint, tolerate profile 404s from
  App Store Connect, and keep scanning active profile candidates. The list
  endpoint can lag deleted or invalidated profile resources.
- Also fetch each reusable profile with `include=certificates` before falling
  back to the profile certificates endpoint. App Store Connect may omit
  certificate relationships from bundle profile listings while still returning
  them through the included profile resource.
- Gather reusable release certificate IDs across all archived bundles before
  creating any missing profiles. A single-target watch app can require a new
  profile while App Store Connect hides the top-level certificate list from the
  API key, so profile creation must be able to reuse the certificate attached to
  a valid app, widget, or watch app profile.
- If App Store Connect exposes no reusable certificate through existing
  profiles or `/certificates`, create a fresh Apple distribution certificate
  from a generated CSR, import its private key into a temporary release
  keychain, and use that certificate ID for every missing App Store profile.
  The release workflow carries only App Store Connect API credentials, not a
  reusable `.p12` signing secret.
- Keep native `interactivePopGestureRecognizer` enabled when hiding the
  navigation bar so real devices get the standard interactive back drag. Keep
  the app-owned `RootView` left-edge fallback active in UI tests because CI
  simulator runs on Xcode 26 failed to trigger UIKit's gesture even though the
  visible `screen.back` button still worked.
- Preserve the failure-only `ios-ui-test-result` artifact. GitHub's compact
  Xcode output omits assertion locations and screenshots needed to diagnose
  simulator-only native navigation and Liquid Glass failures.
- Before trusting a TestFlight release, inspect the downloaded workflow artifact
  entitlements from `.build/release-diagnostics`, not just the provisioning
  profile or checked-in entitlement files.
- Release diagnostics must include code-signing and entitlement dumps for the
  main app and every nested `.app` or `.appex` bundle inside the exported IPA,
  including the single-target watch app, iOS widget, and watch widget bundles.
- Run `just release-preflight` before cutting a TestFlight tag when a local
  macOS/Xcode environment is available. It combines strict metadata validation,
  Python release guard tests, full unit/UI tests, and both release device builds.
