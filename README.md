# Sunclub

Repository layout:

- App: [app/README.md](app/README.md)
- Docs: [docs/](docs/)

The iOS app lives in [app/](app). Product and design notes live in [docs/](docs).
Tooling is pinned in [mise.toml](mise.toml).

Common setup from the repo root:

- `mise install`
- `just icons`
- `just generate`
- `just build`
- `just run`
- `just test`
- `just test-unit`
- `just test-ui`
- `just test-python`
- `just appstore-validate`
- `just appstore-screenshots`
- `just ci`

`just download-model` is only needed when you want to stage the FastVLM On-Demand Resource for local verification or release packaging.
