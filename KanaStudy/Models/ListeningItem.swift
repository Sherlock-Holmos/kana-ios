import Foundation

// MARK: - Listening

struct ListeningItem: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let transcript: String
    let question: String
    let options: [String]
    let answer: String
    let translation: String?
    let level: String?
}