# Store startup recovery

TestFlight 2.0.19 (20260906.96.1) reported a background-launch SIGTRAP on
2026-09-06 at `SunclubApp.swift:28`. The shipped initializer called `fatalError`
whenever the shared ModelContainer could not open. The report does not contain
the underlying SwiftData error; protected data during a locked-device launch is
a possible trigger, not a confirmed diagnosis.

Startup first attempts to open the existing store, including while locked. If
opening throws, startup retries silently on unlock and foreground activation,
and with capped exponential backoff while foregrounded. There is no recovery
screen, retry button, empty replacement store or reset. Services and normal
screens are created only after the store opens. Incoming URLs wait for successful
startup and use the existing authorization handler. Store paths, schemas,
migrations and CloudKit configuration are unchanged.

Existing automation routes remain available after recovery. Opening errors are
recorded in the private Startup system log. Background failures do not create or
publish an empty app state.

Regression coverage includes readable locked stores, unavailable protected data,
unlock notification without a scene, automatic retries and cancellation, retry
with a prior shipped store, initialization only once, and silent foreground
recovery. Physical-device locked/background launch on iOS 27 remains a useful
acceptance check because Simulator cannot reproduce file protection.
