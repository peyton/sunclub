import SwiftUI

struct TimelineLogSection: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    let summary: TimelineDayLogSummary

    @State private var editorDay: IdentifiableDay?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader

            VStack(spacing: 0) {
                categoryHeader(title: "Sunscreen", accent: AppPalette.sun)
                logRow(
                    title: "Sunscreen",
                    value: summary.sunscreenStatusText,
                    identifier: "timeline.log.sunscreen",
                    action: presentEditor,
                    tint: AppPalette.sun
                )
            }
            .background(rowGroupBackground)

            VStack(spacing: 0) {
                categoryHeader(title: "Other Data", accent: AppPalette.pool)
                logRow(
                    title: "Reapplications",
                    value: summary.reapplyStatusText,
                    identifier: "timeline.log.reapplications",
                    action: handleReapply,
                    tint: AppPalette.pool
                )

                rowDivider

                logRow(
                    title: "Notes",
                    value: summary.notesStatusText ?? "Add a note",
                    identifier: "timeline.log.notes",
                    action: presentEditor,
                    tint: AppPalette.pool,
                    isPlaceholder: summary.notesStatusText == nil
                )
            }
            .background(rowGroupBackground)

            VStack(spacing: 0) {
                categoryHeader(title: "Factors", accent: AppPalette.aloe)
                logRow(
                    title: "Factors",
                    value: summary.factorsStatusText,
                    identifier: "timeline.log.factors",
                    action: presentEditor,
                    tint: AppPalette.aloe,
                    isPlaceholder: summary.category == .future
                )
            }
            .background(rowGroupBackground)

            if summary.category == .future {
                Text("Future day — view only. Logging opens when the day arrives.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppPalette.softInk)
                    .padding(.top, 4)
                    .accessibilityIdentifier("timeline.log.futureNotice")
            }
        }
        .sheet(item: $editorDay) { item in
            HistoryRecordEditorView(
                day: item.day,
                existingRecord: appState.record(for: item.day)
            )
        }
    }

    private var sectionHeader: some View {
        HStack {
            Text("Log")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppPalette.ink)

            Spacer(minLength: 0)

            Button {
                router.open(.history)
            } label: {
                Text("Options")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppPalette.pool)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.historyCard")
            .accessibilityHint("Opens history and calendar options.")
        }
    }

    private func categoryHeader(title: String, accent: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(accent)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var rowDivider: some View {
        Rectangle()
            .fill(AppPalette.hairlineStroke)
            .frame(height: 1)
            .padding(.leading, 18)
    }

    private var rowGroupBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(AppPalette.cardFill.opacity(0.72))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppPalette.cardStroke, lineWidth: 1)
            }
    }

    private func logRow(
        title: String,
        value: String,
        identifier: String,
        action: @escaping () -> Void,
        tint: Color,
        isPlaceholder: Bool = false
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)

                Spacer(minLength: 8)

                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isPlaceholder ? AppPalette.softInk : tint)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.trailing)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(summary.category == .future)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityHint(hintForFutureOrAction(title: title))
        .accessibilityIdentifier(identifier)
    }

    private func hintForFutureOrAction(title: String) -> String {
        if summary.category == .future {
            return "View-only on future days."
        }
        return "Opens the \(title.lowercased()) editor for \(summary.day.formatted(.dateTime.month(.abbreviated).day()))."
    }

    private func presentEditor() {
        guard summary.category != .future else {
            return
        }
        editorDay = IdentifiableDay(day: summary.day)
    }

    private func handleReapply() {
        guard summary.category != .future else {
            return
        }
        if summary.category == .today {
            router.open(.reapplyCheckIn)
        } else {
            editorDay = IdentifiableDay(day: summary.day)
        }
    }
}

private struct IdentifiableDay: Identifiable {
    let day: Date
    var id: Date { day }
}
