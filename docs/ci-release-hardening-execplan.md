# CI Release Hardening

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This plan follows the repository instruction to use an ExecPlan for complex CI and release changes. The source planning rules live outside this repository at `~/.agents/PLANS.md`; this document is self-contained for the Sunclub changes described here.

## Purpose / Big Picture

Sunclub's App Store release path should fail early when a GitHub Actions step can hang, when a final IPA hides a signing or entitlement mistake, or when an embedded watch bundle is malformed. After this work, the GitHub workflows will bound every Xcode-heavy release step, the release diagnostics will preserve code-signing and entitlement data for every nested bundle instead of only the first extension, and local Python tests will enforce those release rules from a clean checkout.

## Progress

- [x] (2026-04-14T14:45:43Z) Read the repo release rules, existing CI workflows, App Store archive script, and metadata tests.
- [x] (2026-04-14T14:45:43Z) Started a Claude Code suggestion pass with `claude -p`; the first unbounded run hung without output and was interrupted, then a bounded read-only run was started.
- [x] (2026-04-14T14:52:15Z) Added workflow timeouts and compile-cache guards for App Review and TestFlight release steps.
- [x] (2026-04-14T14:52:15Z) Expanded IPA diagnostics and nested bundle validation in `scripts/appstore/archive-and-upload.sh`.
- [x] (2026-04-14T14:52:15Z) Added and updated tests that enforce the new CI and release invariants.
- [x] (2026-04-14T14:52:15Z) Updated release stability documentation with the new gates.
- [x] (2026-04-14T15:00:17Z) Ran the relevant local validation commands and recorded the result.
- [x] (2026-04-14T15:07:37Z) Fast-forward merged `origin/master`, asked Claude to review the listed hardening items with the current reasoning, implemented the concrete follow-ups, and reran validation.

## Surprises & Discoveries

- Observation: `release-testflight.yml` already disables Swift compile caching on the launch-safety unit test, but its archive/upload step had no `timeout-minutes` even though that step runs `xcodebuild archive` and `xcodebuild -exportArchive`.
  Evidence: `.github/workflows/release-testflight.yml` lines 67-73 contain the archive step and environment without a timeout.
- Observation: `submit-app-review.yml` runs screenshot capture, archive/upload, and submit-review commands without step-level timeouts. The screenshot and archive steps are Xcode-heavy.
  Evidence: `.github/workflows/submit-app-review.yml` lines 82-94 contain those steps without `timeout-minutes`.
- Observation: IPA diagnostics currently write app diagnostics and the first `.appex` found under `PlugIns`, which can miss watch extensions and additional app extensions.
  Evidence: `scripts/appstore/archive-and-upload.sh` uses `find "$signed_app_path/PlugIns" -maxdepth 1 -name '*.appex' -print -quit`.
- Observation: A no-tools Claude Code pass returned 50 suggestions after two repository-scanning Claude attempts timed out without output.
  Evidence: The successful command was `timeout 60 claude -p --tools '' --permission-mode dontAsk ...`; high-confidence items folded into this pass include stable Xcode pinning, release step timeouts, compile-cache guards, IPA/watch validation, release diagnostics, and a `just release-preflight` entry point.
- Observation: After merging `origin/master`, Claude reviewed the chosen hardening items and highlighted three cheap follow-ups: make the Xcode pin easier to audit, preserve watch version parity validation, and assert nested entitlement diagnostics more directly.
  Evidence: The successful review command was `timeout 120 claude -p --tools '' --permission-mode dontAsk ...`; the follow-ups were implemented by adding `SUNCLUB_XCODE_VERSION` workflow env values, final IPA watch `CFBundleShortVersionString` and `CFBundleVersion` checks, and stronger static tests.

## Decision Log

- Decision: Focus this pass on release/CI hardening instead of product feature additions.
  Rationale: The user's request explicitly prioritized GitHub CI and App Store release issues. The current repo already has many user-facing feature plans, while the highest-confidence improvements are safeguards that reduce release regressions without changing user data or app behavior.
  Date/Author: 2026-04-14 / Codex.
- Decision: Use static Python tests for workflow and shell-script invariants.
  Rationale: These checks must run from a clean checkout on Linux via `just test-python`, and they do not require Apple signing credentials or an exported IPA.
  Date/Author: 2026-04-14 / Codex.
- Decision: Implement Claude's release-hardening suggestions that were directly actionable in this repository, and defer broad product features or policy changes that need product review, Apple credentials, or GitHub repository settings.
  Rationale: The user's instruction allowed judgment on Claude's improvements. Changes such as branch protection, CODEOWNERS, nightly release builds, and migration-fixture expansion are valuable but require repository administration, credentials, or larger product/data work beyond a cohesive release hardening patch.
  Date/Author: 2026-04-14 / Codex.
- Decision: Keep the Xcode version pin duplicated as the same workflow-level env key in each iOS workflow rather than introducing a generated workflow or external config.
  Rationale: GitHub Actions cannot read a repository config file in a `uses.with` value before the job starts. A shared env key keeps each workflow self-contained, and Python tests enforce the same value and usage shape across CI, TestFlight, and App Review workflows.
  Date/Author: 2026-04-14 / Codex.

## Outcomes & Retrospective

Implemented a focused release hardening pass. CI now pins Xcode 26.3 for iOS jobs through a workflow env value, TestFlight archive/upload is timeout-bounded, App Review screenshot/archive/submission steps are timeout-bounded, and the App Review job exports `SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1`. The release archive script now writes diagnostics for every nested `.app` and `.appex` bundle and validates every nested bundle's code-signing identifier, including an explicit rejection of the WatchKit stub identifier `com.apple.WK`. Final IPA watch validation also checks watch marketing version and build number parity against the companion app. `just release-preflight` now runs strict metadata validation, Python guard tests, unit tests, and the release build shard with compile caching disabled for Xcode-heavy steps.

