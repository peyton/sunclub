# Stop TestFlight CloudKit Launch Crashes

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds. This repository references `/Users/peyton/.agents/PLANS.md` for the required ExecPlan format; this document follows that format and is self-contained for a future contributor.

## Purpose / Big Picture

Sunclub v1.0.24 reached TestFlight but crashed on launch before testers could use the app. The crash happened when the app tried to create a `CKContainer`, which is Apple's object for accessing CloudKit databases, while the final TestFlight app signature lacked CloudKit entitlements. After this change, a TestFlight build that is missing CloudKit entitlements must not crash on launch, the release workflow must preserve artifacts and entitlement diagnostics, and future release work must run the repo CloudKit checks before cutting another build.

The visible outcome is that testers can open the app even when iCloud sync is unavailable, and release maintainers can download the GitHub Actions artifact to inspect the exact entitlements in the shipped app.

## Progress

- [x] (2026-04-13 21:30 PDT) Pulled the latest merged `origin/master` changes into `master` with a fast-forward merge.
- [x] (2026-04-13 21:33 PDT) Re-ran post-pull local checks: `just test-python` passed all 98 tests and `just ci-lint` completed with only existing SwiftLint warnings.
- [x] (2026-04-13 21:38 PDT) Downloaded the v1.0.24 GitHub Actions artifact and inspected the archive and IPA signatures.
- [x] (2026-04-13 21:42 PDT) Ran `just cloudkit-doctor`, `just cloudkit-export-schema`, and `just cloudkit-validate-schema`; the CloudKit management token and development schema are valid.
- [x] (2026-04-13 21:46 PDT) Added a runtime entitlement guard before every `CKContainer(identifier:)` call so missing CloudKit entitlements are recorded as recoverable sync errors instead of causing a signal trap.
- [x] (2026-04-13 21:46 PDT) Added Swift regression tests for missing CloudKit service and container entitlements in both private sync and public accountability database paths.
- [x] (2026-04-13 21:57 PDT) Hardened release scripts and workflow artifact diagnostics so unsigned archive exports are ad-hoc signed with resolved release entitlements, final IPA entitlements are validated before upload, and diagnostics are persisted.
- [x] (2026-04-13 21:58 PDT) Updated `AGENTS.md` and release documentation with the corrected TestFlight and CloudKit release rules.
- [x] (2026-04-13 22:11 PDT) Re-ran `just test-unit`, `just test-python`, `just ci-lint`, simulator launch, and a local unsigned-archive export. The exported IPA diagnostics include production CloudKit, push, app-group, HealthKit, and WeatherKit app entitlements.
- [ ] Commit and push the fix, cut the next TestFlight tag, then inspect the GitHub Actions artifact before considering the incident closed.

## Surprises & Discoveries

- Observation: The v1.0.24 `.xcarchive` app was not signed at all because the workflow used `--unsigned-archive`.
  Evidence: `codesign -d --entitlements :- /tmp/sunclub-v1.0.24-artifacts/Sunclub.xcarchive/Products/Applications/Sunclub.app` printed `code object is not signed at all`.
- Observation: The v1.0.24 exported IPA was signed for TestFlight but had only base signing entitlements, not the entitlements requested by `app/Sunclub/Sunclub.entitlements`.
  Evidence: `codesign -d --entitlements :- /tmp/sunclub-v1.0.24-ipa/Payload/Sunclub.app` printed only `application-identifier`, `beta-reports-active`, `com.apple.developer.team-identifier`, and `get-task-allow`.
- Observation: The embedded App Store provisioning profile did contain the CloudKit, push, HealthKit, WeatherKit, and app-group capabilities. The loss happened because the unsigned archive did not preserve the requested entitlements for export signing.
  Evidence: decoding `embedded.mobileprovision` showed `aps-environment = production`, `com.apple.developer.icloud-container-identifiers = iCloud.app.peyton.sunclub`, `com.apple.security.application-groups = group.app.peyton.sunclub`, `com.apple.developer.healthkit = true`, and `com.apple.developer.weatherkit = true`.
- Observation: The CloudKit management side is no longer the blocker for this crash.
  Evidence: `just cloudkit-doctor` exported schema for `iCloud.app.peyton.sunclub`, and `just cloudkit-validate-schema` returned `✅ Schema is valid.`

## Decision Log

- Decision: Add a runtime entitlement guard instead of relying only on release-time signing validation.
  Rationale: `CKContainer(identifier:)` can terminate the process with `SIGTRAP` when the app lacks required CloudKit entitlements, and that trap cannot be caught by Swift `do/catch`. The app must check its own signed entitlements before constructing CloudKit containers.
  Date/Author: 2026-04-13, Codex.
