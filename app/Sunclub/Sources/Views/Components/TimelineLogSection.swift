import SwiftUI

struct TimelineLogSection: View {
    @Environment(AppRouter.self) private var router

    let summary: TimelineDayLogSummary
    let onOpenManualLog: (AppLogContext) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader

            VStack(spacing: 0) {
                ForEach(summary.partStatuses) { status in
                    logRow(for: status)
                    if status.dayPart != DayPart.allCases.last {
                        rowDivider
                    }
                }
            }
            .background(rowGroupBackground)

            if let helperText = summary.helperText {
                Text(helperText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppPalette.softInk)
                    .accessibilityIdentifier("timeline.log.futureNotice")
            } else if summary.record == nil {
                Text("Pick a day part and log once. You can update SPF or notes later.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppPalette.softInk)
                    .accessibilityIdentifier("timeline.log.emptyHint")
            }
        }
    }

    private var sectionHeader: some View {
        HStack {
            Text("Timeline Log")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppPalette.ink)

            Spacer(minLength: 0)

            Button("Options") {
                router.open(.history)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppPalette.pool)
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.historyCard")
            .accessibilityHint("Opens history and calendar options.")
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(AppPalette.hairlineStroke)
            .frame(height: 1)
            .padding(.leading, 18)
    }

    private var rowGroupBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(AppPalette.cardFill.opacity(0.76))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppPalette.cardStroke, lineWidth: 1)
            }
    }

    private func logRow(for status: TimelineDayPartStatus) -> some View {
        let actionTitle: String
        if !summary.canLog {
            actionTitle = status.dayPart.title
        } else if status.isCompleted {
            actionTitle = "Update \(status.dayPart.title)"
        } else {
            actionTitle = "Log \(status.dayPart.title)"
        }
        return Button {
            onOpenManualLog(
                AppLogContext(
                    date: summary.day,
                    dayPart: status.dayPart,
                    source: .timeline
                )
            )
        } label: {
            HStack(spacing: 12) {
                Image(systemName: status.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(status.isCompleted ? AppPalette.success : AppPalette.sun)
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(actionTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)

                    Text(status.statusText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.softInk)
                }

                Spacer(minLength: 8)

                if summary.canLog, status.canLog {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppPalette.softInk)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!summary.canLog || !status.canLog)
        .accessibilityLabel(actionTitle)
        .accessibilityHint(
            summary.canLog && status.canLog
                ? "Opens manual logging for this day part."
                : "Cannot log future date."
        )
        .accessibilityValue("\(status.statusText). \(status.isCompleted ? "Complete" : "Incomplete")")
        .accessibilityIdentifier("timeline.log.part.\(status.dayPart.rawValue)")
    }
}
