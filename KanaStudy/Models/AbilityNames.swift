import Foundation

/// Human-readable labels for the internal ability IDs that appear in recommendations,
/// BKT progress, and review hints. Falls back to the raw id when unknown so new
/// abilities never crash the UI.
enum AbilityNames {
    static let mapping: [String: String] = [
        // kana
        "kana.recognition":      "假名识别",
        "kana.recall":           "假名回忆",
        // vocabulary
        "vocabulary.reading":    "词汇读音",
        "vocabulary.meaning":    "词汇含义",
        "vocabulary.production": "词汇产出",
        // kanji
        "kanji.reading":         "汉字读音",
        "kanji.meaning":         "汉字含义",
        "kanji.writing":         "汉字书写",
        // grammar / sentences
        "grammar.pattern":       "语法句型",
        "sentence.shadowing":    "例句跟读",
        // listening / reading
        "listening.comprehension": "听力理解",
        "reading.comprehension":   "阅读理解",
        // speaking
        "speaking.fluency":      "口语流利度",
        "speaking.pronunciation": "口语发音"
    ]

    static func displayName(for id: String) -> String {
        mapping[id] ?? id
    }
}

extension String {
    /// `id.displayName` reads better than the static helper at the call site.
    var abilityDisplayName: String { AbilityNames.displayName(for: self) }
}