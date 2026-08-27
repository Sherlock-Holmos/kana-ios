import Foundation
import Combine

// MARK: - SRS Grade (full SM-2)

enum SRSGrade: Int, Codable, CaseIterable, Identifiable {
    case again = 0   // lapse
    case hard = 1    // q=3
    case good = 2    // q=4
    case easy = 3    // q=5

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .again: return "重来"
        case .hard:  return "困难"
        case .good:  return "记得"
        case .easy:  return "简单"
        }
    }

    /// SM-2 quality score (0–5). again maps to 2 (lapse not full failure).
    var quality: Int {
        switch self {
        case .again: return 2
        case .hard:  return 3
        case .good:  return 4
        case .easy:  return 5
        }
    }
}

struct SRSCard: Codable, Identifiable, Hashable {
    let id: String            // content id
    var ease: Double          // starting 2.5
    var interval: Double      // days until next review
    var repetitions: Int      // consecutive successful reviews
    var dueDate: Date
    var lastReviewed: Date?
    var lapses: Int           // count of times graded .again
    var totalReviews: Int

    static func new(id: String) -> SRSCard {
        SRSCard(
            id: id,
            ease: 2.5,
            interval: 0,
            repetitions: 0,
            dueDate: Date(),
            lastReviewed: nil,
            lapses: 0,
            totalReviews: 0
        )
    }
}

// MARK: - SRS Store (SM-2)

final class SRSStore: ObservableObject {
    @Published private(set) var cards: [String: SRSCard] = [:]

    private let storeKey = "kana-study.srs.cards.v2"
    private let defaults = UserDefaults.standard

    init() {
        load()
    }

    // MARK: Persistence

    private func load() {
        guard let data = defaults.data(forKey: storeKey) else { return }
        if let decoded = try? JSONDecoder().decode([String: SRSCard].self, from: data) {
            cards = decoded
        }
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(cards) else { return }
        defaults.set(encoded, forKey: storeKey)
        SyncTrigger.shared.bump()
    }

    /// Replace the entire card dictionary (used when merging a server-side envelope).
    func replaceAll(_ newCards: [String: SRSCard]) {
        cards = newCards
        save()
    }

    // MARK: Public

    func enroll(_ itemId: String) {
        guard cards[itemId] == nil else { return }
        cards[itemId] = .new(id: itemId)
        save()
    }

    /// Grade a card using SM-2 algorithm.
    func grade(_ itemId: String, as grade: SRSGrade) {
        var card = cards[itemId] ?? .new(id: itemId)
        let now = Date()
        let q = Double(grade.quality)

        // 1. Update ease factor
        let newEase = card.ease + (0.1 - (5.0 - q) * (0.08 + (5.0 - q) * 0.02))
        card.ease = max(1.3, newEase)

        // 2. Update repetition count + interval
        if grade == .again {
            card.repetitions = 0
            card.interval = 0.0007       // ~1 minute
            card.lapses += 1
        } else {
            card.repetitions += 1
            switch card.repetitions {
            case 1: card.interval = 1
            case 2: card.interval = 6
            default: card.interval = (card.interval * card.ease).rounded()
            }
        }

        card.dueDate = now.addingTimeInterval(card.interval * 24 * 60 * 60)
        card.lastReviewed = now
        card.totalReviews += 1

        cards[itemId] = card
        save()
    }

    func dueItems(now: Date = Date()) -> [SRSCard] {
        cards.values.filter { $0.dueDate <= now }.sorted { $0.dueDate < $1.dueDate }
    }

    var totalTracked: Int { cards.count }
    var totalReviews: Int { cards.values.reduce(0) { $0 + $1.totalReviews } }
    var totalLapses: Int { cards.values.reduce(0) { $0 + $1.lapses } }
}