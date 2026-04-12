import Foundation

enum SunclubCopy {
    enum Brand {
        static let welcomeTitle = "Daily sunscreen, made routine."
        static let welcomeDetail = "A quick check-in, a clear streak, and reminders that help you stay steady."
        static let reminderTitle = "Set the daily nudge"
        static let reminderDetail = "Turn on reminders and Sunclub will catch you before the day gets moving. You can change the time later."
        static let homeSubtitle = "Make sunscreen the easy part of the day."
    }

    enum Success {
        static let title = "Day logged"
        static let actionTitle = "Back to Home"

        static func streakDetail(_ streak: Int) -> String {
            if streak == 1 {
                return "First day logged. Keep it going tomorrow."
            }

            return "\(SunclubCopy.countedDays(streak)) in a row."
        }
    }

    enum Sync {
        static func savedOnlyOnThisPhone(_ count: Int) -> String {
            "\(SunclubCopy.countedChanges(count, adjective: "imported")) \(count == 1 ? "is" : "are") saved only on this phone."
        }

        static func readyToSendToICloud(_ count: Int) -> String {
            "\(SunclubCopy.countedChanges(count, adjective: "imported")) \(count == 1 ? "is" : "are") ready to send to iCloud."
        }

        static func mergedChangesNeedReview(_ count: Int) -> String {
            "\(SunclubCopy.countedChanges(count, adjective: "merged")) \(count == 1 ? "needs" : "need") review."
        }
    }

    enum Phrases {
        static let daily: [String] = [
            "Sunscreen first. The rest can follow.",
            "Log today before the day gets busy.",
            "One quick check-in and you're set for today.",
            "Keep the habit easy. Sunscreen first.",
            "Start the day protected.",
            "Get today's check-in done early.",
            "A steady routine beats a perfect one.",
            "Log today and move on with the day.",
            "Keep your bottle where you can see it.",
            "One small step. One protected day.",
            "Make sunscreen the easy part of the morning.",
            "Stay covered, keep it simple."
        ]

        static let weekly: [String] = [
            "A steady week starts with today's check-in.",
            "Keep your sunscreen where you can see it.",
            "If the routine feels easy, it's working.",
            "Open day? Start again today.",
            "Less friction, more consistency.",
            "The goal is coverage, not perfection.",
            "Use the bottle you'll actually reach for.",
            "A simple routine is the one that lasts."
        ]
    }

    static func countedDays(_ count: Int) -> String {
        count == 1 ? "1 day" : "\(count) days"
    }

    static func countedChanges(_ count: Int, adjective: String? = nil) -> String {
        let noun = count == 1 ? "change" : "changes"

        if let adjective {
            return "\(count) \(adjective) \(noun)"
        }

        return "\(count) \(noun)"
    }
}
