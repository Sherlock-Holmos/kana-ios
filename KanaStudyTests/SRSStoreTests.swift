import XCTest
@testable import KanaStudy

/// Tests the SM-2 spaced-repetition math used by SRSStore.grade(_:as:).
/// Each test runs against a fresh UserDefaults suite so the on-disk store
/// doesn't leak between cases.
final class SRSStoreTests: XCTestCase {

    private var store: SRSStore!
    private let testKey = "kana-study.srs.cards.v2"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: testKey)
        store = SRSStore()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: testKey)
        store = nil
        super.tearDown()
    }

    // MARK: - Enroll

    func testEnroll_createsCardWithZeroProgress() {
        store.enroll("kana-a")
        let card = store.cards["kana-a"]
        XCTAssertNotNil(card)
        XCTAssertEqual(card?.repetitions, 0)
        XCTAssertEqual(card?.interval, 0)
        XCTAssertEqual(card?.totalReviews, 0)
        XCTAssertNil(card?.lastReviewed)
    }

    func testEnroll_isIdempotent() {
        store.enroll("kana-a")
        store.enroll("kana-a")
        XCTAssertEqual(store.cards.count, 1)
    }

    // MARK: - Grade .again

    func testGradeAgain_resetsRepetitionsAndBumpsLapses() {
        store.enroll("kana-a")
        store.grade("kana-a", as: .good)   // reps = 1, interval = 1
        store.grade("kana-a", as: .good)   // reps = 2, interval = 6
        store.grade("kana-a", as: .again)  // reset
        let card = store.cards["kana-a"]
        XCTAssertEqual(card?.repetitions, 0)
        XCTAssertEqual(card?.lapses, 1)
    }

    func testGradeAgain_setsDueDateWithinTwoMinutes() {
        // Lapse interval = 0.0007 days ≈ 60s, but JSON round-trip may add a few ms.
        store.enroll("kana-a")
        let before = Date()
        store.grade("kana-a", as: .again)
        let card = store.cards["kana-a"]
        let delta = card?.dueDate.timeIntervalSince(before) ?? 0
        XCTAssertGreaterThan(delta, 0, "dueDate must be in the future")
        XCTAssertLessThan(delta, 120, "dueDate should be ~1 minute for a lapse")
    }

    // MARK: - Grade .good / .easy progression

    func testGradeGood_firstRep_setsIntervalToOneDay() {
        store.enroll("kana-a")
        store.grade("kana-a", as: .good)
        let card = store.cards["kana-a"]
        XCTAssertEqual(card?.repetitions, 1)
        XCTAssertEqual(card?.interval, 1)
        let dayInFuture = card?.dueDate.timeIntervalSinceNow ?? 0
        XCTAssertEqual(dayInFuture, 1 * 24 * 60 * 60, accuracy: 1.0)
    }

    func testGradeGood_secondRep_setsIntervalToSixDays() {
        store.enroll("kana-a")
        store.grade("kana-a", as: .good)
        store.grade("kana-a", as: .good)
        let card = store.cards["kana-a"]
        XCTAssertEqual(card?.repetitions, 2)
        XCTAssertEqual(card?.interval, 6)
    }

    func testGradeGood_thirdRep_multipliesByEase() {
        store.enroll("kana-a")
        store.grade("kana-a", as: .good)   // reps = 1, interval = 1
        store.grade("kana-a", as: .easy)   // reps = 2, interval = 6, ease bumped to 2.6
        let beforeEase = store.cards["kana-a"]!.ease
        store.grade("kana-a", as: .good)   // reps = 3, interval = 6 * ease
        let card = store.cards["kana-a"]
        XCTAssertEqual(card?.repetitions, 3)
        XCTAssertEqual(card?.interval, (6 * beforeEase).rounded())
    }

    // MARK: - Ease factor

    func testEase_neverDropsBelowMinimum() {
        store.enroll("kana-a")
        // Hammer with .again repeatedly to drive ease below floor
        for _ in 0..<20 {
            store.grade("kana-a", as: .again)
        }
        let card = store.cards["kana-a"]
        XCTAssertGreaterThanOrEqual(card?.ease ?? 0, 1.3, "ease must not drop below 1.3 (SM-2 floor)")
    }

    func testEase_increasesOnEasy() {
        store.enroll("kana-a")
        let before = store.cards["kana-a"]!.ease
        store.grade("kana-a", as: .easy)
        let after = store.cards["kana-a"]!.ease
        XCTAssertGreaterThan(after, before, "q=5 should raise ease")
    }

    // MARK: - dueItems

    func testDueItems_excludesFutureCards() {
        // Install one future-dated and one past-dated card directly.
        let now = Date()
        store.replaceAll([
            "future": SRSCard(id: "future", ease: 2.5, interval: 30, repetitions: 1,
                              dueDate: now.addingTimeInterval(60 * 60 * 24 * 30),
                              lastReviewed: nil, lapses: 0, totalReviews: 0),
            "overdue": SRSCard(id: "overdue", ease: 2.5, interval: 0, repetitions: 1,
                               dueDate: now.addingTimeInterval(-60),
                               lastReviewed: nil, lapses: 0, totalReviews: 0)
        ])

        let due = store.dueItems()
        XCTAssertFalse(due.contains { $0.id == "future" })
        XCTAssertTrue(due.contains { $0.id == "overdue" })
    }

    func testDueItems_sortsByDueDateAscending() {
        let now = Date()
        store.replaceAll([
            "a": SRSCard(id: "a", ease: 2.5, interval: 0, repetitions: 0,
                         dueDate: now.addingTimeInterval(-60), lastReviewed: nil,
                         lapses: 0, totalReviews: 0),
            "b": SRSCard(id: "b", ease: 2.5, interval: 0, repetitions: 0,
                         dueDate: now.addingTimeInterval(-300), lastReviewed: nil,
                         lapses: 0, totalReviews: 0),
            "c": SRSCard(id: "c", ease: 2.5, interval: 0, repetitions: 0,
                         dueDate: now.addingTimeInterval(-180), lastReviewed: nil,
                         lapses: 0, totalReviews: 0)
        ])
        let ids = store.dueItems().map(\.id)
        XCTAssertEqual(ids, ["b", "c", "a"],
                       "most-overdue (earliest dueDate) should come first")
    }
}