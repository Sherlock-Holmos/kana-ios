import Foundation

// MARK: - Question Bank 2.0 — Exercise Engine
//
// Generates a presentation-ready exercise for a given question variant, drawing
// distractors from the same content pool. Distractors are randomized per session
// but stable per item.

struct ExercisePrompt: Identifiable, Hashable {
    let id: String            // questionId
    let itemId: String
    let type: String          // kana | vocabulary | ...
    let skill: String
    let prompt: String        // question text shown to user
    let correctAnswer: String
    let options: [String]     // 2..6 options, shuffled
    let abilities: [String]
}

final class ExerciseEngine {
    static let shared = ExerciseEngine()

    /// Generate an exercise for a given question variant.
    /// Currently supports kana + vocabulary variants; other types fall back to text-only display.
    func makeExercise(for variant: QuestionVariant,
                     kana: [KanaItem],
                     vocab: [VocabularyItem]) -> ExercisePrompt? {
        switch variant.type {
        case "kana":
            return makeKanaExercise(for: variant, kana: kana)
        case "vocabulary":
            return makeVocabExercise(for: variant, vocab: vocab)
        default:
            return nil
        }
    }

    // MARK: - Kana

    private func makeKanaExercise(for variant: QuestionVariant, kana: [KanaItem]) -> ExercisePrompt? {
        guard let target = kana.first(where: { $0.id == variant.itemId }) else { return nil }
        let pool = kana.filter { $0.script == target.script }

        switch variant.variantType {
        case "kana-to-romaji":
            let distractors = pool.filter { $0.id != target.id }.shuffled().prefix(3).map { $0.roman }
            return ExercisePrompt(
                id: variant.questionId,
                itemId: variant.itemId,
                type: variant.type,
                skill: variant.skill,
                prompt: "这个假名的罗马音是什么？  \(target.kana)",
                correctAnswer: target.roman,
                options: ([target.roman] + Array(distractors)).shuffled(),
                abilities: variant.abilities
            )
        case "romaji-to-kana":
            let distractors = pool.filter { $0.id != target.id }.shuffled().prefix(3).map { $0.kana }
            return ExercisePrompt(
                id: variant.questionId,
                itemId: variant.itemId,
                type: variant.type,
                skill: variant.skill,
                prompt: "罗马音「\(target.roman)」对应的假名是？",
                correctAnswer: target.kana,
                options: ([target.kana] + Array(distractors)).shuffled(),
                abilities: variant.abilities
            )
        default:
            return nil
        }
    }

    // MARK: - Vocabulary

    private func makeVocabExercise(for variant: QuestionVariant, vocab: [VocabularyItem]) -> ExercisePrompt? {
        guard let target = vocab.first(where: { $0.id == variant.itemId }) else { return nil }

        switch variant.variantType {
        case "meaning":
            let distractors = vocab.filter { $0.id != target.id }.shuffled().prefix(3).map { $0.primaryMeaning }
            return ExercisePrompt(
                id: variant.questionId,
                itemId: variant.itemId,
                type: variant.type,
                skill: variant.skill,
                prompt: "「\(target.expression)」的意思是？",
                correctAnswer: target.primaryMeaning,
                options: ([target.primaryMeaning] + Array(distractors)).shuffled(),
                abilities: variant.abilities
            )
        case "reading":
            let distractors = vocab.filter { $0.id != target.id }.shuffled().prefix(3).map { $0.reading }
            return ExercisePrompt(
                id: variant.questionId,
                itemId: variant.itemId,
                type: variant.type,
                skill: variant.skill,
                prompt: "「\(target.expression)」的读音是？",
                correctAnswer: target.reading,
                options: ([target.reading] + Array(distractors)).shuffled(),
                abilities: variant.abilities
            )
        case "production":
            let distractors = vocab.filter { $0.id != target.id }.shuffled().prefix(3).map { $0.expression }
            return ExercisePrompt(
                id: variant.questionId,
                itemId: variant.itemId,
                type: variant.type,
                skill: variant.skill,
                prompt: "「\(target.primaryMeaning)」的日语单词是？",
                correctAnswer: target.expression,
                options: ([target.expression] + Array(distractors)).shuffled(),
                abilities: variant.abilities
            )
        default:
            return nil
        }
    }

    // MARK: - Batch

    /// Sample a session of N exercises from the question bank, balanced across skills.
    func sessionSample(bank: [QuestionVariant], count: Int = 10) -> [QuestionVariant] {
        let grouped = Dictionary(grouping: bank, by: { $0.skill })
        var picked: [QuestionVariant] = []
        let skills = Array(grouped.keys)
        for skill in skills {
            guard let pool = grouped[skill] else { continue }
            let take = max(1, count / skills.count)
            picked.append(contentsOf: pool.shuffled().prefix(take))
        }
        return Array(picked.shuffled().prefix(count))
    }
}