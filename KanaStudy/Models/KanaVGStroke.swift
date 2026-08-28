import Foundation
import CoreGraphics

/// A single stroke from a kanji/kana template: an ordered polyline of CGPoints.
/// Strokes come from KanjiVG (CC BY-SA 3.0) parsed into normalized coordinates.
struct VGStroke: Codable, Hashable {
    /// Normalized to [-1, 1] unit box, centroid at origin, Y flipped to math-up.
    var points: [CGPoint]

    enum CodingKeys: String, CodingKey { case points }

    init(points: [CGPoint]) { self.points = points }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // JSON points come as [Double] pairs — [x, y].
        let raw = try c.decode([[Double]].self, forKey: .points)
        self.points = raw.map { CGPoint(x: $0[0], y: $0[1]) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(points.map { [Double($0.x), Double($0.y)] }, forKey: .points)
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