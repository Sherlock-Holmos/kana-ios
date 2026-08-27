import Foundation

// MARK: - Question Bank 2.0

struct QuestionVariant: Codable, Identifiable, Hashable {
    let questionId: String
    let itemId: String
    let type: String            // kana | vocabulary | grammar | kanji | sentence | reading | listening
    let skill: String           // recognition | recall | production | meaning | reading
    let variantType: String     // e.g. kana-to-romaji, romaji-to-kana, meaning, etc.
    let difficulty: Int         // 1..N
    let abilities: [String]
    let topics: [String]
    let level: String

    var id: String { questionId }
}