import Foundation
import CoreGraphics
import simd

/// Pure mathematical engine managing furniture translation, floor bounds clamping, and rotation snapping.
public struct FurnitureTransformEngine: Sendable {

    /// Projects 2D screen-space drag translation into 3D floor displacement relative to camera orientation.
    public static func projectScreenDragToFloor(
        translation: CGSize,
        orientation: simd_quatf,
        sensitivity: Float = 0.007
    ) -> SIMD3<Float> {
        let screenRightWorld = SIMD3<Float>(1, 0, 0)
        let screenUpWorld = SIMD3<Float>(0, 1, 0)

        let dragRightLocal = orientation.inverse.act(screenRightWorld)
        let dragUpLocal = orientation.inverse.act(screenUpWorld)

        let dx = Float(translation.width) * sensitivity
        let dy = Float(translation.height) * sensitivity

        let move = dragRightLocal * dx + dragUpLocal * (-dy)
        return SIMD3<Float>(move.x, 0, move.z)
    }

    /// Clamps furniture (X, Z) coordinates inside interior drywall boundaries, accounting for yaw rotation.
    public static func clampPosition(
        position: SIMD3<Float>,
        furnitureWidth: Float,
        furnitureLength: Float,
        rotationYaw: Float,
        roomWidth: Float,
        roomLength: Float,
        margin: Float = 0.05
    ) -> SIMD3<Float> {
        let halfRoomW = roomWidth / 2.0
        let halfRoomL = roomLength / 2.0

        let cosA = abs(cos(rotationYaw))
        let sinA = abs(sin(rotationYaw))
        let effectiveW = (furnitureWidth * cosA) + (furnitureLength * sinA)
        let effectiveL = (furnitureWidth * sinA) + (furnitureLength * cosA)

        let halfEffW = effectiveW / 2.0
        let halfEffL = effectiveL / 2.0

        let minX = -halfRoomW + halfEffW + margin
        let maxX = halfRoomW - halfEffW - margin
        let minZ = -halfRoomL + halfEffL + margin
        let maxZ = halfRoomL - halfEffL - margin

        let safeMinX = min(minX, maxX)
        let safeMaxX = max(minX, maxX)
        let safeMinZ = min(minZ, maxZ)
        let safeMaxZ = max(minZ, maxZ)

        let clampedX = min(max(position.x, safeMinX), safeMaxX)
        let clampedZ = min(max(position.z, safeMinZ), safeMaxZ)

        return SIMD3<Float>(clampedX, position.y, clampedZ)
    }

    /// Normalizes rotation yaw into [0, 2π).
    public static func normalizeYaw(_ yaw: Double) -> Double {
        var angle = yaw.truncatingRemainder(dividingBy: 2.0 * .pi)
        if angle < 0 {
            angle += 2.0 * .pi
        }
        return angle
    }

    /// Converts yaw to rounded degrees (0 – 359).
    public static func yawToDegrees(_ yaw: Double) -> Int {
        let normalized = normalizeYaw(yaw)
        return Int((normalized * 180.0 / .pi).rounded()) % 360
    }

    /// Snaps rotation yaw to the nearest 45-degree (π/4) increment.
    public static func snapToNearest45Degrees(_ yaw: Double) -> Double {
        let step = Double.pi / 4.0
        return (yaw / step).rounded() * step
    }

    /// Normalizes raw yaw into [0, 2π) and snaps to the nearest increment (default 90°, π/2)
    /// if within a magnetic snap threshold, matching Resign's SpatialClearanceEngine.
    public static func snapYaw(
        rawYaw: Float,
        step: Float = .pi / 2.0,
        threshold: Float = 0.14
    ) -> (yaw: Float, didSnap: Bool) {
        let twoPi = Float.pi * 2.0
        let normalized = (rawYaw.truncatingRemainder(dividingBy: twoPi) + twoPi).truncatingRemainder(dividingBy: twoPi)
        let nearestIndex = round(normalized / step)
        let nearestTarget = nearestIndex * step
        let diff = abs(normalized - nearestTarget)
        if diff < threshold || abs(diff - twoPi) < threshold {
            let snapped = (nearestTarget.truncatingRemainder(dividingBy: twoPi) + twoPi).truncatingRemainder(dividingBy: twoPi)
            return (snapped, true)
        }
        return (normalized, false)
    }

    /// Computes the signed angular delta swept between two 2D points relative to a center point.
    /// Positive values correspond to clockwise motion in screen coordinates, matching Resign's circular dial.
    public static func circularAngleDelta(center: CGPoint, previous: CGPoint, current: CGPoint) -> Float {
        let p = CGPoint(x: previous.x - center.x, y: previous.y - center.y)
        let c = CGPoint(x: current.x - center.x, y: current.y - center.y)
        let pLenSq = p.x * p.x + p.y * p.y
        let cLenSq = c.x * c.x + c.y * c.y
        if pLenSq < 16 || cLenSq < 16 {
            return 0
        }
        let cross = p.x * c.y - p.y * c.x
        let dot = p.x * c.x + p.y * c.y
        return Float(atan2(cross, dot))
    }
}
