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
- Supply an explicit native back-item title on iOS 27.1 and later. An empty
  navigation title otherwise leaves Duo's vertical Back control unnamed. Keep
  UIKit's native action and transition delegate; verify the accessible name and
  return navigation in the large-text forecast test.
- Find native Back controls outside horizontal navigation-bar containers in UI
  tests. Fully reveal the large-text reminder switch before tapping it and
  verify that it turned on before looking for interval controls. The accessibility
  scenario accepts native tab labels when custom identifiers have not yet installed.

## Validation with Xcode 27.2

The [November 12 usability audit](duo-usability-audit.md) records current
screenshots, simplifications, fold checks, and local verification on Xcode 27.2
with Duo runtime 24B91016s.

Use Xcode 27.2 (27B52) explicitly without changing the system toolchain:

```sh
export DEVELOPER_DIR=/Applications/Xcode-27.2.0.app/Contents/Developer
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

The original automated Duo pass used iOS 27.2 (24B91011) with Xcode 27.1.
That historical result does not validate the current Xcode 27.2 candidate.
The review verified 659 passing unit tests with this combination. Repository
lint and 279 Python tests also passed. Full UI coverage includes all 14 smoke
scenarios, including rotation, logged-state retention, and large-text controls.
The rotation test requires all three native tabs to exist and remain reachable;
missing custom identifiers must not silently skip overlap assertions. Native-tab
checks accept horizontal or vertical placement. Rotation checks scroll the whole
log button into view; XCTest hittability alone can include a partially clipped
button in a short landscape window.

Results are written to `.build/test-unit.xcresult` and
`.build/test-ui.xcresult`. See the candidate PR checks for current hosted results.
When cancelling a local test, wait for its underlying `xcodebuild` process to
exit before starting another test on the same simulator: delayed cleanup can
otherwise shut down the next test's device.

## Hosted toolchain

The official [Xcode 27 runner manifest](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md)
(image 20261104.0337.1, checked November 12, 2026) lists stable Xcode 27.2 build
27B52 at `/Applications/Xcode_27.2.app`, with iOS 27.2 SDK and iPhone Duo
simulators for iOS 27.1 and 27.2. GitHub's
[runner announcement](https://github.com/actions/runner-images/issues/14404)
documents the `xcode-27` public-preview label.

The shared setup selects Xcode 27.2; all dependent CI, TestFlight, and
App Review workflow jobs use `xcode-27`. The pinned actionlint
needs an explicit allowlist entry for this hosted preview label; its config
calls that setting `self-hosted-runner`, but the workflow uses GitHub hosting.
Full UI coverage runs on master pushes and manual CI dispatches. The required
`CI` merge gate does not wait for UI tests; release validation separately requires
successful full CI, including the full UI step, on the exact source SHA.
The default hosted simulator remains a conventional iPhone. Duo validation
requires the explicit simulator selection shown above.

Apple's [Xcode 27.2 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes)
document that Duo captures can be black for a few minutes after boot. Wait for
a visible, stable screen before accepting screenshots. Device Hub also cannot
convey Duo screen content to VoiceOver or Accessibility Inspector; screenshots
and automated checks do not establish physical-device accessibility coverage.

## Interactive validation (October 18, 2026)

Xcode 27.1 Device Hub and the matching iOS 27.1 runtime (24A94425) were
used for the interactive pass. The earlier unavailable device view was resolved
by restarting the stale CoreDeviceService; simulator boot state alone did not
prove Device Hub connectivity.

- Completed onboarding from the cover display through unfolding.
- Verified Today logging and History editing in left Split View; saved SPF 50
  remained visible after closing and reopening the device.
- Verified right Split View beside the system Settings app, including Sunclub
  Settings, nested Reminders, and the weekday time-picker sheet.
- Repeated Today and manual logging with accessibility text, dark mode, Reduce
  Motion, increased contrast, and non-color cues. Expanded details scrolled to
  coverage and Notes; Save returned to the logged Today state.
- Checked closed, partially open, and open poses with the large-text logged state,
  then moved Sunclub to left Split View and navigated to History.
- Found that the large-text History week row clipped later days in Split View.
  It now wraps into an adaptive grid at accessibility sizes. The rebuilt app
  displayed all seven days beside the original clipped layout. A UI smoke
  regression checks that all seven day controls fit horizontally.

The earlier iOS 27.2 interactive pass also exercised an unsaved SPF selection
across fold transitions, History calendar expansion, Settings, and a reminder
sheet across rotation and unfolding. These are simulator checks, not physical
hardware certification. Recheck these flows when changing native navigation,
safe-area handling, or the shared screen containers.
