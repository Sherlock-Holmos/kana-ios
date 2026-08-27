import Foundation
import Combine

/// AbilityProfile — simple per-sill mastery tracker.
/// Each ability (e.g. "vocabulary.reading", "kana.recognition") starts at 0.5
/// and moves up/down with review outcomes.
struct Ability: Codable, Hashable {
    var id: String             // ability id
    var mastery: Double        // 0.0..1.0
    var attempts: Int
    var successes: Int
    var lastUpdated: Date

    static func zero(_ id: String) -> Ability {
        Ability(id: id, mastery: 0.5, attempts: 0, successes: 0, lastUpdated: Date())
    }

    mutating func recordOutcome(success: Bool) {
        attempts += 1
        if success { successes += 1 }
        // Bayesian-ish update: nudge mastery toward 0/1 with weight = 1/(attempts+1)
        let weight = 1.0 / Double(attempts + 1)
        let target = success ? 1.0 : 0.0
        mastery = mastery * (1 - weight) + target * weight
        mastery = min(max(mastery, 0.0), 1.0)
        lastUpdated = Date()
    }
}

final class AbilityProfile: ObservableObject {
    @Published private(set) var abilities: [String: Ability] = [:]

    private let storeKey = "kana-study.ability.v1"
    private let defaults = UserDefaults.standard

    init() { load() }

    func ensureAbility(_ id: String) {
        if abilities[id] == nil {
            abilities[id] = .zero(id)
        }
    }

    /// Record an outcome against a list of abilities (a single item can target multiple skills).
    func recordOutcomes(_ abilityIds: [String], success: Bool) {
        for id in abilityIds {
            ensureAbility(id)
            abilities[id]?.recordOutcome(success: success)
        }
        save()
    }

    /// Lower-mastery abilities come first, so the planner can target gaps.
    func weakestAbilities(limit: Int = 5) -> [Ability] {
        abilities.values.sorted { $0.mastery < $1.mastery }.prefix(limit).map { $0 }
    }

    func masteryFor(_ id: String) -> Double {
        abilities[id]?.mastery ?? 0.5
    }

    // MARK: Persistence

    private func load() {
        guard let data = defaults.data(forKey: storeKey) else { return }
        if let decoded = try? JSONDecoder().decode([String: Ability].self, from: data) {
            abilities = decoded
        }
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(abilities) else { return }
        defaults.set(encoded, forKey: storeKey)
        SyncTrigger.shared.bump()
    }

    /// Replace the entire abilities dictionary (used when merging a server-side envelope).
    func replaceAll(_ newAbilities: [String: Ability]) {
        abilities = newAbilities
        save()
    }
}