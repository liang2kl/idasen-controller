import Foundation
import Observation

struct Preset: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    /// Target height in centimetres.
    var height: Double
}

/// The user's saved heights, persisted in user defaults.
@MainActor @Observable
final class PresetStore {
    private(set) var presets: [Preset] {
        didSet { persist() }
    }

    private static let key = "presets"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([Preset].self, from: data) {
            presets = saved
        } else {
            presets = [
                Preset(name: String(localized: "Sit"), height: 72),
                Preset(name: String(localized: "Stand"), height: 110),
            ]
        }
    }

    func save(_ preset: Preset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
        } else {
            presets.append(preset)
        }
    }

    func delete(_ preset: Preset) {
        presets.removeAll { $0.id == preset.id }
    }

    /// Moves the preset with `id` to the position currently held by `destination`.
    func move(_ id: Preset.ID, to destination: Preset.ID) {
        guard let from = presets.firstIndex(where: { $0.id == id }),
              let to = presets.firstIndex(where: { $0.id == destination }),
              from != to
        else { return }
        var reordered = presets
        reordered.insert(reordered.remove(at: from), at: to)
        presets = reordered
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
