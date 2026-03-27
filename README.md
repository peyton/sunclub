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

`just download-model` is only needed when you want to stage the FastVLM On-Demand Resource for local verification or release packaging.
