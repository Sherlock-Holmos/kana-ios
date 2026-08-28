import XCTest
import CoreGraphics
@testable import KanaStudy

/// Tests the pure-math core of StrokeMatcher: DTW, resample, normalize,
/// and multi-stroke distance. We deliberately do NOT call recognize()
/// or verify() because those depend on KanaVGLoader which reads bundled
/// SVGs that aren't available in the unit-test target.
final class StrokeMatcherTests: XCTestCase {

    // MARK: - dtw

    func testDtw_identicalStrokes_returnsZero() {
        let a: [CGPoint] = (0..<10).map { i in
            CGPoint(x: CGFloat(i), y: CGFloat(i) * 2)
        }
        XCTAssertEqual(StrokeMatcher.dtw(a, a), 0.0, accuracy: 1e-9)
    }

    func testDtw_isSymmetric() {
        let a: [CGPoint] = [
            CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1),
            CGPoint(x: 2, y: 2), CGPoint(x: 3, y: 3)
        ]
        let b: [CGPoint] = [
            CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 2),
            CGPoint(x: 2, y: 4), CGPoint(x: 3, y: 6)
        ]
        XCTAssertEqual(StrokeMatcher.dtw(a, b),
                       StrokeMatcher.dtw(b, a),
                       accuracy: 1e-9,
                       "DTW cost matrix is symmetric → distance(a,b) == distance(b,a)")
    }

    func testDtw_disjointStrokes_returnsLargeValue() {
        let a: [CGPoint] = (0..<5).map { CGPoint(x: CGFloat($0), y: 0) }
        let b: [CGPoint] = (0..<5).map { CGPoint(x: 100 + CGFloat($0), y: 100) }
        let d = StrokeMatcher.dtw(a, b)
        XCTAssertGreaterThan(d, 50.0,
                             "two strokes far apart should yield a large DTW distance")
    }

    func testDtw_emptyInput_returnsInfinity() {
        let a: [CGPoint] = []
        let b: [CGPoint] = [CGPoint(x: 0, y: 0)]
        XCTAssertEqual(StrokeMatcher.dtw(a, b), .infinity)
        XCTAssertEqual(StrokeMatcher.dtw(b, a), .infinity)
    }

    // MARK: - resample

    func testResample_returnsRequestedCount() {
        let pts: [CGPoint] = (0..<50).map { CGPoint(x: CGFloat($0), y: CGFloat($0)) }
        XCTAssertEqual(StrokeMatcher.resample(pts, to: 24).count, 24)
        XCTAssertEqual(StrokeMatcher.resample(pts, to: 1).count, 1)
    }

    func testResample_startsAtFirstPoint() {
        let pts: [CGPoint] = (0..<20).map { CGPoint(x: CGFloat($0), y: 0) }
        let out = StrokeMatcher.resample(pts, to: 24)
        XCTAssertEqual(out.first?.x ?? -1, 0.0, accuracy: 1e-9)
    }

    func testResample_endsAtLastPoint() {
        let pts: [CGPoint] = (0..<20).map { CGPoint(x: CGFloat($0), y: 0) }
        let out = StrokeMatcher.resample(pts, to: 24)
        XCTAssertEqual(out.last?.x ?? -1, 19.0, accuracy: 1e-9)
    }

    func testResample_singlePoint_returnsCopies() {
        let pts: [CGPoint] = [CGPoint(x: 5, y: 5)]
        let out = StrokeMatcher.resample(pts, to: 24)
        XCTAssertEqual(out.count, 24)
        XCTAssertTrue(out.allSatisfy { $0.x == 5 && $0.y == 5 })
    }

    // MARK: - normalize

    func testNormalize_centroidAtOrigin() {
        let strokes: [[CGPoint]] = [[
            CGPoint(x: 0, y: 0),
            CGPoint(x: 2, y: 0),
            CGPoint(x: 2, y: 2),
            CGPoint(x: 0, y: 2)
        ]]
        let out = StrokeMatcher.normalize(strokes)
        let all = out.flatMap { $0 }
        let cx: CGFloat = all.map(\.x).reduce(0, +) / CGFloat(all.count)
        let cy: CGFloat = all.map(\.y).reduce(0, +) / CGFloat(all.count)
        XCTAssertEqual(Double(cx), 0.0, accuracy: 1e-9)
        XCTAssertEqual(Double(cy), 0.0, accuracy: 1e-9)
    }

    func testNormalize_maxRadiusIsOne() {
        let strokes: [[CGPoint]] = [[
            CGPoint(x: 0, y: 0),
            CGPoint(x: 4, y: 0),
            CGPoint(x: 4, y: 4),
            CGPoint(x: 0, y: 4)
        ]]
        let out = StrokeMatcher.normalize(strokes)
        let maxR: CGFloat = out.flatMap { $0 }
            .map { hypot($0.x, $0.y) }
            .max() ?? 0
        XCTAssertEqual(Double(maxR), 1.0, accuracy: 1e-9)
    }

    func testNormalize_isTranslationInvariant() {
        let s1: [[CGPoint]] = [[CGPoint(x: 1, y: 1), CGPoint(x: 3, y: 1), CGPoint(x: 2, y: 3)]]
        let s2: [[CGPoint]] = [[CGPoint(x: 11, y: 21), CGPoint(x: 13, y: 21), CGPoint(x: 12, y: 23)]]
        let n1 = StrokeMatcher.normalize(s1)
        let n2 = StrokeMatcher.normalize(s2)
        let flatten: ([[CGPoint]]) -> [CGPoint] = { $0.flatMap { $0 } }
        let p1 = flatten(n1)
        let p2 = flatten(n2)
        XCTAssertEqual(p1.count, p2.count)
        for (a, b) in zip(p1, p2) {
            XCTAssertEqual(Double(a.x), Double(b.x), accuracy: 1e-6)
            XCTAssertEqual(Double(a.y), Double(b.y), accuracy: 1e-6)
        }
    }

    // MARK: - distance (multi-stroke)

    func testDistance_identicalStrokes_returnsZero() {
        let strokes: [[CGPoint]] = [
            [CGPoint(x: 0, y: 0), CGPoint(x: 2, y: 0), CGPoint(x: 2, y: 2), CGPoint(x: 0, y: 2)],
            [CGPoint(x: 1, y: 1), CGPoint(x: 3, y: 1), CGPoint(x: 3, y: 3), CGPoint(x: 1, y: 3)]
        ]
        XCTAssertEqual(StrokeMatcher.distance(strokes, strokes), 0.0, accuracy: 1e-6)
    }

    func testDistance_isSymmetric() {
        let s1: [[CGPoint]] = [
            [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 2)]
        ]
        let s2: [[CGPoint]] = [
            [CGPoint(x: 1, y: 0), CGPoint(x: 2, y: 1), CGPoint(x: 3, y: 2)]
        ]
        XCTAssertEqual(StrokeMatcher.distance(s1, s2),
                       StrokeMatcher.distance(s2, s1),
                       accuracy: 1e-9)
    }

    func testDistance_penalizesStrokeCountMismatch() {
        // One stroke vs two strokes: the second stroke is unmatched → +0.5
        let oneStroke: [[CGPoint]] = [
            [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 2)]
        ]
        let twoStrokes: [[CGPoint]] = [
            [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 2)],
            [CGPoint(x: 5, y: 5), CGPoint(x: 6, y: 6), CGPoint(x: 7, y: 7)]
        ]
        // Identical first stroke → cost 0; one unmatched → +0.5; result = 0.5 / 1 pair = 0.5
        XCTAssertEqual(StrokeMatcher.distance(oneStroke, twoStrokes),
                       0.5, accuracy: 1e-6)
    }

    func testDistance_emptyInput_returnsInfinity() {
        let some: [[CGPoint]] = [[CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)]]
        XCTAssertEqual(StrokeMatcher.distance([], some), .infinity)
        XCTAssertEqual(StrokeMatcher.distance(some, []), .infinity)
    }

    func testDistance_normalizesBeforeComparing() {
        // Two L-shapes at different scales and positions should still match closely
        // (normalization handles translation + scale).
        let small: [[CGPoint]] = [[
            CGPoint(x: 0, y: 0), CGPoint(x: 2, y: 0), CGPoint(x: 2, y: 2)
        ]]
        let large: [[CGPoint]] = [[
            CGPoint(x: 100, y: 100), CGPoint(x: 200, y: 100), CGPoint(x: 200, y: 200)
        ]]
        let d = StrokeMatcher.distance(small, large)
        XCTAssertLessThan(d, 0.05,
                          "same shape at different position/scale should be near 0")
    }
}