- Decision: Keep the GitHub release artifacts, add explicit entitlement diagnostics, and validate final IPA entitlements before upload.
  Rationale: The current workflow already persisted the archive and IPA, which made this investigation possible. Future artifacts should also include direct entitlement reports so maintainers do not need to unpack the IPA manually before spotting missing capabilities. The upload should fail before TestFlight if the exported IPA is still missing CloudKit, push, or app-group entitlements.
  Date/Author: 2026-04-13, Codex.
- Decision: Treat `just cloudkit-doctor` as the first CloudKit release diagnostic command, and `just cloudkit-export-schema` plus `just cloudkit-validate-schema` as the follow-up schema validation commands.
  Rationale: `cloudkit-doctor` confirms team and CloudKit container access; schema validation confirms the checked local schema can be accepted by CloudKit. Neither command proves the final IPA was signed with those entitlements, so artifact entitlement inspection remains a separate release gate.
  Date/Author: 2026-04-13, Codex.

## Outcomes & Retrospective

The app now checks its own signed executable entitlements before constructing CloudKit containers. Missing CloudKit service or container entitlements are reported through normal sync error handling instead of letting `CKContainer(identifier:)` terminate the process.

The TestFlight workflow now runs the Swift unit suite before archive, ad-hoc signs unsigned archives with resolved release entitlements, writes final IPA entitlement diagnostics, validates those final entitlements before upload, and persists the archive, IPA, and diagnostics for 90 days. A new TestFlight artifact still needs to be produced and inspected before this incident is fully closed.

Local validation after the `origin/master` fast-forward showed the corrected export path working before upload: `.build/release-diagnostics/Sunclub.entitlements.plist` contains `aps-environment = production`, `com.apple.developer.icloud-container-identifiers = iCloud.app.peyton.sunclub`, `com.apple.developer.icloud-services = CloudKit`, `com.apple.security.application-groups = group.app.peyton.sunclub`, HealthKit, and WeatherKit. The widget extension diagnostics are written as `.build/release-diagnostics/SunclubWidgetsExtension.appex.entitlements.plist` and include the shared app group.

## Context and Orientation

The crash log points to `app/Sunclub/Sources/Services/CloudSyncCoordinator.swift`, specifically `configureEngineIfNeeded()`, which calls `CKContainer(identifier: containerIdentifier).privateCloudDatabase`. `CKContainer` is a CloudKit framework type that reads the app's signed entitlements before returning a database object. If the app is missing the CloudKit service or container entitlement, CloudKit can trap the process with `EXC_BREAKPOINT` before Swift code can catch an error.

The string-only validation currently lives in `app/Sunclub/Sources/Services/SunclubCloudKitAvailability.swift`. It validates that the container identifier looks like `iCloud.app.peyton.sunclub`, but it does not inspect signed entitlements. The public accountability feature uses CloudKit too through `CloudKitAccountabilityDatabase` in `app/Sunclub/Sources/Services/SunclubAccountabilityService.swift`, which also creates a `CKContainer(identifier:)`.

The TestFlight workflow is `.github/workflows/release-testflight.yml`. It calls `scripts/appstore/archive-and-upload.sh --allow-draft-metadata --unsigned-archive --upload-testflight`. The archive script currently validates final IPA entitlements only when the archive was signed. That skip allowed v1.0.24 to upload a minimally entitled app.

## Plan of Work

First, extend `SunclubCloudKitAvailability` with a small entitlement-provider interface backed by a Mach-O code-signature entitlement reader. The reader opens the app's signed executable, finds the code-signature load command, parses the embedded entitlement blob, and returns values from the actual runtime code signature without calling `CKContainer`. The new runtime validator must confirm that the current process has `com.apple.developer.icloud-container-identifiers` containing the configured container and `com.apple.developer.icloud-services` containing `CloudKit` or the wildcard `*`.

Next, inject that provider into `CloudSyncCoordinator` and `CloudKitAccountabilityDatabase`, and call the runtime validator immediately before creating any `CKContainer(identifier:)`. When entitlements are missing, throw a `SunclubCloudKitConfigurationError` that existing sync error handling records in `CloudSyncPreference.lastSyncErrorDescription`.

Then add Swift unit tests in `app/Sunclub/Tests/SunclubTests.swift` with a fake entitlement provider. The tests must show that valid entitlements pass, missing container or service entitlements fail, `CloudSyncCoordinator.start()` records a recoverable error, and `CloudKitAccountabilityDatabase` throws before constructing a CloudKit database.

