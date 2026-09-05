# Sunclub

iOS sunscreen tracking app. Keep existing features, public automation routes,
platform targets, persisted identities, signing identifiers and recovery behavior.

## Start here

```sh
just bootstrap
just build
just run
```

Build/run use **SunclubDev**, Debug, iPhone simulator. Release uses **Sunclub**.
Generation is automatic. Bootstrap installs locked tools and Python dependencies;
optional local Tuist caching is `just cache-setup`.

- [Architecture and feature recipe](docs/architecture.md)
- [Commands](docs/commands.md)
- [Release gates](docs/release-gates.md) — mandatory data, accessibility and automation rules
- [CI and release stability](docs/ci-release-stability.md)
- [Historical troubleshooting](docs/development-troubleshooting.md)
- [Public automation contract](docs/app-automation.md)
- Design: `DESIGN.md`, `AppDesignSystem.swift`; product: `app/SPEC.md`

## Working rules

- Swift 6 strict concurrency; 4-space indentation. Reuse existing protocols;
  inject external services and the clock through `SunclubAppDependencies`.
- `AppState` owns observable state and coordination. Shared writes belong in
  `SunclubMutationService` and revision-history services. Effects follow a
  successful changed receipt; automation authorization stays at its entrypoint.
- No new dependencies or framework/package layers merely for organization.
- Never change persisted fields without a new immutable versioned schema and
  prior-store migration tests. Every container uses `SunclubModelContainerFactory`.
- Preserve local and CloudKit history. Empty startup state must never replace
  meaningful history; reinstall restore fetches before publishing.
- Preserve the accessibility scorecard: named controls, Dynamic Type, sufficient
  contrast, non-color cues and Reduce Motion through `SunMotion`. UI tests keep
  `UITEST_MODE` and deterministic `UITEST_FORCE_*` arguments.
- New user features need App Intent and URL/foreground routes, Settings controls,
  automation documentation and tests. Keep legacy redirects and permission gates.
- Styling uses `AppDesignSystem.swift` and `AppTheme.swift`. Do not change visual
  direction as an incidental refactor. Generated artwork belongs to its generator.
- Specs, plans and tool documentation go in `docs/`, kept terse. No ticket IDs in
  document filenames or headers.
- One PR per task. Commits use `feat:`, `fix:` or `chore:` (`PER-XX:` for ticketed
  work). PR descriptions include verification.

## Verify

- App: `just test-unit`, `just test-ui-smoke`; full candidate: `just ci`.
- Scripts/metadata: `just test-python`. Style: `just ci-lint`.
- CI/workflow edits require the closest local CI-equivalent check and passing
  expected GitHub jobs. Never infer readiness from skipped checks.
- Refactor/release candidates need full CI on the exact SHA. Only known web/docs
  PRs skip iOS; unknown changes run it. Preserve the required `CI` gate.
- Signing, store, import and sync changes must satisfy all
  [data release gates](docs/release-gates.md). Before trusting an upload, inspect
  final IPA entitlements and embedded watch diagnostics, not just profiles.
- App Review submission requires a dry run and review checkpoint before final
  submission. See [App Store submission](docs/app-store-submission.md).
