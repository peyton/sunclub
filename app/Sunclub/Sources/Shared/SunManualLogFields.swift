import SwiftUI

struct SunManualLogFields: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
        selectedAreas: Binding<Set<String>> = .constant([]),
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
            DisclosureGroup("Details", isExpanded: $isShowingDetails) {
                detailsFields.padding(.top, AppSpacing.xs)
            }
            .font(AppTextStyle.bodyMedium.font)
            .tint(AppColor.accent)
            .frame(minHeight: 44)
            .accessibilityIdentifier("\(accessibilityPrefix).detailsToggle")
        } else {
            detailsFields
        }
    }

    private var detailsFields: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            if let suggestion = suggestions.sameAsLastTime {
                Button {
                    suggestion.apply(toSPF: &selectedSPF, notes: &notes, areas: &selectedAreas)
                } label: {
                    AppText(suggestion.chipTitle, style: .captionMedium, color: AppColor.accent)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(accessibilityPrefix).sameAsLastTime")
            }
            if showsSPFSelector {
                spfSelector
            }
            coveredAreasSelector
            notesField
        }
    }

    private var spfSelector: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                AppText("SPF (optional)", style: .bodyMedium)
                Spacer(minLength: 0)
                if selectedSPF != nil {
                    Button("Clear SPF") { selectedSPF = nil }
                        .font(AppTextStyle.captionMedium.font)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("\(accessibilityPrefix).clearSPF")
                }
            }

            AppText(
                selectedSPF.map { "SPF \($0) selected" } ?? "No SPF selected",
                style: .caption,
                color: AppColor.Text.secondary
            )
            .accessibilityIdentifier("\(accessibilityPrefix).spfState")

            spfOptions(commonSPFLevels, name: "spf")

            if let defaultSPF = suggestions.defaultSPF,
               selectedSPF != defaultSPF,
               !commonSPFLevels.contains(defaultSPF) {
                Button("Usual SPF \(defaultSPF)") { selectedSPF = defaultSPF }
                    .font(AppTextStyle.captionMedium.font)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("\(accessibilityPrefix).defaultSPF")
            }

            if !suggestions.scannedSPFLevels.isEmpty {
                AppText("From scans", style: .caption, color: AppColor.Text.secondary)
                spfOptions(suggestions.scannedSPFLevels, name: "scannedSPF")
            }
        }
        .tint(AppColor.accent)
    }

    private func spfOptions(_ levels: [Int], name: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xxs) {
                ForEach(levels, id: \.self) { level in
                    let isSelected = selectedSPF == level
                    Button {
                        withAnimation(SunMotion.easeInOut(duration: 0.15, reduceMotion: reduceMotion)) {
                            selectedSPF = isSelected ? nil : level
                        }
                    } label: {
                        HStack(spacing: AppSpacing.xxs) {
                            if isSelected {
                                selectionCheck
                            }
                            AppText("\(level)", style: .bodyMedium)
                        }
                        .padding(.horizontal, AppSpacing.xs)
                        .frame(minWidth: 44, minHeight: 44)
                        .background(isSelected ? AppColor.control : AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.control))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.control)
                                .stroke(isSelected ? AppColor.accent : AppColor.stroke, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("SPF \(level)")
                    .accessibilityValue(isSelected ? "Selected" : "Not selected")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("\(accessibilityPrefix).\(name).\(level)")
                }
            }
        }
        .accessibilityIdentifier("\(accessibilityPrefix).\(name)Selector")
    }

    private var coveredAreasSelector: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            AppText("Coverage (optional)", style: .bodyMedium)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: AppSpacing.xxs),
                    count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
                ),
                spacing: AppSpacing.xxs
            ) {
                ForEach(SunManualLogInput.coveredAreas, id: \.self) { area in
                    areaButton(area)
                }
            }
            .accessibilityIdentifier("\(accessibilityPrefix).areas")
        }
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
            HStack(spacing: AppSpacing.xxs) {
                AppText(area, style: .body)
                Spacer(minLength: 0)
                selectionCheck.opacity(isSelected ? 1 : 0)
            }
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, AppSpacing.xs)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(isSelected ? AppColor.control : AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.control)
                    .stroke(isSelected ? AppColor.accent : AppColor.stroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(area)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("\(accessibilityPrefix).area.\(area)")
    }

    private var selectionCheck: some View {
        SunIcon.check.image.resizable().scaledToFit()
            .frame(width: 18, height: 18)
            .foregroundStyle(AppColor.accent)
            .accessibilityHidden(true)
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                AppText("Notes (optional)", style: .bodyMedium)
                Spacer(minLength: 0)
                if !notes.isEmpty {
                    Button("Clear note") { notes = "" }
                        .font(AppTextStyle.captionMedium.font)
                        .tint(AppColor.accent)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("\(accessibilityPrefix).clearNote")
                }
            }

            if !suggestions.noteSnippets.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.xxs) {
                        ForEach(Array(suggestions.noteSnippets.enumerated()), id: \.offset) { index, snippet in
                            Button { notes = snippet } label: {
                                AppText(snippet, style: .caption, color: AppColor.accent)
                                    .padding(.horizontal, AppSpacing.xs)
                                    .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("\(accessibilityPrefix).noteSnippet.\(index)")
                        }
                    }
                }
                .accessibilityIdentifier("\(accessibilityPrefix).noteSnippets")
            }

            TextField("Notes", text: $notes, axis: .vertical)
                .font(AppTextStyle.body.font)
                .foregroundStyle(AppColor.Text.primary)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .padding(AppSpacing.sm)
                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.control))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.control)
                        .stroke(AppColor.stroke, lineWidth: 1)
                }
                .accessibilityLabel("Notes")
                .accessibilityIdentifier("\(accessibilityPrefix).notesField")

            let remaining = SunManualLogInput.noteCharacterLimit
                - SunManualLogInput.notesWithCoveredAreas(notes, areas: selectedAreas).count
            AppText(
                remaining >= 0 ? "\(remaining) characters left" : "\(-remaining) characters over the limit",
                style: .caption,
                color: remaining >= 0 ? AppColor.Text.secondary : AppPalette.warning
            )
            .accessibilityIdentifier("\(accessibilityPrefix).noteCount")
        }
    }
}
