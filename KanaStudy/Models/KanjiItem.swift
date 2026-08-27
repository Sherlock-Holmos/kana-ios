import Foundation

// MARK: - Kanji

struct KanjiItem: Codable, Identifiable, Hashable {
    let id: String
    let character: String
    let onReadings: [String]
    let kunReadings: [String]
    let meanings: [String]
    let examples: [String]?
    let level: String?

    var primaryMeaning: String {
        meanings.first ?? ""
    }

    var primaryReading: String {
        onReadings.first ?? kunReadings.first ?? ""
    }
}