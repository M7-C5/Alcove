import CoreGraphics
import RealityKit
import Testing
@testable import Alcove

@Suite("Lighting viewport framing") @MainActor
struct LightingViewportOverlayTests {
    @Test func placementBeforeFirstLayoutStillFitsOverviewWhenFinished() {
        let room = SampleData.createStarterRoom()
        let scene = LightingRoomScene(snapshot: LightingRoomSnapshot(room: room))
        let view = ARView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
                          cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.scene.addAnchor(scene.root)
        defer { view.scene.anchors.removeAll() }
        scene.setPlacementMode(true)
        scene.apply(LightingSimulationSettings(), preset: .top, in: view)
        scene.updateViewportProjection(in: view)
        scene.setPlacementMode(false)
        scene.apply(LightingSimulationSettings(), preset: .dollhouse, in: view)
        let points = StudioViewportGeometry.roomCorners(width: room.dimensionsWidth,
            length: room.dimensionsLength, height: room.dimensionsHeight).compactMap {
                view.project(scene.root.convert(position: $0, to: nil))
            }
        #expect(points.count == 8)
        #expect(points.allSatisfy { $0.y >= StudioViewportGeometry.headerBottom + 24 })
    }

    @Test(arguments: [ViewportPreset.top, .dollhouse])
    func lightingEntryKeepsRoomBelowHeader(preset: ViewportPreset) {
        let room = SampleData.createStarterRoom()
        let scene = LightingRoomScene(snapshot: LightingRoomSnapshot(room: room))
        let view = ARView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
                          cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.scene.addAnchor(scene.root)
        defer { view.scene.anchors.removeAll() }
        scene.apply(LightingSimulationSettings(), preset: preset, in: view)
        let points = StudioViewportGeometry.roomCorners(width: room.dimensionsWidth,
            length: room.dimensionsLength, height: room.dimensionsHeight).compactMap {
                view.project(scene.root.convert(position: $0, to: nil))
            }
        #expect(points.count == 8)
        #expect(points.allSatisfy { $0.y >= StudioViewportGeometry.headerBottom + 24 })
        #expect(!StudioViewportGeometry.overlapsHeader(points))
    }

    @Test func initialRoomFitsOnceAndSubsequentUpdatesPreserveUserZoom() {
        let room = SampleData.createStarterRoom()
        let scene = LightingRoomScene(snapshot: LightingRoomSnapshot(room: room))
        let view = ARView(frame: CGRect(x: 0, y: 0, width: 1194, height: 834),
                          cameraMode: .nonAR, automaticallyConfigureSession: false)
        scene.apply(LightingSimulationSettings(), preset: .top, in: view)
        let fitted = LightingPlacementFraming.distance(width: room.dimensionsWidth, length: room.dimensionsLength,
                                                       height: room.dimensionsHeight, viewport: view.bounds.size)
        #expect(scene.cameraController.distance >= fitted)
        let overviewDistance = scene.cameraController.distance
        scene.cameraController.distance = overviewDistance * 0.7
        scene.apply(LightingSimulationSettings(), preset: .front, in: view)
        scene.updateViewportProjection(in: view)
        #expect(scene.cameraController.distance == overviewDistance * 0.7)
    }

    @Test func headerOverlapClearsWhenRoomMovesBelowHeader() {
        #expect(StudioViewportGeometry.overlapsHeader([
            CGPoint(x: 100, y: 120), CGPoint(x: 500, y: 120), CGPoint(x: 500, y: 600)
        ]))
        #expect(!StudioViewportGeometry.overlapsHeader([
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
