import Foundation

/// Planner — picks the next batch of items to study, prioritizing
/// 1) due SRS cards, 2) never-seen items covering the weakest abilities, 3) any unseen.
struct Planner {
    struct Recommendation: Identifiable, Hashable {
        let id: String          // content item id
        let reason: String
        let priority: Int        // 1..N, lower = more urgent
    }

    let srs: SRSStore
    let ability: AbilityProfile

    /// Build a short list of items to study next.
    func recommend(limit: Int = 8,
                   kana: [KanaItem] = [],
                   vocab: [VocabularyItem] = []) -> [Recommendation] {
        var recs: [Recommendation] = []
        var priority = 1

        // 1. Due SRS cards
        for card in srs.dueItems().prefix(limit) {
            recs.append(.init(id: card.id, reason: "到期复习", priority: priority))
            priority += 1
        }

        // 2. Unseen items to start filling weakest abilities
        let enrolledIds = Set(srs.cards.keys)
        let unseenKana = kana.filter { !enrolledIds.contains($0.id) }
        let unseenVocab = vocab.filter { !enrolledIds.contains($0.id) }

        for k in unseenKana.prefix(limit / 2) {
            if !recs.contains(where: { $0.id == k.id }) {
                recs.append(.init(id: k.id, reason: "新假名", priority: priority))
                priority += 1
            }
        }
        for v in unseenVocab.prefix(limit / 2) {
            if !recs.contains(where: { $0.id == v.id }) {
                recs.append(.init(id: v.id, reason: "新词汇", priority: priority))
                priority += 1
            }
        }

        // 3. Fall back: first kana items if nothing else
        if recs.isEmpty {
            for k in kana.prefix(limit) {
                recs.append(.init(id: k.id, reason: "开始学习", priority: priority))
                priority += 1
            }
        }

        return Array(recs.prefix(limit))
    }
}