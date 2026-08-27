import Foundation

/// Adaptive Planner backed by BKT mastery probability.
/// Picks the next batch of items weighted by:
///   1. SRS due cards (urgent)
///   2. Items whose ability mastery is still below 0.95 (high learning value)
///   3. Brand-new items covering the weakest abilities
struct Planner {
    struct Recommendation: Identifiable, Hashable {
        let id: String          // content item id
        let reason: String      // human-readable
        let priority: Int        // 1..N
    }

    let srs: SRSStore
    let bkt: BKTStore
    let goal: DailyGoalStore

    /// Build a short list of items to study next.
    func recommend(limit: Int = 8,
                   kana: [KanaItem] = [],
                   vocab: [VocabularyItem] = []) -> [Recommendation] {
        var recs: [Recommendation] = []
        var priority = 1
        var seenIds = Set<String>()

        func add(_ id: String, _ reason: String) {
            if seenIds.contains(id) { return }
            seenIds.insert(id)
            recs.append(.init(id: id, reason: reason, priority: priority))
            priority += 1
        }

        // 1. Due SRS cards
        for card in srs.dueItems().prefix(limit) {
            add(card.id, "到期复习")
        }

        // 2. Items whose abilities are still unmastered (BKT)
        let target = bkt.unmastered(threshold: 0.95, limit: 6).map { $0.abilityId }
        let kanaByAbility = kana.filter { $0.pedagogyAbilities.contains { target.contains($0) } }
        let vocabByAbility = vocab.filter { $0.pedagogyAbilities.contains { target.contains($0) } }

        for k in kanaByAbility.prefix(limit / 2) {
            add(k.id, "补弱项（假名）")
        }
        for v in vocabByAbility.prefix(limit / 2) {
            add(v.id, "补弱项（词汇）")
        }

        // 3. Brand-new items covering weakest abilities
        let enrolledIds = Set(srs.cards.keys)
        for k in kana.filter({ !enrolledIds.contains($0.id) }).prefix(2) {
            add(k.id, "新假名")
        }
        for v in vocab.filter({ !enrolledIds.contains($0.id) }).prefix(2) {
            add(v.id, "新词汇")
        }

        // 4. Fallback — just kana
        if recs.isEmpty {
            for k in kana.prefix(limit) {
                add(k.id, "开始学习")
            }
        }

        // 5. If today's goal already met, shrink to nothing
        if goal.goalHitToday && recs.allSatisfy({ $0.reason.contains("到期") }) {
            return Array(recs.prefix(2))
        }

        return Array(recs.prefix(limit))
    }
}

// MARK: - Item ability mapping (cheap version: same mapping the QuestionBank uses)

extension KanaItem {
    /// All ability ids touched by this kana item.
    var pedagogyAbilities: [String] { ["kana.recognition", "kana.recall"] }
}

extension VocabularyItem {
    var pedagogyAbilities: [String] {
        ["vocabulary.meaning", "vocabulary.reading", "vocabulary.production"]
    }
}