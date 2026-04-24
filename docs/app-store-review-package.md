# App Store Review Package

Generated from `scripts/appstore/metadata.json`. Sensitive values are supplied through environment variables or `.state/appstore/review.env`; do not paste real contact values into tracked files.

## Manual Submission Interface

Run `just appstore-env`, then `source .state/appstore/review.env` if submitting from the current shell. Submission scripts also auto-load that file when it exists.

Required environment variables:

- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_KEY_FILE`
- `SUNCLUB_APP_PRIVACY_COMPLETED`
- `SUNCLUB_APP_REVIEW_CONTACT_EMAIL`
- `SUNCLUB_APP_REVIEW_CONTACT_FIRST_NAME`
- `SUNCLUB_APP_REVIEW_CONTACT_LAST_NAME`
- `SUNCLUB_APP_REVIEW_CONTACT_PHONE`
- `SUNCLUB_REGULATED_MEDICAL_DEVICE_STATUS`
- `SUNCLUB_CONFIRM_APP_REVIEW_SUBMIT`
- `SUNCLUB_APP_REVIEW_CHECKPOINT_CONFIRMED`

## Listing

- Name: Sunclub
- Subtitle: Daily SPF Habit Tracker
- SKU: sunclub-ios-001
- Bundle ID: app.peyton.sunclub
- Primary locale: en-US
- Primary category: HEALTH_AND_FITNESS
- Secondary category: LIFESTYLE
- Age rating target: 4+
- Device family: iphone
- Pricing: free
- Support URL: <https://sunclub.peyton.app/support>
- Marketing URL: <https://sunclub.peyton.app>
- Privacy Policy URL: <https://sunclub.peyton.app/privacy>

Description:

Sunclub helps you keep a daily sunscreen habit without accounts, feeds, or extra setup.

Log today in a few taps, keep your streak moving, review the last 7 days at a glance, and get reminders when it is time to apply or reapply.

Features:

• Manual Logging — Record today quickly, even when you're on the go.
• Streak Tracking — Keep your current streak and personal best in view.
• Weekly Summary — Review the last 7 days at a glance.
• Reapply Reminders — Set daily and reapply reminders that open straight into Sunclub.
• Private by Default — No app-owned accounts, no ads, optional private iCloud sync, local backup/import, and no analytics SDKs.

Sunclub is built for people who want sun protection to be a routine instead of another task to remember.

Keywords: sunscreen, spf, uv, habit, streak, daily, reminder, skincare, sun care

Promotional text: Build a steady sunscreen routine with quick logging, streaks, and reminders.

What's New: Initial release. Log sunscreen use quickly, keep your streak on track, and stay consistent with reminders.

## App Review Notes

- Demo account required: no
- Demo account notes: No account required. App data is stored on device and can sync through the user's private iCloud database when iCloud sync is enabled.
- Notes: Yes, Sunclub includes WeatherKit, but only as an optional Live UV enhancement powered by Apple Weather. Live UV is off by default; core manual logging, weekly summaries, reminders, widgets, and watch surfaces work without WeatherKit or location. To navigate to the WeatherKit functionality: complete onboarding, open Settings, open Live UV, enable Live UV, grant location permission if prompted, then return to Home or Timeline. When Live UV is enabled, WeatherKit requests happen from foreground/user-initiated main-app refreshes, are cached and rate-limited, and fall back to local UV estimates if location, network, remote config, or Apple Weather is unavailable. Apple Weather data appears only in main-app surfaces that display Apple Weather attribution plus a visible legal/data-source link. Widgets, watch, and Live Activities use local estimates instead of WeatherKit-derived UV values. Reviewers can complete onboarding, log sunscreen manually from Home, open Weekly Summary, and adjust reminder settings from Settings.
- Contact first name: `SUNCLUB_APP_REVIEW_CONTACT_FIRST_NAME`
- Contact last name: `SUNCLUB_APP_REVIEW_CONTACT_LAST_NAME`
- Contact email: `SUNCLUB_APP_REVIEW_CONTACT_EMAIL`
- Contact phone: `SUNCLUB_APP_REVIEW_CONTACT_PHONE`

## Screenshots

- Capture device: iPhone 17 Pro Max
- Required size class: 6.9-inch iPhone
- Display type: APP_IPHONE_67
- Generated output: `.build/appstore-screenshots`
- welcome: route `welcome`
- home: route `home`
- check-in-success: route `verifySuccess`
- weekly-summary: route `weeklySummary`
- settings: route `settings`

## App Privacy

- Tracking: no
- Data collection: none
- Public CloudKit accountability transport: no
- Notification purpose: Notifications remind the user to apply or reapply sunscreen.
- App Store Connect questionnaire gate: `SUNCLUB_APP_PRIVACY_COMPLETED=1`

Manual App Store Connect answer: data not collected for the default release build. Keep this answer only while public CloudKit accountability transport remains disabled.

## Age Rating

- ads: no
- unrestricted_web_access: no
- broad_user_generated_content: no
- in_app_chat: no
- gambling_or_contests: no
- mature_or_suggestive_content: none
- sexual_content_or_nudity: none
- violence: none
- substance_or_tobacco_content: none
- medical_or_treatment_information: none
- health_or_wellness_topics: sunscreen habit guidance only

## Accessibility Nutrition Label

- ready: yes
- supports_audio_descriptions: no
- supports_captions: no
- supports_dark_interface: yes
- supports_differentiate_without_color_alone: yes
- supports_larger_text: yes
- supports_reduced_motion: yes
- supports_sufficient_contrast: yes
- supports_voice_control: yes
- supports_voiceover: yes

## Export Compliance And Rights

- Uses encryption: no
- Contains third-party content: no
- Content rights note: Sunclub and its app code, product copy, visual assets, and release artifacts are owned by Peyton Randolph. This app does not contain, show, or access third-party content.

## Attestations

- free_only: yes
- in_app_purchases: no
- idfa: no
- tracking: no
- ads: no
- analytics_sdks: no
- non_exempt_encryption: no
- third_party_content: no
- kids_category: no
- iphone_only_v1: yes
- accessibility_criteria_reviewed: yes
- public_cloudkit_accountability_transport_enabled: no

## Medical Device Status

- Manifest status: not_regulated
- App Store Connect value: NOT_MEDICAL_DEVICE
- Confirmation gate: `SUNCLUB_REGULATED_MEDICAL_DEVICE_STATUS=NOT_MEDICAL_DEVICE`
- Notes: Sunclub is sunscreen habit guidance only. It does not diagnose, monitor, prevent, or treat disease and is not a regulated medical device.

## Manual App Store Connect Checks

- Confirm App Privacy answers match this package before setting `SUNCLUB_APP_PRIVACY_COMPLETED=1`.
- Confirm regulated medical device status is `NOT_MEDICAL_DEVICE` before setting `SUNCLUB_REGULATED_MEDICAL_DEVICE_STATUS=NOT_MEDICAL_DEVICE`.
- Confirm age-rating answers match the questionnaire above.
- Confirm pricing is free, no IAP is configured, and no Kids category is selected.
- Confirm screenshot upload completed for the listed iPhone display type.
- Confirm final checkpoint summary before running `just appstore-submit-review` or `just appstore-send-review`.

## Submission Commands

- Draft validation: `just appstore-validate`
- Strict validation: `just appstore-validate-strict`
- Regenerate this package: `just appstore-review-package`
- Dry run: `just appstore-submit-dry-run`
- Submit: `just appstore-submit-review`
- Alias: `just appstore-send-review`

## Remaining Manual Steps

- Run just appstore-env to populate App Store Connect API credentials, App Review contact values, App Privacy confirmation, and medical-device status in .state/appstore/review.env.
- Deploy the web directory to Cloudflare Pages and verify <https://sunclub.peyton.app/config/weatherkit.json> plus <https://sunclub.peyton.app/schemas/weatherkit-config.v1.json> before resubmitting.
- Answer App Privacy questions in App Store Connect to match this manifest, then set SUNCLUB_APP_PRIVACY_COMPLETED=1.
- Set regulated medical device status in App Store Connect to NOT_MEDICAL_DEVICE, then set SUNCLUB_REGULATED_MEDICAL_DEVICE_STATUS=NOT_MEDICAL_DEVICE.
- Review docs/app-store-review-package.md before final submission.
