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

Make sunscreen part of your everyday skincare routine.

A quick log. A timely reminder. A little more consistency. Sunclub keeps your daily SPF routine simple, whether you are getting ready for work or heading outside.

LOG IN A MOMENT
Log sunscreen with a tap, or add the time, SPF, covered areas, and product details. Forgot to log? Add an earlier application to your history.

REMEMBER TO REAPPLY
Choose daily and reapplication reminders that fit your routine. Log or snooze from a notification, and keep reapplication timing close with Live Activities. Follow your sunscreen label for when to reapply.

CHECK THE UV
See UV context for your day, with a clear source and update time. Turn on optional Apple Weather forecasts for your current location or a saved city.

SEE YOUR ROUTINE TAKE SHAPE
Look back at your sunscreen history, recent days, and streak. Keep a useful record of the habit you are building.

KEEP IT CLOSE
Log from widgets and Apple Watch, or make Sunclub part of your Shortcuts.

YOUR ROUTINE, YOUR DATA
Free. No account, ads, or analytics SDKs. Keep your history on your device, enable optional private iCloud sync, and export a backup whenever you need one.

Keywords: sunscreen, spf, uv, habit, streak, daily, reminder, skincare, sun care

Promotional text: Your daily SPF ritual. Log sunscreen in a tap, remember to reapply, and see your routine take shape. Free, private, and made for everyday skincare.

What's New: Simplify, simplify, simplify. Fix notification and other bugs

## App Review Notes

- Demo account required: no
- Demo account notes: No account required. App data is stored on device and can sync through the user's private iCloud database when iCloud sync is enabled.
- Notes: Yes, Sunclub includes WeatherKit as an optional Live UV enhancement powered by Apple Weather. Live UV is off by default; core manual logging, progress, reminders, widgets, and watch surfaces work without WeatherKit or location. To navigate to WeatherKit functionality: complete onboarding, open Settings, open UV & Weather, then choose Choose a City to use a saved city, or turn on Use current location and grant location permission. Return to Today and tap the UV card to view the forecast. WeatherKit requests occur only while the main app is active; they are cache- and rate-limit-gated and may start automatically on launch or foreground activation, or after a user refresh or settings action. Apple Weather forecasts are cached for up to eight hours; last-known Apple Weather values may appear for up to 24 hours with their age clearly shown. The fallback when no Apple Weather value is available is a clearly labeled on-device estimate based on available latitude, season, and time, or generic season and time without location. Apple Weather attribution and the Data Sources legal link apply only to Apple Weather values, including cached or last-known Apple Weather values. Reviewers can complete onboarding, tap Log sunscreen on Today, review logged applications in History, and adjust reminders in Settings > Reminders.
- Contact first name: `SUNCLUB_APP_REVIEW_CONTACT_FIRST_NAME`
- Contact last name: `SUNCLUB_APP_REVIEW_CONTACT_LAST_NAME`
- Contact email: `SUNCLUB_APP_REVIEW_CONTACT_EMAIL`
- Contact phone: `SUNCLUB_APP_REVIEW_CONTACT_PHONE`

## Screenshots

- Capture device: iPhone 17 Pro Max
- Required size class: 6.9-inch iPhone
- Display type: APP_IPHONE_67
- Generated output: `.build/appstore-screenshots`
- daily-ritual: route `home`, headline "Your daily SPF ritual", caption "One quick log for your everyday skincare routine."
- log-spf: route `manualLog`, headline "Log it. Get on with your day.", caption "Keep the time, SPF, and details that matter to you."
- reapply-time: route `home`, headline "Make reapplying a habit", caption "Keep your next reapplication close at hand."
- uv-forecast: route `uvForecast`, headline "A little context for your day", caption "Check the UV with a clear source and forecast."
- routine-history: route `weeklySummary`, headline "See your routine take shape", caption "Look back on the days you made time for SPF."

## App Privacy

- Tracking: no
- Data collection: none
- Collected data types: none
- Collection purpose: Not Collected
- Notification purpose: Notifications remind the user to apply or reapply sunscreen.
- App Store Connect questionnaire gate: `SUNCLUB_APP_PRIVACY_COMPLETED=1`

Manual App Store Connect answer: select Data Not Collected and do not mark tracking, ads, or analytics. Local history and optional private iCloud sync remain user-controlled and are not accessible to the developer.

## Age Rating

- ads: no
- unrestricted_web_access: no
- broad_user_generated_content: no
- in_app_chat: no
- social_media: no
- social_media_age_restricted: no
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
