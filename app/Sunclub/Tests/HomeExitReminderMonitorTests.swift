import CoreLocation
import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class FakeLocationService: SharedLocationManaging {
    var authorizationStatus: CLAuthorizationStatus = .authorizedAlways
    var eventHandler: ((SharedLocationEvent) -> Void)?
    var currentLocationResult: Result<CLLocation, Error> = .success(
        CLLocation(latitude: 34.116, longitude: -118.150)
    )
    private var monitoredRegionStorage: CLCircularRegion?

    func requestWhenInUseAuthorizationIfNeeded() async -> CLAuthorizationStatus {
        authorizationStatus
    }

    func requestAlwaysAuthorizationIfNeeded() async -> CLAuthorizationStatus {
        authorizationStatus
    }

    func currentLocation() async throws -> CLLocation {
        try currentLocationResult.get()
    }

    func monitoredRegion(withIdentifier identifier: String) -> CLCircularRegion? {
        guard monitoredRegionStorage?.identifier == identifier else {
            return nil
        }
        return monitoredRegionStorage
    }

    func startMonitoring(region: CLCircularRegion) {
        monitoredRegionStorage = region
    }

    func stopMonitoring(regionIdentifier: String) {
        if monitoredRegionStorage?.identifier == regionIdentifier {
            monitoredRegionStorage = nil
        }
    }

    func requestState(for region: CLRegion) {}

    func simulateExit(identifier: String = HomeExitReminderMonitor.regionIdentifier) {
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: 34.116, longitude: -118.150),
            radius: 150,
            identifier: identifier
        )
        eventHandler?(.didExitRegion(region))
    }
}

@MainActor
final class FakeHomeExitReminderStateStore: HomeExitReminderStateStoring {
    var observedInsideDay: String?
    var firedDay: String?

    func hasObservedInside(on date: Date, calendar: Calendar) -> Bool {
        observedInsideDay == dayStamp(for: date, calendar: calendar)
    }

    func markObservedInside(on date: Date, calendar: Calendar) {
        observedInsideDay = dayStamp(for: date, calendar: calendar)
    }

    func clearObservedInsideDay() {
        observedInsideDay = nil
    }

    func hasFired(on date: Date, calendar: Calendar) -> Bool {
        firedDay == dayStamp(for: date, calendar: calendar)
    }

    func markFired(on date: Date, calendar: Calendar) {
        firedDay = dayStamp(for: date, calendar: calendar)
    }

