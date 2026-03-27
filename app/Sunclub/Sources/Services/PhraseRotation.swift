import Foundation

enum PhraseRotation {
    static func nextPhrase(from state: Data?, catalog: [String]) -> (String, Data) {
        var remaining = decode(state)
        if remaining.isEmpty {
            remaining = catalog.shuffled()
        }

        if let first = remaining.first {
            remaining.removeFirst()
            let nextState = encode(remaining)
            return (first, nextState)
        }

        return (catalog.first ?? "You're doing great.", encode([]))
    }

    static func decode(_ data: Data?) -> [String] {
        guard let data = data else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    static func encode(_ values: [String]) -> Data {
        (try? JSONEncoder().encode(values)) ?? Data()
    }
}
