# Sunclub Release Hardening

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This repository keeps the ExecPlan guidance outside the repo at `/Users/peyton/.agents/PLANS.md`. This document must be maintained in accordance with that file.

## Purpose / Big Picture

After this change, Sunclub will be shippable as a free, iPhone-only v1 without bundling the FastVLM model inside the app binary. A clean checkout will be able to generate, build, and test without downloading the model first, while release builds can stage the model as an App Store-hosted On-Demand Resource. The verification flow will clearly explain when the AI model still needs to be downloaded, manual logging will continue to work without it, and the App Store tooling will move from aspirational scripts to a validated submission manifest and simulator-driven screenshots.

## Progress

- [x] (2026-03-20 03:34Z) Re-read the external ExecPlan guidance, confirmed the repo currently violates clean-checkout expectations because `just build` and `just test` hard-fail on a missing model, and created this living plan.
- [x] (2026-03-20 10:24Z) Reworked Tuist and repo-local scripts so the model stages under `app/Generated/FastVLMODR/model`, is tagged as the `fastvlm-model` On-Demand Resource on the app target, and is no longer bundled through the `FastVLM` framework or copied into the final app bundle.
- [x] (2026-03-20 10:24Z) Implemented runtime model availability, consent, and download state handling with `FastVLMModelDownloadService`, updated `FastVLMService`, `SunscreenDetectionCoordinator`, launch prewarm, and `LiveVerifyView`, and kept manual logging available when the model is absent.
- [x] (2026-03-20 10:24Z) Removed the v1 subscription surface and simplified adjacent app state, permissions, and reminder code to match the free iPhone-only release.
- [x] (2026-03-20 11:24Z) Replaced the icon pipeline and App Store tooling, validated the new submission manifest, and captured the simulator screenshot set from the real app.
- [x] (2026-03-20 11:24Z) Ran the repo verification commands from a clean-checkout-like state and recorded the observed results here, including archive-level ODR packaging evidence.

## Surprises & Discoveries

- Observation: `just test-unit` currently fails before Xcode starts because the repo hard-requires `app/FastVLM/model/config.json`.
  Evidence: `just test-unit` exits from the `check-model` recipe with “FastVLM model files are missing at app/FastVLM/model.”
- Observation: the current App Store metadata is not submission-safe even before product questions; the subtitle is 34 characters and the keywords string is 105 characters.
  Evidence: local length check against `scripts/appstore/metadata.json`.
- Observation: the app already has UI-test routing hooks, so simulator-driven screenshots can reuse launch arguments instead of adding a browser-based marketing mockup pipeline.
  Evidence: `app/SunclubUITests/SunclubUITests.swift` already uses `UITEST_ROUTE_VERIFY_CAMERA` and `UITEST_ROUTE_WEEKLY_SUMMARY`.
- Observation: using the host’s shared `iPhone 17 Pro` simulator by name made `just test` flaky because CoreSimulator had multiple runtimes with the same device name and the shared device could be left in a Busy preflight state between runs.
  Evidence: repeated `xcodebuild test` failures with `FBSOpenApplicationErrorDomain Code=6 "Application failed preflight checks"` while `xcrun simctl list devices` showed duplicate `iPhone 17 Pro` devices across iOS 26.3 and 26.4 runtimes.
- Observation: a repo-owned simulator plus an erase-before-test reset makes the top-level `just test` entry point reliable again.
  Evidence: `scripts/resolve_simulator.py` now resolves `Sunclub Test iPhone 17 Pro`, and `just test` completed successfully end-to-end after the test recipes switched to `-destination "id=<resolved udid>"`.
- Observation: the archive packaging boundary now behaves as intended: the archived `.app` excludes FastVLM payload files while the archive still contains the `fastvlm-model` asset pack under `Products/OnDemandResources/`.
  Evidence: unsigned archive `.build/Sunclub-odr-check-1774005795.xcarchive` contains `app.peyton.sunclub.fastvlm-model-...assetpack/model/...` while `find .../Products/Applications/Sunclub.app` returns no `config.json`, `*.mlpackage`, or `*.bin` files.

## Decision Log

