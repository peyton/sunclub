# App Store-Aligned Website Refresh

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds. This document follows the requirements in `~/.agents/PLANS.md`.

## Purpose / Big Picture

Sunclub's public website is the App Store marketing, support, and privacy surface for the submitted iPhone release. After this change, a visitor can open `https://sunclub.peyton.app`, see copy that matches the submitted App Store package, understand that the app is a free daily SPF habit tracker without app-owned accounts or ads, find the support and privacy pages used by App Review, and avoid a fake App Store download link while Apple's public listing is not live.

## Progress

- [x] (2026-05-06T15:04-07:00) Read the current website, App Store metadata manifest, generated App Store review package, web validation tests, deployment workflows, and prior marketing website plan.
- [x] (2026-05-06T15:06-07:00) Verified Apple's public lookup for `app.peyton.sunclub` still returns no listing, so the website must not show a live App Store download badge.
- [x] (2026-05-06T15:09-07:00) Reworked the homepage copy and layout around the submitted release: Daily SPF Habit Tracker, free iPhone app, manual logging, streaks, weekly summary, reapply reminders, private-by-default history, and optional Live UV.
- [x] (2026-05-06T15:12-07:00) Updated support, privacy, docs, and automation docs copy so first-review Activity sharing behavior and App Store privacy label details are visible.
- [x] (2026-05-06T15:13-07:00) Added static-site validation and tests that guard against stale App Store status copy and missing submission-aligned disclosures.
- [x] (2026-05-06T15:18-07:00) Ran `just web-fmt`, `just web-check`, `uv run pytest tests/test_web_static_site.py -v`, `just web-build`, `just lint`, and `git diff --check`.
- [x] (2026-05-06T15:22-07:00) Served the site locally, checked all public routes with Browser, and verified 390px mobile plus 1440px desktop layouts with Chrome DevTools Protocol metrics.
- [x] (2026-05-06T15:55-07:00) Replaced the hand-built CSS device hero with a generated composed hero image matching the supplied design template, then reloaded the in-app Browser and verified the updated homepage DOM and console state.
- [x] (2026-05-06T16:23-07:00) Corrected the logo and feature icons against the generated product-page reference: standalone sun mark, rounded lowercase wordmark, and larger rounded-square sun/cloud/shield/Shortcuts icons.
- [ ] Push the branch, open a PR, monitor checks, merge, and verify the web deployment.

## Surprises & Discoveries

- Observation: Apple's public lookup still returns `resultCount: 0` for `app.peyton.sunclub`.
  Evidence: `curl -fsSL 'https://itunes.apple.com/lookup?bundleId=app.peyton.sunclub&country=us'` printed an empty results array on 2026-05-06.
- Observation: The current homepage still used the old "App Store release status" phrasing even though the local App Store package marks marketing, support, and privacy URLs as ready for submission.
  Evidence: `web/index.html` contained `App Store release status` and `Sunclub is being prepared for public App Store availability`.
- Observation: Public Activity sharing transport is disabled for the first App Store review build, but the public automation docs did not explain that `poke-friend` becomes a Message-first foreground route.
  Evidence: `docs/app-automation.md` included the first-review behavior, while `web/docs/automation/index.html` only said Activity sharing links continue to work.
- Observation: A first mobile screenshot attempt appeared clipped because plain Chrome headless screenshot mode used a wider layout viewport than the 390px image output.
  Evidence: A follow-up Chrome DevTools Protocol audit with `Emulation.setDeviceMetricsOverride` reported `viewport=390`, `scrollWidth=390`, and `bodyScrollWidth=390` for `/`, `/docs/`, `/docs/automation/`, `/support/`, `/privacy/`, and `/404.html`.
- Observation: Rebuilding the reference design from separate CSS phone, watch, shadow, and leaf layers produced a jumbled hero at narrow widths.
  Evidence: The in-app Browser showed overlapping hero/device elements after the first reference pass. A generated single-image composition avoids those independent layout layers.
- Observation: The first corrected header still used the app icon as the logo and the feature icons were undersized compared with the generated product-page reference.
  Evidence: The user supplied close-up screenshots of the iCloud and Shortcuts icons plus the full generated product page, and the local screenshot showed a square app-icon wordmark treatment instead of the rounded sunclub mark.

## Decision Log

- Decision: Keep the App Store call to action as submitted-release details instead of a download badge.
  Rationale: The app has been submitted, but the public App Store listing is not live. A fake or guessed App Store URL would create an App Review and user trust problem.
  Date/Author: 2026-05-06 / Codex
- Decision: Use a generated composed hero image for the first viewport, backed by real screenshots in the feature section.
  Rationale: The supplied reference is a single polished product scene. A composed bitmap keeps the hero stable and template-matched while the lower feature row still exposes real Sunclub UI screenshots.
  Date/Author: 2026-05-06 / Codex
- Decision: Add validator-enforced submission copy requirements.
  Rationale: The website is now part of the release contract, so future edits should fail fast if they remove key App Store-aligned status, privacy, or automation disclosures.
  Date/Author: 2026-05-06 / Codex

## Outcomes & Retrospective

Implementation is in progress. The site has been redesigned and copy-aligned locally. Local validation and browser/layout verification pass; PR checks, merge, and deployment verification remain.

## Context and Orientation

