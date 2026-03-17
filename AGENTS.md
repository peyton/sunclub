# Sunclub

iOS sunscreen verification app. Swift 6, iOS 18+, SwiftUI + SwiftData + Vision.
 All ML inference on-device.

## Build & Run

```
open app/Sunclub.xcodeproj
```

Scheme: **Sunclub** | Destination: iPhone simulator (iOS 18+). No SPM resolve or pod install needed.

## Test Commands

| Surface | Command |
|---------|---------|
| Unit tests | `xcodebuild test -project app/Sunclub.xcodeproj -scheme Sunclub -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SunclubTests` |
| UI tests | `xcodebuild test -project app/Sunclub.xcodeproj -scheme Sunclub -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SunclubUITests` |
| Python eval tests | `python -m pytest tests/ -v` |
| Benchmark | `cd evals/benchmark && ./benchmark.sh --strict` |

## Project Layout

```
app/          Xcode project — Swift source, tests, UI tests
evals/        Benchmark suite and eval harness
scripts/      Build/analysis scripts
tests/        Python eval tests
docs/         Specs, design docs, investigation notes
```

## Architecture Conventions

- **Models** → `app/Sunclub/Models/` — SwiftData `@Model` types
- **Services** → `app/Sunclub/Services/` — coordinators, matchers, managers
- **Views** → `app/Sunclub/Views/` — one file per screen
- **Theme** → `app/Sunclub/Shared/AppTheme.swift` — all UI tokens live here
- Singletons: `VisionFeaturePrintService.shared`, `NotificationManager.shared`
- Observable state: `AppState` is the single source of truth, injected via `@Environment`

## Documentation Rules

- **All specs, design docs, and investigation notes go in `docs/`** as Markdown files.
- Keep docs terse — spec fields, not prose
- DO NOT reference Linear ticket IDs (e.g. `PER-44`) in doc filenames or headers
- Existing specs: `SPEC.md` (benchmark), `app/SPEC.md` (product), `docs/subscription-screen-spec.md`

## Commit & PR Conventions

- Prefix: `PER-XX:` for ticketed work, `feat:`/`fix:`/`chore:` for unlinked
- One PR per task — never combine unrelated changes
- PR body should include verification steps

## Code Style

- Swift 6, strict concurrency (`@MainActor`, `nonisolated`, `Sendable`)
- 4-space indent, no external linter
- Custom errors: enum conforming to `LocalizedError`
- UI tests use `UITEST_MODE` launch arg to bypass camera/notifications

## Key Thresholds

Do not change without running the benchmark (`evals/benchmark/benchmark.sh --strict`).

| Config | directHit | consensus | support |
|--------|-----------|-----------|---------|
| `video` | 0.58 | 0.60 | 0.62 |
| `selfie` | 0.56 | 0.59 | 0.60 |

- Consecutive frame requirement: 12
- Frame sampling: every 5th frame
- Training photos: exactly 5

## Things to Avoid

- Don't add external dependencies — the app is intentionally self-contained
- Don't change matching thresholds without running the benchmark
- Don't bypass `UITEST_MODE` in UI tests — they must work without real camera/notifications
- Don't put documentation anywhere other than `docs/`
