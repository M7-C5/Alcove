import Foundation
import simd
import Testing
@testable import Alcove

@Suite("Spatial Viewport Camera Tests") @MainActor
struct SpatialViewportCameraTests {

    @Test func cameraPresetsAngles() {
        let top = ViewportPreset.topDown
        #expect(top.pitchAngleDegrees == 0.0)

        let dollhouse = ViewportPreset.dollhouseIsometric
        #expect(dollhouse.pitchAngleDegrees == 40.0)
        #expect(dollhouse.yawAngleDegrees == -35.0)

        let camera = SpatialViewportCameraState()
        #expect(!camera.isIsometric3D)

        camera.setPreset(.dollhouseIsometric)
        #expect(camera.isIsometric3D)
        #expect(camera.pitchAngleDegrees == 40.0)
        #expect(camera.yawAngleDegrees == -35.0)

        camera.setPreset(.frontElevation)
        #expect(camera.pitchAngleDegrees == 75.0)
        #expect(camera.yawAngleDegrees == 0.0)

        camera.setPreset(.sideElevation)
        #expect(camera.pitchAngleDegrees == 75.0)
        #expect(camera.yawAngleDegrees == -90.0)
    }

    @Test func zoomClamping() {
        let camera = SpatialViewportCameraState()
        #expect(camera.zoomScale == 1.0)

        // Zoom in beyond 3.0 limit
        camera.applyZoom(factor: 5.0)
        #expect(camera.zoomScale == 3.0)

        // Zoom out beyond 0.5 limit
        camera.applyZoom(factor: 0.05)
        #expect(camera.zoomScale == 0.5)
    }

    @Test func panOffsetAndReset() {
        let camera = SpatialViewportCameraState()
        camera.applyPan(translationX: 25.0, translationY: -40.0)
        #expect(camera.panOffsetX == 25.0)
        #expect(camera.panOffsetY == -40.0)

        camera.resetCamera()
        #expect(camera.panOffsetX == 0.0)
        #expect(camera.panOffsetY == 0.0)
        #expect(camera.zoomScale == 1.0)
        #expect(camera.preset == .topDown)
    }

    @Test func architecturalPOVPresetsTargetAnglesAndIcons() {
        // Top view: 89° bird's-eye
        #expect(ViewportPreset.top.targetYaw == 0.0)
        #expect(ViewportPreset.top.targetPitch == 1.55)
        #expect(ViewportPreset.top.systemImage == "button.horizontal.top.press")
        #expect(ViewportPreset.top.title == "Top")

        // Left view: looking from West (-X)
        #expect(abs(ViewportPreset.left.targetYaw - (-Float.pi / 2.0)) < 0.001)
        #expect(ViewportPreset.left.targetPitch == 0.15)
        #expect(ViewportPreset.left.systemImage == "arrow.left.to.line")
        #expect(ViewportPreset.left.title == "Left")

        // Right view: looking from East (+X)
        #expect(abs(ViewportPreset.right.targetYaw - (Float.pi / 2.0)) < 0.001)
        #expect(ViewportPreset.right.targetPitch == 0.15)
        #expect(ViewportPreset.right.systemImage == "arrow.right.to.line")
        #expect(ViewportPreset.right.title == "Right")

        // Front view: looking from South (+Z)
        #expect(ViewportPreset.front.targetYaw == 0.0)
        #expect(ViewportPreset.front.targetPitch == 0.15)
        #expect(ViewportPreset.front.systemImage == "arrow.up.to.line")
        #expect(ViewportPreset.front.title == "Front")

        // Back view: looking from North (-Z)
        #expect(abs(ViewportPreset.back.targetYaw - Float.pi) < 0.001)
        #expect(ViewportPreset.back.targetPitch == 0.15)
        #expect(ViewportPreset.back.systemImage == "arrow.down.to.line")
        #expect(ViewportPreset.back.title == "Back")

        // Reset Angle: 3D Dollhouse
        #expect(ViewportPreset.dollhouse.targetYaw == 0.0)
        #expect(ViewportPreset.dollhouse.targetPitch == 0.62)
        #expect(ViewportPreset.dollhouse.systemImage == "arrow.counterclockwise")
        #expect(ViewportPreset.dollhouse.title == "Reset Angle")
    }

