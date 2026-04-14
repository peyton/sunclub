# Marketing Website Polish Pass

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds. This document follows the requirements in `~/.agents/PLANS.md`.

## Purpose / Big Picture

Sunclub's public website should work as an App Store marketing surface, not only as a support and review checklist. After this change, a visitor can open the homepage, understand the sunscreen habit value quickly, follow a future-ready App Store release-status action, read product documentation under `/docs/`, and still find support without support being treated as the homepage conversion goal. The site remains static, JavaScript-free, and validated by the repo's existing web commands.

## Progress

- [x] (2026-04-14T10:15Z) Read the existing static site, validator, tests, App Store metadata, and automation docs.
- [x] (2026-04-14T10:15Z) Confirmed Apple lookup by bundle ID returned no public App Store listing, so the download action must stay future-ready instead of pointing to a fake URL.
- [x] (2026-04-14T10:34Z) Moved automation documentation from `/automation/` to `/docs/automation/` and added `/docs/`.
- [x] (2026-04-14T10:34Z) Polished homepage, navigation, footer, support prominence, layout, and dark mode.
- [x] (2026-04-14T10:34Z) Updated validator, tests, sitemap, and docs references.
- [x] (2026-04-14T10:34Z) Ran web validation, build, local route checks, and visual inspection.

## Surprises & Discoveries

- Observation: The old static-site validator hard-coded `/automation/` as required in both the file list and sitemap checks.
  Evidence: `scripts/web/validate_static_site.py` included `automation/index.html` and `"/automation/"`.
- Observation: The existing homepage made support a hero CTA even though support should be a low-prominence path.
  Evidence: `web/index.html` linked the secondary hero button to `mailto:support@mail.sunclub.peyton.app`.
- Observation: Mobile light mode needed an opaque secondary hero button because the phone screenshot sits behind the hero actions at 390px.
  Evidence: The first headless mobile screenshot showed weak contrast on `Read the docs`; after increasing the secondary button background opacity, the button stayed readable.
- Observation: The long URL examples on the automation docs do not cause mobile horizontal overflow.
  Evidence: A Chrome DevTools Protocol check at 390px reported `docScrollWidth=390` and `bodyScrollWidth=390` for `/docs/automation/` in light and dark mode.

## Decision Log

- Decision: Use an on-page App Store release-status target until a public App Store URL exists.
  Rationale: The plan explicitly forbids inventing a fake App Store URL, and Apple lookup returned zero results for `app.peyton.sunclub`.
  Date/Author: 2026-04-14 / Codex
- Decision: Remove `/automation/` rather than keeping a compatibility redirect page.
  Rationale: The user chose a clean route move, and the site is static with no redirect layer.
  Date/Author: 2026-04-14 / Codex

## Outcomes & Retrospective

Implemented. Sunclub's website now has a docs-first information architecture with `/docs/` and `/docs/automation/`, no old `/automation/` route, a homepage that uses App Store release status and documentation as its calls to action, lower-prominence support paths, and system-aware dark mode. Validation passed with `just web-check`, `uv run pytest tests/test_web_static_site.py -v`, `just web-build`, local HTTP route checks, and Chrome desktop/mobile light/dark inspection.

## Context and Orientation

The public site lives in `web/` as plain HTML and CSS. `web/index.html` is the homepage, `web/support/index.html` and `web/privacy/index.html` are App Store review support pages, `web/automation/index.html` is the old automation reference, and `web/assets/site.css` is the shared stylesheet. `scripts/web/validate_static_site.py` is the local static-site validator run by `just web-check`, and `tests/test_web_static_site.py` covers the validator and packaging behavior. `docs/app-automation.md` is the repository's source note for the app's automation surface.

## Plan of Work

Create `web/docs/index.html` as a documentation landing page and create `web/docs/automation/index.html` by moving and polishing the old automation reference. Delete `web/automation/index.html`. Update all headers and footers so the primary navigation is Home, Docs, Support, and Privacy, with no direct email address in the header.

Rework `web/index.html` so the hero copy is sharper, the hero buttons are App Store release status and Read the docs, and support is not a homepage call to action. Add docs and release-status sections, rebalance the feature cards around daily logging, reminders, weekly review, widgets, and privacy, and keep support discoverable only through footer/support/privacy paths.

Revise `web/assets/site.css` with semantic color tokens, light and dark palettes via `@media (prefers-color-scheme: dark)`, improved mobile wrapping, stable screenshot sizing, tighter spacing, and dark-mode contrast for cards, buttons, borders, links, and focus rings.

Update `web/sitemap.xml`, `web/404.html`, `web/support/index.html`, `web/privacy/index.html`, `scripts/web/validate_static_site.py`, `tests/test_web_static_site.py`, and `docs/app-automation.md` so `/docs/` and `/docs/automation/` are canonical and `/automation/` is gone.

## Concrete Steps

Run all commands from `/Users/peyton/.codex/worktrees/d602/sunclub`.

After editing, run:

    just web-fmt
    just web-check
    uv run pytest tests/test_web_static_site.py -v
    just web-build

Then serve locally and verify routes:

    just web-serve PORT=8000

Use HTTP checks for `/`, `/docs/`, `/docs/automation/`, `/support/`, `/privacy/`, `/404.html`, `/robots.txt`, `/sitemap.xml`, `/assets/screenshots/home.jpg`, and `/assets/screenshots/weekly-summary.jpg`.

## Validation and Acceptance

`just web-check` must pass, proving Prettier formatting and static-site validation agree with the new route map. `uv run pytest tests/test_web_static_site.py -v` must pass, proving the validator catches broken placeholders and accepts the committed site. `just web-build` must pass and produce `.build/web`.

When served locally, the homepage must have no support CTA, the header must not include a direct email address, the primary navigation must use Docs instead of Automation, `/automation/` must not be present in the sitemap or internal links, and the App Store action must not claim a live download URL. Light and dark mode at mobile and desktop widths must remain readable without clipped copy or broken screenshot framing.

## Idempotence and Recovery

The edits are plain static files and tests. Rerunning `just web-fmt`, `just web-check`, `uv run pytest tests/test_web_static_site.py -v`, and `just web-build` is safe. `.build/web` is generated output and can be deleted or recreated by `just web-build`.

## Artifacts and Notes

Artifacts and verification transcripts will be added after implementation.

## Interfaces and Dependencies

No JavaScript, new package dependency, external asset, redirect service, analytics, or runtime tracking is introduced. The public static routes after this change are `/`, `/docs/`, `/docs/automation/`, `/support/`, `/privacy/`, and `/404.html`.
