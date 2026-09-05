import Foundation

enum SunManualLogInput {
    static let noteCharacterLimit = 280
    static let coveredAreas = ["Face", "Neck", "Ears", "Body"]

    private static let coveredAreasPrefix = "Areas:"

    static func normalizedSPF(_ spfLevel: Int?) -> Int? {
        spfLevel.map { max(1, min($0, 100)) }
    }

    static func normalizedNotes(_ notes: String?) -> String? {
        guard let notes else { return nil }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(noteCharacterLimit))
    }

    static func notesWithCoveredAreas(_ notes: String, areas: Set<String>) -> String {
        // Editors pass prose separately from coverage. Never parse or truncate the draft again.
        let cleanedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let orderedAreas = coveredAreas.filter { areas.contains($0) }
        guard !orderedAreas.isEmpty else {
            return cleanedNotes
        }

        let areaLine = "\(coveredAreasPrefix) \(orderedAreas.joined(separator: ", "))"
        return cleanedNotes.isEmpty ? areaLine : "\(cleanedNotes)\n\(areaLine)"
    }

    static func coveredAreas(in notes: String?) -> Set<String> {
        trailingMetadata(in: notes)?.areas ?? []
    }

    static func validatedNotesWithCoveredAreas(_ notes: String, areas: Set<String>) -> String? {
        let serialized = notesWithCoveredAreas(notes, areas: areas)
        return serialized.count <= noteCharacterLimit ? serialized : nil
    }

    static func notesRemovingCoveredAreas(_ notes: String?) -> String {
        guard let notes else {
            return ""
        }

        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trailingMetadata(in: trimmed)?.prose ?? trimmed
    }

    private static func trailingMetadata(in notes: String?) -> (prose: String, areas: Set<String>)? {
        guard let notes else { return nil }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let lineStart = trimmed.lastIndex(where: { $0.isNewline }).map { trimmed.index(after: $0) }
            ?? trimmed.startIndex
        let line = trimmed[lineStart...]
        guard line.hasPrefix(coveredAreasPrefix) else { return nil }
        let names = line.dropFirst(coveredAreasPrefix.count)
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard !names.isEmpty, names.allSatisfy({ coveredAreas.contains($0) }) else { return nil }
        let prose = String(trimmed[..<lineStart]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (prose, Set(names))
    }

    static func noteDedupeKey(_ note: String?) -> String? {
        guard let normalized = normalizedNotes(note) else {
            return nil
        }

        return normalized.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
