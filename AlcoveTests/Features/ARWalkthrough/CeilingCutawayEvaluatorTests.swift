import Foundation
import Testing
import simd
@testable import Alcove

@Suite("Ceiling Cutaway Evaluator Tests")
struct CeilingCutawayEvaluatorTests {

    let roomW: Float = 4.0
    let roomL: Float = 5.0
    let roomH: Float = 2.60

    @Test func ceilingVisibleWhenStandingInsideRoomLookingUp() {
        // Camera at eye-level inside room center
        let insideEyeLevel = SIMD3<Float>(0, 1.60, 0)
        let isHidden = CeilingCutawayEvaluator.isCeilingHidden(
            localCameraPosition: insideEyeLevel,
            roomWidth: roomW,
            roomLength: roomL,
            roomHeight: roomH
        )

        #expect(!isHidden, "Ceiling should be visible when user stands inside the room at eye level")
        #expect(CeilingCutawayEvaluator.isCameraInsideRoom(
            localCameraPosition: insideEyeLevel,
            roomWidth: roomW,
            roomLength: roomL,
            roomHeight: roomH
        ))
    }

    @Test func ceilingHiddenWhenCameraIsAboveRoomHeight() {
        // Camera positioned above the ceiling (e.g. bird's eye or holding iPad high)
        let aboveCeiling = SIMD3<Float>(0, 2.70, 0)
        let isHidden = CeilingCutawayEvaluator.isCeilingHidden(
            localCameraPosition: aboveCeiling,
            roomWidth: roomW,
            roomLength: roomL,
            roomHeight: roomH
        )

        #expect(isHidden, "Ceiling should cut away when camera is above the room ceiling height")
        #expect(!CeilingCutawayEvaluator.isCameraInsideRoom(
            localCameraPosition: aboveCeiling,
            roomWidth: roomW,
            roomLength: roomL,
            roomHeight: roomH
        ))
    }

    @Test func ceilingHiddenWhenCameraStepsOutsideRoomHorizontally() {
        // Camera positioned 1 meter outside the front wall
        let outsideFrontWall = SIMD3<Float>(0, 1.50, 4.0)
        let isHidden = CeilingCutawayEvaluator.isCeilingHidden(
            localCameraPosition: outsideFrontWall,
            roomWidth: roomW,
            roomLength: roomL,
            roomHeight: roomH
        )

        #expect(isHidden, "Ceiling should cut away when user steps outside room boundaries")
        #expect(!CeilingCutawayEvaluator.isCameraInsideRoom(
            localCameraPosition: outsideFrontWall,
            roomWidth: roomW,
            roomLength: roomL,
            roomHeight: roomH
        ))
    }

    @Test func cameraNearPerimeterWallEdgeStaysVisibleWithinTolerance() {
        // Camera close to wall corner inside
        let nearCornerInside = SIMD3<Float>(1.80, 1.40, 2.30)
        let isHidden = CeilingCutawayEvaluator.isCeilingHidden(
            localCameraPosition: nearCornerInside,
            roomWidth: roomW,
            roomLength: roomL,
            roomHeight: roomH
        )

        #expect(!isHidden, "Ceiling should remain visible near perimeter corners inside")
    }
}
