# First App Store Review Submission Package

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This repository does not contain `.agents/PLANS.md`. The local execution-plan instructions live at `/Users/peyton/.agents/PLANS.md`; this file follows those instructions and must remain self-contained.

## Purpose / Big Picture

Sunclub needs a first App Store review submission path that is easy to run and hard to submit incorrectly. After this work, a maintainer can keep all non-secret App Store listing, privacy, accessibility, export, age-rating, and review information in this monorepo; fill sensitive App Review contact and App Store Connect credentials through environment variables; review a generated redacted checkpoint; and submit the app for review through a guarded `just` command.

The user-visible result is a local workflow that prints a complete App Store review package and refuses final submission until strict metadata, screenshots, App Privacy completion, regulated medical device confirmation, and a typed checkpoint confirmation all pass.

## Progress

- [x] (2026-04-14 09:56Z) Created this living ExecPlan from the approved implementation plan.
- [x] (2026-04-14 10:08Z) Expanded the App Store metadata manifest into a non-secret source of truth.
- [x] (2026-04-14 10:23Z) Added a manifest resolver that reads env-backed contact details and produces redacted checkpoint output.
- [x] (2026-04-14 10:33Z) Added the App Store environment helper and Justfile commands.
- [x] (2026-04-14 10:52Z) Disabled developer-accessible public CloudKit accountability transport by default for the first review build.
- [x] (2026-04-14 11:12Z) Added review-package generation, checkpoint gating, and submission workflow updates.
- [x] (2026-04-14 11:51Z) Updated tests and ran the required verification commands.

## Surprises & Discoveries

- Observation: The current manifest is already draft-valid, but strict submission is blocked by draft App Review contact fields and App Privacy completion.
  Evidence: `just appstore-validate` warns about `review.contact` and `privacy.app_store_connect_completed`.
- Observation: Sunclub currently has public CloudKit accountability profile, invite-response, and poke records.
  Evidence: `SunclubAccountabilityService` uses `CKContainer(...).publicCloudDatabase`, which would be developer-accessible and conflicts with a no-collection App Privacy posture unless disabled for the release path.
- Observation: The full UI suite can pass many test cases and still exit with a simulator infrastructure error on Xcode 26.5 beta.
  Evidence: `just test-ui` reached the changed accountability and settings flows successfully across retries, then exited 65 with `FBSOpenApplicationServiceErrorDomain` and `Application info provider ... returned nil for "app.peyton.sunclub.dev.UITests.xctrunner"`.

## Decision Log

- Decision: Keep private iCloud history sync enabled, but disable public CloudKit accountability transport by default.
  Rationale: Private iCloud sync is user-owned cross-device storage. Public accountability records are developer-accessible CloudKit data and would require conservative App Privacy collection answers if enabled.
  Date/Author: 2026-04-14 / Codex.
- Decision: Store App Review contact and App Store Connect credential values only in environment variables or the ignored `.state/appstore/review.env` helper file.
  Rationale: The monorepo should hold the submission package, but not sensitive contact details or key paths.
  Date/Author: 2026-04-14 / Codex.
- Decision: Treat Sunclub as not a regulated medical device.
  Rationale: Sunclub is a sunscreen habit tracker and explicitly not diagnosis, treatment, monitoring of disease, or medical advice.
  Date/Author: 2026-04-14 / Codex.

## Outcomes & Retrospective

Implemented the first App Store review submission package and guarded submission flow. The repo now contains a non-secret manifest, env-backed sensitive fields, strict manual gates for App Privacy and regulated medical device status, a redacted checkpoint package, `just appstore-env`, `just appstore-validate-strict`, `just appstore-review-package`, and `just appstore-send-review`.

The release-default app no longer instantiates developer-accessible public CloudKit accountability transport. Direct public pokes/status refreshes/subscriptions are guarded behind an explicit future flag, while private iCloud history sync remains unchanged. The default user path now prefers Message/local invite sharing when direct delivery is unavailable.

