# Sunclub Design System

## Source Of Truth

The app design system lives in `app/Sunclub/Sources/Shared/AppDesignSystem.swift`.
Use those tokens and components for iOS, Watch, and shared SwiftUI surfaces.

Legacy brand helpers in `AppTheme.swift` remain for the Sunclub mark, warm screen
backgrounds, product-page cards, and compatibility wrappers, but new screen
styling should route through `AppColor`, `AppText`, `AppCard`, `SunInfoRow`,
`SunUVIndexCard`, and the shared button/card primitives.

All screen titles use the shared large-title treatment and align to the leading
content edge. Do not reintroduce centered navigation-style titles for top-level
screens such as Timeline, History, Insights, Settings, Privacy, or Support.

## Typography

Use San Francisco rounded everywhere:

```swift
.system(size: value, weight: weight, design: .rounded)
```

Screen code should not call `.font(.system(...))` directly. Use `AppText` for
copy and `AppFont.rounded(...)` only for compact visual primitives such as icons,
calendar cells, and charts.

| Token | Size | Weight | Notes |
| --- | ---: | --- | --- |
| `AppTextStyle.largeTitle` | 32 | semibold | main screen titles |
| `AppTextStyle.title` | 26 | semibold | card titles and modal titles |
| `AppTextStyle.sectionHeader` | 21 | semibold | section headers |
| `AppTextStyle.body` | 17 | regular | default body copy |
| `AppTextStyle.caption` | 14 | regular | secondary labels |

Letter spacing is intentionally zero to match the product page and avoid clipped
large Dynamic Type headings.

## Color

Semantic color tokens:

| Token | Usage |
| --- | --- |
| `AppColor.Text.primary` | primary text, near-black |
| `AppColor.Text.secondary` | secondary text |
| `AppColor.background` | page background |
| `AppColor.surface` | soft panels |
| `AppColor.surfaceElevated` | cards and sheets |
| `AppColor.accent` | primary blue Sunclub action |
| `AppColor.sun` | sun and UV accents |
| `AppColor.success` | completed/applied states |
| `AppColor.warning` | destructive or attention states |
| `AppColor.muted` | inactive UI |
| `AppColor.stroke` | low-contrast borders |
| `AppColor.primaryAction` | high-emphasis filled buttons |
| `AppColor.primaryActionForeground` | text and icons on primary actions |

Avoid hardcoded `Color.red`, direct RGB values, and one-off foreground colors in
screen files.

Dark mode uses the same semantic token names. `AppColor` and `AppPalette` should
resolve to warm night surfaces, amber sun accents, readable cream foregrounds,
and visible low-contrast borders. New colors must be added as semantic tokens
instead of screen-local RGB values.

UV severity colors:

| Level | Token |
| --- | --- |
| Low | `AppPalette.aloe` |
| Moderate | `AppPalette.sun.opacity(0.78)` |
| High | `AppPalette.sun` |
| Very High | `AppPalette.coral` |
| Extreme | `AppPalette.uvExtreme` |

## Radius, Spacing, Shadow

Use the 8-point spacing rhythm:

`AppSpacing.xxs` 8, `xs` 12, `sm` 16, `md` 20, `lg` 24, `xl` 32.

Canonical radii:

| Token | Value | Usage |
| --- | ---: | --- |
| `AppRadius.card` | 18 | cards and large panels |
| `AppRadius.button` | 14 | buttons and compact controls |
| `AppRadius.pill` | infinity | capsules |

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
- `SunBottomNavigationBar`

Timeline owns the former Today surface. Keep the bottom tab label as Timeline,
keep the top timeline scrubber, and enrich the selected-day content below it.
The UV card should use the shared overlapping `SunUVIndexCard` meter treatment,
and the daily exposure card should show peak UV, elevated-hours context, and the
hourly strip with shared UV severity colors.

Compact surfaces share the same semantics: widgets and Watch should show one
primary state first, then one supporting detail such as UV, SPF, or reapply
timing. Stale previous-day reapply timers must not surface on Today widgets or
Watch.
