import Foundation

enum ContentError: Error {
    case fileNotFound(String)
    case decodeFailed(String, Error)
}

// MARK: - Content Service

final class ContentService {
    static let shared = ContentService()

    private var kanaCache: [KanaItem]?
    private var vocabCache: [VocabularyItem]?
    private var grammarCache: [GrammarItem]?
    private var kanjiCache: [KanjiItem]?
    private var sentenceCache: [SentenceItem]?

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    // MARK: - Loaders

    func loadKana() throws -> [KanaItem] {
        if let cached = kanaCache { return cached }
        let items = try decode([KanaItem].self, resource: "kana")
        kanaCache = items
        return items
    }

    func loadVocabulary() throws -> [VocabularyItem] {
        if let cached = vocabCache { return cached }
        let items = try decode([VocabularyItem].self, resource: "vocabulary")
        vocabCache = items
        return items
    }

    func loadGrammar() throws -> [GrammarItem] {
        if let cached = grammarCache { return cached }
        let items = try decode([GrammarItem].self, resource: "grammar")
        grammarCache = items
        return items
    }

    func loadKanji() throws -> [KanjiItem] {
        if let cached = kanjiCache { return cached }
        let items = try decode([KanjiItem].self, resource: "kanji")
        kanjiCache = items
        return items
    }

    func loadSentences() throws -> [SentenceItem] {
        if let cached = sentenceCache { return cached }
        let items = try decode([SentenceItem].self, resource: "sentence")
        sentenceCache = items
        return items
    }

    // MARK: - Convenience counts

    struct Counts {
        let kana: Int
        let vocabulary: Int
        let grammar: Int
        let kanji: Int
        let sentence: Int
    }

    func counts() throws -> Counts {
        Counts(
            kana: try loadKana().count,
            vocabulary: try loadVocabulary().count,
            grammar: try loadGrammar().count,
            kanji: try loadKanji().count,
            sentence: try loadSentences().count
        )
    }

    // MARK: - Private

    private func decode<T: Decodable>(_ type: T.Type, resource: String) throws -> T {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json", subdirectory: "Content")
                ?? Bundle.main.url(forResource: resource, withExtension: "json") else {
            throw ContentError.fileNotFound(resource)
        }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(T.self, from: data)
        } catch {
            throw ContentError.decodeFailed(resource, error)
        }
    }
}