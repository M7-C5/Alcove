import RealityKit
import SwiftUI
import Testing
import simd
@testable import Alcove

@Suite("Shared studio lighting") @MainActor
struct SharedStudioLightingTests {
    @Test(arguments: [StageType.audit, .rearrangement])
    func earlierStagesMatchLightingSunFixturesAndCutawayShadows(stage: StageType) throws {
        let room = SampleData.createStarterRoom()
        room.compassOrientation = RoomCompassOrientation(magneticForwardBearingDegrees: 60)
        let fixture = LightFixture(name: "Ceiling Light 1", layer: .ambient, kind: .ceilingLight)
        room.workingLayout?.lightFixtures = [fixture]
        let studio = Studio3DViewport(room: room, selectedFurnitureID: .constant(nil),
                                     selectedFurnitureScreenPosition: .constant(nil), currentStage: stage).makeCoordinator()
        let lighting = LightingRoomScene(snapshot: LightingRoomSnapshot(room: room))
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        let roof = try #require(studio.root.findEntity(named: "SunlightRoofOccluder"))
        let originalRoof = roof.transform
        let originalSun = studio.sun.transform
        let studioFixture = try #require(studio.root.findEntity(named: "LightingFixture-\(fixture.id)") as? SpotLight)
        let lightingFixture = try #require(lighting.root.findEntity(named: "LightingFixture-\(fixture.id)") as? SpotLight)
        for preset in ViewportPreset.allCases {
            studio.snapToViewport(preset, animated: false)
            lighting.apply(LightingSimulationSettings(), preset: preset, in: view)
            let lightingSun = try #require(lighting.root.findEntity(named: "Sunlight") as? DirectionalLight)
            #expect(studio.sun.transform == lightingSun.transform)
            #expect(studio.sun.light.intensity == lightingSun.light.intensity)
            #expect(studio.sun.transform == originalSun)
            #expect(studioFixture.light.intensity == lightingFixture.light.intensity)
            #expect(roof.isEnabled && roof.transform == originalRoof)
            #expect(roof.components[DynamicLightShadowComponent.self]?.castsShadow == true)
            for name in ["FrontWallGroup", "BackWallGroup", "LeftWallGroup", "RightWallGroup"] {
                let wall = try #require(studio.root.findEntity(named: name))
                let reference = try #require(lighting.root.findEntity(named: name))
                #expect(wall.isEnabled)
                #expect(wall.components[OpacityComponent.self]?.opacity == reference.components[OpacityComponent.self]?.opacity)
            }
        }
        studio.updateRoomLighting()
        #expect(studio.root.findEntity(named: studioFixture.name) === studioFixture)
    }

    @Test(arguments: [0.0, 90, 180, 270])
    func sunriseAndSunsetFollowCapturedNorthForEveryRoomHeading(heading: Double) throws {
        let orientation = try #require(RoomCompassOrientation(magneticForwardBearingDegrees: heading))
        let engine = IlluminationSimulationEngine()
        let morning = engine.sunlightDirection(for: engine.calculateDaylight(hourOfDay: 8), orientation: orientation)
        let evening = engine.sunlightDirection(for: engine.calculateDaylight(hourOfDay: 20), orientation: orientation)
        let east = orientation.direction(forBearingDegrees: 90)
        let west = orientation.direction(forBearingDegrees: 270)
        #expect(simd_dot(simd_normalize(morning), east) > 0.999)
        #expect(simd_dot(simd_normalize(evening), west) > 0.999)
    }
}
