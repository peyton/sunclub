# App Store Submission

Sunclub treats `scripts/appstore/metadata.json` as the single non-secret submission manifest. The manifest includes app identity, localization copy, App Review notes, category defaults, age-rating answers, privacy/export answers, accessibility declarations, regulated medical device status, attestations, and the screenshot inventory used by the simulator capture script.

## Current Status

- The public web presence lives in `web/` and is published as static files at `https://sunclub.peyton.app`. The App Store marketing, support, and privacy URLs in the manifest now point to that host.
- Sensitive App Review contact fields and App Store Connect API credentials are loaded from shell env or ignored `.state/appstore/review.env`. Run `just appstore-env` to create that file locally with mode `600`.
- `scripts/appstore/validate_metadata.py --allow-draft` checks the manifest shape, Apple text limits, route inventory, accessibility declarations, screenshot display type, release type, manual gates, and marketing-copy contradictions without requiring final App Review contact details or completion gates.
- `scripts/appstore/validate_metadata.py` runs the strict submission check. It fails until App Review contact env vars are present, `SUNCLUB_APP_PRIVACY_COMPLETED=1`, and `SUNCLUB_REGULATED_MEDICAL_DEVICE_STATUS=NOT_MEDICAL_DEVICE`.
- `scripts/appstore/review_package.py` regenerates `docs/app-store-review-package.md`; `--checkpoint` writes `.build/appstore-review-checkpoint/summary.md` with redacted contact details.
- `scripts/appstore/capture-screenshots.sh` builds the real app, boots the simulator named in the manifest, and captures the manifest-defined iPhone screenshots through `UITEST_MODE` launch routes.
- `scripts/appstore/submit-review.sh --dry-run` prints the App Store Connect mutation plan and local blockers without network writes.
- `scripts/appstore/submit-review.sh --submit` validates strictly, captures screenshots, writes and prints the redacted checkpoint, asks for the exact checkpoint phrase, uploads the build, uploads screenshots, patches metadata, creates the review submission, and submits it for App Review. Non-interactive submission additionally requires `SUNCLUB_CONFIRM_APP_REVIEW_SUBMIT=1` and `SUNCLUB_APP_REVIEW_CHECKPOINT_CONFIRMED=1`.
- `scripts/appstore/create-app-store-listing.sh` is superseded by the Python review-submission workflow. Keep it only for narrow listing-only patching if needed.
- `scripts/appstore/archive-and-upload.sh` validates the manifest, archives the signed release build, exports the IPA, and can upload to TestFlight with `altool` when App Store Connect API key credentials are available.
- `.github/workflows/release-testflight.yml` runs the same archive flow automatically for pushed `vX.Y.Z` tags, but passes `--allow-draft-metadata` so TestFlight uploads are not blocked by still-draft App Review contact details.
- `.github/workflows/submit-app-review.yml` is a manual workflow that checks out a release tag, captures screenshots, writes the checkpoint, uploads the build, and runs the same final review-submission wrapper behind an explicit confirmation input plus `SUNCLUB_APP_REVIEW_CHECKPOINT_CONFIRMED=1`.
- Export compliance is declared by `export_compliance.uses_encryption: false` in the manifest and `ITSAppUsesNonExemptEncryption=false` in `app/Sunclub/Info.plist`.

## Commands

From the repo root:

```bash
just appstore-env
just appstore-validate
just appstore-validate-strict
just appstore-review-package
just appstore-submit-dry-run
just web-check
just web-build
just appstore-screenshots
just appstore-archive
just appstore-submit-review
just appstore-send-review
just release-tag 1.2.3
```

See [docs/testflight-release.md](testflight-release.md) for the full flavor and versioning flow.
Use the default strict archive path when you are preparing the actual App Store submission package.

## Required Manual Work

These steps still require real App Store Connect data and cannot be faked safely inside the repo:

1. Run `just appstore-env` and provide App Store Connect API key values plus App Review contact values.
2. Deploy the web directory to Cloudflare Pages, then verify `https://sunclub.peyton.app/config/weatherkit.json` and `https://sunclub.peyton.app/schemas/weatherkit-config.v1.json` return the current canonical WeatherKit policy/schema.
3. Complete App Privacy answers in App Store Connect so they match `docs/app-store-review-package.md`, then set `SUNCLUB_APP_PRIVACY_COMPLETED=1`.
4. Set regulated medical device status to `NOT_MEDICAL_DEVICE`, then set `SUNCLUB_REGULATED_MEDICAL_DEVICE_STATUS=NOT_MEDICAL_DEVICE`.
5. Re-audit the Accessibility Nutrition Label answers if the supported accessibility criteria change before submission.
6. Review `.build/appstore-review-checkpoint/summary.md` before typing the final local confirmation phrase.

## Review Notes

- Sunclub is free-only for v1.
- The app is iPhone-only.
- Sunclub is not a regulated medical device; it is sunscreen habit guidance, not diagnosis, monitoring, prevention, or treatment.
- Public CloudKit accountability transport is disabled for the first App Store review build. Private iCloud history sync remains enabled.
- This submitted version includes WeatherKit, but only as an optional Live UV enhancement powered by Apple Weather.
- Live UV is off by default. Manual sunscreen logging, Weekly Summary, reminders, widgets, and watch surfaces work without WeatherKit or location.
- To navigate to WeatherKit functionality: complete onboarding, open Settings, open Live UV, enable Live UV, grant location permission if prompted, then return to Home or Timeline.
- WeatherKit requests are foreground/user-initiated from the main app, cached, rate-limited, and covered by the remote config at `https://sunclub.peyton.app/config/weatherkit.json`.
- Main-app Apple Weather values show Apple Weather attribution and a visible legal/data-source link. Widgets, watch, and Live Activities use local estimates instead of WeatherKit-derived UV values.
- Sunclub falls back to local UV estimates when location, network, remote config, or Apple Weather is unavailable.
- The primary check-in flow is manual logging from Home.
- Weekly Summary and reminder settings remain part of the submission flow.

## WeatherKit Reviewer Reply Draft

Use this text when replying to App Review's WeatherKit information request:

```text
Yes, Sunclub includes WeatherKit, but only as an optional Live UV enhancement powered by Apple Weather.

Live UV is off by default. The app's core features, including manual sunscreen logging, Weekly Summary, reminders, widgets, and watch surfaces, work without WeatherKit and without location access.

To navigate to the WeatherKit functionality:
1. Complete onboarding.
2. Open Settings.
3. Open Live UV.
4. Enable Live UV.
5. Grant location permission if prompted.
6. Return to Home or Timeline.

When Live UV is enabled, Apple Weather UV data is shown only in the main app on surfaces that include Apple Weather attribution and a visible Data Sources/legal attribution link. Widgets, watch, and Live Activities use Sunclub's local UV estimates instead of WeatherKit-derived values.

WeatherKit requests are foreground/user-initiated, cached, rate-limited, and fall back to local UV estimates if location, network, remote config, or Apple Weather is unavailable.
```