- Decision: keep the deployment target on iOS 18 and use On-Demand Resources instead of moving to Apple-hosted Background Assets.
  Rationale: the product decision for this release is to stay on iOS 18, and On-Demand Resources are the App Store-hosted option available at that target.
  Date/Author: 2026-03-20 / Codex
- Decision: ship Sunclub as free-only v1 and remove customer-facing subscription affordances from the current app surface.
  Rationale: the codebase has StoreKit plumbing but no shipping paywall or polished purchase UX, so marketing subscriptions in metadata or settings would misrepresent the product.
  Date/Author: 2026-03-20 / Codex
- Decision: treat the current `sunclub.app` support, privacy, and marketing URLs as placeholders that must be validated rather than trusted.
  Rationale: submission automation should fail loudly on placeholder or unreachable URLs instead of silently passing an incomplete listing.
  Date/Author: 2026-03-20 / Codex

## Outcomes & Retrospective

The structural release blockers from the initial state are now addressed. The model is delivered through ODR instead of the framework bundle, the app’s verification flow has explicit missing/downloading/ready/failed states, the free-only iPhone-only product surface matches the actual release scope, and the App Store helper layer is now a validated manifest plus simulator-driven screenshot capture rather than aspirational automation.

The main remaining blockers are intentionally outside code: the manifest still marks support, marketing, privacy-policy, and review-contact data as draft-only, so strict submission validation is supposed to fail until those real values exist. That is the right failure mode for release readiness.

## Context and Orientation

The iOS project lives in `app/`. `app/Project.swift` is the Tuist manifest that defines targets, build settings, and bundled resources. `app/FastVLM/` contains the lightweight framework wrapper around Apple's MLX-based FastVLM runtime; it currently expects model files under `app/FastVLM/model/`. `app/Sunclub/Services/FastVLMService.swift` loads the model and runs inference, `app/Sunclub/Services/SunscreenDetectionCoordinator.swift` drives camera sampling plus inference, and `app/Sunclub/Views/LiveVerifyView.swift` is the user-facing verification screen.

Repo automation starts from the root `justfile`. Right now the `download-model`, `build`, `run`, and `test` commands are coupled to the local model folder. The App Store submission helpers live under `scripts/appstore/`, where `metadata.json` contains product copy and the shell scripts handle version bumps, metadata updates, screenshot capture, and archive/export operations.

An “On-Demand Resource” is an App Store-hosted asset pack. The app ships with a tag name, requests that tag at runtime through `NSBundleResourceRequest`, and the system makes those tagged files available to the app without baking them into the final `.app` bundle. In this repository, that means the model files should move out of `app/FastVLM/model/` and into an app-target resource folder tagged as `fastvlm-model`.

## Plan of Work

First, update the Tuist manifest in `app/Project.swift` so the `FastVLM` framework no longer bundles model assets and so the `Sunclub` app target owns a tagged folder reference for the staged model under `app/Generated/FastVLMODR/model/`. At the same time, remove the post-build copy script for `fastvithd.mlpackage`, make the app iPhone-only through build settings, and align the root `justfile`, `.gitignore`, and model download script usage with the new staging directory.

Next, add a single runtime service that owns model consent, On-Demand Resource access, progress reporting, and resolved model paths. Use that service from `LiveVerifyView`, `SunscreenDetectionCoordinator`, and `FastVLMService` so verification can show four user-visible states: not downloaded, downloading, ready, and failed. Manual logging must remain available when the model is unavailable. App launch prewarming should only run after the service has already made the model accessible.

Then simplify the free v1 surface by removing active subscription wiring from `AppState` and `SettingsView`, while keeping the rest of the habit-tracking flow intact. Tighten `NotificationManager` and `Info.plist` so the declared permissions and background modes match what the app actually uses, including the missing camera usage description.

Finally, replace the App Store helper layer. Introduce a structured manifest in `scripts/appstore/metadata.json`, add a validator that checks field limits and required sections, narrow metadata automation to the fields App Store Connect can really patch, and replace the HTML/Puppeteer screenshot path with simulator-driven captures from the real app using launch arguments. The icon pipeline should become a repo-local script that rasterizes `icon.svg` for both the Xcode app icon set and any reused branded surfaces.

## Concrete Steps

From `/Users/peyton/.codex/worktrees/a5a0/sunclub`, perform the work in this order:

