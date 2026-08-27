import Foundation

// MARK: - Grammar

struct GrammarItem: Codable, Identifiable, Hashable {
    let id: String
    let pattern: String
    let meanings: [String]
    let formation: [String]?
    let explanation: String?
    let level: String?
    let tags: [String]?

    var primaryMeaning: String {
        meanings.first ?? ""
    }
}