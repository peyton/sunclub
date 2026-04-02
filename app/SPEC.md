# Sunclub App Spec

## Product Summary

Sunclub is a local-first iOS app for maintaining a daily sunscreen habit.

The product loop is:

1. Open the app or tap the reminder.
2. Log the day manually.
3. Reinforce the streak.

## Goals

- Help users build a daily sunscreen routine with as little friction as possible.
- Make daily logging fast and repeatable with a simple manual flow.
- Make daily progress visible through streaks and weekly reporting.
- Keep the app useful without requiring an account or cloud service.
- Keep the product focused on one action: logging sunscreen for today.

## Non-Goals

- Social features, sharing, or community participation.
- Cloud sync, account creation, or cross-device history.
- Product education, ingredient analysis, or sunscreen recommendations.
- Multi-user or household support.
- In-app subscriptions, paywalls, or premium-only product tiers for v1.
- Bottle identity, barcode capture, or per-product model training.

## Core Product Principles

- One primary action per visit: the app should always guide the user toward the next obvious step.
- Low ceremony: the daily check-in should be fast enough to feel routine, not like work.
- Private by default: user data stays on device.
- Habit-first: progress, reminders, and summaries should reinforce consistency more than novelty.
- Deterministic logging: recording today should be a direct, low-friction action.

## Primary User Journey

### 1. First-Time Setup

The first-time experience should move the user from zero setup to a ready-to-use habit flow with minimal setup.

Expected sequence:

1. Welcome screen introduces Sunclub and offers a single `Get Started` action.
2. Notification prompt asks the user to enable reminders.
3. User lands on Home once onboarding is complete.

Important expectations:

- Notification permission should be requested during onboarding, but denial must not block access to the app.
- Onboarding should never force the user through a training flow.

### 2. Daily Check-In

The main recurring flow starts from Home.

Expected sequence:

1. User opens the app.
2. Home highlights the current streak and offers a prominent `Log Manually` action.
3. Manual logging records the day as complete.
4. Success screen confirms completion and shows the updated streak.
5. User returns to Home.

Important expectations:

- Verification should feel mostly automatic once sunscreen is clearly in view.
- A completed day should only count once, even if the user verifies multiple times that day.
- The app should require two consecutive `YES` responses before logging success.
- The success state should clearly reinforce progress without adding extra decisions.

### 3. Ongoing Review

The user should be able to understand recent performance without digging through history.

Expected sequence:

1. User taps the streak card on Home.
2. App opens the weekly summary.
3. User sees the number of applied days in the last seven days, any missed days, and a lightweight recap of their logged SPF and recent notes when that data exists.

The weekly summary should reinforce momentum, not punish failure.

### 4. Maintenance and Recovery

Users need a lightweight way to update reminders or review recent progress without leaving the core manual flow.

Expected sequence:

1. User opens Settings from Home.
2. User can change reminder time or adjust reapply reminders.

## Screen Responsibilities

### Welcome

- Introduce the product clearly.
- Establish that Sunclub is about daily sunscreen consistency.
- Offer one primary action: start onboarding.

### Enable Notifications

- Ask for notification permission at the right moment in onboarding.
- Explain the value simply: daily reminders to stay on track.
- Complete onboarding whether permission is granted or denied.

### Home

- Serve as the app's main dashboard.
- Show current streak prominently.
- Provide a single primary call to action: `Log Manually`.
- Provide quick access to weekly summary and settings.

### Verification Success

- Confirm the day was recorded successfully.
- Show the updated streak in a positive, lightweight way.
- Provide one action back to Home.

### Weekly Summary

- Show how many of the last seven days were completed.
- Surface missed days in a readable way.
- Surface lightweight SPF and recent note insights when the user has logged that metadata.
- Make progress easy to scan at a glance.

### Settings

- Let the user update the daily reminder time.
- Let the user tune reapply reminders without leaving the app.

## Feature Requirements

### Onboarding

- The onboarding flow should be linear and easy to understand.
- Users should always know which step they are on.
- The flow should end in a ready-to-use home screen, not a dead end.
- Onboarding completion should be persisted so returning users go straight to Home.

### Daily Verification

- The app should record a successful check-in for the current calendar day.
- Re-logging on the same day should update the existing day entry, not create duplicates.

### Streaks and Progress

- Home should display the current streak as a primary motivational element.
- Streaks should reflect consecutive completed days.
- Weekly summary should cover the rolling last seven days, including today.
- Weekly summary may show lightweight SPF and note recaps from saved check-ins.
- Progress UI should stay simple and legible rather than analytical.

### Notifications

- The app should support a user-configurable daily reminder time.
- Reminder copy should rotate so messaging does not feel overly repetitive.
- Daily notifications should provide a quick path back into the app.
- A `Log Today` notification action should route directly to manual logging.
- Weekly reminders should open the weekly summary view.
- Weekly reporting should still have a fallback notification path even if richer background behavior is unavailable.

### Settings and Controls

- Users should be able to change reminder time without repeating onboarding.
- Manual logging should always remain available as the primary check-in flow.

## Key Behavioral Expectations

### Permissions

- Notification-denied users should still be able to use the full app.
- Permission failures should surface as understandable states, not broken flows.

### Data and Persistence

- Settings and daily completion history should persist locally on device.
- The app should remain functional offline.
- There should be no required account or server dependency for core usage.

### Routing from Notifications

- A daily reminder should bring the user into the manual logging flow.
- A `Log Today` notification action should route directly to manual logging.
- Weekly reminders should open the weekly summary view.

## Out of Scope for This Version

- Multiple tracked products or bottles.
- Barcode identity or custom bottle training.
- Household or family plans.
- Deep analytics beyond streak, weekly summary, and lightweight SPF/note recap.
- Rich calendar history browsing.
- Product catalog, purchase flow, or refill logistics inside the app.
- Coaching content beyond short reminder and summary copy.

## Success Criteria

- A new user can complete onboarding in one short session.
- A returning user can complete a daily check-in quickly from Home.
- Users can understand their recent adherence from the weekly summary without explanation.
- Reminder settings are easy enough to use without support.
- The app remains valuable even for users who decline notifications.
