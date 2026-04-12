# Static Web Presence ExecPlan

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

The local PLANS guidance used for this work was found at `/Users/peyton/.agents/PLANS.md`; the originally referenced `/Users/peyton/.agent/PLANS.md` did not exist in this environment.

## Purpose / Big Picture

Sunclub needs a public web presence that is suitable for App Store review and cheap static hosting. After this change, `https://sunclub.peyton.app` can serve a real homepage, support page, and privacy policy without JavaScript, a build step, placeholder links, or stale claims from the older camera/AI version of the app. A reviewer or user can open the site, find contact information, read the privacy policy, and confirm that the web copy matches the current manual-first iOS app.

## Progress

- [x] (2026-04-12T03:54Z) Confirmed the existing `web/landing.html` was stale and did not include support or privacy routes.
- [x] (2026-04-12T03:54Z) Confirmed the live `https://sunclub.peyton.app` page was a Craft-hosted JavaScript document with `noindex`, which is not a good App Review support or marketing target.
- [x] (2026-04-12T03:54Z) Replaced the old single-page artifact with static pages under `web/`, including `index.html`, `support/index.html`, `privacy/index.html`, `404.html`, `robots.txt`, `sitemap.xml`, and shared assets.
- [x] (2026-04-12T03:54Z) Added a Python static-site validator, web-specific just commands, and tests.
- [x] (2026-04-12T03:54Z) Updated App Store metadata URLs to `https://sunclub.peyton.app`, `https://sunclub.peyton.app/support`, and `https://sunclub.peyton.app/privacy`.
- [x] (2026-04-12T04:17Z) Generated current App Store screenshots and used selected downsampled images in the static site.
- [x] (2026-04-12T04:17Z) Ran the full verification set and recorded the remaining App Store review-contact warning.
- [x] (2026-04-12T04:22Z) Removed stale no-cloud copy from App Store metadata and added a metadata validator guard against stale AI, camera-verification, fully-offline, and no-cloud claims.

## Surprises & Discoveries

- Observation: The screenshot capture wrapper failed before it reached the simulator because it executed `bin/mise`, but this worktree did not have that shim.
  Evidence: `just appstore-screenshots` failed with `scripts/appstore/capture-screenshots.sh: line 7: /Users/peyton/.codex/worktrees/7ee2/sunclub/bin/mise: No such file or directory`.
- Observation: The product has evolved beyond the old landing-page copy.
  Evidence: `app/SPEC.md` and `app/README.md` describe manual logging, widgets, iCloud sync, local backups, HealthKit, location-driven reminders, and product scanning; the old page still claimed camera verification and no cloud.
- Observation: The screenshot capture script also inherited development app environment values, which made the screenshot flow build the wrong app bundle for the production screenshot path.
  Evidence: After switching away from the missing `bin/mise` shim, the screenshot run built `SunclubDev.app` while the capture script expected `Sunclub.app`; clearing those inherited values and forcing the production flavor fixed the run.
- Observation: The first mobile browser screenshot showed the hero text and nav too close to the right edge.
  Evidence: A Chrome headless screenshot at `390x1600` clipped the top hero line before responsive text width and nav wrapping were tightened.

## Decision Log

- Decision: Keep the site provider-neutral instead of adding Cloudflare Pages, GitHub Pages, or another host-specific workflow.
  Rationale: The requested deployment preference was cheapest and simplest. A plain `web/` publish directory works with any static host and avoids introducing provider state before the live host is chosen.
  Date/Author: 2026-04-12 / Codex
- Decision: Do not add an App Store badge or download link yet.
  Rationale: The real App Store URL is not present in the repo. A fake or placeholder download link would be worse for App Review and users than a clear release-in-progress note.
  Date/Author: 2026-04-12 / Codex
- Decision: Make `sunclub@peyton.app` visible on every HTML page.
  Rationale: Apple requires support URLs to lead to actual contact information. Repeating the address in the header/footer also makes privacy and support contact easy to find.
  Date/Author: 2026-04-12 / Codex
- Decision: Fix `scripts/appstore/capture-screenshots.sh` to use the repo's common tooling wrapper rather than `bin/mise`.
  Rationale: The existing command failed from this clean worktree before it could generate screenshots. Reusing `scripts/tooling/common.sh` matches the rest of the repo scripts and avoids relying on an undeclared shim.
  Date/Author: 2026-04-12 / Codex
- Decision: Use real generated app screenshots instead of a CSS-drawn phone mockup on the homepage.
  Rationale: App Review and users get a more accurate public surface when the page reflects the current app UI. The selected JPEGs are small enough for a static site and do not expose private data.
  Date/Author: 2026-04-12 / Codex
- Decision: Extend App Store metadata validation to stale product-positioning claims, not only URL readiness and free-release copy.
  Rationale: The same App Review risk applies if stale camera, AI, fully-offline, or no-cloud language reappears in App Store metadata after the web surface is fixed.
  Date/Author: 2026-04-12 / Codex

