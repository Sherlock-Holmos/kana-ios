import Foundation
import Combine

/// Bayesian Knowledge Tracing — per-ability mastery probability with 4 parameters.
///   p(L_n)         prior / current mastery probability
///   p(T)           probability of learning transition after each opportunity
///   p(S)           slip: wrong-when-mastered
///   p(G)           guess: right-when-not-mastered
///
/// Updated after each review outcome per ability id.
struct BKTParameters {
    var pInit: Double = 0.20    // p(L_0)
    var pTransit: Double = 0.25 // p(T)
    var pSlip: Double = 0.10    // p(S)
    var pGuess: Double = 0.25   // p(G)

    static let standard = BKTParameters()
}

struct BKTMastery: Codable, Hashable {
    var abilityId: String
    var pMaster: Double          // p(L_n) ∈ [0,1]
    var opportunities: Int
    var lastUpdated: Date

    static func zero(_ id: String, pInit: Double) -> BKTMastery {
        BKTMastery(abilityId: id, pMaster: pInit, opportunities: 0, lastUpdated: Date())
    }
}

/// BKTStore — one mastery probability per ability id.
final class BKTStore: ObservableObject {
    @Published private(set) var masteries: [String: BKTMastery] = [:]

    var params: BKTParameters = .standard

    private let storeKey = "kana-study.bkt.v1"
    private let defaults = UserDefaults.standard

    init() {
        load()
    }

    // MARK: - Public

    func ensure(_ abilityId: String) {
        if masteries[abilityId] == nil {
            masteries[abilityId] = .zero(abilityId, pInit: params.pInit)
        }
    }

    /// Update p(mastery) for an ability given a single binary outcome.
    func update(abilityId: String, correct: Bool) {
        ensure(abilityId)
        guard var m = masteries[abilityId] else { return }

        let pL = m.pMaster
        let pS = params.pSlip
        let pG = params.pGuess

        let pGivenObs: Double
        if correct {
            let num = pL * (1 - pS)
            let den = pL * (1 - pS) + (1 - pL) * pG
            pGivenObs = den == 0 ? pL : num / den
        } else {
            let num = pL * pS
            let den = pL * pS + (1 - pL) * (1 - pG)
            pGivenObs = den == 0 ? pL : num / den
        }

        let pNext = pGivenObs + (1 - pGivenObs) * params.pTransit

        m.pMaster = min(max(pNext, 0.0), 1.0)
        m.opportunities += 1
        m.lastUpdated = Date()
        masteries[abilityId] = m
        save()
    }

    func mastery(for abilityId: String) -> Double {
        masteries[abilityId]?.pMaster ?? params.pInit
    }

    /// Abilities still below mastery threshold, weakest first.
    func unmastered(threshold: Double = 0.95, limit: Int = 5) -> [BKTMastery] {
        masteries.values
            .filter { $0.pMaster < threshold }
            .sorted { $0.pMaster < $1.pMaster }
            .prefix(limit)
            .map { $0 }
    }

    var totalOpportunities: Int {
        masteries.values.reduce(0) { $0 + $1.opportunities }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = defaults.data(forKey: storeKey) else { return }
        if let decoded = try? JSONDecoder().decode([String: BKTMastery].self, from: data) {
            masteries = decoded
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(masteries) {
            defaults.set(encoded, forKey: storeKey)
        }
    }
}