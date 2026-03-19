# Tuist Migration Notes

- Tuist manifests live under `app/` in `Project.swift`, `Tuist.swift`, and `Tuist/Package.swift`.
- The `FastVLM` source files were restored to `app/FastVLM/`.
- `just` now drives `tuist generate --no-open` and `xcodebuild`.
- Fastlane release and screenshot automation were intentionally removed.
- Model assets are expected under `app/FastVLM/model/` after `just download-model`.
