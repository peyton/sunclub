# App Store Review Automation ExecPlan

Sunclub needs a repeatable App Review submission path that uses the existing metadata manifest and release build tooling instead of relying on App Store Connect web UI steps for every release. This change adds a repo-local App Store Connect API client, a guarded final submission command, a dry-run command, and a manual GitHub Actions workflow for release-tag submissions.

## Progress

- [x] Added a stdlib Python App Store Connect client with JWT auth, pagination, retries, and asset upload operations.
- [x] Added local dry-run and final-submit commands through `just`.
- [x] Extended the manifest and validator for release type, screenshot display type, App Privacy completion, and optional iPhone accessibility declarations.
- [x] Added a guarded manual GitHub workflow for App Review submission.
- [x] Added Python tests for validation, API client behavior, dry-run planning, and review submission flow failures.

## Decisions

- App Privacy questionnaire answers remain a manual verified gate because the current official API surface does not expose the questionnaire resources.
- Final review submission requires `SUNCLUB_CONFIRM_APP_REVIEW_SUBMIT=1` or `--confirm-submit` before screenshots, archive upload, or App Store Connect mutations run.
- Release type defaults to `MANUAL`, so approval moves the app to developer release instead of automatically going live.
- The automation expects the App Store Connect app record for `app.peyton.sunclub` to already exist.

## Verification

Run from the repo root:

```bash
just test-python
just appstore-validate
just ci-lint
```

`just appstore-validate` is intentionally draft-mode and should keep warning until the real review contact and App Privacy gate are completed.