Finally, update the release workflow and archive script so the GitHub artifact includes entitlement diagnostics for the exported IPA, unsigned archives are ad-hoc signed with resolved release entitlements before export, and final IPA entitlement validation gates upload. Update Python metadata tests to lock in the corrected release behavior. Update `docs/testflight-release.md`, `docs/cloudkit-setup.md`, and `AGENTS.md` so future agents know to run the CloudKit commands and inspect final IPA entitlements before a TestFlight release.

## Concrete Steps

From the repository root `/Users/peyton/ghq/github.com/peyton/sunclub`, run the following investigation commands when this issue recurs:

    gh run download <run-id> --name sunclub-testflight-vX.Y.Z --dir /tmp/sunclub-vX.Y.Z-artifacts
    unzip -q -o /tmp/sunclub-vX.Y.Z-artifacts/export/Sunclub.ipa -d /tmp/sunclub-vX.Y.Z-ipa
    codesign -d --entitlements :- /tmp/sunclub-vX.Y.Z-ipa/Payload/Sunclub.app
    just cloudkit-doctor
    just cloudkit-export-schema
    just cloudkit-validate-schema

After edits, run:

    just test-python
    just test-unit
    just ci-lint

For simulator verification, use the XcodeBuildMCP simulator flow with the `Sunclub` scheme and confirm the app launches without a `CKContainer` crash.

For TestFlight verification, cut a new tag with:

    just release-testflight 1.0.25

Then inspect the GitHub run artifact before trusting the release. If the run fails before upload because the artifact would be unsafe, increment the patch version only after fixing the failing preflight.

## Validation and Acceptance

The Swift unit suite must include tests that fail on the old code because there is no runtime entitlement validator and pass after the guard is added. `just test-unit` must pass. `just test-python` must pass after release-script and workflow tests are updated. `just ci-lint` must not introduce serious lint failures.

Manual simulator acceptance is that the app launches to its first screen without crashing even when the simulator build lacks production CloudKit entitlements. The expected degraded behavior is that iCloud sync records a warning instead of terminating the process.

Release acceptance is that the GitHub Actions TestFlight workflow publishes an artifact containing the `.xcarchive`, exported IPA, and entitlement diagnostics. Before another release is considered safe, inspect the exported IPA entitlements. CloudKit, push, and app-group entitlements must be present because the workflow validates them before upload. The runtime guard remains a last-resort protection against launch crashes if future signing regressions slip through.

## Idempotence and Recovery

The CloudKit commands are safe to repeat. `just cloudkit-export-schema` writes an ignored local `.state/cloudkit/sunclub-cloudkit-schema.json` file, and `just cloudkit-validate-schema` reads that file. The downloaded GitHub artifact directories under `/tmp` can be deleted and recreated. If a release tag is created and the workflow fails before upload, use the next patch version for the next attempt rather than moving the tag.

## Artifacts and Notes

The v1.0.24 artifact inspection produced the key evidence:

    Archive app:
    code object is not signed at all

    Exported IPA app entitlements:
    application-identifier = 3VDQ4656LX.app.peyton.sunclub
    beta-reports-active = true
    com.apple.developer.team-identifier = 3VDQ4656LX
    get-task-allow = false

    Embedded provisioning profile entitlements included:
    aps-environment = production
    com.apple.developer.icloud-container-identifiers = iCloud.app.peyton.sunclub
    com.apple.security.application-groups = group.app.peyton.sunclub
    com.apple.developer.healthkit = true
    com.apple.developer.weatherkit = true

This means the Apple account and profile had the capabilities, but the unsigned archive export did not request them in the app signature.

## Interfaces and Dependencies

Use a code-signature entitlement reader to read the current process entitlements from the executable's Mach-O code signature. Add an internal protocol in `SunclubCloudKitAvailability.swift`:

    protocol SunclubCloudKitEntitlementProviding {
        func entitlementValue(for key: String) -> Any?
    }

Add:

    static func validateRuntime(containerIdentifier: String, entitlementProvider: SunclubCloudKitEntitlementProviding) throws

`CloudSyncCoordinator` and `CloudKitAccountabilityDatabase` must accept a `cloudKitEntitlementProvider` initializer argument defaulting to `CodeSignatureCloudKitEntitlementProvider`. Tests should pass a fake dictionary-backed provider.

Revision note: Created during the v1.0.24 TestFlight launch-crash investigation so future work can resume with artifact evidence, commands, and design decisions intact.
