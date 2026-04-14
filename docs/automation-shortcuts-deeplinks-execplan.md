# Automation, Shortcuts, and Deep Links ExecPlan

Sunclub should be automatable from Apple Shortcuts, Control Center, widgets, custom URL scheme links, and x-callback-url callers without weakening the core local-first release posture. This work adds one automation runtime, a broader App Intents surface, URL/x-callback parsing, in-app controls, website documentation, and tests that keep future features aligned with an always-automatable product rule.

## Progress

- [x] Add Codable automation preferences to growth settings without a SwiftData schema bump.
- [x] Add a shared automation runtime for non-destructive writes, status reads, files, and friend actions.
- [x] Expand App Intents and App Shortcuts while keeping the widget/control target compiling.
- [x] Extend deep links with `automation` and `x-callback-url` hosts while preserving legacy widget and accountability URLs.
- [x] Add Automation UI in Settings and Home.
- [x] Document the URL, x-callback, Shortcuts, privacy, and future-feature contract in `docs/`, `web/`, and `AGENTS.md`.
- [x] Add unit, UI, and web tests, then run release-adjacent verification.

## Decisions

- Universal Links are deferred for this release; do not add Associated Domains or `apple-app-site-association`.
- URL and x-callback callers may perform non-destructive writes by default. Users can disable Shortcut writes, URL open actions, URL write actions, and detailed callback payloads in Sunclub.
- Destructive, review-heavy, file-picker, camera, and permission-only flows remain foreground UI actions.
- Automation preferences live in the existing Codable growth-settings store so this feature does not require a SwiftData migration.
- Outside-app writes must go through the revision-history model and update widget snapshots; direct SwiftData-only quick logging is retired.

## Verification

Run from the repo root before calling the feature ready:

```bash
just generate
just test-unit
just test-ui
just test-python
just web-check
just lint
just ci
```

Also inspect the Automation UI in the simulator at normal text, accessibility text, dark mode, increased contrast, reduced motion, and differentiate-without-color.

Completed April 14, 2026:

- `just generate`
- `just test-unit`
- `just test-ui`
- `just test-python`
- `just web-check`
- `just lint`
- `just ci`
- Simulator polish pass on Automation at normal text, accessibility text, dark mode, increased contrast, reduced motion, differentiate-without-color, plus lower-page URL/x-callback controls.