    private func dayStamp(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

@MainActor
final class HomeExitReminderMonitorTests: XCTestCase {
    func testFirstHomeExitSchedulesImmediateReminderWithoutRemovingRepeatingFallback() async throws {
        let calendar = Calendar.current
        let now = try referenceTime(in: calendar)
        let notificationManager = MockNotificationManager()
        let locationService = FakeLocationService()
        let stateStore = FakeHomeExitReminderStateStore()
        let monitor = HomeExitReminderMonitor(
            locationService: locationService,
            notificationManager: notificationManager,
            stateStore: stateStore,
            calendar: calendar, clock: { now }
        )
        let state = try makeAppState(notificationManager: notificationManager, now: now)
        try configureLeaveHomeReminder(
            on: state,
            enabled: true,
            reminderTime: now.addingTimeInterval(600)
        )
        monitor.setStateProvider { state }
        stateStore.markObservedInside(on: now, calendar: calendar)

        locationService.simulateExit()
        await Task.yield()

        XCTAssertEqual(notificationManager.scheduleLeaveHomeReminderLevels, [.unknown])
        XCTAssertEqual(notificationManager.scheduleLeaveHomeReminderRoutes, [.departureCheckIn])
        XCTAssertTrue(notificationManager.cancelDailyReminderDays.isEmpty)
        XCTAssertTrue(stateStore.hasFired(on: now, calendar: calendar))
    }

    func testFailedHomeExitScheduleRemainsEligibleForRetry() async throws {
        let calendar = Calendar.current
        let now = try referenceTime(in: calendar)
        let notificationManager = MockNotificationManager()
        notificationManager.notificationOperationResult = .failure("Queue unavailable.")
        let locationService = FakeLocationService()
        let stateStore = FakeHomeExitReminderStateStore()
        let monitor = HomeExitReminderMonitor(
            locationService: locationService,
            notificationManager: notificationManager,
            stateStore: stateStore,
            calendar: calendar, clock: { now }
        )
        let state = try makeAppState(notificationManager: notificationManager, now: now)
        try configureLeaveHomeReminder(
            on: state,
            enabled: true,
            reminderTime: now.addingTimeInterval(600)
        )
        monitor.setStateProvider { state }
        stateStore.markObservedInside(on: now, calendar: calendar)

        locationService.simulateExit()
        await Task.yield()

        XCTAssertEqual(notificationManager.scheduleLeaveHomeReminderLevels, [.unknown])
        XCTAssertFalse(stateStore.hasFired(on: now, calendar: calendar))
    }

    func testExitDoesNotFireWhenUserWasAlreadyAway() async throws {
        let calendar = Calendar.current
        let now = try referenceTime(in: calendar)
        let notificationManager = MockNotificationManager()
        let locationService = FakeLocationService()
        let stateStore = FakeHomeExitReminderStateStore()
        let monitor = HomeExitReminderMonitor(
            locationService: locationService,
            notificationManager: notificationManager,
            stateStore: stateStore,
            calendar: calendar, clock: { now }
        )
        let state = try makeAppState(notificationManager: notificationManager, now: now)
        try configureLeaveHomeReminder(
            on: state,
            enabled: true,
            reminderTime: now.addingTimeInterval(600)
        )
        monitor.setStateProvider { state }

        locationService.simulateExit()
        await Task.yield()

        XCTAssertTrue(notificationManager.scheduleLeaveHomeReminderLevels.isEmpty)
        XCTAssertTrue(notificationManager.cancelDailyReminderDays.isEmpty)
        XCTAssertFalse(stateStore.hasFired(on: now, calendar: calendar))
    }

    func testExitStillFiresAfterDailyReminderTime() async throws {
        let calendar = Calendar.current
        let now = try referenceTime(in: calendar)
        let notificationManager = MockNotificationManager()
        let locationService = FakeLocationService()
        let stateStore = FakeHomeExitReminderStateStore()
        let monitor = HomeExitReminderMonitor(
            locationService: locationService,
            notificationManager: notificationManager,
            stateStore: stateStore,
            calendar: calendar, clock: { now }
        )
        let state = try makeAppState(notificationManager: notificationManager, now: now)
        try configureLeaveHomeReminder(
            on: state,
            enabled: true,
            reminderTime: now.addingTimeInterval(-600)
        )
        monitor.setStateProvider { state }
        stateStore.markObservedInside(on: now, calendar: calendar)

        locationService.simulateExit()
        await Task.yield()

        XCTAssertEqual(notificationManager.scheduleLeaveHomeReminderLevels, [.unknown])
        XCTAssertTrue(notificationManager.cancelDailyReminderDays.isEmpty)
    }

    func testInsideObservationSurvivesMidnightUntilExit() throws {
        let calendar = Calendar.current
        let now = try referenceTime(in: calendar)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let store = HomeExitReminderStateStore(defaults: defaults)
        store.markObservedInside(on: now.addingTimeInterval(-86400), calendar: calendar)
        XCTAssertTrue(store.hasObservedInside(on: now, calendar: calendar))
        store.clearObservedInsideDay()
        XCTAssertFalse(store.hasObservedInside(on: now, calendar: calendar))
    }

    func testOutOfHoursExitConsumesOccupancyWithoutCreatingHistory() async throws {
        let calendar = Calendar.current
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 4, hour: 5)))
        let notifications = MockNotificationManager()
        let location = FakeLocationService()
        let store = FakeHomeExitReminderStateStore()
        let state = try makeAppState(notificationManager: notifications, now: now)
        try configureLeaveHomeReminder(on: state, enabled: true, reminderTime: now.addingTimeInterval(3600))
        let monitor = HomeExitReminderMonitor(locationService: location, notificationManager: notifications,
            stateStore: store, calendar: calendar, clock: { now })
        monitor.setStateProvider { state }
        store.markObservedInside(on: now, calendar: calendar)
        location.simulateExit()
        await Task.yield()
        XCTAssertFalse(store.hasObservedInside(on: now, calendar: calendar))
        XCTAssertTrue(state.departureCheckIns.isEmpty)
        XCTAssertTrue(notifications.scheduleLeaveHomeReminderLevels.isEmpty)
    }

    func testFailedDeliveryRetriesFromDurableCheckInWithoutAnotherExit() async throws {
        let calendar = Calendar.current
        let now = try referenceTime(in: calendar)
        let notifications = MockNotificationManager()
        notifications.notificationOperationResult = .failure("Unavailable")
        let location = FakeLocationService()
        let store = FakeHomeExitReminderStateStore()
        let state = try makeAppState(notificationManager: notifications, now: now)
        try configureLeaveHomeReminder(on: state, enabled: true, reminderTime: now)
        let monitor = HomeExitReminderMonitor(locationService: location, notificationManager: notifications,
            stateStore: store, calendar: calendar, clock: { now })
        monitor.setStateProvider { state }
        store.markObservedInside(on: now, calendar: calendar)
        location.simulateExit()
        await Task.yield()
        XCTAssertEqual(state.departureCheckIns.count, 1)
        notifications.notificationOperationResult = .success("Accepted")
        _ = await monitor.refreshMonitoring(using: state, allowPermissionPrompt: false)
        XCTAssertTrue(store.hasFired(on: now, calendar: calendar))
        XCTAssertEqual(state.departureCheckIns.count, 1)
        XCTAssertEqual(notifications.scheduleLeaveHomeReminderLevels.count, 2)
    }

    private func makeAppState(notificationManager: NotificationScheduling, now: Date) throws -> AppState {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        return AppState(
            context: ModelContext(container),
            notificationManager: notificationManager,
            uvIndexService: UVIndexService(),
            homeExitReminderMonitor: NoopHomeExitReminderMonitor(),
            clock: { now }
        )
    }

    private func configureLeaveHomeReminder(
        on state: AppState,
        enabled: Bool,
        reminderTime: Date
    ) throws {
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        var reminderSettings = state.settings.smartReminderSettings
        reminderSettings.weekdayTime = ReminderTime(hour: components.hour ?? 8, minute: components.minute ?? 0)
        reminderSettings.weekendTime = ReminderTime(hour: components.hour ?? 8, minute: components.minute ?? 0)
        reminderSettings.leaveHomeReminder = LeaveHomeReminderSettings(
            isEnabled: enabled,
            homeLocation: HomeLocation(latitude: 34.116, longitude: -118.150),
            radiusMeters: 150
        )
        let history = SunclubHistoryService(context: state.modelContext)
        let data = try JSONEncoder().encode(reminderSettings)
        _ = try history.applySettingsChange(kind: .reminderSettings, summary: "Configure test reminders",
            changedFields: [.smartReminderSettingsData]) { snapshot in
            snapshot.smartReminderSettingsData = data
        }
        state.refresh()
    }

    private func referenceTime(in calendar: Calendar) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 4, hour: 12)))
    }
}
