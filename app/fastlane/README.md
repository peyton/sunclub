fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios prepare_model

```sh
[bundle exec] fastlane ios prepare_model
```

Ensure the FastVLM 0.5B model is present for local runs

### ios unit_tests

```sh
[bundle exec] fastlane ios unit_tests
```

Run Sunclub unit tests

### ios ui_tests

```sh
[bundle exec] fastlane ios ui_tests
```

Run Sunclub UI tests

### ios tests

```sh
[bundle exec] fastlane ios tests
```

Run all automated tests

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Capture App Store screenshots from the UI test flow

### ios build

```sh
[bundle exec] fastlane ios build
```

Create an unsigned archive for local validation

### ios launch

```sh
[bundle exec] fastlane ios launch
```

Build the debug app for the simulator, install it, and launch it

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Run tests, build a signed ipa, and upload it to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Run tests, build a signed ipa, and upload it to App Store Connect

### ios submit_release

```sh
[bundle exec] fastlane ios submit_release
```

Upload the current release build and submit it for App Store review

### ios ci

```sh
[bundle exec] fastlane ios ci
```

CI-friendly lane for local validation

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
