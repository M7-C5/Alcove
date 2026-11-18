import RealityKit
import Testing
import simd
@testable import Alcove

@Suite("Floor north visualization") @MainActor
struct LightingNorthIndicatorTests {
    @Test(arguments: [0.0, 90, 180, 270])
    func floorArrowMatchesCapturedNorthAndStaysFixedDuringOrbit(bearing: Double) throws {
        let room = SampleData.createStarterRoom()
        room.compassOrientation = RoomCompassOrientation(magneticForwardBearingDegrees: bearing)
        let scene = LightingRoomScene(snapshot: LightingRoomSnapshot(room: room))
        let marker = try #require(scene.root.findEntity(named: "RoomNorthMarker"))
        let north = try #require(room.compassOrientation).direction(forBearingDegrees: 0)
        #expect(simd_distance(marker.orientation.act([0, 0, -1]), north) < 0.001)
        #expect(marker.position.y > 0 && marker.position.y < 0.03)
        #expect(marker.findEntity(named: "NorthLabel") != nil)
        let original = marker.transform
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        for preset in ViewportPreset.allCases {
            scene.apply(LightingSimulationSettings(), preset: preset, in: view)
            #expect(marker.transform == original)
        }
        func checkShadows(_ entity: Entity) {
            #expect(entity.components[DynamicLightShadowComponent.self]?.castsShadow == false)
            for child in entity.children { checkShadows(child) }
        }
        checkShadows(marker)
    }

    @Test func uncapturedRoomHasExplicitSampleMarker() {
        let room = SampleData.createStarterRoom()
        room.compassOrientation = nil
        let marker = RoomNorthMarker.build(snapshot: LightingRoomSnapshot(room: room))
        #expect(marker.findEntity(named: "NorthSampleLabel") != nil)
        #expect(simd_distance(marker.orientation.act([0, 0, -1]), [0, 0, 1]) < 0.001)
    }
}