    @Test func povPresetsCutawayEvaluations() {
        // In Top view (pitch = 1.55 >= 1.05), none of the walls are hidden
        let topQuat = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        #expect(!WallCutawayEvaluator.isWallHidden(wallNormal: WallCutawayEvaluator.frontNormal, orientation: topQuat, pitch: ViewportPreset.top.targetPitch))
        #expect(!WallCutawayEvaluator.isWallHidden(wallNormal: WallCutawayEvaluator.backNormal, orientation: topQuat, pitch: ViewportPreset.top.targetPitch))
        #expect(!WallCutawayEvaluator.isWallHidden(wallNormal: WallCutawayEvaluator.leftNormal, orientation: topQuat, pitch: ViewportPreset.top.targetPitch))
        #expect(!WallCutawayEvaluator.isWallHidden(wallNormal: WallCutawayEvaluator.rightNormal, orientation: topQuat, pitch: ViewportPreset.top.targetPitch))

        // In Front view (yaw = 0.0, pitch = 0.15), front wall is hidden, others visible
        let frontYawQuat = simd_quatf(angle: -ViewportPreset.front.targetYaw, axis: SIMD3<Float>(0, 1, 0))
        let frontPitchQuat = simd_quatf(angle: ViewportPreset.front.targetPitch, axis: SIMD3<Float>(1, 0, 0))
        let frontOrientation = frontPitchQuat * frontYawQuat
        #expect(WallCutawayEvaluator.isWallHidden(wallNormal: WallCutawayEvaluator.frontNormal, orientation: frontOrientation, pitch: ViewportPreset.front.targetPitch))
        #expect(!WallCutawayEvaluator.isWallHidden(wallNormal: WallCutawayEvaluator.backNormal, orientation: frontOrientation, pitch: ViewportPreset.front.targetPitch))
        #expect(!WallCutawayEvaluator.isWallHidden(wallNormal: WallCutawayEvaluator.leftNormal, orientation: frontOrientation, pitch: ViewportPreset.front.targetPitch))
        #expect(!WallCutawayEvaluator.isWallHidden(wallNormal: WallCutawayEvaluator.rightNormal, orientation: frontOrientation, pitch: ViewportPreset.front.targetPitch))

        // In Back view (yaw = pi, pitch = 0.15), back wall is hidden, others visible
        let backYawQuat = simd_quatf(angle: -ViewportPreset.back.targetYaw, axis: SIMD3<Float>(0, 1, 0))
        let backPitchQuat = simd_quatf(angle: ViewportPreset.back.targetPitch, axis: SIMD3<Float>(1, 0, 0))
        let backOrientation = backPitchQuat * backYawQuat
        #expect(!WallCutawayEvaluator.isWallHidden(wallNormal: WallCutawayEvaluator.frontNormal, orientation: backOrientation, pitch: ViewportPreset.back.targetPitch))
        #expect(WallCutawayEvaluator.isWallHidden(wallNormal: WallCutawayEvaluator.backNormal, orientation: backOrientation, pitch: ViewportPreset.back.targetPitch))
        #expect(!WallCutawayEvaluator.isWallHidden(wallNormal: WallCutawayEvaluator.leftNormal, orientation: backOrientation, pitch: ViewportPreset.back.targetPitch))
        #expect(!WallCutawayEvaluator.isWallHidden(wallNormal: WallCutawayEvaluator.rightNormal, orientation: backOrientation, pitch: ViewportPreset.back.targetPitch))

        // In Left view (yaw = -pi/2, pitch = 0.15), left wall is hidden, others visible
        let leftYawQuat = simd_quatf(angle: -ViewportPreset.left.targetYaw, axis: SIMD3<Float>(0, 1, 0))
        let leftPitchQuat = simd_quatf(angle: ViewportPreset.left.targetPitch, axis: SIMD3<Float>(1, 0, 0))
        let leftOrientation = leftPitchQuat * leftYawQuat
        #expect(!WallCutawayEvaluator.isWallHidden(wallNormal: WallCutawayEvaluator.frontNormal, orientation: leftOrientation, pitch: ViewportPreset.left.targetPitch))
        #expect(!WallCutawayEvaluator.isWallHidden(wallNormal: WallCutawayEvaluator.backNormal, orientation: leftOrientation, pitch: ViewportPreset.left.targetPitch))
        #expect(WallCutawayEvaluator.isWallHidden(wallNormal: WallCutawayEvaluator.leftNormal, orientation: leftOrientation, pitch: ViewportPreset.left.targetPitch))
        #expect(!WallCutawayEvaluator.isWallHidden(wallNormal: WallCutawayEvaluator.rightNormal, orientation: leftOrientation, pitch: ViewportPreset.left.targetPitch))

        // In Right view (yaw = pi/2, pitch = 0.15), right wall is hidden, others visible
        let rightYawQuat = simd_quatf(angle: -ViewportPreset.right.targetYaw, axis: SIMD3<Float>(0, 1, 0))
        let rightPitchQuat = simd_quatf(angle: ViewportPreset.right.targetPitch, axis: SIMD3<Float>(1, 0, 0))
        let rightOrientation = rightPitchQuat * rightYawQuat
        #expect(!WallCutawayEvaluator.isWallHidden(wallNormal: WallCutawayEvaluator.frontNormal, orientation: rightOrientation, pitch: ViewportPreset.right.targetPitch))
        #expect(!WallCutawayEvaluator.isWallHidden(wallNormal: WallCutawayEvaluator.backNormal, orientation: rightOrientation, pitch: ViewportPreset.right.targetPitch))
        #expect(!WallCutawayEvaluator.isWallHidden(wallNormal: WallCutawayEvaluator.leftNormal, orientation: rightOrientation, pitch: ViewportPreset.right.targetPitch))
        #expect(WallCutawayEvaluator.isWallHidden(wallNormal: WallCutawayEvaluator.rightNormal, orientation: rightOrientation, pitch: ViewportPreset.right.targetPitch))
    }
}
