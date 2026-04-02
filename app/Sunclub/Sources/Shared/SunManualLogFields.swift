import SwiftUI

struct SunManualLogFields: View {
    @Binding var selectedSPF: Int?
    @Binding var notes: String

    let accessibilityPrefix: String

    private let commonSPFLevels = [15, 30, 50, 70, 100]

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            spfSelector
            notesField
        }
    }

    private var spfSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SPF Level")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            HStack(spacing: 10) {
                ForEach(commonSPFLevels, id: \.self) { level in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedSPF = selectedSPF == level ? nil : level
                        }
                    } label: {
                        Text("\(level)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(selectedSPF == level ? .white : AppPalette.ink)
                            .frame(width: 48, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selectedSPF == level ? AppPalette.sun : Color.white.opacity(0.72))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(selectedSPF == level ? Color.clear : Color.black.opacity(0.06), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("\(accessibilityPrefix).spf.\(level)")
                }
            }
            .accessibilityIdentifier("\(accessibilityPrefix).spfSelector")
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            TextField("e.g. Applied before morning run", text: $notes)
                .font(.system(size: 15))
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                }
                .accessibilityIdentifier("\(accessibilityPrefix).notesField")
        }
    }
}
