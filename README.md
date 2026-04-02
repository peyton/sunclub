# Sunclub

Repository layout:

- App: [app/README.md](app/README.md)
- Docs: [docs/](docs/)
- TestFlight flow: [docs/testflight-release.md](docs/testflight-release.md)

The iOS app lives in [app/](app). Product and design notes live in [docs/](docs).
Tooling is pinned in [mise.toml](mise.toml).

Common setup from the repo root:

- `just bootstrap`
- `just icons`
- `just generate`
- `just build`
- `just run`
- `just cloudkit-save-token`
- `just cloudkit-doctor`
- `just cloudkit-ensure-container`
- `just cloudkit-export-schema`
- `just cloudkit-validate-schema`
- `just cloudkit-import-schema`
- `just cloudkit-reset-dev`
- `just clean-build`
- `just clean-generated`
- `just clean`
- `just lint`
- `just fmt`
- `just test`
- `just test-unit`
- `just test-ui`
- `just test-python`
- `just ci-lint`
- `just ci-python`
- `just ci-build`
- `just appstore-validate`
- `just appstore-screenshots`
- `just appstore-archive`
- `just release-tag 1.2.3`
- `just ci`

`just bootstrap` installs repo-local tooling into `.mise/`, syncs the Python environment into `.venv/`, and prepares repo-local caches under `.cache/`.

Sunclub stays local-first, but the app now ships with default-on iCloud sync for revision history plus local backup export/import. Local imports stay recoverable on-device and do not change iCloud until the user explicitly publishes the imported batches from `Recovery & Changes`.

CloudKit setup is documented in [docs/cloudkit-setup.md](docs/cloudkit-setup.md). `just cloudkit-doctor` validates that the saved token is a management token for the configured team, checks whether a signed build actually carries the expected CloudKit entitlements, and retries `cktool` schema access. `just cloudkit-ensure-container` runs the same validation and opens the relevant Apple setup pages if the container or App ID configuration is still missing.

Release automation and the dev/prod flavor split are documented in [docs/testflight-release.md](docs/testflight-release.md). In short: local `just build` / `just run` use the `SunclubDev` flavor, `just appstore-archive` uses the production `Sunclub` flavor, and pushing a `vX.Y.Z` tag through `just release-tag` triggers the TestFlight workflow.

`just clean-build` removes repo-local build artifacts and the generated workspace, `just clean-generated` additionally removes repo-local caches and environments such as `.venv`, `.mise`, `.cache`, `.config`, `.state`, and `__pycache__`, and `just clean` runs the full cleanup chain.
