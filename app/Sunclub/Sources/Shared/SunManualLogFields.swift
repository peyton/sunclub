import SwiftUI

struct SunManualLogFields: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var selectedSPF: Int?
    @Binding var notes: String
    @Binding var selectedAreas: Set<String>
    @State private var isShowingDetails: Bool

    let accessibilityPrefix: String
    let suggestions: ManualLogSuggestionState
    let showsOptionalDisclosure: Bool
    let showsSPFSelector: Bool

    private let commonSPFLevels = [15, 30, 50, 70, 100]

    init(
        selectedSPF: Binding<Int?>,
        notes: Binding<String>,
        selectedAreas: Binding<Set<String>> = Binding<Set<String>>.constant([]),
        accessibilityPrefix: String,
        suggestions: ManualLogSuggestionState = .empty,
        showsOptionalDisclosure: Bool = true,
        showsSPFSelector: Bool = true,
        detailsInitiallyExpanded: Bool = false
    ) {
        _selectedSPF = selectedSPF
        _notes = notes
        _selectedAreas = selectedAreas
        _isShowingDetails = State(initialValue: detailsInitiallyExpanded)
        self.accessibilityPrefix = accessibilityPrefix
        self.suggestions = suggestions
        self.showsOptionalDisclosure = showsOptionalDisclosure
        self.showsSPFSelector = showsSPFSelector
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
                            .font(AppFont.rounded(size: 17, weight: .semibold))
                            .foregroundStyle(AppPalette.ink)

                        Text(detailsSummary)
                            .font(AppFont.rounded(size: 14))
                            .foregroundStyle(AppPalette.softInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isShowingDetails ? "chevron.up" : "chevron.down")
                        .font(AppFont.rounded(size: 13, weight: .semibold))
                        .foregroundStyle(AppPalette.softInk)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
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
            if showsSPFSelector {
                spfSelector
            }
            coveredAreasSelector
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
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            HStack(spacing: 10) {
                Text(selectedSPF.map { "SPF \($0) selected" } ?? "No SPF selected")
                    .font(AppFont.rounded(size: 13, weight: .medium))
                    .foregroundStyle(AppPalette.softInk)
                    .accessibilityIdentifier("\(accessibilityPrefix).spfState")

                if selectedSPF != nil {
                    Button("Clear SPF") {
                        selectedSPF = nil
                    }
                    .font(AppFont.rounded(size: 13, weight: .semibold))
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
                        notes = SunManualLogInput.clampedNotes(note)
                    }
                } label: {
                    Text(sameAsLastTime.chipTitle)
                        .font(AppFont.rounded(size: 13, weight: .semibold))
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

            if let defaultSPF = suggestions.defaultSPF,
               shouldShowDefaultSPF(defaultSPF) {
                Button {
                    withAnimation(SunMotion.easeInOut(duration: 0.15, reduceMotion: reduceMotion)) {
                        selectedSPF = defaultSPF
                    }
                } label: {
                    Label("Usual SPF \(defaultSPF)", systemImage: "clock.arrow.circlepath")
                        .font(AppFont.rounded(size: 13, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)
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
                .accessibilityLabel("Use usual SPF \(defaultSPF)")
                .accessibilityIdentifier("\(accessibilityPrefix).defaultSPF")
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

    private func shouldShowDefaultSPF(_ level: Int) -> Bool {
        selectedSPF != level && suggestions.sameAsLastTime?.spfLevel != level
    }

    private func spfOptionSection(
        title: String,
        levels: [Int],
        accessibilityName: String,
        showsSPFPrefix: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFont.rounded(size: 12, weight: .semibold))
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
                        .font(AppFont.rounded(size: 10, weight: .bold))
                }

                Text(title)
                    .font(AppFont.rounded(size: 15, weight: .medium))
            }
            .foregroundStyle(isSelected ? AppPalette.onAccent : AppPalette.ink)
            .frame(minWidth: 48, minHeight: 40)
            .padding(.horizontal, title.count > 3 || isSelected ? 12 : 0)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .fill(isSelected ? AppPalette.sun : AppPalette.cardFill.opacity(0.72))
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .stroke(isSelected ? Color.clear : AppPalette.hairlineStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("SPF \(level)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var coveredAreasSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Areas Covered")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 14) {
                    SunCoveredAreaIllustration(selectedAreas: selectedAreas)
                        .frame(width: 148, height: 190)
                        .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        ForEach(SunManualLogInput.coveredAreas, id: \.self) { area in
                            areaButton(area)
                                .frame(width: 124)
                        }
                    }
                    .accessibilityIdentifier("\(accessibilityPrefix).areas")
                }

                VStack(alignment: .leading, spacing: 12) {
                    SunCoveredAreaIllustration(selectedAreas: selectedAreas)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)

                    LazyVGrid(columns: areaColumns, spacing: 8) {
                        ForEach(SunManualLogInput.coveredAreas, id: \.self) { area in
                            areaButton(area)
                        }
                    }
                    .accessibilityIdentifier("\(accessibilityPrefix).areas")
                }
            }
        }
    }

    private var areaColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 104), spacing: 8)]
    }

    private func areaButton(_ area: String) -> some View {
        let isSelected = selectedAreas.contains(area)

        return Button {
            withAnimation(SunMotion.easeInOut(duration: 0.15, reduceMotion: reduceMotion)) {
                if isSelected {
                    selectedAreas.remove(area)
                } else {
                    selectedAreas.insert(area)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(area)
                    .font(AppFont.rounded(size: 14, weight: isSelected ? .bold : .semibold))

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .fill(isSelected ? AppPalette.sun : Color.clear)
                        .overlay {
                            Circle()
                                .stroke(isSelected ? AppPalette.sun : AppPalette.hairlineStroke, lineWidth: 1.4)
                        }

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(AppFont.rounded(size: 10, weight: .bold))
                            .foregroundStyle(AppPalette.onAccent)
                    }
                }
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)
            }
            .foregroundStyle(AppPalette.ink)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .fill(AppPalette.cardFill.opacity(isSelected ? 0.92 : 0.72))
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .stroke(isSelected ? AppPalette.sun.opacity(0.75) : AppPalette.hairlineStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(area)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("\(accessibilityPrefix).area.\(area)")
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Notes (optional)")
                    .font(AppFont.rounded(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)

                Spacer(minLength: 0)

                if hasNotes {
                    Button("Clear Note") {
                        notes = ""
                    }
                    .font(AppFont.rounded(size: 13, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("\(accessibilityPrefix).clearNote")
                }
            }

            if !suggestions.noteSnippets.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(suggestions.noteSnippets.enumerated()), id: \.offset) { index, noteSnippet in
                            Button {
                                notes = SunManualLogInput.clampedNotes(noteSnippet)
                            } label: {
                                Text(noteSnippet)
                                    .font(AppFont.rounded(size: 13, weight: .medium))
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

            TextField("Add notes about your sunscreen", text: $notes, axis: .vertical)
                .font(AppFont.rounded(size: 15))
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                        .fill(AppPalette.cardFill.opacity(0.72))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                        .stroke(AppPalette.hairlineStroke, lineWidth: 1)
                }
                .accessibilityLabel("Notes")
                .accessibilityIdentifier("\(accessibilityPrefix).notesField")
                .onChange(of: notes) { _, newValue in
                    let clampedNotes = SunManualLogInput.clampedNotes(newValue)
                    if clampedNotes != newValue {
                        notes = clampedNotes
                    }
                }

            Text(noteCountText)
                .font(AppFont.rounded(size: 12, weight: .medium))
                .foregroundStyle(AppPalette.softInk.opacity(0.86))
                .accessibilityIdentifier("\(accessibilityPrefix).noteCount")
        }
    }

    private var hasNotes: Bool {
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var noteCountText: String {
        let remaining = SunManualLogInput.remainingNoteCharacters(for: notes)
        if remaining == 1 {
            return "1 character left"
        }

        return "\(remaining) characters left"
    }
}

private struct SunCoveredAreaIllustration: View {
    let selectedAreas: Set<String>

    var body: some View {
        ZStack(alignment: .bottom) {
            Circle()
                .fill(AppPalette.warmGlow.opacity(0.18))
                .frame(width: 136, height: 136)
                .offset(y: 44)

            SunclubVisualAsset.coverageFaceDiagram.image
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
        }
        .frame(height: 154)
    }
}
