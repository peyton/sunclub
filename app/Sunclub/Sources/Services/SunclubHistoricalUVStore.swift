import Foundation

/// Lightweight per-day UV index history.
///
/// Populated when the user logs sunscreen, so future views can tint
/// past chips by the UV they were logged under. Lives in the shared
/// App Group UserDefaults (not SwiftData) to avoid a schema migration —
/// this data is non-critical, never synced to CloudKit, and can be
/// repopulated simply by using the app going forward.
final class SunclubHistoricalUVStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String
    private let lock = NSLock()
    private let calendar = Calendar(identifier: .gregorian)
    private let maxEntries = 400

    init(
        appGroupID: String = SunclubRuntimeConfiguration.appGroupID,
        key: String = "sunclub.historicalUV.v1"
    ) {
        self.defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        self.key = key
    }

    /// Record the UV index the user experienced on `day`.
    /// Re-recording the same day overwrites. Entries older than
    /// ~13 months are pruned on write.
    func record(uvIndex: Int, for day: Date) {
        lock.lock()
        defer { lock.unlock() }
        var entries = loadEntries()
        let normalized = calendar.startOfDay(for: day)
        entries[normalized] = uvIndex

        if entries.count > maxEntries {
            let sorted = entries.sorted(by: { $0.key > $1.key })
            entries = Dictionary(uniqueKeysWithValues: sorted.prefix(maxEntries).map { ($0.key, $0.value) })
        }
        saveEntries(entries)
    }

    func uvIndex(for day: Date) -> Int? {
        lock.lock()
        defer { lock.unlock() }
        return loadEntries()[calendar.startOfDay(for: day)]
    }

    func allEntries() -> [Date: Int] {
        lock.lock()
        defer { lock.unlock() }
        return loadEntries()
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: key)
    }

    private func loadEntries() -> [Date: Int] {
        guard let data = defaults.data(forKey: key),
              let serialized = try? JSONDecoder().decode([SerializedEntry].self, from: data) else {
            return [:]
        }
        var map: [Date: Int] = [:]
        for entry in serialized {
            map[entry.day] = entry.index
        }
        return map
    }

    private func saveEntries(_ entries: [Date: Int]) {
        let serialized = entries.map { SerializedEntry(day: $0.key, index: $0.value) }
        guard let data = try? JSONEncoder().encode(serialized) else { return }
        defaults.set(data, forKey: key)
    }

    private struct SerializedEntry: Codable {
        let day: Date
        let index: Int
    }
}
