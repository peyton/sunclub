# Sunclub

iOS sunscreen tracking app with AI validation.

## Build & Run

```text
just bootstrap
just download-model
just generate
open app/Sunclub.xcworkspace
```

Scheme: **Sunclub** | Destination: iPhone simulator (iOS 18+). No manual SPM or CocoaPods steps needed.

## Test Commands

| Surface           | Command                 |
| ----------------- | ----------------------- |
| Unit tests        | `just test-unit`        |
| UI tests          | `just test-ui`          |
| All tests         | `just test`             |
| CI validation     | `just ci`               |
| Lint              | `just lint`             |
| Format            | `just fmt`              |
| Python eval tests | `just test-python`      |
| Benchmark         | `just benchmark-strict` |

## Project Layout

```text
app/          iOS Apps, Swift source, iOS tests, UI tests
evals/        Benchmark suite and eval harness
scripts/      All project-level scripts.
tests/        Other tests and test runners
docs/         One place for all documentation on the app, evals, scripts, and tests.
```

## Architecture Conventions

- **Models** → `app/Sunclub/Models/` — SwiftData `@Model` types
- **Persistence Versioning** → `app/Sunclub/Sources/Models/SunclubSchema.swift` — all SwiftData `VersionedSchema`, migration stages, and `ModelContainer` factory wiring live here
- **Services** → `app/Sunclub/Services/` — coordinators, matchers, managers
- **Views** → `app/Sunclub/Views/` — one file per screen
- **Theme** → `app/Sunclub/Shared/AppTheme.swift` — all UI tokens live here
- Singletons: `VisionFeaturePrintService.shared`, `NotificationManager.shared`
- Observable state: `AppState` is the single source of truth, injected via `@Environment`

### SwiftData Migration Rules

- Treat every persisted SwiftData field change as a schema version bump. Add a new `VersionedSchema` entry in `app/Sunclub/Sources/Models/SunclubSchema.swift` and keep older schema definitions immutable.
- When freezing an older schema, annotate it with the shipped commit or release it matches so migration tests have a concrete source of truth.
- Route every `ModelContainer` creation path through `SunclubModelContainerFactory`; do not create ad-hoc containers that skip the migration plan.
- Keep data fixes that must happen once per upgrade inside the migration stage, not scattered across unrelated runtime code.

## Documentation Rules

- **All specs, design docs, and investigation notes go in `docs/`** as Markdown files.
- All documentation about tools goes in `docs/` as Markdown files.
- Persisted-data changes should add or update a migration note/ExecPlan in `docs/` when the migration behavior or rollout assumptions are non-trivial.
- Keep docs terse — spec fields, not prose
- DO NOT reference Linear ticket IDs (e.g. `PER-44`) in doc filenames or headers
- Existing specs: `SPEC.md` (benchmark), `app/SPEC.md` (product), `docs/subscription-screen-spec.md`

## Commit & PR Conventions

- Prefix: `PER-XX:` for ticketed work, `feat:`/`fix:`/`chore:` for unlinked
- One PR per task — never combine unrelated changes
- PR body should include verification steps

## Code Style

- Swift 6, strict concurrency (`@MainActor`, `nonisolated`, `Sendable`)
- 4-space indent
- Custom errors: enum conforming to `LocalizedError`
- UI tests use `UITEST_MODE` launch arg to bypass camera/notifications
- Linting/formatting managed by [hk](https://hk.jdx.dev/) — see `hk.pkl`
- Python: `ruff` for linting and formatting
- Shell: `shellcheck` + `shfmt`
- Markdown/JSON/YAML: `prettier`
- Swift: `swiftlint` (macOS only)

## Things to Avoid

- Don't add external dependencies — the app is intentionally self-contained
- Don't change matching thresholds without running the benchmark
- Don't change persisted SwiftData models without bumping the schema version and adding/updating a migration test that opens the previous shipped store
- Don't bypass `UITEST_MODE` in UI tests — they must work without real camera/notifications
- Don't put documentation anywhere other than `docs/`
