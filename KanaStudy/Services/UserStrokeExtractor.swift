import Foundation
import CoreGraphics
import PencilKit
import Vision
import UIKit

/// UserStrokeExtractor — converts a PKDrawing into a list of strokes (each
/// stroke is an ordered polyline of CGPoints).
///
/// PKStrokePath is opaque (no public control-points access in PencilKit), so
/// the cleanest extraction path is to render the drawing to a UIImage and run
/// Apple's VNDetectContoursRequest. The result is a hierarchy of contours;
/// we flatten the top-level contours and sample each into a fixed-length
/// point array.
enum UserStrokeExtractor {

    /// Render the drawing to a monochrome bitmap and find ink contours.
    /// Returns a list of strokes (each = polyline of CGPoints in image space).
    static func extractStrokes(from drawing: PKDrawing, size: CGSize) async -> [[CGPoint]] {
        guard size.width > 0, size.height > 0 else { return [] }

        // 1. Render drawing to a high-contrast image.
        let bounds = drawing.bounds
        // If the drawing is empty, VNDetectContoursRequest will simply return [].
        let renderBounds = bounds.isEmpty
            ? CGRect(origin: .zero, size: size)
            : bounds.insetBy(dx: -10, dy: -10)

        let scale: CGFloat = 2.0   // render at 2x for VN accuracy
        let image = drawing.image(from: renderBounds, scale: scale)
        guard let cgImage = image.cgImage else { return [] }

        // 2. Run contour detection.
        let contours = await detectContours(cgImage: cgImage)

        // 3. Convert each contour's CGPath into a sampled polyline in the
        //    original canvas coordinate space.
        let scaleFactor: CGFloat = 1.0 / scale
        let offset = CGPoint(x: renderBounds.minX, y: renderBounds.minY)

        var strokes: [[CGPoint]] = []
        for path in contours {
            var pts: [CGPoint] = []
            path.applyWithBlock { elementPtr in
                let el = elementPtr.pointee
                let pt = el.points.pointee
                pts.append(CGPoint(x: (pt.x * scaleFactor) + offset.x,
                                   y: (pt.y * scaleFactor) + offset.y))
            }
            // ApplyWithBlock yields the start point first, then 0 length for
            // moves, then line/curve endpoints. Filter out degenerate points.
            let filtered = pts.filter { hypot($0.x, $0.y) > 0 || pts.count < 4 }
            if filtered.count >= 3 {
                strokes.append(filtered)
            }
        }
        return strokes
    }

    /// Run VNDetectContoursRequest on the CGImage and return top-level contour
    /// CGPaths. Async wrapper around Vision's callback API.
    private static func detectContours(cgImage: CGImage) async -> [CGPath] {
        await withCheckedContinuation { continuation in
            let request = VNDetectContoursRequest { req, _ in
                let observation = (req.results as? [VNContoursObservation])?.first
                let paths = observation?.topLevelContours.map { $0.path } ?? []
                continuation.resume(returning: paths)
            }
            request.contrastAdjustment = 1.0
            request.detectsDarkOnLight = true   // pencil ink on light background
            request.maximumObservations = 12
            request.contrastPivot = 0.5

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
}