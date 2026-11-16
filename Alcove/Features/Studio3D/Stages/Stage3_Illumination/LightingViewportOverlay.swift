import CoreGraphics
import Foundation

/// Geometry checks do not draw over the room canvas.
enum LightingViewportGeometry {
    static func overlapsHeader(_ points: [CGPoint]) -> Bool {
        points.contains { $0.x.isFinite && $0.y.isFinite && $0.y < 160 }
    }
}

/// Fits the entire placement plane into the clear area between the open inspectors.
enum LightingPlacementFraming {
    static func distance(width: Double, length: Double, height: Double, viewport: CGSize) -> Float {
        let panel = min(300.0, max(240.0, viewport.width * 0.22))
        let clearWidth = max(100, viewport.width - 2 * (panel + 44 + 16) - 48)
        let clearHeight = max(100, viewport.height - 360)
        let tangent = tan(40.0 * .pi / 360)
        let vertical = length / (2 * tangent * (clearHeight / max(1, viewport.height)))
        let horizontal = width / (2 * tangent * (clearWidth / max(1, viewport.height)))
        return Float(max(vertical, horizontal) + height * 0.65)
    }
}
