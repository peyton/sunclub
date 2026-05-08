import Foundation

enum SunManualLogInput {
    static let noteCharacterLimit = 280
    static let coveredAreas = ["Face", "Neck", "Ears", "Body"]
    static let defaultCoveredAreas: Set<String> = ["Face", "Neck"]

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

    static func clampedNotes(_ notes: String) -> String {
        String(notes.prefix(noteCharacterLimit))
    }

    static func notesWithCoveredAreas(_ notes: String, areas: Set<String>) -> String {
        let cleanedNotes = notesRemovingCoveredAreas(notes)
        let orderedAreas = coveredAreas.filter { areas.contains($0) }
        guard !orderedAreas.isEmpty else {
            return clampedNotes(cleanedNotes)
        }

        let areaLine = "\(coveredAreasPrefix) \(orderedAreas.joined(separator: ", "))"
        let combined = cleanedNotes.isEmpty ? areaLine : "\(cleanedNotes)\n\(areaLine)"
        return clampedNotes(combined)
    }

    static func coveredAreas(in notes: String?) -> Set<String> {
        guard let notes else {
            return []
        }

        let lines = notes.components(separatedBy: .newlines)
        guard let areaLine = lines.last(where: { $0.hasPrefix(coveredAreasPrefix) }) else {
            return []
        }

        let rawAreas = areaLine
            .dropFirst(coveredAreasPrefix.count)
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        return Set(rawAreas.filter { coveredAreas.contains($0) })
    }

    static func notesRemovingCoveredAreas(_ notes: String?) -> String {
        guard let notes else {
            return ""
        }

        let lines = notes
            .components(separatedBy: .newlines)
            .filter { !$0.hasPrefix(coveredAreasPrefix) }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func remainingNoteCharacters(for notes: String) -> Int {
        max(0, noteCharacterLimit - notes.count)
    }

    static func noteDedupeKey(_ note: String?) -> String? {
        guard let normalized = normalizedNotes(note) else {
            return nil
        }

        return normalized.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
