import Foundation
import simd

/// Pure algorithmic engine for 1:1 AR placement, coordinate transformations,
/// and surface reticle tracking.
public struct ARPlacementEngine: Sendable {

    /// Transforms a point from world coordinates into room-local coordinates.
    ///
    /// - Parameters:
    ///   - worldPoint: Point in ARKit world space.
    ///   - roomWorldPosition: Origin of the room in ARKit world space.
    ///   - roomRotationYaw: Yaw rotation of the room around the Y-axis (in radians).
    /// - Returns: Point transformed into the room's local reference frame where (0, 0, 0) is the room center.
    public static func worldToLocal(
        worldPoint: SIMD3<Float>,
        roomWorldPosition: SIMD3<Float>,
        roomRotationYaw: Float
    ) -> SIMD3<Float> {
        let delta = worldPoint - roomWorldPosition
        let cosYaw = cos(-roomRotationYaw)
        let sinYaw = sin(-roomRotationYaw)

        let localX = delta.x * cosYaw - delta.z * sinYaw
        let localZ = delta.x * sinYaw + delta.z * cosYaw
        let localY = delta.y

        return SIMD3<Float>(localX, localY, localZ)
    }

    /// Transforms a point from room-local coordinates into ARKit world coordinates.
    public static func localToWorld(
        localPoint: SIMD3<Float>,
        roomWorldPosition: SIMD3<Float>,
        roomRotationYaw: Float
    ) -> SIMD3<Float> {
        let cosYaw = cos(roomRotationYaw)
        let sinYaw = sin(roomRotationYaw)

        let worldX = localPoint.x * cosYaw - localPoint.z * sinYaw
        let worldZ = localPoint.x * sinYaw + localPoint.z * cosYaw
        let worldY = localPoint.y

        return roomWorldPosition + SIMD3<Float>(worldX, worldY, worldZ)
    }

    /// Evaluates whether a candidate floor placement hit is within ergonomic range of the user.
    ///
    /// - Parameters:
    ///   - cameraPosition: Camera position in ARKit world space.
    ///   - hitPosition: Candidate floor plane intersection in ARKit world space.
    /// - Returns: `true` if distance is between 0.4m and 6.0m and beneath the camera.
    public static func isValidPlacementDistance(
        cameraPosition: SIMD3<Float>,
        hitPosition: SIMD3<Float>
    ) -> Bool {
        let dist = simd_distance(cameraPosition, hitPosition)
        let isBelowCamera = hitPosition.y <= cameraPosition.y + 0.10
        return dist >= 0.40 && dist <= 6.0 && isBelowCamera
    }

    /// Normalizes any angle in radians to (-π, π].
    public static func normalizeAngle(_ angle: Float) -> Float {
        var a = angle.truncatingRemainder(dividingBy: .pi * 2)
        if a > .pi { a -= .pi * 2 }
        if a <= -.pi { a += .pi * 2 }
        return a
    }
}
