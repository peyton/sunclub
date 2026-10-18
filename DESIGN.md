# Sunclub Design System

## Source Of Truth

The app design system lives in `app/Sunclub/Sources/Shared/AppDesignSystem.swift`.
Use those tokens and components for iOS, Watch, and shared SwiftUI surfaces.

Legacy brand helpers in `AppTheme.swift` remain for the Sunclub mark, quiet screen
backgrounds, product-page cards, and compatibility wrappers, but new screen
styling should route through `AppColor`, `AppText`, `AppCard`, `SunInfoRow`,
`SunUVIndexCard`, and the shared button/card primitives.

All screen titles use the shared large-title treatment and align to the leading
content edge. Do not reintroduce centered navigation-style titles for top-level
screens such as Today, History, Settings, Privacy, or Support.

## Typography

Use San Francisco rounded everywhere:

```swift
.system(size: value, weight: weight, design: .rounded)
```

Screen code should not call `.font(.system(...))` directly. Use `AppText` for
copy and `AppFont.rounded(...)` only for compact visual primitives such as icons,
calendar cells, and charts.

| Token                        | Size | Weight   | Notes                        |
| ---------------------------- | ---: | -------- | ---------------------------- |
| `AppTextStyle.largeTitle`    |   32 | semibold | main screen titles           |
| `AppTextStyle.title`         |   26 | semibold | card titles and modal titles |
| `AppTextStyle.sectionHeader` |   21 | semibold | section headers              |
| `AppTextStyle.body`          |   17 | regular  | default body copy            |
| `AppTextStyle.caption`       |   14 | regular  | secondary labels             |

Letter spacing is intentionally zero to match the product page and avoid clipped
large Dynamic Type headings.

## Color

Semantic color tokens:

| Token                              | Usage                             |
| ---------------------------------- | --------------------------------- |
| `AppColor.Text.primary`            | primary text, near-black          |
| `AppColor.Text.secondary`          | secondary text                    |
| `AppColor.background`              | page background                   |
| `AppColor.surface`                 | soft panels                       |
| `AppColor.surfaceElevated`         | cards and sheets                  |
| `AppColor.accent`                  | readable amber links and controls |
| `AppColor.sun`                     | sun and UV accents                |
| `AppColor.success`                 | completed/applied states          |
| `AppColor.warning`                 | destructive or attention states   |
| `AppColor.muted`                   | inactive UI                       |
| `AppColor.stroke`                  | low-contrast borders              |
| `AppColor.primaryAction`           | high-emphasis filled buttons      |
| `AppColor.primaryActionForeground` | text and icons on primary actions |

Avoid hardcoded `Color.red`, direct RGB values, and one-off foreground colors in
screen files.

The shipped icon anchors cream surfaces, golden amber accents, and charcoal nights.
Dark mode uses the same semantic token names. Add colors as semantic tokens,
never screen-local RGB values. Watch uses explicit dark tokens because its
shared color resolver does not use UIKit appearance traits.

| Role                      | Light             | Dark              |
| ------------------------- | ----------------- | ----------------- |
| Canvas                    | `#FDF7E7`         | `#141412`         |
| Surface                   | `#FFFBF0`         | `#20201C`         |
| Elevated surface          | `#FFFFFF`         | `#2C2C26`         |
| Primary text              | `#2E281C`         | `#FDF7E7`         |
| Secondary text            | `#6D624A`         | `#C4BFB4`         |
| Links and active controls | `#805600`         | `#FFC045`         |
| Primary button / label    | `#805600` / white | `#805600` / white |
| Soft selection fill       | `#FFEEBE`         | `#3D3625`         |
| Decorative amber          | `#FAA500`         | `#FFC045`         |

Bright amber is decorative; use the deeper amber for small light-mode text.
Native prominent glass uses white labels, so its fill stays deep amber in both
appearances. Preserve the icon, semantic UV scale, success green, and error red.
Use warm separators and quiet shadows, with glass reserved for native controls
and navigation. Keep the existing screen order and open Today composition.

UV severity colors:

| Level     | Token                          |
| --------- | ------------------------------ |
| Low       | `AppPalette.aloe`              |
| Moderate  | `AppPalette.sun.opacity(0.78)` |
| High      | `AppPalette.sun`               |
| Very High | `AppPalette.coral`             |
| Extreme   | `AppPalette.uvExtreme`         |

## Radius, Spacing, Shadow

Use the 8-point spacing rhythm:

`AppSpacing.xxs` 8, `xs` 12, `sm` 16, `md` 20, `lg` 24, `xl` 32.

Canonical radii:

| Token              |    Value | Usage                        |
| ------------------ | -------: | ---------------------------- |
| `AppRadius.card`   |       18 | cards and large panels       |
| `AppRadius.button` |       14 | buttons and compact controls |
| `AppRadius.pill`   | infinity | capsules                     |

`AppShadow.soft` is the single reusable elevation style. Screen code should use
`.appShadow(AppShadow.soft)` or components that apply it internally.

## Components

Required shared components:

- `AppText`
- `AppCard`
- `PrimaryButton`
- `SecondaryPillButton`
- `StatusBadge`
- `DayCapsule`
- `StatCard`
- `FeatureIcon`
- `InfoRow`

Use these before creating bespoke card, button, badge, or stat treatments.

Product-page iOS wrappers in `AppTheme.swift` include:

- `SunProductIcon`
- `SunInfoRow`
- `SunUVIndexCard`
- `SunMiniBarChart`
- `SunForecastStrip`
- Native `TabView` for Today, History, and Settings
- `SunIcon` for bundled template SVG icons

Today uses an open ivory canvas and a chronological application timeline, with
one primary action: Log sunscreen, then Log reapplication after the first log.
Recorded events use filled markers; current and planned events use outlined
markers and explicit text. Compact UV context follows the logging action, keeping
source/freshness details and forecast access. Date browsing belongs to History.
History starts with compact week selection and chronological event rows; full calendar and
weekly insights remain available there. Settings uses simple grouped rows.

Reserve native Liquid Glass for controls and navigation; avoid textured backdrops
and nested material layers. Charts and timeline rails are live native visuals, not decorative raster art. Use `AppFont.heroMetric(size:)` with `@ScaledMetric` for its display value.
New interface icons use pinned Lucide 0.468.0 SVG imagesets through `SunIcon`;
licenses are bundled in Resources/Lucide-LICENSE.txt. Do not rasterize these icons.

Compact surfaces put sunscreen timing first, followed by one supporting detail
such as UV or SPF. Their primary logging action is adaptive: log sunscreen for
the day's first application, then log reapplications in place even when reminders
are off or no reminder is due. Stale previous-day reapply timers must not surface
on Today widgets or Watch. Logged Days remains a compact seven-day view, Stats
counts recorded days, and History remains date-based.

The Daylight Timeline presentation and motion contract is in
[Daylight Timeline](docs/daylight-timeline.md).
