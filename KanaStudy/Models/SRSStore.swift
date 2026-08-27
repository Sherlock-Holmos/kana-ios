import Foundation
import Combine

// MARK: - SRS Card State

enum SRSGrade: Int, Codable, CaseIterable, Identifiable {
    case again = 0
    case hard = 1
    case good = 2
    case easy = 3

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .again: return "重来"
        case .hard:  return "困难"
        case .good:  return "记得"
        case .easy:  return "简单"
        }
    }

    /// Interval multiplier in days (simplified SM-2).
    var multiplier: Double {
        switch self {
        case .again: return 0.0   // relaunch today
        case .hard:  return 1.2
        case .good:  return 2.0
        case .easy:  return 3.0
        }
    }
}

struct SRSCard: Codable, Identifiable, Hashable {
    let id: String            // matches content id (e.g. "hiragana:あ")
    var ease: Double          // starting 2.5
    var interval: Double      // days until next review
    var repetitions: Int
    var dueDate: Date
    var lastReviewed: Date?

    static func new(id: String) -> SRSCard {
        SRSCard(
            id: id,
            ease: 2.5,
            interval: 0,
            repetitions: 0,
            dueDate: Date(),
            lastReviewed: nil
        )
    }
}

// MARK: - SRS Store

final class SRSStore: ObservableObject {
    @Published private(set) var cards: [String: SRSCard] = [:]

    private let storeKey = "kana-study.srs.cards.v1"
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
    }

    // MARK: Public

    /// Enroll an item if it isn't tracked yet.
    func enroll(_ itemId: String) {
        guard cards[itemId] == nil else { return }
        cards[itemId] = .new(id: itemId)
        save()
    }

    /// Grade a card and reschedule.
    func grade(_ itemId: String, as grade: SRSGrade) {
        var card = cards[itemId] ?? .new(id: itemId)
        let now = Date()

        switch grade {
        case .again:
            card.repetitions = 0
            card.interval = 0.0007   // ~1 minute
        case .hard:
            card.repetitions += 1
            card.ease = max(1.3, card.ease - 0.15)
            card.interval = max(1, card.interval) * 1.2
        case .good:
            card.repetitions += 1
            if card.repetitions == 1 {
                card.interval = 1
            } else if card.repetitions == 2 {
                card.interval = 3
            } else {
                card.interval = card.interval * card.ease
            }
        case .easy:
            card.repetitions += 1
            card.ease = min(3.0, card.ease + 0.10)
            if card.repetitions == 1 {
                card.interval = 4
            } else {
                card.interval = card.interval * card.ease * 1.3
            }
        }

        card.dueDate = now.addingTimeInterval(card.interval * 24 * 60 * 60)
        card.lastReviewed = now
        cards[itemId] = card
        save()
    }

    /// Items due today (or earlier).
    func dueItems(now: Date = Date()) -> [SRSCard] {
        cards.values.filter { $0.dueDate <= now }.sorted { $0.dueDate < $1.dueDate }
    }

    var totalTracked: Int { cards.count }
    var totalReviews: Int { cards.values.reduce(0) { $0 + $1.repetitions } }
}