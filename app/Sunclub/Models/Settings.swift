import Foundation
import SwiftData

@Model
final class Settings {
    @Attribute(.unique) var id: UUID
    var hasCompletedOnboarding: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var weeklyHour: Int
    var weeklyWeekday: Int
    var dailyPhraseState: Data?
    var weeklyPhraseState: Data?

    init() {
        self.id = UUID()
        self.hasCompletedOnboarding = false
        self.reminderHour = 8
        self.reminderMinute = 0
        self.weeklyHour = 18
        self.weeklyWeekday = 1
        self.dailyPhraseState = nil
        self.weeklyPhraseState = nil
    }
}
