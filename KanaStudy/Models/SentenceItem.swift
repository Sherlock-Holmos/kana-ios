import Foundation

// MARK: - Sentence

struct SentenceItem: Codable, Identifiable, Hashable {
    let id: String
    let jp: String
    let reading: String?
    let zh: String?
    let vocabulary: [String]?
    let grammar: [String]?
    let level: String?
}