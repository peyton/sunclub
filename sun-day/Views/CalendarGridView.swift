import SwiftUI

struct CalendarGridView: View {
    @Environment(AppState.self) private var appState
    @State private var monthAnchor = Date()
    @State private var selectedDay: IdentifiedDate?

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        ZStack {
            SunBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    monthCard
                    legendCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedDay) { item in
            DayDetailView(date: item.date)
                .environment(appState)
        }
    }

    private var weekHeader: [String] {
        var symbols = Calendar.current.shortWeekdaySymbols
        let first = Calendar.current.firstWeekday - 1
        if first > 0 {
            symbols = Array(symbols[first...] + symbols[..<first])
        }
        return symbols
    }

    private var header: some View {
        HStack {
            Button(action: goToPreviousMonth) {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.72), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 4) {
                Text(monthAnchor.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(AppPalette.ink)

                Text("Filled circle = protected. Open circle = still pending.")
                    .font(.footnote)
                    .foregroundStyle(AppPalette.softInk)
            }

            Spacer()

            Button(action: goToNextMonth) {
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.72), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .sunCard()
    }

    private var monthCard: some View {
        VStack(spacing: 16) {
            HStack {
                ForEach(weekHeader, id: \.self) { weekday in
                    Text(weekday.uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .tracking(1.1)
                        .foregroundStyle(AppPalette.softInk)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(appState.monthGrid(for: monthAnchor), id: \.self) { day in
                    Button {
                        selectedDay = IdentifiedDate(date: day)
                    } label: {
                        dayCell(for: day)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sunCard()
    }

    private var legendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Legend")
                .font(.headline)
                .foregroundStyle(AppPalette.ink)

            HStack(spacing: 10) {
                LegendChip(title: "Applied", tint: AppPalette.success) {
                    Circle()
                        .fill(AppPalette.success)
                        .frame(width: 10, height: 10)
                }

                LegendChip(title: "Today", tint: AppPalette.warning) {
                    Circle()
                        .stroke(AppPalette.warning, lineWidth: 2)
                        .frame(width: 10, height: 10)
                }

                LegendChip(title: "Missed", tint: AppPalette.danger) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppPalette.danger)
                }
            }

            Text("Future days stay blank. Taps open a day card with method and timing details when available.")
                .font(.footnote)
                .foregroundStyle(AppPalette.softInk)
        }
        .sunCard()
    }

    @ViewBuilder
    private func dayCell(for day: Date) -> some View {
        let status = appState.dayStatus(for: day)
        let isCurrentMonth = appState.isCurrentMonth(day, month: monthAnchor)
        let isToday = Calendar.current.isDateInToday(day)
        let opacity = isCurrentMonth ? 1.0 : 0.35

        VStack(spacing: 10) {
            Text(day.formatted(.dateTime.day()))
                .font(.headline)
                .foregroundStyle(AppPalette.ink.opacity(opacity))

            Group {
                switch status {
                case .applied:
                    Circle()
                        .fill(AppPalette.success)
                        .frame(width: 20, height: 20)
                        .shadow(color: AppPalette.success.opacity(0.22), radius: 8, x: 0, y: 4)
                case .todayPending:
                    Circle()
                        .stroke(AppPalette.warning, lineWidth: 2.5)
                        .frame(width: 20, height: 20)
                case .missed:
                    Image(systemName: "xmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppPalette.danger)
                case .future:
                    Color.clear
                        .frame(width: 20, height: 20)
                }
            }
            .frame(height: 20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(isCurrentMonth ? 0.72 : 0.36))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isToday ? AppPalette.sun.opacity(0.9) : Color.white.opacity(0.5), lineWidth: isToday ? 2 : 1)
        }
        .shadow(color: Color.black.opacity(isCurrentMonth ? 0.05 : 0.02), radius: 8, x: 0, y: 4)
    }

    private func goToPreviousMonth() {
        monthAnchor = Calendar.current.date(byAdding: .month, value: -1, to: monthAnchor) ?? monthAnchor
    }

    private func goToNextMonth() {
        monthAnchor = Calendar.current.date(byAdding: .month, value: 1, to: monthAnchor) ?? monthAnchor
    }
}

struct DayDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let date: Date

    var body: some View {
        ZStack {
            SunBackdrop()

            VStack(spacing: 18) {
                Text(date.formatted(.dateTime.weekday(.wide).day().month().year()))
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(AppPalette.ink)

                VStack(spacing: 10) {
                    let status = appState.dayStatus(for: date)
                    switch status {
                    case .applied:
                        Text("Sunscreen applied")
                            .font(.headline)
                            .foregroundStyle(AppPalette.success)
                        if let record = appState.record(for: date) {
                            detailRow(label: "Method", value: record.method.displayName)
                            if let code = record.barcode {
                                detailRow(label: "Barcode", value: code)
                            }
                            if let distance = record.featureDistance {
                                detailRow(label: "Feature distance", value: String(format: "%.3f", distance))
                            }
                            detailRow(
                                label: "Time",
                                value: record.verifiedAt.formatted(date: .omitted, time: .shortened)
                            )
                        }
                    case .todayPending:
                        Text("Not yet applied today.")
                            .foregroundStyle(AppPalette.warning)
                    case .missed:
                        Text("No successful verification this day.")
                            .foregroundStyle(AppPalette.danger)
                    case .future:
                        Text("This is a future date.")
                            .foregroundStyle(AppPalette.softInk)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .sunCard()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(SunPrimaryButtonStyle())
            }
            .padding(24)
        }
        .presentationDetents([.medium])
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(AppPalette.softInk)

            Spacer()

            Text(value)
                .font(.body)
                .foregroundStyle(AppPalette.ink)
        }
    }
}

private struct IdentifiedDate: Identifiable {
    let id = UUID()
    let date: Date
}

private struct LegendChip<Icon: View>: View {
    let title: String
    let tint: Color
    let icon: () -> Icon

    init(title: String, tint: Color, @ViewBuilder icon: @escaping () -> Icon) {
        self.title = title
        self.tint = tint
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 8) {
            icon()
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(AppPalette.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay {
            Capsule()
                .stroke(tint.opacity(0.18), lineWidth: 1)
        }
    }
}
