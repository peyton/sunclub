# Sunclub App Spec

## Product Summary

Sunclub is a local-first iOS app for helping someone maintain a daily sunscreen habit.

The product is centered on one simple loop:

1. Set up the sunscreen bottle the user actually uses.
2. Make daily verification fast and repeatable.
3. Reinforce consistency through streaks, reminders, and a weekly summary.

The app should feel lightweight, private, and focused. It is not trying to be a full skincare platform or a social product.

## Goals

- Help users build a daily sunscreen routine with as little friction as possible.
- Turn one sunscreen bottle into a repeatable habit anchor.
- Make daily progress visible through streaks and weekly reporting.
- Keep the app useful without requiring an account, network connection, or external services.
- Give users a simple way to recover from setup issues by retraining their bottle or changing reminder time.

## Non-Goals

- Social features, sharing, or community participation.
- Cloud sync, account creation, or cross-device history.
- Product education, ingredient analysis, or sunscreen recommendations.
- Multi-user or household support.
- Advanced subscription management inside the app beyond handing off to Apple.
- A complex verification system with multiple daily tasks or long-form journaling.

## Core Product Principles

- One primary action per visit: the app should always guide the user toward the next obvious step.
- Low ceremony: the daily check-in should be fast enough to feel routine, not like work.
- Private by default: user data stays on device.
- Habit-first: progress, reminders, and summaries should reinforce consistency more than novelty.
- Recoverable setup: if the bottle changes or setup fails, the app should offer a clear retraining path.

## Primary User Journey

### 1. First-Time Setup

The first-time experience should move the user from zero setup to a ready-to-use habit flow.

Expected sequence:

1. Welcome screen introduces Sunclub and offers a single `Get Started` action.
2. Barcode scan screen asks the user to scan their sunscreen bottle barcode.
3. Bottle training screen captures exactly five photos of the bottle.
4. Notification prompt asks the user to enable reminders.
5. User lands on Home once onboarding is complete.

Important expectations:

- Barcode capture is helpful but not mandatory. Users can skip it and continue onboarding.
- Bottle training is mandatory before onboarding is complete.
- Notification permission should be requested during onboarding, but denial must not block access to the app.

### 2. Daily Check-In

The main recurring flow starts from Home.

Expected sequence:

1. User opens the app.
2. Home highlights the current streak and offers a prominent `Verify Now` action.
3. Verification screen uses the camera to recognize the trained bottle.
4. Successful verification records the day as complete.
5. Success screen confirms completion and shows the updated streak.
6. User returns to Home.

Important expectations:

- Verification should feel mostly automatic once the bottle is clearly in view.
- A completed day should only count once, even if the user verifies multiple times that day.
- The success state should clearly reinforce progress without adding extra decisions.

### 3. Ongoing Review

The user should be able to understand recent performance without digging through history.

Expected sequence:

1. User taps the streak card on Home.
2. App opens the weekly summary.
3. User sees the number of applied days in the last seven days and any missed days.

The weekly summary should reinforce momentum, not punish failure.

### 4. Maintenance and Recovery

Users need a lightweight way to update reminders or replace their trained bottle model.

Expected sequence:

1. User opens Settings from Home.
2. User can change reminder time, retrain the bottle model, or manage subscription externally.

Retraining is the main recovery path when:

- the user changes bottles,
- the original training data is poor,
- or verification becomes unreliable.

## Screen Responsibilities

### Welcome

- Introduce the product clearly.
- Establish that Sunclub is about daily sunscreen consistency.
- Offer one primary action: start onboarding.

### Scan Barcode

- Capture the barcode of the sunscreen bottle the user wants to track.
- Save that barcode as the expected bottle identity when available.
- Allow the user to skip if scanning is inconvenient or unavailable.

### Train Bottle

- Capture five photos of the bottle to prepare it for verification.
- Show clear progress during capture.
- Reuse the same flow for both first-time onboarding and later retraining.

### Enable Notifications

- Ask for notification permission at the right moment in onboarding.
- Explain the value simply: daily reminders to stay on track.
- Complete onboarding whether permission is granted or denied.

### Home

- Serve as the app's main dashboard.
- Show current streak prominently.
- Provide a single primary call to action: `Verify Now`.
- Provide quick access to weekly summary and settings.

### Verify

- Use the live camera experience to confirm the trained bottle is present.
- Communicate current status clearly while recognition is in progress.
- Transition automatically to success once verification is complete.

### Verification Success

- Confirm the day was recorded successfully.
- Show the updated streak in a positive, lightweight way.
- Provide one action back to Home.

### Weekly Summary

- Show how many of the last seven days were completed.
- Surface missed days in a readable way.
- Make progress easy to scan at a glance.

### Settings

- Let the user update the daily reminder time.
- Let the user clear and retrain the bottle model.
- Hand off subscription management to Apple when available.

## Feature Requirements

### Onboarding

- The onboarding flow should be linear and easy to understand.
- Users should always know which step they are on.
- The flow should end in a ready-to-use home screen, not a dead end.
- Onboarding completion should be persisted so returning users go straight to Home.

### Bottle Registration

- The app should support associating the habit with one sunscreen bottle.
- Barcode capture is optional support for bottle identity.
- Visual training is required and should produce a usable verification model from five captures.
- Retraining should replace the prior bottle model rather than layering multiple active bottle setups.

### Daily Verification

- Verification should rely on the trained bottle model.
- The app should record a successful check-in for the current calendar day.
- Re-verifying on the same day should update the existing day entry, not create duplicates.
- If the user tries to verify without training data, the app should direct them toward retraining instead of failing silently.

### Streaks and Progress

- Home should display the current streak as a primary motivational element.
- Streaks should reflect consecutive completed days.
- Weekly summary should cover the rolling last seven days, including today.
- Progress UI should stay simple and legible rather than analytical.

### Notifications

- The app should support a user-configurable daily reminder time.
- Reminder copy should rotate so messaging does not feel overly repetitive.
- Daily notifications should provide a quick path back into the app.
- Weekly notifications should direct the user to their weekly summary.
- Weekly reporting should still have a fallback notification path even if richer background behavior is unavailable.

### Settings and Controls

- Users should be able to change reminder time without repeating onboarding.
- Users should be able to retrain the bottle model without resetting the entire app.
- Subscription management should be a system handoff, not a custom in-app billing interface.

## Key Behavioral Expectations

### Permissions

- Camera-denied states should be handled gracefully on scan, train, and verify screens.
- Notification-denied users should still be able to use the full app.
- Permission failures should surface as understandable states, not broken flows.

### Data and Persistence

- Settings, training data, and daily completion history should persist locally on device.
- The app should remain functional offline after installation.
- There should be no required account or server dependency for core usage.

### Routing from Notifications

- A daily reminder should bring the user back into the core daily flow.
- A `Verify Now` notification action should route directly to verification.
- Weekly reminders should open the weekly summary view.

## Out of Scope for This Version

- Multiple tracked bottles.
- Household or family plans.
- Deep analytics beyond streak and weekly summary.
- Rich calendar history browsing.
- Product catalog, purchase flow, or refill logistics inside the app.
- Coaching content beyond short reminder and summary copy.

## Success Criteria

- A new user can complete onboarding in one short session.
- A returning user can complete a daily verification quickly from Home.
- Users can understand their recent adherence from the weekly summary without explanation.
- Reminder settings and retraining are easy enough to use without support.
- The app remains valuable even for users who decline notifications.
