# Web Release Flow

Sunclub's public site is a static site in `web/`. GitHub Actions builds,
packages, and deploys it to Cloudflare Pages with Wrangler Direct Upload.

## GitHub Automation

`.github/workflows/deploy-web-cloudflare.yml` runs for pushes and pull requests
to `master` only when files under `web/` change.

- Pull requests run `just web-package` and upload a rollback artifact.
- Pushes to `master` run the same packaging step, then deploy `.build/web` to
  the Cloudflare Pages project `sunclub`.
- Cloudflare-side Git automatic builds should stay disabled; GitHub Actions is
  the deployment source.

Required GitHub Actions secrets:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`

The existing iOS release secrets are not used by web workflows:

- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_KEY_P8`

## Commands

From the repo root:

```bash
just web-check
just web-build
just web-package VERSION=test
just web-release-tag 1.2.3
```

`just web-package VERSION=1.2.3` writes:

- `.build/releases/sunclub-web-1.2.3.tar.gz`
- `.build/releases/sunclub-web-1.2.3.tar.gz.sha256`

`just web-release-tag 1.2.3` requires a clean worktree, creates
`web/v1.2.3`, and pushes it. `.github/workflows/release-web.yml` then creates
a GitHub Release with the package and checksum.

## Rollback

Cloudflare Pages keeps successful production deployments available for dashboard
rollback. The repository also keeps web release artifacts so rollback can be
done from GitHub.

Use `.github/workflows/rollback-web-cloudflare.yml` and provide a release tag
such as `web/v1.2.3`. The workflow downloads the matching release tarball and
checksum, verifies the checksum, extracts the site, and redeploys it to the
production Cloudflare Pages branch.

## Release Split

- Web releases use tags shaped like `web/vX.Y.Z`.
- iOS TestFlight releases use tags shaped like `vX.Y.Z`.
- Web workflows never use App Store Connect secrets.
- iOS workflows never use `web/v*.*.*` tags.
