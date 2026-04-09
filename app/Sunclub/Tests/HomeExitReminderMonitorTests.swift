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
    func testFirstHomeExitSchedulesImmediateReminderAndCancelsTodayFallback() async throws {
        let calendar = Calendar.current
        let now = Date()
        let notificationManager = MockNotificationManager()
        let locationService = FakeLocationService()
        let stateStore = FakeHomeExitReminderStateStore()
        let monitor = HomeExitReminderMonitor(
            locationService: locationService,
            notificationManager: notificationManager,
            stateStore: stateStore,
            calendar: calendar
        )
        let state = try makeAppState(notificationManager: notificationManager)
        configureLeaveHomeReminder(
            on: state,
            enabled: true,
            reminderTime: futureReminderTime(from: now, calendar: calendar)
        )
        monitor.setStateProvider { state }
        stateStore.markObservedInside(on: now, calendar: calendar)

        locationService.simulateExit()
        await Task.yield()

        XCTAssertEqual(notificationManager.scheduleLeaveHomeReminderLevels.count, 1)
        XCTAssertEqual(notificationManager.scheduleLeaveHomeReminderRoutes, [.manualLog])
        XCTAssertEqual(notificationManager.cancelDailyReminderDays.count, 1)
        XCTAssertTrue(stateStore.hasFired(on: now, calendar: calendar))
    }

    func testExitDoesNotFireWhenUserWasAlreadyAway() async throws {
        let calendar = Calendar.current
        let notificationManager = MockNotificationManager()
        let locationService = FakeLocationService()
        let stateStore = FakeHomeExitReminderStateStore()
        let monitor = HomeExitReminderMonitor(
            locationService: locationService,
            notificationManager: notificationManager,
            stateStore: stateStore,
            calendar: calendar
        )
        let state = try makeAppState(notificationManager: notificationManager)
        configureLeaveHomeReminder(
            on: state,
            enabled: true,
            reminderTime: futureReminderTime(from: Date(), calendar: calendar)
        )
        monitor.setStateProvider { state }

        locationService.simulateExit()
        await Task.yield()

        XCTAssertTrue(notificationManager.scheduleLeaveHomeReminderLevels.isEmpty)
        XCTAssertTrue(notificationManager.cancelDailyReminderDays.isEmpty)
        XCTAssertFalse(stateStore.hasFired(on: Date(), calendar: calendar))
    }

    func testExitDoesNotFireAfterDailyReminderCutoff() async throws {
        let calendar = Calendar.current
        let notificationManager = MockNotificationManager()
        let locationService = FakeLocationService()
        let stateStore = FakeHomeExitReminderStateStore()
        let monitor = HomeExitReminderMonitor(
            locationService: locationService,
            notificationManager: notificationManager,
            stateStore: stateStore,
            calendar: calendar
        )
        let state = try makeAppState(notificationManager: notificationManager)
        configureLeaveHomeReminder(
            on: state,
            enabled: true,
            reminderTime: pastReminderTime(from: Date(), calendar: calendar)
        )
        monitor.setStateProvider { state }
        stateStore.markObservedInside(on: Date(), calendar: calendar)

        locationService.simulateExit()
        await Task.yield()

        XCTAssertTrue(notificationManager.scheduleLeaveHomeReminderLevels.isEmpty)
        XCTAssertTrue(notificationManager.cancelDailyReminderDays.isEmpty)
    }

    private func makeAppState(notificationManager: NotificationScheduling) throws -> AppState {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        return AppState(
            context: ModelContext(container),
            notificationManager: notificationManager,
            homeExitReminderMonitor: NoopHomeExitReminderMonitor()
        )
    }

    private func configureLeaveHomeReminder(
        on state: AppState,
        enabled: Bool,
        reminderTime: Date
    ) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        var reminderSettings = state.settings.smartReminderSettings
        reminderSettings.weekdayTime = ReminderTime(hour: components.hour ?? 8, minute: components.minute ?? 0)
        reminderSettings.weekendTime = ReminderTime(hour: components.hour ?? 8, minute: components.minute ?? 0)
        reminderSettings.leaveHomeReminder = LeaveHomeReminderSettings(
            isEnabled: enabled,
            homeLocation: HomeLocation(latitude: 34.116, longitude: -118.150),
            radiusMeters: 150
        )
        state.settings.smartReminderSettings = reminderSettings
        state.save()
    }

    private func futureReminderTime(from date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let currentHour = components.hour ?? 12
        let currentMinute = components.minute ?? 0

        let targetHour: Int
        let targetMinute: Int
        if currentMinute <= 48 {
            targetHour = currentHour
            targetMinute = currentMinute + 10
        } else if currentHour < 23 {
            targetHour = currentHour + 1
            targetMinute = 0
        } else {
            targetHour = 23
            targetMinute = 59
        }

        return calendar.date(bySettingHour: targetHour, minute: targetMinute, second: 0, of: date) ?? date
    }

    private func pastReminderTime(from date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let currentHour = components.hour ?? 12
        let currentMinute = components.minute ?? 0

        let targetHour: Int
        let targetMinute: Int
        if currentMinute >= 10 {
            targetHour = currentHour
            targetMinute = currentMinute - 10
        } else if currentHour > 0 {
            targetHour = currentHour - 1
            targetMinute = 50
        } else {
            targetHour = 0
            targetMinute = 0
        }

        return calendar.date(bySettingHour: targetHour, minute: targetMinute, second: 0, of: date) ?? date
    }
}
