import Foundation
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
}
