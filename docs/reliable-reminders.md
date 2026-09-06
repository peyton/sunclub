# Reliable reminders and check-ins

## Approved behavior

- Reconcile reminders automatically without removing valid requests before replacement succeeds. Preserve future daily reminders after today's log. Dated daily requests cover a rolling 28-day horizon, replenished when Sunclub runs; background opportunities are scheduled but controlled by iOS.
- Opted-in first home exits from 06:00 through 19:59 create one unconfirmed check-in per day. An initial outside observation is not an exit.
- Today, History and compact surfaces distinguish unconfirmed check-ins from sunscreen applications. Confirm with an actual application time, snooze 15 minutes, or dismiss.
- Persist check-ins through versioned schema, history, backup, sync and recovery. Never count unconfirmed events as applications or streaks.
- Live Activities have an independent default-on preference, share committed session state, preserve snooze and respect dismissal and OS execution constraints.
- Preserve existing visual language, automation entrypoint authorization, targets, identifiers and recovery behavior.

## Verification

Regression tests cover failed/overlapping scheduling, recurrence, overnight exits, duplicate callbacks, committed actions, migrations, restore, compact surfaces and accessibility. Run unit, UI, Python and lint checks plus full exact-SHA CI. Physical-device background notification and ActivityKit verification is a merge gate when simulator evidence cannot establish delivery.

## Device acceptance

With notifications allowed, Home set and leave-home reminders enabled, verify a real inside-to-outside transition while Sunclub is backgrounded, then after process relaunch. Check one accepted departure per day, action delivery, earlier-time confirmation, snooze, dismissal and no duplicate application. Repeat with notifications denied and with Always location unavailable; Settings must describe the missing permission.

Confirm an application from Today, a notification, widget and Watch. Verify the same reapply deadline, reapplication updating the current activity, snooze surviving foreground refresh, system dismissal respected, and midnight clearing active surfaces while History keeps Unconfirmed. Simulator request acceptance does not establish physical delivery.

Live Activities start from the foreground or a supported LiveActivityIntent execution context, following [Apple's ActivityKit execution guidance](https://developer.apple.com/documentation/ActivityKit/displaying-live-data-with-live-activities). Background departures use notifications and widgets as the baseline.
