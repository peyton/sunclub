# Sunclub UX Audit, Missing Features & Improvement Proposals

## Current User Flows

### Flow 1: Onboarding (First Launch)

```
WelcomeView → EnableNotificationsView → HomeView
```

- Welcome: Logo + "Get Started" CTA
- EnableNotifications: Bell icon, explanation, single "Enable Notifications" button
- Completes onboarding flag, navigates to Home

### Flow 2: Daily Verification

```
HomeView → [Verify Now] → LiveVerifyView → VerificationSuccessView → HomeView
```

- Home shows today status card + streak card
- Camera opens, FastVLM detects sunscreen (2 consecutive YES frames)
- Success screen shows checkmark + streak count
- "Done" returns to Home

### Flow 3: Weekly Summary

```
HomeView → [Tap Streak Card] → WeeklyReportView → HomeView
```

- 7-day applied count (e.g. "3 / 7")
- 3x3 grid visualization (filled = applied)
- Lists missed days

### Flow 4: Settings

```
HomeView → [Gear Icon] → SettingsView → HomeView
```

- Daily reminder time picker (sheet)
- Manage Subscription link (external)

### Flow 5: Notification Deep Links

```
Daily notification → LiveVerifyView
Weekly notification → WeeklyReportView
```

---

## Missing Features

### High Priority (Expected in any habit-tracking app)

1. **History / Calendar View** — No way to see records beyond last 7 days. Users expect a scrollable monthly calendar showing applied/missed days at a glance.

2. **Manual Log / Tap-to-Log** — Camera-only verification is a single point of failure. Users need an alternative when they don't have their sunscreen bottle handy but did apply. The VerificationMethod enum already has room for this.

3. **Longest Streak Record** — Only current streak is shown. Users want to see their personal best to stay motivated.

4. **UV Index / Sun Exposure Awareness** — A sunscreen app should surface UV data. Even a simple "UV is high today" banner would add urgency and context.

5. **Reapplication Reminders** — Sunscreen wears off every 2 hours in sun. Users should be able to set reapplication timers after their initial check-in.

6. **Edit / Delete Records** — No way to fix mistakes. If a user accidentally logs or misses logging, there's no correction mechanism.

### Medium Priority (Expected in polished apps)

7. **Onboarding Skip Option** — No way to skip the notification step. Users who decline notifications are still forced through the flow.

8. **Weekly Notification Time Setting** — Daily reminder time is configurable, but weekly notification day/time isn't exposed in Settings (the API exists on AppState but the UI doesn't).

9. **Stats / Insights Screen** — Beyond the 7-day summary: monthly compliance rate, average streak length, best day of week, etc.

10. **Haptic Feedback** — No tactile feedback on verification success or button presses.

11. **Share Streak** — No social sharing for streaks or weekly reports.

12. **Dark Mode Toggle** — Camera screen is dark, rest is light. No user preference for full dark mode.

### Lower Priority (Nice to have)

13. **Widget** — Home screen widget showing streak + today status.
14. **Apple Watch Complication** — Quick glance at streak.
15. **Skin Type Profile** — Personalized SPF recommendations.
16. **Sunscreen Product Logging** — Track which product was used (brand, SPF level).
17. **Photo Journal** — Save the verified photos as a log.
18. **Gamification** — Badges/achievements for milestones (7-day, 30-day, 100-day).
19. **Export Data** — CSV export of verification history.

---

## UX Improvement Proposals

### Proposal 1: Add History Tab with Calendar View

Replace the single-screen Home with a lightweight tab approach or add a dedicated History route. The calendar shows a full month grid (already computed by `monthGrid()`) with colored dots. Tapping a day shows details.

**Changes:**

- New `HistoryView` with month navigation
- New `AppRoute.history` case
- Use existing `CalendarAnalytics.monthGridDays()` and `dayStatus()`

### Proposal 2: Add Manual Verification

Add a "Log Manually" button alongside "Verify Now" on HomeView. This creates a record with `VerificationMethod.manual` (new enum case). Quick, one-tap logging for when camera verification isn't practical.

**Changes:**

- Add `.manual` to `VerificationMethod`
- Add "Log Manually" secondary button on HomeView
- Confirmation sheet before logging

### Proposal 3: Track Longest Streak

Persist `longestStreak` in Settings. Update on every new verification. Display on HomeView streak card and WeeklyReportView.

**Changes:**

- Add `longestStreak: Int` to `Settings`
- Update in `markAppliedToday()` when currentStreak > longestStreak
- Show "Personal best: N days" below current streak

### Proposal 4: UV Index Service

Fetch current UV index from a weather API (or use WeatherKit). Display a banner on HomeView when UV is moderate or higher.

**Changes:**

- New `UVIndexService` using CoreLocation + WeatherKit
- UV banner component on HomeView
- Contextual messaging ("UV is high — don't forget sunscreen!")

### Proposal 5: Reapplication Reminders

After a successful verification, offer to set a 2-hour reapplication timer. Uses local notifications with a dedicated category.

**Changes:**

- Add `reapplyIntervalMinutes: Int` to Settings (default 120)
- New notification category for reapplication
- Toggle in Settings
- Timer starts after verification success

### Proposal 6: Simplify Home Screen

The current Home has: greeting, today card, streak card, verify button. With new features, it risks becoming cluttered. Proposed simplification:

- Combine today status INTO the streak card (one unified "status card")
- Move weekly summary access to a History route
- Keep "Verify Now" prominent at bottom
- Add UV banner at top when relevant
