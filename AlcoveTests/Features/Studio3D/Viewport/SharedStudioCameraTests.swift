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

    @Test func floorNorthDoesNotChangeCutawayShadows() throws {
        for bearing in [0.0, 90, 180, 270] {
            let room = SampleData.createStarterRoom()
            room.compassOrientation = RoomCompassOrientation(magneticForwardBearingDegrees: bearing)
            let scene = LightingRoomScene(snapshot: LightingRoomSnapshot(room: room))
            #expect(scene.root.findEntity(named: "RoomNorthMarker") != nil)
            let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
            for preset in ViewportPreset.allCases {
                scene.apply(LightingSimulationSettings(), preset: preset, in: view)
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

    @Test func auditFloorNorthStaysFixedWithoutFurnitureSelection() throws {
        let room = SampleData.createStarterRoom()
        room.compassOrientation = RoomCompassOrientation(magneticForwardBearingDegrees: 90)
        let audit = Studio3DViewport(room: room, selectedFurnitureID: .constant(nil),
                                     selectedFurnitureScreenPosition: .constant(nil)).makeCoordinator()
        let marker = try #require(audit.root.findEntity(named: "RoomNorthMarker"))
        let original = marker.transform
        for preset in ViewportPreset.allCases {
            audit.snapToViewport(preset, animated: false)
            #expect(marker.isEnabled)
            #expect(marker.transform == original)
            #expect(marker.position.y < 0.03)
        }
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

    @Test func twoFingerPanMovesCameraAnchorHorizontallyAndVerticallyAndSnapResetsToCenter() {
        let camera = StudioOrbitCameraController(width: 4, length: 5, height: 2.6)
        let center = camera.defaultTarget
        #expect(camera.target == center)

        // Pan horizontally and vertically in camera screen space
        camera.panAnchor(from: center, deltaX: 120, deltaY: 80)
        #expect(camera.target.x < center.x)
        #expect(camera.target.y > center.y)

        // Extreme pan stays clamped within room bounds
        camera.panAnchor(from: center, deltaX: 100_000, deltaY: -100_000)
        #expect(camera.target.x >= -camera.span * 0.9)
        #expect(camera.target.y >= 0)

        // Orbit pitch clamps to minOrbitPitch
        camera.orbit(fromYaw: 0, pitch: 0.62, deltaX: 0, deltaY: -100_000)
        #expect(camera.pitch == StudioOrbitCameraController.minOrbitPitch)

        // Snapping to a preset re-centers the anchor on the room
        camera.snap(to: .dollhouse, animated: false) {}
        #expect(camera.target == center)
    }
}
