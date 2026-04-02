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

    static let empty = ManualLogSuggestionState(defaultSPF: nil, sameAsLastTime: nil, noteSnippets: [])
}

enum ManualLogSuggestionEngine {
    static func suggestions(
        from records: [DailyRecord],
        excluding day: Date? = nil,
        calendar: Calendar = Calendar.current,
        noteLimit: Int = 3
    ) -> ManualLogSuggestionState {
        let filteredRecords = records.filter { record in
            guard let day else {
                return true
            }

            return !calendar.isDate(record.startOfDay, inSameDayAs: day)
        }

        let sortedRecords = filteredRecords.sorted { lhs, rhs in
            if lhs.verifiedAt != rhs.verifiedAt {
                return lhs.verifiedAt > rhs.verifiedAt
            }

            return lhs.startOfDay > rhs.startOfDay
        }

        let mostRecentReusableRecord = sortedRecords.first {
            $0.spfLevel != nil || $0.trimmedNotes != nil
        }

        let sameAsLastTime = mostRecentReusableRecord.map {
            ManualLogReuseSuggestion(spfLevel: $0.spfLevel, note: $0.trimmedNotes)
        }

        let excludedNotes = Set([sameAsLastTime?.note].compactMap { $0 })
        var noteSnippets: [String] = []
        var seenNotes = Set<String>()

        for record in sortedRecords {
            guard let note = record.trimmedNotes,
                  !excludedNotes.contains(note),
                  seenNotes.insert(note).inserted else {
                continue
            }

            noteSnippets.append(note)
            if noteSnippets.count == noteLimit {
                break
            }
        }

        return ManualLogSuggestionState(
            defaultSPF: mostRecentReusableRecord?.spfLevel,
            sameAsLastTime: sameAsLastTime?.hasContent == true ? sameAsLastTime : nil,
            noteSnippets: noteSnippets
        )
    }
}
