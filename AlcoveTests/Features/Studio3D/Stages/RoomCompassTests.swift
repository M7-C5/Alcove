import Foundation
import RealityKit
import SwiftData
import Testing
import UIKit
import simd
@testable import Alcove

@Suite("Room compass") @MainActor
struct RoomCompassTests {
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
        let geometry = LightingRoomGeometry(width: 4, length: 5, height: 2.6)
        let camera = LightingCameraNavigation()
        for preset in ViewportPreset.allCases {
            let offset = camera.position(preset: preset, geometry: geometry) - camera.target(in: geometry)
            let azimuth = atan2(offset.x, offset.z)
            #expect(abs(sin(azimuth - preset.targetYaw)) < 0.001)
            #expect(abs(atan2(offset.y, hypot(offset.x, offset.z)) - preset.targetPitch) < 0.001)
        }
    }
}
