import SwiftUI

struct TimelineTodayStatusCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let presentation: TimelineHomePresentation
    let accessibilityIdentifierSuffix: String?

    private var isToday: Bool {
        Calendar.current.isDate(presentation.selectedDay, inSameDayAs: presentation.today)
    }

    private var weekLoggedCount: Int {
        presentation.weekProgressDays.filter(\.isLogged).count
    }

    var body: some View {
        AppCard(padding: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        AppText(statusTitle, style: .largeTitle)
                            .accessibilityIdentifier(identifier(statusAccessibilityIdentifier))

                        if let statusDetail {
                            AppText(statusDetail, style: .body, color: AppColor.Text.secondary)
                                .accessibilityIdentifier(identifier("timeline.statusDetail"))
                        }
                    }

                    Spacer(minLength: 0)

                    StatusBadge(
                        title: ringLabel,
                        systemImage: statusSymbolName,
                        tint: statusTint
                    )
                }

                Rectangle()
                    .fill(AppPalette.hairlineStroke)
                    .frame(height: 1)
                    .accessibilityHidden(true)

                SunWeekProgressRow(days: presentation.weekProgressDays)
                    .accessibilityIdentifier(identifier("timeline.weekProgress"))

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) {
                        statusMetricCards
                    }
                } else {
                    HStack(spacing: 10) {
                        statusMetricCards
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var statusMetricCards: some View {
        StatCard(
            value: "\(weekLoggedCount)/7",
            label: "logged this week",
            systemImage: "checkmark.circle.fill",
            tint: AppPalette.streakAccent,
            usesGlass: false
        )
        .accessibilityIdentifier(identifier("timeline.status.weekLogged"))

        StatCard(
            value: reapplyStatusValue,
            label: "reapply",
            systemImage: "timer",
            tint: AppPalette.sun,
            usesGlass: false
        )
        .accessibilityIdentifier(identifier("timeline.status.reapply"))
    }

    private var dateText: String {
        presentation.selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var statusTitle: String {
        switch presentation.logSummary.category {
        case .today:
            return presentation.logSummary.record == nil ? "No sunscreen logged today" : "Sunscreen Logged"
        case .past:
            return presentation.logSummary.record == nil ? "No log" : "Logged"
        case .future:
            return "Forecast only"
        }
    }

    private var statusAccessibilityIdentifier: String {
        if presentation.logSummary.category == .today, presentation.logSummary.record != nil {
            return "home.todayStatus"
        }
        return "timeline.todayStatus"
    }

    private func identifier(_ base: String) -> String {
        guard let accessibilityIdentifierSuffix else {
            return base
        }
        return "\(base).\(accessibilityIdentifierSuffix)"
    }

    private var statusDetail: String? {
        switch presentation.logSummary.category {
        case .today:
            if presentation.logSummary.record != nil {
                return "Add SPF, areas, or a note."
            }
            return "Add a log to start your reminder."
        case .past:
            return presentation.logSummary.record == nil
                ? "Backfill this day if you applied sunscreen."
                : "SPF and notes are saved for this day."
        case .future:
            return presentation.logSummary.futurePreview?.suggestionText
                ?? "Use the forecast to plan SPF before the day starts."
        }
    }

    private var statusSymbolName: String {
        switch presentation.logSummary.category {
        case .today:
            return presentation.logSummary.record == nil ? "sun.max.fill" : "checkmark.shield.fill"
        case .past:
            return presentation.logSummary.record == nil ? "calendar.badge.plus" : "checkmark.circle.fill"
        case .future:
            return "sparkles"
        }
    }

    private var ringLabel: String {
        switch presentation.logSummary.category {
        case .today:
            return presentation.logSummary.record == nil ? "No log" : "Logged"
        case .past:
            return presentation.logSummary.record == nil ? "Open" : "Saved"
        case .future:
            return "Plan"
        }
    }

    private var reapplyStatusValue: String {
        guard presentation.logSummary.category == .today,
              presentation.logSummary.record != nil else {
            return "After log"
        }
        return "2h"
    }

    private var statusTint: Color {
        if presentation.logSummary.record != nil {
            return AppPalette.success
        }
        return presentation.logSummary.category == .future ? AppPalette.pool : AppPalette.sun
    }
}