The public site lives in `web/` as static HTML and CSS. `web/index.html` is the homepage. `web/support/index.html`, `web/privacy/index.html`, `web/docs/index.html`, and `web/docs/automation/index.html` are the public support, privacy, documentation, and automation routes. `web/assets/site.css` is the shared stylesheet. `scripts/web/validate_static_site.py` implements release-safety checks for the static site, and `tests/test_web_static_site.py` covers those checks.

The App Store source of truth is `scripts/appstore/metadata.json`. The generated human-readable package is `docs/app-store-review-package.md`. For this submitted release, Sunclub is a free iPhone-only app with subtitle `Daily SPF Habit Tracker`, categories Health & Fitness and Lifestyle, age rating 4+, no app-owned accounts, no ads, no analytics SDKs, optional private iCloud sync, and optional WeatherKit Live UV that is off by default.

Web deployment is owned by `.github/workflows/deploy-web-cloudflare.yml`. Pull requests that touch `web/**` build and package the static site. Pushes to `master` deploy `.build/web` to Cloudflare Pages at `https://sunclub.peyton.app`.

## Plan of Work

Rework `web/index.html` so the first viewport presents the submitted product clearly: a generated App Store-style hero composition, Daily SPF Habit Tracker positioning, free iPhone submission facts, and honest submitted-release status instead of a fake App Store link. Keep support and privacy discoverable without making support the primary homepage conversion goal.

Update `web/assets/site.css` to support a lighter product-first layout with stable screenshot frames, responsive hero sizing, fixed font sizes through breakpoints rather than viewport-scaled text, accessible contrast in light and dark modes, and repeated cards that stay within an 8px radius design language.

Update `web/support/index.html`, `web/privacy/index.html`, `web/docs/index.html`, and `web/docs/automation/index.html` so their copy matches the submitted package. The privacy page must explicitly state that the submitted App Store privacy label is data not collected. The automation page must explain that public Activity sharing transport is disabled for first review, so friend reminders open a Message-first foreground route.

Extend `scripts/web/validate_static_site.py` and `tests/test_web_static_site.py` to enforce the new submission-aligned copy contract.

## Concrete Steps

Run all commands from `/Users/peyton/.codex/worktrees/d422/sunclub`.

After editing, run:

    just web-fmt
    just web-check
    uv run pytest tests/test_web_static_site.py -v
    just web-build

Then serve locally:

    just web-serve PORT=8000

Use Browser to inspect `http://127.0.0.1:8000/`, `/docs/`, `/docs/automation/`, `/support/`, `/privacy/`, and `/404.html` at desktop and mobile widths. The homepage should show the generated hero scene and real feature screenshots without overlap, no clipped text, and no fake App Store download badge.

## Validation and Acceptance

`just web-check` must pass, proving Prettier and the static-site validator agree with the committed site. The focused pytest command must pass, including the homepage App Store positioning test. `just web-build` must pass and produce `.build/web`.

Browser verification must show the homepage, docs, automation docs, support, privacy, and 404 routes render without JavaScript, broken links, hidden primary content, clipped buttons, or overlapping screenshot frames. The homepage must say the public App Store listing is not live yet and must not contain `Download on the App Store`.

After merge, the GitHub web deployment workflow should run for `master` and publish the new static site to Cloudflare Pages. `https://sunclub.peyton.app/` should serve the new submitted-release homepage.

## Idempotence and Recovery

All edits are plain text static files, Python validator code, tests, and this ExecPlan. Rerunning `just web-fmt`, `just web-check`, the focused pytest command, and `just web-build` is safe. `.build/web` is generated output and can be deleted or recreated by `just web-build`. The working tree has a pre-existing unrelated `mise.lock` change; preserve it and do not include it in this website branch unless the user explicitly asks.

## Artifacts and Notes

Local verification completed:

    just web-check
    Static site validation passed for web.

    uv run pytest tests/test_web_static_site.py -v
    7 passed

    just web-build
    Static site validation passed for web.

    just lint
    Passed with existing SwiftLint warnings and no serious violations.

    Browser route check
    /, /docs/, /docs/automation/, /support/, /privacy/, and /404.html loaded with zero console errors.

    Browser generated-hero check
    The in-app Browser reloaded http://127.0.0.1:8000/ after the composed hero image was added, found the expected hero headline, and reported zero console errors.

    Browser logo/icon check
    The in-app Browser reloaded http://127.0.0.1:8000/ after the logo and feature icons were corrected and reported zero console errors.

    Chrome DevTools Protocol responsive audit
    Every public route reported mobile viewport 390, scrollWidth 390, and bodyScrollWidth 390. Every public route reported desktop viewport 1440, scrollWidth 1440, and bodyScrollWidth 1440. No route contained `Download on the App Store`.

Generated hero source:

    /Users/peyton/.codex/generated_images/019dff51-6f51-7710-bc60-3c31681b723e/ig_0b563d72f14b76750169fbc5e0235481959e101569e1c815b0.png

Committed web asset:

    web/assets/hero-sunclub-devices.jpg

## Interfaces and Dependencies

No JavaScript runtime, new package dependency, analytics, tracking, App Store URL guess, external image asset, or Cloudflare configuration change is introduced. The public static routes remain `/`, `/docs/`, `/docs/automation/`, `/support/`, `/privacy/`, and `/404.html`.
