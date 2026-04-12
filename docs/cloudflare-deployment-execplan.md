# Cloudflare Website and Email Deployment

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

The local PLANS guidance used for this work was found at `/Users/peyton/.agents/PLANS.md`; the originally referenced `/Users/peyton/.agent/PLANS.md` does not exist in this environment.

## Purpose / Big Picture

Sunclub needs a public website and working support email surface that are stable enough for App Store review. After this change, the existing static site in `web/` can be connected to Cloudflare Pages at `https://sunclub.peyton.app`, and Cloudflare Email Routing can forward inbound `peyton.app` mail to the owner's private inbox without committing that inbox address. The iOS app Settings screen will also include visible support, privacy, and email links so reviewers and users can reach the same public pages from inside the app.

## Progress

- [x] (2026-04-12T00:00-07:00) Confirmed the requested implementation plan and repo orientation.
- [x] (2026-04-12T00:00-07:00) Confirmed `/Users/peyton/.agent/PLANS.md` is absent and `/Users/peyton/.agents/PLANS.md` exists.
- [x] (2026-04-12T00:00-07:00) Added tracked Cloudflare configuration under `infra/cloudflare/`.
- [x] (2026-04-12T00:00-07:00) Added standard-library Cloudflare helper scripts under `scripts/cloudflare/`.
- [x] (2026-04-12T00:00-07:00) Wired root `just` targets for Cloudflare status, setup, and checks.
- [x] (2026-04-12T00:00-07:00) Added Help & Legal links to the iOS Settings screen.
- [x] (2026-04-12T00:00-07:00) Added Python and UI test coverage.
- [x] (2026-04-12T00:00-07:00) Ran validation commands and recorded results.
- [x] (2026-04-12T00:00-07:00) Switched web deployment ownership from Cloudflare Git integration to GitHub Actions Direct Upload.

## Surprises & Discoveries

- Observation: The current Cloudflare API token available to this session could list the `peyton.app` zone but could not inspect DNS or Email Routing state.
  Evidence: Cloudflare API calls to DNS and Email Routing returned authentication errors while listing the zone succeeded.

- Observation: Adding a new Swift file required regenerating the Tuist workspace before UI tests could compile it.
  Evidence: The first `just test-ui` attempt failed with `Cannot find 'SunclubWebLinks' in scope`; `just generate` refreshed the generated Xcode workspace and the next builds compiled.

- Observation: UI tests currently compile but cannot launch because CoreSimulatorService dies while installing the runner.
  Evidence: `just test-ui` fails after build with `NSMachErrorDomain Code -308 (ipc/mig) server died` and `Failed to install or launch the test runner`; rerunning after `xcrun simctl shutdown all` produced the same simulator-service failure.

- Observation: The Cloudflare OpenAPI metadata available through the Cloudflare MCP matches the REST endpoints and payload keys used by the scripts.
  Evidence: The spec lists Pages project create/update, Pages custom domains, Email Routing destination addresses, Email Routing DNS/enable, and catch-all rule update endpoints with the fields used here.

## Decision Log

- Decision: Initially use Cloudflare Pages Git integration rather than Direct Upload.
  Rationale: This was the original deployment direction, but it has since been superseded by GitHub Actions Direct Upload to keep web and iOS monorepo releases separate.
  Date/Author: 2026-04-12 / Codex

- Decision: Supersede Cloudflare-side Git automatic builds with GitHub Actions Direct Upload for web deploys.
  Rationale: Web and iOS release trains need separate monorepo workflows. GitHub Actions can path-filter `web/**`, package rollback artifacts, and deploy through Wrangler while the iOS tag workflow remains isolated.
  Date/Author: 2026-04-12 / Codex

- Decision: Keep the forwarding destination out of tracked files and read it from `SUNCLUB_FORWARD_TO`.
  Rationale: The destination is a private inbox address. Using an environment variable keeps setup repeatable without exposing the address in git.
  Date/Author: 2026-04-12 / Codex

- Decision: Make status commands safe without credentials, while setup commands require credentials.
  Rationale: Repo-root commands should be runnable from a clean checkout for local validation. Remote mutation and real status need Cloudflare credentials, so those paths must fail clearly only when explicitly invoked for setup.
  Date/Author: 2026-04-12 / Codex

## Outcomes & Retrospective

