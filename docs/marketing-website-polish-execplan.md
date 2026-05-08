# Sunclub Website Reference Polish

This ExecPlan is a living document for polishing the static website in `web/`
against the supplied PRD, design-system document, reference website image, icon
sheet, and contact sheets.

## Purpose

Sunclub's public website should feel like the supplied Apple-native app
marketing reference while staying truthful to the live product. The site remains
static HTML/CSS with no runtime JavaScript, analytics, tracking, external
dependencies, new routes, or hosting configuration changes. The public claims
remain: Sunclub is live on the App Store, free, iOS 18.6+, has no app-owned
accounts, shows no ads, offers optional private iCloud sync, offers optional
Live UV context, and provides general non-medical guidance.

## Progress

- [x] Created branch `codex/web-polish-gpt55-reference` from detached HEAD
      `ff035b8` while preserving the unrelated unstaged `mise.lock` edit.
- [x] Generated the initial review bundle at `.build/web-polish-review/initial/`
      with desktop and mobile screenshots for `/`, `/docs/`,
      `/docs/getting-started/`, `/docs/uv-index/`, `/docs/automation/`,
      `/support/`, `/privacy/`, and `/404.html`.
- [x] Uploaded the PRD, design system, four reference PNGs, and initial contact
      sheet to ChatGPT Atlas using GPT-5.5 Pro Extended.
- [x] Captured the Atlas critique locally at
      `.build/web-polish-review/atlas/initial-critique.md`.
- [x] Added tracked critique resolution notes in
      `docs/website-polish-critique.md`.
- [x] Replaced homepage CSS mock visuals with local reference-quality hero,
      feature, and icon assets.
- [x] Updated homepage, docs, support, privacy, 404, validator, and tests for
      the new visual/copy contract.
- [x] Ran final desktop/mobile route captures and refreshed
      `.build/web-polish-review/final/` with screenshots, HTML contact sheet,
      stitched PNG contact sheet, and manifest checks.
- [x] Ran Browser route verification for all public routes with zero console
      logs.
- [x] Ran the second Atlas review pass, implemented its five remaining
      blockers, and submitted the updated final contact sheet for confirmation.
- [x] Recorded the final Atlas confirmation pass: no remaining CG blockers
      visible in the updated contact sheet.
- [x] Run full formatting, validation, and source checks after the final doc
      updates.
- [ ] Push the branch, create a PR, wait for checks, merge, monitor Cloudflare
      deployment, and verify `https://sunclub.peyton.app/`.

## Decisions

- Use local WebP crops under `web/assets/marketing/` and `web/assets/features/`
  for hero and feature visuals. Keep original screenshot assets available but
  do not use CSS mocks for the homepage feature row.
- Use local SVG feature icons under `web/assets/icons/`, including corrected
  Shortcuts and watch/shield icons.
- Keep public email addresses under `mail.sunclub.peyton.app`. Atlas suggested
  the literal mailbox `mail.sunclub.peyton.app`, but the repo's existing public
  contract is `support|privacy|security|contact@mail.sunclub.peyton.app`.
- Keep the live App Store link and `iOS 18.6+` compatibility even where the
  reference design says iOS 16+.

## Validation Plan

Run:

```text
just web-fmt
just web-check
uv run pytest tests/test_web_static_site.py tests/test_web_deployment_workflow.py -v
just web-build
just lint
git diff --check
```

Serve locally with:

```text
just web-serve PORT=8787
```

Then verify all allowed routes at 1440 px and 390 px, with zero console errors,
no horizontal overflow, no clipped buttons/text, and a final contact sheet saved
under `.build/web-polish-review/final/`. The current final manifest records 16
captures with zero console issues, zero broken images, no horizontal overflow,
App Store links, apple-touch icon links, and the shared header route order.

## Recovery Notes

The unrelated `mise.lock` change predates this task and must not be staged. The
review bundles under `.build/` are generated evidence and can be recreated. All
tracked edits are limited to `web/`, `scripts/web/`, `tests/`, and `docs/`.
