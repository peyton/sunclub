import Foundation

enum SunManualLogInput {
    static let noteCharacterLimit = 280

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
