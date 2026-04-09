import Foundation

protocol HomeExitReminderStateStoring: AnyObject {
    func hasObservedInside(on date: Date, calendar: Calendar) -> Bool
    func markObservedInside(on date: Date, calendar: Calendar)
    func clearObservedInsideDay()
    func hasFired(on date: Date, calendar: Calendar) -> Bool
    func markFired(on date: Date, calendar: Calendar)
}

final class HomeExitReminderStateStore: HomeExitReminderStateStoring {
    private enum Key {
        static let observedInsideDay = "sunclub.home-exit.observed-inside-day"
        static let firedDay = "sunclub.home-exit.fired-day"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func hasObservedInside(on date: Date, calendar: Calendar = .current) -> Bool {
        defaults.string(forKey: Key.observedInsideDay) == dayStamp(for: date, calendar: calendar)
    }

    func markObservedInside(on date: Date, calendar: Calendar = .current) {
        defaults.set(dayStamp(for: date, calendar: calendar), forKey: Key.observedInsideDay)
    }

    func clearObservedInsideDay() {
        defaults.removeObject(forKey: Key.observedInsideDay)
    }

    func hasFired(on date: Date, calendar: Calendar = .current) -> Bool {
        defaults.string(forKey: Key.firedDay) == dayStamp(for: date, calendar: calendar)
    }

    func markFired(on date: Date, calendar: Calendar = .current) {
        defaults.set(dayStamp(for: date, calendar: calendar), forKey: Key.firedDay)
    }

    private func dayStamp(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return "\(year)-\(month)-\(day)"
    }
}
