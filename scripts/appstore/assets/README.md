# App Store photography

`skincare-morning.png` is the selected background plate, generated with built-in
imagegen on September 6, 2026. The screenshot compositor adds real simulator
captures and rounded typography; the generated image contains no app UI or text.

## Prompt

Use case: ads-marketing. Asset type: photographic background plate for Sunclub
App Store screenshots, not a finished ad or UI. Premium editorial skincare
still-life photograph in a tall portrait 1320:2868 aspect ratio. Warm ivory
plaster and subtly textured peach-white stone in soft natural morning window
light, gentle diagonal shadows. A minimal unlabeled matte ivory sunscreen tube
with closed apricot cap and a folded cream linen cloth near the extreme
bottom-right corner, small and partially cropped. Most of the frame, especially
the top 35 percent and central 80 percent width, is quiet pale ivory negative
space for a large real app screenshot and cocoa headline to be composited later.
Tactile, calm, contemporary skincare editorial, restrained elegant warmth, no
shiny luxury cliches. Canvas #FFF8F0 with subtle apricot #ED941F accents.
Photorealistic materials. No words, logos, labels, people, phone, screen, UI,
drawn graphics or watermarks. Inviting and grounded, like a small daily
self-care ritual.

## Reproduce

Run `just appstore-screenshots` from the repository root. Final opaque RGB PNGs
are generated at 1320 × 2868 in `.build/appstore-screenshots`; unaltered simulator
captures are retained in its `raw` subdirectory. Artwork is aspect-filled and
app captures keep their native aspect ratio.
