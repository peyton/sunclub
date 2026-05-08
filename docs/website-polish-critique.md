# Website Polish Critique

Source: ChatGPT Atlas, GPT-5.5 Pro, Extended, run against the PRD, design
system, four reference PNGs, and initial website contact sheet. Raw copied
output is retained locally at `.build/web-polish-review/atlas/initial-critique.md`.

## Resolution Checklist

| CG items | Status | Resolution |
| --- | --- | --- |
| CG-001..CG-024 | Implemented | Rebuilt the home first viewport around the reference hero, larger display type, real App Store CTA, truthful live App Store copy, `Free - iOS 18.6+ - iPhone and Apple Watch`, local `<picture>` hero crops, and concrete product copy. |
| CG-025..CG-029 | Implemented | Added five reference-aligned SVG feature icons under `web/assets/icons/`, including corrected purple Shortcuts and green watch/shield icons. |
| CG-030..CG-035 | Implemented | Replaced CSS feature mocks with local reference-board WebP crops for logging, UV detail, watch/widgets, Shortcuts, and history. |
| CG-036..CG-040 | Implemented | Kept the five-feature order, short capability-specific copy, equal visual cards, decorative icon treatment, and a white feature band below the hero. |
| CG-041..CG-055 | Implemented | Rewrote privacy/support home panels, retained mailboxes at `support|privacy|security|contact@mail.sunclub.peyton.app`, made iCloud optional, removed heavy footer treatment, and used local imagery with explicit dimensions and decoding/loading hints. |
| CG-056..CG-060 | Implemented | Kept docs index to four existing-resource cards with outline icons, titles, short descriptions, chevrons, active Docs nav state, and mobile-friendly grid behavior. |
| CG-061..CG-065 | Implemented | Getting Started now maps to real setup steps and uses the reference Log Sunscreen crop; Live UV/location remains explicitly optional. |
| CG-066..CG-070 | Implemented | UV docs keep labeled severity ranges, color-plus-text meaning, reference UV Detail crop, data-availability caveat, and non-medical guidance note. |
| CG-071..CG-075 | Implemented | Shortcuts docs now list supported actions, use the reference Shortcuts crop, preserve Ask Before Running/user-control language, keep examples static with allowed routes only, and reserve purple Shortcuts styling for automation affordances. |
| CG-076..CG-081 | Implemented | Support page uses warm page styling, a blue top action panel for Email Support, Common Questions, and Feedback, consistent public mailboxes, no automatic diagnostic collection claim, and full-width mobile cards. |
| CG-082..CG-088 | Implemented | Privacy page states no Sunclub account, no ads, no data sale, optional iCloud sync, optional location/Live UV, export/import/delete controls, and safer iCloud wording. |
| CG-089..CG-092 | Implemented | 404 page uses the shared warm shell/footer, direct recovery copy, and links to Home, Docs, and Support. |
| CG-093..CG-100 | Implemented | CSS tokens, Apple system typography, dark text on yellow surfaces, visible focus, skip links, landmarks, flexible mobile layouts, and 44 px tappable targets are preserved and covered by source/browser checks. |
| CG-101..CG-104 | Implemented | Site remains static HTML/CSS with local assets only, no runtime JavaScript, existing route set, and validator-guarded links/assets. |
| CG-105 | Resolved | Chart/exposure meanings are represented in visible screenshot alt text and UV docs copy; no new interactive chart was added to the static site. |
| CG-106 | Implemented | Added reduced-motion CSS guard for future transitions/animations. |
| CG-107 | Implemented | Exported local WebP hero and feature assets with explicit dimensions and eager/async or lazy/async loading according to page position. |
| CG-108 | Implemented | Kept the local SVG favicon contract and added a generated `web/assets/apple-touch-icon.png` referenced by every public route. |
| CG-109 | Implemented | Existing unique titles and meta descriptions are preserved across all public routes while copy was tightened. |
| CG-110 | Implemented | Final desktop/mobile screenshots, HTML contact sheet, stitched PNG contact sheet, Browser route check, and Atlas follow-up pass are retained under `.build/web-polish-review/`. |

## Atlas Follow-Up

- First final pass:
  `.build/web-polish-review/atlas/final-critique-pre-fixes.md` returned five
  blockers covering shared headers, docs card anatomy, Shortcuts color, support
  actions, and source-level QA.
- Resolution: those five blockers were implemented in `web/`,
  `scripts/web/validate_static_site.py`, and `tests/test_web_static_site.py`.
- Confirmation pass: Atlas reviewed the updated final contact sheet and returned
  `PASS`, with no remaining CG blockers visible. It accepted the source-only QA
  items as resolved based on the recorded validation pass.
- Evidence: `.build/web-polish-review/final/manifest.json` records 16
  desktop/mobile captures with zero console issues, zero broken images, no
  horizontal overflow, the shared header route order, App Store links, and
  apple-touch icon links.

## Factual Adaptations

- ChatGPT suggested `mailto:mail.sunclub.peyton.app`; this was corrected to the
  actual public mailbox pattern: `support@mail.sunclub.peyton.app`,
  `privacy@mail.sunclub.peyton.app`, `security@mail.sunclub.peyton.app`, and
  `contact@mail.sunclub.peyton.app`.
- The reference says iOS 16+, but the live public listing requires iOS 18.6+.
  The site keeps `iOS 18.6+`.
