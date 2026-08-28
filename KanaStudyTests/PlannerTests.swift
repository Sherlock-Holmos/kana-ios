import XCTest
@testable import KanaStudy

/// Tests the BKT-driven recommendation logic in Planner.recommend.
/// KanaItem.pedagogyAbilities is hardcoded to ["kana.recognition", "kana.recall"],
/// so any KanaItem we construct will match those BKT ability IDs.
final class PlannerTests: XCTestCase {

    private var srs: SRSStore!
    private var bkt: BKTStore!
    private var goal: DailyGoalStore!

    private let srsKey = "kana-study.srs.cards.v2"
    private let bktKey = "kana-study.bkt.v1"
    private let goalKey = "kana-study.daily.goal"
    private let activityKey = "kana-study.daily.activity.v1"
    private let learnedKey = "kana-study.daily.learned.v1"
    private let listeningKey = "kana-study.daily.listening.v1"
    private let readingKey = "kana-study.daily.reading.v1"

    override func setUp() {
        super.setUp()
        [srsKey, bktKey, goalKey, activityKey,
         learnedKey, listeningKey, readingKey].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
        srs = SRSStore()
        bkt = BKTStore()
        goal = DailyGoalStore()
    }

    override func tearDown() {
        [srsKey, bktKey, goalKey, activityKey,
         learnedKey, listeningKey, readingKey].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
        srs = nil; bkt = nil; goal = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Mastery both kana abilities so the BKT filter in the planner yields nothing.
    private func masterAllKanaAbilities() {
        for _ in 0..<60 { bkt.update(abilityId: "kana.recognition", correct: true) }
        for _ in 0..<60 { bkt.update(abilityId: "kana.recall", correct: true) }
    }

    /// Builds a KanaItem matching the real Decodable shape.
    private func makeKana(_ id: String) -> KanaItem {
        KanaItem(
            id: id, script: "hiragana", kana: id, roman: id,
            row: "vowel", category: nil, memory: nil,
            title: id, subtitle: ""
        )
    }

    private func makeVocab(_ id: String) -> VocabularyItem {
        VocabularyItem(
            id: id, expression: id, reading: id,
            meanings: [id], partOfSpeech: nil, level: nil
        )
    }

    // MARK: - Priority 1: SRS due items

    func testPriority_srsDueItemsComeFirst() {
        // Force a card to be due now by backdating its dueDate
        let due = SRSCard(id: "kana-due", ease: 2.5, interval: 1, repetitions: 1,
                          dueDate: Date().addingTimeInterval(-60),
                          lastReviewed: nil, lapses: 0, totalReviews: 0)
        srs.replaceAll(["kana-due": due])

        let brandNew = [makeKana("kana-new")]
        let recs = Planner(srs: srs, bkt: bkt, goal: goal)
            .recommend(limit: 4, kana: brandNew, vocab: [])

        XCTAssertEqual(recs.first?.id, "kana-due",
                       "SRS-due items must be the top priority regardless of brand-new availability")
        XCTAssertEqual(recs.first?.priority, 1)
        XCTAssertEqual(recs.first?.reason, "到期复习")
    }

    func testPriority_multipleSrsDueItems_sortedByDueDate() {
        let now = Date()
        let older = SRSCard(id: "kana-old", ease: 2.5, interval: 1, repetitions: 1,
                            dueDate: now.addingTimeInterval(-120),
                            lastReviewed: nil, lapses: 0, totalReviews: 0)
        let newer = SRSCard(id: "kana-new", ease: 2.5, interval: 1, repetitions: 1,
                            dueDate: now.addingTimeInterval(-30),
                            lastReviewed: nil, lapses: 0, totalReviews: 0)
        srs.replaceAll(["kana-old": older, "kana-new": newer])

        let recs = Planner(srs: srs, bkt: bkt, goal: goal)
            .recommend(limit: 4, kana: [], vocab: [])
        let ids = recs.map(\.id)
        XCTAssertEqual(ids.first, "kana-old",
                       "more overdue cards should come first")
    }

    // MARK: - Priority 2: BKT unmastered items

    func testPriority_unmasteredBKTItems_secondTier() {
        // No SRS due, kana-recognition seeded (unmastered at pInit=0.20)
        bkt.ensure("kana.recognition")
        let kana = [makeKana("kana-unmastered")]
        let recs = Planner(srs: srs, bkt: bkt, goal: goal)
            .recommend(limit: 4, kana: kana, vocab: [])

        XCTAssertEqual(recs.first?.id, "kana-unmastered")
        XCTAssertEqual(recs.first?.reason, "补弱项（假名）")
        XCTAssertEqual(recs.first?.priority, 1)
    }

    func testPriority_vocabWeakAbility_secondTier() {
        // Seed the vocabulary.meaning ability as unmastered so the planner picks
        // vocab items via the BKT-unmastered path.
        bkt.ensure("vocabulary.meaning")
        let vocab = [makeVocab("vocab-weak")]
        let recs = Planner(srs: srs, bkt: bkt, goal: goal)
            .recommend(limit: 4, kana: [], vocab: vocab)

        XCTAssertEqual(recs.first?.id, "vocab-weak")
        XCTAssertEqual(recs.first?.reason, "补弱项（词汇）")
    }

    // MARK: - Priority 3: brand-new items

    func testPriority_brandNewItems_thirdTier() {
        // Both kana abilities mastered → BKT yields nothing → brand-new path activates
        masterAllKanaAbilities()

        let kana = [makeKana("kana-fresh")]
        let recs = Planner(srs: srs, bkt: bkt, goal: goal)
            .recommend(limit: 4, kana: kana, vocab: [])

        XCTAssertEqual(recs.first?.id, "kana-fresh")
        XCTAssertEqual(recs.first?.reason, "新假名")
    }

    // MARK: - Limits and dedup

    func testRespectsLimit() {
        // Fill the SRS due-items tier with 5 cards — that's the only tier
        // that takes `limit` literally without halving it.
        let now = Date()
        let cards = (0..<5).map { i in
            SRSCard(id: "kana-\(i)", ease: 2.5, interval: 1, repetitions: 1,
                    dueDate: now.addingTimeInterval(-60 - Double(i)),
                    lastReviewed: nil, lapses: 0, totalReviews: 0)
        }
        srs.replaceAll(Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) }))

        let recs = Planner(srs: srs, bkt: bkt, goal: goal)
            .recommend(limit: 5, kana: [], vocab: [])
        XCTAssertEqual(recs.count, 5)
        XCTAssertTrue(recs.allSatisfy { $0.reason == "到期复习" })
    }

    func testNoDuplicateRecommendations() {
        let kana = [makeKana("kana-a")]
        let recs = Planner(srs: srs, bkt: bkt, goal: goal)
            .recommend(limit: 10, kana: kana, vocab: [])
        let unique = Set(recs.map(\.id))
        XCTAssertEqual(recs.count, unique.count,
                       "planner must not emit the same id twice")
    }

    // MARK: - Edge cases

    func testFallbackReason_whenNoData() {
        let kana = [makeKana("kana-fallback")]
        let recs = Planner(srs: srs, bkt: bkt, goal: goal)
            .recommend(limit: 3, kana: kana, vocab: [])
        XCTAssertFalse(recs.isEmpty)
        XCTAssertTrue(["补弱项（假名）", "新假名", "到期复习"].contains(recs.first?.reason ?? ""))
    }

    func testEmptyStores_returnsSomething() {
        // No kana, no vocab, no SRS — planner should fall back gracefully.
        let recs = Planner(srs: srs, bkt: bkt, goal: goal)
            .recommend(limit: 3, kana: [], vocab: [])
        // Either empty (everything was empty) or fallback reason is surfaced.
        if !recs.isEmpty {
            XCTAssertEqual(recs.first?.reason, "开始学习")
        }
    }

    func testPriorityNumbersAreSequential() {
        let kana = (0..<5).map { makeKana("kana-\($0)") }
        let recs = Planner(srs: srs, bkt: bkt, goal: goal)
            .recommend(limit: 5, kana: kana, vocab: [])
        let priorities = recs.map(\.priority)
        XCTAssertEqual(priorities, Array(1...recs.count))
    }

    func testDailyGoalHit_shrinksToTopSrsOnly() {
        // Hit the daily goal by recording reviews
        for _ in 0..<30 { goal.recordReview() }
        XCTAssertTrue(goal.goalHitToday)

        // Two SRS due items, both kana abilities mastered, no brand-new kana
        masterAllKanaAbilities()
        let now = Date()
        srs.replaceAll([
            "kana-a": SRSCard(id: "kana-a", ease: 2.5, interval: 1, repetitions: 1,
                              dueDate: now.addingTimeInterval(-60),
                              lastReviewed: nil, lapses: 0, totalReviews: 0),
            "kana-b": SRSCard(id: "kana-b", ease: 2.5, interval: 1, repetitions: 1,
                              dueDate: now.addingTimeInterval(-30),
                              lastReviewed: nil, lapses: 0, totalReviews: 0)
        ])

        let recs = Planner(srs: srs, bkt: bkt, goal: goal)
            .recommend(limit: 8, kana: [], vocab: [])

        // Goal hit + only SRS due → shrink to top 2
        XCTAssertLessThanOrEqual(recs.count, 2)
        XCTAssertTrue(recs.allSatisfy { $0.reason.contains("到期") })
    }
}