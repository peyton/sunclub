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
- Subtitle: Daily Sunscreen Tracker
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

Sunclub is a private sunscreen tracker for exact application logging, live UV context, helpful progress, and reliable reapply reminders.

Record what you applied and when, see when sun protection is recommended, and keep the next useful action close at hand.

Features:

• Accurate Logging — Record an exact time, SPF, covered areas, and optional product details.
• Live UV Context — See Apple Weather UV guidance with a clear source and update time.
• Reliable Reminders — Set daily and reapply reminders, then log or snooze from the notification.
• Apple Watch and Widgets — Check UV and log sunscreen from the surfaces you already use.
• Shortcuts and Live Activities — Automate non-destructive actions and keep reapply timing visible.
• Private by Default — No app-owned accounts, no ads, optional private iCloud sync, local backup/import, and no analytics SDKs.

Sunclub supports a sunscreen routine without medical scoring or pressure-based goals.

Keywords: sunscreen, spf, uv, habit, streak, daily, reminder, skincare, sun care

Promotional text: Log sunscreen with an exact time, check sourced UV guidance, and act on reliable reapply reminders — private by default.

What's New: This update makes logging and reminders more trustworthy: edit exact application times, see clearer live UV sources, use contextual next actions, and act on reapply notifications. It also improves Larger Text layouts and keeps public Activity sharing disabled while that feature is not part of the visible app.

## App Review Notes

- Demo account required: no
- Demo account notes: No account required. App data is stored on device and can sync through the user's private iCloud database when iCloud sync is enabled.
- Notes: Yes, Sunclub includes WeatherKit, but only as an optional Live UV enhancement powered by Apple Weather. Live UV is off by default; core manual logging, progress, reminders, widgets, and watch surfaces work without WeatherKit or location. To navigate to WeatherKit functionality: complete onboarding, open Settings, open UV & Health, enable Live UV, choose a city or grant location permission, then return to Timeline/Home. WeatherKit requests are foreground/user-initiated, cached for no more than two hours, and rate-limited. The fallback when location, network, remote config, or Apple Weather is unavailable is an explicit UV unavailable state rather than a numeric estimate. Apple Weather values show attribution plus a visible legal data-source link named Data Sources. Reviewers can complete onboarding, log sunscreen manually from Home, open Insights, and adjust reminder settings from Settings.
- Contact first name: `SUNCLUB_APP_REVIEW_CONTACT_FIRST_NAME`
- Contact last name: `SUNCLUB_APP_REVIEW_CONTACT_LAST_NAME`
- Contact email: `SUNCLUB_APP_REVIEW_CONTACT_EMAIL`
- Contact phone: `SUNCLUB_APP_REVIEW_CONTACT_PHONE`

## Screenshots

- Capture device: iPhone 17 Pro Max
- Required size class: 6.9-inch iPhone
- Display type: APP_IPHONE_67
- Generated output: `.build/appstore-screenshots`
- log-spf: route `manualLog`, headline "Log the exact time", caption "Record time, SPF, covered areas, and an optional reusable profile."
- uv-timeline: route `home`, headline "Know today's UV", caption "See sourced Apple Weather UV, its update time, and the next useful action."
- reapply-time: route `verifySuccess`, headline "Act on reminders", caption "Follow your label, log a reapplication, or snooze for 30 minutes."
- weekly-progress: route `weeklySummary`, headline "Build from day one", caption "Review eligible days and encouraging local-first progress insights."
- private-settings: route `settings`, headline "Private by default", caption "No account, no ads, optional iCloud sync and local backup."

## App Privacy

- Tracking: no
- Data collection: none
- Collected data types: none
- Collection purpose: Not Collected
- Public CloudKit accountability transport: no
- Notification purpose: Notifications remind the user to apply or reapply sunscreen.
- App Store Connect questionnaire gate: `SUNCLUB_APP_PRIVACY_COMPLETED=1`

Manual App Store Connect answer: select Data Not Collected and do not mark tracking, ads, or analytics. The production build keeps public Activity sharing transport disabled. Local history and optional private iCloud sync remain user-controlled and are not accessible to the developer.

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
  `just appstore-submit-draft` prepares the draft submission without the final review submit flag.

## Submission Commands

- Draft validation: `just appstore-validate`
- Strict validation: `just appstore-validate-strict`
- Regenerate this package: `just appstore-review-package`
- Dry run: `just appstore-submit-dry-run`
- Draft: `just appstore-submit-draft`
- Submit: `just appstore-submit-review`
- Alias: `just appstore-send-review`

## Remaining Manual Steps

- Run just appstore-env to populate App Store Connect API credentials, App Review contact values, App Privacy confirmation, and medical-device status in .state/appstore/review.env.
- Deploy the web directory to Cloudflare Pages and verify <https://sunclub.peyton.app/config/weatherkit.json> plus <https://sunclub.peyton.app/schemas/weatherkit-config.v1.json> before resubmitting.
- Answer App Privacy questions in App Store Connect to match this manifest, then set SUNCLUB_APP_PRIVACY_COMPLETED=1.
- Set regulated medical device status in App Store Connect to NOT_MEDICAL_DEVICE, then set SUNCLUB_REGULATED_MEDICAL_DEVICE_STATUS=NOT_MEDICAL_DEVICE.
- Review docs/app-store-review-package.md before final submission.
