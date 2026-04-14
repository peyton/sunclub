# App Store Submission

Sunclub treats `scripts/appstore/metadata.json` as the single submission manifest. The manifest includes app identity, localization copy, App Review notes, privacy/export answers, and the screenshot inventory used by the simulator capture script.

## Current Status

- The public web presence lives in `web/` and is published as static files at `https://sunclub.peyton.app`. The App Store marketing, support, and privacy URLs in the manifest now point to that host.
- `scripts/appstore/validate_metadata.py --allow-draft` checks the manifest shape, Apple text limits, route inventory, accessibility declarations, screenshot display type, release type, and marketing-copy contradictions without requiring final App Review contact details or the App Privacy completion gate.
- `scripts/appstore/validate_metadata.py` runs the strict submission check. It fails until the App Review contact is marked ready and `privacy.app_store_connect_completed` is `true`.
- `scripts/appstore/capture-screenshots.sh` builds the real app, boots the simulator named in the manifest, and captures the manifest-defined iPhone screenshots through `UITEST_MODE` launch routes.
- `scripts/appstore/submit-review.sh --dry-run` prints the App Store Connect mutation plan and local blockers without network writes.
- `scripts/appstore/submit-review.sh --submit` captures screenshots, uploads the build, uploads screenshots, patches metadata, creates the review submission, and submits it for App Review. It refuses to run without `SUNCLUB_CONFIRM_APP_REVIEW_SUBMIT=1` or `--confirm-submit`.
- `scripts/appstore/create-app-store-listing.sh` is superseded by the Python review-submission workflow. Keep it only for narrow listing-only patching if needed.
- `scripts/appstore/archive-and-upload.sh` validates the manifest, archives the signed release build, exports the IPA, and can upload to TestFlight with `altool` when App Store Connect API key credentials are available.
- `.github/workflows/release-testflight.yml` runs the same archive flow automatically for pushed `vX.Y.Z` tags, but passes `--allow-draft-metadata` so TestFlight uploads are not blocked by still-draft App Review contact details.
- `.github/workflows/submit-app-review.yml` is a manual workflow that checks out a release tag, captures screenshots, uploads the build, and runs the same final review-submission command behind an explicit confirmation input.
- Export compliance is declared by `export_compliance.uses_encryption: false` in the manifest and `ITSAppUsesNonExemptEncryption=false` in `app/Sunclub/Info.plist`.

## Commands

From the repo root:

```bash
just appstore-validate
just appstore-submit-dry-run
just web-check
just web-build
just appstore-screenshots
just appstore-archive
SUNCLUB_CONFIRM_APP_REVIEW_SUBMIT=1 just appstore-submit-review
just release-tag 1.2.3
```

See [docs/testflight-release.md](testflight-release.md) for the full flavor and versioning flow.
Use the default strict archive path when you are preparing the actual App Store submission package.

## Required Manual Work

These steps still require real App Store Connect data and cannot be faked safely inside the repo:

1. Replace the draft App Review contact information in `scripts/appstore/metadata.json`, then set `review.contact.ready` to `true`.
2. Complete App Privacy answers in App Store Connect so they match the manifest, then set `privacy.app_store_connect_completed` to `true`.
3. Re-audit the Accessibility Nutrition Label answers if the supported accessibility criteria change before submission.

## Review Notes

- Sunclub is free-only for v1.
- The app is iPhone-only.
- The primary check-in flow is manual logging from Home.
- Weekly Summary and reminder settings remain part of the submission flow.