Implemented repo-root Cloudflare deployment tooling, tracked Cloudflare configuration, Settings links for App Store review, and tests for the new Python configuration helpers. Web deployment is now owned by GitHub Actions Direct Upload; any existing Cloudflare Git integration should have automatic production and preview builds disabled. Remote Cloudflare state was not mutated in this session because no usable `CLOUDFLARE_API_TOKEN` and `SUNCLUB_FORWARD_TO` were present.

Validation results:

- `just web-check`: passed as part of `just cloudflare-check`, `just web-build`, and `just lint`.
- `just web-build`: passed.
- `just cloudflare-status`: passed; remote checks skipped because `CLOUDFLARE_API_TOKEN` was not set.
- `just cloudflare-pages-status`: passed; remote check skipped because `CLOUDFLARE_API_TOKEN` was not set.
- `just cloudflare-email-status`: passed; remote check skipped because `CLOUDFLARE_API_TOKEN` was not set and `SUNCLUB_FORWARD_TO` was missing.
- `just cloudflare-check`: passed; local config validation passed and remote checks were skipped without credentials.
- `uv run pytest tests/test_web_static_site.py tests/test_cloudflare_config.py -v`: passed, 8 tests.
- `just lint`: passed, with existing SwiftLint warning-level violations and zero serious violations.
- `just build`: passed after `just generate`.
- `just test-ui`: blocked by CoreSimulatorService launch failure after compilation, not by a Swift compile error.

## Context and Orientation

The public static site lives under `web/`. It already contains `index.html`, `support/index.html`, `privacy/index.html`, `404.html`, `robots.txt`, `sitemap.xml`, and shared assets. The repo has `just web-check`, `just web-build`, and `just web-serve` commands in the root `justfile`.

The iOS app lives under `app/`. The Settings screen is implemented in `app/Sunclub/Sources/Views/SettingsView.swift`. The app target in `app/Sunclub/Project.swift` includes every file under `app/Sunclub/Sources/**`, so a new shared Swift file under `app/Sunclub/Sources/Shared/` is automatically compiled into the app target.

Cloudflare Pages is the Cloudflare static-hosting product used here. GitHub Actions deploys the static site with Wrangler Direct Upload whenever `web/**` changes land on `master`; Cloudflare-side Git automatic builds should stay disabled. Cloudflare Email Routing is the Cloudflare inbound-mail forwarding product. A catch-all rule means any address at `peyton.app`, such as `sunclub@peyton.app` or `support@peyton.app`, forwards to the configured destination.

The Cloudflare account is `0e32ee7804b102bea6b9d3056d60f980` named Personal. The `peyton.app` zone is `a004f01ed99de3582152debde5a96a08` and is active. The GitHub repository is `peyton/sunclub`, and `origin/HEAD` points to `master`.

## Plan of Work

Create `infra/cloudflare/` as the tracked source of truth for Cloudflare setup. `pages-project.json` describes the Pages project named `sunclub`, production branch `master`, custom domain `sunclub.peyton.app`, GitHub Actions Direct Upload mode, build command `just web-build`, output directory `.build/web`, and required GitHub Actions secrets. `email-routing.json` describes a catch-all forwarding rule for `peyton.app`, with its destination read from `SUNCLUB_FORWARD_TO`. `infra/cloudflare/.env.example` documents the required local environment variables, while the real `.env` remains ignored.

Create `scripts/cloudflare/` with Python modules that use only the standard library. `common.py` will load config, validate environment variables, call Cloudflare's REST API, and expose idempotent helpers. `pages.py` will inspect or set up the Pages project and custom domain. `email.py` will inspect or set up destination addresses, Email Routing DNS, Email Routing enablement, and the catch-all rule.

Update the root `justfile` with `cloudflare-status`, `cloudflare-pages-setup`, `cloudflare-pages-status`, `cloudflare-email-setup`, `cloudflare-email-status`, and `cloudflare-check`. The status and check targets should succeed without credentials by validating local config and explaining that remote checks were skipped. The setup targets should require `CLOUDFLARE_API_TOKEN`; email setup should also require `SUNCLUB_FORWARD_TO`.

Add `app/Sunclub/Sources/Shared/SunclubWebLinks.swift` with canonical URLs for support, privacy, and email support. Extend `SettingsView` with a new `Help & Legal` settings section that opens those URLs through SwiftUI's `openURL` environment value. Keep this section separate from data and sync settings.

