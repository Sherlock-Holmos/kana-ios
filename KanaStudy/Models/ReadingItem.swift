import Foundation

// MARK: - Reading

struct ReadingItem: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let passage: String
    let question: String
    let options: [String]
    let answer: String
    let translation: String?
    let level: String?
    let tags: [String]?
}