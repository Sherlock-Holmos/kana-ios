import Foundation
import CoreGraphics

/// StrokeMatcher — DTW-based distance + recognition for kana handwriting.
///
/// Pipeline:
///   1. User's PKDrawing is rendered to a UIImage and contours are extracted
///      via VNDetectContoursRequest → array of strokes.
///   2. Each stroke is resampled to N points at uniform arc-length.
///   3. Each stroke is centroid-translated + scaled to a unit box.
///   4. DTW between two normalized strokes gives a scalar distance.
///   5. Greedy optimal pairing matches user's strokes to the template's
///      strokes; total distance is the sum across pairs (divided by N).
///   6. We pick the template with the lowest total distance; below a
///      threshold AND matching the prompted character → pass.
enum StrokeMatcher {

    static let samplesPerStroke = 24

    // MARK: - DTW core

    /// DTW distance between two equal-length point arrays.
    /// O(N²) with N = 24 = 576 ops, negligible.
    static func dtw(_ a: [CGPoint], _ b: [CGPoint]) -> Double {
        let n = a.count
        guard n > 0, b.count > 0 else { return .infinity }

        var prev = [Double](repeating: .infinity, count: n + 1)
        var curr = [Double](repeating: .infinity, count: n + 1)
        prev[0] = 0
        for i in 1...n {
            curr[0] = .infinity
            for j in 1...n {
                let cost = hypot(a[i-1].x - b[j-1].x, a[i-1].y - b[j-1].y)
                curr[j] = cost + min(prev[j], curr[j-1], prev[j-1])
            }
            swap(&prev, &curr)
        }
        return prev[n] / Double(n)   // average per-step cost
    }

    /// Resample a polyline (list of points) to N points at uniform arc-length.
    static func resample(_ points: [CGPoint], to n: Int) -> [CGPoint] {
        guard points.count > 1 else {
            return Array(repeating: points.first ?? .zero, count: n)
        }
        var seg: [Double] = []
        var total: Double = 0
        for i in 1..<points.count {
            let d = hypot(points[i].x - points[i-1].x, points[i].y - points[i-1].y)
            seg.append(d); total += d
        }
        if total == 0 { return Array(repeating: points[0], count: n) }

        var out: [CGPoint] = [points[0]]
        let step = total / Double(n - 1)
        var target = step
        var i = 1
        while i < points.count && out.count < n {
            let segLen = seg[i-1]
            while target <= segLen && out.count < n {
                let t = target / segLen
                let p = CGPoint(
                    x: points[i-1].x + t * (points[i].x - points[i-1].x),
                    y: points[i-1].y + t * (points[i].y - points[i-1].y)
                )
                out.append(p)
                target += step
            }
            target -= segLen
            i += 1
        }
        while out.count < n { out.append(points.last!) }
        return Array(out.prefix(n))
    }

    /// Translate each point so the centroid sits at origin, then scale so the
    /// max distance from the centroid is 1. Y stays in image coords (y-down)
    /// because both templates and user strokes live in the same frame.
    static func normalize(_ strokes: [[CGPoint]]) -> [[CGPoint]] {
        let allPoints = strokes.flatMap { $0 }
        guard !allPoints.isEmpty else { return strokes }
        let cx = allPoints.map(\.x).reduce(0, +) / Double(allPoints.count)
        let cy = allPoints.map(\.y).reduce(0, +) / Double(allPoints.count)
        let centered = strokes.map { stroke in
            stroke.map { CGPoint(x: $0.x - cx, y: $0.y - cy) }
        }
        let maxR = centered.flatMap { $0 }.map { hypot($0.x, $0.y) }.max() ?? 1
        let s = maxR == 0 ? 1 : 1 / maxR
        return centered.map { stroke in
            stroke.map { CGPoint(x: $0.x * s, y: $0.y * s) }
        }
    }

    // MARK: - multi-stroke matching

    /// Distance between two multi-stroke drawings, using greedy optimal pairing.
    /// If stroke counts differ, we leave out strokes that have no close match.
    static func distance(_ user: [[CGPoint]], _ template: [[CGPoint]]) -> Double {
        guard !user.isEmpty, !template.isEmpty else { return .infinity }
        let u = normalize(user.map { resample($0, to: samplesPerStroke) })
        let t = normalize(template.map { resample($0, to: samplesPerStroke) })

        // Greedy: repeatedly pair the worst-matched pair.
        var availableU = Array(0..<u.count)
        var availableT = Array(0..<t.count)
        var total: Double = 0
        var pairCount = 0

        while !availableU.isEmpty && !availableT.isEmpty {
            var bestDist = Double.infinity
            var bestPair: (Int, Int) = (0, 0)
            for ui in availableU {
                for ti in availableT {
                    let d = dtw(u[ui], t[ti])
                    if d < bestDist {
                        bestDist = d
                        bestPair = (ui, ti)
                    }
                }
            }
            total += bestDist
            pairCount += 1
            availableU.removeAll { $0 == bestPair.0 }
            availableT.removeAll { $0 == bestPair.1 }
        }
        // Penalty for unmatched strokes (count mismatch).
        let unmatched = abs(u.count - t.count)
        total += Double(unmatched) * 0.5
        guard pairCount > 0 else { return .infinity }
        return total / Double(pairCount)
    }

    // MARK: - recognition API

    struct RecognitionResult {
        let bestCharacter: String
        let bestDistance: Double
        let secondBestDistance: Double?
    }

    /// Find the template most similar to the user's drawing.
    static func recognize(_ userStrokes: [[CGPoint]]) -> RecognitionResult? {
        let templates = KanaVGLoader.all()
        guard !templates.isEmpty, !userStrokes.isEmpty else { return nil }

        var scored: [(String, Double)] = []
        for (character, template) in templates {
            let strokes = template.strokes.map { $0.points }
            let d = distance(userStrokes, strokes)
            scored.append((character, d))
        }
        scored.sort { $0.1 < $1.1 }

        guard let best = scored.first else { return nil }
        let second = scored.count > 1 ? scored[1].1 : nil
        return RecognitionResult(
            bestCharacter: best.0,
            bestDistance: best.1,
            secondBestDistance: second
        )
    }

    /// Verify the user wrote the prompted character. Returns (pass, debugInfo).
    static func verify(userStrokes: [[CGPoint]], expectedCharacter: String, threshold: Double = 0.18) -> (Bool, String) {
        // Distinguish the two "can't recognize" failure modes so the UI can
        // tell the user whether the problem is the matcher (no templates
        // loaded) or the Vision pipeline (no strokes extracted from the canvas).
        let templates = KanaVGLoader.all()
        if templates.isEmpty {
            return (false, "模板加载失败")
        }
        if userStrokes.isEmpty {
            return (false, "未检测到笔画，请再写一次")
        }
        guard let result = recognize(userStrokes) else {
            return (false, "无法识别笔画")
        }
        let matched = result.bestCharacter == expectedCharacter && result.bestDistance < threshold
        let confidence = result.secondBestDistance.map { result.bestDistance / max($0, 0.001) } ?? 1.0
        let debug = "matched \(result.bestCharacter) dist=\(String(format: "%.3f", result.bestDistance)) conf=\(String(format: "%.2f", confidence))"
        return (matched, debug)
    }
}