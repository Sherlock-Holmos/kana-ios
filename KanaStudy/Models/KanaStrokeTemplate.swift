import Foundation
import CoreGraphics

/// KanaStrokeTemplate — per-character expectations for the production handwriting
/// challenge. Today (MVP) covers stroke count + bounding-box aspect range. Next
/// pass adds DTW distance against KanjiVG path data so the validator can also
/// distinguish same-stroke-count kana.
///
/// Aspect ranges are width-over-height (w/h):
///   tall narrow (e.g. い / し / り) → 0.2 – 0.6
///   square (e.g. う / つ / ん) → 0.6 – 1.3
///   wide horizontal (e.g. あ / か / さ / は) → 1.0 – 1.7
struct KanaStrokeTemplate {
    let character: String
    let romaji: String
    let strokeCount: Int
    let minAspect: Double
    let maxAspect: Double
    /// Total path length must be at least this fraction of canvas perimeter
    /// so a quick tap doesn't qualify as drawing the character.
    let minPathCoverage: Double

    /// Score a user's drawing against this template. Returns the verdict and a
    /// human-readable reason on failure. The checks are intentionally permissive:
    /// finger-drawn strokes on iPhone naturally drift ±1 in count and aspect,
    // and we don't want to reject legitimate attempts. KanjiVG + DTW replaces
    /// this with real character recognition next week.
    static func evaluate(
        _ template: KanaStrokeTemplate,
        strokeCount: Int,
        aspect: Double,
        pathCoverage: Double
    ) -> Verdict {
        // Allow ±1 stroke tolerance for finger drawings (decorative dots, hooks,
        // double-lifts that the stroke counter treats as separate strokes).
        if abs(strokeCount - template.strokeCount) > 1 {
            return .fail("笔数不对：\(template.character) 是 \(template.strokeCount) 画，你画了 \(strokeCount) 画")
        }
        // Aspect range widened by 0.15 on each side compared to the data table
        // so tall-narrow characters (し, に, り) and wide characters (あ, か)
        // don't trip the gate when drawn naturally.
        let aspectMin = max(0.05, template.minAspect - 0.15)
        let aspectMax = template.maxAspect + 0.15
        if aspect < aspectMin {
            return .fail("形状不对：\(template.character) 偏瘦")
        }
        if aspect > aspectMax {
            return .fail("形状不对：\(template.character) 偏扁")
        }
        // Path coverage is a coarse "did the user fill the canvas at all" check.
        // Tall-narrow characters naturally cover less than wide ones, so the
        // global threshold is low (0.12). Real per-character thresholds would
        // come from KanjiVG.
        if pathCoverage < 0.12 {
            return .fail("画得太少，请重画")
        }
        return .pass
    }

    enum Verdict {
        case pass
        case fail(String)
    }
}

