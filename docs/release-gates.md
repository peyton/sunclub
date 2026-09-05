# Release gates

These rules apply to every app change. Read the relevant gate before editing.

## Data Preservation Release Gate

Every app update must preserve user data stored locally and in CloudKit. Treat data preservation as a release gate for any change that touches signing, entitlements, app groups, store paths, SwiftData schema, revision history, backup import, or CloudKit sync.

- Test app-group entitlement and store-location transitions whenever signing, entitlements, app-group IDs, container IDs, store URLs, SwiftData container setup, or release export behavior changes. At minimum, cover the update path from no app-group entitlement using the Application Support `default.store` to a later build with the app-group entitlement using the shared app-group `default.store`.
- Never assume a provisioning profile proves runtime capabilities. For TestFlight or CloudKit-affecting releases, inspect the final exported IPA entitlements from the release artifact with `codesign -d --entitlements :- Payload/Sunclub.app` or the checked release diagnostics before trusting CloudKit, push, or app-group behavior.
- Route every SwiftData `ModelContainer` creation path through `SunclubModelContainerFactory` so migrations, store-location recovery, and CloudKit `.none` configuration stay consistent. This app uses manual `CKSyncEngine`; do not enable SwiftData CloudKit mirroring accidentally.
- Empty/default local bootstrap state must never overwrite meaningful local or CloudKit history. Mark synthetic empty migration seeds local-only, do not queue them for CloudKit, and ignore synthetic default `migrationSeed` or default `conflictAutoMerge` settings revisions whenever meaningful settings history exists.
- Fresh reinstall restore is a launch gate, not a normal sync. For effectively empty production stores, fetch CloudKit before saving the custom zone or sending local batches; restore success should rebuild projections before routing, no remote history should fall through to onboarding, and startup failure should expose retry/continue instead of silently accepting an empty store.
- Persisted model or history changes must include migration or projection tests that open prior shipped stores and prove non-empty users keep publishable history while empty stores remain local-only.
- Recovery and import paths must be idempotent and non-destructive: never delete current days during recovery, never overwrite current settings with less complete defaults, and always prefer `hasCompletedOnboarding: true` over `false`.

## Accessibility Scorecard Rules

Every future change under `app/` must preserve a perfect App Store Accessibility Nutrition Label scorecard for the app's common tasks. Treat the scorecard as a release gate, not a nice-to-have.

- Supported criteria must remain true for VoiceOver, Voice Control, Larger Text, Dark Interface, Differentiate Without Color Alone, Sufficient Contrast, and Reduced Motion.
- Captions and Audio Descriptions are currently not applicable because the app has no time-based audio or video content. If media playback is added, captions and audio descriptions become required before shipping.
- All interactive controls need visible, specific accessible names. Icon-only controls need explicit labels and, when useful, hints. Use stable accessibility identifiers for UI-testable flows.
- VoiceOver users must be able to perceive and operate every common task. Decorative images and symbols should be `accessibilityHidden(true)`; meaningful custom visuals need labels and values.
- Voice Control names should match visible text where practical. Do not hide primary actions behind unlabeled gestures.
- Text must support Dynamic Type through accessibility sizes without clipping essential content, overlapping controls, or blocking primary actions. Do not use `minimumScaleFactor` or fixed `lineLimit` for essential app copy.
- Do not encode status, selection, risk, or progress with color alone. Pair color with text, symbols, selection traits, labels, or values.
- Text, icons, controls, focusable states, and semantic colors must keep sufficient contrast in light mode, dark mode, and increased-contrast contexts. Use `AppPalette` tokens such as `onAccent` instead of low-contrast foregrounds on accent fills.
- Motion must honor Reduce Motion. Use `SunMotion` for SwiftUI animations, and suppress or replace decorative looping effects when `accessibilityReduceMotion` is true.
- UI or behavior changes in `app/` should add or update unit/UI/integration tests for any affected scorecard criterion. Prefer the existing `UITEST_FORCE_*` launch arguments for deterministic accessibility coverage.

## Always-Automatable Rules

Every future user-facing feature must preserve Sunclub's always-automatable posture. Before a feature is considered ready, document and test its automation surface.

- Add an App Intent for the feature, or document why it is destructive, permission-only, camera-based, file-picker-based, or review-heavy enough to open foreground UI instead.
- Add a custom URL/x-callback route for non-destructive reads and writes, or document the foreground route users and callers should open.
- Add Settings visibility for any automation knob, privacy toggle, or sensitive callback behavior.
- Route outside-app writes through the shared automation runtime and revision-history services; do not add ad hoc direct-write shortcuts.
- Update `docs/app-automation.md`, app product docs, website copy under `web/`, and tests whenever an automation surface changes.
- Keep Universal Links deferred unless the release plan explicitly includes Associated Domains signing and `apple-app-site-association` verification.

### SwiftData Migration Rules

- Treat every persisted SwiftData field change as a schema version bump. Add a new `VersionedSchema` entry in `app/Sunclub/Sources/Models/SunclubSchema.swift` and keep older schema definitions immutable.
- When freezing an older schema, annotate it with the shipped commit or release it matches so migration tests have a concrete source of truth.
- Route every `ModelContainer` creation path through `SunclubModelContainerFactory`; do not create ad-hoc containers that skip the migration plan.
- Keep data fixes that must happen once per upgrade inside the migration stage, not scattered across unrelated runtime code.
