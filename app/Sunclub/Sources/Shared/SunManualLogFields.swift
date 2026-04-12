import SwiftUI

struct SunManualLogFields: View {
    @Binding var selectedSPF: Int?
    @Binding var notes: String

    let accessibilityPrefix: String
    let suggestions: ManualLogSuggestionState

    private let commonSPFLevels = [15, 30, 50, 70, 100]

    init(
        selectedSPF: Binding<Int?>,
        notes: Binding<String>,
        accessibilityPrefix: String,
        suggestions: ManualLogSuggestionState = .empty
    ) {
        _selectedSPF = selectedSPF
        _notes = notes
        self.accessibilityPrefix = accessibilityPrefix
        self.suggestions = suggestions
    }

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

            if let sameAsLastTime = suggestions.sameAsLastTime {
                Button {
                    if let spfLevel = sameAsLastTime.spfLevel {
                        selectedSPF = spfLevel
                    }
                    if let note = sameAsLastTime.note {
                        notes = note
                    }
                } label: {
                    Text(sameAsLastTime.chipTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(AppPalette.warmGlow.opacity(0.5))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(accessibilityPrefix).sameAsLastTime")
            }

            spfOptionSection(
                title: "Presets",
                levels: commonSPFLevels,
                accessibilityName: "spf",
                showsSPFPrefix: false
            )

            if !suggestions.scannedSPFLevels.isEmpty {
                spfOptionSection(
                    title: "From scans",
                    levels: suggestions.scannedSPFLevels,
                    accessibilityName: "scannedSPF",
                    showsSPFPrefix: true
                )
            }
        }
    }

    private func spfOptionSection(
        title: String,
        levels: [Int],
        accessibilityName: String,
        showsSPFPrefix: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppPalette.softInk.opacity(0.85))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(levels, id: \.self) { level in
                        spfButton(
                            level: level,
                            title: showsSPFPrefix ? "SPF \(level)" : "\(level)",
                            accessibilityIdentifier: "\(accessibilityPrefix).\(accessibilityName).\(level)"
                        )
                    }
                }
            }
            .accessibilityIdentifier("\(accessibilityPrefix).\(accessibilityName)Selector")
        }
    }

    private func spfButton(level: Int, title: String, accessibilityIdentifier: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedSPF = selectedSPF == level ? nil : level
            }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(selectedSPF == level ? .white : AppPalette.ink)
                .frame(minWidth: 48, minHeight: 40)
                .padding(.horizontal, title.count > 3 ? 12 : 0)
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
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            if !suggestions.noteSnippets.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(suggestions.noteSnippets.enumerated()), id: \.offset) { index, noteSnippet in
                            Button {
                                notes = noteSnippet
                            } label: {
                                Text(noteSnippet)
                                    .lineLimit(1)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppPalette.ink)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.72))
                                    )
                                    .overlay {
                                        Capsule()
                                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("\(accessibilityPrefix).noteSnippet.\(index)")
                        }
                    }
                }
                .accessibilityIdentifier("\(accessibilityPrefix).noteSnippets")
            }

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
