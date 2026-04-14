# CI And Release Stability

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
- Xcode compile cache handling changed in `dad9575`, then release-only timeout
  and cache guards were added in `0d19f6f`.
- Normal CI did not get those Xcode cache guards until `7afbd71`.

GitHub run cross-check:

- `v1.0.26`, run `24383578595`, succeeded after the TestFlight launch-safety
  unit test disabled Xcode compile caches and had a timeout. That tag points to
  `0d19f6f`, before `a00d38e` embedded the watch app into the iOS app target.
- Master CI run `24386961134` for `5d93e0a` failed in `Build iOS` because
  WatchKit validation saw `SunclubWatch.app` at marketing version `1.0` while
  the companion app was `1.0.0`.
- Master CI run `24387310082` for `4ef874e` passed the build but stalled in
  `iOS Tests` after `Run unit tests` started. The job exposed no live logs for
  the in-progress step.
- Master CI run `24387713866` for `7afbd71` completed the cache-disabled unit
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

- Do not cut a TestFlight tag until the latest `master` CI run for the exact
  `HEAD` commit succeeds.
- Keep every GitHub Actions Xcode build or test step bounded with
  `timeout-minutes`.
- Set `SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1` on every macOS GitHub Actions job
  that runs `just test-unit`, `just test-ui`, `just ci-build`, or release
  archive/test commands.
- If an in-progress GitHub iOS job has no downloadable logs, inspect job step
  metadata with `gh run view <run-id> --json jobs` or
  `gh api /repos/peyton/sunclub/actions/jobs/<job-id>`.
- Cancel superseded stalled CI runs after pushing a fix so the newest commit can
  own the release gate.
- Keep generated iOS, widget, watch app, watch extension, watch container, and
  watch widget `Info.plist` values aligned:
  - `CFBundleShortVersionString=$(MARKETING_VERSION)`
  - `CFBundleVersion=$(SUNCLUB_BUILD_NUMBER)`
- Do not rely on Tuist defaults for embedded watch metadata. WatchKit
  `ValidateEmbeddedBinary` requires the embedded watch app marketing version to
  exactly match the companion app.
- Keep the embedded watch app `Info.plist` App Store-safe. The watch app plist
  must keep `WKCompanionAppBundleIdentifier`, `CFBundleIconName=AppIcon`, and
  version fields, but must not inherit iOS app runtime keys like
  `CFBundleURLTypes`, `SunclubAppGroupID`, `SunclubICloudContainerIdentifier`,
  or `SunclubURLScheme`.
- Keep `WatchApp/Resources/Assets.xcassets/AppIcon.appiconset` wired into the
  watch app resources. App Store Connect rejects embedded watch apps that do not
  export compiled icon assets.
- Keep release IPA validation checking the embedded watch app before upload:
  code-signing identifier equals `CFBundleIdentifier`, `CFBundleIconName` is
  `AppIcon`, compiled `Assets.car` exists, and the iOS-only plist keys are
  absent.
- Before `xcodebuild -exportArchive`, prepare App Store provisioning profiles
  for every archived `.app` and `.appex` bundle. The release script must
  enumerate the archive itself, create any missing App Store profiles through
  App Store Connect, install them locally for export, and preserve
  `.build/release-diagnostics/provisioning-profiles.json` for audit.
- Treat an existing App Store profile as reusable only after decoding the
  profile content and proving it covers the archived bundle's profile-backed
  entitlements, including app groups. Stale profiles must be skipped and
  regenerated before export.
- When borrowing certificates from existing profiles to create a replacement
  profile, query the profile certificates endpoint, tolerate profile 404s from
  App Store Connect, and keep scanning active profile candidates. The list
  endpoint can lag deleted or invalidated profile resources.
- Gather reusable release certificate IDs across all archived bundles before
  creating any missing profiles. A watch extension can require a new profile
  while App Store Connect hides the top-level certificate list from the API key,
  so profile creation must be able to reuse the certificate attached to a valid
  app, widget, or watch app profile.
- Keep the app-owned left-edge back gesture in `RootView` when hiding the
  native navigation bar. Do not rely only on UIKit
  `interactivePopGestureRecognizer`; CI simulator runs on Xcode 26 failed to
  trigger it even though the visible `screen.back` button still worked.
- Before trusting a TestFlight release, inspect the downloaded workflow artifact
  entitlements from `.build/release-diagnostics`, not just the provisioning
  profile or checked-in entitlement files.
