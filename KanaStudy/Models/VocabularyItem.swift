import Foundation

// MARK: - Vocabulary

struct VocabularyItem: Codable, Identifiable, Hashable {
    let id: String
    let expression: String
    let reading: String
    let meanings: [String]
    let partOfSpeech: String?
    let level: String?

    enum CodingKeys: String, CodingKey {
        case id, expression, reading, meanings
        case partOfSpeech, level
    }

    var primaryMeaning: String {
        meanings.first ?? ""
    }
}