Verification completed:

    just test-python
    just test-unit
    just web-check
    just appstore-validate
    SUNCLUB_APP_REVIEW_CONTACT_FIRST_NAME=Peyton SUNCLUB_APP_REVIEW_CONTACT_LAST_NAME=Randolph SUNCLUB_APP_REVIEW_CONTACT_EMAIL=review@example.com SUNCLUB_APP_REVIEW_CONTACT_PHONE=+14155550100 SUNCLUB_APP_PRIVACY_COMPLETED=1 SUNCLUB_REGULATED_MEDICAL_DEVICE_STATUS=NOT_MEDICAL_DEVICE just appstore-validate-strict
    just appstore-submit-dry-run
    just appstore-review-package
    just lint
    git diff --check

`just test-ui` did not complete because the simulator repeatedly failed to launch the UI test runner with `FBSOpenApplicationServiceErrorDomain` / `Application info provider ... returned nil`. The failure was infrastructure-level rather than an app assertion; the changed accountability UI paths passed before the simulator runner failed.

Remaining manual App Store Connect work is to run `just appstore-env`, fill `.state/appstore/review.env`, complete the App Privacy questionnaire, set regulated medical device status to `NOT_MEDICAL_DEVICE`, review `docs/app-store-review-package.md`, and then run the guarded submit command.

## Context and Orientation

The App Store submission manifest is `scripts/appstore/metadata.json`. It is validated by `scripts/appstore/validate_metadata.py` and consumed by `scripts/appstore/submit_review.py`, which talks to the App Store Connect API through `scripts/appstore/connect_api.py`. The shell wrapper `scripts/appstore/submit-review.sh` currently captures screenshots, archives and uploads a TestFlight build, and submits the version to App Review. The repository exposes common commands through the root `justfile`.

The iOS app lives under `app/Sunclub`. The optional accountability friend layer stores local state in `SunclubGrowthSettings` and currently uses `SunclubAccountabilityService` for public CloudKit profile, invite, and poke delivery. `AppState` chooses the default accountability service in `app/Sunclub/Sources/Services/AppState.swift`. Private iCloud history sync is separate and lives in `CloudSyncCoordinator`; this plan must not disable private iCloud history sync.

Apple’s App Privacy definition treats data as collected when it is transmitted off-device in a way that the developer or partners can access for longer than real-time request servicing. Public CloudKit accountability records meet that risk profile. Data processed only on-device, private user iCloud storage that the developer cannot access, and local files do not need to be declared as collected by the developer for this release posture.

## Plan of Work

First, extend `scripts/appstore/metadata.json` with non-secret App Store submission fields: categories, age-rating questionnaire answers, privacy answers, attestations, medical-device status, accessibility declarations, screenshot inventory, and manual App Store Connect gates. Replace tracked App Review contact values with environment-variable references.

Second, add a small resolver module in `scripts/appstore/manifest.py`. It will load the manifest, optionally load `.state/appstore/review.env`, resolve `{"env": "NAME"}` values from the environment, and return a resolved manifest for strict validation and submission. It will also provide a redacted summary used by dry runs, checkpoint files, and generated docs.

Third, add `scripts/appstore/review_package.py` and `scripts/appstore/review-env.sh`. The package script writes `docs/app-store-review-package.md` and `.build/appstore-review-checkpoint/summary.md`. The env script prompts for contact details, credentials, App Privacy completion, and regulated medical device confirmation, then writes `.state/appstore/review.env` with mode `600`.

Fourth, update `validate_metadata.py`, `submit_review.py`, `submit-review.sh`, `archive-and-upload.sh`, `.github/workflows/submit-app-review.yml`, the root `justfile`, `README.md`, and `docs/app-store-submission.md` so strict submission uses resolved env values and the final path includes a redacted checkpoint that requires explicit confirmation before screenshots, archive upload, or App Store Connect mutation.

Fifth, disable public CloudKit accountability transport by default. Add a runtime configuration flag that defaults to false, make default production `AppState` use the no-op accountability service unless that flag is true, and adjust direct poke/status behavior and copy so Message/local invite sharing remains the supported default. Preserve fake-service tests for direct transport by explicit injection.

Sixth, update Python and Swift tests to prove the resolver, strict gates, env helper, checkpoint confirmation, privacy manifest posture, public CloudKit guard, and default accountability transport behavior.

