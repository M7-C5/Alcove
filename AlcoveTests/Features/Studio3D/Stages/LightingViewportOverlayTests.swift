import CoreGraphics
import RealityKit
import Testing
@testable import Alcove

@Suite("Lighting viewport framing") @MainActor
struct LightingViewportOverlayTests {
    @Test func initialRoomFitsOnceAndSubsequentUpdatesPreserveUserZoom() {
        let room = SampleData.createStarterRoom()
        let scene = LightingRoomScene(snapshot: LightingRoomSnapshot(room: room))
        let view = ARView(frame: CGRect(x: 0, y: 0, width: 1194, height: 834),
                          cameraMode: .nonAR, automaticallyConfigureSession: false)
        scene.apply(LightingSimulationSettings(), preset: .top, in: view)
        let fitted = LightingPlacementFraming.distance(width: room.dimensionsWidth, length: room.dimensionsLength,
                                                       height: room.dimensionsHeight, viewport: view.bounds.size)
        #expect(scene.cameraController.distance == fitted)
        scene.cameraController.distance = fitted * 0.7
        scene.apply(LightingSimulationSettings(), preset: .front, in: view)
        scene.updateViewportProjection(in: view)
        #expect(scene.cameraController.distance == fitted * 0.7)
    }

    @Test func headerOverlapClearsWhenRoomMovesBelowHeader() {
        #expect(LightingViewportGeometry.overlapsHeader([
            CGPoint(x: 100, y: 120), CGPoint(x: 500, y: 120), CGPoint(x: 500, y: 600)
        ]))
        #expect(!LightingViewportGeometry.overlapsHeader([
            CGPoint(x: 100, y: 200), CGPoint(x: 500, y: 200), CGPoint(x: 500, y: 600)
        ]))
    }

    @Test func placementFitsBetweenInspectorsForDifferentRoomShapes() {
        let viewport = CGSize(width: 1194, height: 834)
        for (width, length) in [(4.0, 5.0), (12, 3), (3, 15)] {
            let distance = Double(LightingPlacementFraming.distance(width: width, length: length,
                                                                   height: 2.6, viewport: viewport))
            let floorDistance = distance - 2.6 * 0.65
            let pixelsPerMeter = viewport.height / (2 * floorDistance * tan(40 * .pi / 360))
            let panel = min(300.0, max(240.0, viewport.width * 0.22))
            #expect(width * pixelsPerMeter <= viewport.width - 2 * (panel + 60) - 47)
            #expect(length * pixelsPerMeter <= viewport.height - 359)
        }
    }
}
