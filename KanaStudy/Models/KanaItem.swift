import Foundation

// MARK: - Kana

struct KanaItem: Codable, Identifiable, Hashable {
    let id: String
    let script: String          // "hiragana" | "katakana"
    let kana: String
    let roman: String
    let row: String
    let category: String?
    let memory: String?
    let title: String
    let subtitle: String

    enum CodingKeys: String, CodingKey {
        case id, script, kana, roman, row, category, memory, title, subtitle
    }
}

extension KanaItem {
    var isHiragana: Bool { script == "hiragana" }
    var isKatakana: Bool { script == "katakana" }
}