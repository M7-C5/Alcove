import Foundation
import simd

/// Pure mathematical evaluator determining camera-facing wall occlusion and dynamic cutaways.
public struct WallCutawayEvaluator: Sendable {
    /// Dot product cutoff threshold above which a wall faces the camera and should be cut away.
    public static let cutoff: Float = 0.15

    /// Pitch angle threshold (in radians, ~60°) at which camera enters bird's-eye top-down view.
    public static let topDownPitchThreshold: Float = 1.05

    /// Canonical outward normals for the 4 cardinal room perimeter walls.
    public static let frontNormal = SIMD3<Float>(0, 0, 1)
    public static let backNormal = SIMD3<Float>(0, 0, -1)
    public static let leftNormal = SIMD3<Float>(-1, 0, 0)
    public static let rightNormal = SIMD3<Float>(1, 0, 0)

    /// Evaluates whether a perimeter wall with the given outward normal is currently facing
    /// the camera and should be cut away (hidden) to prevent line-of-sight occlusion.
    public static func isWallHidden(
        wallNormal: SIMD3<Float>,
        orientation: simd_quatf,
        pitch: Float
    ) -> Bool {
        // In bird's-eye top-down view, all perimeter walls remain visible to frame the room plan
        if pitch >= topDownPitchThreshold {
            return false
        }

        // World-space vector from room center to camera (looking down -Z)
        let toCamWorld = SIMD3<Float>(0, 0, 1)
        // Transform into room-local coordinate space
        let toCamLocal = orientation.inverse.act(toCamWorld)

        return simd_dot(wallNormal, toCamLocal) > cutoff
    }
}
