# Commands

Run from the repository root. `just --list` is the complete executable reference.
Supported environments: local macOS with stable Xcode, and GitHub Actions.

| Command                                    | Behavior                                                                       |
| ------------------------------------------ | ------------------------------------------------------------------------------ |
| `just bootstrap`                           | Install locked mise tools and sync Python dependencies; no Xcode service       |
| `just build`                               | Generate as needed; SunclubDev Debug simulator build                           |
| `just run`                                 | Build, install and launch using the development build directory                |
| `just test-unit`                           | All Swift unit tests                                                           |
| `just test-unit ClassName/testMethod`      | Filter unit tests                                                              |
| `just test-ui-smoke`                       | The 13 PR smoke scenarios                                                      |
| `just test-ui`                             | Every UI test, including smoke                                                 |
| `just test-python`                         | Tooling, release, metadata and website contracts                               |
| `just ci-build dev` / `just ci-build prod` | Selected Release device build                                                  |
| `just ci`                                  | Lint, Python, full Swift unit/UI tests, both device builds                     |
| `just lint` / `just fmt`                   | Check / format with hk and web validation                                      |
| `just generate`                            | Force regeneration for opening Xcode; ordinary commands generate automatically |
| `just cache-setup`                         | Explicit optional local Tuist cache installation                               |
| `just icons` / `just visual-assets`        | Regenerate owned icon / non-logo artwork                                       |

Bootstrap enforces `mise.lock`. Change tool versions and refresh the lockfile
intentionally. Lint and Python commands do not resolve release versions or start
Tuist services. Build commands fingerprint manifests, membership, tool versions,
and generation environment; adding a source file requires no manual generation. Ordinary builds use a stable development
build number; explicit versions and release numbering still invalidate generation.

Use `DEVELOPER_DIR=/Applications/Xcode-VERSION.app/Contents/Developer` to select a
local stable Xcode without changing the machine default. For compile-cache
recovery, set `SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1`. Local builds default to
cache disabled so a cold checkout works without a daemon. After `just cache-setup`,
opt in with `SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=0`. GitHub builds default to
caching enabled after authenticated setup. Extra deliberate overrides
use `BUILD_XCODEBUILD_ARGS` or `TEST_XCODEBUILD_ARGS`.

CI prepares authenticated caching once per macOS job through the shared setup
action. Build, test, screenshot and archive entrypoints reuse
`scripts/tooling/common.sh`; signing and export remain in `scripts/appstore/`.

To request full CI for a candidate branch, run:

```sh
gh workflow run ci.yml --ref BRANCH
```

Release uploads require successful full CI on their exact SHA. PR smoke evidence
alone does not satisfy this gate.

## Release & App Store Commands

| Surface            | Command                         |
| ------------------ | ------------------------------- |
| App Review env     | `just appstore-env`             |
| Draft metadata     | `just appstore-validate`        |
| Strict metadata    | `just appstore-validate-strict` |
| Review package     | `just appstore-review-package`  |
| Screenshots        | `just appstore-screenshots`     |
| Archive            | `just appstore-archive`         |
| App Review dry run | `just appstore-submit-dry-run`  |
| App Review draft   | `just appstore-submit-draft`    |
| App Review submit  | `just appstore-submit-review`   |
| App Review alias   | `just appstore-send-review`     |
| Release doctor     | `just release-doctor`           |
| Release tag        | `just release-tag 1.2.3`        |
| TestFlight alias   | `just release-testflight 1.2.3` |

After full CI passes for the candidate SHA, request signed export validation:

```sh
gh workflow run release-testflight.yml --ref BRANCH
```

Manual runs use the GitHub `testflight` environment to archive, sign, export and
validate the IPA. They do not upload to TestFlight or change tester groups.
Download `sunclub-export-RUN_ID` from that run for the archive, IPA and final
signing/watch diagnostics. Pushed release tags retain upload and tester behavior.
See [TestFlight release](testflight-release.md) for artifact inspection.

## Web & Cloudflare Commands

| Surface           | Command                               |
| ----------------- | ------------------------------------- |
| Local web preview | `just web-serve`                      |
| Web validation    | `just web-check`                      |
| Web format        | `just web-fmt`                        |
| Web build         | `just web-build`                      |
| Web build/package | `just web-package VERSION=test`       |
| Web release tag   | `just web-release-tag 1.2.3`          |
| Cloudflare status | `just cloudflare-status`              |
| Pages status      | `just cloudflare-pages-status`        |
| Pages setup       | `just cloudflare-pages-setup`         |
| Pages DNS setup   | `just cloudflare-pages-dns`           |
| Cloudflare deploy | `just cloudflare-pages-deploy master` |
| Email status      | `just cloudflare-email-status`        |
| Email setup       | `just cloudflare-email-setup`         |
| Cloudflare check  | `just cloudflare-check`               |

## CloudKit Commands

| Surface          | Command                          |
| ---------------- | -------------------------------- |
| Save token       | `just cloudkit-save-token`       |
| Doctor           | `just cloudkit-doctor`           |
| Ensure container | `just cloudkit-ensure-container` |
| Export schema    | `just cloudkit-export-schema`    |
| Validate schema  | `just cloudkit-validate-schema`  |
| Import schema    | `just cloudkit-import-schema`    |
| Reset dev        | `just cloudkit-reset-dev`        |

## Maintenance Commands

| Surface                 | Command                |
| ----------------------- | ---------------------- |
| Build cleanup           | `just clean-build`     |
| Generated/cache cleanup | `just clean-generated` |
| Full cleanup            | `just clean`           |
