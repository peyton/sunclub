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

## Validation with Xcode 27.1

Use Xcode 27.1 (27A9275) explicitly without changing the system toolchain:

```sh
export DEVELOPER_DIR=/Applications/Xcode-27.1.0.app/Contents/Developer
just build
just ci-lint
just test-python
DEFAULT_SIMULATOR_DEVICE='iPhone Duo' \
  TEST_SIMULATOR_NAME='Sunclub Duo Adaptive Tests' \
  TEST_XCODEBUILD_MAX_ATTEMPTS=1 just test-unit
DEFAULT_SIMULATOR_DEVICE='iPhone Duo' \
  TEST_SIMULATOR_NAME='Sunclub Duo Adaptive Tests' \
  TEST_XCODEBUILD_MAX_ATTEMPTS=1 just test-ui
```

The local Duo simulator uses the installed iOS 27.2 Duo runtime (24B91011).
That runtime version is distinct from the selected Xcode 27.1 compiler and SDK.
The review verified 659 passing unit tests with this combination. Repository
lint and 279 Python tests also passed. Full UI coverage includes all 14 smoke
scenarios, including rotation, logged-state retention, and large-text controls.
The rotation test requires all three native tabs to exist and remain reachable;
missing custom identifiers must not silently skip overlap assertions.

Results are written to `.build/test-unit.xcresult` and
`.build/test-ui.xcresult`. See the candidate PR checks for current hosted results.
When cancelling a local test, wait for its underlying `xcodebuild` process to
exit before starting another test on the same simulator: delayed cleanup can
otherwise shut down the next test's device.

## Hosted toolchain

The official [Xcode 27 runner manifest](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md)
(image 20261012.0260.1) lists Xcode 27.1 build 27A9275 at
`/Applications/Xcode_27.1_Release_Candidate.app`, with the
`/Applications/Xcode_27.1.app` alias and iOS 27.1 SDK. GitHub's
[runner announcement](https://github.com/actions/runner-images/issues/14404)
documents the `xcode-27` public-preview label. The ordinary `macos-26` manifest
does not list Xcode 27.1.

The shared setup now selects Xcode 27.1; all dependent CI, TestFlight, and
App Review workflow jobs use `xcode-27`. The pinned actionlint
needs an explicit allowlist entry for this hosted preview label; its config
calls that setting `self-hosted-runner`, but the workflow uses GitHub hosting.
Hosted validation confirmed runner access, Xcode setup, both Release device
builds, and unit tests. Full UI results remain part of the required `CI` gate.
The image manifest lists iOS 27.0 simulators, not a Duo runtime, so hosted CI is
not claimed to execute Duo-specific tests.

## Remaining visual checks

Interactive fold and Split View checks remain required. Device Hub expansion
was unreliable during review, and Xcode 27.1's GUI showed component setup.
Command-line rotation tests do not prove fold-transition or Split View behavior.

Use Device Hub to verify closed, open, partially folded, rotated, and both Split
View positions. Check Today, History, Settings, onboarding, manual logging, and
sheets at default and accessibility text sizes. Do not claim complete Duo
certification from rotation checks alone.
