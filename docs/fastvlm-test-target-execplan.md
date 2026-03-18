# Split FastVLM Tests By Target

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This repository does not check in `PLANS.md`, but this document is maintained in accordance with `/Users/peyton/.agents/PLANS.md`.

## Purpose / Big Picture

After this change, the framework-specific FastVLM model-directory tests will run in a dedicated `FastVLMTests` unit-test target that builds the `FastVLM` framework directly, while the app-level `SunclubTests` target will keep only tests that exercise `Sunclub` code. A contributor should be able to open `app/Sunclub.xcodeproj`, see separate test targets for the app and the framework, and run each target independently.

## Progress

- [x] (2026-03-18 04:11Z) Confirmed the current project has `SunclubTests` and `SunclubUITests` only, and that the new FastVLM model-directory tests are incorrectly living in `app/SunclubTests/SunclubTests.swift`.
- [x] (2026-03-18 10:42Z) Added a new `FastVLMTests` unit-test target in `app/Sunclub.xcodeproj`, wired it to `FastVLM.framework`, and checked in a shared `FastVLM.xcscheme` so `xcodebuild` can run the framework tests directly.
- [x] (2026-03-18 10:44Z) Moved the framework resolver tests into `app/FastVLMTests/FastVLMTests.swift` and reduced `app/SunclubTests/SunclubTests.swift` to an app-level wrapper test around `FastVLMService`.
- [x] (2026-03-18 10:51Z) Verified the target graphs with `xcodebuild` for both schemes and captured the existing unrelated `fastvithd` compile failure that still blocks execution.

## Surprises & Discoveries

- Observation: The project uses `PBXFileSystemSynchronizedRootGroup` entries instead of the older per-file source membership model.
  Evidence: `app/Sunclub.xcodeproj/project.pbxproj` lists `Sunclub`, `SunclubTests`, and `SunclubUITests` as synchronized root groups and each target references only its folder in `fileSystemSynchronizedGroups`.
- Observation: The shared scheme files are not checked into the repo; `xcodebuild` is relying on implicit schemes and target attributes.
  Evidence: `find app/Sunclub.xcodeproj -name '*.xcscheme'` returned no files while `xcodebuild` still found `Sunclub` and `FastVLM`.
- Observation: The framework test target needed an explicit shared scheme before `xcodebuild test -scheme FastVLM` would treat `FastVLMTests` as part of the test action.
  Evidence: Before adding `app/Sunclub.xcodeproj/xcshareddata/xcschemes/FastVLM.xcscheme`, `xcodebuild` reported that the `FastVLM` scheme was not configured for the test action.
- Observation: The app-side test command now proves the app tests are building the app target and consuming the framework through the target graph, not by owning the framework test sources.
  Evidence: `xcodebuild test -project app/Sunclub.xcodeproj -scheme Sunclub -only-testing:SunclubTests` printed `SunclubTests -> Sunclub -> FastVLM`.

## Decision Log

- Decision: Add `FastVLMTests` as a separate unit-test bundle instead of expanding `SunclubTests`.
  Rationale: The framework resolver now lives in `app/Sunclub/FastVLM/FastVLM.swift`, so framework tests should compile the framework target directly and avoid conflating framework behavior with app-hosted tests.
  Date/Author: 2026-03-18 / Codex
- Decision: Keep one app-target test around the `FastVLMService` wrapper instead of deleting all app-side coverage.
  Rationale: The bugfix touched both `FastVLM` and `FastVLMService`, so both targets need test coverage, but only the framework target should own the underlying model-directory resolver cases.
  Date/Author: 2026-03-18 / Codex

## Outcomes & Retrospective

The repository now has distinct unit-test targets for the app and the framework. `FastVLMTests` owns the framework resolver cases in `app/FastVLMTests/FastVLMTests.swift`, while `SunclubTests` keeps only the app-facing wrapper coverage in `app/SunclubTests/SunclubTests.swift`. The project and scheme wiring are sufficient for `xcodebuild -list` to show both targets and for both test invocations to resolve the correct target graphs.

Execution is still blocked by a pre-existing compile error in `app/Sunclub/FastVLM/FastVLM.swift`: the type `fastvithd` is unresolved at lines 274, 279, and 288. That blocker is independent of the new test-target split, but it prevents either test bundle from actually running.

## Context and Orientation

The relevant project file is `app/Sunclub.xcodeproj/project.pbxproj`. The `FastVLM` framework target is declared there as a native target named `FastVLM`, and the app test target is declared there as `SunclubTests`. The app code that wraps the framework resolver lives in `app/Sunclub/Services/FastVLMService.swift`. The framework resolver itself lives in `app/Sunclub/FastVLM/FastVLM.swift`. The existing app tests live in `app/SunclubTests/SunclubTests.swift`. A “target” in Xcode is the independently built product and its source membership; if a test should validate the framework directly, it belongs in a test target that depends on `FastVLM.framework`, not on `Sunclub.app`.

