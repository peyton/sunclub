# iPhone Duo validation

## Platform guidance

Apple's [Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/)
confirms that building with iOS 27.1 or later enables the full-screen experience.
Native tabs and navigation adapt to the device's poses. Keep foreground controls
inside the safe area, handle each edge independently, and avoid screen-size or
orientation assumptions. Landscape support matters on the outer display; the
inner display can resize independently of supported orientations.

## Implementation

- Enable both iPhone landscape orientations while retaining portrait and the
  existing iPad orientations. Keep the iOS 18.6 deployment target.
- Use the existing form-width token to center and bound Today content on wider
  windows while retaining flexible width on compact windows.
- Clamp shared light/dark screen minimum heights to zero for short windows.
- Preserve native TabView/NavigationStack and safe-area layout. No new device
  detection, persistence changes, or public automation routes are necessary.
- Add metadata coverage and a UI smoke scenario for logged-state retention,
  reachable actions, and tab overlap after rotation with accessibility settings.
- Find native Back controls outside horizontal navigation-bar containers in UI
  tests. Fully reveal the large-text reminder switch before tapping it and
  verify that it turned on before looking for interval controls. The accessibility
  scenario accepts native tab labels when custom identifiers have not yet installed.

## Local verification

BigBook has Xcode 27.2 (27B5038j), iOS Simulator SDK 27.2, and the Duo-specific
27.2 runtime (24B91011). Tests use a dedicated `Sunclub Duo Adaptive Tests`
simulator; existing simulators are preserved.

```sh
just build
just ci-lint
just test-python
DEFAULT_SIMULATOR_DEVICE='iPhone Duo' \
  TEST_SIMULATOR_NAME='Sunclub Duo Adaptive Tests' \
  TEST_XCODEBUILD_MAX_ATTEMPTS=1 just test-unit
DEFAULT_SIMULATOR_DEVICE='iPhone Duo' \
  TEST_SIMULATOR_NAME='Sunclub Duo Adaptive Tests' \
  TEST_XCODEBUILD_MAX_ATTEMPTS=1 just test-ui-smoke
```

Builds with Xcode 27.2 and Xcode 27.1 (27A9275) passed. The latter uses
`DEVELOPER_DIR=/Applications/Xcode-27.1.0.app/Contents/Developer just build`,
without changing the system toolchain. Lint, 279 Python tests, and 659 Duo unit
tests passed. The final clean Duo smoke run passed all 14 tests together with
zero failures or skipped tests (269.5 seconds). It includes the large-text
accessibility scenario and the new rotation/state-retention scenario.

Results: `.build/build.xcresult` (Xcode 27.1), `.build/test-unit.xcresult`
(659 unit tests), and `.build/test-ui-smoke.xcresult` (14 smoke tests).
Earlier diagnostic runs are preserved as
`.build/test-ui-smoke-duo-initial.xcresult`,
`.build/test-ui-smoke-duo-second.xcresult`,
`.build/test-ui-smoke-duo-third.xcresult`, and
`.build/test-ui-smoke-duo-accessibility-pass.xcresult`.
The test harness's normal Tuist result processing also produced a
[final smoke run](https://tuist.dev/peyton/sunclub/tests/test-runs/d5d7c552-10ce-4de0-b311-3d374453df3f).

## Hosted toolchain

The official [Xcode 27 runner manifest](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md)
(image 20261012.0260.1) lists Xcode 27.1 build 27A9275 at
`/Applications/Xcode_27.1_Release_Candidate.app`, with the
`/Applications/Xcode_27.1.app` alias and iOS 27.1 SDK. GitHub's
[runner announcement](https://github.com/actions/runner-images/issues/14404)
documents the `xcode-27` public-preview label. The ordinary `macos-26` manifest
does not list Xcode 27.1.

The shared setup now selects Xcode 27.1; all dependent CI, TestFlight, and
App Review workflow jobs use `xcode-27`. This updates configuration only: no
workflow was dispatched and no release was uploaded. The pinned actionlint
needs an explicit allowlist entry for this hosted preview label; its config
calls that setting `self-hosted-runner`, but the workflow uses GitHub hosting.
Python workflow contracts and the full repository lint checks pass. A real
hosted run remains necessary to validate runner access and simulator provisioning.
The image manifest lists iOS 27.0 simulators, not a Duo runtime, so hosted CI is
not claimed to execute Duo-specific tests.

## Remaining visual checks

BigBook remains locked. `simctl help`, `simctl io`, and `simctl ui` expose display
capture/geometry and ordinary UI settings, but no supported hinge-pose or Split
View command. `devicectl device appResize` supports resizable app sessions for
CoreDevice targets, but `device info displays --device
DDD5C376-2134-4B8D-8F19-91F71F261CC5 --timeout 15` returns CoreDeviceError 1000,
"The specified device was not found" for the dedicated simulator. This is a
technical targeting limitation, not a permission denial. No unlock was attempted.

Use Device Hub when an interactive session is available to verify closed, open,
partially folded, rotated, and both Split View positions. Check Today, History,
Settings, onboarding, manual logging, and sheets at default and accessibility
text sizes. Rotation tests do not prove fold-transition or Split View behavior.
Do not claim complete Duo certification from these checks.
