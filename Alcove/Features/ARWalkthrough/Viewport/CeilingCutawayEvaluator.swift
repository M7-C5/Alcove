import Foundation
import simd

/// Pure mathematical evaluator determining dynamic ceiling occlusion and cutaway state
/// based on the 1:1 camera position relative to the room envelope.
public struct CeilingCutawayEvaluator: Sendable {

    /// Evaluates whether the ceiling should be hidden (cut away) given the camera's position
    /// in the room's local coordinate space.
    ///
    /// - Parameters:
    ///   - localCameraPosition: Position of the camera relative to room center at (0, 0, 0).
    ///   - roomWidth: Total width of the room along the X-axis.
    ///   - roomLength: Total length of the room along the Z-axis.
    ///   - roomHeight: Total height of the room along the Y-axis.
    /// - Returns: `true` if the ceiling should be cut away (hidden), `false` if visible.
    public static func isCeilingHidden(
        localCameraPosition: SIMD3<Float>,
        roomWidth: Float,
        roomLength: Float,
        roomHeight: Float
    ) -> Bool {
        // If camera is above the ceiling level (or slightly below with 5cm tolerance),
        // cut the ceiling away so the user can look down inside without occlusion.
        if localCameraPosition.y >= (roomHeight - 0.05) {
            return true
        }

        // Check horizontal bounds with a small outward margin (10cm)
        let halfW = (roomWidth / 2.0) + 0.10
        let halfL = (roomLength / 2.0) + 0.10

        let isInsideHorizontalBounds = (localCameraPosition.x >= -halfW && localCameraPosition.x <= halfW) &&
                                       (localCameraPosition.z >= -halfL && localCameraPosition.z <= halfL)

        // When the camera is inside the room horizontal perimeter and below the ceiling,
        // the user is standing inside the 1:1 room: keep the ceiling visible.
        if isInsideHorizontalBounds && localCameraPosition.y >= 0.0 {
            return false
        }

        // When the camera is stepped outside the room envelope, cut away the ceiling
        // so it does not cast an artificial shadow or block exterior sightlines.
        return true
    }

    /// Evaluates whether the user is physically positioned inside the 1:1 virtual room boundary.
    public static func isCameraInsideRoom(
        localCameraPosition: SIMD3<Float>,
        roomWidth: Float,
        roomLength: Float,
        roomHeight: Float
    ) -> Bool {
        let halfW = roomWidth / 2.0
        let halfL = roomLength / 2.0

        return localCameraPosition.x >= -halfW && localCameraPosition.x <= halfW &&
               localCameraPosition.z >= -halfL && localCameraPosition.z <= halfL &&
               localCameraPosition.y >= 0.0 && localCameraPosition.y <= roomHeight
    }
}