## Plan of Work

Create a new folder at `app/FastVLMTests` and add a Swift test file there. Update `app/Sunclub.xcodeproj/project.pbxproj` so the project has a new synchronized root group for `FastVLMTests`, a new `FastVLMTests.xctest` product, a new native target named `FastVLMTests`, and a target dependency from `FastVLMTests` to `FastVLM`. Configure the new test target as a unit-test bundle for iOS, set its product bundle identifier, and associate it with the `FastVLM` target through `TargetAttributes` and build settings.

Then trim `app/SunclubTests/SunclubTests.swift` so it keeps only an app-level test around `FastVLMService.resolveModelDirectory(searchRoots:)`. Move the detailed model-directory layout tests into the new `app/FastVLMTests` test file and point them at `FastVLM.resolveModelDirectory(searchRoots:)`. This keeps framework logic tested in the framework target and app wrapper logic tested in the app target.

## Concrete Steps

From `/Users/peyton/.codex/worktrees/58e3/sunclub`, update:

1. `docs/fastvlm-test-target-execplan.md` with live progress.
2. `app/Sunclub.xcodeproj/project.pbxproj` to add the `FastVLMTests` root group, product, target, build phases, target dependency, target attributes, and build configurations.
3. `app/SunclubTests/SunclubTests.swift` to keep only the app-level wrapper test.
4. `app/FastVLMTests/FastVLMTests.swift` with the framework-level resolver tests.

Expected verification commands:

    cd /Users/peyton/.codex/worktrees/58e3/sunclub
    xcodebuild test -project app/Sunclub.xcodeproj -scheme Sunclub -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SunclubTests
    xcodebuild test -project app/Sunclub.xcodeproj -scheme FastVLM -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FastVLMTests

If the repository-wide `fastvithd` compilation issue still blocks execution, capture that blocker and fall back to lighter validation that proves the edited files parse and the project file now contains the intended target wiring.

## Validation and Acceptance

Acceptance means:

1. `app/Sunclub.xcodeproj/project.pbxproj` defines a `FastVLMTests` unit-test target tied to `FastVLM`, not to `Sunclub`.
2. `app/SunclubTests/SunclubTests.swift` contains only app-level coverage for the wrapper touched in `FastVLMService.swift`.
3. `app/FastVLMTests/FastVLMTests.swift` contains the model-directory layout tests and imports `FastVLM`.
4. Running the test commands either executes the right targets or fails only on the existing unrelated `fastvithd` blocker.

## Idempotence and Recovery

The folder additions and project-file edits are additive. Re-running the project-update script must detect an existing `FastVLMTests` target and avoid duplicating it. If the target wiring is wrong, the safe recovery path is to delete only the new `FastVLMTests` entries from the project file and rerun the script.

## Artifacts and Notes

Important current evidence:

    git status --short
     M app/Sunclub.xcodeproj/project.pbxproj
     M app/Sunclub/FastVLM/FastVLM.swift
     M app/Sunclub/Services/FastVLMService.swift
     M app/SunclubTests/SunclubTests.swift
    ?? app/FastVLMTests/
    ?? app/Sunclub.xcodeproj/xcshareddata/
    ?? docs/fastvlm-test-target-execplan.md

    xcodebuild -list -project app/Sunclub.xcodeproj
    ... shows targets Sunclub, SunclubTests, SunclubUITests, FastVLM, FastVLMTests
    ... shows schemes FastVLM and Sunclub

    xcodebuild test -project app/Sunclub.xcodeproj -scheme Sunclub -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SunclubTests
    ... shows target graph SunclubTests -> Sunclub -> FastVLM
    ... fails later on FastVLM.swift:274/279/288 because fastvithd is unresolved

    xcodebuild test -project app/Sunclub.xcodeproj -scheme FastVLM -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FastVLMTests
    ... shows target graph FastVLMTests -> FastVLM
    ... fails later on FastVLM.swift:274/279/288 because fastvithd is unresolved

## Interfaces and Dependencies

The new framework test file should expose normal XCTest methods only; no production interface changes are required beyond the already-public `FastVLM.resolveModelDirectory(searchRoots:)`. The app test target should continue to use `FastVLMService.resolveModelDirectory(searchRoots:)` from `app/Sunclub/Services/FastVLMService.swift`. The project update should rely on the installed Ruby `xcodeproj` gem to mutate `app/Sunclub.xcodeproj/project.pbxproj` safely instead of hand-editing UUID blocks.