## Outcomes & Retrospective

The static site now exists in `web/` and can be served directly. The App Store manifest points to the new marketing, support, and privacy URLs and only the private review contact remains draft. The site uses real generated app screenshots, has no JavaScript dependency, includes support and privacy routes, and has a repo-local validator wired into `just web-check`, `just web-build`, and `just lint`. App Store metadata now describes optional private iCloud sync instead of claiming no cloud sync.

Verification passed:

    just web-check
    uv run pytest tests/test_web_static_site.py tests/test_appstore_metadata_validator.py -v
    just appstore-validate
    just web-build
    just lint

`just appstore-validate` still reports the expected warning that `review.contact` is not ready for submission. `just lint` exits 0 while still printing the existing SwiftLint warning set.

Local static serving was checked with `just web-serve PORT=8000`. The routes `/`, `/privacy/`, `/support/`, `/robots.txt`, `/sitemap.xml`, `/assets/screenshots/home.jpg`, and `/assets/screenshots/weekly-summary.jpg` returned HTTP 200. Chrome headless screenshots at desktop and mobile widths confirmed the homepage renders without JavaScript and without the mobile clipping found in the first pass.

## Context and Orientation

The iOS app lives under `app/`. Current product behavior is documented in `app/SPEC.md` and `app/README.md`. App Store metadata is centralized in `scripts/appstore/metadata.json` and checked by `scripts/appstore/validate_metadata.py`. Repo commands are exposed through `justfile`. The public website now lives entirely under `web/`; a static host should publish that directory as the document root with no build command.

The site must avoid App Review risks: placeholder links, JavaScript-required rendering, `noindex`, invisible contact details, misleading claims, and copy that conflicts with the current app. The public support contact is `sunclub@peyton.app`.

## Plan of Work

Create a plain static site with a shared stylesheet and three public routes: home, support, and privacy. The homepage explains the current Sunclub product without claiming a download URL. The support page gives real contact information and troubleshooting categories. The privacy policy explains local storage, optional private iCloud sync, backups, notifications, optional location/UV behavior, optional HealthKit support, optional camera/product scanning, tracking, retention, deletion, and medical disclaimer language.

Add `scripts/web/validate_static_site.py` so web review rules are executable. Wire it into `just web-check`, make `just lint` depend on it, and add tests that prove the committed site passes and broken placeholder pages fail. Update App Store metadata and documentation so the web URLs are no longer draft.

## Concrete Steps

From the repository root, run:

    just web-check
    uv run pytest tests/test_web_static_site.py tests/test_appstore_metadata_validator.py -v
    just appstore-validate
    just lint

For local manual review, run:

    just web-serve PORT=8000

Then open:

    http://localhost:8000/
    http://localhost:8000/privacy/
    http://localhost:8000/support/
    http://localhost:8000/robots.txt
    http://localhost:8000/sitemap.xml

## Validation and Acceptance

Acceptance is user-visible and command-backed. `just web-check` must pass with no broken links, placeholder links, `noindex`, missing titles, missing descriptions, insecure URLs, missing support email, or forbidden stale claims. The focused pytest command must pass. `just appstore-validate` may still warn that the private App Review contact is draft, but it must not warn that the marketing, support, or privacy URLs are draft. `just lint` must include web validation through its dependency chain.

When served locally, the homepage, support page, and privacy policy must render without JavaScript. The header and footer must provide `sunclub@peyton.app`. The homepage must not show a fake App Store link. The support and privacy pages must say Sunclub is not medical advice.

## Idempotence and Recovery

The site is plain files, so rerunning `just web-check`, `just web-fmt`, and `just web-build` is safe. `just web-build` deletes and recreates `.build/web`, which is ignored generated output. If a static host needs a publish artifact, use `.build/web`; otherwise publish `web/` directly.

If screenshot capture is needed later, rerun `just appstore-screenshots` after `just bootstrap`. Generated screenshots land under `.build/appstore-screenshots` and can be copied into `web/assets/` only after confirming they match the current product and do not expose private data.

## Artifacts and Notes

Representative files added or changed:

    web/index.html
    web/support/index.html
    web/privacy/index.html
    web/assets/site.css
    scripts/web/validate_static_site.py
    tests/test_web_static_site.py
    scripts/appstore/metadata.json
    justfile

## Interfaces and Dependencies

The site has no runtime dependencies and no JavaScript. The validator uses only the Python standard library and exposes:

    validate_site(root: Path) -> list[str]

The `justfile` exposes:

    just web-serve PORT=8000
    just web-check
    just web-fmt
    just web-build

Revision note: This ExecPlan was created during implementation to make the web-presence work restartable from the repo alone and to record the hosting, contact, and no-placeholder-link decisions.
