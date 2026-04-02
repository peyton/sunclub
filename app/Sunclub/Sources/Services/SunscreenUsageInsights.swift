import Foundation

struct MostUsedSPFInsight: Equatable {
    let level: Int
    let count: Int
    let totalLoggedCount: Int

    var title: String {
        "SPF \(level)"
    }

    var detail: String {
        let checkInLabel = totalLoggedCount == 1 ? "SPF check-in" : "SPF check-ins"
        return "\(count) of \(totalLoggedCount) \(checkInLabel)"
    }
}

struct RecentUsageNote: Equatable {
    let date: Date
    let text: String
}

struct SunscreenUsageInsights: Equatable {
    let mostUsedSPF: MostUsedSPFInsight?
    let recentNotes: [RecentUsageNote]

    static let empty = SunscreenUsageInsights(mostUsedSPF: nil, recentNotes: [])

    var hasContent: Bool {
        mostUsedSPF != nil || !recentNotes.isEmpty
    }
}

enum SunscreenUsageAnalytics {
    static func insights(
        from records: [DailyRecord],
        recentNotesLimit: Int = 3
    ) -> SunscreenUsageInsights {
        let mostUsedSPF = mostUsedSPFInsight(from: records)

        let recentNotes = records
            .compactMap { record -> RecentUsageNote? in
                guard let text = record.trimmedNotes else {
                    return nil
                }

                return RecentUsageNote(date: record.verifiedAt, text: text)
            }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date {
                    return lhs.date > rhs.date
                }

                return lhs.text < rhs.text
            }

        return SunscreenUsageInsights(
            mostUsedSPF: mostUsedSPF,
            recentNotes: Array(recentNotes.prefix(recentNotesLimit))
        )
    }

    static func mostUsedSPFInsight(from records: [DailyRecord]) -> MostUsedSPFInsight? {
        let spfRecords = records.compactMap { record -> (level: Int, verifiedAt: Date)? in
            guard let level = record.spfLevel else {
                return nil
            }

            return (level, record.verifiedAt)
        }

        return mostUsedSPFInsight(from: spfRecords)
    }

    private static func mostUsedSPFInsight(
        from spfRecords: [(level: Int, verifiedAt: Date)]
    ) -> MostUsedSPFInsight? {
        guard !spfRecords.isEmpty else {
            return nil
        }

        let groupedByLevel = Dictionary(grouping: spfRecords) { $0.level }
        let totalLoggedCount = spfRecords.count

        let rankedInsights = groupedByLevel.compactMap { level, entries -> (insight: MostUsedSPFInsight, lastUsedAt: Date)? in
            guard let lastUsedAt = entries.map({ $0.verifiedAt }).max() else {
                return nil
            }

            return (
                MostUsedSPFInsight(level: level, count: entries.count, totalLoggedCount: totalLoggedCount),
                lastUsedAt
            )
        }
        .sorted { lhs, rhs in
            if lhs.insight.count != rhs.insight.count {
                return lhs.insight.count > rhs.insight.count
            }

            if lhs.lastUsedAt != rhs.lastUsedAt {
                return lhs.lastUsedAt > rhs.lastUsedAt
            }

            return lhs.insight.level < rhs.insight.level
        }

        return rankedInsights.first?.insight
    }
}
