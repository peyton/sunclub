# Sunclub Design System

## Source Of Truth

The app design system lives in `app/Sunclub/Sources/Shared/AppDesignSystem.swift`.
Use those tokens and components for iOS, Watch, and shared SwiftUI surfaces.

Legacy brand helpers in `AppTheme.swift` remain for the Sunclub mark, warm screen
backgrounds, and compatibility wrappers, but new screen styling should route
through `AppColor`, `AppText`, `AppCard`, and the shared button/card primitives.

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

Heading styles apply slight negative tracking.

## Color

Semantic color tokens:

| Token | Usage |
| --- | --- |
| `AppColor.Text.primary` | primary text, near-black |
| `AppColor.Text.secondary` | secondary text |
| `AppColor.background` | page background |
| `AppColor.surface` | soft panels |
| `AppColor.surfaceElevated` | cards and sheets |
| `AppColor.accent` | primary Sunclub action |
| `AppColor.success` | completed/applied states |
| `AppColor.warning` | destructive or attention states |
| `AppColor.muted` | inactive UI |
| `AppColor.stroke` | low-contrast borders |

Avoid hardcoded `Color.red`, direct RGB values, and one-off foreground colors in
screen files.

## Radius, Spacing, Shadow

Use the 8-point spacing rhythm:

`AppSpacing.xxs` 8, `xs` 12, `sm` 16, `md` 20, `lg` 24, `xl` 32.

Canonical radii:

| Token | Value | Usage |
| --- | ---: | --- |
| `AppRadius.card` | 22 | cards and large panels |
| `AppRadius.button` | 18 | buttons and compact controls |
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

Use these before creating bespoke card, button, badge, or stat treatments.
