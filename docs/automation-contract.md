# Repository automation contract

- Public command interface: [commands](commands.md), implemented by root `justfile`.
- Application automation: [App Intents, URL and callback contracts](app-automation.md).
- Ownership and feature changes: [architecture](architecture.md).
- Supported execution: local macOS and GitHub Actions.
- Environment setup is separate from Xcode preparation. Bootstrap, lint and Python
  tests never start Tuist services or resolve release metadata.
- `mise.lock` and `uv.lock` are enforced. Shared wrappers keep caches and state in
  the repository; do not modify machine-global tooling configuration.
- The setup composite action configures authenticated Tuist caching once per
  macOS job. Local cache installation is explicit with `just cache-setup`.
- Build/test/screenshot/archive entrypoints use the shared generation and Xcode
  invocation primitives. Ordinary builds generate automatically when needed.
- hk owns lint/formatting: Markdown, Pkl, shellcheck, shfmt, Prettier and Ruff;
  SwiftLint runs on macOS. Asset JSON stays in formatting coverage.
- Diagnostics and generated outputs go under `.build/` and `.DerivedData/`.
  These directories are not CI caches.
