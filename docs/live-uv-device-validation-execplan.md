# Live UV Device Validation ExecPlan

This ExecPlan tracks the live UV audit and device-readiness work.

## Purpose / Big Picture

Sunclub already has a live UV toggle and a WeatherKit entitlement, but the live path is not reliably validated. This change makes the WeatherKit and location seams injectable, keeps heuristic fallback safe, and adds tests that prove the end-to-end app state and UI behavior without depending on Apple services during CI.

## Progress

- [x] (2026-04-11) Audited the current live UV service, forecast service, settings UI, entitlements, and test seams.
- [x] (2026-04-11) Refactored live UV fetching so WeatherKit is behind a mockable provider used by both current UV and forecast code.
- [x] (2026-04-11) Added deterministic unit and AppState integration coverage for live success, permission, unavailable, and fallback cases.
- [x] (2026-04-11) Added UI-test launch fixtures that exercise the live UV settings flow without real device permission prompts.
- [x] (2026-04-11) Added metadata tests that guard the app WeatherKit entitlement and location usage copy.
- [x] (2026-04-11) Regenerated the workspace and ran the relevant repo validation commands.

## Decision Log

- Decision: Keep WeatherKit as an optional live source layered behind the existing heuristic UV estimate.
  Rationale: Live UV cannot become a hard dependency because permission denial, missing provisioning, no location, and WeatherKit outages must not blank the Home card.
  Date/Author: 2026-04-11 / Codex
- Decision: Add app-only WeatherKit entitlement validation instead of adding WeatherKit to extensions.
  Rationale: The app target is the only target that calls WeatherKit. Adding unused capabilities to widgets or watch extensions would increase provisioning burden without improving runtime behavior.
  Date/Author: 2026-04-11 / Codex

## Context and Orientation

The current UV reading service lives in `app/Sunclub/Sources/Services/UVIndexService.swift`. The forecast service lives in `app/Sunclub/Sources/Services/SunclubUVBriefingService.swift`. Settings UI calls `AppState.updateLiveUVPreference` from `app/Sunclub/Sources/Views/SettingsView.swift`. UI-test launch wiring lives in `app/Sunclub/Sources/SunclubApp.swift`.

## Plan of Work

1. Introduce a `LiveUVWeatherProviding` abstraction and a WeatherKit-backed implementation.
2. Inject the provider into `UVIndexService` and `SunclubUVBriefingService`.
3. Fall back to heuristic forecasts when WeatherKit fails or returns no usable forecast hours.
4. Add debug-only UI-test fake location and live UV weather providers.
5. Add focused unit and integration tests for service and AppState behavior.
6. Add a UI test that toggles live UV with mocked live WeatherKit data and verifies the Settings and Home surfaces.
7. Add Python metadata tests for the checked-in entitlement and location copy.

## Validation and Acceptance

1. A live provider success produces a WeatherKit-sourced current reading and live forecast in AppState.
2. Permission denial, missing permission, provider errors, or empty live forecast results fall back to heuristic UV without crashing or blanking UI.
3. UI tests can validate the live UV toggle and Home UV presentation without relying on real WeatherKit or Core Location prompts.
4. The checked-in app entitlement declares `com.apple.developer.weatherkit = true`, and the app Info.plist explains live UV location use.

## Outcomes & Retrospective

Implemented. Live UV now has one injectable WeatherKit provider shared by current readings and hourly forecasts. Tests cover WeatherKit success, location denial/missing live permission fallback, provider failure fallback, empty forecast fallback, and AppState end-to-end refresh. The UI integration test drives Settings live UV enablement and verifies the Home UV headline/detail using debug-only mocked live providers.

Validation run:

- `just generate`: passed.
- `just test-unit`: passed, 150 tests.
- `just test-python`: passed, 54 tests.
- `just lint`: passed with existing SwiftLint warnings only.
- Targeted UI integration: `SunclubUITests/SunclubUITests/testSettingsLiveUVToggleUsesMockedLiveWeatherDataEndToEnd` passed.

The full `just test-ui` suite initially hit simulator launch failures on Xcode 26.5 beta (`Mach error -308`, then an xctrunner lookup failure) after the live UV UI test had already passed in the suite. Deleting/recreating the dedicated test simulator made targeted UI and unit validation pass. This appears to be simulator infrastructure instability, not a live UV assertion failure.