1. Edit `app/Project.swift`, `.gitignore`, `justfile`, and `app/FastVLM/README.md` so the model path moves to `app/Generated/FastVLMODR/model` and the app target owns the tagged resources.
2. Add the generated-directory keep files and update any docs that still tell contributors to populate `app/FastVLM/model`.
3. Add the model download service plus the runtime changes in `app/Sunclub/Services/` and `app/Sunclub/Views/LiveVerifyView.swift`.
4. Remove the free-v1 subscription surface and tighten app permissions and routing in `app/Sunclub/`.
5. Add the icon generator and submission-manifest validator under `scripts/`, then update `scripts/appstore/` to use them.
6. Run `just generate`, `just test`, `just build`, the metadata validator, and the screenshot script. Record the results in this document.

## Validation and Acceptance

Acceptance requires all of the following observable results:

1. From a checkout with no staged model files, `just generate`, `just test`, and `just build` complete without the old `check-model` failure.
2. Running `just download-model` stages files under `app/Generated/FastVLMODR/model`, not under `app/FastVLM/model`.
3. Launching the app without staged model assets still allows onboarding, home navigation, history, settings, and manual logging. Opening the camera verification flow shows a clear download-required state instead of crashing or hanging.
4. After staging the model for a local build, the verification flow can make the model available, complete inference, and log a successful verification.
5. The App Store validator reports the missing or placeholder submission blockers with explicit error messages, and the screenshot script captures real simulator screens instead of HTML mockups.
6. A release archive built with staged model assets keeps the model out of the final `.app` bundle while still producing the tagged asset pack.

Observed verification results on 2026-03-20:

1. `just generate` succeeded from a checkout with no staged model.
2. `just build` succeeded from a checkout with no staged model.
3. `just test` succeeded from a checkout with no staged model after switching the recipes to a repo-owned simulator (`Sunclub Test iPhone 17 Pro`) resolved by `scripts/resolve_simulator.py`.
4. `just appstore-validate` succeeded in draft mode and reported the expected submission-readiness warnings for placeholder URLs and review contact data.
5. `just appstore-screenshots` succeeded and wrote six screenshots to `.build/appstore-screenshots/`.
6. `just download-model` staged the FastVLM payload under `app/Generated/FastVLMODR/model`.
7. An unsigned archive at `.build/Sunclub-odr-check-1774005795.xcarchive` succeeded with the staged model, and inspection confirmed:
   - no model payload files inside `Products/Applications/Sunclub.app`
   - a tagged asset pack under `Products/OnDemandResources/app.peyton.sunclub.fastvlm-model-...assetpack/`

## Idempotence and Recovery

The generated model directory must be safe to clear and repopulate repeatedly. Re-running `just download-model` should replace the staged model contents without touching tracked files. Re-running `just generate`, `just build`, and `just test` should not require manual cleanup beyond existing derived data behavior.

If On-Demand Resource access fails during local development because the model was never staged, the app must recover by staying usable and presenting a clear instruction to run `just download-model` for local builds. If the model is staged but a runtime load still fails, the service should clear any stale error state and allow a new download attempt without reinstalling the app.

## Artifacts and Notes

Initial failure evidence before implementation:

    $ just test-unit
    FastVLM model files are missing at app/FastVLM/model. Run 'just download-model' from the repo root and retry.

Current metadata length evidence before implementation:

    subtitle chars: 34
    keywords chars: 105

## Interfaces and Dependencies

The runtime work will add one new model-delivery service in `app/Sunclub/Services/` with a small public interface:

    @MainActor
    final class FastVLMModelDownloadService

It must expose the current availability state, a method to refresh or download the model, a method to tell whether consent has already been recorded, and a way to resolve the model directory once resources are available. `FastVLMService` must stop assuming bundled assets and instead accept or resolve the directory supplied by that service. `LiveVerifyView` must render user-facing states from that interface. The App Store validator must run from a repo-local script in `scripts/appstore/` and return a non-zero exit code when required fields or limits are violated.

Revision note (2026-03-20): Created this ExecPlan at implementation start to capture the clean-checkout failure, the iOS 18 ODR decision, and the free-only v1 scope before code changes begin.
