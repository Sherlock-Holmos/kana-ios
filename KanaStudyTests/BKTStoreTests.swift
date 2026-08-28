import XCTest
@testable import KanaStudy

/// Tests the Bayesian Knowledge Tracing math used by BKTStore.update(abilityId:correct:).
final class BKTStoreTests: XCTestCase {

    private var store: BKTStore!
    private let testKey = "kana-study.bkt.v1"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: testKey)
        store = BKTStore()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: testKey)
        store = nil
        super.tearDown()
    }

    // MARK: - Initialization

    func testEnsure_seedsAtInitialProbability() {
        store.ensure("kana.recognition")
        let m = store.masteries["kana.recognition"]!
        XCTAssertEqual(m.pMaster, 0.20, accuracy: 0.001,
                       "first-time ability should start at pInit = 0.20")
    }

    func testEnsure_isIdempotent() {
        store.ensure("kana.recognition")
        store.update(abilityId: "kana.recognition", correct: true)
        let firstMastery = store.masteries["kana.recognition"]!.pMaster
        store.ensure("kana.recognition")  // must not reset
        XCTAssertEqual(store.masteries["kana.recognition"]!.pMaster, firstMastery,
                       accuracy: 0.0001)
    }

    // MARK: - Bayesian update

    /// P(L_0) = 0.20, P(T) = 0.25, P(S) = 0.10, P(G) = 0.25
    /// P(L_1 | correct) = [0.20 * (1 - 0.10)] / [0.20 * (1 - 0.10) + 0.80 * 0.25]
    ///                  = 0.18 / (0.18 + 0.20) = 0.4737
    /// P(L_1) = 0.4737 + (1 - 0.4737) * 0.25 = 0.6053
    func testUpdate_correctOnFirstAttempt_raisesMastery() {
        store.ensure("kana.recognition")
        store.update(abilityId: "kana.recognition", correct: true)
        let m = store.masteries["kana.recognition"]!
        XCTAssertEqual(m.pMaster, 0.6053, accuracy: 0.01)
        XCTAssertEqual(m.opportunities, 1)
    }

    /// P(L_1 | wrong) = [0.20 * 0.10] / [0.20 * 0.10 + 0.80 * (1 - 0.25)]
    ///                  = 0.02 / (0.02 + 0.60) = 0.0323
    /// P(L_1) = 0.0323 + (1 - 0.0323) * 0.25 = 0.2742
    func testUpdate_wrongOnFirstAttempt_lowersMasteryButNotBelowZero() {
        store.ensure("kana.recognition")
        store.update(abilityId: "kana.recognition", correct: false)
        let m = store.masteries["kana.recognition"]!
        XCTAssertEqual(m.pMaster, 0.2742, accuracy: 0.01)
        XCTAssertEqual(m.opportunities, 1)
    }

    /// Seed mastery at the upper end and verify many correct updates still clamp at 1.0.
    func testUpdate_keepsMasteryWithinUpperBound() {
        let seeded = BKTMastery(abilityId: "x", pMaster: 0.95,
                                opportunities: 0, lastUpdated: Date())
        store.replaceAll(["x": seeded])
        for _ in 0..<200 { store.update(abilityId: "x", correct: true) }
        XCTAssertLessThanOrEqual(store.masteries["x"]!.pMaster, 1.0)
    }

    /// Seed mastery very low and verify many wrong updates still clamp at 0.0.
    func testUpdate_keepsMasteryWithinLowerBound() {
        let seeded = BKTMastery(abilityId: "x", pMaster: 0.01,
                                opportunities: 0, lastUpdated: Date())
        store.replaceAll(["x": seeded])
        for _ in 0..<200 { store.update(abilityId: "x", correct: false) }
        XCTAssertGreaterThanOrEqual(store.masteries["x"]!.pMaster, 0.0)
    }

    func testUpdate_repeatedCorrectsConvergeToOne() {
        store.ensure("x")
        for _ in 0..<30 { store.update(abilityId: "x", correct: true) }
        XCTAssertGreaterThan(store.masteries["x"]!.pMaster, 0.95)
    }

    func testUpdate_repeatedWrongsConvergeBelowInitial() {
        // BKT with pS=0.10, pG=0.25, pT=0.25 has a steady-state for wrong
        // outcomes at ~0.29 — wrong updates never reduce mastery all the way
        // to zero because (1-pG) keeps a residual "didn't know" probability.
        // Verify mastery drops well below the initial 0.20 and converges.
        store.ensure("x")
        for _ in 0..<30 { store.update(abilityId: "x", correct: false) }
        let final = store.masteries["x"]!.pMaster
        XCTAssertLessThan(final, 0.20, "wrong updates must reduce mastery below pInit")
        XCTAssert(final > 0.25 && final < 0.32,
                  "expected ~0.29 BKT steady state, got \(final)")
    }

    // MARK: - Queries

    func testMastery_returnsInitialForUnknownAbility() {
        XCTAssertEqual(store.mastery(for: "never.touched"), 0.20, accuracy: 0.001)
    }

    func testUnmastered_sortsByAscendingMastery() {
        store.ensure("a"); store.update(abilityId: "a", correct: true)   // grows
        store.ensure("b"); store.update(abilityId: "b", correct: false)  // stays low
        store.ensure("c"); store.update(abilityId: "c", correct: true)
        let unmastered = store.unmastered(threshold: 0.95, limit: 10).map(\.abilityId)
        XCTAssertEqual(unmastered.first, "b",
                       "lowest-mastery ability should come first")
    }

    func testUnmastered_excludesHighMastery() {
        store.ensure("strong")
        for _ in 0..<30 { store.update(abilityId: "strong", correct: true) }
        XCTAssertFalse(store.unmastered(threshold: 0.95, limit: 10)
            .contains { $0.abilityId == "strong" })
    }

    func testTotalOpportunities_sumsAllAbilities() {
        store.ensure("a"); store.ensure("b"); store.ensure("c")
        store.update(abilityId: "a", correct: true)
        store.update(abilityId: "b", correct: false)
        store.update(abilityId: "b", correct: true)
        XCTAssertEqual(store.totalOpportunities, 3)
    }

    func testReplaceAll_overwritesMasteries() {
        store.ensure("a"); store.update(abilityId: "a", correct: true)
        let replacement = BKTMastery(abilityId: "z", pMaster: 0.5,
                                     opportunities: 7, lastUpdated: Date())
        store.replaceAll(["z": replacement])
        XCTAssertEqual(store.masteries.count, 1)
        XCTAssertEqual(store.masteries["z"]?.opportunities, 7)
        XCTAssertNil(store.masteries["a"])
    }
}