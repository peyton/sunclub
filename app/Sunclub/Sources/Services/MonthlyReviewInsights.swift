import Foundation

struct MonthlyWeekdayInsight: Equatable {
    let weekday: Int
    let completedCount: Int
    let totalCount: Int

    var rate: Double {
        guard totalCount > 0 else {
            return 0
        }

        return Double(completedCount) / Double(totalCount)
    }

    var title: String {
        let formatter = DateFormatter()
        return formatter.weekdaySymbols[weekday - 1]
    }

    var detail: String {
        "\(completedCount) of \(totalCount) logged"
    }
}

struct MonthlyReviewInsights: Equatable {
    let bestWeekday: MonthlyWeekdayInsight?
    let hardestWeekday: MonthlyWeekdayInsight?
    let mostCommonSPF: MostUsedSPFInsight?

    static let empty = MonthlyReviewInsights(bestWeekday: nil, hardestWeekday: nil, mostCommonSPF: nil)

    var hasContent: Bool {
        bestWeekday != nil || hardestWeekday != nil || mostCommonSPF != nil
    }
}

enum MonthlyReviewAnalytics {
    static func insights(
        from records: [DailyRecord],
        month: Date,
        now: Date = Date(),
        calendar: Calendar = Calendar.current
    ) -> MonthlyReviewInsights {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return .empty
        }

        let today = calendar.startOfDay(for: now)
        let effectiveEnd = min(monthEnd, calendar.date(byAdding: .day, value: 1, to: today) ?? monthEnd)
        guard monthStart < effectiveEnd else {
            return .empty
        }

        let monthRecords = records.filter { record in
            let day = calendar.startOfDay(for: record.startOfDay)
            return day >= monthStart && day < effectiveEnd
        }

        var totalByWeekday: [Int: Int] = [:]
        var cursor = monthStart
        while cursor < effectiveEnd {
            let weekday = calendar.component(.weekday, from: cursor)
            totalByWeekday[weekday, default: 0] += 1
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? effectiveEnd
        }

        var completedByWeekday: [Int: Int] = [:]
        for record in monthRecords {
            let weekday = calendar.component(.weekday, from: record.startOfDay)
            completedByWeekday[weekday, default: 0] += 1
        }

        let weekdayInsights = totalByWeekday.keys.compactMap { weekday -> MonthlyWeekdayInsight? in
            guard let totalCount = totalByWeekday[weekday] else {
                return nil
            }

            return MonthlyWeekdayInsight(
                weekday: weekday,
                completedCount: completedByWeekday[weekday, default: 0],
                totalCount: totalCount
            )
        }

        let rankedBest = weekdayInsights.sorted { lhs, rhs in
            if lhs.rate != rhs.rate {
                return lhs.rate > rhs.rate
            }

            if lhs.totalCount != rhs.totalCount {
                return lhs.totalCount > rhs.totalCount
            }

            if lhs.completedCount != rhs.completedCount {
                return lhs.completedCount > rhs.completedCount
            }

            return lhs.weekday < rhs.weekday
        }

        let rankedHardest = weekdayInsights.sorted { lhs, rhs in
            if lhs.rate != rhs.rate {
                return lhs.rate < rhs.rate
            }

            if lhs.totalCount != rhs.totalCount {
                return lhs.totalCount > rhs.totalCount
            }

            if lhs.completedCount != rhs.completedCount {
                return lhs.completedCount < rhs.completedCount
            }

            return lhs.weekday < rhs.weekday
        }

        let bestWeekday = rankedBest.first
        let hardestWeekday = rankedHardest.first { hardest in
            hardest.weekday != bestWeekday?.weekday || rankedHardest.count == 1
        }

        return MonthlyReviewInsights(
            bestWeekday: bestWeekday,
            hardestWeekday: hardestWeekday,
            mostCommonSPF: SunscreenUsageAnalytics.mostUsedSPFInsight(from: monthRecords)
        )
    }
}
