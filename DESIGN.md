# Sunclub Design System

## Palette

| Token        | Hex       | Usage                        |
|-------------|-----------|------------------------------|
| Sun         | `#FAA402` | Primary brand, CTAs, icon    |
| Sun Light   | `#FFDD80` | Highlights, glows            |
| Cream       | `#FBF7EF` | Page background              |
| Warm Glow   | `#FFEDBD` | Ambient gradient blobs       |
| Ink         | `#1D1A16` | Headlines, primary text      |
| Soft Ink    | `#837568` | Secondary text               |
| Surface     | `rgba(255,255,255,0.82)` | Cards, overlays |
| Dark        | `#1D1916` | Dark mode background         |
| Dark Surface| `#2C2621` | Dark mode cards              |
| Success     | `#26C55A` | Positive states              |
| White       | `#FFFFFF` | Contrast text on dark fills  |

## Typography

System font stack: `-apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", Roboto, Helvetica, Arial, sans-serif`

| Scale   | Size   | Weight | Use                |
|---------|--------|--------|--------------------|
| Hero    | 60px   | 800    | Landing headlines  |
| 3XL     | 44px   | 800    | Section titles     |
| 2XL     | 32px   | 800    | Card titles        |
| XL      | 24px   | 700    | Subtitles          |
| LG      | 18px   | 600    | Nav, buttons       |
| Base    | 16px   | 400    | Body text          |
| SM      | 14px   | 500    | Captions           |
| XS      | 12px   | 600    | Badges, labels     |

## Spacing

4px grid. Common values: 4, 8, 12, 16, 20, 24, 32, 40, 48, 64, 80.

## Radii

| Token | Value  | Use               |
|-------|--------|-------------------|
| SM    | 10px   | Feature icons     |
| MD    | 16px   | Buttons, inputs   |
| LG    | 24px   | Cards             |
| XL    | 32px   | Large panels      |
| Full  | 9999px | Badges, dots      |

## Icon / Logo

The Sunclub mark is a solid `#FAA402` circle. On light backgrounds it sits alone; on dark backgrounds it may carry subtle concentric glow rings at 12% and 6% opacity.

The wordmark uses the system font at weight 800, lowercase, tracking -0.02em.

## Files

- `icon.svg` — App icon (512x512, rounded square)
- `landing.html` — Reference landing page using all tokens
