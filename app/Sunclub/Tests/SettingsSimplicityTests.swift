import Foundation
import XCTest
@testable import Sunclub

@MainActor
final class SettingsSimplicityTests: SunclubTestCase {
    // Catches routing new users through location setup before optional reminders.
    func testWelcomeStartsAtOptionalRemindersWithoutCompletingSetup() throws {
        let state = try isolatedState()
        let router = AppRouter()
        router.open(.welcome)

        WelcomeView.beginOnboarding(router: router)

        XCTAssertEqual(router.path, [.enableNotifications])
        XCTAssertFalse(state.settings.hasCompletedOnboarding)
        XCTAssertFalse(state.settings.usesLiveUV)
        XCTAssertNil(state.settings.selectedUVPlace)
    }

    func testFinishingOnboardingReturnsToToday() throws {
        let state = try isolatedState()
        XCTAssertTrue(state.completeOnboarding().succeeded)
        let router = AppRouter()
        router.open(.enableNotifications)

        EnableNotificationsView.finishOnboarding(appState: state, router: router)

        XCTAssertTrue(router.path.isEmpty)
        XCTAssertEqual(router.selectedTab, .today)
        XCTAssertTrue(state.settings.hasCompletedOnboarding)
    }

    // Catches using the first daily log when a newer reapplication exists.
    func testLastLoggedUsesMostRecentApplication() {
        let first = Date(timeIntervalSince1970: 1_788_537_600)
        let latest = first.addingTimeInterval(2 * 60 * 60)
        let record = DailyRecord(
            startOfDay: Calendar.current.startOfDay(for: first),
            verifiedAt: first,
            method: .manual,
            reapplyCount: 1,
            lastReappliedAt: latest
        )

        XCTAssertEqual(ReapplyCheckInView.lastLoggedAt(for: record), latest)
    }

    // An edited first log can be newer than a previously saved reapplication.
    func testLastLoggedDoesNotMoveBackwardForOlderReapplication() {
        let latest = Date(timeIntervalSince1970: 1_788_544_800)
        let record = DailyRecord(
            startOfDay: Calendar.current.startOfDay(for: latest),
            verifiedAt: latest,
            method: .manual,
            reapplyCount: 1,
            lastReappliedAt: latest.addingTimeInterval(-60 * 60)
        )

        XCTAssertEqual(ReapplyCheckInView.lastLoggedAt(for: record), latest)
    }

    // Catches making sample writes executable in the catalog, including callbacks.
    func testWriteExamplesNeverOfferExecutableURL() {
        for path in [
            "automation/log-today?spf=50",
            "automation/save-log?date=2026-04-13&time=08:30&part=morning&spf=50",
            "automation/reapply",
            "automation/set-reminder?kind=weekday&time=08:30",
            "automation/set-reapply?enabled=true&interval=90",
            "automation/set-toggle?name=dailyUVBriefing&enabled=true",
            "x-callback-url/log-today?spf=50&x-success=shortcuts://callback"
        ] {
            let example = AutomationExample(
                id: "write", title: "Sample", detail: "", urlString: "sunclub://\(path)"
            )

            XCTAssertNil(example.testURL, path)
        }
    }

    // Read and navigation examples retain their real public URL behavior.
    func testReadAndOpenExamplesRetainExecutableURL() throws {
        for path in [
            "automation/status",
            "automation/time-since-last-application",
            "automation/open?route=settings",
            "x-callback-url/status?x-success=shortcuts://callback"
        ] {
            let url = try XCTUnwrap(URL(string: "sunclub://\(path)"))
            let example = AutomationExample(id: "read", title: "Sample", detail: "", urlString: url.absoluteString)

            XCTAssertEqual(example.testURL, url)
        }
    }

    private func isolatedState() throws -> AppState {
        let suite = "SettingsSimplicityTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return try makeAppState(
            notificationManager: MockNotificationManager(),
            cloudSyncCoordinator: ProbeCloudSyncCoordinator(),
            growthFeatureStore: SunclubGrowthFeatureStore(userDefaults: defaults),
            runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: true,
                isPreviewing: false,
                hasAppGroupContainer: false
            )
        )
    }
}
