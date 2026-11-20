import Foundation
import RealityKit
import SwiftData
import Testing
import UIKit
import simd
@testable import Alcove

@Suite("Room compass") @MainActor
struct RoomCompassTests {
    @Test(arguments: [0.0, 90, 180, 270, 359])
    func scanCompassStaysInWorldFrameWhileCameraTurns(worldHeading: Double) throws {
        var stabilizer = RoomCompassStabilizer()
        var result: Double?
        for cameraOffset in [-70.0, 25, 140] {
            let angle = Float(cameraOffset * .pi / 180)
            let forward = SIMD3<Float>(sin(angle), 0, -cos(angle))
            let bearing = try #require(RoomCompassCapture.worldBearing(
                cameraBearing: worldHeading + cameraOffset, cameraForward: forward))
            result = stabilizer.append(bearing)
        }
        let heading = try #require(result)
        let error = (heading - worldHeading + 540).truncatingRemainder(dividingBy: 360) - 180
        #expect(abs(error) < 0.001)
        #expect(RoomCompassCapture.worldBearing(cameraBearing: 0, cameraForward: [0, -1, 0]) == nil)
        #expect(RoomCompassCapture.worldBearing(cameraBearing: 0, cameraForward: [.nan, 0, -1]) == nil)
    }

    @Test(arguments: [0.0, Double.pi / 2, -Double.pi / 2, Double.pi, 0.63])
    func scannedNorthMatchesNormalizedWallsAndFurniture(wallYaw: Double) throws {
        let orientation = try #require(RoomCompassOrientation(magneticForwardBearingDegrees: 37))
        let payload = CapturedRoomPayload(roomLength: 4, roomWidth: 5, roomHeight: 2.6,
            walls: [ScannedWallPayload(position: [2, 1.3, -3], dimensions: [5, 2.6, 0.1],
                                       rotationYaw: Float(wallYaw))], openings: [], objects: [])
        let room = RoomCaptureMapper().mapToRoom(payload: payload, compassOrientation: orientation)
        let snapshot = try #require(room.planSnapshot)
        let localCompass = try #require(room.compassOrientation)
        #expect(localCompass.capturedAt == orientation.capturedAt)
        for bearing in [0.0, 90, 180, 270] {
            let worldDirection = orientation.direction(forBearingDegrees: bearing)
            let origin = snapshot.localCoordinates(worldX: snapshot.centerX, worldZ: snapshot.centerZ)
            let point = snapshot.localCoordinates(worldX: snapshot.centerX + worldDirection.x,
                                                  worldZ: snapshot.centerZ + worldDirection.z)
            let expected = SIMD3<Float>(point.x - origin.x, 0, point.y - origin.y)
            #expect(simd_distance(localCompass.direction(forBearingDegrees: bearing), expected) < 0.001)
        }
        let marker = RoomNorthMarker.build(snapshot: LightingRoomSnapshot(room: room))
        #expect(simd_distance(marker.orientation.act([0, 0, -1]),
                              localCompass.direction(forBearingDegrees: 0)) < 0.001)
    }

    @Test func cameraDirectionUsesRearCameraInsteadOfInterfaceOrientation() throws {
        #expect(RoomCompassCapture.cameraBearing(north: 1, west: 0) == 0)
        #expect(RoomCompassCapture.cameraBearing(north: 0, west: -1) == 90)
        #expect(RoomCompassCapture.cameraBearing(north: -1, west: 0) == 180)
        #expect(RoomCompassCapture.cameraBearing(north: 0, west: 1) == 270)
        #expect(RoomCompassCapture.cameraBearing(north: 0, west: 0) == nil)
        #expect(RoomCompassCapture.cameraBearing(north: .nan, west: 0) == nil)
        // Tilting the device does not change the horizontal bearing.
        #expect(RoomCompassCapture.cameraBearing(north: 0.5, west: 0) == 0)
    }

    @Test func compassRequiresStableReadingsAndHandlesNorthWraparound() throws {
        var filter = RoomCompassStabilizer()
        #expect(filter.append(359) == nil)
        #expect(filter.append(0) == nil)
        let northReading = filter.append(1)
        let north = try #require(northReading)
        #expect(min(north, 360 - north) < 0.001)
        filter = RoomCompassStabilizer()
        #expect(filter.append(10) == nil)
        #expect(filter.append(90) == nil)
        #expect(filter.append(91) == nil)
        let stableReading = filter.append(89)
        let stable = try #require(stableReading)
        #expect(abs(stable - 90) < 0.001)
        #expect(filter.append(.infinity) == nil)
    }

    @Test func compassPersistsAndSurvivesLayoutResetWithSafeLegacyFallback() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let room = SampleData.createStarterRoom()
        #expect(room.compassOrientation == nil)
        let orientation = try #require(RoomCompassOrientation(magneticForwardBearingDegrees: 450))
        room.compassOrientation = orientation
        container.mainContext.insert(room)
        try container.mainContext.save()
        let stored = try #require(ModelContext(container).fetch(FetchDescriptor<Room>()).first)
        #expect(stored.compassOrientation == orientation)
        #expect(stored.compassOrientation?.magneticForwardBearingDegrees == 90)
        let snapshot = LightingRoomSnapshot(room: stored)
        stored.resetWorkingLayoutToBaseline()
        #expect(stored.compassOrientation == orientation)
        #expect(snapshot.compassOrientation == orientation)
        stored.compassOrientationData = Data("invalid".utf8)
        #expect(stored.compassOrientation == nil)
        #expect(RoomCompassOrientation(magneticForwardBearingDegrees: .nan) == nil)
    }

    @Test func morningLightComesFromEastRelativeToRoomHeading() throws {
        let engine = IlluminationSimulationEngine()
        let morning = engine.calculateDaylight(hourOfDay: 8)
        let northFacing = try #require(RoomCompassOrientation(magneticForwardBearingDegrees: 0))
        let eastFacing = try #require(RoomCompassOrientation(magneticForwardBearingDegrees: 90))
        let northRoom = engine.sunlightDirection(for: morning, orientation: northFacing)
        let eastRoom = engine.sunlightDirection(for: morning, orientation: eastFacing)
        #expect(northRoom.x > 0.99 && abs(northRoom.z) < 0.001)
        #expect(eastRoom.z < -0.99 && abs(eastRoom.x) < 0.001)
        let evening = engine.sunlightDirection(for: engine.calculateDaylight(hourOfDay: 20), orientation: northFacing)
        #expect(evening.x < -0.99)
        #expect(simd_distance(northFacing.direction(forBearingDegrees: 0), [0, 0, -1]) < 0.001)
        #expect(simd_distance(eastFacing.direction(forBearingDegrees: 0), [-1, 0, 0]) < 0.001)
    }

    @Test func cameraChangesDoNotRotateCapturedSunOrCompass() throws {
        let room = SampleData.createStarterRoom()
        room.compassOrientation = RoomCompassOrientation(magneticForwardBearingDegrees: 75)
        let snapshot = LightingRoomSnapshot(room: room)
        let scene = LightingRoomScene(snapshot: snapshot)
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        scene.apply(LightingSimulationSettings(), preset: .front, in: view)
        let sun = try #require(scene.root.findEntity(named: "Sunlight"))
        let transform = sun.transform
        for preset in ViewportPreset.allCases {
            scene.apply(LightingSimulationSettings(), preset: preset, in: view)
            #expect(sun.transform == transform)
            #expect(room.compassOrientation == snapshot.compassOrientation)
        }
    }

    @Test func lightingUsesPrimaryViewportPresetAngles() {
        let camera = StudioOrbitCameraController(width: 4, length: 5, height: 2.6)
        for preset in ViewportPreset.allCases {
            camera.snap(to: preset, animated: false) {}
            let offset = camera.position - camera.target
            let azimuth = atan2(offset.x, offset.z)
            #expect(abs(sin(azimuth - preset.targetYaw)) < 0.001)
            #expect(abs(atan2(offset.y, hypot(offset.x, offset.z)) - preset.targetPitch) < 0.001)
        }
    }
}
