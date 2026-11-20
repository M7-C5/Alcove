import RealityKit
import SwiftUI
import Testing
import simd
@testable import Alcove

@Suite("Shared Audit and Lighting camera") @MainActor
struct SharedStudioCameraTests {
    private func flushProjectionCallbacks() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume(returning: ()) }
        }
    }

    @Test(arguments: [StageType.audit, .rearrangement, .harmony],
          [CGSize(width: 1194, height: 834), CGSize(width: 1024, height: 768)])
    func initialFramingKeepsHeaderVisibleAndPreservesLaterZoom(stage: StageType, size: CGSize) async throws {
        for (width, length, height) in [(4.0, 5.0, 2.6), (12, 3, 2.6), (3, 15, 2.6), (4, 4, 4)] {
            let room = Room(name: "Framing", dimensionsWidth: width, dimensionsLength: length,
                            dimensionsHeight: height)
            var overlaps: [Bool] = []
            let coordinator = Studio3DViewport(room: room, selectedFurnitureID: .constant(nil),
                selectedFurnitureScreenPosition: .constant(nil), currentStage: stage,
                onHeaderOverlap: { overlaps.append($0) }).makeCoordinator()
            let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
            coordinator.install(in: view)
            defer { Studio3DViewport.dismantleUIView(view, coordinator: coordinator) }
            let initialDistance = coordinator.distance
            coordinator.updateHeaderOverlap()
            #expect(coordinator.distance == initialDistance)
            #expect(overlaps.isEmpty)

            view.frame = CGRect(origin: .zero, size: size)
            coordinator.updateHeaderOverlap()
            await flushProjectionCallbacks()
            #expect(overlaps == [false])
            let points = StudioViewportGeometry.roomCorners(width: width, length: length, height: height)
                .compactMap { view.project(coordinator.root.convert(position: $0, to: nil)) }
            #expect(points.count == 8)
            #expect(points.allSatisfy { $0.y >= StudioViewportGeometry.headerBottom + 24 })

            let overviewDistance = coordinator.distance
            coordinator.cameraController.magnify(from: overviewDistance, scale: 1)
            #expect(coordinator.distance == overviewDistance)
            coordinator.cameraController.magnify(from: coordinator.distance, scale: 2)
            let zoomedDistance = coordinator.distance
            coordinator.updateCamera()
            coordinator.updateHeaderOverlap()
            #expect(coordinator.distance == zoomedDistance)
        }
    }

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
        lighting.snapToViewport(.front, animated: false)
        #expect(lighting.cameraController.yaw == ViewportPreset.front.targetYaw)
        #expect(lighting.cameraController.pitch == ViewportPreset.front.targetPitch)
        #expect(lighting.cameraController.distance == distance)
    }

    @Test func lightingPresetCommandSurvivesSwiftUIRefreshAndRapidSelection() async throws {
        let room = SampleData.createStarterRoom()
        let scene = LightingRoomScene(snapshot: LightingRoomSnapshot(room: room))
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        scene.apply(LightingSimulationSettings(), preset: .front, in: view)
        let furnitureID = try #require(room.workingLayout?.furnitures.first?.id)
        let furniture = try #require(scene.root.findEntity(named: "Furniture-\(furnitureID)"))
        let sun = try #require(scene.root.findEntity(named: "Sunlight"))
        let sunlightTransform = sun.transform
        scene.snapToViewport(.left)
        scene.snapToViewport(.right, animated: false)
        scene.apply(LightingSimulationSettings(), preset: .right, in: view, animated: true)
        await Task.yield()
        #expect(scene.cameraController.yaw == ViewportPreset.right.targetYaw)
        #expect(scene.cameraController.pitch == ViewportPreset.right.targetPitch)
        #expect(scene.cameraController.animationTask == nil)
        #expect(sun.transform == sunlightTransform)
        #expect(scene.root.findEntity(named: furniture.name) === furniture)
    }

    @Test func lightingPlacementBlocksPresetCommandsUntilPlacementFinishes() {
        let room = SampleData.createStarterRoom()
        let scene = LightingRoomScene(snapshot: LightingRoomSnapshot(room: room))
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        scene.setPlacementMode(true)
        scene.apply(LightingSimulationSettings(), preset: .front, in: view)
        scene.snapToViewport(.left, animated: false)
        #expect(scene.cameraController.yaw == ViewportPreset.top.targetYaw)
        #expect(scene.cameraController.pitch == ViewportPreset.top.targetPitch)
        scene.setPlacementMode(false)
        scene.snapToViewport(.left, animated: false)
        #expect(scene.cameraController.yaw == ViewportPreset.left.targetYaw)
        #expect(scene.cameraController.pitch == ViewportPreset.left.targetPitch)
    }

    @Test func backgroundCompassPreservesCutawayShadowsWithoutVisibleNorth() throws {
        for bearing in [0.0, 90, 180, 270] {
            let room = SampleData.createStarterRoom()
            room.compassOrientation = RoomCompassOrientation(magneticForwardBearingDegrees: bearing)
            let scene = LightingRoomScene(snapshot: LightingRoomSnapshot(room: room))
            #expect(scene.root.findEntity(named: "RoomNorthMarker") == nil)
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

    @Test(arguments: [StageType.audit, .rearrangement, .harmony])
    func stageCompassStaysInBackgroundDuringCameraChanges(stage: StageType) throws {
        let room = SampleData.createStarterRoom()
        room.compassOrientation = RoomCompassOrientation(magneticForwardBearingDegrees: 90)
        let audit = Studio3DViewport(room: room, selectedFurnitureID: .constant(nil),
                                     selectedFurnitureScreenPosition: .constant(nil),
                                     currentStage: stage).makeCoordinator()
        let orientation = try #require(room.compassOrientation)
        let sunlight = audit.sun.transform
        for preset in ViewportPreset.allCases {
            audit.snapToViewport(preset, animated: false)
            #expect(audit.root.findEntity(named: "RoomNorthMarker") == nil)
            #expect(room.compassOrientation == orientation)
            #expect(audit.sun.transform == sunlight)
        }
    }

    @Test(arguments: [StageType.audit, .rearrangement, .harmony])
    func zoomHidesAndRestoresStageHeaderWithoutFurnitureSelection(stage: StageType) async {
        let room = SampleData.createStarterRoom()
        var overlaps: [Bool] = []
        let coordinator = Studio3DViewport(room: room, selectedFurnitureID: .constant(nil),
            selectedFurnitureScreenPosition: .constant(nil), currentStage: stage,
            onHeaderOverlap: { overlaps.append($0) }).makeCoordinator()
        let view = ARView(frame: CGRect(x: 0, y: 0, width: 1194, height: 834),
                          cameraMode: .nonAR, automaticallyConfigureSession: false)
        coordinator.install(in: view)
        defer { Studio3DViewport.dismantleUIView(view, coordinator: coordinator) }
        coordinator.distance = coordinator.cameraController.span * 3.5
        coordinator.updateCamera()
        await flushProjectionCallbacks()
        #expect(overlaps == [false])
        coordinator.cameraController.magnify(from: coordinator.distance, scale: 10)
        coordinator.updateCamera()
        await flushProjectionCallbacks()
        #expect(overlaps == [false, true])
        coordinator.updateHeaderOverlap()
        await flushProjectionCallbacks()
        #expect(overlaps == [false, true])
        coordinator.distance = coordinator.cameraController.span * 3.5
        coordinator.updateCamera()
        await flushProjectionCallbacks()
        #expect(overlaps == [false, true, false])
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
