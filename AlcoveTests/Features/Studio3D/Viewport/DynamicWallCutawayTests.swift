import Foundation
import Testing
import simd
@testable import Alcove

@Suite("Dynamic Wall Cutaway Tests")
struct DynamicWallCutawayTests {

    private func makeOrientation(yaw: Float, pitch: Float) -> simd_quatf {
        let yawQuat = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
        let pitchQuat = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
        return pitchQuat * yawQuat
    }

    @Test func frontWallHiddenWhenViewingFromFront() {
        let orientation = makeOrientation(yaw: 0.0, pitch: 0.62)

        let isFrontHidden = WallCutawayEvaluator.isWallHidden(
            wallNormal: WallCutawayEvaluator.frontNormal,
            orientation: orientation,
            pitch: 0.62
        )
        let isBackHidden = WallCutawayEvaluator.isWallHidden(
            wallNormal: WallCutawayEvaluator.backNormal,
            orientation: orientation,
            pitch: 0.62
        )
        let isLeftHidden = WallCutawayEvaluator.isWallHidden(
            wallNormal: WallCutawayEvaluator.leftNormal,
            orientation: orientation,
            pitch: 0.62
        )
        let isRightHidden = WallCutawayEvaluator.isWallHidden(
            wallNormal: WallCutawayEvaluator.rightNormal,
            orientation: orientation,
            pitch: 0.62
        )

        #expect(isFrontHidden == true)
        #expect(isBackHidden == false)
        #expect(isLeftHidden == false)
        #expect(isRightHidden == false)
    }

    @Test func backWallHiddenWhenViewingFromRear() {
        let orientation = makeOrientation(yaw: Float.pi, pitch: 0.62)

        let isFrontHidden = WallCutawayEvaluator.isWallHidden(
            wallNormal: WallCutawayEvaluator.frontNormal,
            orientation: orientation,
            pitch: 0.62
        )
        let isBackHidden = WallCutawayEvaluator.isWallHidden(
            wallNormal: WallCutawayEvaluator.backNormal,
            orientation: orientation,
            pitch: 0.62
        )

        #expect(isFrontHidden == false)
        #expect(isBackHidden == true)
    }

    @Test func leftWallHiddenWhenViewingFromLeftSide() {
        let orientation = makeOrientation(yaw: Float.pi / 2, pitch: 0.62)

        let isLeftHidden = WallCutawayEvaluator.isWallHidden(
            wallNormal: WallCutawayEvaluator.leftNormal,
            orientation: orientation,
            pitch: 0.62
        )
        let isRightHidden = WallCutawayEvaluator.isWallHidden(
            wallNormal: WallCutawayEvaluator.rightNormal,
            orientation: orientation,
            pitch: 0.62
        )

        #expect(isLeftHidden == true)
        #expect(isRightHidden == false)
    }

    @Test func rightWallHiddenWhenViewingFromRightSide() {
        let orientation = makeOrientation(yaw: -Float.pi / 2, pitch: 0.62)

        let isLeftHidden = WallCutawayEvaluator.isWallHidden(
            wallNormal: WallCutawayEvaluator.leftNormal,
            orientation: orientation,
            pitch: 0.62
        )
        let isRightHidden = WallCutawayEvaluator.isWallHidden(
            wallNormal: WallCutawayEvaluator.rightNormal,
            orientation: orientation,
            pitch: 0.62
        )

        #expect(isLeftHidden == false)
        #expect(isRightHidden == true)
    }

    @Test func allWallsVisibleInTopDownBirdseyeView() {
        let orientation = makeOrientation(yaw: 0.0, pitch: 1.25)

        for normal in [
            WallCutawayEvaluator.frontNormal,
            WallCutawayEvaluator.backNormal,
            WallCutawayEvaluator.leftNormal,
            WallCutawayEvaluator.rightNormal
        ] {
            let isHidden = WallCutawayEvaluator.isWallHidden(
                wallNormal: normal,
                orientation: orientation,
                pitch: 1.25
            )
            #expect(isHidden == false)
        }
    }

    @Test func defaultDollhousePerspectiveHidesFrontWall() {
        let defaultPitch: Float = 0.62
        let defaultYaw: Float = -0.52
        let orientation = makeOrientation(yaw: defaultYaw, pitch: defaultPitch)

        let isFrontHidden = WallCutawayEvaluator.isWallHidden(
            wallNormal: WallCutawayEvaluator.frontNormal,
            orientation: orientation,
            pitch: defaultPitch
        )
        let isBackHidden = WallCutawayEvaluator.isWallHidden(
            wallNormal: WallCutawayEvaluator.backNormal,
            orientation: orientation,
            pitch: defaultPitch
        )

        #expect(isFrontHidden == true)
        #expect(isBackHidden == false)
    }
}
