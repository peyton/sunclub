# CI And Release Stability

## History Check

Checked on 2026-04-14 with `gh run list` and `git log` across:

- `.github/workflows/ci.yml`
- `.github/workflows/release-testflight.yml`
- `app/Sunclub/Project.swift`
- `scripts/tooling/test_ios.sh`
- `scripts/tooling/common.sh`
- `scripts/tooling/ci_build.sh`
- `docs/testflight-release.md`
- `AGENTS.md`

Recent churn was high:

- Watch and project generation changed in `14ba81f`, `a00d38e`, and
  `5d93e0a`.
- App Store and TestFlight release signing changed in `bd703e2`, `f2267e9`,
  `0114419`, `1f4282e`, `0008185`, `002d584`, `0b9fb05`, and `0d19f6f`.
- Xcode compile cache handling changed in `dad9575`, then release-only timeout
  and cache guards were added in `0d19f6f`.
- Normal CI did not get those Xcode cache guards until `7afbd71`.

GitHub run cross-check:

- `v1.0.26`, run `24383578595`, succeeded after the TestFlight launch-safety
  unit test disabled Xcode compile caches and had a timeout.
- Master CI run `24386961134` for `5d93e0a` failed in `Build iOS` because
  WatchKit validation saw `SunclubWatch.app` at marketing version `1.0` while
  the companion app was `1.0.0`.
- Master CI run `24387310082` for `4ef874e` passed the build but stalled in
  `iOS Tests` after `Run unit tests` started. The job exposed no live logs for
  the in-progress step.
- Master CI run `24387713866` for `7afbd71` completed the cache-disabled unit
  tests in about 3.5 minutes, then failed UI tests because the simulator did
  not trigger the UIKit interactive-pop gesture from the left edge.

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
- Keep the app-owned left-edge back gesture in `RootView` when hiding the
  native navigation bar. Do not rely only on UIKit
  `interactivePopGestureRecognizer`; CI simulator runs on Xcode 26 failed to
  trigger it even though the visible `screen.back` button still worked.
- Before trusting a TestFlight release, inspect the downloaded workflow artifact
  entitlements from `.build/release-diagnostics`, not just the provisioning
  profile or checked-in entitlement files.
