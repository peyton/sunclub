import Foundation
import XCTest
@testable import Sunclub

@MainActor
final class AutomationSettingsRouteTests: SunclubTestCase {
    // Catches missing direct/callback routes or routing a detail to general Settings.
    func testSettingsDetailURLsParseAndKeepTheirDestinationWhenEncoded() throws {
        for (name, destination): (String, AppRoute) in [
            ("settings-sunscreen", .settingsSunscreen),
            ("settings-health", .settingsHealth)
        ] {
            for scheme in ["sunclub", "sunclub-dev"] {
                for host in ["automation", "x-callback-url"] {
                    let url = try XCTUnwrap(URL(string: "\(scheme)://\(host)/open?route=\(name)"))
                    let link = try XCTUnwrap(SunclubDeepLink(url: url))
                    guard case let .automation(request) = link,
                          case let .open(route) = request.action else {
                        return XCTFail("Expected foreground open for \(url)")
                    }

                    XCTAssertEqual(route.appRoute, destination)
                    XCTAssertFalse(request.action.isWriteAction)
                    let encoded = try XCTUnwrap(URLComponents(url: request.url, resolvingAgainstBaseURL: false))
                    XCTAssertEqual(encoded.host, host)
                    XCTAssertEqual(encoded.queryItems?.first(where: { $0.name == "route" })?.value, name)
                }
            }
        }
    }

    // Catches intent choices missing from either conversion direction.
    func testOpenIntentRetainsSpecificSettingsDestination() throws {
        for (name, publicName, destination): (String, String, AppRoute) in [
            ("settingsSunscreen", "settings-sunscreen", .settingsSunscreen),
            ("settingsHealth", "settings-health", .settingsHealth)
        ] {
            let choice = try XCTUnwrap(SunclubAutomationRouteIntentValue(rawValue: name))
            let route = try XCTUnwrap(SunclubAutomationRoute(rawValue: publicName))

            XCTAssertEqual(choice.route.appRoute, destination)
            XCTAssertEqual(SunclubAutomationRouteIntentValue(route: route), choice)
            XCTAssertEqual(OpenSunclubRouteIntent(route: route).route.route.appRoute, destination)
        }
    }

    // Read-only setup routes must remain usable when outside writes are disabled.
    func testSettingsURLsOpenDetailsWithWritesDisabledWithoutChangingData() throws {
        let state = try isolatedState()
        XCTAssertTrue(state.completeOnboarding().succeeded)
        var preferences = state.automationPreferences
        preferences.urlWriteActionsEnabled = false
        preferences.shortcutWritesEnabled = false
        state.updateAutomationPreferences(preferences)
        let router = AppRouter()

        for (name, destination): (String, AppRoute) in [
            ("settings-sunscreen", .settingsSunscreen),
            ("settings-health", .settingsHealth)
        ] {
            let url = try XCTUnwrap(URL(string: "sunclub://automation/open?route=\(name)"))

            XCTAssertTrue(SunclubDeepLinkHandler.handle(url: url, appState: state, router: router))
            XCTAssertEqual(router.selectedTab, .settings)
            XCTAssertEqual(router.path, [destination])
            XCTAssertTrue(state.records.isEmpty)
            XCTAssertNil(state.settings.sunscreenProfile)
            XCTAssertFalse(state.growthSettings.healthKit.isEnabled)
            XCTAssertEqual(state.automationPreferences, preferences)
        }
    }

    // Adding a destination must not bypass the existing URL-open permission gate.
    func testSettingsDetailURLsRespectOpenPermission() throws {
        let state = try isolatedState()
        XCTAssertTrue(state.completeOnboarding().succeeded)
        var preferences = state.automationPreferences
        preferences.urlOpenActionsEnabled = false
        state.updateAutomationPreferences(preferences)
        let router = AppRouter()

        for name in ["settings-sunscreen", "settings-health"] {
            let url = try XCTUnwrap(URL(string: "sunclub://automation/open?route=\(name)"))

            XCTAssertTrue(SunclubDeepLinkHandler.handle(url: url, appState: state, router: router))
            XCTAssertEqual(router.path, [.automation])
            XCTAssertTrue(state.records.isEmpty)
            XCTAssertEqual(state.automationPreferences, preferences)
        }
    }

    // Preserve public compatibility destinations while removing their old UI requirements.
    func testLegacyAutomationDestinationsRemainAccepted() throws {
        for (name, destination): (String, AppRoute) in [
            ("summary", .weeklySummary),
            ("achievements", .weeklySummary),
            ("friends", .settings),
            ("health-report", .history),
            ("product-scanner", .manualLog)
        ] {
            let url = try XCTUnwrap(URL(string: "sunclub://automation/open?route=\(name)"))
            guard case let .automation(request) = SunclubDeepLink(url: url),
                  case let .open(route) = request.action else {
                return XCTFail("Lost compatibility route \(name)")
            }
            XCTAssertEqual(route.appRoute, destination)
        }
    }

    private func isolatedState() throws -> AppState {
        let suite = "AutomationSettingsRouteTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return try makeAppState(
            notificationManager: MockNotificationManager(),
            cloudSyncCoordinator: ProbeCloudSyncCoordinator(),
            growthFeatureStore: SunclubGrowthFeatureStore(userDefaults: defaults),
            runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: true,
                isPreviewing: false,
                hasAppGroupContainer: false,
                isPublicAccountabilityTransportEnabled: false
            )
        )
    }
}
