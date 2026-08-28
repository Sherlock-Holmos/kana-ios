import Foundation
import CoreGraphics

/// A single stroke from a kanji/kana template: an ordered polyline of CGPoints.
/// Strokes come from KanjiVG (CC BY-SA 3.0) parsed into normalized coordinates.
struct VGStroke: Codable, Hashable {
    /// Normalized to [-1, 1] unit box, centroid at origin, Y flipped to math-up.
    var points: [CGPoint]

    init(points: [CGPoint]) { self.points = points }

    // JSON format on disk:
    //   "strokes": [
    //     [[x, y], [x, y], ...],
    //     [[x, y], [x, y], ...]
    //   ]
    // i.e. each stroke is an UNWRAPPED array of [x, y] pairs, not a {"points": ...}
    // object. The bundled kana-vg-data.json uses this flat shape.
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var pts: [CGPoint] = []
        while !container.isAtEnd {
            let pair = try container.decode([Double].self)
            if pair.count >= 2 {
                pts.append(CGPoint(x: pair[0], y: pair[1]))
            }
        }
        self.points = pts
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for p in points {
            try container.encode([Double(p.x), Double(p.y)])
        }
    }
}

/// One kana's full template: romaji label + ordered list of strokes.
struct VGCharacter: Codable, Hashable {
    let romaji: String
    let strokes: [VGStroke]
}

/// Loader for the bundled kana-vg-data.json. Caches in memory after first load.
enum KanaVGLoader {
    private static var cache: [String: VGCharacter] = [:]

    static func all() -> [String: VGCharacter] {
        if cache.isEmpty { load() }
        return cache
    }

    static func template(for character: String) -> VGCharacter? {
        if cache.isEmpty { load() }
        return cache[character]
    }

    private static func load() {
        guard let url = Bundle.main.url(forResource: "kana-vg-data", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("[KanaVGLoader] kana-vg-data.json not found in bundle")
            return
        }
        do {
            cache = try JSONDecoder().decode([String: VGCharacter].self, from: data)
            print("[KanaVGLoader] loaded \(cache.count) kana templates")
        } catch {
            print("[KanaVGLoader] decode failed: \(error)")
        }
    }
}