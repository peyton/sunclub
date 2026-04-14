import SwiftUI

struct SunManualLogFields: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var selectedSPF: Int?
    @Binding var notes: String
    @State private var isShowingDetails: Bool

    let accessibilityPrefix: String
    let suggestions: ManualLogSuggestionState
    let showsOptionalDisclosure: Bool

    private let commonSPFLevels = [15, 30, 50, 70, 100]

    init(
        selectedSPF: Binding<Int?>,
        notes: Binding<String>,
        accessibilityPrefix: String,
        suggestions: ManualLogSuggestionState = .empty,
        showsOptionalDisclosure: Bool = true,
        detailsInitiallyExpanded: Bool = false
    ) {
        _selectedSPF = selectedSPF
        _notes = notes
        _isShowingDetails = State(initialValue: detailsInitiallyExpanded)
        self.accessibilityPrefix = accessibilityPrefix
        self.suggestions = suggestions
        self.showsOptionalDisclosure = showsOptionalDisclosure
    }

    var body: some View {
        if showsOptionalDisclosure {
            optionalDetailsDisclosure
        } else {
            detailsFields
        }
    }

    private var optionalDetailsDisclosure: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(SunMotion.easeInOut(duration: 0.2, reduceMotion: reduceMotion)) {
                    isShowingDetails.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Add details")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppPalette.ink)

                        Text(detailsSummary)
                            .font(.system(size: 14))
                            .foregroundStyle(AppPalette.softInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isShowingDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppPalette.softInk)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppPalette.cardFill.opacity(0.72))
                )
            }
            .buttonStyle(.plain)
            .accessibilityValue(isShowingDetails ? "Expanded" : "Collapsed")
            .accessibilityHint(isShowingDetails ? "Hides optional SPF and note fields." : "Shows optional SPF and note fields.")
            .accessibilityIdentifier("\(accessibilityPrefix).detailsToggle")

            if isShowingDetails {
                detailsFields
            }
        }
    }

    private var detailsFields: some View {
        VStack(alignment: .leading, spacing: 26) {
            spfSelector
            notesField
        }
    }

    private var detailsSummary: String {
        var parts: [String] = []

        if let selectedSPF {
            parts.append("SPF \(selectedSPF)")
        } else {
            parts.append("No SPF selected")
        }

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            parts.append("Note added")
        }

        return "\(parts.joined(separator: " · ")). Optional."
    }

    private var spfSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SPF (optional)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            HStack(spacing: 10) {
                Text(selectedSPF.map { "SPF \($0) selected" } ?? "No SPF selected")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppPalette.softInk)
                    .accessibilityIdentifier("\(accessibilityPrefix).spfState")

                if selectedSPF != nil {
                    Button("Clear SPF") {
                        selectedSPF = nil
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("\(accessibilityPrefix).clearSPF")
                }
            }

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
        let isSelected = selectedSPF == level

        return Button {
            withAnimation(SunMotion.easeInOut(duration: 0.15, reduceMotion: reduceMotion)) {
                selectedSPF = isSelected ? nil : level
            }
        } label: {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }

                Text(title)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(isSelected ? AppPalette.onAccent : AppPalette.ink)
            .frame(minWidth: 48, minHeight: 40)
            .padding(.horizontal, title.count > 3 || isSelected ? 12 : 0)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? AppPalette.sun : AppPalette.cardFill.opacity(0.72))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.clear : AppPalette.hairlineStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("SPF \(level)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes (optional)")
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
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppPalette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(AppPalette.cardFill.opacity(0.72))
                                    )
                                    .overlay {
                                        Capsule()
                                            .stroke(AppPalette.hairlineStroke, lineWidth: 1)
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
                        .fill(AppPalette.cardFill.opacity(0.72))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppPalette.hairlineStroke, lineWidth: 1)
                }
                .accessibilityIdentifier("\(accessibilityPrefix).notesField")
        }
    }
}
