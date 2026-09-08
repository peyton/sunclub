# Web Daylight design

All eight public HTML pages share the app's ivory, amber, charcoal and rounded
system typography. The homepage leads with logging, then reminders, UV and
companion access. Guides use plain sections; Support uses native disclosures.
Existing page and asset URLs, contact addresses and weather configuration remain.

## Assets

- `web/assets/screenshots/today-daylight.webp`: converted from
  `docs/daylight-timeline-evidence/today-reapply.png` (1206 × 2622).
- `web/assets/screenshots/watch-daylight.webp`: converted from the same evidence
  directory's `watch.png` (374 × 446).
- `web/assets/icons/daylight-*.svg`: copied from the app's Quiet imagesets;
  the Lucide license is included beside them.
- `web/assets/marketing/daylight-outside.webp`: built-in ImageGen, 1024 × 1536,
  WebP quality 88. The photograph is decorative; app UI is a real capture.

Final image prompt:

> Use case: photorealistic-natural. Asset type: Sunclub sunscreen app website hero
> editorial background, portrait 2:3. Primary request: quiet sunlit still-life of
> a plain ivory sunscreen tube resting on a warm pale limestone ledge outdoors,
> with a small soft shadow of foliage and a glimpse of warm golden late-afternoon
> light. Product design reference: Sunclub uses open ivory #FDF7E7, amber #FAA500
> and brown-charcoal #2E281C, rounded typography, and a minimal Daylight Timeline.
> No typography in this asset. Composition: understated premium editorial
> photograph, tube at bottom left of frame, broad calm cream negative space
> across top and center to accommodate a real app screenshot layered later.
> Natural fine stone texture, restrained colors, soft shadows. No labels, logos,
> text, people, devices, app UI, watermarks, or decorative illustrations. This is
> a supporting atmosphere image, not a product mockup.

## Design QA

Final result: passed.

Source visual: `docs/daylight-timeline-evidence/today-reapply.png`, viewed beside
an in-app Browser full-page capture of the website at 1440 CSS pixels wide.
The app source is 1206 × 2622 pixels and is displayed proportionally at 248 CSS
pixels wide inside the homepage image treatment. This is a web adaptation of
the app palette, typography and hierarchy, not a clone of an app screen.

Implementation capture: task artifact `sunclub-web-desktop.png` in the Codex
visualizations directory for task `01a08334-d773-70a2-a2e4-3faab801c81d`.

- Typography: rounded system type, strong leading headings, readable body copy.
- Layout: open sections and single-column mobile guides; no observed overflow
  at 320, 390 or 1440 CSS pixels.
- Tokens: matched light/dark app colors; navigation targets at least 44px high.
- Imagery: actual app captures, proportional sizing, existing brand mark and
  shipped icons. The full-page capture confirms the hero and lower sections.
- Content: current logging, check-ins, reminders, Shortcuts and private history;
  removed repeated prompts and outdated camera language.
- Iteration: corrected the mobile Low UV border color, enlarged navigation
  targets and replaced older colorful feature icons with the app's icon set.
- Interaction: guide navigation, native FAQ disclosure, 404 recovery and link
  destinations checked. Dark mode and reduced-motion emulation checked. No
  browser console warnings or errors observed.
- Local checks: 278 Python tests, site validation/package, and `just ci-lint`.
  Swift lint reports existing warnings. No app source changes.
