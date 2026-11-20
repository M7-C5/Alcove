import CoreGraphics
import simd

/// Shared room projection rules for the headers in every studio stage.
enum StudioViewportGeometry {
    static let headerBottom: CGFloat = 160

    static func roomCorners(width: Double, length: Double, height: Double) -> [SIMD3<Float>] {
        let w = Float(width / 2)
        let l = Float(length / 2)
        return [-w, w].flatMap { x in
            [Float(0), Float(height)].flatMap { y in
                [-l, l].map { z in SIMD3<Float>(x, y, z) }
            }
        }
    }

    static func overlapsHeader(_ points: [CGPoint]) -> Bool {
        points.contains { $0.x.isFinite && $0.y.isFinite && $0.y < headerBottom }
    }

    /// Perspective fit with space reserved above the room for the title and stage progress.
    static func framingDistance(corners: [SIMD3<Float>], target: SIMD3<Float>, yaw: Float,
                                pitch: Float, viewport: CGSize) -> Float? {
        guard viewport.width.isFinite, viewport.height.isFinite,
              viewport.width > 1, viewport.height > 1 else { return nil }
        let tangent = tan(Float.pi / 9) // Shared camera's 40° vertical field of view.
        let topInset = min(headerBottom + 32, viewport.height * 0.4)
        let bottomInset = min(CGFloat(96), viewport.height * 0.2)
        let sideInset = min(CGFloat(32), viewport.width * 0.1)
        let topSlope = tangent * Float(1 - 2 * topInset / viewport.height)
        let bottomSlope = tangent * Float(1 - 2 * bottomInset / viewport.height)
        let sideSlope = tangent * Float((viewport.width - 2 * sideInset) / viewport.height)
        let right = SIMD3<Float>(cos(yaw), 0, -sin(yaw))
        let up = SIMD3<Float>(-sin(pitch) * sin(yaw), cos(pitch), -sin(pitch) * cos(yaw))
        let towardCamera = SIMD3<Float>(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
        return corners.reduce(Float(0.1)) { distance, corner in
            let offset = corner - target
            let vertical = simd_dot(offset, up)
            let depth = simd_dot(offset, towardCamera)
            let verticalDistance = abs(vertical) / (vertical >= 0 ? topSlope : bottomSlope)
            let horizontalDistance = abs(simd_dot(offset, right)) / sideSlope
            return max(distance, depth + max(verticalDistance, horizontalDistance) + 0.1)
        }
    }
}
