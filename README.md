# Sunclub

Repository layout:

- App: [app/README.md](app/README.md)
- Docs: [docs/](docs/)

The iOS app lives in [app/](app). Product and design notes live in [docs/](docs).
Tooling is pinned in [mise.toml](mise.toml).

Common setup from the repo root:

- `just bootstrap`
- `just icons`
- `just generate`
- `just build`
- `just run`
- `just cloudkit-save-token`
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
- `just ci`

`just bootstrap` installs repo-local tooling into `.mise/`, syncs the Python environment into `.venv/`, and prepares repo-local caches under `.cache/`.

Sunclub stays local-first, but the app now ships with default-on iCloud sync for revision history plus local backup export/import. Local imports stay recoverable on-device and do not change iCloud until the user explicitly publishes the imported batches from `Recovery & Changes`.

`just clean-build` removes repo-local build artifacts and the generated workspace, `just clean-generated` additionally removes repo-local caches and environments such as `.venv`, `.mise`, `.cache`, `.config`, `.state`, and `__pycache__`, and `just clean` runs the full cleanup chain.
