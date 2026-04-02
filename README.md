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

`just clean-build` removes repo-local build artifacts and the generated workspace, `just clean-generated` additionally removes repo-local caches and environments such as `.venv`, `.mise`, `.cache`, `.config`, `.state`, and `__pycache__`, and `just clean` runs the full cleanup chain.