## Concrete Steps

Work from the repository root:

    /Users/peyton/.codex/worktrees/334e/sunclub

Edit these paths:

    scripts/appstore/metadata.json
    scripts/appstore/manifest.py
    scripts/appstore/review_package.py
    scripts/appstore/review-env.sh
    scripts/appstore/validate_metadata.py
    scripts/appstore/submit_review.py
    scripts/appstore/submit-review.sh
    scripts/appstore/archive-and-upload.sh
    justfile
    .github/workflows/submit-app-review.yml
    app/Sunclub/Sources/Shared/SunclubRuntimeConfiguration.swift
    app/Sunclub/Sources/Shared/RuntimeEnvironment.swift
    app/Sunclub/Sources/Services/AppState.swift
    app/Sunclub/Sources/Views/FriendsView.swift
    app/Sunclub/Sources/Views/HomeView.swift
    app/Sunclub/Sources/Views/AutomationView.swift
    docs/app-store-submission.md
    docs/app-store-review-package.md
    README.md
    tests/test_appstore_metadata_validator.py
    tests/test_appstore_submit_review.py
    tests/test_ios_metadata.py
    tests/test_web_deployment_workflow.py
    app/Sunclub/Tests/SunclubTests.swift
    app/Sunclub/UITests/SunclubUITests.swift

Run verification from the repo root:

    just test-python
    just test-unit
    just test-ui
    just web-check
    just appstore-validate
    just appstore-submit-dry-run
    just lint
    git diff --check

## Validation and Acceptance

The metadata work is accepted when `just appstore-validate` passes in draft mode, `just appstore-submit-dry-run` prints a redacted checkpoint summary without leaking real contact values, and strict validation fails unless the App Review contact env vars, App Privacy completion, and medical-device status env gates are present.

The final submission guard is accepted when `just appstore-submit-review` refuses to run without a checkpoint confirmation and when a non-interactive GitHub run can bypass the prompt only with both workflow confirmation and `SUNCLUB_APP_REVIEW_CHECKPOINT_CONFIRMED=1`.

The privacy posture is accepted when release-default code does not instantiate public CloudKit accountability transport, tests prove `PrivacyInfo.xcprivacy` remains no-tracking/no-collected-data, and any future public transport opt-in is guarded by stricter privacy metadata.

The App Store package is accepted when `docs/app-store-review-package.md` contains copy-paste-ready App Store fields, manual App Privacy and medical-device instructions, screenshot inventory, and all manual App Store Connect gates without storing real contact values.

## Idempotence and Recovery

The helper env script may be rerun; it overwrites only `.state/appstore/review.env`, which is ignored by git. Generated checkpoint files live under `.build/` and can be deleted safely. The App Store submission command must perform only local validation and checkpoint output before the explicit confirmation. If a later command fails, rerun after fixing the blocker; repeated screenshot upload replaces the screenshot set in App Store Connect.

Disabling public accountability transport must be additive and reversible through a future explicit flag. Existing local friend state should remain readable, and injected fake accountability services in tests must keep direct-delivery behavior testable.

## Artifacts and Notes

Important source references discovered before implementation:

    scripts/appstore/metadata.json currently marks review.contact.ready false and privacy.app_store_connect_completed false.
    app/Sunclub/Sources/Services/SunclubAccountabilityService.swift currently uses publicCloudDatabase.
    app/Sunclub/Sources/Services/CloudSyncCoordinator.swift uses privateCloudDatabase for history sync and must remain enabled.

## Interfaces and Dependencies

Do not add runtime dependencies. Python tooling must stay stdlib-only outside existing test dependencies. Use `uv run python -m ...` entry points and expose workflows through `just`.

The new resolver module must expose functions equivalent to:

    load_resolved_manifest(path: Path, environment: Mapping[str, str] | None = None, allow_env_file: bool = True) -> dict[str, Any]
    redacted_summary(manifest: Mapping[str, Any], context: SubmissionContext | None = None) -> list[str]

The runtime public accountability flag must default to false for release builds and tests must be able to construct an environment snapshot with the flag set either way.
