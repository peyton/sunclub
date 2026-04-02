# Tuist Migration Notes

- Tuist manifests live under `app/` in `Project.swift`, `Tuist.swift`, and `Tuist/Package.swift`.
- The main app target now uses `app/Sunclub/Info.plist` as the single source of truth for device-required background task and document type metadata; keep `Project.swift` pointed at that file rather than duplicating plist keys in `infoPlist: .extendingDefault(...)`.
- `just` now drives `tuist generate --no-open` and `xcodebuild`.
- Fastlane release and screenshot automation were intentionally removed.
- The generated workspace is now app-only; there is no separate `Frameworks/**` project in the workspace.
- `app/Tuist/Package.swift` stays in place for Tuist, but the package currently has no remote SwiftPM dependencies.