Add tests. Python tests should cover config parsing, missing environment handling, API payload shape, and idempotent behavior when a Pages custom domain or Email Routing destination already exists. UI tests should assert that Help & Legal and its support, privacy, and email buttons exist without tapping them.

## Concrete Steps

From the repository root, add the config, scripts, app links, and tests. Then run:

    just web-check
    just web-build
    just cloudflare-status
    just cloudflare-pages-status
    just cloudflare-email-status
    just cloudflare-check
    uv run pytest tests/test_web_static_site.py tests/test_cloudflare_config.py -v
    just lint

If credentials are available, run:

    CLOUDFLARE_API_TOKEN=... just cloudflare-pages-setup
    CLOUDFLARE_API_TOKEN=... SUNCLUB_FORWARD_TO=owner@example.com just cloudflare-email-setup

If an existing Pages project is still connected to Cloudflare's Git integration, Pages setup should disable automatic production and preview deployments so GitHub Actions remains the deployment source.

## Validation and Acceptance

Local acceptance requires `just web-check`, `just web-build`, `just cloudflare-status`, `just cloudflare-pages-status`, `just cloudflare-email-status`, `just cloudflare-check`, and `uv run pytest tests/test_web_static_site.py tests/test_cloudflare_config.py -v` to pass from the repo root. `just lint` must also pass or report only pre-existing SwiftLint warnings while exiting zero.

App acceptance requires the Settings UI test to find the section button `settings.section.help` and the buttons `settings.support`, `settings.privacyPolicy`, and `settings.emailSupport`.

Remote acceptance, when credentials are available, requires `just cloudflare-pages-setup` to create or update a Pages project named `sunclub`, attach `sunclub.peyton.app`, keep Cloudflare-side Git automatic builds disabled when source control is present, and report the project/domain status. It also requires `just cloudflare-email-setup` to ensure Email Routing is enabled and the catch-all rule forwards to the verified `SUNCLUB_FORWARD_TO` address.

## Idempotence and Recovery

The setup scripts must be safe to rerun. If the Pages project already exists, update its build configuration and disable Cloudflare-side Git automatic deployments when a source configuration is present instead of creating a duplicate. If the custom domain already exists, leave it in place. If the forwarding destination already exists, reuse it. If the destination exists but is not verified, tell the operator to verify it and rerun the setup command. If Email Routing is already enabled, leave it enabled and update the catch-all rule to the desired state.

No script should store secrets in tracked files. A local `infra/cloudflare/.env` file may be used by shell users, but it must stay ignored by git.

## Artifacts and Notes

The GitHub OAuth step cannot always be completed through the Cloudflare REST API because Cloudflare Pages may require the account owner to authorize the GitHub app in the dashboard. The scripts should detect that failure mode and show:

    https://dash.cloudflare.com/0e32ee7804b102bea6b9d3056d60f980/workers-and-pages/create/pages

## Interfaces and Dependencies

The Cloudflare scripts must use only Python standard-library modules such as `argparse`, `json`, `os`, `urllib.request`, `urllib.error`, and `pathlib`.

The public Python helpers at the end of implementation should include:

    scripts.cloudflare.common.load_cloudflare_configs()
    scripts.cloudflare.common.CloudflareClient.request(method, path, body=None, query=None)
    scripts.cloudflare.pages.build_pages_project_payload(config, github_repo_id=None)
    scripts.cloudflare.pages.ensure_pages_project(client, config, github_repo_id=None)
    scripts.cloudflare.pages.ensure_pages_domain(client, config)
    scripts.cloudflare.email.destination_address(config)
    scripts.cloudflare.email.build_catch_all_payload(config, destination)
    scripts.cloudflare.email.ensure_destination_address(client, config)
    scripts.cloudflare.email.ensure_email_routing(client, config)
    scripts.cloudflare.email.ensure_catch_all_rule(client, config)

The Swift interface should be a simple enum:

    enum SunclubWebLinks {
        static let support = URL(string: "https://sunclub.peyton.app/support/")!
        static let privacy = URL(string: "https://sunclub.peyton.app/privacy/")!
        static let supportEmail = URL(string: "mailto:sunclub@peyton.app")!
    }
