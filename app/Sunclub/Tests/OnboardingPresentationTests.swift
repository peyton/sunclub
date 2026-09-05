import XCTest
@testable import Sunclub

final class OnboardingPresentationTests: XCTestCase {
    func testNewSetupRemainsPresentedAcrossSavedCompletionAndRetry() {
        let router = AppRouter()
        router.open(.enableNotifications)

        let firstAttempt = router.beginOnboardingCompletion(hasCompletedOnboarding: false)

        XCTAssertTrue(router.retainsOnboarding)
        XCTAssertTrue(router.isCurrentOnboardingCompletion(firstAttempt))

        let retry = router.beginOnboardingCompletion(hasCompletedOnboarding: true)

        XCTAssertTrue(router.retainsOnboarding, "Retry must not discard the saved setup's failure presentation.")
        XCTAssertFalse(router.isCurrentOnboardingCompletion(firstAttempt))
        XCTAssertTrue(router.isCurrentOnboardingCompletion(retry))
    }

    func testCompletedUserOpeningLegacyPermissionsNeverRetainsOnboardingRoot() {
        let router = AppRouter()
        router.open(.enableNotifications)

        let attempt = router.beginOnboardingCompletion(hasCompletedOnboarding: true)

        XCTAssertFalse(router.retainsOnboarding, "Existing users must stay in the tabbed root while requesting reminders.")
        XCTAssertEqual(router.path, [.enableNotifications])
        XCTAssertTrue(router.isCurrentOnboardingCompletion(attempt))
    }

    func testGoHomeClearsHoldAndInvalidatesPendingCompletion() {
        let router = AppRouter()
        router.open(.enableNotifications)
        let attempt = router.beginOnboardingCompletion(hasCompletedOnboarding: false)

        router.goHome()

        XCTAssertFalse(router.retainsOnboarding)
        XCTAssertFalse(router.isCurrentOnboardingCompletion(attempt))
        XCTAssertEqual(router.selectedTab, .today)
        XCTAssertTrue(router.path.isEmpty)
    }

    func testOpeningAnyRootClearsHoldWithoutRevivingItWhenReturningToToday() {
        for route in [AppRoute.home, .history, .settings] {
            let router = AppRouter()
            router.open(.enableNotifications)
            let attempt = router.beginOnboardingCompletion(hasCompletedOnboarding: false)

            router.open(route)

            XCTAssertFalse(router.retainsOnboarding, route.rawValue)
            XCTAssertFalse(router.isCurrentOnboardingCompletion(attempt), route.rawValue)
            XCTAssertEqual(router.selectedTab, route.rootTab)
            XCTAssertTrue(router.path.isEmpty)
            router.selectTab(.today)
            XCTAssertFalse(router.retainsOnboarding)
            XCTAssertFalse(router.isCurrentOnboardingCompletion(attempt))
        }
    }

    func testLeavingPermissionsInvalidatesLateCompletionEvenAfterReturning() {
        let router = AppRouter()
        router.open(.enableNotifications)
        let attempt = router.beginOnboardingCompletion(hasCompletedOnboarding: false)

        router.push(.uvForecast)

        XCTAssertFalse(router.retainsOnboarding)
        XCTAssertFalse(router.isCurrentOnboardingCompletion(attempt), "Late notification work must not route away from the forecast.")
        XCTAssertEqual(router.path, [.enableNotifications, .uvForecast])
        router.goBack()
        XCTAssertFalse(router.isCurrentOnboardingCompletion(attempt), "Returning must not revive an abandoned attempt.")
    }

    func testNativePopAndTabChangeReleaseTheOnboardingPresentation() {
        let router = AppRouter()
        router.open(.enableNotifications)
        let poppedAttempt = router.beginOnboardingCompletion(hasCompletedOnboarding: false)

        router.setPath([], for: .today)

        XCTAssertFalse(router.retainsOnboarding)
        XCTAssertFalse(router.isCurrentOnboardingCompletion(poppedAttempt))
        router.open(.enableNotifications)
        let switchedAttempt = router.beginOnboardingCompletion(hasCompletedOnboarding: false)
        router.selectTab(.settings)
        router.selectTab(.today)
        XCTAssertFalse(router.retainsOnboarding)
        XCTAssertFalse(router.isCurrentOnboardingCompletion(switchedAttempt))
    }

    func testNewExternalPermissionsPresentationRejectsEarlierAsyncCompletion() {
        let router = AppRouter()
        router.open(.enableNotifications)
        let earlierAttempt = router.beginOnboardingCompletion(hasCompletedOnboarding: false)

        router.open(.enableNotifications)
        let currentAttempt = router.beginOnboardingCompletion(hasCompletedOnboarding: true)

        XCTAssertFalse(router.retainsOnboarding)
        XCTAssertFalse(router.isCurrentOnboardingCompletion(earlierAttempt))
        XCTAssertTrue(router.isCurrentOnboardingCompletion(currentAttempt))
    }
}
