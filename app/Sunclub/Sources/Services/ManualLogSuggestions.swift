import Foundation

struct ManualLogReuseSuggestion: Equatable {
    let spfLevel: Int?
    let note: String?

    var chipTitle: String {
        if spfLevel != nil, note != nil {
            return "Same as last time"
        }

        if let spfLevel {
            return "Reuse SPF \(spfLevel)"
        }

        return "Reuse last note"
    }

    var detail: String {
        var parts: [String] = []

        if let spfLevel {
            parts.append("SPF \(spfLevel)")
        }

        if let note {
            parts.append(note)
        }

        return parts.joined(separator: " · ")
    }

    var hasContent: Bool {
        spfLevel != nil || note != nil
    }
}

struct ManualLogSuggestionState: Equatable {
    let defaultSPF: Int?
    let sameAsLastTime: ManualLogReuseSuggestion?
    let noteSnippets: [String]
    let scannedSPFLevels: [Int]

    static let empty = ManualLogSuggestionState(
        defaultSPF: nil,
        sameAsLastTime: nil,
        noteSnippets: [],
        scannedSPFLevels: []
    )
}

struct SunManualLogResolvedDefaults: Equatable {
    let spfLevel: Int?
    let coveredAreas: Set<String>

    static let empty = SunManualLogResolvedDefaults(spfLevel: nil, coveredAreas: [])

    var oneTapNotes: String? {
        guard !coveredAreas.isEmpty else {
            return nil
        }

        return SunManualLogInput.notesWithCoveredAreas("", areas: coveredAreas)
    }
}

enum SunManualLogDefaultResolver {
    static func oneTapDefaults(
        from records: [DailyRecord],
        excluding day: Date? = nil,
        calendar: Calendar = Calendar.current
    ) -> SunManualLogResolvedDefaults {
        let sortedRecords = ManualLogSuggestionEngine.sortedRecords(
            from: records,
            excluding: day,
            calendar: calendar
        )
        let spfLevel = sortedRecords.first { $0.spfLevel != nil }?.spfLevel
        let coveredAreas = sortedRecords
            .lazy
            .map { SunManualLogInput.coveredAreas(in: $0.notes) }
            .first { !$0.isEmpty } ?? []

        return SunManualLogResolvedDefaults(spfLevel: spfLevel, coveredAreas: coveredAreas)
    }
}

enum ManualLogSuggestionEngine {
    static func suggestions(
        from records: [DailyRecord],
        excluding day: Date? = nil,
        calendar: Calendar = Calendar.current,
        noteLimit: Int = 3,
        scannedSPFLevels: [Int] = []
    ) -> ManualLogSuggestionState {
        let sortedRecords = sortedRecords(from: records, excluding: day, calendar: calendar)

        let mostRecentReusableRecord = sortedRecords.first {
            $0.spfLevel != nil || $0.trimmedNotes != nil
        }
        let mostRecentSPFRecord = sortedRecords.first {
            $0.spfLevel != nil
        }

        let sameAsLastTime = mostRecentReusableRecord.map {
            ManualLogReuseSuggestion(spfLevel: $0.spfLevel, note: $0.trimmedNotes)
        }

        let excludedNotes = Set([sameAsLastTime?.note].compactMap(SunManualLogInput.noteDedupeKey))
        var noteSnippets: [String] = []
        var seenNotes = Set<String>()

        for record in sortedRecords {
            guard let note = record.trimmedNotes,
                  let noteKey = SunManualLogInput.noteDedupeKey(note),
                  !excludedNotes.contains(noteKey),
                  seenNotes.insert(noteKey).inserted else {
                continue
            }

            noteSnippets.append(note)
            if noteSnippets.count == noteLimit {
                break
            }
        }

        return ManualLogSuggestionState(
            defaultSPF: mostRecentSPFRecord?.spfLevel,
            sameAsLastTime: sameAsLastTime?.hasContent == true ? sameAsLastTime : nil,
            noteSnippets: noteSnippets,
            scannedSPFLevels: SunclubGrowthSettings.normalizedSPFLevels(scannedSPFLevels)
        )
    }

    static func sortedRecords(
        from records: [DailyRecord],
        excluding day: Date? = nil,
        calendar: Calendar = Calendar.current
    ) -> [DailyRecord] {
        let filteredRecords = records.filter { record in
            guard let day else {
                return true
            }

            return !calendar.isDate(record.startOfDay, inSameDayAs: day)
        }

        return filteredRecords.sorted { lhs, rhs in
            if lhs.verifiedAt != rhs.verifiedAt {
                return lhs.verifiedAt > rhs.verifiedAt
            }

            return lhs.startOfDay > rhs.startOfDay
        }
    }
}
