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

        // 3. Convert each contour's normalized CGPath into a sampled polyline in
        //    the original canvas coordinate space. VNContour exposes only
        //    normalizedPath (a CGPath) as the public geometry access; we walk
        //    it with applyWithBlock to collect the path points.
        let renderW = renderBounds.width
        let renderH = renderBounds.height
        let offset = CGPoint(x: renderBounds.minX, y: renderBounds.minY)

        var strokes: [[CGPoint]] = []
        for contour in contours {
            let path = contour.normalizedPath
            var pts: [CGPoint] = []
            path.applyWithBlock { elementPtr in
                let el = elementPtr.pointee
                pts.append(CGPoint(
                    x: el.points[0].x * renderW + offset.x,
                    y: el.points[0].y * renderH + offset.y
                ))
            }
            if pts.count >= 3 {
                strokes.append(pts)
            }
        }
        return strokes
    }

    /// Run VNDetectContoursRequest on the CGImage and return top-level
    /// VNContours. Async wrapper around Vision's callback API.
    private static func detectContours(cgImage: CGImage) async -> [VNContour] {
        await withCheckedContinuation { continuation in
            let request = VNDetectContoursRequest { req, _ in
                let observation = (req.results as? [VNContoursObservation])?.first
                let contours = observation?.topLevelContours ?? []
                continuation.resume(returning: contours)
            }
            request.contrastAdjustment = 1.0
            request.detectsDarkOnLight = true   // pencil ink on light background
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