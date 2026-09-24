import Foundation
import Observation

struct PlaceTypeEntry: Codable, Identifiable, Equatable {
    var id: String { value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }
    let value: String
    var useCount: Int
    var createdAt: Date
    var lastUsedAt: Date
}

@Observable
final class PlaceTypeMemory {
    private(set) var entries: [PlaceTypeEntry] = []
    private let defaults: UserDefaults
    private let dataKey = "rememberedPlaceTypeEntriesV2"
    private let legacyKey = "rememberedPlaceTypes"

    var values: [String] { rankedEntries.map(\.value) }

    var quickValues: [String] {
        let top = Array(rankedEntries.prefix(3))
        let topIDs = Set(top.map(\.id))
        let newestOutsideTop = entries
            .filter { !topIDs.contains($0.id) }
            .max { $0.createdAt < $1.createdAt }
        return (top + [newestOutsideTop].compactMap { $0 }).prefix(4).map(\.value)
    }

    var remainingValues: [String] {
        let quick = Set(quickValues.map(normalized))
        return rankedEntries.map(\.value).filter { !quick.contains(normalized($0)) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: dataKey),
           let decoded = try? JSONDecoder().decode([PlaceTypeEntry].self, from: data) {
            entries = decoded
        } else {
            let values = defaults.stringArray(forKey: legacyKey) ?? ["美食", "甜點", "咖啡", "特殊販賣物"]
            let base = Date(timeIntervalSince1970: 0)
            entries = values.enumerated().map { index, value in
                PlaceTypeEntry(value: value, useCount: 0, createdAt: base.addingTimeInterval(Double(index)), lastUsedAt: base)
            }
            persist()
        }
    }

    func remember(_ rawValue: String, at date: Date = .now) {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        if let index = entries.firstIndex(where: { normalized($0.value) == normalized(value) }) {
            entries[index].useCount += 1
            entries[index].lastUsedAt = date
        } else {
            entries.append(PlaceTypeEntry(value: value, useCount: 1, createdAt: date, lastUsedAt: date))
        }
        entries = Array(rankedEntries.prefix(100))
        persist()
    }

    func suggestions(for query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return quickValues }
        return rankedEntries
            .map(\.value)
            .filter { $0.localizedCaseInsensitiveContains(trimmed) }
    }

    func replace(with values: [PlaceTypeEntry]) {
        entries = values
        persist()
    }

    private var rankedEntries: [PlaceTypeEntry] {
        entries.sorted {
            if $0.useCount != $1.useCount { return $0.useCount > $1.useCount }
            if $0.lastUsedAt != $1.lastUsedAt { return $0.lastUsedAt > $1.lastUsedAt }
            return $0.createdAt > $1.createdAt
        }
    }

    private func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: dataKey)
        }
    }
}
