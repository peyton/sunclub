# PER-44: Subscription Screen Spec Extraction (Figma node `1:2`)

## Scope

- Linear issue: `PER-44`
- Figma file: `O41oolGDq5MbLxAluZy74x`
- Node: `1:2` (Subscription screen)
- Target app: `app/Sunclub`

## Extraction Status

Figma MCP extraction is currently blocked by seat/plan quota.

Attempted required flow (in order):

1. `get_design_context(fileKey: "O41oolGDq5MbLxAluZy74x", nodeId: "1:2")` on 2026-03-16 (America/Los_Angeles) -> blocked by plan call limit.
2. `get_screenshot(fileKey: "O41oolGDq5MbLxAluZy74x", nodeId: "1:2")` on 2026-03-16 (America/Los_Angeles) -> blocked by plan call limit.

Because both calls failed, exact text copy and pixel-accurate measurements are not available from this run.

## Known Constraints From Existing Project Context

- This screen is present in Figma but not implemented in code.
- Existing app conventions indicate the screen should be a light-mode screen (`SunLightScreen`) unless design evidence says otherwise.
- Existing Settings already includes "Manage Subscription" as an external App Store handoff; this new screen is expected to cover in-app subscription purchase UX.

## Spec Fields Pending Exact Extraction

The following are still pending due to Figma MCP quota block:

- Exact headline/body copy
- Exact CTA labels and button hierarchy
- Pricing tiers, prices, billing cadence text, and visual emphasis rules
- Precise spacing, sizing, and component hierarchy
- Exact typography specs (size/weight/line-height)
- Exact color values for any new screen-specific tokens
- Illustration/icon asset list and treatment
- Dismiss behavior details

## AppTheme Cross-Reference (Current Token Baseline)

Relevant existing tokens from `app/Sunclub/Shared/AppTheme.swift`:

- `AppPalette.cream` `#FAF7F0`
- `AppPalette.warmGlow` `#FFEDC2`
- `AppPalette.sun` `#FAA403`
- `AppPalette.ink` `#211D1A`
- `AppPalette.softInk` `#83756D`
- Existing CTA styles:
  - `SunPrimaryButtonStyle`: 58pt height, 18pt radius, `AppPalette.sun` fill
  - `SunSecondaryButtonStyle`: 52pt height, 16pt radius, translucent white fill + subtle border

Use these as the initial implementation baseline if PER-46 starts before Figma MCP quota is restored.

## Unblock Steps

1. Restore Figma MCP tool-call availability for the current seat/plan.
2. Re-run `get_design_context` for node `1:2`.
3. Re-run `get_screenshot` for node `1:2`.
4. Fill in all pending exact spec fields above.
5. Update Notion "User Flows & Screens" section 10 with exact extracted values.