/// Canonical stroke counts (modern form, per Japanese 文部科学省 guidelines).
/// Aspect ranges are an MVP heuristic — they keep out garbage, but a user who
/// draws another kana with the same count + aspect may slip through. Real
/// recognition comes next week from KanjiVG + DTW.
enum KanaStrokeLibrary {
    static let templates: [String: KanaStrokeTemplate] = [
        // a i u e o
        "あ": .init(character: "あ", romaji: "a",  strokeCount: 3, minAspect: 1.0, maxAspect: 1.7, minPathCoverage: 0.6),
        "い": .init(character: "い", romaji: "i",  strokeCount: 2, minAspect: 0.2, maxAspect: 0.55, minPathCoverage: 0.4),
        "う": .init(character: "う", romaji: "u",  strokeCount: 2, minAspect: 0.6, maxAspect: 1.2, minPathCoverage: 0.4),
        "え": .init(character: "え", romaji: "e",  strokeCount: 3, minAspect: 0.7, maxAspect: 1.3, minPathCoverage: 0.5),
        "お": .init(character: "お", romaji: "o",  strokeCount: 3, minAspect: 0.9, maxAspect: 1.4, minPathCoverage: 0.6),

        // ka ki ku ke ko
        "か": .init(character: "か", romaji: "ka", strokeCount: 3, minAspect: 1.0, maxAspect: 1.5, minPathCoverage: 0.6),
        "き": .init(character: "き", romaji: "ki", strokeCount: 4, minAspect: 0.4, maxAspect: 0.9, minPathCoverage: 0.7),
        "く": .init(character: "く", romaji: "ku", strokeCount: 2, minAspect: 0.4, maxAspect: 1.0, minPathCoverage: 0.3),
        "け": .init(character: "け", romaji: "ke", strokeCount: 3, minAspect: 0.5, maxAspect: 1.1, minPathCoverage: 0.5),
        "こ": .init(character: "こ", romaji: "ko", strokeCount: 2, minAspect: 0.8, maxAspect: 1.5, minPathCoverage: 0.4),

        // sa shi su se so
        "さ": .init(character: "さ", romaji: "sa", strokeCount: 3, minAspect: 1.0, maxAspect: 1.7, minPathCoverage: 0.6),
        "し": .init(character: "し", romaji: "shi", strokeCount: 3, minAspect: 0.2, maxAspect: 0.55, minPathCoverage: 0.5),
        "す": .init(character: "す", romaji: "su", strokeCount: 2, minAspect: 0.7, maxAspect: 1.3, minPathCoverage: 0.4),
        "せ": .init(character: "せ", romaji: "se", strokeCount: 3, minAspect: 0.7, maxAspect: 1.3, minPathCoverage: 0.5),
        "そ": .init(character: "そ", romaji: "so", strokeCount: 3, minAspect: 1.0, maxAspect: 1.6, minPathCoverage: 0.6),

        // ta chi tsu te to
        "た": .init(character: "た", romaji: "ta", strokeCount: 4, minAspect: 0.9, maxAspect: 1.5, minPathCoverage: 0.7),
        "ち": .init(character: "ち", romaji: "chi", strokeCount: 2, minAspect: 0.6, maxAspect: 1.2, minPathCoverage: 0.4),
        "つ": .init(character: "つ", romaji: "tsu", strokeCount: 2, minAspect: 0.6, maxAspect: 1.2, minPathCoverage: 0.3),
        "て": .init(character: "て", romaji: "te", strokeCount: 2, minAspect: 0.4, maxAspect: 0.9, minPathCoverage: 0.4),
        "と": .init(character: "と", romaji: "to", strokeCount: 2, minAspect: 0.7, maxAspect: 1.3, minPathCoverage: 0.4),

        // na ni nu ne no
        "な": .init(character: "な", romaji: "na", strokeCount: 4, minAspect: 0.6, maxAspect: 1.1, minPathCoverage: 0.7),
        "に": .init(character: "に", romaji: "ni", strokeCount: 3, minAspect: 0.3, maxAspect: 0.7, minPathCoverage: 0.5),
        "ぬ": .init(character: "ぬ", romaji: "nu", strokeCount: 2, minAspect: 0.6, maxAspect: 1.2, minPathCoverage: 0.4),
        "ね": .init(character: "ね", romaji: "ne", strokeCount: 3, minAspect: 0.6, maxAspect: 1.2, minPathCoverage: 0.5),
        "の": .init(character: "の", romaji: "no", strokeCount: 2, minAspect: 0.8, maxAspect: 1.3, minPathCoverage: 0.4),

        // ha hi fu he ho
        "は": .init(character: "は", romaji: "ha", strokeCount: 3, minAspect: 1.0, maxAspect: 1.6, minPathCoverage: 0.6),
        "ひ": .init(character: "ひ", romaji: "hi", strokeCount: 2, minAspect: 0.6, maxAspect: 1.2, minPathCoverage: 0.4),
        "ふ": .init(character: "ふ", romaji: "fu", strokeCount: 4, minAspect: 0.6, maxAspect: 1.2, minPathCoverage: 0.7),
        "へ": .init(character: "へ", romaji: "he", strokeCount: 1, minAspect: 0.7, maxAspect: 1.4, minPathCoverage: 0.2),
        "ほ": .init(character: "ほ", romaji: "ho", strokeCount: 4, minAspect: 0.7, maxAspect: 1.2, minPathCoverage: 0.7),

        // ma mi mu me mo
        "ま": .init(character: "ま", romaji: "ma", strokeCount: 3, minAspect: 0.7, maxAspect: 1.2, minPathCoverage: 0.6),
        "み": .init(character: "み", romaji: "mi", strokeCount: 3, minAspect: 0.6, maxAspect: 1.1, minPathCoverage: 0.5),
        "む": .init(character: "む", romaji: "mu", strokeCount: 4, minAspect: 0.6, maxAspect: 1.1, minPathCoverage: 0.7),
        "め": .init(character: "め", romaji: "me", strokeCount: 3, minAspect: 0.7, maxAspect: 1.2, minPathCoverage: 0.5),
        "も": .init(character: "も", romaji: "mo", strokeCount: 3, minAspect: 0.7, maxAspect: 1.2, minPathCoverage: 0.5),

        // ya yu yo
        "や": .init(character: "や", romaji: "ya", strokeCount: 2, minAspect: 0.9, maxAspect: 1.4, minPathCoverage: 0.4),
        "ゆ": .init(character: "ゆ", romaji: "yu", strokeCount: 2, minAspect: 0.9, maxAspect: 1.4, minPathCoverage: 0.4),
        "よ": .init(character: "よ", romaji: "yo", strokeCount: 2, minAspect: 0.9, maxAspect: 1.4, minPathCoverage: 0.4),

        // ra ri ru re ro
        "ら": .init(character: "ら", romaji: "ra", strokeCount: 2, minAspect: 0.5, maxAspect: 1.0, minPathCoverage: 0.4),
        "り": .init(character: "り", romaji: "ri", strokeCount: 2, minAspect: 0.3, maxAspect: 0.65, minPathCoverage: 0.4),
        "る": .init(character: "る", romaji: "ru", strokeCount: 2, minAspect: 0.6, maxAspect: 1.0, minPathCoverage: 0.4),
        "れ": .init(character: "れ", romaji: "re", strokeCount: 2, minAspect: 0.6, maxAspect: 1.0, minPathCoverage: 0.4),
        "ろ": .init(character: "ろ", romaji: "ro", strokeCount: 2, minAspect: 0.5, maxAspect: 1.0, minPathCoverage: 0.4),

        // wa wo n
        "わ": .init(character: "わ", romaji: "wa", strokeCount: 2, minAspect: 0.7, maxAspect: 1.1, minPathCoverage: 0.4),
        "を": .init(character: "を", romaji: "wo", strokeCount: 3, minAspect: 0.7, maxAspect: 1.2, minPathCoverage: 0.5),
        "ん": .init(character: "ん", romaji: "n",  strokeCount: 2, minAspect: 0.7, maxAspect: 1.1, minPathCoverage: 0.4)
    ]

    /// Order used by the challenge pool — keeps the UI label aligned with character.
    static let allCharacters: [String] = [
        "あ","い","う","え","お",
        "か","き","く","け","こ",
        "さ","し","す","せ","そ",
        "た","ち","つ","て","と",
        "な","に","ぬ","ね","の",
        "は","ひ","ふ","へ","ほ",
        "ま","み","む","め","も",
        "や","ゆ","よ",
        "ら","り","る","れ","ろ",
        "わ","を","ん"
    ]

    static func template(for character: String) -> KanaStrokeTemplate? {
        templates[character]
    }
}

/// Aggregate metrics for a single PKDrawing, used by the validator.
struct DrawingMetrics {
    let strokeCount: Int
    /// width / height of the drawing's bounding box.
    let aspect: Double
    /// Total path length / canvas perimeter. Rough proxy for "how much did the user draw".
    let pathCoverage: Double
}