import Foundation
import XCTest
@testable import Sunclub

final class ReminderPlannerTests: XCTestCase {
    func testSmartReminderSettingsDecodesLegacyPayloadWithLeaveHomeReminderDisabled() throws {
        struct LegacySmartReminderSettings: Codable {
            let weekdayTime: ReminderTime
            let weekendTime: ReminderTime
            let followsTravelTimeZone: Bool
            let anchoredTimeZoneIdentifier: String
            let streakRiskEnabled: Bool
        }

        let payload = LegacySmartReminderSettings(
            weekdayTime: ReminderTime(hour: 8, minute: 0),
            weekendTime: ReminderTime(hour: 9, minute: 30),
            followsTravelTimeZone: false,
            anchoredTimeZoneIdentifier: "America/Los_Angeles",
            streakRiskEnabled: true
        )

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(SmartReminderSettings.self, from: data)

        XCTAssertFalse(decoded.leaveHomeReminder.isEnabled)
        XCTAssertNil(decoded.leaveHomeReminder.homeLocation)
        XCTAssertEqual(decoded.leaveHomeReminder.radiusMeters, LeaveHomeReminderSettings.defaultRadiusMeters)
    }

    func testScheduleKindUsesWeekendForSaturdayAndSunday() {
        let calendar = makeCalendar()
        let saturday = makeDate(year: 2026, month: 4, day: 4, hour: 9, minute: 0, calendar: calendar)
        let sunday = makeDate(year: 2026, month: 4, day: 5, hour: 9, minute: 0, calendar: calendar)
        let monday = makeDate(year: 2026, month: 4, day: 6, hour: 9, minute: 0, calendar: calendar)

        XCTAssertEqual(ReminderPlanner.scheduleKind(for: saturday, calendar: calendar), .weekend)
        XCTAssertEqual(ReminderPlanner.scheduleKind(for: sunday, calendar: calendar), .weekend)
        XCTAssertEqual(ReminderPlanner.scheduleKind(for: monday, calendar: calendar), .weekday)
    }

    func testStreakRiskPlanTargetsTodayWhenTodayIsStillOpen() {
        let calendar = makeCalendar()
        let settings = SmartReminderSettings(
            weekdayTime: ReminderTime(hour: 8, minute: 0),
            weekendTime: ReminderTime(hour: 10, minute: 30),
            followsTravelTimeZone: false,
            anchoredTimeZoneIdentifier: calendar.timeZone.identifier,
            streakRiskEnabled: true
        )
        let now = makeDate(year: 2026, month: 4, day: 2, hour: 9, minute: 0, calendar: calendar)
        let yesterday = makeDate(year: 2026, month: 4, day: 1, hour: 8, minute: 0, calendar: calendar)

        let plan = ReminderPlanner.streakRiskPlan(
            records: [yesterday],
            now: now,
            settings: settings,
            calendar: calendar,
            currentTimeZone: calendar.timeZone
        )

        XCTAssertEqual(plan?.targetDay, calendar.startOfDay(for: now))
        XCTAssertEqual(
            plan?.fireDate,
            makeDate(year: 2026, month: 4, day: 2, hour: 17, minute: 0, calendar: calendar)
        )
        XCTAssertEqual(plan?.streakCount, 1)
    }

    func testStreakRiskPlanTargetsTomorrowAfterTodayLogged() {
        let calendar = makeCalendar()
        let settings = SmartReminderSettings(
            weekdayTime: ReminderTime(hour: 8, minute: 0),
            weekendTime: ReminderTime(hour: 10, minute: 30),
            followsTravelTimeZone: false,
            anchoredTimeZoneIdentifier: calendar.timeZone.identifier,
            streakRiskEnabled: true
        )
        let now = makeDate(year: 2026, month: 4, day: 3, hour: 9, minute: 0, calendar: calendar)
        let yesterday = makeDate(year: 2026, month: 4, day: 2, hour: 8, minute: 0, calendar: calendar)
        let today = makeDate(year: 2026, month: 4, day: 3, hour: 8, minute: 0, calendar: calendar)

        let plan = ReminderPlanner.streakRiskPlan(
            records: [yesterday, today],
            now: now,
            settings: settings,
            calendar: calendar,
            currentTimeZone: calendar.timeZone
        )

        XCTAssertEqual(
            plan?.targetDay,
            makeDate(year: 2026, month: 4, day: 4, hour: 0, minute: 0, calendar: calendar)
        )
        XCTAssertEqual(
            plan?.fireDate,
            makeDate(year: 2026, month: 4, day: 4, hour: 18, minute: 30, calendar: calendar)
        )
        XCTAssertEqual(plan?.streakCount, 2)
    }

    func testStreakRiskPlanReturnsNilWhenFeatureIsDisabled() {
        let calendar = makeCalendar()
        let settings = SmartReminderSettings(
            weekdayTime: ReminderTime(hour: 8, minute: 0),
            weekendTime: ReminderTime(hour: 10, minute: 30),
            followsTravelTimeZone: false,
            anchoredTimeZoneIdentifier: calendar.timeZone.identifier,
            streakRiskEnabled: false
        )
        let now = makeDate(year: 2026, month: 4, day: 2, hour: 9, minute: 0, calendar: calendar)
        let yesterday = makeDate(year: 2026, month: 4, day: 1, hour: 8, minute: 0, calendar: calendar)

        let plan = ReminderPlanner.streakRiskPlan(
            records: [yesterday],
            now: now,
            settings: settings,
            calendar: calendar,
            currentTimeZone: calendar.timeZone
        )

        XCTAssertNil(plan)
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }
}
