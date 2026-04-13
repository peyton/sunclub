# Automation Contract

## Public Commands

Run all human and CI automation from the repo root with `just`.

- Setup: `just bootstrap`
- App: `just icons`, `just generate`, `just build`, `just run`
- Web: `just web-serve`, `just web-check`, `just web-fmt`, `just web-build`, `just web-package`, `just web-release-tag`, `just cloudflare-pages-deploy`
- Verification: `just lint`, `just fmt`, `just test-python`, `just test-unit`, `just test-ui`, `just test`
- CI shards: `just ci-lint`, `just ci-python`, `just ci-build`, `just ci`
- Release-adjacent: `just appstore-validate`, `just appstore-screenshots`, `just appstore-archive`, `just release-tag`, `just web-release-tag`

## Ownership

- Root `just` recipes are the canonical interface.
- Shared wrappers live in `scripts/tooling/`.
- GitHub Actions calls only the root CI shard and web recipes.
- Xcode Cloud scripts stay in `app/ci_scripts/`, but only as provider glue that delegates back to `scripts/tooling/`.

## Environment

- `bin/mise` localizes tool installs and config into `.mise/`.
- Shared wrappers export repo-local cache/state directories under `.cache/`, `.config/`, and `.state/`.
- `just bootstrap` installs tools and runs `uv sync --group dev --group eval`.

## Linting

- Cross-platform lint runs through `hk` for markdown, pkl, shellcheck, shfmt, Prettier, and Ruff.
- JSON and YAML stay in the Prettier contract, including `*.xcassets/**/Contents.json`.
- SwiftLint runs separately on macOS with an explicit repo-local cache path.
- Asset JSON stays in the Prettier contract; do not exclude `*.xcassets/**/Contents.json`.

## Troubleshooting

- If Python tooling is missing, re-run `just bootstrap`.
- If Xcode project files drift, re-run `just generate`.
- If CI cache or tool state looks stale, remove `.cache/`, `.state/`, `.venv/`, and `.mise/`, then run `just bootstrap` again.
