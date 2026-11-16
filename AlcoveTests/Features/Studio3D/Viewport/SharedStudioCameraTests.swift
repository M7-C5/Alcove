import RealityKit
import SwiftUI
import Testing
import simd
@testable import Alcove

@Suite("Shared Audit and Lighting camera") @MainActor
struct SharedStudioCameraTests {
    @Test func bothViewportsUseIdenticalCameraPosesAndProjectionForEveryPreset() throws {
        let room = SampleData.createStarterRoom()
        let audit = Studio3DViewport(room: room, selectedFurnitureID: .constant(nil),
                                     selectedFurnitureScreenPosition: .constant(nil)).makeCoordinator()
        let lighting = LightingRoomScene(snapshot: LightingRoomSnapshot(room: room))
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        let camera = try #require(lighting.root.findEntity(named: "LightingCamera") as? PerspectiveCamera)
        for preset in ViewportPreset.allCases {
            audit.snapToViewport(preset, animated: false)
            lighting.apply(LightingSimulationSettings(), preset: preset, in: view)
            #expect(simd_distance(audit.camera.position, camera.position) < 0.001)
            #expect(simd_distance(audit.camera.orientation.vector, camera.orientation.vector) < 0.001)
            #expect(audit.camera.camera.fieldOfViewInDegrees == camera.camera.fieldOfViewInDegrees)
            #expect(audit.camera.camera.near == camera.camera.near)
            #expect(audit.camera.camera.far == camera.camera.far)
        }
    }

    @Test func selectingTheSamePresetAfterOrbitSnapsAgainWithoutChangingZoom() {
        let room = SampleData.createStarterRoom()
        let lighting = LightingRoomScene(snapshot: LightingRoomSnapshot(room: room))
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        lighting.apply(LightingSimulationSettings(), preset: .front, in: view)
        lighting.cameraController.orbit(fromYaw: 0, pitch: 0.15, deltaX: 200, deltaY: 20)
        lighting.cameraController.magnify(from: lighting.cameraController.distance, scale: 2)
        let distance = lighting.cameraController.distance
        lighting.apply(LightingSimulationSettings(), preset: .front, in: view, requestID: 1)
        #expect(lighting.cameraController.yaw == ViewportPreset.front.targetYaw)
        #expect(lighting.cameraController.pitch == ViewportPreset.front.targetPitch)
        #expect(lighting.cameraController.distance == distance)
    }

    @Test func northMarkerStaysAlignedWithCapturedNorthAcrossCameraPresets() throws {
        for bearing in [0.0, 90, 180, 270] {
            let room = SampleData.createStarterRoom()
            room.compassOrientation = RoomCompassOrientation(magneticForwardBearingDegrees: bearing)
            let scene = LightingRoomScene(snapshot: LightingRoomSnapshot(room: room))
            let marker = try #require(scene.root.findEntity(named: "RoomNorthMarker"))
            let expected = try #require(room.compassOrientation).direction(forBearingDegrees: 0)
            let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
            for preset in ViewportPreset.allCases {
                scene.apply(LightingSimulationSettings(), preset: preset, in: view)
                #expect(simd_distance(marker.orientation.act([0, 0, -1]), expected) < 0.001)
                for name in ["FrontWallGroup", "BackWallGroup", "LeftWallGroup", "RightWallGroup"] {
                    let wall = try #require(scene.root.findEntity(named: name))
                    #expect(wall.isEnabled)
                    if let opacity = wall.components[OpacityComponent.self] {
                        #expect(opacity.opacity > 0)
                    }
                }
            }
        }
    }

    @Test func auditNorthIndicatorIsVisibleWithoutFurnitureSelection() {
        let room = SampleData.createStarterRoom()
        room.compassOrientation = RoomCompassOrientation(magneticForwardBearingDegrees: 90)
        let audit = Studio3DViewport(room: room, selectedFurnitureID: .constant(nil),
                                     selectedFurnitureScreenPosition: .constant(nil)).makeCoordinator()
        let view = ARView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
                          cameraMode: .nonAR, automaticallyConfigureSession: false)
        audit.install(in: view)
        defer { audit.updateSubscription?.cancel(); view.scene.anchors.removeAll() }
        for preset in ViewportPreset.allCases {
            audit.snapToViewport(preset, animated: false)
            audit.updateSelectedProjection()
            #expect(audit.northIndicator.superview === view)
            #expect(!audit.northIndicator.isHidden)
            #expect(view.bounds.contains(audit.northIndicator.frame))
        }
        room.compassOrientation = nil
        audit.updateSelectedProjection()
        #expect(audit.northIndicator.isHidden)
    }

    @Test func supersedingAnAnimatedSnapCancelsItsUpdates() async {
        let camera = StudioOrbitCameraController(width: 4, length: 5, height: 2.6)
        camera.snap(to: .left) {}
        camera.snap(to: .right, animated: false) {}
        await Task.yield()
        #expect(camera.yaw == ViewportPreset.right.targetYaw)
        #expect(camera.pitch == ViewportPreset.right.targetPitch)
        #expect(camera.animationTask == nil)
    }
}