Validation passed for `bash -n scripts/appstore/archive-and-upload.sh`, targeted Python tests, full `just test-python`, and full `just ci-lint`. After merging `origin/master`, the final targeted Python check passed with 45 tests and the final full Python shard passed with 134 tests. A local `SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 just ci-build` attempt was started before the merge follow-up and then manually terminated after about five minutes with no new xcodebuild output and no visible compiler child process. The local toolchain is Xcode 26.5 build 17F5012f from `/Applications/Xcode-26.5.0-Beta.app`, while CI is now pinned to Xcode 26.3.

## Context and Orientation

The primary GitHub CI workflow is `.github/workflows/ci.yml`. It runs lint and Python tests on Ubuntu, and iOS unit tests, UI tests, and a release build on macOS. The TestFlight workflow is `.github/workflows/release-testflight.yml`; it is triggered by version tags and runs App Store metadata validation, release-safety unit tests, archive/export, upload, and artifact preservation. The App Review workflow is `.github/workflows/submit-app-review.yml`; it is manually dispatched for a release tag and runs screenshots, checkpoint creation, TestFlight upload, and final review submission.

The release archive script is `scripts/appstore/archive-and-upload.sh`. It generates the Tuist workspace, archives the app, optionally ad-hoc signs an unsigned archive with resolved release entitlements, exports an IPA, writes diagnostics to `.build/release-diagnostics`, validates the final signed IPA entitlements, validates the embedded watch app, and optionally uploads the IPA to TestFlight.

In this document, "IPA" means the `.ipa` archive uploaded to App Store Connect. "Entitlements" are Apple signing capabilities embedded into the final code signature, such as CloudKit, push notifications, and app groups. "Nested bundle" means an app extension, watch app, or watch extension inside the main iOS app bundle.

## Plan of Work

First, update `.github/workflows/release-testflight.yml` and `.github/workflows/submit-app-review.yml` so every Xcode-heavy release step has a bounded `timeout-minutes` value and the screenshot/archive steps carry `SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1`.

Second, update `scripts/appstore/archive-and-upload.sh` so release diagnostics are generated for every nested `.appex` and watch `.app`, and so the final IPA validation checks code-signing identifiers for every nested app and extension bundle. Keep the existing app entitlement and watch-app metadata checks intact.

Third, add tests in `tests/test_ios_metadata.py` that assert the workflow timeouts, compile-cache environment, all-bundle diagnostics, and nested bundle validation calls are present.

Fourth, update `docs/ci-release-stability.md` to document the new expectation that release diagnostics include every nested bundle and that App Review screenshots/archive steps are timeout-bounded.

## Concrete Steps

Run these commands from the repository root:

    just test-python
    just ci-lint

If macOS/Xcode validation is available after the focused checks pass, run:

    just ci-build

Commands run during this pass:

    bash -n scripts/appstore/archive-and-upload.sh
    uv run pytest tests/test_ios_metadata.py tests/test_tooling_config.py -q
    just test-python
    just ci-lint
    SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 just ci-build

The final `just ci-build` attempt was interrupted because the local Xcode 26.5 beta build produced no output for several minutes after build graph creation.

After merging `origin/master` and applying Claude's follow-up feedback, the final verification commands were:

    bash -n scripts/appstore/archive-and-upload.sh
    uv run pytest tests/test_ios_metadata.py tests/test_tooling_config.py -q
    just test-python
    just ci-lint

## Validation and Acceptance

`just test-python` should pass and should include tests proving the App Review and TestFlight workflows have release step timeouts, compile-cache guards where needed, and release script diagnostics/validation coverage for nested bundles.

`just ci-lint` should pass so shell, Python, web, and formatting checks accept the edited files. SwiftLint may report existing warning-level violations; the acceptance condition is the command exit code.

The release behavior is accepted when a final IPA export still validates main app entitlements and watch-app App Store constraints, while diagnostics now preserve code-signing and entitlement outputs for every nested bundle that exists in the IPA.

## Idempotence and Recovery

The workflow edits are declarative YAML changes and can be rerun safely. The archive script diagnostics delete only previous diagnostic files under `.build/release-diagnostics`, which is generated release output. If a local validation command fails because Xcode or Apple credentials are unavailable, keep the failure output and run the nearest clean-checkout command that does not require those external services.

## Artifacts and Notes

The first Claude Code command attempted was:

    claude -p "You are reviewing the Sunclub iOS sunscreen tracking app repository ..."

It remained silent for more than 90 seconds and was killed. A bounded read-only rerun was started with:

    timeout 180 claude -p --permission-mode bypassPermissions --tools 'Read,Grep,Glob' --max-budget-usd 2 "Review this repository ..."

That read-only run timed out with no output. A final no-tools prompt succeeded and returned 50 numbered suggestions:

    timeout 60 claude -p --tools '' --permission-mode dontAsk --max-budget-usd 1 "Return exactly 50 concise numbered suggestions ..."

The implemented subset covers Claude's stable Xcode pinning, Xcode-step timeout, compile-cache guard, post-export IPA validation, watch app validation, release diagnostics, and release preflight suggestions.

## Interfaces and Dependencies

No new third-party dependencies are introduced. The tests use Python's standard library and existing `pytest` setup. The shell script continues to depend on macOS release tools already required by the repository: `codesign`, `unzip`, `/usr/libexec/PlistBuddy`, `xcodebuild`, and `xcrun`.
