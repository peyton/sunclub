import SwiftUI

struct CalendarGridView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var monthAnchor = Date()
    @State private var selectedDay: IdentifiedDate?

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            header

            LazyVGrid(columns: columns) {
                ForEach(weekHeader, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }

                ForEach(appState.monthGrid(for: monthAnchor), id: \.self) { day in
                    dayCell(for: day)
                        .onTapGesture {
                            selectedDay = IdentifiedDate(date: day)
                        }
                }
            }
            .padding(.horizontal)

            Spacer()

            Text("Symbols: filled circle = applied, open circle = today pending, X = missed")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Calendar")
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
            Button {
                monthAnchor = Calendar.current.date(byAdding: .month, value: -1, to: monthAnchor) ?? monthAnchor
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(monthAnchor.formatted(.dateTime.month(.wide).year()))
                .font(.headline)

            Spacer()

            Button {
                monthAnchor = Calendar.current.date(byAdding: .month, value: 1, to: monthAnchor) ?? monthAnchor
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func dayCell(for day: Date) -> some View {
        let status = appState.dayStatus(for: day)
        let isCurrentMonth = appState.isCurrentMonth(day, month: monthAnchor)
        let opacity = isCurrentMonth ? 1.0 : 0.35

        VStack {
            Text(day.formatted(.dateTime.day()))
                .font(.caption)
                .opacity(opacity)
                .padding(.top, 2)

            Group {
                switch status {
                case .applied:
                    Circle()
                        .fill(Color.green)
                        .frame(width: 20, height: 20)
                case .todayPending:
                    Circle()
                        .stroke(Color.orange, lineWidth: 2)
                        .frame(width: 20, height: 20)
                case .missed:
                    Text("✕")
                        .foregroundStyle(.red)
                        .font(.headline)
                        .offset(y: -2)
                case .future:
                    EmptyView()
                }
            }
            .frame(height: 22)
            Spacer(minLength: 2)
        }
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)).opacity(opacity))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

struct DayDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let date: Date

    var body: some View {
        VStack(spacing: 12) {
            Text(date.formatted(.dateTime.weekday().day().month().year()))
                .font(.headline)

            let status = appState.dayStatus(for: date)
            switch status {
            case .applied:
                Text("Sunscreen applied")
                    .foregroundStyle(.green)
                if let record = appState.record(for: date) {
                    Text("Method: \(record.method.displayName)")
                    if let code = record.barcode {
                        Text("Barcode: \(code)")
                            .font(.caption)
                    }
                    if let distance = record.featureDistance {
                        Text(String(format: "Distance: %.3f", distance))
                            .font(.caption)
                    }
                    Text("At \(record.verifiedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                }
            case .todayPending:
                Text("Not yet applied today.")
            case .missed:
                Text("No successful verification this day.")
                    .foregroundStyle(.red)
            case .future:
                Text("This is a future date.")
                    .foregroundStyle(.secondary)
            }

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

private struct IdentifiedDate: Identifiable {
    let id = UUID()
    let date: Date
}
