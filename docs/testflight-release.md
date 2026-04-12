# TestFlight Release Flow

## Flavors

- `SunclubDev`
  - bundle ID: `app.peyton.sunclub.dev`
  - widget bundle ID: `app.peyton.sunclub.dev.widgets`
  - app group: `group.app.peyton.sunclub.dev`
  - CloudKit container: `iCloud.app.peyton.sunclub.dev`
  - URL scheme: `sunclub-dev`
- `Sunclub`
  - bundle ID: `app.peyton.sunclub`
  - widget bundle ID: `app.peyton.sunclub.widgets`
  - app group: `group.app.peyton.sunclub`
  - CloudKit container: `iCloud.app.peyton.sunclub`
  - URL scheme: `sunclub`

`just build`, `just run`, and the iOS test commands use `SunclubDev` so local builds can install alongside TestFlight.
`just appstore-archive` and the release workflow use `Sunclub`.

## Versioning

- Source env contract:
  - `SUNCLUB_MARKETING_VERSION`
  - `SUNCLUB_BUILD_NUMBER`
  - `SUNCLUB_FLAVOR`
  - `SUNCLUB_APS_ENVIRONMENT`
- Tooling mirrors those values into `TUIST_*` variables before `tuist generate` because Tuist manifests only read `TUIST_`-prefixed environment variables.
- `CFBundleShortVersionString` comes from `MARKETING_VERSION`.
- `CFBundleVersion` comes from `SUNCLUB_BUILD_NUMBER`.
- `CURRENT_PROJECT_VERSION` uses the digits-only projection of `SUNCLUB_BUILD_NUMBER` because Tuist/Xcode collapses dotted values like `20260402.201943.0` back to `1`.
- App Store archives force `SUNCLUB_APS_ENVIRONMENT=production` before generation so the signed archive uses production push entitlements.

Resolved values:

- Tag release:
  - marketing version: `vX.Y.Z -> X.Y.Z`
  - build number: `YYYYMMDD.GITHUB_RUN_NUMBER.GITHUB_RUN_ATTEMPT`
- Local dev:
  - marketing version: latest reachable `vX.Y.Z`, fallback `1.0.0`
  - build number: `YYYYMMDD.HHMMSS.0`

Normal build commands regenerate the workspace before `xcodebuild` so the resolved version always reaches the generated project.

## Release Commands

From the repo root:

```bash
just appstore-validate
just appstore-screenshots
just appstore-archive
just release-tag 1.2.3
```

`just release-tag 1.2.3` validates semver, requires a clean worktree, creates `v1.2.3`, and pushes it.
The tag workflow archives with `--allow-draft-metadata` so TestFlight uploads are not blocked on final App Store support/privacy URLs or the App Review contact.
Keep `just appstore-archive` strict for final submission-ready archives.
The production flavor uses automatic signing with an Apple Distribution identity for Release builds. Development flavors keep development signing so local installs and tests continue to use dev profiles.

## GitHub Automation

`.github/workflows/release-testflight.yml` runs on pushed tags matching `v*.*.*`.

It:

1. resolves release versions
2. validates App Store metadata
   - uses draft mode for TestFlight-only fields
3. archives and exports the production IPA on pinned stable Xcode `26.3`
4. uploads the IPA to TestFlight with `altool` and App Store Connect API key auth
5. publishes the `.xcarchive` and exported IPA as workflow artifacts

Required secrets:

- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_KEY_P8`

## Simulator Notes

- Local simulator builds are unsigned by default.
- The build scripts disable Xcode compilation caches automatically on beta Xcode installations because the cache service can fail and leave incomplete app bundles.
- Unsigned simulator runs fall back to the no-op Cloud sync coordinator when the app-group container is unavailable, which keeps local launch logs clean without changing signed release behavior.
