# App Store Submission

Sunclub now treats `scripts/appstore/metadata.json` as the single submission manifest. The manifest includes app identity, localization copy, App Review notes, privacy/export answers, and the screenshot inventory used by the simulator capture script.

## Current Status

- `scripts/appstore/validate_metadata.py --allow-draft` checks the manifest shape, Apple text limits, route inventory, and marketing-copy contradictions without requiring final URLs or final App Review contact details.
- `scripts/appstore/validate_metadata.py` runs the strict submission check. It fails until the support, marketing, and privacy URLs are live and the App Review contact is marked ready.
- `scripts/appstore/capture-screenshots.sh` builds the real app, boots the simulator named in the manifest, and captures the manifest-defined iPhone screenshots through `UITEST_MODE` launch routes.
- `scripts/appstore/create-app-store-listing.sh` only patches the App Store Connect fields that map cleanly to the manifest. It does not create the app record, upload screenshots, or answer App Privacy questionnaires.
- `scripts/appstore/archive-and-upload.sh` validates the manifest, archives the signed release build, confirms the FastVLM payload is absent from the `.app` bundle, confirms an ODR asset pack exists, and exports the IPA. Upload remains manual.

## Commands

From the repo root:

```bash
just appstore-validate
bash scripts/appstore/capture-screenshots.sh
bash scripts/appstore/create-app-store-listing.sh
bash scripts/appstore/archive-and-upload.sh
```

## Required Manual Work

These steps still require real App Store Connect data and cannot be faked safely inside the repo:

1. Replace the draft support, marketing, and privacy URLs in `scripts/appstore/metadata.json`, then set each `ready` flag to `true`.
2. Replace the draft App Review contact information in `scripts/appstore/metadata.json`, then set `review.contact.ready` to `true`.
3. Upload the generated 6.9-inch iPhone screenshots in App Store Connect.
4. Complete App Privacy answers and export compliance answers in App Store Connect so they match the manifest.
5. Upload the exported IPA with Transporter or the App Store Connect web flow.

## Review Notes

- Sunclub is free-only for v1.
- The app is iPhone-only.
- Camera verification uses a one-time App Store-hosted FastVLM download, then keeps verification available offline on that device.
- Manual logging remains available even when the model has not been downloaded.
