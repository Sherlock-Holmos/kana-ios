import Foundation

enum ContentError: Error {
    case fileNotFound(String)
    case decodeFailed(String, Error)
}

// MARK: - Content Service

/// Actor-isolated content loader. All caches live inside actor state, so concurrent
/// callers (background tasks, SwiftUI `.task`, sync engine, etc.) cannot race.
///
/// IO is performed on a detached background thread (`Task.detached(priority: .userInitiated)`)
/// so `Data(contentsOf:)` and `JSONDecoder.decode` never block the actor executor —
/// a long JSON parse would otherwise stall every concurrent view that calls into
/// the service at the same time.
actor ContentService {
    static let shared = ContentService()

    private var kanaCache: [KanaItem]?
    private var vocabCache: [VocabularyItem]?
    private var grammarCache: [GrammarItem]?
    private var kanjiCache: [KanjiItem]?
    private var sentenceCache: [SentenceItem]?
    private var readingCache: [ReadingItem]?
    private var listeningCache: [ListeningItem]?
    private var questionBankCache: [QuestionVariant]?

    // MARK: - Loaders

    func loadKana() async throws -> [KanaItem] {
        if let cached = kanaCache { return cached }
        let items = try await Self.loadResource([KanaItem].self, resource: "kana")
        kanaCache = items
        return items
    }

    func loadVocabulary() async throws -> [VocabularyItem] {
        if let cached = vocabCache { return cached }
        let items = try await Self.loadResource([VocabularyItem].self, resource: "vocabulary")
        vocabCache = items
        return items
    }

    func loadGrammar() async throws -> [GrammarItem] {
        if let cached = grammarCache { return cached }
        let items = try await Self.loadResource([GrammarItem].self, resource: "grammar")
        grammarCache = items
        return items
    }

    func loadKanji() async throws -> [KanjiItem] {
        if let cached = kanjiCache { return cached }
        let items = try await Self.loadResource([KanjiItem].self, resource: "kanji")
        kanjiCache = items
        return items
    }

    func loadSentences() async throws -> [SentenceItem] {
        if let cached = sentenceCache { return cached }
        let items = try await Self.loadResource([SentenceItem].self, resource: "sentence")
        sentenceCache = items
        return items
    }

    func loadReading() async throws -> [ReadingItem] {
        if let cached = readingCache { return cached }
        let items = try await Self.loadResource([ReadingItem].self, resource: "reading")
        readingCache = items
        return items
    }

    func loadListening() async throws -> [ListeningItem] {
        if let cached = listeningCache { return cached }
        let items = try await Self.loadResource([ListeningItem].self, resource: "listening")
        listeningCache = items
        return items
    }

    func loadQuestionBank() async throws -> [QuestionVariant] {
        if let cached = questionBankCache { return cached }
        let items = try await Self.loadResource([QuestionVariant].self, resource: "question-bank")
        questionBankCache = items
        return items
    }

    // MARK: - Warm-cache (fire-and-forget)

    /// Background-warm the kana cache without forcing the caller to await — fires
    /// the decode off the main thread and stores the result so the first view that
    /// asks for kana lands on an instant cache hit.
    func warmKana() async {
        _ = try? await loadKana()
    }

    /// Background-warm the vocabulary cache (same pattern as warmKana).
    func warmVocabulary() async {
        _ = try? await loadVocabulary()
    }

    // MARK: - Convenience

    struct Counts: Sendable {
        let kana: Int
        let vocabulary: Int
        let grammar: Int
        let kanji: Int
        let sentence: Int
        let reading: Int
        let listening: Int
        let questionVariants: Int
    }

    /// Count every content collection in parallel. Useful for the progress dashboard.
    func counts() async throws -> Counts {
        async let kana = loadKana()
        async let vocab = loadVocabulary()
        async let grammar = loadGrammar()
        async let kanji = loadKanji()
        async let sentence = loadSentences()
        async let reading = loadReading()
        async let listening = loadListening()
        async let question = loadQuestionBank()
        return try await Counts(
            kana: kana.count,
            vocabulary: vocab.count,
            grammar: grammar.count,
            kanji: kanji.count,
            sentence: sentence.count,
            reading: reading.count,
            listening: listening.count,
            questionVariants: question.count
        )
    }

    // MARK: - Private (nonisolated static — runs off actor)

    /// Run `Data(contentsOf:)` + `JSONDecoder.decode` on a detached background thread.
    /// `static` makes this method nonisolated by default — `Task.detached` further
    /// guarantees it never blocks the actor's executor or the calling view's main thread.
    private static func loadResource<T: Decodable>(_ type: T.Type, resource: String) async throws -> T {
        try await Task.detached(priority: .userInitiated) {
            guard let url = Bundle.main.url(forResource: resource, withExtension: "json", subdirectory: "Content")
                    ?? Bundle.main.url(forResource: resource, withExtension: "json") else {
                throw ContentError.fileNotFound(resource)
            }
            let data = try Data(contentsOf: url)
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw ContentError.decodeFailed(resource, error)
            }
        }.value
    }
}